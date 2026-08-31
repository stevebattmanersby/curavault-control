-- CuraVault Control Site: controlled Codex provider architecture, Phase 3.
-- This migration records server-governed provider policy and durable execution
-- evidence only. It never stores provider credentials, repository credentials,
-- raw prompts, raw terminal output, patient data, or executable shell input.

-- New enum labels must commit before they can be used in table/function DDL.
alter type public.development_execution_provider add value if not exists 'codex';
alter type public.development_executor_mode add value if not exists 'codex';

begin;

-- Phase 2's mock configuration remains mock-only. Codex has a separate
-- server-managed row so enabling a disposable mock executor cannot enable it.
create table if not exists public.admin_development_execution_provider_configuration (
  provider public.development_execution_provider primary key,
  is_enabled boolean not null default false,
  allowed_repository text not null default 'stevebattmanersby/curavult-app'
    check (allowed_repository = 'stevebattmanersby/curavult-app'),
  allowed_base_branch_pattern text not null default '^main$',
  max_runtime_seconds integer not null default 1800
    check (max_runtime_seconds between 60 and 1800),
  max_attempts smallint not null default 3 check (max_attempts between 1 and 3),
  max_concurrent_jobs smallint not null default 1 check (max_concurrent_jobs = 1),
  allow_provider_api_network boolean not null default true,
  allow_repository_network boolean not null default false,
  allow_workspace_write boolean not null default true,
  policy_version text not null default 'phase_3_codex_v1'
    check (char_length(policy_version) between 1 and 80),
  changed_by uuid references public.admin_users(admin_user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (provider = 'codex'),
  check (allow_provider_api_network),
  check (allow_workspace_write)
);

insert into public.admin_development_execution_provider_configuration (provider, is_enabled)
values ('codex', false)
on conflict (provider) do nothing;

-- A trusted worker/deployment path refreshes this pin. Browser roles have no
-- access; a missing or stale pin rejects a request instead of floating a ref.
create table if not exists public.admin_development_repository_revisions (
  repository text not null check (repository = 'stevebattmanersby/curavult-app'),
  base_branch text not null check (base_branch = 'main'),
  resolved_base_sha text not null check (resolved_base_sha ~ '^[0-9a-f]{40,64}$'),
  resolved_at timestamptz not null default now(),
  resolved_by text not null default 'trusted_worker' check (char_length(resolved_by) <= 80),
  primary key (repository, base_branch)
);

create table if not exists public.admin_development_codex_execution_authorizations (
  task_id uuid primary key references public.admin_development_tasks(id) on delete restrict,
  authorized_by uuid not null references public.admin_users(admin_user_id) on delete restrict,
  authorized_at timestamptz not null default now(),
  policy_version text not null default 'phase_3_codex_v1' check (char_length(policy_version) <= 80),
  revoked_at timestamptz,
  revoked_by uuid references public.admin_users(admin_user_id) on delete restrict,
  check ((revoked_at is null and revoked_by is null) or (revoked_at is not null and revoked_by is not null))
);

alter table public.admin_development_execution_jobs
  add column if not exists requested_base_branch text,
  add column if not exists resolved_base_sha text check (resolved_base_sha is null or resolved_base_sha ~ '^[0-9a-f]{40,64}$'),
  add column if not exists provider_policy_version text,
  add column if not exists max_runtime_seconds integer check (max_runtime_seconds is null or max_runtime_seconds between 60 and 1800),
  add column if not exists workspace_change_summary jsonb not null default '{}'::jsonb,
  add column if not exists changed_paths jsonb not null default '[]'::jsonb,
  add column if not exists diff_sha256 text check (diff_sha256 is null or diff_sha256 ~ '^[0-9a-f]{64}$'),
  add column if not exists protected_path_changed boolean not null default false,
  add column if not exists tests_summary text,
  add column if not exists analyzer_summary text,
  add column if not exists cleanup_status text,
  add column if not exists worker_lease_expires_at timestamptz;

do $$
declare constraint_name text;
begin
  select conname into constraint_name
  from pg_constraint
  where conrelid = 'public.admin_development_execution_jobs'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%provider = ''mock''%';
  if constraint_name is not null then
    execute format('alter table public.admin_development_execution_jobs drop constraint %I', constraint_name);
  end if;
  select conname into constraint_name
  from pg_constraint
  where conrelid = 'public.admin_development_execution_jobs'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%executor_mode = ''mock''%';
  if constraint_name is not null then
    execute format('alter table public.admin_development_execution_jobs drop constraint %I', constraint_name);
  end if;
end;
$$;

alter table public.admin_development_execution_jobs
  add constraint admin_development_execution_provider_mode_check check (
    (provider = 'mock' and executor_mode = 'mock') or
    (provider = 'codex' and executor_mode = 'codex')
  );

do $$
declare constraint_name text;
begin
  select conname into constraint_name
  from pg_constraint
  where conrelid = 'public.admin_development_execution_jobs'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%failure_code%';
  if constraint_name is not null then
    execute format('alter table public.admin_development_execution_jobs drop constraint %I', constraint_name);
  end if;
end;
$$;

alter table public.admin_development_execution_jobs
  add constraint admin_development_execution_jobs_failure_code_check check (
    failure_code is null or failure_code in (
      'development_execution_disabled', 'task_not_eligible', 'approval_required',
      'security_review_required', 'critical_execution_not_supported',
      'stale_task_snapshot', 'provider_not_allowed', 'execution_conflict',
      'execution_cancelled', 'mock_execution_failed', 'codex_execution_disabled',
      'repository_not_allowed', 'base_branch_not_allowed', 'base_sha_unresolved',
      'codex_execution_authorization_required', 'execution_output_policy_violation',
      'workspace_cleanup_failed', 'provider_timeout', 'provider_error',
      'provider_malformed_response', 'codex_concurrency_limit_reached'
    )
  );

alter table public.admin_development_execution_policy_decisions
  add column if not exists effective_risk_level public.development_risk_level,
  add column if not exists resolved_base_sha text,
  add column if not exists provider_policy_version text;

create unique index if not exists admin_development_one_active_codex_execution_idx
  on public.admin_development_execution_jobs ((1))
  where provider = 'codex' and status in ('queued', 'starting', 'running', 'cancel_requested');

create or replace function public.admin_development_codex_execution_enabled()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select is_enabled
    from public.admin_development_execution_provider_configuration
    where provider = 'codex'
  ), false)
$$;

-- Escalation can only increase risk. Prompt text is never trusted to reduce
-- controls; it is inspected only to conservatively recognize protected scope.
create or replace function public.admin_development_codex_effective_risk(p_task public.admin_development_tasks)
returns public.development_risk_level language sql stable security definer set search_path = public as $$
  select case
    when p_task.risk_level = 'critical' then 'critical'::public.development_risk_level
    when p_task.risk_level = 'high' then 'high'::public.development_risk_level
    when p_task.task_type in ('security', 'migration', 'release') then 'high'::public.development_risk_level
    when lower(coalesce(p_task.execution_prompt, '')) ~ '(supabase/(migrations|functions)|android/|ios/|\.github/workflows|entitlement|auth/|rls|security)' then 'high'::public.development_risk_level
    else p_task.risk_level
  end
$$;

create or replace function public.admin_audit_development_codex_configuration()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_admin_email text;
begin
  if new.is_enabled is distinct from old.is_enabled then
    select email into v_admin_email from public.admin_users where admin_user_id = auth.uid();
    insert into public.admin_audit_log (
      admin_user_id, admin_email, target_resource_type, target_resource_id,
      action_type, result, next
    ) values (
      auth.uid(), v_admin_email, 'admin_development_execution_provider_configuration', new.provider::text,
      'development.codex.configuration.updated', 'success',
      jsonb_build_object('provider', new.provider, 'is_enabled', new.is_enabled)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists admin_audit_development_codex_configuration on public.admin_development_execution_provider_configuration;
create trigger admin_audit_development_codex_configuration
  after update on public.admin_development_execution_provider_configuration
  for each row execute function public.admin_audit_development_codex_configuration();

create or replace function public.admin_authorize_codex_execution(p_task_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_admin() or public.current_admin_role() <> 'owner' then
    raise exception 'development_execution_not_authorized';
  end if;
  if not exists (select 1 from public.admin_development_tasks where id = p_task_id) then
    raise exception 'task_not_found';
  end if;
  insert into public.admin_development_codex_execution_authorizations (task_id, authorized_by)
  values (p_task_id, auth.uid())
  on conflict (task_id) do update set
    authorized_by = excluded.authorized_by,
    authorized_at = now(),
    revoked_at = null,
    revoked_by = null;
end;
$$;

create or replace function public.admin_codex_execution_available(p_task_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_task public.admin_development_tasks;
begin
  if not public.is_active_admin() or public.current_admin_role() not in ('owner', 'admin') then
    return false;
  end if;
  select * into v_task from public.admin_development_tasks where id = p_task_id;
  return found
    and public.admin_development_codex_execution_enabled()
    and v_task.repository = 'stevebattmanersby/curavult-app'
    and exists (
      select 1 from public.admin_development_repository_revisions
      where repository = v_task.repository and base_branch = v_task.base_branch
        and resolved_at >= now() - interval '15 minutes'
    )
    and v_task.risk_level <> 'critical';
end;
$$;

create or replace function public.admin_request_codex_development_execution(p_task_id uuid)
returns table(job_id uuid, job_key text, job_status public.development_execution_status, policy_decision public.development_execution_policy_decision, duplicate boolean)
language plpgsql security definer set search_path = public as $$
declare
  v_task public.admin_development_tasks;
  v_config public.admin_development_execution_provider_configuration;
  v_revision public.admin_development_repository_revisions;
  v_authorization public.admin_development_codex_execution_authorizations;
  v_existing public.admin_development_execution_jobs;
  v_snapshot text; v_prompt_hash text; v_idempotency text; v_reasons jsonb := '[]'::jsonb;
  v_effective_risk public.development_risk_level;
  v_decision public.development_execution_policy_decision := 'deny'; v_job public.admin_development_execution_jobs;
begin
  if not public.is_active_admin() or public.current_admin_role() not in ('owner', 'admin') then
    raise exception 'development_execution_not_authorized';
  end if;
  select * into v_task from public.admin_development_tasks where id = p_task_id for update;
  if not found then raise exception 'task_not_found'; end if;
  v_effective_risk := public.admin_development_codex_effective_risk(v_task);
  select * into v_existing from public.admin_development_execution_jobs
    where task_id = p_task_id and status in ('requested', 'policy_check', 'queued', 'starting', 'running', 'cancel_requested')
    order by created_at desc limit 1;
  if found then
    return query select v_existing.id, v_existing.job_key, v_existing.status,
      coalesce((select decision from public.admin_development_execution_policy_decisions where execution_job_id = v_existing.id order by evaluated_at desc limit 1), 'deny'::public.development_execution_policy_decision), true;
    return;
  end if;
  select * into v_config from public.admin_development_execution_provider_configuration where provider = 'codex';
  select * into v_revision from public.admin_development_repository_revisions
    where repository = v_task.repository and base_branch = v_task.base_branch;
  select * into v_authorization from public.admin_development_codex_execution_authorizations
    where task_id = p_task_id and revoked_at is null;
  v_snapshot := public.admin_development_execution_snapshot(v_task);
  v_prompt_hash := encode(digest(coalesce(v_task.execution_prompt, ''), 'sha256'), 'hex');
  v_idempotency := encode(digest(concat_ws('|', p_task_id::text, v_snapshot, 'codex', coalesce(v_revision.resolved_base_sha, 'unresolved'), coalesce(v_config.policy_version, 'unconfigured')), 'sha256'), 'hex');
  insert into public.admin_development_execution_jobs (
    task_id, job_key, requested_by, approved_execution_by, idempotency_key, task_snapshot_hash,
    execution_prompt_hash, provider, executor_mode, repository, base_branch, requested_base_branch,
    resolved_base_sha, provider_policy_version, max_runtime_seconds
  ) values (
    p_task_id, 'CVRUN-' || lpad(nextval('public.admin_development_execution_job_key_seq')::text, 6, '0'),
    auth.uid(), case when v_task.human_approval_status = 'approved' then v_task.approved_by else null end,
    v_idempotency, v_snapshot, v_prompt_hash, 'codex', 'codex', v_task.repository, v_task.base_branch,
    v_task.base_branch, v_revision.resolved_base_sha, coalesce(v_config.policy_version, 'unconfigured'), v_config.max_runtime_seconds
  ) returning * into v_job;
  perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'execution_requested', null, 'requested', 'admin', auth.uid(), 'Codex execution requested.');
  update public.admin_development_execution_jobs set status = 'policy_check', updated_at = now() where id = v_job.id;
  perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'policy_check_started', 'requested', 'policy_check', 'dispatcher', auth.uid(), 'Codex execution policy evaluation started.');
  if v_config is null or not v_config.is_enabled then
    v_reasons := jsonb_build_array('codex_execution_disabled');
  elsif v_task.repository <> v_config.allowed_repository then
    v_reasons := jsonb_build_array('repository_not_allowed');
  elsif v_task.base_branch !~ v_config.allowed_base_branch_pattern then
    v_reasons := jsonb_build_array('base_branch_not_allowed');
  elsif v_revision is null or v_revision.resolved_at < now() - interval '15 minutes' then
    v_reasons := jsonb_build_array('base_sha_unresolved');
  elsif v_task.execution_prompt is null or btrim(v_task.execution_prompt) = '' or v_task.status in ('cancelled', 'completed', 'failed', 'blocked', 'draft') then
    v_reasons := jsonb_build_array('task_not_eligible');
  elsif v_effective_risk = 'critical' then
    v_decision := 'manual_review_required'; v_reasons := jsonb_build_array('critical_execution_not_supported');
  elsif v_effective_risk = 'low' and v_task.status in ('ready', 'awaiting_review', 'approved') then
    v_decision := 'allow'; v_reasons := jsonb_build_array('low_risk_codex_allowed');
  elsif v_effective_risk = 'medium' and v_task.status = 'approved' and v_task.architecture_review_status = 'approved' then
    v_decision := 'allow'; v_reasons := jsonb_build_array('medium_risk_architecture_reviewed_codex_allowed');
  elsif v_effective_risk = 'high' and v_task.status = 'approved'
    and v_task.human_approval_status = 'approved' and v_task.approved_by is not null and v_task.approved_at is not null
    and v_task.architecture_review_status = 'approved' and v_task.security_review_status = 'approved'
    and v_authorization.task_id is not null then
    v_decision := 'allow'; v_reasons := jsonb_build_array('high_risk_owner_authorized_codex_allowed');
  elsif v_effective_risk = 'high' then
    v_reasons := jsonb_build_array('approval_required', 'security_review_required', 'codex_execution_authorization_required');
  else
    v_reasons := jsonb_build_array('task_not_eligible');
  end if;
  insert into public.admin_development_execution_policy_decisions (
    execution_job_id, task_id, decision, risk_level, effective_risk_level, task_status, human_approval_status,
    architecture_review_status, security_review_status, repository, base_branch, resolved_base_sha, provider_policy_version, reasons
  ) values (
    v_job.id, p_task_id, v_decision, v_task.risk_level, v_effective_risk, v_task.status, v_task.human_approval_status,
    v_task.architecture_review_status, v_task.security_review_status, v_task.repository, v_task.base_branch,
    v_revision.resolved_base_sha, coalesce(v_config.policy_version, 'unconfigured'), v_reasons
  );
  if v_decision <> 'allow' then
    update public.admin_development_execution_jobs set status = 'rejected', failed_at = now(), updated_at = now(), failure_code = v_reasons->>0, failure_summary = 'Codex execution policy did not allow this run.' where id = v_job.id;
    perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'policy_rejected', 'policy_check', 'rejected', 'dispatcher', auth.uid(), 'Codex execution policy rejected the run.', jsonb_build_object('decision', v_decision));
    perform public.admin_audit_development_execution('development.execution.rejected', p_task_id, v_job.id, 'codex', 'rejected', v_decision, v_reasons->>0);
  else
    begin
      update public.admin_development_execution_jobs set status = 'queued', queued_at = now(), updated_at = now() where id = v_job.id;
      perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'execution_queued', 'policy_check', 'queued', 'dispatcher', auth.uid(), 'Codex execution queued for the trusted worker.', jsonb_build_object('policy_version', v_config.policy_version, 'base_sha_pinned', true));
      perform public.admin_audit_development_execution('development.execution.queued', p_task_id, v_job.id, 'codex', 'queued', v_decision);
    exception when unique_violation then
      v_decision := 'deny';
      update public.admin_development_execution_jobs set status = 'rejected', failed_at = now(), updated_at = now(), failure_code = 'codex_concurrency_limit_reached', failure_summary = 'Codex concurrency limit is already in use.' where id = v_job.id;
      perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'policy_rejected', 'policy_check', 'rejected', 'dispatcher', auth.uid(), 'Codex execution rejected by the global concurrency limit.');
      perform public.admin_audit_development_execution('development.execution.rejected', p_task_id, v_job.id, 'codex', 'rejected', v_decision, 'codex_concurrency_limit_reached');
    end;
  end if;
  select * into v_job from public.admin_development_execution_jobs where id = v_job.id;
  return query select v_job.id, v_job.job_key, v_job.status, v_decision, false;
end;
$$;

do $$ declare t text; begin
  foreach t in array array['admin_development_execution_provider_configuration', 'admin_development_repository_revisions', 'admin_development_codex_execution_authorizations'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
  end loop;
end $$;

revoke all on function public.admin_development_codex_execution_enabled() from public, anon, authenticated;
revoke all on function public.admin_development_codex_effective_risk(public.admin_development_tasks) from public, anon, authenticated;
revoke all on function public.admin_audit_development_codex_configuration() from public, anon, authenticated;
revoke all on function public.admin_authorize_codex_execution(uuid) from public, anon;
revoke all on function public.admin_codex_execution_available(uuid) from public, anon;
revoke all on function public.admin_request_codex_development_execution(uuid) from public, anon;
grant execute on function public.admin_authorize_codex_execution(uuid) to authenticated;
grant execute on function public.admin_codex_execution_available(uuid) to authenticated;
grant execute on function public.admin_request_codex_development_execution(uuid) to authenticated;

commit;

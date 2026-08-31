-- CuraVault Control Site: secure Development Execution Dispatcher, Phase 2.
-- Mock-only orchestration metadata. This migration never stores provider tokens,
-- raw prompts, product requests, raw logs, patient data, or executable commands.

begin;

do $$ begin
  create type public.development_execution_provider as enum ('mock');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_executor_mode as enum ('mock');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_execution_status as enum (
    'requested', 'policy_check', 'rejected', 'queued', 'starting', 'running',
    'succeeded', 'failed', 'cancel_requested', 'cancelled', 'timed_out'
  );
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_execution_actor_type as enum ('admin', 'dispatcher', 'executor', 'system');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_execution_policy_decision as enum ('allow', 'deny', 'manual_review_required');
exception when duplicate_object then null; end $$;

create sequence if not exists public.admin_development_execution_job_key_seq;

-- This singleton is intentionally server-managed. No authenticated policy or
-- public RPC can enable it; a future privileged deployment path must be
-- separately designed and reviewed.
create table if not exists public.admin_development_execution_configuration (
  provider public.development_execution_provider primary key default 'mock',
  is_enabled boolean not null default false,
  changed_by uuid references public.admin_users(admin_user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (provider = 'mock')
);

insert into public.admin_development_execution_configuration (provider, is_enabled)
values ('mock', false)
on conflict (provider) do nothing;

create table if not exists public.admin_development_execution_jobs (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.admin_development_tasks(id) on delete restrict,
  job_key text not null unique,
  provider public.development_execution_provider not null default 'mock',
  executor_mode public.development_executor_mode not null default 'mock',
  status public.development_execution_status not null default 'requested',
  attempt_number smallint not null default 1 check (attempt_number between 1 and 3),
  requested_by uuid not null references public.admin_users(admin_user_id) on delete restrict,
  approved_execution_by uuid references public.admin_users(admin_user_id) on delete restrict,
  idempotency_key text not null check (char_length(idempotency_key) = 64),
  task_snapshot_hash text not null check (char_length(task_snapshot_hash) = 64),
  execution_prompt_hash text not null check (char_length(execution_prompt_hash) = 64),
  repository text not null check (repository ~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'),
  base_branch text not null check (char_length(base_branch) between 1 and 160),
  requested_working_branch text check (char_length(requested_working_branch) <= 160),
  provider_job_id text check (char_length(provider_job_id) <= 240),
  provider_run_reference text check (char_length(provider_run_reference) <= 240),
  queued_at timestamptz,
  started_at timestamptz,
  heartbeat_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  cancelled_at timestamptz,
  failure_code text check (failure_code is null or failure_code in (
    'development_execution_disabled', 'task_not_eligible', 'approval_required',
    'security_review_required', 'critical_execution_not_supported',
    'stale_task_snapshot', 'provider_not_allowed', 'execution_conflict',
    'execution_cancelled', 'mock_execution_failed'
  )),
  failure_summary text check (char_length(failure_summary) <= 1000),
  result_summary text check (char_length(result_summary) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(task_id, idempotency_key),
  check (provider = 'mock'),
  check (executor_mode = 'mock'),
  check (status <> 'succeeded' or completed_at is not null),
  check (status <> 'failed' or failed_at is not null),
  check (status <> 'cancelled' or cancelled_at is not null)
);

create table if not exists public.admin_development_execution_events (
  id uuid primary key default gen_random_uuid(),
  execution_job_id uuid not null references public.admin_development_execution_jobs(id) on delete restrict,
  task_id uuid not null references public.admin_development_tasks(id) on delete restrict,
  event_type text not null check (char_length(event_type) <= 80),
  previous_status public.development_execution_status,
  new_status public.development_execution_status,
  actor_type public.development_execution_actor_type not null,
  actor_user_id uuid references public.admin_users(admin_user_id) on delete restrict,
  provider public.development_execution_provider not null default 'mock',
  summary text not null check (char_length(summary) <= 1000),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create table if not exists public.admin_development_execution_policy_decisions (
  id uuid primary key default gen_random_uuid(),
  execution_job_id uuid not null references public.admin_development_execution_jobs(id) on delete restrict,
  task_id uuid not null references public.admin_development_tasks(id) on delete restrict,
  decision public.development_execution_policy_decision not null,
  risk_level public.development_risk_level not null,
  task_status public.development_task_status not null,
  human_approval_status public.development_review_decision not null,
  architecture_review_status public.development_review_decision not null,
  security_review_status public.development_review_decision not null,
  repository text not null,
  base_branch text not null,
  policy_version text not null default 'phase_2_mock_v1' check (char_length(policy_version) <= 80),
  reasons jsonb not null default '[]'::jsonb check (jsonb_typeof(reasons) = 'array'),
  evaluated_at timestamptz not null default now()
);

create index if not exists admin_development_execution_jobs_task_created_idx on public.admin_development_execution_jobs(task_id, created_at desc);
create index if not exists admin_development_execution_jobs_status_queued_idx on public.admin_development_execution_jobs(status, queued_at) where status in ('queued', 'starting', 'running', 'cancel_requested');
create index if not exists admin_development_execution_events_job_created_idx on public.admin_development_execution_events(execution_job_id, created_at);
create index if not exists admin_development_execution_policy_job_evaluated_idx on public.admin_development_execution_policy_decisions(execution_job_id, evaluated_at desc);
create unique index if not exists admin_development_one_active_execution_per_task_idx
  on public.admin_development_execution_jobs(task_id)
  where status in ('requested', 'policy_check', 'queued', 'starting', 'running', 'cancel_requested');

create or replace function public.admin_development_execution_snapshot(p_task public.admin_development_tasks)
returns text language sql stable security definer set search_path = public as $$
  select encode(digest(concat_ws('|', p_task.execution_prompt, p_task.repository,
    p_task.base_branch, p_task.risk_level::text, p_task.status::text,
    p_task.human_approval_status::text, p_task.architecture_review_status::text,
    p_task.security_review_status::text, p_task.acceptance_notes), 'sha256'), 'hex')
$$;

create or replace function public.admin_development_mock_execution_enabled()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select is_enabled from public.admin_development_execution_configuration
    where provider = 'mock'
  ), false)
$$;

create or replace function public.admin_audit_development_execution_configuration()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_admin_email text;
begin
  if new.is_enabled is distinct from old.is_enabled then
    select email into v_admin_email from public.admin_users where admin_user_id = auth.uid();
    insert into public.admin_audit_log (
      admin_user_id, admin_email, target_resource_type, target_resource_id,
      action_type, result, next
    ) values (
      auth.uid(), v_admin_email, 'admin_development_execution_configuration', new.provider::text,
      'development.execution.configuration.updated', 'success',
      jsonb_build_object('provider', new.provider, 'is_enabled', new.is_enabled)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists admin_audit_development_execution_configuration on public.admin_development_execution_configuration;
create trigger admin_audit_development_execution_configuration
  after update on public.admin_development_execution_configuration
  for each row execute function public.admin_audit_development_execution_configuration();

create or replace function public.admin_record_development_execution_event(
  p_job_id uuid, p_task_id uuid, p_event_type text,
  p_previous public.development_execution_status,
  p_new public.development_execution_status,
  p_actor_type public.development_execution_actor_type,
  p_actor_user_id uuid, p_summary text, p_metadata jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.admin_development_execution_events (
    execution_job_id, task_id, event_type, previous_status, new_status,
    actor_type, actor_user_id, summary, metadata
  ) values (
    p_job_id, p_task_id, p_event_type, p_previous, p_new,
    p_actor_type, p_actor_user_id, p_summary, p_metadata
  );
end;
$$;

create or replace function public.admin_audit_development_execution(
  p_action text, p_task_id uuid, p_job_id uuid,
  p_provider public.development_execution_provider,
  p_status public.development_execution_status,
  p_decision public.development_execution_policy_decision default null,
  p_failure_code text default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_admin_email text;
begin
  select email into v_admin_email from public.admin_users where admin_user_id = auth.uid();
  insert into public.admin_audit_log (
    admin_user_id, admin_email, target_resource_type, target_resource_id,
    action_type, result, next
  ) values (
    auth.uid(), v_admin_email, 'admin_development_execution_jobs', p_job_id::text,
    p_action, 'success', jsonb_strip_nulls(jsonb_build_object(
      'task_id', p_task_id, 'execution_job_id', p_job_id, 'provider', p_provider,
      'status', p_status, 'policy_decision', p_decision, 'failure_code', p_failure_code
    ))
  );
end;
$$;

create or replace function public.admin_process_mock_development_execution(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_job public.admin_development_execution_jobs; v_task public.admin_development_tasks; v_current_snapshot text;
begin
  select * into v_job from public.admin_development_execution_jobs where id = p_job_id for update;
  if not found or v_job.status <> 'queued' then return; end if;
  select * into v_task from public.admin_development_tasks where id = v_job.task_id for update;
  v_current_snapshot := public.admin_development_execution_snapshot(v_task);
  if v_current_snapshot <> v_job.task_snapshot_hash then
    update public.admin_development_execution_jobs set status = 'failed', failed_at = now(), updated_at = now(), failure_code = 'stale_task_snapshot', failure_summary = 'Task changed after execution was requested.' where id = v_job.id;
    perform public.admin_record_development_execution_event(v_job.id, v_job.task_id, 'execution_failed', v_job.status, 'failed', 'dispatcher', auth.uid(), 'Mock execution rejected because the task snapshot changed.');
    perform public.admin_audit_development_execution('development.execution.failed', v_job.task_id, v_job.id, v_job.provider, 'failed', null, 'stale_task_snapshot');
    return;
  end if;
  update public.admin_development_execution_jobs set status = 'starting', started_at = now(), heartbeat_at = now(), updated_at = now() where id = v_job.id;
  perform public.admin_record_development_execution_event(v_job.id, v_job.task_id, 'execution_starting', 'queued', 'starting', 'dispatcher', auth.uid(), 'Mock execution is starting.');
  update public.admin_development_execution_jobs set status = 'running', heartbeat_at = now(), updated_at = now() where id = v_job.id;
  perform public.admin_record_development_execution_event(v_job.id, v_job.task_id, 'execution_running', 'starting', 'running', 'executor', auth.uid(), 'Mock execution is running.');
  if v_task.failure_summary = 'mock_execution_failure' then
    update public.admin_development_execution_jobs set status = 'failed', failed_at = now(), heartbeat_at = now(), updated_at = now(), failure_code = 'mock_execution_failed', failure_summary = 'Controlled mock execution failure.' where id = v_job.id;
    perform public.admin_record_development_execution_event(v_job.id, v_job.task_id, 'execution_failed', 'running', 'failed', 'executor', auth.uid(), 'Mock execution failed by controlled scenario.');
    perform public.admin_audit_development_execution('development.execution.failed', v_job.task_id, v_job.id, v_job.provider, 'failed', null, 'mock_execution_failed');
  else
    update public.admin_development_execution_jobs set status = 'succeeded', completed_at = now(), heartbeat_at = now(), updated_at = now(), provider_job_id = 'mock-' || substring(v_job.idempotency_key from 1 for 16), provider_run_reference = 'mock-run-' || substring(v_job.task_snapshot_hash from 1 for 16), result_summary = 'Mock execution completed. No code, repository, network, or provider action occurred.' where id = v_job.id;
    perform public.admin_record_development_execution_event(v_job.id, v_job.task_id, 'execution_succeeded', 'running', 'succeeded', 'executor', auth.uid(), 'Mock execution completed.');
    perform public.admin_audit_development_execution('development.execution.succeeded', v_job.task_id, v_job.id, v_job.provider, 'succeeded');
  end if;
end;
$$;

create or replace function public.admin_request_mock_development_execution(p_task_id uuid, p_retry boolean default false)
returns table(job_id uuid, job_key text, job_status public.development_execution_status, policy_decision public.development_execution_policy_decision, duplicate boolean)
language plpgsql security definer set search_path = public as $$
declare
  v_task public.admin_development_tasks; v_existing public.admin_development_execution_jobs;
  v_snapshot text; v_prompt_hash text; v_idempotency text; v_attempt smallint := 1;
  v_decision public.development_execution_policy_decision := 'deny'; v_reasons jsonb := '[]'::jsonb;
  v_job public.admin_development_execution_jobs;
begin
  if not public.is_active_admin() or public.current_admin_role() not in ('owner', 'admin') then
    raise exception 'development_execution_not_authorized';
  end if;
  select * into v_task from public.admin_development_tasks where id = p_task_id for update;
  if not found then raise exception 'task_not_found'; end if;
  select * into v_existing from public.admin_development_execution_jobs
    where task_id = p_task_id and status in ('requested', 'policy_check', 'queued', 'starting', 'running', 'cancel_requested')
    order by created_at desc limit 1;
  if found then
    return query select v_existing.id, v_existing.job_key, v_existing.status,
      coalesce((select decision from public.admin_development_execution_policy_decisions where execution_job_id = v_existing.id order by evaluated_at desc limit 1), 'deny'::public.development_execution_policy_decision), true;
    return;
  end if;
  if p_retry then
    select coalesce(max(attempt_number), 0)::smallint + 1 into v_attempt from public.admin_development_execution_jobs where task_id = p_task_id;
    if v_attempt > 3 then raise exception 'execution_retry_limit_reached'; end if;
  end if;
  v_snapshot := public.admin_development_execution_snapshot(v_task);
  v_prompt_hash := encode(digest(coalesce(v_task.execution_prompt, ''), 'sha256'), 'hex');
  v_idempotency := encode(digest(concat_ws('|', p_task_id::text, v_snapshot, 'mock', 'mock', v_attempt::text), 'sha256'), 'hex');
  select * into v_existing from public.admin_development_execution_jobs where task_id = p_task_id and idempotency_key = v_idempotency;
  if found then
    return query select v_existing.id, v_existing.job_key, v_existing.status,
      coalesce((select decision from public.admin_development_execution_policy_decisions where execution_job_id = v_existing.id order by evaluated_at desc limit 1), 'deny'::public.development_execution_policy_decision), true;
    return;
  end if;
  insert into public.admin_development_execution_jobs (
    task_id, job_key, requested_by, approved_execution_by, idempotency_key,
    task_snapshot_hash, execution_prompt_hash, repository, base_branch, attempt_number
  ) values (
    p_task_id, 'CVRUN-' || lpad(nextval('public.admin_development_execution_job_key_seq')::text, 6, '0'), auth.uid(),
    case when v_task.human_approval_status = 'approved' then v_task.approved_by else null end,
    v_idempotency, v_snapshot, v_prompt_hash, v_task.repository, v_task.base_branch, v_attempt
  ) returning * into v_job;
  perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'execution_requested', null, 'requested', 'admin', auth.uid(), 'Mock execution requested.');
  update public.admin_development_execution_jobs set status = 'policy_check', updated_at = now() where id = v_job.id;
  perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'policy_check_started', 'requested', 'policy_check', 'dispatcher', auth.uid(), 'Execution policy evaluation started.');
  if not public.admin_development_mock_execution_enabled() then
    v_reasons := jsonb_build_array('development_execution_disabled');
  elsif v_task.execution_prompt is null or btrim(v_task.execution_prompt) = '' then
    v_reasons := jsonb_build_array('task_not_eligible');
  elsif v_task.status in ('cancelled', 'completed', 'failed', 'blocked', 'draft') then
    v_reasons := jsonb_build_array('task_not_eligible');
  elsif v_task.risk_level = 'critical' then
    v_decision := 'manual_review_required'; v_reasons := jsonb_build_array('critical_execution_not_supported');
  elsif v_task.risk_level = 'low' and v_task.status in ('ready', 'awaiting_review', 'approved') then
    v_decision := 'allow'; v_reasons := jsonb_build_array('low_risk_mock_allowed');
  elsif v_task.risk_level = 'medium' and v_task.status = 'approved' and v_task.architecture_review_status = 'approved' then
    v_decision := 'allow'; v_reasons := jsonb_build_array('medium_risk_reviewed_mock_allowed');
  elsif v_task.risk_level = 'high' and v_task.status = 'approved'
    and v_task.human_approval_status = 'approved' and v_task.approved_by is not null and v_task.approved_at is not null
    and v_task.architecture_review_status = 'approved' and v_task.security_review_status = 'approved' then
    v_decision := 'allow'; v_reasons := jsonb_build_array('high_risk_owner_approved_mock_allowed');
  elsif v_task.risk_level = 'high' then
    v_reasons := jsonb_build_array('approval_required', 'security_review_required');
  else
    v_reasons := jsonb_build_array('task_not_eligible');
  end if;
  insert into public.admin_development_execution_policy_decisions (
    execution_job_id, task_id, decision, risk_level, task_status, human_approval_status,
    architecture_review_status, security_review_status, repository, base_branch, reasons
  ) values (
    v_job.id, p_task_id, v_decision, v_task.risk_level, v_task.status, v_task.human_approval_status,
    v_task.architecture_review_status, v_task.security_review_status, v_task.repository, v_task.base_branch, v_reasons
  );
  if v_decision <> 'allow' then
    update public.admin_development_execution_jobs set status = 'rejected', failed_at = now(), updated_at = now(), failure_code = v_reasons->>0, failure_summary = 'Execution policy did not allow this mock run.' where id = v_job.id;
    perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'policy_rejected', 'policy_check', 'rejected', 'dispatcher', auth.uid(), 'Execution policy rejected the mock run.', jsonb_build_object('decision', v_decision));
    perform public.admin_audit_development_execution('development.execution.rejected', p_task_id, v_job.id, 'mock', 'rejected', v_decision, v_reasons->>0);
  else
    update public.admin_development_execution_jobs set status = 'queued', queued_at = now(), updated_at = now() where id = v_job.id;
    perform public.admin_record_development_execution_event(v_job.id, p_task_id, 'execution_queued', 'policy_check', 'queued', 'dispatcher', auth.uid(), 'Mock execution queued.', jsonb_build_object('policy_version', 'phase_2_mock_v1'));
    perform public.admin_audit_development_execution('development.execution.queued', p_task_id, v_job.id, 'mock', 'queued', v_decision);
    perform public.admin_process_mock_development_execution(v_job.id);
  end if;
  select * into v_job from public.admin_development_execution_jobs where id = v_job.id;
  return query select v_job.id, v_job.job_key, v_job.status, v_decision, false;
end;
$$;

create or replace function public.admin_retry_mock_development_execution(p_task_id uuid)
returns table(job_id uuid, job_key text, job_status public.development_execution_status, policy_decision public.development_execution_policy_decision, duplicate boolean)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_admin() or public.current_admin_role() not in ('owner', 'admin') then
    raise exception 'development_execution_not_authorized';
  end if;
  return query select * from public.admin_request_mock_development_execution(p_task_id, true);
end;
$$;

create or replace function public.admin_cancel_development_execution(p_job_id uuid)
returns public.development_execution_status language plpgsql security definer set search_path = public as $$
declare v_job public.admin_development_execution_jobs;
begin
  if not public.is_active_admin() or public.current_admin_role() not in ('owner', 'admin') then raise exception 'development_execution_not_authorized'; end if;
  select * into v_job from public.admin_development_execution_jobs where id = p_job_id for update;
  if not found then raise exception 'execution_not_found'; end if;
  if v_job.status not in ('requested', 'policy_check', 'queued', 'starting', 'running', 'cancel_requested') then return v_job.status; end if;
  update public.admin_development_execution_jobs set status = 'cancel_requested', updated_at = now() where id = v_job.id;
  perform public.admin_record_development_execution_event(v_job.id, v_job.task_id, 'cancellation_requested', v_job.status, 'cancel_requested', 'admin', auth.uid(), 'Mock execution cancellation requested.');
  update public.admin_development_execution_jobs set status = 'cancelled', cancelled_at = now(), updated_at = now(), failure_code = 'execution_cancelled', failure_summary = 'Mock execution cancelled.' where id = v_job.id;
  perform public.admin_record_development_execution_event(v_job.id, v_job.task_id, 'execution_cancelled', 'cancel_requested', 'cancelled', 'dispatcher', auth.uid(), 'Mock execution cancelled.');
  perform public.admin_audit_development_execution('development.execution.cancelled', v_job.task_id, v_job.id, v_job.provider, 'cancelled', null, 'execution_cancelled');
  return 'cancelled';
end;
$$;

do $$ declare t text; begin
  foreach t in array array['admin_development_execution_jobs', 'admin_development_execution_events', 'admin_development_execution_policy_decisions', 'admin_development_execution_configuration'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
  end loop;
end $$;

grant select on table public.admin_development_execution_jobs, public.admin_development_execution_events, public.admin_development_execution_policy_decisions to authenticated;

create policy admin_development_execution_jobs_read on public.admin_development_execution_jobs for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin', 'compliance', 'read_only'));
create policy admin_development_execution_events_read on public.admin_development_execution_events for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin', 'compliance', 'read_only'));
create policy admin_development_execution_policy_read on public.admin_development_execution_policy_decisions for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin', 'compliance', 'read_only'));

revoke all on sequence public.admin_development_execution_job_key_seq from public, anon, authenticated;
revoke all on function public.admin_development_execution_snapshot(public.admin_development_tasks) from public, anon, authenticated;
revoke all on function public.admin_development_mock_execution_enabled() from public, anon, authenticated;
revoke all on function public.admin_audit_development_execution_configuration() from public, anon, authenticated;
revoke all on function public.admin_record_development_execution_event(uuid, uuid, text, public.development_execution_status, public.development_execution_status, public.development_execution_actor_type, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.admin_audit_development_execution(text, uuid, uuid, public.development_execution_provider, public.development_execution_status, public.development_execution_policy_decision, text) from public, anon, authenticated;
revoke all on function public.admin_process_mock_development_execution(uuid) from public, anon, authenticated;
revoke all on function public.admin_request_mock_development_execution(uuid, boolean) from public, anon;
revoke all on function public.admin_retry_mock_development_execution(uuid) from public, anon;
revoke all on function public.admin_cancel_development_execution(uuid) from public, anon;
grant execute on function public.admin_request_mock_development_execution(uuid, boolean) to authenticated;
grant execute on function public.admin_retry_mock_development_execution(uuid) to authenticated;
grant execute on function public.admin_cancel_development_execution(uuid) to authenticated;

commit;

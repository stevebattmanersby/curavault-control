-- CuraVault Control Site: Phase 4 trusted Codex worker boundary.
-- This migration adds no browser execution capability and no credentials. The
-- dedicated LOGIN/NOINHERIT worker role is a database authorization boundary; its
-- login credential must be provisioned only by the isolated worker host.

begin;

do $$ begin
  create role curavault_codex_worker login noinherit;
exception when duplicate_object then
  alter role curavault_codex_worker login noinherit;
end $$;
grant usage on schema public to curavault_codex_worker;

alter table public.admin_development_execution_jobs
  add column if not exists worker_id text check (worker_id is null or worker_id ~ '^[a-zA-Z0-9_.-]{1,80}$'),
  add column if not exists worker_lease_token_hash text check (worker_lease_token_hash is null or worker_lease_token_hash ~ '^[0-9a-f]{64}$'),
  add column if not exists worker_lease_acquired_at timestamptz,
  add column if not exists worker_last_heartbeat_at timestamptz,
  add column if not exists provider_model_id text check (provider_model_id is null or provider_model_id = 'gpt-5.3-codex'),
  add column if not exists execution_duration_ms integer check (execution_duration_ms is null or execution_duration_ms between 0 and 1800000);

do $$
declare v_constraint text;
begin
  select conname into v_constraint from pg_constraint
  where conrelid = 'public.admin_development_execution_jobs'::regclass
    and contype = 'c' and pg_get_constraintdef(oid) like '%codex_execution_authorization_stale%';
  if v_constraint is not null then
    execute format('alter table public.admin_development_execution_jobs drop constraint %I', v_constraint);
  end if;
end $$;

alter table public.admin_development_execution_jobs
  add constraint admin_development_execution_jobs_phase_4_failure_code_check check (
    failure_code is null or failure_code in (
      'development_execution_disabled', 'task_not_eligible', 'approval_required',
      'security_review_required', 'critical_execution_not_supported', 'stale_task_snapshot',
      'provider_not_allowed', 'execution_conflict', 'execution_cancelled',
      'mock_execution_failed', 'codex_execution_disabled', 'repository_not_allowed',
      'base_branch_not_allowed', 'base_sha_unresolved',
      'codex_execution_authorization_required', 'execution_output_policy_violation',
      'workspace_cleanup_failed', 'provider_timeout', 'provider_error',
      'provider_malformed_response', 'codex_concurrency_limit_reached',
      'codex_execution_authorization_stale', 'worker_lease_expired',
      'worker_lease_lost', 'worker_network_policy_not_verified'
    )
  );

create table if not exists public.admin_development_codex_worker_configuration (
  singleton boolean primary key default true check (singleton),
  live_execution_enabled boolean not null default false,
  fake_execution_enabled boolean not null default false,
  isolation_verified boolean not null default false,
  network_policy_verified boolean not null default false,
  repository_credential_verified boolean not null default false,
  provider_credential_verified boolean not null default false,
  monitoring_verified boolean not null default false,
  changed_by uuid references public.admin_users(admin_user_id) on delete restrict,
  updated_at timestamptz not null default now()
);
insert into public.admin_development_codex_worker_configuration(singleton) values (true) on conflict do nothing;

create table if not exists public.admin_development_codex_worker_status (
  worker_id text primary key check (worker_id ~ '^[a-zA-Z0-9_.-]{1,80}$'),
  last_poll_at timestamptz not null default now(),
  last_successful_poll_at timestamptz,
  active_job_count smallint not null default 0 check (active_job_count between 0 and 1),
  failure_count integer not null default 0 check (failure_count >= 0),
  updated_at timestamptz not null default now()
);

alter table public.admin_development_codex_worker_configuration enable row level security;
alter table public.admin_development_codex_worker_status enable row level security;
revoke all on table public.admin_development_codex_worker_configuration, public.admin_development_codex_worker_status from public, anon, authenticated;

create or replace function public.worker_require_codex_identity()
returns void language plpgsql security definer set search_path = public as $$
begin
  if session_user <> 'curavault_codex_worker' then
    raise exception 'trusted_worker_identity_required';
  end if;
end $$;

create or replace function public.worker_claim_codex_execution(p_worker_id text)
returns table(job_id uuid, lease_token text)
language plpgsql security definer set search_path = public as $$
declare v_job public.admin_development_execution_jobs; v_token text;
begin
  perform public.worker_require_codex_identity();
  if p_worker_id !~ '^[a-zA-Z0-9_.-]{1,80}$' then raise exception 'invalid_worker_id'; end if;
  if not public.admin_development_codex_execution_enabled() then return; end if;
  if not exists (select 1 from public.admin_development_codex_worker_configuration where singleton and (live_execution_enabled or fake_execution_enabled)) then return; end if;
  select j.* into v_job from public.admin_development_execution_jobs j
  join public.admin_development_tasks t on t.id = j.task_id
  join public.admin_development_execution_provider_configuration c on c.provider = 'codex'
  where j.provider = 'codex' and j.status = 'queued' and c.is_enabled
    and j.repository = c.allowed_repository and j.base_branch ~ c.allowed_base_branch_pattern
    and j.resolved_base_sha ~ '^[0-9a-f]{40,64}$'
    and j.task_snapshot_hash = public.admin_development_execution_snapshot(t)
    and j.provider_policy_version = c.policy_version
    and public.admin_development_codex_effective_risk(t) <> 'critical'
  order by j.queued_at for update skip locked limit 1;
  if not found then return; end if;
  v_token := encode(gen_random_bytes(32), 'hex');
  update public.admin_development_execution_jobs set status='starting', worker_id=p_worker_id,
    worker_lease_token_hash=encode(digest(v_token, 'sha256'), 'hex'), worker_lease_acquired_at=now(),
    worker_lease_expires_at=now()+interval '60 seconds', worker_last_heartbeat_at=now(), heartbeat_at=now(), started_at=coalesce(started_at, now()), updated_at=now()
  where id=v_job.id;
  insert into public.admin_development_codex_worker_status(worker_id,last_successful_poll_at,active_job_count)
  values(p_worker_id,now(),1) on conflict(worker_id) do update set last_poll_at=now(),last_successful_poll_at=now(),active_job_count=1,updated_at=now();
  perform public.admin_record_development_execution_event(v_job.id,v_job.task_id,'worker_claimed','queued','starting','executor',null,'Trusted worker claimed pinned Codex job.');
  return query select v_job.id,v_token;
end $$;

create or replace function public.worker_heartbeat_codex_execution(p_job_id uuid, p_lease_token text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_worker text;
begin
  perform public.worker_require_codex_identity();
  update public.admin_development_execution_jobs set worker_lease_expires_at=now()+interval '60 seconds', worker_last_heartbeat_at=now(), heartbeat_at=now(), updated_at=now()
  where id=p_job_id and provider='codex' and status in ('starting','running','cancel_requested')
    and worker_lease_token_hash=encode(digest(p_lease_token,'sha256'),'hex')
  returning worker_id into v_worker;
  if not found then return false; end if;
  update public.admin_development_codex_worker_status set last_poll_at=now(),last_successful_poll_at=now(),updated_at=now() where worker_id=v_worker;
  return true;
end $$;

create or replace function public.worker_get_codex_execution_context(p_job_id uuid, p_lease_token text)
returns table(task_id uuid, repository text, base_sha text, task_prompt text, acceptance_notes text, policy_version text, model_id text, max_runtime_seconds integer, cancellation_requested boolean)
language plpgsql security definer set search_path = public as $$
declare v_job public.admin_development_execution_jobs; v_task public.admin_development_tasks; v_config public.admin_development_execution_provider_configuration; v_authorization public.admin_development_codex_execution_authorizations;
begin
  perform public.worker_require_codex_identity();
  select * into v_job from public.admin_development_execution_jobs where id=p_job_id and provider='codex'
    and worker_lease_token_hash=encode(digest(p_lease_token,'sha256'),'hex') and worker_lease_expires_at > now() for update;
  if not found then raise exception 'worker_lease_lost'; end if;
  select * into v_task from public.admin_development_tasks where id=v_job.task_id;
  select * into v_config from public.admin_development_execution_provider_configuration where provider='codex';
  if not v_config.is_enabled then raise exception 'codex_execution_disabled'; end if;
  if v_job.repository <> v_config.allowed_repository or v_job.base_branch !~ v_config.allowed_base_branch_pattern or v_job.resolved_base_sha !~ '^[0-9a-f]{40,64}$' then raise exception 'execution_output_policy_violation'; end if;
  if v_job.task_snapshot_hash <> public.admin_development_execution_snapshot(v_task) or v_job.provider_policy_version <> v_config.policy_version then raise exception 'stale_task_snapshot'; end if;
  if public.admin_development_codex_effective_risk(v_task)='critical' then raise exception 'critical_execution_not_supported'; end if;
  if public.admin_development_codex_effective_risk(v_task)='high' then
    select * into v_authorization from public.admin_development_codex_execution_authorizations where task_id=v_task.id and revoked_at is null;
    if not found or v_authorization.task_snapshot_hash <> v_job.task_snapshot_hash
      or v_authorization.provider_policy_version <> v_config.policy_version
      or v_authorization.repository <> v_job.repository or v_authorization.base_branch <> v_job.base_branch then
      raise exception 'codex_execution_authorization_stale';
    end if;
  end if;
  return query select v_task.id,v_job.repository,v_job.resolved_base_sha,v_task.execution_prompt,v_task.acceptance_notes,v_config.policy_version,v_config.model_id,v_job.max_runtime_seconds,(v_job.status='cancel_requested');
end $$;

create or replace function public.worker_record_codex_provider_start(p_job_id uuid,p_lease_token text,p_provider_reference text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_task_id uuid;
begin
  perform public.worker_require_codex_identity();
  update public.admin_development_execution_jobs set status='running',provider_run_reference=left(p_provider_reference,240),provider_model_id='gpt-5.3-codex',heartbeat_at=now(),updated_at=now()
  where id=p_job_id and status='starting' and worker_lease_token_hash=encode(digest(p_lease_token,'sha256'),'hex') and worker_lease_expires_at>now() returning task_id into v_task_id;
  if not found then return false; end if;
  perform public.admin_record_development_execution_event(p_job_id,v_task_id,'provider_started','starting','running','executor',null,'Trusted worker started the configured provider.');
  return true;
end $$;

create or replace function public.worker_complete_codex_execution(p_job_id uuid,p_lease_token text,p_changed_paths jsonb,p_diff_sha256 text,p_tests_summary text,p_analyzer_summary text,p_cleanup_succeeded boolean,p_duration_ms integer)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_task_id uuid;
begin
  perform public.worker_require_codex_identity();
  if jsonb_typeof(p_changed_paths) <> 'array' or p_diff_sha256 !~ '^[0-9a-f]{64}$' or not p_cleanup_succeeded then raise exception 'execution_output_policy_violation'; end if;
  if exists(select 1 from jsonb_array_elements_text(p_changed_paths) path where path !~ '^(lib/|test/|docs/)[A-Za-z0-9_./-]+$' or path ~ '(^|/)(\.env|\.git|\.ssh)') then raise exception 'execution_output_policy_violation'; end if;
  update public.admin_development_execution_jobs set status='succeeded',completed_at=now(),changed_paths=p_changed_paths,diff_sha256=p_diff_sha256,tests_summary=left(p_tests_summary,1000),analyzer_summary=left(p_analyzer_summary,1000),cleanup_status='verified',execution_duration_ms=p_duration_ms,worker_lease_expires_at=null,updated_at=now()
  where id=p_job_id and status='running' and worker_lease_token_hash=encode(digest(p_lease_token,'sha256'),'hex') and worker_lease_expires_at>now() returning task_id into v_task_id;
  if not found then return false; end if;
  perform public.admin_record_development_execution_event(p_job_id,v_task_id,'execution_succeeded','running','succeeded','executor',null,'Trusted worker completed and cleaned up the isolated workspace.');
  return true;
end $$;

create or replace function public.worker_fail_codex_execution(p_job_id uuid,p_lease_token text,p_failure_code text,p_summary text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_task_id uuid;
begin
  perform public.worker_require_codex_identity();
  if p_failure_code not in ('provider_timeout','provider_error','provider_malformed_response','execution_output_policy_violation','workspace_cleanup_failed','worker_lease_lost','worker_network_policy_not_verified') then raise exception 'invalid_failure_code'; end if;
  update public.admin_development_execution_jobs set status=case when p_failure_code='provider_timeout' then 'timed_out'::public.development_execution_status else 'failed'::public.development_execution_status end,failed_at=now(),failure_code=p_failure_code,failure_summary=left(p_summary,1000),worker_lease_expires_at=null,updated_at=now()
  where id=p_job_id and status in ('starting','running','cancel_requested') and worker_lease_token_hash=encode(digest(p_lease_token,'sha256'),'hex') returning task_id into v_task_id;
  if not found then return false; end if;
  perform public.admin_record_development_execution_event(p_job_id,v_task_id,'execution_failed',null,'failed','executor',null,'Trusted worker recorded a bounded failure.');
  return true;
end $$;

create or replace function public.worker_refresh_repository_revision(p_repository text,p_base_branch text,p_resolved_base_sha text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform public.worker_require_codex_identity();
  if p_repository <> 'stevebattmanersby/curavult-app' or p_base_branch <> 'main' or p_resolved_base_sha !~ '^[0-9a-f]{40,64}$' then raise exception 'repository_not_allowed'; end if;
  insert into public.admin_development_repository_revisions(repository,base_branch,resolved_base_sha,resolved_at,resolved_by) values(p_repository,p_base_branch,p_resolved_base_sha,now(),'trusted_worker')
  on conflict(repository,base_branch) do update set resolved_base_sha=excluded.resolved_base_sha,resolved_at=excluded.resolved_at,resolved_by=excluded.resolved_by;
  return true;
end $$;

create or replace function public.admin_codex_live_execution_readiness()
returns table(provider_enabled boolean,worker_healthy boolean,repository_revision_fresh boolean,model_valid boolean,live_worker_gate_enabled boolean,isolation_verified boolean,network_policy_verified boolean,can_execute boolean)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_admin() or public.current_admin_role() not in ('owner','admin') then raise exception 'development_execution_not_authorized'; end if;
  return query select c.is_enabled,
    exists(select 1 from public.admin_development_codex_worker_status s where s.last_successful_poll_at>now()-interval '2 minutes'),
    exists(select 1 from public.admin_development_repository_revisions r where r.repository='stevebattmanersby/curavult-app' and r.base_branch='main' and r.resolved_at>now()-interval '15 minutes'),
    c.model_id='gpt-5.3-codex',w.live_execution_enabled,w.isolation_verified,w.network_policy_verified,
    c.is_enabled and w.live_execution_enabled and w.isolation_verified and w.network_policy_verified
      and w.repository_credential_verified and w.provider_credential_verified and w.monitoring_verified
      and c.model_id='gpt-5.3-codex'
      and exists(select 1 from public.admin_development_codex_worker_status s where s.last_successful_poll_at>now()-interval '2 minutes')
      and exists(select 1 from public.admin_development_repository_revisions r where r.repository='stevebattmanersby/curavult-app' and r.base_branch='main' and r.resolved_at>now()-interval '15 minutes')
  from public.admin_development_execution_provider_configuration c cross join public.admin_development_codex_worker_configuration w where c.provider='codex' and w.singleton;
end $$;

revoke all on function public.worker_require_codex_identity() from public,anon,authenticated;
revoke all on function public.worker_claim_codex_execution(text), public.worker_heartbeat_codex_execution(uuid,text), public.worker_get_codex_execution_context(uuid,text), public.worker_record_codex_provider_start(uuid,text,text), public.worker_complete_codex_execution(uuid,text,jsonb,text,text,text,boolean,integer), public.worker_fail_codex_execution(uuid,text,text,text), public.worker_refresh_repository_revision(text,text,text) from public,anon,authenticated;
grant execute on function public.worker_claim_codex_execution(text), public.worker_heartbeat_codex_execution(uuid,text), public.worker_get_codex_execution_context(uuid,text), public.worker_record_codex_provider_start(uuid,text,text), public.worker_complete_codex_execution(uuid,text,jsonb,text,text,text,boolean,integer), public.worker_fail_codex_execution(uuid,text,text,text), public.worker_refresh_repository_revision(text,text,text) to curavault_codex_worker;
revoke all on function public.admin_codex_live_execution_readiness() from public,anon;
grant execute on function public.admin_codex_live_execution_readiness() to authenticated;

commit;

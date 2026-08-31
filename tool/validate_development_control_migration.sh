#!/usr/bin/env bash
set -euo pipefail

psql_cmd=(psql -X -v ON_ERROR_STOP=1)

run_sql() {
  "${psql_cmd[@]}" "$@"
}

expect_rejected() {
  local label="$1"
  local sql="$2"
  if run_sql -c "$sql" >/dev/null 2>&1; then
    echo "Expected rejection was accepted: $label" >&2
    exit 1
  fi
  echo "Rejected as expected: $label"
}

assert_count() {
  local label="$1"
  local expected="$2"
  local sql="$3"
  local actual
  actual="$(run_sql -tA -c "$sql" | tail -n 1)"
  if [[ "$actual" != "$expected" ]]; then
    echo "$label expected $expected, got $actual" >&2
    exit 1
  fi
}

run_sql <<'SQL'
create schema auth;
create table auth.users (id uuid primary key, email text);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create role anon nologin;
create role authenticated nologin;
grant usage on schema public, auth to anon, authenticated;
SQL

run_sql -f supabase/migrations/20260612230013_20260612_create_control_site_admin_tables.sql
run_sql -f supabase/migrations/20260830213000_development_control_plane_phase_1.sql
run_sql -f supabase/migrations/20260831090000_development_execution_dispatcher_phase_2.sql

run_sql <<'SQL'
do $$
declare table_count integer; rls_count integer; policy_count integer; index_count integer;
begin
  select count(*) into table_count from pg_class where relnamespace = 'public'::regnamespace and relname = any(array['admin_development_tasks','admin_development_task_events','admin_development_prompt_templates','admin_development_reviews','admin_development_checks','admin_releases']);
  select count(*) into rls_count from pg_class where relnamespace = 'public'::regnamespace and relname = any(array['admin_development_tasks','admin_development_task_events','admin_development_prompt_templates','admin_development_reviews','admin_development_checks','admin_releases']) and relrowsecurity;
  select count(*) into policy_count from pg_policies where schemaname = 'public' and tablename = any(array['admin_development_tasks','admin_development_task_events','admin_development_prompt_templates','admin_development_reviews','admin_development_checks','admin_releases']);
  select count(*) into index_count from pg_indexes where schemaname = 'public' and indexname in ('admin_development_tasks_status_updated_idx','admin_development_tasks_risk_updated_idx','admin_development_tasks_repository_updated_idx','admin_development_events_task_created_idx','admin_development_reviews_task_type_idx','admin_development_checks_task_status_idx','admin_releases_status_created_idx');
  if table_count <> 6 or rls_count <> 6 or policy_count <> 15 or index_count <> 7 or to_regclass('public.admin_development_task_key_seq') is null then
    raise exception 'development control schema assets are incomplete';
  end if;
end $$;

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'admin@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'compliance@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'readonly@example.test'),
  ('55555555-5555-5555-5555-555555555555', 'support@example.test'),
  ('66666666-6666-6666-6666-666666666666', 'billing@example.test');
insert into public.admin_users (admin_user_id, email, role, is_active) values
  ('11111111-1111-1111-1111-111111111111', 'owner@example.test', 'owner', true),
  ('22222222-2222-2222-2222-222222222222', 'admin@example.test', 'admin', true),
  ('33333333-3333-3333-3333-333333333333', 'compliance@example.test', 'compliance', true),
  ('44444444-4444-4444-4444-444444444444', 'readonly@example.test', 'read_only', true),
  ('55555555-5555-5555-5555-555555555555', 'support@example.test', 'support', true),
  ('66666666-6666-6666-6666-666666666666', 'billing@example.test', 'billing', true);
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
insert into public.admin_development_tasks (title, original_product_request, risk_level) values
  ('Synthetic task one', 'Synthetic request one', 'medium'),
  ('Synthetic task two', 'Synthetic request two', 'high');
reset role;
SQL

run_sql <<'SQL'
do $$
declare task_count integer; distinct_keys integer; bad_keys integer; event_count integer;
begin
  select count(*), count(distinct task_key), count(*) filter (where task_key !~ '^CVDEV-[0-9]{6}$') into task_count, distinct_keys, bad_keys from public.admin_development_tasks;
  select count(*) into event_count from public.admin_development_task_events where event_type = 'task_created';
  if task_count <> 2 or distinct_keys <> 2 or bad_keys <> 0 or event_count <> 2 then
    raise exception 'task key or task event invariant failed';
  end if;
end $$;
SQL

expect_rejected 'admin status approved without human approval' "set role authenticated; select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false); update public.admin_development_tasks set status = 'approved' where title = 'Synthetic task one';"
expect_rejected 'admin human approval' "set role authenticated; select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false); update public.admin_development_tasks set human_approval_status = 'approved' where title = 'Synthetic task one';"
expect_rejected 'admin manual attribution' "set role authenticated; select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false); update public.admin_development_tasks set approved_by = '22222222-2222-2222-2222-222222222222' where title = 'Synthetic task one';"
expect_rejected 'high completion without approval' "set role authenticated; select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false); update public.admin_development_tasks set status = 'completed' where title = 'Synthetic task two';"

run_sql <<'SQL'
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
update public.admin_development_tasks set human_approval_status = 'approved', status = 'approved' where title = 'Synthetic task two';
reset role;
do $$
declare audit_bad integer; delete_privilege boolean; helper_execute boolean; attributed uuid; approved_at_value timestamptz;
begin
  select approved_by, approved_at into attributed, approved_at_value from public.admin_development_tasks where title = 'Synthetic task two';
  if attributed <> '11111111-1111-1111-1111-111111111111'::uuid or approved_at_value is null then raise exception 'owner approval attribution failed'; end if;
  select count(*) into audit_bad from public.admin_audit_log where action_type like 'development.%' and ((prev::text ilike '%Synthetic request%' or next::text ilike '%Synthetic request%') or (prev::text ilike '%execution_prompt%' or next::text ilike '%execution_prompt%'));
  if audit_bad <> 0 then raise exception 'audit leaked protected task content'; end if;
  select has_table_privilege('authenticated', 'public.admin_development_tasks', 'delete') into delete_privilege;
  select has_function_privilege('authenticated', 'public.admin_guard_development_approval()', 'execute') into helper_execute;
  if delete_privilege or helper_execute then raise exception 'unexpected delete or helper execute privilege'; end if;
end $$;
SQL

assert_count 'compliance task visibility' 0 "set role authenticated; select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); select count(*) from public.admin_development_tasks;"
assert_count 'compliance evidence visibility' 3 "set role authenticated; select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); select count(*) from public.admin_development_task_events;"
assert_count 'readonly evidence visibility' 3 "set role authenticated; select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false); select count(*) from public.admin_development_task_events;"
assert_count 'support evidence visibility' 0 "set role authenticated; select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false); select count(*) from public.admin_development_task_events;"
assert_count 'billing evidence visibility' 0 "set role authenticated; select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666666', false); select count(*) from public.admin_development_task_events;"
expect_rejected 'anon evidence read' "set role anon; select count(*) from public.admin_development_task_events;"

run_sql <<'SQL'
do $$
declare table_count integer; rls_count integer; active_index boolean; anon_execute boolean; direct_update boolean; provider_values text[];
begin
  select count(*) into table_count from pg_class where relnamespace = 'public'::regnamespace and relname = any(array['admin_development_execution_jobs','admin_development_execution_events','admin_development_execution_policy_decisions','admin_development_execution_configuration']);
  select count(*) into rls_count from pg_class where relnamespace = 'public'::regnamespace and relname = any(array['admin_development_execution_jobs','admin_development_execution_events','admin_development_execution_policy_decisions','admin_development_execution_configuration']) and relrowsecurity;
  select exists(select 1 from pg_indexes where schemaname = 'public' and indexname = 'admin_development_one_active_execution_per_task_idx') into active_index;
  select has_function_privilege('anon', 'public.admin_request_mock_development_execution(uuid, boolean)', 'execute') into anon_execute;
  select has_table_privilege('authenticated', 'public.admin_development_execution_configuration', 'update') into direct_update;
  select array_agg(enumlabel order by enumsortorder) into provider_values from pg_enum where enumtypid = 'public.development_execution_provider'::regtype;
  if table_count <> 4 or rls_count <> 4 or not active_index or anon_execute or direct_update or provider_values <> array['mock'] then
    raise exception 'phase 2 execution schema security assets are incomplete';
  end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
update public.admin_development_tasks
  set execution_prompt = 'Synthetic mock-only task',
      architecture_review_status = 'approved',
      human_approval_status = 'approved',
      status = 'approved'
  where title = 'Synthetic task one';

-- The default server-side gate is closed, so the first request is durable
-- evidence of a rejection rather than an execution.
select job_status from public.admin_request_mock_development_execution(
  (select id from public.admin_development_tasks where title = 'Synthetic task one'));
reset role;
do $$
begin
  if (select status from public.admin_development_execution_jobs order by created_at limit 1) <> 'rejected' then
    raise exception 'disabled execution gate did not reject mock run';
  end if;
end $$;
SQL

expect_rejected 'owner direct mock enable' "set role authenticated; select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false); update public.admin_development_execution_configuration set is_enabled = true where provider = 'mock';"
expect_rejected 'admin direct mock enable' "set role authenticated; select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false); update public.admin_development_execution_configuration set is_enabled = true where provider = 'mock';"
expect_rejected 'compliance direct mock enable' "set role authenticated; select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); update public.admin_development_execution_configuration set is_enabled = true where provider = 'mock';"
expect_rejected 'readonly direct mock enable' "set role authenticated; select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false); update public.admin_development_execution_configuration set is_enabled = true where provider = 'mock';"
expect_rejected 'support direct mock enable' "set role authenticated; select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false); update public.admin_development_execution_configuration set is_enabled = true where provider = 'mock';"
expect_rejected 'billing direct mock enable' "set role authenticated; select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666666', false); update public.admin_development_execution_configuration set is_enabled = true where provider = 'mock';"

run_sql <<'SQL'
-- This is privileged disposable-database setup, not a browser/API path.
update public.admin_development_execution_configuration set is_enabled = true where provider = 'mock';
do $$
begin
  if (select count(*) from public.admin_development_execution_configuration where provider = 'mock' and is_enabled) <> 1 then
    raise exception 'privileged mock enablement did not persist';
  end if;
  if (select count(*) from public.admin_audit_log where action_type = 'development.execution.configuration.updated' and next @> '{"provider":"mock","is_enabled":true}'::jsonb) <> 1 then
    raise exception 'mock configuration update was not audited';
  end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
insert into public.admin_development_tasks (title, original_product_request, risk_level)
values ('Synthetic concurrency task', 'Synthetic concurrency request', 'medium');
update public.admin_development_tasks
  set execution_prompt = 'Synthetic concurrent mock-only task',
      architecture_review_status = 'approved',
      human_approval_status = 'approved',
      status = 'approved'
  where title = 'Synthetic concurrency task';
select job_status from public.admin_request_mock_development_execution(
  (select id from public.admin_development_tasks where title = 'Synthetic task one'), true);
reset role;
do $$
declare success_count integer; event_count integer; prompt_leak integer; attempts smallint;
begin
  select count(*), max(attempt_number) into success_count, attempts from public.admin_development_execution_jobs where status = 'succeeded';
  select count(*) into event_count from public.admin_development_execution_events where event_type in ('execution_requested', 'policy_check_started', 'execution_queued', 'execution_starting', 'execution_running', 'execution_succeeded');
  select count(*) into prompt_leak from public.admin_audit_log where next::text ilike '%Synthetic mock-only task%';
  if success_count <> 1 or attempts <> 2 or event_count <> 8 or prompt_leak <> 0 then
    raise exception 'mock lifecycle, bounded retry, or prompt isolation invariant failed';
  end if;
end $$;
SQL

# Two independent authenticated sessions request the same eligible task. The
# task row lock plus deterministic idempotency key must leave exactly one job.
(
  run_sql -c "set role authenticated; select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false); select * from public.admin_request_mock_development_execution((select id from public.admin_development_tasks where title = 'Synthetic concurrency task'), false);" >/dev/null
) & first_request=$!
(
  run_sql -c "set role authenticated; select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false); select * from public.admin_request_mock_development_execution((select id from public.admin_development_tasks where title = 'Synthetic concurrency task'), false);" >/dev/null
) & second_request=$!
wait "$first_request"
wait "$second_request"

run_sql <<'SQL'
do $$
declare job_count integer; active_count integer;
begin
  select count(*) into job_count from public.admin_development_execution_jobs
    where task_id = (select id from public.admin_development_tasks where title = 'Synthetic concurrency task');
  select count(*) into active_count from public.admin_development_execution_jobs
    where task_id = (select id from public.admin_development_tasks where title = 'Synthetic concurrency task')
      and status in ('requested', 'policy_check', 'queued', 'starting', 'running', 'cancel_requested');
  if job_count <> 1 or active_count <> 0 then
    raise exception 'concurrent mock requests were not idempotent';
  end if;
end $$;
SQL

assert_count 'compliance execution evidence visibility' 3 "set role authenticated; select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); select count(*) from public.admin_development_execution_jobs;"
assert_count 'support execution evidence visibility' 0 "set role authenticated; select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false); select count(*) from public.admin_development_execution_jobs;"
expect_rejected 'anon mock execution request' "set role anon; select * from public.admin_request_mock_development_execution('11111111-1111-1111-1111-111111111111', false);"

echo 'Development Control Phase 1 and Phase 2 migration validation passed.'

run_sql -f supabase/migrations/20260831100000_development_codex_provider_phase_3.sql

run_sql <<'SQL'
do $$
declare provider_values text[]; executor_values text[]; table_count integer; codex_default boolean;
begin
  select array_agg(enumlabel order by enumsortorder) into provider_values
    from pg_enum where enumtypid = 'public.development_execution_provider'::regtype;
  select array_agg(enumlabel order by enumsortorder) into executor_values
    from pg_enum where enumtypid = 'public.development_executor_mode'::regtype;
  select count(*) into table_count from pg_class where relnamespace = 'public'::regnamespace
    and relname = any(array['admin_development_execution_provider_configuration','admin_development_repository_revisions','admin_development_codex_execution_authorizations']);
  select is_enabled into codex_default from public.admin_development_execution_provider_configuration where provider = 'codex';
  if provider_values <> array['mock','codex'] or executor_values <> array['mock','codex']
    or table_count <> 3 or codex_default then
    raise exception 'phase 3 provider configuration is incomplete or enabled by default';
  end if;
end $$;
SQL

expect_rejected 'owner direct Codex configuration read' "set role authenticated; select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false); select * from public.admin_development_execution_provider_configuration;"
expect_rejected 'owner direct Codex configuration enable' "set role authenticated; select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false); update public.admin_development_execution_provider_configuration set is_enabled = true where provider = 'codex';"
expect_rejected 'admin direct Codex configuration enable' "set role authenticated; select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false); update public.admin_development_execution_provider_configuration set is_enabled = true where provider = 'codex';"
expect_rejected 'compliance direct Codex configuration enable' "set role authenticated; select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false); update public.admin_development_execution_provider_configuration set is_enabled = true where provider = 'codex';"
expect_rejected 'readonly direct Codex configuration enable' "set role authenticated; select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false); update public.admin_development_execution_provider_configuration set is_enabled = true where provider = 'codex';"
expect_rejected 'support direct Codex configuration enable' "set role authenticated; select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false); update public.admin_development_execution_provider_configuration set is_enabled = true where provider = 'codex';"
expect_rejected 'billing direct Codex configuration enable' "set role authenticated; select set_config('request.jwt.claim.sub', '66666666-6666-6666-6666-666666666666', false); update public.admin_development_execution_provider_configuration set is_enabled = true where provider = 'codex';"

run_sql <<'SQL'
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
insert into public.admin_development_tasks (title, original_product_request, execution_prompt, risk_level, status)
values ('Synthetic Codex disabled task', 'Synthetic safe request', 'Synthetic safe Codex task', 'low', 'ready');
select job_status from public.admin_request_codex_development_execution(
  (select id from public.admin_development_tasks where title = 'Synthetic Codex disabled task'));
reset role;
do $$ begin
  if (select failure_code from public.admin_development_execution_jobs where provider = 'codex' order by created_at desc limit 1) <> 'codex_execution_disabled' then
    raise exception 'disabled Codex provider did not reject request';
  end if;
end $$;

-- Privileged disposable setup only. It proves mock and Codex gates are separate.
update public.admin_development_execution_configuration set is_enabled = true where provider = 'mock';
update public.admin_development_execution_provider_configuration set is_enabled = true where provider = 'codex';
insert into public.admin_development_repository_revisions (repository, base_branch, resolved_base_sha)
values ('stevebattmanersby/curavult-app', 'main', repeat('a', 40));

set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
insert into public.admin_development_tasks (title, original_product_request, execution_prompt, risk_level, status, repository)
values ('Synthetic blocked repository task', 'Synthetic safe request', 'Synthetic safe Codex task', 'low', 'ready', 'other/blocked');
select job_status from public.admin_request_codex_development_execution(
  (select id from public.admin_development_tasks where title = 'Synthetic blocked repository task'));
insert into public.admin_development_tasks (title, original_product_request, execution_prompt, risk_level, status)
values ('Synthetic Critical Codex task', 'Synthetic safe request', 'Synthetic safe Codex task', 'critical', 'ready');
select job_status from public.admin_request_codex_development_execution(
  (select id from public.admin_development_tasks where title = 'Synthetic Critical Codex task'));
insert into public.admin_development_tasks (title, original_product_request, execution_prompt, risk_level, status)
values ('Synthetic High Codex task', 'Synthetic safe request', 'Synthetic safe Codex task', 'high', 'awaiting_approval');
update public.admin_development_tasks set architecture_review_status = 'approved', security_review_status = 'approved', human_approval_status = 'approved', status = 'approved'
  where title = 'Synthetic High Codex task';
select public.admin_authorize_codex_execution((select id from public.admin_development_tasks where title = 'Synthetic High Codex task'));
select job_status from public.admin_request_codex_development_execution(
  (select id from public.admin_development_tasks where title = 'Synthetic High Codex task'));
insert into public.admin_development_tasks (title, original_product_request, execution_prompt, risk_level, status)
values ('Synthetic protected Codex task', 'Synthetic safe request', 'Update supabase/migrations safely', 'low', 'ready');
select job_status from public.admin_request_codex_development_execution(
  (select id from public.admin_development_tasks where title = 'Synthetic protected Codex task'));
insert into public.admin_development_tasks (title, original_product_request, execution_prompt, risk_level, status)
values ('Synthetic concurrent Codex task', 'Synthetic safe request', 'Synthetic safe Codex task', 'high', 'awaiting_approval');
update public.admin_development_tasks set architecture_review_status = 'approved', security_review_status = 'approved', human_approval_status = 'approved', status = 'approved'
  where title = 'Synthetic concurrent Codex task';
select public.admin_authorize_codex_execution((select id from public.admin_development_tasks where title = 'Synthetic concurrent Codex task'));
select job_status from public.admin_request_codex_development_execution(
  (select id from public.admin_development_tasks where title = 'Synthetic concurrent Codex task'));
reset role;
do $$
begin
  if not exists (select 1 from public.admin_development_execution_jobs where provider = 'codex' and failure_code = 'repository_not_allowed') then
    raise exception 'repository allow-list did not reject';
  end if;
  if not exists (select 1 from public.admin_development_execution_jobs where provider = 'codex' and failure_code = 'critical_execution_not_supported') then
    raise exception 'critical Codex request was not denied';
  end if;
  if not exists (select 1 from public.admin_development_execution_jobs where provider = 'codex' and status = 'queued' and resolved_base_sha = repeat('a', 40)) then
    raise exception 'eligible high Codex request was not pinned and queued';
  end if;
  if not exists (select 1 from public.admin_development_execution_policy_decisions where effective_risk_level = 'high' and task_id = (select id from public.admin_development_tasks where title = 'Synthetic protected Codex task')) then
    raise exception 'protected scope did not escalate effective risk';
  end if;
  if not exists (select 1 from public.admin_development_execution_jobs where provider = 'codex' and failure_code = 'codex_concurrency_limit_reached') then
    raise exception 'global Codex concurrency limit did not reject a second job';
  end if;
  if (select count(*) from public.admin_development_execution_configuration where provider = 'mock' and is_enabled) <> 1 then
    raise exception 'Codex setup changed mock configuration';
  end if;
end $$;
SQL

expect_rejected 'anon Codex execution request' "set role anon; select * from public.admin_request_codex_development_execution('11111111-1111-1111-1111-111111111111');"
expect_rejected 'support Codex execution request' "set role authenticated; select set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false); select * from public.admin_request_codex_development_execution('11111111-1111-1111-1111-111111111111');"

echo 'Development Control Phase 3 Codex provider validation passed.'

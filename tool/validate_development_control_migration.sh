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

run_sql <<'SQL'
do $$
declare table_count integer; rls_count integer; policy_count integer; index_count integer;
begin
  select count(*) into table_count from pg_class where relnamespace = 'public'::regnamespace and relname = any(array['admin_development_tasks','admin_development_task_events','admin_development_prompt_templates','admin_development_reviews','admin_development_checks','admin_releases']);
  select count(*) into rls_count from pg_class where relnamespace = 'public'::regnamespace and relname = any(array['admin_development_tasks','admin_development_task_events','admin_development_prompt_templates','admin_development_reviews','admin_development_checks','admin_releases']) and relrowsecurity;
  select count(*) into policy_count from pg_policies where (schemaname = 'public' and tablename like 'admin_development%') or (schemaname = 'public' and tablename = 'admin_releases');
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

echo 'Development Control Phase 1 migration validation passed.'

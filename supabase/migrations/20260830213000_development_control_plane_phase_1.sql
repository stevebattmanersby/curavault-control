-- CuraVault Control Site: Development Control Plane, Phase 1.
-- This is administrative workflow metadata only. It must never store patient,
-- medical, credential, token, or execution-log content.

begin;

create extension if not exists pgcrypto;

do $$ begin
  create type public.development_risk_level as enum ('low', 'medium', 'high', 'critical');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_task_status as enum (
    'draft', 'ready', 'queued', 'in_progress', 'awaiting_ci', 'awaiting_review',
    'changes_requested', 'awaiting_approval', 'approved', 'completed', 'blocked', 'failed', 'cancelled'
  );
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_review_type as enum ('architecture', 'security', 'qa', 'release');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_review_decision as enum ('pending', 'approved', 'changes_requested', 'blocked');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_check_status as enum ('pending', 'running', 'passed', 'failed', 'skipped', 'cancelled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.development_release_status as enum ('planned', 'candidate', 'approved', 'released', 'cancelled');
exception when duplicate_object then null; end $$;

create sequence if not exists public.admin_development_task_key_seq;

create table if not exists public.admin_development_tasks (
  id uuid primary key default gen_random_uuid(),
  task_key text not null unique,
  title text not null check (char_length(title) between 3 and 240),
  original_product_request text not null check (char_length(original_product_request) <= 20000),
  execution_prompt text check (char_length(execution_prompt) <= 30000),
  acceptance_notes text check (char_length(acceptance_notes) <= 8000),
  task_type text not null default 'feature' check (task_type in ('bug_fix', 'feature', 'ui_ux', 'security', 'migration', 'release', 'test', 'documentation', 'other')),
  repository text not null default 'stevebattmanersby/curavult-app' check (repository ~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'),
  base_branch text not null default 'main' check (char_length(base_branch) <= 160),
  working_branch text check (char_length(working_branch) <= 160),
  risk_level public.development_risk_level not null default 'medium',
  status public.development_task_status not null default 'draft',
  priority smallint not null default 3 check (priority between 1 and 5),
  requested_by uuid not null references public.admin_users(admin_user_id) on delete restrict,
  approved_by uuid references public.admin_users(admin_user_id) on delete restrict,
  approved_at timestamptz,
  architecture_review_status public.development_review_decision not null default 'pending',
  security_review_status public.development_review_decision not null default 'pending',
  human_approval_status public.development_review_decision not null default 'pending',
  github_issue_number integer check (github_issue_number > 0),
  github_issue_url text check (github_issue_url is null or github_issue_url ~ '^https://github\\.com/'),
  github_pr_number integer check (github_pr_number > 0),
  github_pr_url text check (github_pr_url is null or github_pr_url ~ '^https://github\\.com/'),
  github_commit_sha text check (github_commit_sha is null or github_commit_sha ~ '^[0-9a-fA-F]{7,64}$'),
  release_reference text check (char_length(release_reference) <= 160),
  manual_testing_required boolean not null default true,
  blocker_summary text check (char_length(blocker_summary) <= 4000),
  failure_summary text check (char_length(failure_summary) <= 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  cancelled_at timestamptz,
  check ((approved_by is null) = (approved_at is null))
);

create table if not exists public.admin_development_task_events (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.admin_development_tasks(id) on delete restrict,
  event_type text not null check (char_length(event_type) <= 80),
  previous_status public.development_task_status,
  new_status public.development_task_status,
  actor_user_id uuid not null references public.admin_users(admin_user_id) on delete restrict,
  summary text not null check (char_length(summary) <= 2000),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create table if not exists public.admin_development_prompt_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 3 and 160),
  description text check (char_length(description) <= 2000),
  category text not null default 'general' check (char_length(category) <= 80),
  prompt_template text not null check (char_length(prompt_template) <= 30000),
  default_risk_level public.development_risk_level not null default 'medium',
  is_active boolean not null default true,
  version integer not null default 1 check (version > 0),
  created_by uuid not null references public.admin_users(admin_user_id) on delete restrict,
  updated_by uuid not null references public.admin_users(admin_user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(name, version)
);

create table if not exists public.admin_development_reviews (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.admin_development_tasks(id) on delete restrict,
  review_type public.development_review_type not null,
  reviewer_user_id uuid not null references public.admin_users(admin_user_id) on delete restrict,
  decision public.development_review_decision not null default 'pending',
  summary text check (char_length(summary) <= 6000),
  findings jsonb not null default '[]'::jsonb check (jsonb_typeof(findings) = 'array'),
  created_at timestamptz not null default now()
);

create table if not exists public.admin_development_checks (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.admin_development_tasks(id) on delete restrict,
  check_type text not null check (char_length(check_type) <= 80),
  provider text not null default 'manual' check (char_length(provider) <= 80),
  name text not null check (char_length(name) <= 240),
  status public.development_check_status not null default 'pending',
  external_url text check (external_url is null or external_url ~ '^https://'),
  external_id text check (char_length(external_id) <= 240),
  commit_sha text check (commit_sha is null or commit_sha ~ '^[0-9a-fA-F]{7,64}$'),
  summary text check (char_length(summary) <= 4000),
  started_at timestamptz,
  completed_at timestamptz,
  recorded_at timestamptz not null default now()
);

create table if not exists public.admin_releases (
  id uuid primary key default gen_random_uuid(),
  release_name text not null unique check (char_length(release_name) <= 160),
  version_name text check (char_length(version_name) <= 80),
  build_number text check (char_length(build_number) <= 80),
  platform text not null check (platform in ('android', 'ios', 'web', 'backend', 'multi_platform')),
  branch text check (char_length(branch) <= 160),
  commit_sha text check (commit_sha is null or commit_sha ~ '^[0-9a-fA-F]{7,64}$'),
  status public.development_release_status not null default 'planned',
  notes text check (char_length(notes) <= 6000),
  created_by uuid not null references public.admin_users(admin_user_id) on delete restrict,
  approved_by uuid references public.admin_users(admin_user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  released_at timestamptz
);

create index if not exists admin_development_tasks_status_updated_idx on public.admin_development_tasks(status, updated_at desc);
create index if not exists admin_development_tasks_risk_updated_idx on public.admin_development_tasks(risk_level, updated_at desc);
create index if not exists admin_development_tasks_repository_updated_idx on public.admin_development_tasks(repository, updated_at desc);
create index if not exists admin_development_events_task_created_idx on public.admin_development_task_events(task_id, created_at desc);
create index if not exists admin_development_reviews_task_type_idx on public.admin_development_reviews(task_id, review_type, created_at desc);
create index if not exists admin_development_checks_task_status_idx on public.admin_development_checks(task_id, status, recorded_at desc);
create index if not exists admin_releases_status_created_idx on public.admin_releases(status, created_at desc);

create or replace function public.admin_assign_development_fields()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_active_admin() then
    raise exception 'development control write access denied';
  end if;
  if tg_table_name = 'admin_development_reviews' then
    if public.current_admin_role() not in ('owner', 'admin')
       and not (public.current_admin_role() = 'compliance' and new.review_type = 'security') then
      raise exception 'development control write access denied';
    end if;
  elsif public.current_admin_role() not in ('owner', 'admin') then
    raise exception 'development control write access denied';
  end if;
  if tg_table_name = 'admin_development_tasks' and tg_op = 'INSERT' then
    new.task_key := 'CVDEV-' || lpad(nextval('public.admin_development_task_key_seq')::text, 6, '0');
    new.requested_by := auth.uid();
  end if;
  if tg_table_name = 'admin_development_task_events' and tg_op = 'INSERT' then new.actor_user_id := auth.uid(); end if;
  if tg_table_name = 'admin_development_prompt_templates' then
    if tg_op = 'INSERT' then new.created_by := auth.uid(); end if;
    new.updated_by := auth.uid();
  end if;
  if tg_table_name = 'admin_development_reviews' and tg_op = 'INSERT' then new.reviewer_user_id := auth.uid(); end if;
  if tg_table_name = 'admin_releases' and tg_op = 'INSERT' then new.created_by := auth.uid(); end if;
  if tg_table_name in ('admin_development_tasks', 'admin_development_prompt_templates', 'admin_releases') then new.updated_at := now(); end if;
  return new;
end;
$$;

create or replace function public.admin_guard_development_approval()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (new.approved_by is distinct from old.approved_by or new.approved_at is distinct from old.approved_at or new.human_approval_status is distinct from old.human_approval_status)
     and public.current_admin_role() <> 'owner' then
    raise exception 'owner approval required';
  end if;
  if new.risk_level in ('high', 'critical') and new.human_approval_status = 'approved' and new.approved_by is null then
    raise exception 'high-risk approval requires an authenticated owner';
  end if;
  if new.human_approval_status = 'approved' and new.approved_by is null then new.approved_by := auth.uid(); new.approved_at := now(); end if;
  return new;
end;
$$;

create or replace function public.admin_audit_development_mutation()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_id text; v_action text; v_admin_email text; v_prev jsonb; v_next jsonb;
begin
  if not public.is_active_admin() then raise exception 'not authorized'; end if;
  select email into v_admin_email from public.admin_users where admin_user_id = auth.uid();
  v_id := coalesce(to_jsonb(new)->>'id', to_jsonb(old)->>'id');
  v_action := 'development.' || tg_table_name || '.' || lower(tg_op);
  v_prev := case when tg_op = 'INSERT' then null else jsonb_build_object('status', to_jsonb(old)->>'status', 'risk_level', to_jsonb(old)->>'risk_level', 'is_active', to_jsonb(old)->>'is_active') end;
  v_next := case when tg_op = 'DELETE' then null else jsonb_build_object('task_key', to_jsonb(new)->>'task_key', 'status', to_jsonb(new)->>'status', 'risk_level', to_jsonb(new)->>'risk_level', 'is_active', to_jsonb(new)->>'is_active') end;
  insert into public.admin_audit_log(admin_user_id, admin_email, target_resource_type, target_resource_id, action_type, result, prev, next)
  values (auth.uid(), v_admin_email, tg_table_name, v_id, v_action, 'success', v_prev, v_next);
  return new;
end;
$$;

create or replace function public.admin_record_development_task_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.admin_development_task_events(task_id, event_type, previous_status, new_status, actor_user_id, summary)
  values (
    new.id,
    case when tg_op = 'INSERT' then 'task_created' else 'status_changed' end,
    case when tg_op = 'INSERT' then null else old.status end,
    new.status,
    auth.uid(),
    case when tg_op = 'INSERT' then 'Development task created.' else 'Task status updated.' end
  );
  return new;
end;
$$;

drop trigger if exists admin_assign_development_task_fields on public.admin_development_tasks;
create trigger admin_assign_development_task_fields before insert or update on public.admin_development_tasks for each row execute function public.admin_assign_development_fields();
drop trigger if exists admin_guard_development_task_approval on public.admin_development_tasks;
create trigger admin_guard_development_task_approval before update on public.admin_development_tasks for each row execute function public.admin_guard_development_approval();
drop trigger if exists admin_assign_development_event_fields on public.admin_development_task_events;
create trigger admin_assign_development_event_fields before insert on public.admin_development_task_events for each row execute function public.admin_assign_development_fields();
drop trigger if exists admin_assign_development_prompt_fields on public.admin_development_prompt_templates;
create trigger admin_assign_development_prompt_fields before insert or update on public.admin_development_prompt_templates for each row execute function public.admin_assign_development_fields();
drop trigger if exists admin_assign_development_review_fields on public.admin_development_reviews;
create trigger admin_assign_development_review_fields before insert on public.admin_development_reviews for each row execute function public.admin_assign_development_fields();
drop trigger if exists admin_assign_development_release_fields on public.admin_releases;
create trigger admin_assign_development_release_fields before insert or update on public.admin_releases for each row execute function public.admin_assign_development_fields();
drop trigger if exists admin_audit_development_task_mutation on public.admin_development_tasks;
create trigger admin_audit_development_task_mutation after insert or update on public.admin_development_tasks for each row execute function public.admin_audit_development_mutation();
drop trigger if exists admin_record_development_task_event on public.admin_development_tasks;
create trigger admin_record_development_task_event after insert or update of status on public.admin_development_tasks for each row execute function public.admin_record_development_task_event();
drop trigger if exists admin_audit_development_event_mutation on public.admin_development_task_events;
create trigger admin_audit_development_event_mutation after insert on public.admin_development_task_events for each row execute function public.admin_audit_development_mutation();
drop trigger if exists admin_audit_development_prompt_mutation on public.admin_development_prompt_templates;
create trigger admin_audit_development_prompt_mutation after insert or update on public.admin_development_prompt_templates for each row execute function public.admin_audit_development_mutation();
drop trigger if exists admin_audit_development_review_mutation on public.admin_development_reviews;
create trigger admin_audit_development_review_mutation after insert on public.admin_development_reviews for each row execute function public.admin_audit_development_mutation();
drop trigger if exists admin_audit_development_check_mutation on public.admin_development_checks;
create trigger admin_audit_development_check_mutation after insert or update on public.admin_development_checks for each row execute function public.admin_audit_development_mutation();
drop trigger if exists admin_audit_development_release_mutation on public.admin_releases;
create trigger admin_audit_development_release_mutation after insert or update on public.admin_releases for each row execute function public.admin_audit_development_mutation();

do $$ declare t text; begin
  foreach t in array array['admin_development_tasks', 'admin_development_task_events', 'admin_development_prompt_templates', 'admin_development_reviews', 'admin_development_checks', 'admin_releases'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon', t);
    execute format('grant select, insert, update on table public.%I to authenticated', t);
  end loop;
end $$;

create policy admin_development_tasks_read on public.admin_development_tasks for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_development_prompts_read on public.admin_development_prompt_templates for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_development_events_read on public.admin_development_task_events for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin', 'compliance', 'read_only'));
create policy admin_development_reviews_read on public.admin_development_reviews for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin', 'compliance', 'read_only'));
create policy admin_development_checks_read on public.admin_development_checks for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin', 'compliance', 'read_only'));
create policy admin_releases_read on public.admin_releases for select to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin', 'compliance', 'read_only'));

create policy admin_development_tasks_write on public.admin_development_tasks for insert to authenticated with check (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_development_tasks_update on public.admin_development_tasks for update to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin')) with check (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_development_events_write on public.admin_development_task_events for insert to authenticated with check (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_development_prompts_write on public.admin_development_prompt_templates for all to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin')) with check (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_development_reviews_write on public.admin_development_reviews for insert to authenticated with check (public.is_active_admin() and (public.current_admin_role() in ('owner', 'admin') or (public.current_admin_role() = 'compliance' and review_type = 'security')));
create policy admin_development_checks_write on public.admin_development_checks for insert to authenticated with check (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_development_checks_update on public.admin_development_checks for update to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin')) with check (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_releases_write on public.admin_releases for insert to authenticated with check (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));
create policy admin_releases_update on public.admin_releases for update to authenticated using (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin')) with check (public.is_active_admin() and public.current_admin_role() in ('owner', 'admin'));

revoke all on sequence public.admin_development_task_key_seq from public, anon, authenticated;
revoke all on function public.admin_assign_development_fields() from public, anon, authenticated;
revoke all on function public.admin_guard_development_approval() from public, anon, authenticated;
revoke all on function public.admin_audit_development_mutation() from public, anon, authenticated;
revoke all on function public.admin_record_development_task_event() from public, anon, authenticated;

commit;

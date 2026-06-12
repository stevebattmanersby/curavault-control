-- CuraVault Control Site (Internal Admin) schema
-- IMPORTANT PRIVACY RULE:
--   This migration ONLY creates admin/control tables.
--   It does NOT modify, reference, or expose consumer health tables.
--
-- Assumptions:
--   - You use Supabase Auth (auth.users).
--   - Admins are a subset of auth users, represented in public.admin_users.
--   - Admin privileges are enforced via RLS that checks admin_users for the logged-in auth.uid().

begin;

-- Extensions
create extension if not exists pgcrypto;

-- ==========================================================
-- Updated-at trigger
-- ==========================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ==========================================================
-- Admin role model
-- ==========================================================
do $$
begin
  if not exists (select 1 from pg_type where typname = 'admin_role') then
    create type public.admin_role as enum (
      'owner',
      'admin',
      'support',
      'billing',
      'compliance',
      'read_only'
    );
  end if;
end $$;

-- ==========================================================
-- Admin users (profile + access control)
-- ==========================================================
create table if not exists public.admin_users (
  admin_user_id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name text,
  role public.admin_role not null default 'read_only',
  is_active boolean not null default true,
  -- Optional: require step-up (re-auth) for sensitive changes
  require_step_up boolean not null default true,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists admin_users_role_idx on public.admin_users (role);
create index if not exists admin_users_is_active_idx on public.admin_users (is_active);

drop trigger if exists set_updated_at_admin_users on public.admin_users;
create trigger set_updated_at_admin_users
before update on public.admin_users
for each row execute function public.set_updated_at();

-- ==========================================================
-- Helper functions for RLS checks
-- ==========================================================
-- NOTE: security definer so it can read admin_users regardless of RLS.
-- It only returns booleans; do not expose any sensitive columns.
create or replace function public.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.admin_users au
    where au.admin_user_id = auth.uid()
      and au.is_active = true
  );
$$;

create or replace function public.current_admin_role()
returns public.admin_role
language sql
stable
security definer
set search_path = public
as $$
  select au.role
  from public.admin_users au
  where au.admin_user_id = auth.uid()
    and au.is_active = true
  limit 1;
$$;

-- ==========================================================
-- Admin audit log (mandatory for all changes)
-- ==========================================================
-- Stores only metadata/redacted diffs. Do NOT store health data, document titles,
-- prompts, responses, or any free-text that could contain PHI.
create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  -- Actor
  admin_user_id uuid references public.admin_users (admin_user_id) on delete set null,
  admin_email text,

  -- Target (optional)
  target_user_id uuid,
  target_resource_type text,
  target_resource_id text,

  -- What happened
  action_type text not null,
  result text not null default 'success', -- e.g. success|failure|denied

  -- Redacted before/after
  prev jsonb,
  next jsonb,

  -- Optional metadata
  reason text,
  ticket_id text,

  -- Client context
  ip inet,
  user_agent text
);

create index if not exists admin_audit_log_created_at_idx on public.admin_audit_log (created_at desc);
create index if not exists admin_audit_log_action_type_idx on public.admin_audit_log (action_type);
create index if not exists admin_audit_log_target_user_idx on public.admin_audit_log (target_user_id);
create index if not exists admin_audit_log_admin_user_idx on public.admin_audit_log (admin_user_id);

-- ==========================================================
-- Admin feature flags (control-site + operational toggles)
-- ==========================================================
create table if not exists public.admin_feature_flags (
  key text primary key,
  enabled boolean not null default false,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_updated_at_admin_feature_flags on public.admin_feature_flags;
create trigger set_updated_at_admin_feature_flags
before update on public.admin_feature_flags
for each row execute function public.set_updated_at();

-- ==========================================================
-- Support sessions (metadata only)
-- ==========================================================
create table if not exists public.admin_support_sessions (
  id uuid primary key default gen_random_uuid(),

  -- The user the support session relates to (identifier only; no names)
  target_user_id uuid,

  status text not null default 'open', -- open|closed
  priority text not null default 'normal', -- low|normal|high

  opened_by_admin_user_id uuid references public.admin_users (admin_user_id) on delete set null,
  closed_by_admin_user_id uuid references public.admin_users (admin_user_id) on delete set null,

  opened_at timestamptz not null default now(),
  closed_at timestamptz,

  -- Optional linkage to external systems
  ticket_id text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists admin_support_sessions_target_user_idx on public.admin_support_sessions (target_user_id);
create index if not exists admin_support_sessions_status_idx on public.admin_support_sessions (status);
create index if not exists admin_support_sessions_opened_at_idx on public.admin_support_sessions (opened_at desc);

drop trigger if exists set_updated_at_admin_support_sessions on public.admin_support_sessions;
create trigger set_updated_at_admin_support_sessions
before update on public.admin_support_sessions
for each row execute function public.set_updated_at();

-- Support notes (redacted-only; keep extremely short to reduce PHI risk)
create table if not exists public.admin_support_notes (
  id uuid primary key default gen_random_uuid(),
  support_session_id uuid not null references public.admin_support_sessions (id) on delete cascade,
  author_admin_user_id uuid references public.admin_users (admin_user_id) on delete set null,

  -- IMPORTANT: store only redacted content (no names, no document titles, no health details)
  note_redacted text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint admin_support_notes_redacted_len check (char_length(note_redacted) <= 280)
);

create index if not exists admin_support_notes_session_idx on public.admin_support_notes (support_session_id);
create index if not exists admin_support_notes_created_at_idx on public.admin_support_notes (created_at desc);

drop trigger if exists set_updated_at_admin_support_notes on public.admin_support_notes;
create trigger set_updated_at_admin_support_notes
before update on public.admin_support_notes
for each row execute function public.set_updated_at();

-- ==========================================================
-- Compliance workflows (metadata only)
-- ==========================================================
create table if not exists public.admin_compliance_requests (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid,
  request_type text not null, -- e.g. export|delete|access|restriction
  status text not null default 'open', -- open|in_review|fulfilled|rejected|cancelled
  opened_by_admin_user_id uuid references public.admin_users (admin_user_id) on delete set null,
  closed_by_admin_user_id uuid references public.admin_users (admin_user_id) on delete set null,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  ticket_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists admin_compliance_requests_target_user_idx on public.admin_compliance_requests (target_user_id);
create index if not exists admin_compliance_requests_status_idx on public.admin_compliance_requests (status);
create index if not exists admin_compliance_requests_opened_at_idx on public.admin_compliance_requests (opened_at desc);

drop trigger if exists set_updated_at_admin_compliance_requests on public.admin_compliance_requests;
create trigger set_updated_at_admin_compliance_requests
before update on public.admin_compliance_requests
for each row execute function public.set_updated_at();

-- ==========================================================
-- Row Level Security (RLS)
-- ==========================================================

-- ADMIN USERS
alter table public.admin_users enable row level security;

-- Active admins can read their own profile.
drop policy if exists "admin_users_select_self" on public.admin_users;
create policy "admin_users_select_self"
on public.admin_users
for select
to authenticated
using (admin_user_id = auth.uid() and is_active = true);

-- Only owners/admins can read all admin users.
drop policy if exists "admin_users_select_all_owner_admin" on public.admin_users;
create policy "admin_users_select_all_owner_admin"
on public.admin_users
for select
to authenticated
using (public.is_active_admin() and public.current_admin_role() in ('owner','admin'));

-- Only owners can insert/update admin users (bootstrap via dashboard SQL if needed).
drop policy if exists "admin_users_insert_owner" on public.admin_users;
create policy "admin_users_insert_owner"
on public.admin_users
for insert
to authenticated
with check (public.is_active_admin() and public.current_admin_role() = 'owner');

drop policy if exists "admin_users_update_owner" on public.admin_users;
create policy "admin_users_update_owner"
on public.admin_users
for update
to authenticated
using (public.is_active_admin() and public.current_admin_role() = 'owner')
with check (public.is_active_admin() and public.current_admin_role() = 'owner');

-- AUDIT LOG
alter table public.admin_audit_log enable row level security;

-- Any active admin can read audit logs (you can narrow this later).
drop policy if exists "admin_audit_log_select_active_admin" on public.admin_audit_log;
create policy "admin_audit_log_select_active_admin"
on public.admin_audit_log
for select
to authenticated
using (public.is_active_admin());

-- Any active admin can insert audit logs (mandatory logging).
drop policy if exists "admin_audit_log_insert_active_admin" on public.admin_audit_log;
create policy "admin_audit_log_insert_active_admin"
on public.admin_audit_log
for insert
to authenticated
with check (public.is_active_admin());

-- Prevent updates/deletes to preserve audit integrity.
drop policy if exists "admin_audit_log_update_none" on public.admin_audit_log;
create policy "admin_audit_log_update_none"
on public.admin_audit_log
for update
to authenticated
using (false);

drop policy if exists "admin_audit_log_delete_none" on public.admin_audit_log;
create policy "admin_audit_log_delete_none"
on public.admin_audit_log
for delete
to authenticated
using (false);

-- FEATURE FLAGS
alter table public.admin_feature_flags enable row level security;

drop policy if exists "admin_feature_flags_select_active_admin" on public.admin_feature_flags;
create policy "admin_feature_flags_select_active_admin"
on public.admin_feature_flags
for select
to authenticated
using (public.is_active_admin());

drop policy if exists "admin_feature_flags_write_owner_admin" on public.admin_feature_flags;
create policy "admin_feature_flags_write_owner_admin"
on public.admin_feature_flags
for all
to authenticated
using (public.is_active_admin() and public.current_admin_role() in ('owner','admin'))
with check (public.is_active_admin() and public.current_admin_role() in ('owner','admin'));

-- SUPPORT SESSIONS
alter table public.admin_support_sessions enable row level security;

drop policy if exists "admin_support_sessions_select_active_admin" on public.admin_support_sessions;
create policy "admin_support_sessions_select_active_admin"
on public.admin_support_sessions
for select
to authenticated
using (public.is_active_admin());

drop policy if exists "admin_support_sessions_write_support_owner_admin" on public.admin_support_sessions;
create policy "admin_support_sessions_write_support_owner_admin"
on public.admin_support_sessions
for all
to authenticated
using (public.is_active_admin() and public.current_admin_role() in ('owner','admin','support'))
with check (public.is_active_admin() and public.current_admin_role() in ('owner','admin','support'));

-- SUPPORT NOTES
alter table public.admin_support_notes enable row level security;

drop policy if exists "admin_support_notes_select_active_admin" on public.admin_support_notes;
create policy "admin_support_notes_select_active_admin"
on public.admin_support_notes
for select
to authenticated
using (public.is_active_admin());

drop policy if exists "admin_support_notes_write_support_owner_admin" on public.admin_support_notes;
create policy "admin_support_notes_write_support_owner_admin"
on public.admin_support_notes
for all
to authenticated
using (public.is_active_admin() and public.current_admin_role() in ('owner','admin','support'))
with check (public.is_active_admin() and public.current_admin_role() in ('owner','admin','support'));

-- COMPLIANCE REQUESTS
alter table public.admin_compliance_requests enable row level security;

drop policy if exists "admin_compliance_requests_select_active_admin" on public.admin_compliance_requests;
create policy "admin_compliance_requests_select_active_admin"
on public.admin_compliance_requests
for select
to authenticated
using (public.is_active_admin());

drop policy if exists "admin_compliance_requests_write_compliance_owner_admin" on public.admin_compliance_requests;
create policy "admin_compliance_requests_write_compliance_owner_admin"
on public.admin_compliance_requests
for all
to authenticated
using (public.is_active_admin() and public.current_admin_role() in ('owner','admin','compliance'))
with check (public.is_active_admin() and public.current_admin_role() in ('owner','admin','compliance'));

commit;

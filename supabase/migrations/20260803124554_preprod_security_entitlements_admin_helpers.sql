-- Pre-production security repair: entitlements and admin reporting helpers.
--
-- This migration is forward-only and intentionally avoids changing billing,
-- OCR, AI or clinical data access rules. It removes client-side entitlement
-- writes and prevents direct execution of internal admin helper functions.

begin;

-- Ensure the canonical entitlement table exists for environments that only
-- replay the root Supabase migration path. The shape is derived from the live
-- schema, generated types, app reads, and server-side webhook upserts.
create table if not exists public.user_entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'plus', 'pro')),
  ai_access boolean not null default false,
  export_access boolean not null default false,
  document_quota_mb integer not null default 250,
  subscription_status text not null default 'active' check (subscription_status in ('active', 'trialing', 'past_due', 'canceled', 'expired')),
  source_platform text not null default 'internal',
  expires_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  plan_key text not null default 'free',
  status text not null default 'active',
  ai_enabled boolean not null default false,
  export_enabled boolean not null default false,
  max_storage_mb integer not null default 250,
  max_family_members integer not null default 1,
  mass_upload_enabled boolean not null default false,
  current_period_end timestamptz null,
  billing_period text null check (billing_period in ('monthly', 'annual') or billing_period is null),
  ocr_enabled boolean not null default true,
  ocr_access boolean not null default true,
  ai_monthly_cap integer not null default 0,
  ocr_monthly_cap integer not null default 10000,
  storage_gb_override double precision null,
  ai_monthly_tokens_override integer null,
  ocr_monthly_pages_override integer null,
  max_family_profiles_override integer null,
  entitlement_override_reason text null,
  entitlement_override_expires_at timestamptz null,
  override_updated_by text null,
  override_updated_at timestamptz null
);

alter table public.user_entitlements
  add column if not exists plan_key text,
  add column if not exists billing_period text,
  add column if not exists status text,
  add column if not exists ai_enabled boolean,
  add column if not exists ocr_enabled boolean,
  add column if not exists ocr_access boolean,
  add column if not exists export_enabled boolean,
  add column if not exists mass_upload_enabled boolean,
  add column if not exists max_storage_mb integer,
  add column if not exists max_family_members integer,
  add column if not exists ai_monthly_cap integer,
  add column if not exists ocr_monthly_cap integer,
  add column if not exists current_period_end timestamptz,
  add column if not exists storage_gb_override double precision,
  add column if not exists ai_monthly_tokens_override integer,
  add column if not exists ocr_monthly_pages_override integer,
  add column if not exists max_family_profiles_override integer,
  add column if not exists entitlement_override_reason text,
  add column if not exists entitlement_override_expires_at timestamptz,
  add column if not exists override_updated_by text,
  add column if not exists override_updated_at timestamptz;

alter table public.user_entitlements
  alter column plan set default 'free',
  alter column document_quota_mb set default 250,
  alter column subscription_status set default 'active',
  alter column source_platform set default 'internal',
  alter column plan_key set default 'free',
  alter column status set default 'active',
  alter column ai_enabled set default false,
  alter column ocr_enabled set default true,
  alter column ocr_access set default true,
  alter column export_enabled set default false,
  alter column mass_upload_enabled set default false,
  alter column max_storage_mb set default 250,
  alter column max_family_members set default 1,
  alter column ai_monthly_cap set default 0,
  alter column ocr_monthly_cap set default 10000;

alter table public.user_entitlements enable row level security;

-- Server-owned free entitlement creation. The function accepts no caller
-- supplied plan, limits, status, or override fields.
create or replace function public.ensure_my_free_entitlement()
returns public.user_entitlements
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_row public.user_entitlements;
begin
  v_user_id := (select auth.uid());

  if v_user_id is null then
    raise exception 'authenticated user required' using errcode = '42501';
  end if;

  insert into public.user_entitlements (
    user_id,
    plan,
    plan_key,
    billing_period,
    status,
    subscription_status,
    ai_access,
    ai_enabled,
    ocr_access,
    ocr_enabled,
    export_access,
    export_enabled,
    mass_upload_enabled,
    document_quota_mb,
    max_storage_mb,
    max_family_members,
    ai_monthly_cap,
    ocr_monthly_cap,
    source_platform,
    expires_at,
    current_period_end
  )
  values (
    v_user_id,
    'free',
    'free',
    null,
    'active',
    'active',
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    250,
    250,
    1,
    0,
    10000,
    'internal',
    null,
    null
  )
  on conflict (user_id) do nothing;

  select *
  into v_row
  from public.user_entitlements
  where user_id = v_user_id;

  return v_row;
end;
$$;

create or replace function public.create_default_user_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_entitlements (
    user_id,
    plan,
    plan_key,
    billing_period,
    status,
    subscription_status,
    ai_access,
    ai_enabled,
    ocr_access,
    ocr_enabled,
    export_access,
    export_enabled,
    mass_upload_enabled,
    document_quota_mb,
    max_storage_mb,
    max_family_members,
    ai_monthly_cap,
    ocr_monthly_cap,
    source_platform,
    expires_at,
    current_period_end
  )
  values (
    new.id,
    'free',
    'free',
    null,
    'active',
    'active',
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    250,
    250,
    1,
    0,
    10000,
    'internal',
    null,
    null
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_create_default_user_entitlement on auth.users;
create trigger trg_create_default_user_entitlement
after insert on auth.users
for each row
execute function public.create_default_user_entitlement();

insert into public.user_entitlements (
  user_id,
  plan,
  plan_key,
  billing_period,
  status,
  subscription_status,
  ai_access,
  ai_enabled,
  ocr_access,
  ocr_enabled,
  export_access,
  export_enabled,
  mass_upload_enabled,
  document_quota_mb,
  max_storage_mb,
  max_family_members,
  ai_monthly_cap,
  ocr_monthly_cap,
  source_platform,
  expires_at,
  current_period_end
)
select
  u.id,
  'free',
  'free',
  null,
  'active',
  'active',
  false,
  false,
  true,
  true,
  false,
  false,
  false,
  250,
  250,
  1,
  0,
  10000,
  'internal',
  null,
  null
from auth.users u
where not exists (
  select 1
  from public.user_entitlements e
  where e.user_id = u.id
);

drop policy if exists "user_entitlements_insert_own" on public.user_entitlements;
drop policy if exists "user_entitlements_insert_free_defaults" on public.user_entitlements;
drop policy if exists "user_entitlements_update_own" on public.user_entitlements;
drop policy if exists "user_entitlements_delete_own" on public.user_entitlements;
drop policy if exists "user_entitlements_select_own" on public.user_entitlements;

create policy "user_entitlements_select_own"
on public.user_entitlements
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke select, insert, update, delete, truncate, references, trigger
on table public.user_entitlements
from anon;

revoke insert, update, delete, truncate, references, trigger
on table public.user_entitlements
from authenticated;

grant select on table public.user_entitlements to authenticated;
grant select, insert, update, delete on table public.user_entitlements to service_role;

revoke all on function public.ensure_my_free_entitlement() from public, anon, authenticated;
grant execute on function public.ensure_my_free_entitlement() to authenticated;

revoke all on function public.create_default_user_entitlement() from public, anon, authenticated, service_role;

-- Harden internal admin helper functions. Direct execution is revoked from
-- browser/mobile roles; authorized top-level admin RPCs can still invoke them
-- internally because they run as the function owner.
create or replace function public._admin_safe_assert_active_admin()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_active_admin() then
    raise exception 'access denied' using errcode = '42501';
  end if;
end;
$$;

create or replace function public._admin_safe_table_exists(p_qualified_table text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_schema text;
  v_table text;
begin
  if p_qualified_table is null
     or p_qualified_table !~ '^[a-z_][a-z0-9_]*[.][a-z_][a-z0-9_]*$' then
    return false;
  end if;

  v_schema := split_part(p_qualified_table, '.', 1);
  v_table := split_part(p_qualified_table, '.', 2);

  if v_schema <> 'public' then
    return false;
  end if;

  return exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = v_schema
      and c.relname = v_table
      and c.relkind in ('r', 'p', 'v', 'm')
  );
end;
$$;

create or replace function public._admin_safe_column_exists(
  p_schema text,
  p_table text,
  p_column text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_schema <> 'public'
     or p_table is null
     or p_column is null
     or p_table !~ '^[a-z_][a-z0-9_]*$'
     or p_column !~ '^[a-z_][a-z0-9_]*$' then
    return false;
  end if;

  return exists (
    select 1
    from pg_catalog.pg_attribute a
    join pg_catalog.pg_class c on c.oid = a.attrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = p_schema
      and c.relname = p_table
      and a.attname = p_column
      and a.attnum > 0
      and not a.attisdropped
  );
end;
$$;

create or replace function public._admin_safe_count(
  p_qualified_table text,
  p_where_sql text default null
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_schema text;
  v_table text;
  v_where text;
  v_count bigint := 0;
begin
  if not public._admin_safe_table_exists(p_qualified_table) then
    return 0;
  end if;

  v_schema := split_part(p_qualified_table, '.', 1);
  v_table := split_part(p_qualified_table, '.', 2);
  v_where := lower(trim(coalesce(p_where_sql, '')));

  if v_where = '' then
    execute format('select count(*)::bigint from %I.%I', v_schema, v_table)
    into v_count;
  elsif v_where in ('is_active is true', 'is_active is false') then
    execute format('select count(*)::bigint from %I.%I where %s', v_schema, v_table, v_where)
    into v_count;
  else
    raise exception 'unsupported admin count predicate' using errcode = '42501';
  end if;

  return coalesce(v_count, 0);
end;
$$;

create or replace function public._admin_safe_count_uuid(
  p_qualified_table text,
  p_where_sql text,
  p_user_id uuid
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_schema text;
  v_table text;
  v_column text;
  v_match text[];
  v_count bigint := 0;
begin
  if not public._admin_safe_table_exists(p_qualified_table) then
    return 0;
  end if;

  v_match := regexp_match(trim(coalesce(p_where_sql, '')), '^([a-z_][a-z0-9_]*)\s*=\s*\$1$');
  if v_match is null then
    raise exception 'unsupported admin uuid count predicate' using errcode = '42501';
  end if;

  v_schema := split_part(p_qualified_table, '.', 1);
  v_table := split_part(p_qualified_table, '.', 2);
  v_column := v_match[1];

  if not public._admin_safe_column_exists(v_schema, v_table, v_column) then
    return 0;
  end if;

  execute format('select count(*)::bigint from %I.%I where %I = $1', v_schema, v_table, v_column)
  into v_count
  using p_user_id;

  return coalesce(v_count, 0);
end;
$$;

revoke all on function public._admin_safe_assert_active_admin() from public, anon, authenticated;
revoke all on function public._admin_safe_table_exists(text) from public, anon, authenticated;
revoke all on function public._admin_safe_column_exists(text, text, text) from public, anon, authenticated;
revoke all on function public._admin_safe_count(text, text) from public, anon, authenticated;
revoke all on function public._admin_safe_count_uuid(text, text, uuid) from public, anon, authenticated;

grant execute on function public._admin_safe_assert_active_admin() to service_role;
grant execute on function public._admin_safe_table_exists(text) to service_role;
grant execute on function public._admin_safe_column_exists(text, text, text) to service_role;
grant execute on function public._admin_safe_count(text, text) to service_role;
grant execute on function public._admin_safe_count_uuid(text, text, uuid) to service_role;

do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as fn
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'admin\_get\_%' escape '\'
  loop
    execute format('revoke all on function %s from public, anon', r.fn);
    execute format('grant execute on function %s to authenticated, service_role', r.fn);
  end loop;
end;
$$;

commit;
;

-- Admin-safe reporting RPCs for the CuraVault Control Site
--
-- PRIVACY RULES (hard requirements):
-- - SECURITY DEFINER + gate with public.is_active_admin()
-- - Aggregates only: counts/totals/statuses/dates
-- - Never return medical record contents, notes, document names, file names, prompts/responses, or health values

begin;

-- ----------------------------------------------------------
-- Helpers (graceful handling for missing relations)
-- ----------------------------------------------------------

create or replace function public._admin_safe_count(_qualified_table text)
returns bigint
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  _count bigint;
begin
  if to_regclass(_qualified_table) is null then
    return 0;
  end if;

  execute format('select count(*)::bigint from %s', _qualified_table) into _count;
  return coalesce(_count, 0);
exception
  when undefined_table then
    return 0;
end;
$$;

-- ----------------------------------------------------------
-- 1) Dashboard metrics (single row)
-- ----------------------------------------------------------

create or replace function public.admin_get_dashboard_metrics()
returns table (
  total_auth_users bigint,
  total_admin_users bigint,
  active_admin_users bigint,
  total_profiles bigint,
  total_family_members bigint,
  total_medical_records_count bigint,
  total_appointments_count bigint,
  total_medications_count bigint,
  total_vaccinations_count bigint,
  total_blood_pressure_entries_count bigint,
  total_medical_documents_count bigint,
  total_usage_events_count bigint,
  total_subscription_events_count bigint,
  total_entitlements_count bigint,
  total_audit_events_count bigint,
  total_support_sessions_count bigint,
  total_compliance_requests_count bigint
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if not public.is_active_admin() then
    raise exception 'not_authorized';
  end if;

  return query
  select
    -- auth.users is readable here because of SECURITY DEFINER
    (select count(*)::bigint from auth.users) as total_auth_users,
    public._admin_safe_count('public.admin_users') as total_admin_users,
    (select count(*)::bigint from public.admin_users where is_active = true) as active_admin_users,
    public._admin_safe_count('public.user_profiles') as total_profiles,
    public._admin_safe_count('public.family_members') as total_family_members,
    public._admin_safe_count('public.medical_records') as total_medical_records_count,
    public._admin_safe_count('public.appointments') as total_appointments_count,
    public._admin_safe_count('public.medications') as total_medications_count,
    public._admin_safe_count('public.vaccinations') as total_vaccinations_count,
    public._admin_safe_count('public.blood_pressure_readings') as total_blood_pressure_entries_count,
    public._admin_safe_count('public.medical_documents') as total_medical_documents_count,
    public._admin_safe_count('public.usage_events') as total_usage_events_count,
    public._admin_safe_count('public.subscription_events') as total_subscription_events_count,
    public._admin_safe_count('public.user_entitlements') as total_entitlements_count,
    public._admin_safe_count('public.admin_audit_log') as total_audit_events_count,
    public._admin_safe_count('public.admin_support_sessions') as total_support_sessions_count,
    public._admin_safe_count('public.admin_compliance_requests') as total_compliance_requests_count;
end;
$$;

grant execute on function public.admin_get_dashboard_metrics() to authenticated;

-- ----------------------------------------------------------
-- 2) Per-user usage summary (one row per auth user)
-- ----------------------------------------------------------

create or replace function public.admin_get_user_usage_summary()
returns table (
  user_id uuid,
  email text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  profile_count bigint,
  family_member_count bigint,
  medical_record_count bigint,
  appointment_count bigint,
  medication_count bigint,
  vaccination_count bigint,
  blood_pressure_entry_count bigint,
  medical_document_count bigint,
  usage_event_count bigint,
  entitlement_count bigint,
  subscription_event_count bigint
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if not public.is_active_admin() then
    raise exception 'not_authorized';
  end if;

  -- NOTE: This function intentionally returns ONLY identifiers + counts + timestamps.
  -- It never returns names, titles, notes, document filenames, or any medical values.

  return query
  with
    profiles as (
      select user_id, count(*)::bigint as c
      from public.user_profiles
      group by user_id
    ),
    family as (
      select owner_user_id as user_id, count(*)::bigint as c
      from public.family_members
      group by owner_user_id
    ),
    records as (
      select owner_user_id as user_id, count(*)::bigint as c
      from public.medical_records
      group by owner_user_id
    ),
    appts as (
      select owner_user_id as user_id, count(*)::bigint as c
      from public.appointments
      group by owner_user_id
    ),
    meds as (
      select owner_user_id as user_id, count(*)::bigint as c
      from public.medications
      group by owner_user_id
    ),
    vax as (
      select owner_user_id as user_id, count(*)::bigint as c
      from public.vaccinations
      group by owner_user_id
    ),
    bp as (
      select owner_user_id as user_id, count(*)::bigint as c
      from public.blood_pressure_readings
      group by owner_user_id
    ),
    docs as (
      select owner_user_id as user_id, count(*)::bigint as c
      from public.medical_documents
      group by owner_user_id
    ),
    usage as (
      select user_id, count(*)::bigint as c
      from public.usage_events
      group by user_id
    ),
    ent as (
      select user_id, count(*)::bigint as c
      from public.user_entitlements
      group by user_id
    ),
    subs as (
      select user_id, count(*)::bigint as c
      from public.subscription_events
      group by user_id
    )
  select
    u.id as user_id,
    u.email,
    u.created_at,
    u.last_sign_in_at,
    coalesce(p.c, 0) as profile_count,
    coalesce(f.c, 0) as family_member_count,
    coalesce(r.c, 0) as medical_record_count,
    coalesce(a.c, 0) as appointment_count,
    coalesce(m.c, 0) as medication_count,
    coalesce(v.c, 0) as vaccination_count,
    coalesce(b.c, 0) as blood_pressure_entry_count,
    coalesce(d.c, 0) as medical_document_count,
    coalesce(ue.c, 0) as usage_event_count,
    coalesce(e.c, 0) as entitlement_count,
    coalesce(s.c, 0) as subscription_event_count
  from auth.users u
  left join profiles p on p.user_id = u.id
  left join family f on f.user_id = u.id
  left join records r on r.user_id = u.id
  left join appts a on a.user_id = u.id
  left join meds m on m.user_id = u.id
  left join vax v on v.user_id = u.id
  left join bp b on b.user_id = u.id
  left join docs d on d.user_id = u.id
  left join usage ue on ue.user_id = u.id
  left join ent e on e.user_id = u.id
  left join subs s on s.user_id = u.id
  order by u.created_at desc;
end;
$$;

grant execute on function public.admin_get_user_usage_summary() to authenticated;

-- ----------------------------------------------------------
-- 3) Usage events summary (aggregated)
-- ----------------------------------------------------------

create or replace function public.admin_get_usage_events_summary()
returns table (
  event_name text,
  feature_area text,
  platform text,
  app_version text,
  country text,
  count bigint,
  first_seen_at timestamptz,
  last_seen_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_active_admin() then
    raise exception 'not_authorized';
  end if;

  if to_regclass('public.usage_events') is null then
    return;
  end if;

  -- IMPORTANT: Only extracts controlled metadata keys from `properties`.
  -- It does NOT return free-form properties payloads.
  return query
  select
    ue.event_key as event_name,
    nullif(coalesce(ue.properties->>'feature_area', ue.properties->>'feature', ue.event_type, ''), '') as feature_area,
    nullif(coalesce(ue.properties->>'platform', ''), '') as platform,
    nullif(coalesce(ue.properties->>'app_version', ue.properties->>'version', ''), '') as app_version,
    nullif(coalesce(ue.properties->>'country', ue.properties->>'country_code', ''), '') as country,
    count(*)::bigint as count,
    min(ue.created_at) as first_seen_at,
    max(ue.created_at) as last_seen_at
  from public.usage_events ue
  group by 1,2,3,4,5
  order by count desc, last_seen_at desc;
end;
$$;

grant execute on function public.admin_get_usage_events_summary() to authenticated;

-- ----------------------------------------------------------
-- 4) Billing summary (aggregated)
-- ----------------------------------------------------------

create or replace function public.admin_get_billing_summary()
returns table (
  plan text,
  billing_status text,
  subscription_provider text,
  user_count bigint,
  active_count bigint,
  cancelled_count bigint,
  failed_payment_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_active_admin() then
    raise exception 'not_authorized';
  end if;

  if to_regclass('public.user_entitlements') is null then
    return;
  end if;

  -- Source of truth: public.user_entitlements
  -- - plan: user_entitlements.plan (or plan_key)
  -- - billing_status: user_entitlements.subscription_status
  -- - subscription_provider: user_entitlements.source_platform
  return query
  select
    coalesce(nullif(e.plan, ''), nullif(e.plan_key, ''), 'unknown') as plan,
    coalesce(nullif(e.subscription_status, ''), nullif(e.status, ''), 'unknown') as billing_status,
    coalesce(nullif(e.source_platform, ''), 'unknown') as subscription_provider,
    count(*)::bigint as user_count,
    sum(case when coalesce(e.subscription_status, e.status) = 'active' then 1 else 0 end)::bigint as active_count,
    sum(case when coalesce(e.subscription_status, e.status) in ('canceled','cancelled') then 1 else 0 end)::bigint as cancelled_count,
    sum(case when coalesce(e.subscription_status, e.status) in ('past_due','retrying') then 1 else 0 end)::bigint as failed_payment_count
  from public.user_entitlements e
  group by 1,2,3
  order by user_count desc, plan asc, billing_status asc;
end;
$$;

grant execute on function public.admin_get_billing_summary() to authenticated;

commit;

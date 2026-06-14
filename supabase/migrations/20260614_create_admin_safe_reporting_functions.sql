-- CuraVault Control Site: Admin-safe reporting RPCs (aggregate-only)
--
-- IMPORTANT PRIVACY RULES
-- - Do NOT modify any existing health tables.
-- - Do NOT weaken RLS on existing tables.
-- - Do NOT return raw health content (titles, notes, names, values, file paths, prompts, etc.).
-- - These functions are SECURITY DEFINER and must gate access using public.is_active_admin().
--
-- DESIGN GOALS
-- - Frontend calls authenticated RPCs only (no service-role key in frontend).
-- - Functions are robust to missing tables/columns (return 0/empty results instead of failing).
-- - Outputs contain ONLY counts/totals/statuses/timestamps + limited safe metadata (auth email).

begin;

-- If earlier iterations exist (e.g., 20260614_admin_safe_reporting_rpcs.sql),
-- drop the RPCs first so we can safely change OUT parameters / return shapes.
drop function if exists public.admin_get_dashboard_metrics();
drop function if exists public.admin_get_user_usage_summary();
drop function if exists public.admin_get_usage_events_summary();
drop function if exists public.admin_get_billing_summary();
drop function if exists public.admin_get_country_usage_summary();
drop function if exists public.admin_get_system_health_summary();

-- -----------------------------------------------------------------------------
-- Helper utilities (internal)
-- -----------------------------------------------------------------------------

create or replace function public._admin_safe_assert_active_admin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_active_admin() then
    raise exception 'access denied' using errcode = '42501';
  end if;
end;
$$;

create or replace function public._admin_safe_table_exists(p_qualified_table text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select to_regclass(p_qualified_table) is not null;
$$;

create or replace function public._admin_safe_column_exists(p_schema text, p_table text, p_column text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from information_schema.columns
    where table_schema = p_schema
      and table_name = p_table
      and column_name = p_column
  );
$$;

create or replace function public._admin_safe_count(p_qualified_table text, p_where_sql text default null)
returns bigint
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_count bigint := 0;
  v_sql text;
begin
  if not public._admin_safe_table_exists(p_qualified_table) then
    return 0;
  end if;

  v_sql := 'select count(*)::bigint from ' || p_qualified_table;
  if p_where_sql is not null and length(trim(p_where_sql)) > 0 then
    v_sql := v_sql || ' where ' || p_where_sql;
  end if;

  execute v_sql into v_count;
  return coalesce(v_count, 0);
end;
$$;

create or replace function public._admin_safe_count_uuid(p_qualified_table text, p_where_sql text, p_user_id uuid)
returns bigint
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_count bigint := 0;
  v_sql text;
begin
  if not public._admin_safe_table_exists(p_qualified_table) then
    return 0;
  end if;

  v_sql := 'select count(*)::bigint from ' || p_qualified_table || ' where ' || p_where_sql;
  execute v_sql into v_count using p_user_id;
  return coalesce(v_count, 0);
end;
$$;

-- -----------------------------------------------------------------------------
-- 1) Dashboard metrics: one-row safe totals
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_dashboard_metrics()
returns table(
  total_auth_users bigint,
  total_admin_users bigint,
  active_admin_users bigint,
  total_user_profiles bigint,
  total_family_members bigint,
  total_medical_records bigint,
  total_appointments bigint,
  total_medications bigint,
  total_vaccinations bigint,
  total_blood_pressure_entries bigint,
  total_medical_documents bigint,
  total_insurance_cards bigint,
  total_usage_events bigint,
  total_subscription_events bigint,
  total_user_entitlements bigint,
  total_audit_events bigint,
  total_support_sessions bigint,
  open_support_sessions bigint,
  total_compliance_requests bigint,
  open_compliance_requests bigint
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_total_auth_users bigint := 0;
begin
  perform public._admin_safe_assert_active_admin();

  -- auth.users is expected to exist in Supabase projects; keep it guarded anyway.
  if to_regclass('auth.users') is not null then
    execute 'select count(*)::bigint from auth.users' into v_total_auth_users;
  end if;

  total_auth_users := coalesce(v_total_auth_users, 0);
  total_admin_users := public._admin_safe_count('public.admin_users');
  active_admin_users := public._admin_safe_count('public.admin_users', 'is_active is true');
  total_user_profiles := public._admin_safe_count('public.user_profiles');
  total_family_members := public._admin_safe_count('public.family_members');
  total_medical_records := public._admin_safe_count('public.medical_records');
  total_appointments := public._admin_safe_count('public.appointments');
  total_medications := public._admin_safe_count('public.medications');
  total_vaccinations := public._admin_safe_count('public.vaccinations');
  total_blood_pressure_entries := public._admin_safe_count('public.blood_pressure_readings');
  total_medical_documents := public._admin_safe_count('public.medical_documents');
  total_insurance_cards := public._admin_safe_count('public.insurance_cards');
  total_usage_events := public._admin_safe_count('public.usage_events');
  total_subscription_events := public._admin_safe_count('public.subscription_events');
  total_user_entitlements := public._admin_safe_count('public.user_entitlements');
  total_audit_events := public._admin_safe_count('public.admin_audit_log');
  total_support_sessions := public._admin_safe_count('public.admin_support_sessions');
  open_support_sessions := public._admin_safe_count('public.admin_support_sessions', $q$status = 'open'$q$);
  total_compliance_requests := public._admin_safe_count('public.admin_compliance_requests');
  open_compliance_requests := public._admin_safe_count('public.admin_compliance_requests', $q$status = 'open'$q$);

  return next;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2) Per-user usage summary: one row per auth user (aggregate-only)
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_user_usage_summary()
returns table(
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
  insurance_card_count bigint,
  usage_event_count bigint,
  entitlement_count bigint,
  subscription_event_count bigint
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  r record;
begin
  perform public._admin_safe_assert_active_admin();

  if to_regclass('auth.users') is null then
    return;
  end if;

  for r in execute 'select id, email, created_at, last_sign_in_at from auth.users order by created_at desc'
  loop
    user_id := r.id;
    email := r.email;
    created_at := r.created_at;
    last_sign_in_at := r.last_sign_in_at;

    -- Counts are best-effort; if a table is missing, helper returns 0.
    profile_count := public._admin_safe_count_uuid('public.user_profiles', 'user_id = $1', user_id);
    family_member_count := public._admin_safe_count_uuid('public.family_members', 'owner_user_id = $1', user_id);
    medical_record_count := public._admin_safe_count_uuid('public.medical_records', 'owner_user_id = $1', user_id);
    appointment_count := public._admin_safe_count_uuid('public.appointments', 'owner_user_id = $1', user_id);
    medication_count := public._admin_safe_count_uuid('public.medications', 'owner_user_id = $1', user_id);
    vaccination_count := public._admin_safe_count_uuid('public.vaccinations', 'owner_user_id = $1', user_id);
    blood_pressure_entry_count := public._admin_safe_count_uuid('public.blood_pressure_readings', 'owner_user_id = $1', user_id);
    medical_document_count := public._admin_safe_count_uuid('public.medical_documents', 'owner_user_id = $1', user_id);
    insurance_card_count := public._admin_safe_count_uuid('public.insurance_cards', 'owner_user_id = $1', user_id);
    usage_event_count := public._admin_safe_count_uuid('public.usage_events', 'user_id = $1', user_id);
    entitlement_count := public._admin_safe_count_uuid('public.user_entitlements', 'user_id = $1', user_id);
    subscription_event_count := public._admin_safe_count_uuid('public.subscription_events', 'user_id = $1', user_id);

    return next;
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3) Usage event summary: aggregates only.
--    If some columns don't exist, we fall back to safe defaults ('unknown'/NULL).
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_usage_events_summary()
returns table(
  event_name text,
  feature_area text,
  platform text,
  app_version text,
  country text,
  event_count bigint,
  unique_user_count bigint,
  first_seen_at timestamptz,
  last_seen_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_table boolean;
  v_has_user_id boolean;
  v_has_created_at boolean;
  v_has_event_key boolean;
  v_has_event_name boolean;
  v_has_event_type boolean;
  v_has_properties boolean;
  v_sql text;
  v_event_name_expr text;
  v_feature_area_expr text;
  v_platform_expr text;
  v_app_version_expr text;
  v_country_expr text;
  v_unique_user_expr text;
  v_first_seen_expr text;
  v_last_seen_expr text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_table := public._admin_safe_table_exists('public.usage_events');
  if not v_has_table then
    return;
  end if;

  v_has_user_id := public._admin_safe_column_exists('public', 'usage_events', 'user_id');
  v_has_created_at := public._admin_safe_column_exists('public', 'usage_events', 'created_at');
  v_has_event_key := public._admin_safe_column_exists('public', 'usage_events', 'event_key');
  v_has_event_name := public._admin_safe_column_exists('public', 'usage_events', 'event_name');
  v_has_event_type := public._admin_safe_column_exists('public', 'usage_events', 'event_type');
  v_has_properties := public._admin_safe_column_exists('public', 'usage_events', 'properties');

  v_event_name_expr := case
    when v_has_event_name then 'ue.event_name'
    when v_has_event_key then 'ue.event_key'
    else $q$'unknown'::text$q$
  end;

  v_feature_area_expr := case
    when v_has_event_type and v_has_properties then $q$coalesce(ue.event_type, ue.properties->>'feature_area', 'unknown')$q$
    when v_has_event_type then $q$coalesce(ue.event_type, 'unknown')$q$
    when v_has_properties then $q$coalesce(ue.properties->>'feature_area', 'unknown')$q$
    else $q$'unknown'::text$q$
  end;

  v_platform_expr := case when v_has_properties then $q$coalesce(ue.properties->>'platform', 'unknown')$q$ else $q$'unknown'::text$q$ end;
  v_app_version_expr := case when v_has_properties then $q$coalesce(ue.properties->>'app_version', 'unknown')$q$ else $q$'unknown'::text$q$ end;
  v_country_expr := case when v_has_properties then $q$coalesce(ue.properties->>'country', 'unknown')$q$ else $q$'unknown'::text$q$ end;

  v_unique_user_expr := case when v_has_user_id then 'count(distinct ue.user_id)::bigint' else '0::bigint' end;
  v_first_seen_expr := case when v_has_created_at then 'min(ue.created_at)' else 'null::timestamptz' end;
  v_last_seen_expr := case when v_has_created_at then 'max(ue.created_at)' else 'null::timestamptz' end;

  v_sql :=
    'select '
    || v_event_name_expr || ' as event_name,'
    || v_feature_area_expr || ' as feature_area,'
    || v_platform_expr || ' as platform,'
    || v_app_version_expr || ' as app_version,'
    || v_country_expr || ' as country,'
    || 'count(*)::bigint as event_count,'
    || v_unique_user_expr || ' as unique_user_count,'
    || v_first_seen_expr || ' as first_seen_at,'
    || v_last_seen_expr || ' as last_seen_at '
    || 'from public.usage_events ue '
    || 'group by 1,2,3,4,5 '
    || 'order by event_count desc';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4) Billing summary: aggregated billing/entitlement data.
--    Uses subscription_events and user_entitlements only if relevant columns exist.
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_billing_summary()
returns table(
  plan text,
  billing_status text,
  subscription_provider text,
  user_count bigint,
  active_count bigint,
  cancelled_count bigint,
  failed_payment_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_entitlements boolean;
  v_has_sub_events boolean;
  v_has_plan boolean;
  v_has_status boolean;
  v_has_provider boolean;
  v_has_user_id boolean;
  v_has_se_user_id boolean;
  v_has_se_created_at boolean;
  v_has_se_event_key boolean;
  v_plan_expr text;
  v_status_expr text;
  v_provider_expr text;
  v_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_entitlements := public._admin_safe_table_exists('public.user_entitlements');
  if not v_has_entitlements then
    return;
  end if;

  v_has_plan := public._admin_safe_column_exists('public', 'user_entitlements', 'plan');
  v_has_status := public._admin_safe_column_exists('public', 'user_entitlements', 'subscription_status');
  v_has_provider := public._admin_safe_column_exists('public', 'user_entitlements', 'source_platform');
  v_has_user_id := public._admin_safe_column_exists('public', 'user_entitlements', 'user_id');

  v_plan_expr := case when v_has_plan then 'e.plan' else $q$'unknown'::text$q$ end;
  v_status_expr := case when v_has_status then 'e.subscription_status' else $q$'unknown'::text$q$ end;
  v_provider_expr := case when v_has_provider then 'e.source_platform' else $q$'unknown'::text$q$ end;

  v_has_sub_events := public._admin_safe_table_exists('public.subscription_events');
  v_has_se_user_id := v_has_sub_events and public._admin_safe_column_exists('public', 'subscription_events', 'user_id');
  v_has_se_created_at := v_has_sub_events and public._admin_safe_column_exists('public', 'subscription_events', 'created_at');
  v_has_se_event_key := v_has_sub_events and public._admin_safe_column_exists('public', 'subscription_events', 'event_key');

  -- We treat "failed payment" as a conservative signal from subscription_events.
  -- If subscription_events lacks these columns, failed_payment_count defaults to 0.
  v_sql :=
    'with failed_payers as ('
    || case
      when v_has_sub_events and v_has_se_user_id and v_has_se_created_at and v_has_se_event_key then
        'select distinct se.user_id from public.subscription_events se '
        || 'where se.created_at > now() - interval ''90 days'' '
        || 'and (se.event_key ilike ''%fail%'' or se.event_key ilike ''%past_due%'')'
      else
        'select null::uuid as user_id where false'
    end
    || ') '
    || 'select '
    || v_plan_expr || ' as plan,'
    || v_status_expr || ' as billing_status,'
    || v_provider_expr || ' as subscription_provider,'
    || 'count(*)::bigint as user_count,'
    || case when v_has_status then 'count(*) filter (where e.subscription_status in (''active'',''trialing''))::bigint' else '0::bigint' end || ' as active_count,'
    || case when v_has_status then 'count(*) filter (where e.subscription_status in (''canceled'',''expired''))::bigint' else '0::bigint' end || ' as cancelled_count,'
    || case when v_has_user_id then 'count(*) filter (where e.user_id in (select user_id from failed_payers))::bigint' else '0::bigint' end || ' as failed_payment_count '
    || 'from public.user_entitlements e '
    || 'group by 1,2,3 '
    || 'order by user_count desc';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5) Country usage summary: aggregated country usage.
--    Privacy rule: if fewer than 10 users, group it under "Other".
--    storage_used_mb and ai_tokens_used are included only if relevant columns exist.
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_country_usage_summary()
returns table(
  country text,
  user_count bigint,
  active_user_count bigint,
  usage_event_count bigint,
  storage_used_mb bigint,
  ai_tokens_used bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_usage boolean;
  v_has_user_id boolean;
  v_has_created_at boolean;
  v_has_properties boolean;
  v_has_tok_in boolean;
  v_has_tok_out boolean;
  v_has_docs boolean;
  v_has_doc_owner boolean;
  v_has_doc_size boolean;
  v_sql text;
  v_country_expr text;
  v_user_id_expr text;
  v_created_at_expr text;
  v_tokens_expr text;
  v_storage_join_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_usage := public._admin_safe_table_exists('public.usage_events');
  if not v_has_usage then
    return;
  end if;

  v_has_user_id := public._admin_safe_column_exists('public', 'usage_events', 'user_id');
  v_has_created_at := public._admin_safe_column_exists('public', 'usage_events', 'created_at');
  v_has_properties := public._admin_safe_column_exists('public', 'usage_events', 'properties');
  v_has_tok_in := public._admin_safe_column_exists('public', 'usage_events', 'estimated_tokens_input');
  v_has_tok_out := public._admin_safe_column_exists('public', 'usage_events', 'estimated_tokens_output');

  v_country_expr := case when v_has_properties then $q$coalesce(ue.properties->>'country', 'unknown')$q$ else $q$'unknown'::text$q$ end;
  v_user_id_expr := case when v_has_user_id then 'ue.user_id' else 'null::uuid' end;
  v_created_at_expr := case when v_has_created_at then 'ue.created_at' else 'null::timestamptz' end;
  v_tokens_expr := case
    when v_has_tok_in and v_has_tok_out then 'coalesce(ue.estimated_tokens_input,0) + coalesce(ue.estimated_tokens_output,0)'
    when v_has_tok_in then 'coalesce(ue.estimated_tokens_input,0)'
    when v_has_tok_out then 'coalesce(ue.estimated_tokens_output,0)'
    else '0'
  end;

  v_has_docs := public._admin_safe_table_exists('public.medical_documents');
  v_has_doc_owner := v_has_docs and public._admin_safe_column_exists('public', 'medical_documents', 'owner_user_id');
  v_has_doc_size := v_has_docs and public._admin_safe_column_exists('public', 'medical_documents', 'file_size');

  v_storage_join_sql := case
    when v_has_docs and v_has_doc_owner and v_has_doc_size and v_has_user_id and v_has_created_at then
      'storage_by_country as ('
      || 'with user_country as ('
      || 'select distinct on (ue.user_id) ue.user_id, ' || v_country_expr || ' as country_raw '
      || 'from public.usage_events ue '
      || 'where ue.user_id is not null '
      || 'order by ue.user_id, ue.created_at desc'
      || ') '
      || 'select uc.country_raw, coalesce(sum(md.file_size),0)::bigint as storage_bytes '
      || 'from user_country uc '
      || 'join public.medical_documents md on md.owner_user_id = uc.user_id '
      || 'where md.file_size is not null '
      || 'group by 1'
      || ')'
    else
      'storage_by_country as (select null::text as country_raw, 0::bigint as storage_bytes where false)'
  end;

  v_sql :=
    'with base as ('
    || 'select '
    || v_country_expr || ' as country_raw,'
    || v_user_id_expr || ' as user_id,'
    || v_created_at_expr || ' as created_at,'
    || v_tokens_expr || ' as tokens '
    || 'from public.usage_events ue'
    || '), '
    || 'per_country as ('
    || 'select '
    || 'country_raw, '
    || (case when v_has_user_id then 'count(distinct user_id)::bigint' else '0::bigint' end) || ' as user_count, '
    || (case when v_has_user_id and v_has_created_at then "count(distinct user_id) filter (where created_at > now() - interval '30 days')::bigint" else '0::bigint' end) || ' as active_user_count, '
    || 'count(*)::bigint as usage_event_count, '
    || 'coalesce(sum(tokens),0)::bigint as ai_tokens_used '
    || 'from base '
    || 'group by 1'
    || '), '
    || v_storage_join_sql
    || ' '
    || 'select '
    || "case when pc.user_count < 10 then 'Other' else pc.country_raw end as country,"
    || 'sum(pc.user_count)::bigint as user_count, '
    || 'sum(pc.active_user_count)::bigint as active_user_count, '
    || 'sum(pc.usage_event_count)::bigint as usage_event_count, '
    || 'coalesce(sum((sbc.storage_bytes / 1048576)::bigint),0)::bigint as storage_used_mb, '
    || 'sum(pc.ai_tokens_used)::bigint as ai_tokens_used '
    || 'from per_country pc '
    || 'left join storage_by_country sbc on sbc.country_raw = pc.country_raw '
    || 'group by 1 '
    || 'order by user_count desc';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 6) System health summary: safe operational metrics.
--    Do NOT return raw error payloads.
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_system_health_summary()
returns table(
  recent_usage_events_24h bigint,
  recent_errors_24h bigint,
  failed_upload_events_24h bigint,
  failed_sync_events_24h bigint,
  latest_usage_event_at timestamptz,
  latest_audit_event_at timestamptz,
  latest_support_session_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_usage boolean;
  v_has_usage_created_at boolean;
  v_has_usage_success boolean;
  v_has_usage_failure_code boolean;
  v_has_usage_event_key boolean;
  v_has_audit boolean;
  v_has_audit_created_at boolean;
  v_has_support boolean;
  v_has_support_opened_at boolean;
  v_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_usage := public._admin_safe_table_exists('public.usage_events');
  v_has_usage_created_at := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'created_at');
  v_has_usage_success := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'success');
  v_has_usage_failure_code := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'failure_code');
  v_has_usage_event_key := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'event_key');

  v_has_audit := public._admin_safe_table_exists('public.admin_audit_log');
  v_has_audit_created_at := v_has_audit and public._admin_safe_column_exists('public', 'admin_audit_log', 'created_at');

  v_has_support := public._admin_safe_table_exists('public.admin_support_sessions');
  v_has_support_opened_at := v_has_support and public._admin_safe_column_exists('public', 'admin_support_sessions', 'opened_at');

  -- Build safe counts using dynamic SQL so missing columns don't break parsing.
  v_sql :=
    'select '
    || case when v_has_usage and v_has_usage_created_at then
      "(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval '24 hours')"
    else '0::bigint' end
    || ' as recent_usage_events_24h, '
    || case when v_has_usage and v_has_usage_created_at and (v_has_usage_success or v_has_usage_failure_code) then
      '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ('
      || case
        when v_has_usage_success and v_has_usage_failure_code then '(ue.success is false or ue.failure_code is not null)'
        when v_has_usage_success then '(ue.success is false)'
        else '(ue.failure_code is not null)'
      end
      || '))'
    else '0::bigint' end
    || ' as recent_errors_24h, '
    || case when v_has_usage and v_has_usage_created_at and v_has_usage_event_key and (v_has_usage_success or v_has_usage_failure_code) then
      '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ue.event_key ilike ''%upload%'' and ('
      || case
        when v_has_usage_success and v_has_usage_failure_code then '(ue.success is false or ue.failure_code is not null)'
        when v_has_usage_success then '(ue.success is false)'
        else '(ue.failure_code is not null)'
      end
      || '))'
    else '0::bigint' end
    || ' as failed_upload_events_24h, '
    || case when v_has_usage and v_has_usage_created_at and v_has_usage_event_key and (v_has_usage_success or v_has_usage_failure_code) then
      '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ue.event_key ilike ''%sync%'' and ('
      || case
        when v_has_usage_success and v_has_usage_failure_code then '(ue.success is false or ue.failure_code is not null)'
        when v_has_usage_success then '(ue.success is false)'
        else '(ue.failure_code is not null)'
      end
      || '))'
    else '0::bigint' end
    || ' as failed_sync_events_24h, '
    || case when v_has_usage and v_has_usage_created_at then '(select max(ue.created_at) from public.usage_events ue)' else 'null::timestamptz' end
    || ' as latest_usage_event_at, '
    || case when v_has_audit and v_has_audit_created_at then '(select max(al.created_at) from public.admin_audit_log al)' else 'null::timestamptz' end
    || ' as latest_audit_event_at, '
    || case when v_has_support and v_has_support_opened_at then '(select max(ss.opened_at) from public.admin_support_sessions ss)' else 'null::timestamptz' end
    || ' as latest_support_session_at';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- Execution privileges: authenticated only. Active-admin gate is inside each RPC.
-- -----------------------------------------------------------------------------

revoke all on function public.admin_get_dashboard_metrics() from public;
revoke all on function public.admin_get_dashboard_metrics() from anon;
grant execute on function public.admin_get_dashboard_metrics() to authenticated;

revoke all on function public.admin_get_user_usage_summary() from public;
revoke all on function public.admin_get_user_usage_summary() from anon;
grant execute on function public.admin_get_user_usage_summary() to authenticated;

revoke all on function public.admin_get_usage_events_summary() from public;
revoke all on function public.admin_get_usage_events_summary() from anon;
grant execute on function public.admin_get_usage_events_summary() to authenticated;

revoke all on function public.admin_get_billing_summary() from public;
revoke all on function public.admin_get_billing_summary() from anon;
grant execute on function public.admin_get_billing_summary() to authenticated;

revoke all on function public.admin_get_country_usage_summary() from public;
revoke all on function public.admin_get_country_usage_summary() from anon;
grant execute on function public.admin_get_country_usage_summary() to authenticated;

revoke all on function public.admin_get_system_health_summary() from public;
revoke all on function public.admin_get_system_health_summary() from anon;
grant execute on function public.admin_get_system_health_summary() to authenticated;

commit;

begin;

drop function if exists public._admin_safe_count(text);

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

  if to_regclass('auth.users') is not null then
    execute 'select count(*)::bigint from auth.users' into v_total_auth_users;
  end if;

  total_auth_users := coalesce(v_total_auth_users, 0);
  total_admin_users := public._admin_safe_count('public.admin_users', null);
  active_admin_users := public._admin_safe_count('public.admin_users', 'is_active is true');
  total_user_profiles := public._admin_safe_count('public.user_profiles', null);
  total_family_members := public._admin_safe_count('public.family_members', null);
  total_medical_records := public._admin_safe_count('public.medical_records', null);
  total_appointments := public._admin_safe_count('public.appointments', null);
  total_medications := public._admin_safe_count('public.medications', null);
  total_vaccinations := public._admin_safe_count('public.vaccinations', null);
  total_blood_pressure_entries := public._admin_safe_count('public.blood_pressure_readings', null);
  total_medical_documents := public._admin_safe_count('public.medical_documents', null);
  total_insurance_cards := public._admin_safe_count('public.insurance_cards', null);
  total_usage_events := public._admin_safe_count('public.usage_events', null);
  total_subscription_events := public._admin_safe_count('public.subscription_events', null);
  total_user_entitlements := public._admin_safe_count('public.user_entitlements', null);
  total_audit_events := public._admin_safe_count('public.admin_audit_log', null);
  total_support_sessions := public._admin_safe_count('public.admin_support_sessions', null);
  open_support_sessions := public._admin_safe_count('public.admin_support_sessions', $q$status = 'open'$q$);
  total_compliance_requests := public._admin_safe_count('public.admin_compliance_requests', null);
  open_compliance_requests := public._admin_safe_count('public.admin_compliance_requests', $q$status = 'open'$q$);

  return next;
end;
$$;

revoke all on function public.admin_get_dashboard_metrics() from public;
revoke all on function public.admin_get_dashboard_metrics() from anon;
grant execute on function public.admin_get_dashboard_metrics() to authenticated;

commit;;

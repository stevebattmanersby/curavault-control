-- Repair legacy admin reporting RPCs used by Admin Data Test.
--
-- Earlier versions built portions of dynamic SQL with double-quoted text, which
-- Postgres interpreted as identifiers. These replacements keep output
-- aggregate-only and qualify all dynamic expressions.

begin;

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
  v_sql text;
  v_country_expr text;
  v_user_id_expr text;
  v_created_at_expr text;
  v_tokens_expr text;
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

  v_country_expr := case
    when v_has_properties then $q$coalesce(nullif(ue.properties->>'country', ''), 'unknown')$q$
    else $q$'unknown'::text$q$
  end;
  v_user_id_expr := case when v_has_user_id then 'ue.user_id' else 'null::uuid' end;
  v_created_at_expr := case when v_has_created_at then 'ue.created_at' else 'null::timestamptz' end;
  v_tokens_expr := case
    when v_has_tok_in and v_has_tok_out then 'coalesce(ue.estimated_tokens_input, 0) + coalesce(ue.estimated_tokens_output, 0)'
    when v_has_tok_in then 'coalesce(ue.estimated_tokens_input, 0)'
    when v_has_tok_out then 'coalesce(ue.estimated_tokens_output, 0)'
    else '0'
  end;

  v_sql :=
    'with base as ('
    || 'select '
    || v_country_expr || ' as country_raw, '
    || v_user_id_expr || ' as user_id, '
    || v_created_at_expr || ' as created_at, '
    || v_tokens_expr || ' as tokens '
    || 'from public.usage_events ue'
    || '), per_country as ('
    || 'select '
    || 'country_raw, '
    || case when v_has_user_id then 'count(distinct user_id)::bigint' else '0::bigint' end || ' as user_count, '
    || case
      when v_has_user_id and v_has_created_at then $q$count(distinct user_id) filter (where created_at > now() - interval '30 days')::bigint$q$
      else '0::bigint'
    end || ' as active_user_count, '
    || 'count(*)::bigint as usage_event_count, '
    || 'coalesce(sum(tokens), 0)::bigint as ai_tokens_used '
    || 'from base '
    || 'group by 1'
    || ') '
    || 'select '
    || $q$case when pc.user_count < 10 then 'Other' else pc.country_raw end as country, $q$
    || 'sum(pc.user_count)::bigint as user_count, '
    || 'sum(pc.active_user_count)::bigint as active_user_count, '
    || 'sum(pc.usage_event_count)::bigint as usage_event_count, '
    || '0::bigint as storage_used_mb, '
    || 'sum(pc.ai_tokens_used)::bigint as ai_tokens_used '
    || 'from per_country pc '
    || 'group by 1 '
    || 'order by user_count desc';

  return query execute v_sql;
end;
$$;

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
  v_has_usage_event_name boolean;
  v_has_audit boolean;
  v_has_audit_created_at boolean;
  v_has_support boolean;
  v_has_support_opened_at boolean;
  v_sql text;
  v_fail_pred text;
  v_event_expr text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_usage := public._admin_safe_table_exists('public.usage_events');
  v_has_usage_created_at := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'created_at');
  v_has_usage_success := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'success');
  v_has_usage_failure_code := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'failure_code');
  v_has_usage_event_key := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'event_key');
  v_has_usage_event_name := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'event_name');

  v_has_audit := public._admin_safe_table_exists('public.admin_audit_log');
  v_has_audit_created_at := v_has_audit and public._admin_safe_column_exists('public', 'admin_audit_log', 'created_at');

  v_has_support := public._admin_safe_table_exists('public.admin_support_sessions');
  v_has_support_opened_at := v_has_support and public._admin_safe_column_exists('public', 'admin_support_sessions', 'opened_at');

  v_fail_pred := case
    when v_has_usage_success and v_has_usage_failure_code then '(ue.success is false or ue.failure_code is not null)'
    when v_has_usage_success then '(ue.success is false)'
    when v_has_usage_failure_code then '(ue.failure_code is not null)'
    else 'false'
  end;

  v_event_expr := case
    when v_has_usage_event_key then 'ue.event_key'
    when v_has_usage_event_name then 'ue.event_name'
    else $q$''::text$q$
  end;

  v_sql :=
    'select '
    || case
      when v_has_usage and v_has_usage_created_at then $q$(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval '24 hours')$q$
      else '0::bigint'
    end || ' as recent_usage_events_24h, '
    || case
      when v_has_usage and v_has_usage_created_at and (v_has_usage_success or v_has_usage_failure_code) then
        '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ' || v_fail_pred || ')'
      else '0::bigint'
    end || ' as recent_errors_24h, '
    || case
      when v_has_usage and v_has_usage_created_at and (v_has_usage_event_key or v_has_usage_event_name) and (v_has_usage_success or v_has_usage_failure_code) then
        '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ' || v_event_expr || ' ilike ''%upload%'' and ' || v_fail_pred || ')'
      else '0::bigint'
    end || ' as failed_upload_events_24h, '
    || case
      when v_has_usage and v_has_usage_created_at and (v_has_usage_event_key or v_has_usage_event_name) and (v_has_usage_success or v_has_usage_failure_code) then
        '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ' || v_event_expr || ' ilike ''%sync%'' and ' || v_fail_pred || ')'
      else '0::bigint'
    end || ' as failed_sync_events_24h, '
    || case when v_has_usage and v_has_usage_created_at then '(select max(ue.created_at) from public.usage_events ue)' else 'null::timestamptz' end
    || ' as latest_usage_event_at, '
    || case when v_has_audit and v_has_audit_created_at then '(select max(al.created_at) from public.admin_audit_log al)' else 'null::timestamptz' end
    || ' as latest_audit_event_at, '
    || case when v_has_support and v_has_support_opened_at then '(select max(ss.opened_at) from public.admin_support_sessions ss)' else 'null::timestamptz' end
    || ' as latest_support_session_at';

  return query execute v_sql;
end;
$$;

revoke all on function public.admin_get_country_usage_summary() from public;
revoke all on function public.admin_get_country_usage_summary() from anon;
grant execute on function public.admin_get_country_usage_summary() to authenticated;

revoke all on function public.admin_get_system_health_summary() from public;
revoke all on function public.admin_get_system_health_summary() from anon;
grant execute on function public.admin_get_system_health_summary() to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;

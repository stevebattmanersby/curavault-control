-- CuraVault Control Site: Complete live-data admin-safe reporting RPCs
--
-- PRIVACY + SECURITY REQUIREMENTS (hard requirements)
-- - Do NOT modify any existing health tables.
-- - Do NOT weaken RLS on existing tables.
-- - Do NOT return raw health content (titles, notes, values, names, file paths, URLs, prompts/responses, etc.).
-- - SECURITY DEFINER + must gate access using public.is_active_admin().
-- - Grant EXECUTE only to authenticated; revoke from anon/public.
-- - Set a safe search_path.
-- - Functions must be robust to missing tables/columns (return 0/NULL instead of failing).

begin;

-- -----------------------------------------------------------------------------
-- Drop/replace (safe evolution of return shapes)
-- -----------------------------------------------------------------------------

drop function if exists public.admin_get_storage_summary();
drop function if exists public.admin_get_ai_usage_summary();
drop function if exists public.admin_get_compliance_summary();
drop function if exists public.admin_get_support_summary();
drop function if exists public.admin_get_plan_permission_summary();
drop function if exists public.admin_get_audit_summary();
drop function if exists public.admin_get_system_health_summary_v2();

-- -----------------------------------------------------------------------------
-- 1) Storage summary
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_storage_summary()
returns table(
  total_document_count bigint,
  total_storage_used_mb bigint,
  average_storage_per_user_mb bigint,
  users_over_storage_limit bigint,
  users_near_storage_limit bigint,
  failed_upload_events_24h bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_docs boolean;
  v_has_doc_owner boolean;
  v_has_doc_size boolean;
  v_has_entitlements boolean;
  v_has_ent_user_id boolean;
  v_has_ent_storage_limit boolean;
  v_has_usage boolean;
  v_has_usage_created_at boolean;
  v_has_usage_event_key boolean;
  v_has_usage_success boolean;
  v_has_usage_failure_code boolean;
  v_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_docs := public._admin_safe_table_exists('public.medical_documents');
  v_has_doc_owner := v_has_docs and public._admin_safe_column_exists('public', 'medical_documents', 'owner_user_id');
  v_has_doc_size := v_has_docs and (
    public._admin_safe_column_exists('public', 'medical_documents', 'file_size')
    or public._admin_safe_column_exists('public', 'medical_documents', 'file_size_bytes')
    or public._admin_safe_column_exists('public', 'medical_documents', 'size_bytes')
  );

  v_has_entitlements := public._admin_safe_table_exists('public.user_entitlements');
  v_has_ent_user_id := v_has_entitlements and public._admin_safe_column_exists('public', 'user_entitlements', 'user_id');
  v_has_ent_storage_limit := v_has_entitlements and (
    public._admin_safe_column_exists('public', 'user_entitlements', 'storage_limit_mb')
    or public._admin_safe_column_exists('public', 'user_entitlements', 'storage_limit_bytes')
  );

  v_has_usage := public._admin_safe_table_exists('public.usage_events');
  v_has_usage_created_at := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'created_at');
  v_has_usage_event_key := v_has_usage and (
    public._admin_safe_column_exists('public', 'usage_events', 'event_key')
    or public._admin_safe_column_exists('public', 'usage_events', 'event_name')
  );
  v_has_usage_success := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'success');
  v_has_usage_failure_code := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'failure_code');

  -- NOTE: Never return document names, file paths, URLs, or contents.
  -- Only aggregated storage metrics.
  v_sql :=
    'with '
    || case
      when v_has_docs and v_has_doc_owner and v_has_doc_size then
        -- Choose whichever file size column exists.
        'doc_sizes as ('
        || 'select '
        || 'md.owner_user_id as user_id, '
        || 'coalesce(sum(' ||
            case
              when public._admin_safe_column_exists('public', 'medical_documents', 'file_size_bytes') then 'md.file_size_bytes'
              when public._admin_safe_column_exists('public', 'medical_documents', 'size_bytes') then 'md.size_bytes'
              else 'md.file_size'
            end
          || '),0)::bigint as total_bytes '
        || 'from public.medical_documents md '
        || 'where md.owner_user_id is not null '
        || 'group by 1'
        || ')'
      else
        'doc_sizes as (select null::uuid as user_id, 0::bigint as total_bytes where false)'
    end
    || ', '
    || case
      when v_has_entitlements and v_has_ent_user_id and v_has_ent_storage_limit then
        'ent_limits as ('
        || 'select e.user_id, '
        || case
             when public._admin_safe_column_exists('public', 'user_entitlements', 'storage_limit_bytes') then 'e.storage_limit_bytes'
             else '(e.storage_limit_mb::bigint * 1048576)'
           end
        || '::bigint as limit_bytes '
        || 'from public.user_entitlements e '
        || 'where e.user_id is not null '
        || ')'
      else
        'ent_limits as (select null::uuid as user_id, 0::bigint as limit_bytes where false)'
    end
    || ' '
    || 'select '
    || case when v_has_docs then '(select count(*)::bigint from public.medical_documents)' else '0::bigint' end
    || ' as total_document_count, '
    || case when v_has_docs and v_has_doc_size then '(select coalesce(sum(ds.total_bytes),0)::bigint from doc_sizes ds) / 1048576' else '0::bigint' end
    || ' as total_storage_used_mb, '
    || case when v_has_docs and v_has_doc_size then '(select case when count(*) = 0 then 0 else round(avg(ds.total_bytes / 1048576.0))::bigint end from doc_sizes ds)' else '0::bigint' end
    || ' as average_storage_per_user_mb, '
    || case
      when v_has_docs and v_has_doc_size and v_has_entitlements and v_has_ent_user_id and v_has_ent_storage_limit then
        '(select count(*)::bigint from doc_sizes ds join ent_limits el on el.user_id = ds.user_id where el.limit_bytes > 0 and ds.total_bytes > el.limit_bytes)'
      else
        '0::bigint'
    end
    || ' as users_over_storage_limit, '
    || case
      when v_has_docs and v_has_doc_size and v_has_entitlements and v_has_ent_user_id and v_has_ent_storage_limit then
        '(select count(*)::bigint from doc_sizes ds join ent_limits el on el.user_id = ds.user_id where el.limit_bytes > 0 and ds.total_bytes >= (el.limit_bytes * 0.8) and ds.total_bytes <= el.limit_bytes)'
      else
        '0::bigint'
    end
    || ' as users_near_storage_limit, '
    || case
      when v_has_usage and v_has_usage_created_at and v_has_usage_event_key and (v_has_usage_success or v_has_usage_failure_code) then
        '(select count(*)::bigint from public.usage_events ue '
        || 'where ue.created_at > now() - interval ''24 hours'' '
        || 'and ('
        || case
          when public._admin_safe_column_exists('public', 'usage_events', 'event_key') then 'ue.event_key'
          else 'ue.event_name'
        end
        || ' ilike ''%upload%'' '
        || ') and ('
        || case
          when v_has_usage_success and v_has_usage_failure_code then '(ue.success is false or ue.failure_code is not null)'
          when v_has_usage_success then '(ue.success is false)'
          else '(ue.failure_code is not null)'
        end
        || '))'
      else
        '0::bigint'
    end
    || ' as failed_upload_events_24h';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2) AI usage summary (aggregate-only)
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_ai_usage_summary()
returns table(
  ai_request_count bigint,
  input_tokens bigint,
  output_tokens bigint,
  total_tokens bigint,
  estimated_cost numeric,
  failed_ai_requests bigint,
  users_near_ai_limit bigint,
  users_over_ai_limit bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_usage boolean;
  v_has_user_id boolean;
  v_has_created_at boolean;
  v_has_event_key boolean;
  v_has_event_name boolean;
  v_has_success boolean;
  v_has_failure_code boolean;
  v_has_tokens_in boolean;
  v_has_tokens_out boolean;
  v_has_cost boolean;
  v_has_entitlements boolean;
  v_has_ent_user_id boolean;
  v_has_ai_limit boolean;
  v_sql text;
  v_event_expr text;
  v_fail_pred text;
  v_tokens_in_expr text;
  v_tokens_out_expr text;
  v_cost_expr text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_usage := public._admin_safe_table_exists('public.usage_events');
  if not v_has_usage then
    ai_request_count := 0;
    input_tokens := 0;
    output_tokens := 0;
    total_tokens := 0;
    estimated_cost := 0;
    failed_ai_requests := 0;
    users_near_ai_limit := 0;
    users_over_ai_limit := 0;
    return next;
    return;
  end if;

  v_has_user_id := public._admin_safe_column_exists('public', 'usage_events', 'user_id');
  v_has_created_at := public._admin_safe_column_exists('public', 'usage_events', 'created_at');
  v_has_event_key := public._admin_safe_column_exists('public', 'usage_events', 'event_key');
  v_has_event_name := public._admin_safe_column_exists('public', 'usage_events', 'event_name');
  v_has_success := public._admin_safe_column_exists('public', 'usage_events', 'success');
  v_has_failure_code := public._admin_safe_column_exists('public', 'usage_events', 'failure_code');
  v_has_tokens_in := public._admin_safe_column_exists('public', 'usage_events', 'estimated_tokens_input');
  v_has_tokens_out := public._admin_safe_column_exists('public', 'usage_events', 'estimated_tokens_output');
  v_has_cost := public._admin_safe_column_exists('public', 'usage_events', 'estimated_cost');

  v_has_entitlements := public._admin_safe_table_exists('public.user_entitlements');
  v_has_ent_user_id := v_has_entitlements and public._admin_safe_column_exists('public', 'user_entitlements', 'user_id');
  v_has_ai_limit := v_has_entitlements and (
    public._admin_safe_column_exists('public', 'user_entitlements', 'ai_token_limit')
    or public._admin_safe_column_exists('public', 'user_entitlements', 'ai_tokens_limit')
  );

  v_event_expr := case
    when v_has_event_key then 'ue.event_key'
    when v_has_event_name then 'ue.event_name'
    else $q$''::text$q$
  end;

  v_fail_pred := case
    when v_has_success and v_has_failure_code then '(ue.success is false or ue.failure_code is not null)'
    when v_has_success then '(ue.success is false)'
    when v_has_failure_code then '(ue.failure_code is not null)'
    else 'false'
  end;

  v_tokens_in_expr := case when v_has_tokens_in then 'coalesce(ue.estimated_tokens_input,0)' else '0' end;
  v_tokens_out_expr := case when v_has_tokens_out then 'coalesce(ue.estimated_tokens_output,0)' else '0' end;
  v_cost_expr := case when v_has_cost then 'coalesce(ue.estimated_cost,0)' else '0' end;

  -- We intentionally define "AI requests" using event keys/names containing 'ai'.
  -- This avoids returning prompts/responses and keeps it strictly operational.
  v_sql :=
    'with ai_events as ('
    || 'select '
    || (case when v_has_user_id then 'ue.user_id' else 'null::uuid' end) || ' as user_id, '
    || (case when v_has_created_at then 'ue.created_at' else 'null::timestamptz' end) || ' as created_at, '
    || v_tokens_in_expr || '::bigint as in_tokens, '
    || v_tokens_out_expr || '::bigint as out_tokens, '
    || v_cost_expr || '::numeric as cost, '
    || case when v_fail_pred <> 'false' then v_fail_pred else 'false' end || ' as is_failed '
    || 'from public.usage_events ue '
    || 'where '
    || case
      when v_has_event_key or v_has_event_name then '(' || v_event_expr || ' ilike ''%ai%'' )'
      else 'false'
    end
    || ')'
    || ', per_user as ('
    || 'select user_id, coalesce(sum(in_tokens + out_tokens),0)::bigint as tokens_30d '
    || 'from ai_events '
    || case when v_has_user_id and v_has_created_at then $q$where created_at > now() - interval '30 days'$q$ else '' end
    || 'group by 1'
    || ')'
    || ', ent as ('
    || case
      when v_has_entitlements and v_has_ent_user_id and v_has_ai_limit then
        'select e.user_id, '
        || case
             when public._admin_safe_column_exists('public', 'user_entitlements', 'ai_token_limit') then 'e.ai_token_limit'
             else 'e.ai_tokens_limit'
           end
        || '::bigint as token_limit '
        || 'from public.user_entitlements e '
      else
        'select null::uuid as user_id, 0::bigint as token_limit where false'
    end
    || ') '
    || 'select '
    || '(select count(*)::bigint from ai_events) as ai_request_count, '
    || '(select coalesce(sum(in_tokens),0)::bigint from ai_events) as input_tokens, '
    || '(select coalesce(sum(out_tokens),0)::bigint from ai_events) as output_tokens, '
    || '(select coalesce(sum(in_tokens + out_tokens),0)::bigint from ai_events) as total_tokens, '
    || '(select coalesce(sum(cost),0)::numeric from ai_events) as estimated_cost, '
    || '(select count(*)::bigint from ai_events where is_failed is true) as failed_ai_requests, '
    || case
      when v_has_entitlements and v_has_ent_user_id and v_has_ai_limit and v_has_user_id then
        '(select count(*)::bigint from per_user pu join ent e on e.user_id = pu.user_id where e.token_limit > 0 and pu.tokens_30d >= (e.token_limit * 0.8) and pu.tokens_30d <= e.token_limit)'
      else
        '0::bigint'
    end
    || ' as users_near_ai_limit, '
    || case
      when v_has_entitlements and v_has_ent_user_id and v_has_ai_limit and v_has_user_id then
        '(select count(*)::bigint from per_user pu join ent e on e.user_id = pu.user_id where e.token_limit > 0 and pu.tokens_30d > e.token_limit)'
      else
        '0::bigint'
    end
    || ' as users_over_ai_limit';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3) Compliance summary (metadata-only)
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_compliance_summary()
returns table(
  total_requests bigint,
  open_requests bigint,
  in_progress_requests bigint,
  completed_requests bigint,
  failed_requests bigint,
  deletion_requests bigint,
  export_requests bigint,
  latest_request_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_table boolean;
  v_has_status boolean;
  v_has_type boolean;
  v_has_created_at boolean;
  v_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_table := public._admin_safe_table_exists('public.admin_compliance_requests');
  if not v_has_table then
    total_requests := 0;
    open_requests := 0;
    in_progress_requests := 0;
    completed_requests := 0;
    failed_requests := 0;
    deletion_requests := 0;
    export_requests := 0;
    latest_request_at := null;
    return next;
    return;
  end if;

  v_has_status := public._admin_safe_column_exists('public', 'admin_compliance_requests', 'status');
  v_has_type := public._admin_safe_column_exists('public', 'admin_compliance_requests', 'request_type');
  v_has_created_at := public._admin_safe_column_exists('public', 'admin_compliance_requests', 'created_at');

  v_sql :=
    'select '
    || 'count(*)::bigint as total_requests, '
    || (case when v_has_status then $q$count(*) filter (where status = 'open')::bigint$q$ else '0::bigint' end) || ' as open_requests, '
    || (case when v_has_status then $q$count(*) filter (where status in ('in_progress','in_review','review'))::bigint$q$ else '0::bigint' end) || ' as in_progress_requests, '
    || (case when v_has_status then $q$count(*) filter (where status in ('completed','fulfilled','done'))::bigint$q$ else '0::bigint' end) || ' as completed_requests, '
    || (case when v_has_status then $q$count(*) filter (where status in ('failed','rejected','error'))::bigint$q$ else '0::bigint' end) || ' as failed_requests, '
    || (case when v_has_type then $q$count(*) filter (where request_type ilike '%delete%')::bigint$q$ else '0::bigint' end) || ' as deletion_requests, '
    || (case when v_has_type then $q$count(*) filter (where request_type ilike '%export%')::bigint$q$ else '0::bigint' end) || ' as export_requests, '
    || (case when v_has_created_at then 'max(created_at)' else 'null::timestamptz' end) || ' as latest_request_at '
    || 'from public.admin_compliance_requests';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4) Support summary (metadata-only)
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_support_summary()
returns table(
  total_sessions bigint,
  open_sessions bigint,
  active_sessions bigint,
  closed_sessions bigint,
  expired_sessions bigint,
  latest_session_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_table boolean;
  v_has_status boolean;
  v_has_opened_at boolean;
  v_has_updated_at boolean;
  v_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_table := public._admin_safe_table_exists('public.admin_support_sessions');
  if not v_has_table then
    total_sessions := 0;
    open_sessions := 0;
    active_sessions := 0;
    closed_sessions := 0;
    expired_sessions := 0;
    latest_session_at := null;
    return next;
    return;
  end if;

  v_has_status := public._admin_safe_column_exists('public', 'admin_support_sessions', 'status');
  v_has_opened_at := public._admin_safe_column_exists('public', 'admin_support_sessions', 'opened_at');
  v_has_updated_at := public._admin_safe_column_exists('public', 'admin_support_sessions', 'updated_at');

  -- Active vs open: "active" is best-effort defined as open + updated recently.
  v_sql :=
    'select '
    || 'count(*)::bigint as total_sessions, '
    || (case when v_has_status then $q$count(*) filter (where status = 'open')::bigint$q$ else '0::bigint' end) || ' as open_sessions, '
    || (case when v_has_status and v_has_updated_at then $q$count(*) filter (where status = 'open' and updated_at > now() - interval '30 minutes')::bigint$q$ else '0::bigint' end) || ' as active_sessions, '
    || (case when v_has_status then $q$count(*) filter (where status = 'closed')::bigint$q$ else '0::bigint' end) || ' as closed_sessions, '
    || (case when v_has_status then $q$count(*) filter (where status in ('expired','timeout'))::bigint$q$ else '0::bigint' end) || ' as expired_sessions, '
    || (case when v_has_opened_at then 'max(opened_at)' else 'null::timestamptz' end) || ' as latest_session_at '
    || 'from public.admin_support_sessions';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5) Plan + permission summary (aggregate-only)
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_plan_permission_summary()
returns table(
  plan text,
  user_count bigint,
  active_count bigint,
  storage_limit_mb bigint,
  ai_token_limit bigint,
  profile_limit bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_ent boolean;
  v_has_plan boolean;
  v_has_status boolean;
  v_has_storage_limit boolean;
  v_has_ai_limit boolean;
  v_has_profile_limit boolean;
  v_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_ent := public._admin_safe_table_exists('public.user_entitlements');
  if not v_has_ent then
    return;
  end if;

  v_has_plan := public._admin_safe_column_exists('public', 'user_entitlements', 'plan')
    or public._admin_safe_column_exists('public', 'user_entitlements', 'plan_key');
  v_has_status := public._admin_safe_column_exists('public', 'user_entitlements', 'subscription_status')
    or public._admin_safe_column_exists('public', 'user_entitlements', 'status');

  v_has_storage_limit := public._admin_safe_column_exists('public', 'user_entitlements', 'storage_limit_mb');
  v_has_ai_limit := public._admin_safe_column_exists('public', 'user_entitlements', 'ai_token_limit')
    or public._admin_safe_column_exists('public', 'user_entitlements', 'ai_tokens_limit');
  v_has_profile_limit := public._admin_safe_column_exists('public', 'user_entitlements', 'profile_limit')
    or public._admin_safe_column_exists('public', 'user_entitlements', 'profiles_limit');

  v_sql :=
    'select '
    || case
      when public._admin_safe_column_exists('public', 'user_entitlements', 'plan') then $q$coalesce(nullif(e.plan,''), 'unknown')$q$
      when public._admin_safe_column_exists('public', 'user_entitlements', 'plan_key') then $q$coalesce(nullif(e.plan_key,''), 'unknown')$q$
      else $q$'unknown'::text$q$
    end
    || ' as plan, '
    || 'count(*)::bigint as user_count, '
    || case
      when public._admin_safe_column_exists('public', 'user_entitlements', 'subscription_status') then $q$count(*) filter (where e.subscription_status in ('active','trialing'))::bigint$q$
      when public._admin_safe_column_exists('public', 'user_entitlements', 'status') then $q$count(*) filter (where e.status in ('active','trialing'))::bigint$q$
      else '0::bigint'
    end
    || ' as active_count, '
    || (case when v_has_storage_limit then 'max(e.storage_limit_mb)::bigint' else 'null::bigint' end) || ' as storage_limit_mb, '
    || (case
      when public._admin_safe_column_exists('public', 'user_entitlements', 'ai_token_limit') then 'max(e.ai_token_limit)::bigint'
      when public._admin_safe_column_exists('public', 'user_entitlements', 'ai_tokens_limit') then 'max(e.ai_tokens_limit)::bigint'
      else 'null::bigint'
    end) || ' as ai_token_limit, '
    || (case
      when public._admin_safe_column_exists('public', 'user_entitlements', 'profile_limit') then 'max(e.profile_limit)::bigint'
      when public._admin_safe_column_exists('public', 'user_entitlements', 'profiles_limit') then 'max(e.profiles_limit)::bigint'
      else 'null::bigint'
    end) || ' as profile_limit '
    || 'from public.user_entitlements e '
    || 'group by 1 '
    || 'order by user_count desc, plan asc';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 6) Audit summary (metadata-only)
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_audit_summary()
returns table(
  total_audit_events bigint,
  audit_events_24h bigint,
  failed_admin_actions_24h bigint,
  latest_audit_event_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_table boolean;
  v_has_created_at boolean;
  v_has_result boolean;
  v_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_table := public._admin_safe_table_exists('public.admin_audit_log');
  if not v_has_table then
    total_audit_events := 0;
    audit_events_24h := 0;
    failed_admin_actions_24h := 0;
    latest_audit_event_at := null;
    return next;
    return;
  end if;

  v_has_created_at := public._admin_safe_column_exists('public', 'admin_audit_log', 'created_at');
  v_has_result := public._admin_safe_column_exists('public', 'admin_audit_log', 'result');

  -- IMPORTANT: This function never returns prev/next JSON payloads.
  v_sql :=
    'select '
    || 'count(*)::bigint as total_audit_events, '
    || (case when v_has_created_at then $q$count(*) filter (where created_at > now() - interval '24 hours')::bigint$q$ else '0::bigint' end) || ' as audit_events_24h, '
    || (case
      when v_has_created_at and v_has_result then $q$count(*) filter (where created_at > now() - interval '24 hours' and result in ('failure','failed','denied'))::bigint$q$
      else '0::bigint'
    end) || ' as failed_admin_actions_24h, '
    || (case when v_has_created_at then 'max(created_at)' else 'null::timestamptz' end) || ' as latest_audit_event_at '
    || 'from public.admin_audit_log';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- 7) System health summary v2 (operational aggregates only)
-- -----------------------------------------------------------------------------

create or replace function public.admin_get_system_health_summary_v2()
returns table(
  recent_usage_events_24h bigint,
  recent_errors_24h bigint,
  failed_upload_events_24h bigint,
  failed_sync_events_24h bigint,
  latest_usage_event_at timestamptz,
  latest_audit_event_at timestamptz,
  latest_support_session_at timestamptz,
  latest_compliance_request_at timestamptz
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
  v_has_compliance boolean;
  v_has_compliance_opened_at boolean;
  v_has_compliance_created_at boolean;
  v_sql text;
  v_fail_pred text;
  v_event_expr text;
begin
  perform public._admin_safe_assert_active_admin();

  v_has_usage := public._admin_safe_table_exists('public.usage_events');
  v_has_usage_created_at := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'created_at');
  v_has_usage_success := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'success');
  v_has_usage_failure_code := v_has_usage and public._admin_safe_column_exists('public', 'usage_events', 'failure_code');
  v_has_usage_event_key := v_has_usage and (
    public._admin_safe_column_exists('public', 'usage_events', 'event_key')
    or public._admin_safe_column_exists('public', 'usage_events', 'event_name')
  );

  v_has_audit := public._admin_safe_table_exists('public.admin_audit_log');
  v_has_audit_created_at := v_has_audit and public._admin_safe_column_exists('public', 'admin_audit_log', 'created_at');

  v_has_support := public._admin_safe_table_exists('public.admin_support_sessions');
  v_has_support_opened_at := v_has_support and public._admin_safe_column_exists('public', 'admin_support_sessions', 'opened_at');

  v_has_compliance := public._admin_safe_table_exists('public.admin_compliance_requests');
  v_has_compliance_opened_at := v_has_compliance and public._admin_safe_column_exists('public', 'admin_compliance_requests', 'opened_at');
  v_has_compliance_created_at := v_has_compliance and public._admin_safe_column_exists('public', 'admin_compliance_requests', 'created_at');

  v_fail_pred := case
    when v_has_usage_success and v_has_usage_failure_code then '(ue.success is false or ue.failure_code is not null)'
    when v_has_usage_success then '(ue.success is false)'
    when v_has_usage_failure_code then '(ue.failure_code is not null)'
    else 'false'
  end;

  v_event_expr := case
    when public._admin_safe_column_exists('public', 'usage_events', 'event_key') then 'ue.event_key'
    when public._admin_safe_column_exists('public', 'usage_events', 'event_name') then 'ue.event_name'
    else $q$''::text$q$
  end;

  v_sql :=
    'select '
    || case when v_has_usage and v_has_usage_created_at then
      $q$(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval '24 hours')$q$
    else '0::bigint' end
    || ' as recent_usage_events_24h, '
    || case when v_has_usage and v_has_usage_created_at and (v_has_usage_success or v_has_usage_failure_code) then
      '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ' || v_fail_pred || ')'
    else '0::bigint' end
    || ' as recent_errors_24h, '
    || case when v_has_usage and v_has_usage_created_at and v_has_usage_event_key and (v_has_usage_success or v_has_usage_failure_code) then
      '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ' || v_event_expr || $q$ ilike '%upload%' and $q$ || v_fail_pred || ')'
    else '0::bigint' end
    || ' as failed_upload_events_24h, '
    || case when v_has_usage and v_has_usage_created_at and v_has_usage_event_key and (v_has_usage_success or v_has_usage_failure_code) then
      '(select count(*)::bigint from public.usage_events ue where ue.created_at > now() - interval ''24 hours'' and ' || v_event_expr || $q$ ilike '%sync%' and $q$ || v_fail_pred || ')'
    else '0::bigint' end
    || ' as failed_sync_events_24h, '
    || case when v_has_usage and v_has_usage_created_at then '(select max(ue.created_at) from public.usage_events ue)' else 'null::timestamptz' end
    || ' as latest_usage_event_at, '
    || case when v_has_audit and v_has_audit_created_at then '(select max(al.created_at) from public.admin_audit_log al)' else 'null::timestamptz' end
    || ' as latest_audit_event_at, '
    || case when v_has_support and v_has_support_opened_at then '(select max(ss.opened_at) from public.admin_support_sessions ss)' else 'null::timestamptz' end
    || ' as latest_support_session_at, '
    || case
      when v_has_compliance and v_has_compliance_opened_at then '(select max(cr.opened_at) from public.admin_compliance_requests cr)'
      when v_has_compliance and v_has_compliance_created_at then '(select max(cr.created_at) from public.admin_compliance_requests cr)'
      else 'null::timestamptz'
    end
    || ' as latest_compliance_request_at';

  return query execute v_sql;
end;
$$;

-- -----------------------------------------------------------------------------
-- Execution privileges: authenticated only. Active-admin gate is inside each RPC.
-- -----------------------------------------------------------------------------

revoke all on function public.admin_get_storage_summary() from public;
revoke all on function public.admin_get_storage_summary() from anon;
grant execute on function public.admin_get_storage_summary() to authenticated;

revoke all on function public.admin_get_ai_usage_summary() from public;
revoke all on function public.admin_get_ai_usage_summary() from anon;
grant execute on function public.admin_get_ai_usage_summary() to authenticated;

revoke all on function public.admin_get_compliance_summary() from public;
revoke all on function public.admin_get_compliance_summary() from anon;
grant execute on function public.admin_get_compliance_summary() to authenticated;

revoke all on function public.admin_get_support_summary() from public;
revoke all on function public.admin_get_support_summary() from anon;
grant execute on function public.admin_get_support_summary() to authenticated;

revoke all on function public.admin_get_plan_permission_summary() from public;
revoke all on function public.admin_get_plan_permission_summary() from anon;
grant execute on function public.admin_get_plan_permission_summary() to authenticated;

revoke all on function public.admin_get_audit_summary() from public;
revoke all on function public.admin_get_audit_summary() from anon;
grant execute on function public.admin_get_audit_summary() to authenticated;

revoke all on function public.admin_get_system_health_summary_v2() from public;
revoke all on function public.admin_get_system_health_summary_v2() from anon;
grant execute on function public.admin_get_system_health_summary_v2() to authenticated;

commit;

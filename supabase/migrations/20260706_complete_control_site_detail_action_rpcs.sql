--
-- Complete the live Control Site detail/action paths with privacy-safe RPCs.
--
-- These functions deliberately return metadata and aggregate counts only. They
-- do not expose document names, health notes, values, prompts, file paths, or
-- other user-authored health content.

begin;

create or replace function public.admin_get_user_account_detail(
  p_user_id uuid,
  p_include_email boolean default false
)
returns table(
  user_id text,
  email text,
  country text,
  created_at timestamptz,
  last_login_at timestamptz,
  last_active_at timestamptz,
  account_status text,
  plan text,
  billing_status text,
  subscription_provider text,
  profile_count bigint,
  record_count bigint,
  appointment_count bigint,
  medication_count bigint,
  vaccination_count bigint,
  document_count bigint,
  storage_used_bytes bigint,
  ai_tokens_used_this_month bigint,
  ai_requests_this_month bigint,
  platform text,
  app_version text,
  last_sync_at timestamptz,
  failed_sync_count_30d bigint,
  failed_upload_count_30d bigint,
  last_known_error_code text,
  device_type text,
  os_version text,
  storage_limit_bytes bigint,
  ai_token_limit_this_month bigint,
  profile_limit bigint,
  upload_limit bigint,
  open_support_sessions bigint,
  consent_status text,
  ticket_reference text,
  support_notes text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb;
begin
  perform public._admin_safe_assert_active_admin();
  if public.current_admin_role() not in ('owner', 'support') then
    raise exception 'Access denied: user detail' using errcode = '42501';
  end if;

  select to_jsonb(t)
  into v_row
  from public.admin_get_user_usage_summary() t
  where (t.user_id)::text = p_user_id::text
  limit 1;

  user_id := p_user_id::text;
  email := case when p_include_email then v_row->>'email' else null end;
  country := coalesce(v_row->>'country', '-');
  created_at := coalesce((v_row->>'created_at')::timestamptz, now());
  last_login_at := nullif(v_row->>'last_sign_in_at', '')::timestamptz;
  last_active_at := last_login_at;
  account_status := coalesce(v_row->>'account_status', 'unknown');
  plan := coalesce(v_row->>'plan', '-');
  billing_status := coalesce(v_row->>'billing_status', 'unknown');
  subscription_provider := coalesce(v_row->>'subscription_provider', 'unknown');
  profile_count := coalesce((v_row->>'profile_count')::bigint, 0);
  record_count := coalesce((v_row->>'medical_record_count')::bigint, 0);
  appointment_count := coalesce((v_row->>'appointment_count')::bigint, 0);
  medication_count := coalesce((v_row->>'medication_count')::bigint, 0);
  vaccination_count := coalesce((v_row->>'vaccination_count')::bigint, 0);
  document_count := coalesce((v_row->>'medical_document_count')::bigint, 0);
  storage_used_bytes := coalesce((v_row->>'storage_used_bytes')::bigint, 0);
  ai_tokens_used_this_month := coalesce((v_row->>'ai_tokens_this_month')::bigint, 0);
  ai_requests_this_month := coalesce((v_row->>'ai_requests_this_month')::bigint, 0);
  platform := coalesce(v_row->>'platform', '-');
  app_version := coalesce(v_row->>'app_version', '-');
  last_sync_at := null;
  failed_sync_count_30d := 0;
  failed_upload_count_30d := 0;
  last_known_error_code := null;
  device_type := '-';
  os_version := '-';
  storage_limit_bytes := coalesce((v_row->>'storage_limit_bytes')::bigint, 0);
  ai_token_limit_this_month := coalesce((v_row->>'ai_token_limit_this_month')::bigint, 0);
  profile_limit := coalesce((v_row->>'profile_limit')::bigint, 0);
  upload_limit := null;

  select count(*)::bigint, max(ticket_id)
  into open_support_sessions, ticket_reference
  from public.admin_support_sessions s
  where s.target_user_id = p_user_id
    and s.status = 'open';

  consent_status := case when open_support_sessions > 0 then 'on_file' else 'missing' end;
  support_notes := null;
  return next;
end;
$$;

create or replace function public.admin_get_support_session_detail(
  p_support_session_id uuid,
  p_include_email boolean default false
)
returns table(
  support_session_id text,
  user_id text,
  email text,
  account_status text,
  plan text,
  app_version text,
  platform text,
  country text,
  last_login_at timestamptz,
  last_sync_at timestamptz,
  failed_sync_count bigint,
  failed_upload_count bigint,
  storage_used_bytes bigint,
  storage_limit_bytes bigint,
  ai_tokens_used bigint,
  ai_limit bigint,
  open_errors text[],
  admin_notes text,
  consent_window_status text,
  status text,
  access_expires_at timestamptz,
  ticket_reference text,
  updated_at timestamptz,
  assigned_admin text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.admin_support_sessions%rowtype;
  v_user jsonb;
begin
  perform public._admin_safe_assert_active_admin();
  if public.current_admin_role() not in ('owner', 'admin', 'support') then
    raise exception 'Access denied: support detail' using errcode = '42501';
  end if;

  select *
  into v_session
  from public.admin_support_sessions
  where id = p_support_session_id;

  if not found then
    return;
  end if;

  if v_session.target_user_id is not null then
    select to_jsonb(t)
    into v_user
    from public.admin_get_user_usage_summary() t
    where (t.user_id)::text = v_session.target_user_id::text
    limit 1;
  end if;

  support_session_id := v_session.id::text;
  user_id := coalesce(v_session.target_user_id::text, '');
  email := case when p_include_email then v_user->>'email' else null end;
  account_status := coalesce(v_user->>'account_status', 'unknown');
  plan := coalesce(v_user->>'plan', '-');
  app_version := coalesce(v_user->>'app_version', '-');
  platform := coalesce(v_user->>'platform', '-');
  country := coalesce(v_user->>'country', '-');
  last_login_at := nullif(v_user->>'last_sign_in_at', '')::timestamptz;
  last_sync_at := null;
  failed_sync_count := 0;
  failed_upload_count := 0;
  storage_used_bytes := coalesce((v_user->>'storage_used_bytes')::bigint, 0);
  storage_limit_bytes := coalesce((v_user->>'storage_limit_bytes')::bigint, 0);
  ai_tokens_used := coalesce((v_user->>'ai_tokens_this_month')::bigint, 0);
  ai_limit := coalesce((v_user->>'ai_token_limit_this_month')::bigint, 0);
  open_errors := array[]::text[];

  select string_agg(left(n.note_redacted, 280), E'\n' order by n.created_at desc)
  into admin_notes
  from public.admin_support_notes n
  where n.support_session_id = p_support_session_id;

  consent_window_status := case
    when v_session.status = 'closed' then 'revoked'
    when v_session.closed_at is not null then 'expired'
    else 'active'
  end;
  status := case when v_session.status = 'open' then 'active' else v_session.status end;
  access_expires_at := v_session.closed_at;
  ticket_reference := v_session.ticket_id;
  updated_at := v_session.updated_at;
  assigned_admin := v_session.opened_by_admin_user_id::text;
  return next;
end;
$$;

create or replace function public.admin_run_user_diagnostics(p_user_id uuid)
returns table(
  id text,
  title text,
  status text,
  explanation text,
  suggested_action text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_detail record;
begin
  perform public._admin_safe_assert_active_admin();
  if public.current_admin_role() not in ('owner', 'admin', 'support') then
    raise exception 'Access denied: diagnostics' using errcode = '42501';
  end if;

  select *
  into v_detail
  from public.admin_get_user_account_detail(p_user_id, false)
  limit 1;

  id := 'account';
  title := 'Account metadata';
  status := case when v_detail.user_id is null then 'fail' else 'pass' end;
  explanation := case when v_detail.user_id is null then 'No privacy-safe account summary was found.' else 'Privacy-safe account summary is available.' end;
  suggested_action := case when v_detail.user_id is null then 'Check that summary RPCs are deployed and the user id is correct.' else 'No action required.' end;
  return next;

  id := 'support_access';
  title := 'Support access';
  status := case when coalesce(v_detail.open_support_sessions, 0) > 0 then 'pass' else 'warning' end;
  explanation := case when coalesce(v_detail.open_support_sessions, 0) > 0 then 'An open support session exists.' else 'No open support session is recorded.' end;
  suggested_action := case when coalesce(v_detail.open_support_sessions, 0) > 0 then 'Continue with support workflow.' else 'Open a support session before taking user-specific support actions.' end;
  return next;

  id := 'recent_errors';
  title := 'Recent technical errors';
  status := case when v_detail.last_known_error_code is null then 'pass' else 'warning' end;
  explanation := coalesce('Last known error code: ' || v_detail.last_known_error_code, 'No recent error code is available in the safe summary.');
  suggested_action := case when v_detail.last_known_error_code is null then 'No action required.' else 'Review aggregate system health before escalating.' end;
  return next;
end;
$$;

create or replace function public.admin_perform_user_action(
  p_target_user_id uuid,
  p_action text,
  p_reason text,
  p_ticket_id text default null,
  p_parameters jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit_id uuid;
begin
  perform public._admin_safe_assert_active_admin();
  if public.current_admin_role() not in ('owner', 'admin', 'support') then
    raise exception 'Access denied: user action' using errcode = '42501';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception 'Reason is required' using errcode = '22023';
  end if;

  insert into public.admin_audit_log (
    admin_user_id, admin_email, target_user_id, target_resource_type,
    target_resource_id, action_type, result, next, reason, ticket_id
  )
  values (
    auth.uid(),
    (select email from public.admin_users where admin_user_id = auth.uid()),
    p_target_user_id,
    'user',
    p_target_user_id::text,
    p_action,
    'success',
    jsonb_build_object('parameters', coalesce(p_parameters, '{}'::jsonb)),
    p_reason,
    p_ticket_id
  )
  returning id into v_audit_id;

  return v_audit_id;
end;
$$;

create or replace function public.admin_perform_support_action(
  p_support_session_id uuid,
  p_target_user_id uuid,
  p_action text,
  p_reason text,
  p_ticket_id text default null,
  p_parameters jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit_id uuid;
  v_note text;
begin
  perform public._admin_safe_assert_active_admin();
  if public.current_admin_role() not in ('owner', 'admin', 'support') then
    raise exception 'Access denied: support action' using errcode = '42501';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception 'Reason is required' using errcode = '22023';
  end if;

  if p_action = 'closeSupportSession' then
    update public.admin_support_sessions
    set status = 'closed',
        closed_by_admin_user_id = auth.uid(),
        closed_at = now(),
        updated_at = now()
    where id = p_support_session_id;
  elsif p_action = 'addSupportNote' then
    v_note := case
      when coalesce(p_parameters, '{}'::jsonb) ? 'note_redacted' then p_parameters->>'note_redacted'
      else '[redacted note omitted; see audit reason]'
    end;

    insert into public.admin_support_notes (
      support_session_id, author_admin_user_id, note_redacted
    )
    values (
      p_support_session_id,
      auth.uid(),
      left(coalesce(nullif(trim(v_note), ''), '[redacted note omitted]'), 280)
    );
  end if;

  insert into public.admin_audit_log (
    admin_user_id, admin_email, target_user_id, target_resource_type,
    target_resource_id, action_type, result, next, reason, ticket_id
  )
  values (
    auth.uid(),
    (select email from public.admin_users where admin_user_id = auth.uid()),
    p_target_user_id,
    'support_session',
    p_support_session_id::text,
    p_action,
    'success',
    jsonb_build_object('parameters', coalesce(p_parameters, '{}'::jsonb)),
    p_reason,
    p_ticket_id
  )
  returning id into v_audit_id;

  return v_audit_id;
end;
$$;

create or replace function public.admin_perform_compliance_action(
  p_target_user_id uuid,
  p_request_id text,
  p_action text,
  p_reason text,
  p_ticket_id text default null,
  p_parameters jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit_id uuid;
  v_request_uuid uuid;
  v_next_status text;
begin
  perform public._admin_safe_assert_active_admin();
  if public.current_admin_role() not in ('owner', 'admin', 'compliance', 'support') then
    raise exception 'Access denied: compliance action' using errcode = '42501';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception 'Reason is required' using errcode = '22023';
  end if;

  if p_request_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_request_uuid := p_request_id::uuid;
  end if;

  v_next_status := case p_action
    when 'markExportInProgress' then 'in_review'
    when 'markDeletionInProgress' then 'in_review'
    when 'markExportComplete' then 'fulfilled'
    when 'markDeletionComplete' then 'fulfilled'
    when 'recordFailureReason' then 'rejected'
    else null
  end;

  if v_request_uuid is not null and v_next_status is not null then
    update public.admin_compliance_requests
    set status = v_next_status,
        closed_by_admin_user_id = case when v_next_status in ('fulfilled', 'rejected') then auth.uid() else closed_by_admin_user_id end,
        closed_at = case when v_next_status in ('fulfilled', 'rejected') then now() else closed_at end,
        updated_at = now()
    where id = v_request_uuid;
  end if;

  insert into public.admin_audit_log (
    admin_user_id, admin_email, target_user_id, target_resource_type,
    target_resource_id, action_type, result, next, reason, ticket_id
  )
  values (
    auth.uid(),
    (select email from public.admin_users where admin_user_id = auth.uid()),
    p_target_user_id,
    'compliance_request',
    p_request_id,
    p_action,
    'success',
    jsonb_build_object('parameters', coalesce(p_parameters, '{}'::jsonb), 'status', v_next_status),
    p_reason,
    p_ticket_id
  )
  returning id into v_audit_id;

  return v_audit_id;
end;
$$;

revoke all on function public.admin_get_user_account_detail(uuid, boolean) from public;
revoke all on function public.admin_get_user_account_detail(uuid, boolean) from anon;
grant execute on function public.admin_get_user_account_detail(uuid, boolean) to authenticated;

revoke all on function public.admin_get_support_session_detail(uuid, boolean) from public;
revoke all on function public.admin_get_support_session_detail(uuid, boolean) from anon;
grant execute on function public.admin_get_support_session_detail(uuid, boolean) to authenticated;

revoke all on function public.admin_run_user_diagnostics(uuid) from public;
revoke all on function public.admin_run_user_diagnostics(uuid) from anon;
grant execute on function public.admin_run_user_diagnostics(uuid) to authenticated;

revoke all on function public.admin_perform_user_action(uuid, text, text, text, jsonb) from public;
revoke all on function public.admin_perform_user_action(uuid, text, text, text, jsonb) from anon;
grant execute on function public.admin_perform_user_action(uuid, text, text, text, jsonb) to authenticated;

revoke all on function public.admin_perform_support_action(uuid, uuid, text, text, text, jsonb) from public;
revoke all on function public.admin_perform_support_action(uuid, uuid, text, text, text, jsonb) from anon;
grant execute on function public.admin_perform_support_action(uuid, uuid, text, text, text, jsonb) to authenticated;

revoke all on function public.admin_perform_compliance_action(uuid, text, text, text, text, jsonb) from public;
revoke all on function public.admin_perform_compliance_action(uuid, text, text, text, text, jsonb) from anon;
grant execute on function public.admin_perform_compliance_action(uuid, text, text, text, text, jsonb) to authenticated;

commit;

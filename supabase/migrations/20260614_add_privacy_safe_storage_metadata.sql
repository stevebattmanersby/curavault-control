-- CuraVault: Privacy-safe storage metadata for admin reporting
--
-- Goal:
-- - Store upload/storage metadata WITHOUT file names, paths, titles, or content.
-- - Enable admin-safe aggregate reporting (counts + bytes only).
--
-- SECURITY REQUIREMENTS
-- - Do NOT modify existing health tables or weaken their RLS.
-- - Do NOT expose raw document fields (file_name, storage_path, title, tags, OCR, etc.).
-- - Admin reporting must remain SECURITY DEFINER and gated by public.is_active_admin().

begin;

-- -----------------------------------------------------------------------------
-- 1) Privacy-safe per-document storage metadata (no names/paths/content)
-- -----------------------------------------------------------------------------

create table if not exists public.document_storage_metadata (
  document_id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  file_size_bytes bigint null,
  storage_size_bytes bigint null,
  mime_type_group text null,
  upload_status text not null default 'uploaded',
  created_at timestamptz not null default now(),
  deleted_at timestamptz null,
  updated_at timestamptz not null default now()
);

comment on table public.document_storage_metadata is
  'Privacy-safe storage metadata for reporting: bytes + status only (no names/paths/content).';

-- Minimal constraints: allow only a coarse mime grouping if provided.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'document_storage_metadata_mime_type_group_check'
  ) then
    alter table public.document_storage_metadata
      add constraint document_storage_metadata_mime_type_group_check
      check (mime_type_group is null or mime_type_group in ('pdf','image','other'));
  end if;
end $$;

-- Keep upload_status flexible (string), but prevent empty.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'document_storage_metadata_upload_status_nonempty'
  ) then
    alter table public.document_storage_metadata
      add constraint document_storage_metadata_upload_status_nonempty
      check (char_length(trim(upload_status)) > 0);
  end if;
end $$;

create index if not exists idx_document_storage_metadata_owner_user_id on public.document_storage_metadata(owner_user_id);
create index if not exists idx_document_storage_metadata_created_at on public.document_storage_metadata(created_at);
create index if not exists idx_document_storage_metadata_status on public.document_storage_metadata(upload_status);

-- RLS: users can only write/read their own storage metadata rows.
alter table public.document_storage_metadata enable row level security;

drop policy if exists "document_storage_metadata_select_own" on public.document_storage_metadata;
create policy "document_storage_metadata_select_own"
  on public.document_storage_metadata
  for select
  to authenticated
  using (owner_user_id = auth.uid());

drop policy if exists "document_storage_metadata_insert_own" on public.document_storage_metadata;
create policy "document_storage_metadata_insert_own"
  on public.document_storage_metadata
  for insert
  to authenticated
  with check (owner_user_id = auth.uid());

drop policy if exists "document_storage_metadata_update_own" on public.document_storage_metadata;
create policy "document_storage_metadata_update_own"
  on public.document_storage_metadata
  for update
  to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 2) Admin-safe storage summary v2 (aggregate-only; prefers the new metadata table)
-- -----------------------------------------------------------------------------

-- Keep the existing admin_get_storage_summary() intact (already deployed) and
-- add a v2 RPC that uses privacy-safe metadata when available.

drop function if exists public.admin_get_storage_summary_v2();

create or replace function public.admin_get_storage_summary_v2()
returns table(
  total_document_count bigint,
  total_storage_used_mb bigint,
  average_storage_per_user_mb bigint,
  high_usage_users bigint,
  users_over_storage_limit bigint,
  users_near_storage_limit bigint,
  failed_upload_count bigint,
  failed_upload_events_24h bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_meta boolean;
  v_has_meta_owner boolean;
  v_has_meta_doc boolean;
  v_has_meta_file_size boolean;
  v_has_meta_storage_size boolean;
  v_has_meta_deleted boolean;
  v_has_meta_status boolean;
  v_has_meta_created_at boolean;
  v_has_entitlements boolean;
  v_has_ent_user_id boolean;
  v_has_ent_storage_limit boolean;
  v_has_docs boolean;
  v_has_doc_owner boolean;
  v_has_doc_size boolean;
  v_sql text;
begin
  perform public._admin_safe_assert_active_admin();

  -- Prefer privacy-safe storage metadata table.
  v_has_meta := public._admin_safe_table_exists('public.document_storage_metadata');
  v_has_meta_owner := v_has_meta and public._admin_safe_column_exists('public', 'document_storage_metadata', 'owner_user_id');
  v_has_meta_doc := v_has_meta and public._admin_safe_column_exists('public', 'document_storage_metadata', 'document_id');
  v_has_meta_file_size := v_has_meta and public._admin_safe_column_exists('public', 'document_storage_metadata', 'file_size_bytes');
  v_has_meta_storage_size := v_has_meta and public._admin_safe_column_exists('public', 'document_storage_metadata', 'storage_size_bytes');
  v_has_meta_deleted := v_has_meta and public._admin_safe_column_exists('public', 'document_storage_metadata', 'deleted_at');
  v_has_meta_status := v_has_meta and public._admin_safe_column_exists('public', 'document_storage_metadata', 'upload_status');
  v_has_meta_created_at := v_has_meta and public._admin_safe_column_exists('public', 'document_storage_metadata', 'created_at');

  -- Storage limits (if deployed).
  v_has_entitlements := public._admin_safe_table_exists('public.user_entitlements');
  v_has_ent_user_id := v_has_entitlements and public._admin_safe_column_exists('public', 'user_entitlements', 'user_id');
  v_has_ent_storage_limit := v_has_entitlements and (
    public._admin_safe_column_exists('public', 'user_entitlements', 'storage_limit_mb')
    or public._admin_safe_column_exists('public', 'user_entitlements', 'storage_limit_bytes')
  );

  -- Back-compat fallback: medical_documents sizes (never return names/paths).
  v_has_docs := public._admin_safe_table_exists('public.medical_documents');
  v_has_doc_owner := v_has_docs and public._admin_safe_column_exists('public', 'medical_documents', 'owner_user_id');
  v_has_doc_size := v_has_docs and (
    public._admin_safe_column_exists('public', 'medical_documents', 'file_size')
    or public._admin_safe_column_exists('public', 'medical_documents', 'file_size_bytes')
    or public._admin_safe_column_exists('public', 'medical_documents', 'size_bytes')
  );

  -- Aggregate only: totals + bytes + failure counts. Never return file names/paths/content.
  v_sql :=
    'with '
    || case
      when v_has_meta and v_has_meta_owner and (v_has_meta_file_size or v_has_meta_storage_size) then
        'doc_sizes as ('
        || 'select '
        || 'dsm.owner_user_id as user_id, '
        || 'coalesce(sum(coalesce(' ||
          case when v_has_meta_storage_size then 'dsm.storage_size_bytes' else 'null' end
          || ', '
          || case when v_has_meta_file_size then 'dsm.file_size_bytes' else 'null' end
          || ', 0)),0)::bigint as total_bytes '
        || 'from public.document_storage_metadata dsm '
        || 'where dsm.owner_user_id is not null '
        || (case when v_has_meta_deleted then 'and dsm.deleted_at is null ' else '' end)
        || (case when v_has_meta_status then 'and (dsm.upload_status ilike ''uploaded%'' or dsm.upload_status ilike ''success%'' or dsm.upload_status ilike ''complete%'') ' else '' end)
        || 'group by 1'
        || ')'
      when v_has_docs and v_has_doc_owner and v_has_doc_size then
        'doc_sizes as ('
        || 'select md.owner_user_id as user_id, '
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
    || ', ent_limits as ('
    || case
      when v_has_entitlements and v_has_ent_user_id and v_has_ent_storage_limit then
        'select e.user_id, '
        || case
            when public._admin_safe_column_exists('public', 'user_entitlements', 'storage_limit_bytes') then 'e.storage_limit_bytes'
            else '(e.storage_limit_mb::bigint * 1048576)'
          end
        || '::bigint as limit_bytes '
        || 'from public.user_entitlements e '
        || 'where e.user_id is not null'
      else
        'select null::uuid as user_id, 0::bigint as limit_bytes where false'
    end
    || ') '
    || 'select '
    || case
      when v_has_meta and v_has_meta_doc then
        '(select count(*)::bigint from public.document_storage_metadata dsm '
        || 'where 1=1 '
        || (case when v_has_meta_deleted then 'and dsm.deleted_at is null ' else '' end)
        || (case when v_has_meta_status then 'and (dsm.upload_status ilike ''uploaded%'' or dsm.upload_status ilike ''success%'' or dsm.upload_status ilike ''complete%'') ' else '' end)
        || ')'
      when v_has_docs then '(select count(*)::bigint from public.medical_documents)'
      else '0::bigint'
    end
    || ' as total_document_count, '
    || '(select coalesce(sum(ds.total_bytes),0)::bigint from doc_sizes ds) / 1048576 as total_storage_used_mb, '
    || '(select case when count(*) = 0 then 0 else round(avg(ds.total_bytes / 1048576.0))::bigint end from doc_sizes ds) as average_storage_per_user_mb, '
    || '(select count(*)::bigint from doc_sizes ds where ds.total_bytes >= (select coalesce(percentile_cont(0.95) within group (order by total_bytes), 0) from doc_sizes)) as high_usage_users, '
    || case
      when v_has_entitlements and v_has_ent_user_id and v_has_ent_storage_limit then
        '(select count(*)::bigint from doc_sizes ds join ent_limits el on el.user_id = ds.user_id where el.limit_bytes > 0 and ds.total_bytes > el.limit_bytes)'
      else
        '0::bigint'
    end
    || ' as users_over_storage_limit, '
    || case
      when v_has_entitlements and v_has_ent_user_id and v_has_ent_storage_limit then
        '(select count(*)::bigint from doc_sizes ds join ent_limits el on el.user_id = ds.user_id where el.limit_bytes > 0 and ds.total_bytes >= (el.limit_bytes * 0.8) and ds.total_bytes <= el.limit_bytes)'
      else
        '0::bigint'
    end
    || ' as users_near_storage_limit, '
    || case
      when v_has_meta and v_has_meta_status then
        '(select count(*)::bigint from public.document_storage_metadata dsm where dsm.upload_status ilike ''fail%'' or dsm.upload_status ilike ''error%'')'
      else
        '0::bigint'
    end
    || ' as failed_upload_count, '
    || case
      when v_has_meta and v_has_meta_status and v_has_meta_created_at then
        '(select count(*)::bigint from public.document_storage_metadata dsm where dsm.created_at > now() - interval ''24 hours'' and (dsm.upload_status ilike ''fail%'' or dsm.upload_status ilike ''error%''))'
      else
        '0::bigint'
    end
    || ' as failed_upload_events_24h';

  return query execute v_sql;
end;
$$;

revoke all on function public.admin_get_storage_summary_v2() from public;
revoke all on function public.admin_get_storage_summary_v2() from anon;
grant execute on function public.admin_get_storage_summary_v2() to authenticated;

commit;

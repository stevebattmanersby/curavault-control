-- Phase 5: production billing + admin override entitlements (v2)
--
-- Goals:
-- - Add canonical entitlement columns used by webhooks + app
-- - Preserve legacy columns for backwards compatibility
-- - Add admin override columns (Control Site writes; app reads only)
-- - Avoid changing RLS policies (kept as-is)

alter table if exists public.user_entitlements
  add column if not exists plan_key text null,
  add column if not exists billing_period text null check (billing_period in ('monthly', 'annual') or billing_period is null),
  add column if not exists status text null,
  add column if not exists ai_enabled boolean null,
  add column if not exists ocr_enabled boolean null,
  -- Back-compat (explicit) entitlement flags expected by older clients.
  add column if not exists ocr_access boolean null,
  add column if not exists export_enabled boolean null,
  add column if not exists mass_upload_enabled boolean null,
  add column if not exists max_storage_mb integer null,
  add column if not exists max_family_members integer null,
  add column if not exists ai_monthly_cap integer null,
  add column if not exists ocr_monthly_cap integer null,
  add column if not exists current_period_end timestamptz null,
  -- Admin overrides (written by Control Site only)
  add column if not exists storage_gb_override double precision null,
  add column if not exists ai_monthly_tokens_override integer null,
  add column if not exists ocr_monthly_pages_override integer null,
  add column if not exists max_family_profiles_override integer null,
  add column if not exists entitlement_override_reason text null,
  add column if not exists entitlement_override_expires_at timestamptz null,
  add column if not exists override_updated_by text null,
  add column if not exists override_updated_at timestamptz null;
-- Backfill canonical columns from legacy where possible.
update public.user_entitlements
set
  plan_key = coalesce(plan_key, plan),
  status = coalesce(status, subscription_status),
  ai_enabled = coalesce(ai_enabled, ai_access),
  ocr_enabled = coalesce(ocr_enabled, true),
  ocr_access = coalesce(ocr_access, true),
  export_enabled = coalesce(export_enabled, export_access),
  max_storage_mb = coalesce(max_storage_mb, document_quota_mb),
  max_family_members = coalesce(max_family_members, 1),
  ai_monthly_cap = coalesce(ai_monthly_cap, 0),
  ocr_monthly_cap = coalesce(ocr_monthly_cap, 10000)
where
  plan_key is null
  or status is null
  or ai_enabled is null
  or ocr_enabled is null
  or ocr_access is null
  or export_enabled is null
  or max_storage_mb is null
  or max_family_members is null
  or ai_monthly_cap is null
  or ocr_monthly_cap is null;
-- Ensure canonical columns are not null going forward (best-effort defaults).
alter table if exists public.user_entitlements
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
-- Make them non-null if they exist (safe for new installs; existing rows backfilled above).
do $$
begin
  begin
    alter table public.user_entitlements alter column plan_key set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column status set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column ai_enabled set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column ocr_enabled set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column ocr_access set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column export_enabled set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column mass_upload_enabled set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column max_storage_mb set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column max_family_members set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column ai_monthly_cap set not null;
  exception when others then null; end;
  begin
    alter table public.user_entitlements alter column ocr_monthly_cap set not null;
  exception when others then null; end;
end $$;

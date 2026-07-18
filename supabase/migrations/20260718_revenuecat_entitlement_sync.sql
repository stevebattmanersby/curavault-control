-- RevenueCat entitlement sync layer (idempotent, non-destructive)
--
-- IMPORTANT:
-- - Do NOT drop/truncate existing data.
-- - This migration only adds tables/columns needed for webhook-driven sync.
-- - RLS policies are owner/admin only for webhook event logs.
-- - user_entitlements is assumed to be part of the consumer schema already.

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- A) revenuecat_webhook_events
-- ---------------------------------------------------------------------------

create table if not exists public.revenuecat_webhook_events (
  id uuid primary key default gen_random_uuid(),
  revenuecat_event_id text not null unique,
  app_user_id uuid,
  original_app_user_id text,
  event_type text not null,
  product_id text,
  entitlement_id text,
  store text,
  environment text,
  period_type text,
  purchased_at timestamptz,
  expiration_at timestamptz,
  cancellation_at timestamptz,
  is_trial_conversion boolean,
  raw_event_redacted jsonb,
  processed_at timestamptz,
  processing_result text,
  created_at timestamptz not null default now()
);

create index if not exists revenuecat_webhook_events_created_at_idx
  on public.revenuecat_webhook_events (created_at desc);

create index if not exists revenuecat_webhook_events_app_user_id_idx
  on public.revenuecat_webhook_events (app_user_id);

alter table public.revenuecat_webhook_events enable row level security;

-- Admin-only visibility (best effort). Assumes `public.is_active_admin()` exists.
drop policy if exists revenuecat_webhook_events_admin_select on public.revenuecat_webhook_events;
create policy revenuecat_webhook_events_admin_select
on public.revenuecat_webhook_events
for select
to authenticated
using (public.is_active_admin());

drop policy if exists revenuecat_webhook_events_admin_write on public.revenuecat_webhook_events;
create policy revenuecat_webhook_events_admin_write
on public.revenuecat_webhook_events
for all
to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- ---------------------------------------------------------------------------
-- B) subscription_events (ensure it can store RevenueCat lifecycle)
-- ---------------------------------------------------------------------------

-- NOTE: subscription_events may already exist in the consumer schema.
-- We only add missing columns.

alter table if exists public.subscription_events
  add column if not exists user_id uuid;

alter table if exists public.subscription_events
  add column if not exists provider text not null default 'revenuecat';

alter table if exists public.subscription_events
  add column if not exists store text;

alter table if exists public.subscription_events
  add column if not exists event_key text;

alter table if exists public.subscription_events
  add column if not exists product_id text;

alter table if exists public.subscription_events
  add column if not exists entitlement_id text;

alter table if exists public.subscription_events
  add column if not exists environment text;

alter table if exists public.subscription_events
  add column if not exists period_type text;

alter table if exists public.subscription_events
  add column if not exists purchased_at timestamptz;

alter table if exists public.subscription_events
  add column if not exists expiration_at timestamptz;

alter table if exists public.subscription_events
  add column if not exists created_at timestamptz not null default now();

-- Helpful index (no-op if table does not exist or index already present).
do $$
begin
  if exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'subscription_events'
  ) then
    create index if not exists subscription_events_user_id_created_at_idx
      on public.subscription_events (user_id, created_at desc);
  end if;
end$$;

-- ---------------------------------------------------------------------------
-- C) user_entitlements (ensure it can store RevenueCat sync state)
-- ---------------------------------------------------------------------------

-- NOTE: user_entitlements is assumed to exist already.
-- We add columns to support RevenueCat as source of truth.

alter table if exists public.user_entitlements
  add column if not exists user_id uuid;

-- Best-effort: ensure unique per user if the table doesn't already enforce it.
do $$
begin
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'user_entitlements'
  ) then
    begin
      alter table public.user_entitlements
        add constraint user_entitlements_user_id_unique unique (user_id);
    exception when duplicate_object then
      -- already exists
      null;
    end;
  end if;
end$$;

alter table if exists public.user_entitlements
  add column if not exists plan_key text;

alter table if exists public.user_entitlements
  add column if not exists plan text;

alter table if exists public.user_entitlements
  add column if not exists status text;

alter table if exists public.user_entitlements
  add column if not exists subscription_status text;

alter table if exists public.user_entitlements
  add column if not exists provider text;

alter table if exists public.user_entitlements
  add column if not exists source_platform text;

alter table if exists public.user_entitlements
  add column if not exists store text;

alter table if exists public.user_entitlements
  add column if not exists revenuecat_app_user_id text;

alter table if exists public.user_entitlements
  add column if not exists revenuecat_original_app_user_id text;

alter table if exists public.user_entitlements
  add column if not exists active_entitlement_ids text[];

alter table if exists public.user_entitlements
  add column if not exists product_id text;

alter table if exists public.user_entitlements
  add column if not exists current_period_start timestamptz;

alter table if exists public.user_entitlements
  add column if not exists current_period_end timestamptz;

alter table if exists public.user_entitlements
  add column if not exists trial_start timestamptz;

alter table if exists public.user_entitlements
  add column if not exists trial_end timestamptz;

alter table if exists public.user_entitlements
  add column if not exists cancel_at_period_end boolean;

alter table if exists public.user_entitlements
  add column if not exists latest_revenuecat_event_id text;

alter table if exists public.user_entitlements
  add column if not exists storage_limit_bytes bigint;

alter table if exists public.user_entitlements
  add column if not exists ai_token_limit integer;

alter table if exists public.user_entitlements
  add column if not exists profile_limit integer;

alter table if exists public.user_entitlements
  add column if not exists updated_at timestamptz;

-- A small helper view for admin-safe billing visibility (counts only).
-- This does not expose any user content/health data.
create or replace view public.revenuecat_sync_health_v1 as
select
  (select count(*)::int from public.revenuecat_webhook_events) as webhook_event_rows,
  (select max(created_at) from public.revenuecat_webhook_events) as latest_webhook_received_at,
  (select max(processed_at) from public.revenuecat_webhook_events) as latest_webhook_processed_at,
  (select count(*)::int from public.revenuecat_webhook_events where processing_result is not null and processing_result <> 'ok') as webhook_failed_rows,
  (select count(*)::int from public.revenuecat_webhook_events where app_user_id is null) as webhook_unmapped_app_user_id_rows;

alter view public.revenuecat_sync_health_v1 set (security_invoker = true);

commit;

-- Phase 3: pricing/plans/entitlements foundation
--
-- Creates a per-user entitlement record that:
-- - is readable/writable only by the owning auth user (RLS)
-- - can be updated later by a sync job from Stripe/Apple/Google/RevenueCat
-- - contains feature flags + quota used by the app

create table if not exists public.user_entitlements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  plan text not null check (plan in ('free', 'plus', 'pro')),
  ai_access boolean not null default false,
  export_access boolean not null default false,
  document_quota_mb integer not null default 50,
  subscription_status text not null default 'active' check (subscription_status in ('active', 'trialing', 'past_due', 'canceled', 'expired')),
  source_platform text not null default 'internal',
  expires_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_entitlements enable row level security;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_entitlements_updated_at on public.user_entitlements;
create trigger trg_user_entitlements_updated_at
before update on public.user_entitlements
for each row
execute function public.set_updated_at();

-- Owner read
drop policy if exists "user_entitlements_select_own" on public.user_entitlements;
create policy "user_entitlements_select_own"
on public.user_entitlements
for select
using (auth.uid() = user_id);

-- Owner update (used by app-side preference updates in future; safe for now)
drop policy if exists "user_entitlements_update_own" on public.user_entitlements;
create policy "user_entitlements_update_own"
on public.user_entitlements
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Owner insert (lets client create a default row on first sign-in)
drop policy if exists "user_entitlements_insert_own" on public.user_entitlements;
create policy "user_entitlements_insert_own"
on public.user_entitlements
for insert
with check (auth.uid() = user_id);

-- Optional: ensure `medical_documents.file_size` exists for quota metering.
-- (Your current app already writes to file_size, but older DBs may be missing it.)
alter table if exists public.medical_documents
add column if not exists file_size bigint null;

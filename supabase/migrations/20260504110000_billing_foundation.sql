-- Billing foundation required by Stripe/RevenueCat Edge Functions.
--
-- This migration intentionally keeps billing rows owner-scoped and RLS enabled.
-- Webhooks use the service role; authenticated users may only read their own
-- customer/event rows if a client surface needs them later.

create extension if not exists pgcrypto;

create table if not exists public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_key text not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  event_type text null,
  checkout_session_id text null,
  subscription_id text null,
  customer_id text null,
  status text null,
  current_period_end timestamptz null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscription_events_provider_event_nonempty
    check (btrim(provider) <> '' and btrim(event_key) <> '')
);

create index if not exists idx_subscription_events_user
  on public.subscription_events (user_id, created_at desc);
create index if not exists idx_subscription_events_provider
  on public.subscription_events (provider, created_at desc);

drop trigger if exists trg_subscription_events_updated_at on public.subscription_events;
create trigger trg_subscription_events_updated_at
before update on public.subscription_events
for each row
execute function public.set_updated_at();

alter table public.subscription_events enable row level security;
grant select, insert, update, delete on table public.subscription_events to authenticated;

drop policy if exists "subscription_events_select_own" on public.subscription_events;
create policy "subscription_events_select_own"
on public.subscription_events
for select
using (auth.uid() = user_id);

drop policy if exists "subscription_events_insert_own" on public.subscription_events;
create policy "subscription_events_insert_own"
on public.subscription_events
for insert
with check (auth.uid() = user_id);

drop policy if exists "subscription_events_update_own" on public.subscription_events;
create policy "subscription_events_update_own"
on public.subscription_events
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "subscription_events_delete_own" on public.subscription_events;
create policy "subscription_events_delete_own"
on public.subscription_events
for delete
using (auth.uid() = user_id);

create table if not exists public.stripe_customers (
  user_id uuid primary key references auth.users (id) on delete cascade,
  stripe_customer_id text not null,
  last_requested_price_id text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stripe_customers_customer_nonempty
    check (btrim(stripe_customer_id) <> '')
);

create unique index if not exists uq_stripe_customers_customer_id
  on public.stripe_customers (stripe_customer_id);

drop trigger if exists trg_stripe_customers_updated_at on public.stripe_customers;
create trigger trg_stripe_customers_updated_at
before update on public.stripe_customers
for each row
execute function public.set_updated_at();

alter table public.stripe_customers enable row level security;
grant select, insert, update, delete on table public.stripe_customers to authenticated;

drop policy if exists "stripe_customers_select_own" on public.stripe_customers;
create policy "stripe_customers_select_own"
on public.stripe_customers
for select
using (auth.uid() = user_id);

drop policy if exists "stripe_customers_insert_own" on public.stripe_customers;
create policy "stripe_customers_insert_own"
on public.stripe_customers
for insert
with check (auth.uid() = user_id);

drop policy if exists "stripe_customers_update_own" on public.stripe_customers;
create policy "stripe_customers_update_own"
on public.stripe_customers
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "stripe_customers_delete_own" on public.stripe_customers;
create policy "stripe_customers_delete_own"
on public.stripe_customers
for delete
using (auth.uid() = user_id);

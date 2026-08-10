-- RevenueCat Test Store readiness: canonical subscription vocabulary and
-- webhook idempotency preparation.
--
-- This migration is intentionally repository-only until reviewed/applied.
-- It preserves existing entitlement expiry dates and server-owned writes.

begin;

alter table if exists public.user_entitlements
  alter column plan set default 'starter',
  alter column plan_key set default 'starter',
  alter column subscription_status set default 'active',
  alter column status set default 'active';

with canonical_entitlement_tiers as (
  select
    user_id,
    case
      when plan = 'family' or plan_key = 'family' then 'family'
      when plan in ('pro', 'premium', 'plus')
        or plan_key in ('pro', 'premium', 'plus') then 'plus'
      when plan in ('free', 'starter')
        or plan_key in ('free', 'starter') then 'starter'
      else null
    end as canonical_tier
  from public.user_entitlements
)
update public.user_entitlements ent
set
  plan_key = coalesce(tiers.canonical_tier, ent.plan_key),
  plan = coalesce(tiers.canonical_tier, ent.plan),
  status = case
    when ent.status = 'canceled' then 'cancelled'
    when ent.status in ('active', 'trialing', 'grace_period', 'past_due', 'cancelled', 'expired') then ent.status
    else 'expired'
  end,
  subscription_status = case
    when ent.subscription_status = 'canceled' then 'cancelled'
    when ent.subscription_status in ('active', 'trialing', 'grace_period', 'past_due', 'cancelled', 'expired') then ent.subscription_status
    else 'expired'
  end
from canonical_entitlement_tiers tiers
where
  ent.user_id = tiers.user_id
  and (
    tiers.canonical_tier is not null
    or ent.status in ('canceled', 'active', 'trialing', 'grace_period', 'past_due', 'cancelled', 'expired')
    or ent.subscription_status in ('canceled', 'active', 'trialing', 'grace_period', 'past_due', 'cancelled', 'expired')
  );

alter table if exists public.user_entitlements
  drop constraint if exists user_entitlements_plan_check,
  drop constraint if exists user_entitlements_plan_key_check,
  drop constraint if exists user_entitlements_subscription_status_check,
  drop constraint if exists user_entitlements_status_check;

alter table if exists public.user_entitlements
  add constraint user_entitlements_plan_check
    check (plan in ('starter', 'plus', 'family')),
  add constraint user_entitlements_plan_key_check
    check (plan_key in ('starter', 'plus', 'family')),
  add constraint user_entitlements_subscription_status_check
    check (subscription_status in ('active', 'trialing', 'grace_period', 'past_due', 'cancelled', 'expired')),
  add constraint user_entitlements_status_check
    check (status in ('active', 'trialing', 'grace_period', 'past_due', 'cancelled', 'expired'));

create or replace function public.ensure_my_free_entitlement()
returns public.user_entitlements
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_row public.user_entitlements;
begin
  v_user_id := (select auth.uid());

  if v_user_id is null then
    raise exception 'authenticated user required' using errcode = '42501';
  end if;

  insert into public.user_entitlements (
    user_id,
    plan,
    plan_key,
    billing_period,
    status,
    subscription_status,
    ai_access,
    ai_enabled,
    ocr_access,
    ocr_enabled,
    export_access,
    export_enabled,
    mass_upload_enabled,
    document_quota_mb,
    max_storage_mb,
    max_family_members,
    ai_monthly_cap,
    ocr_monthly_cap,
    source_platform,
    expires_at,
    current_period_end
  )
  values (
    v_user_id,
    'starter',
    'starter',
    null,
    'active',
    'active',
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    250,
    250,
    1,
    0,
    10000,
    'internal',
    null,
    null
  )
  on conflict (user_id) do nothing;

  select *
  into v_row
  from public.user_entitlements
  where user_id = v_user_id;

  return v_row;
end;
$$;

create or replace function public.create_default_user_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_entitlements (
    user_id,
    plan,
    plan_key,
    billing_period,
    status,
    subscription_status,
    ai_access,
    ai_enabled,
    ocr_access,
    ocr_enabled,
    export_access,
    export_enabled,
    mass_upload_enabled,
    document_quota_mb,
    max_storage_mb,
    max_family_members,
    ai_monthly_cap,
    ocr_monthly_cap,
    source_platform,
    expires_at,
    current_period_end
  )
  values (
    new.id,
    'starter',
    'starter',
    null,
    'active',
    'active',
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    250,
    250,
    1,
    0,
    10000,
    'internal',
    null,
    null
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function public.ensure_my_free_entitlement() from public, anon, authenticated, service_role;
grant execute on function public.ensure_my_free_entitlement() to authenticated;
revoke all on function public.create_default_user_entitlement() from public, anon, authenticated, service_role;

alter table if exists public.subscription_events
  add column if not exists provider text not null default 'unknown';

with ranked_subscription_events as (
  select
    id,
    row_number() over (
      partition by provider, event_key
      order by created_at asc, id asc
    ) as duplicate_rank
  from public.subscription_events
  where event_key is not null
)
delete from public.subscription_events se
using ranked_subscription_events ranked
where se.id = ranked.id
  and ranked.duplicate_rank > 1;

create unique index if not exists subscription_events_provider_event_key_unique
  on public.subscription_events (provider, event_key);

revoke all on table public.user_entitlements from anon;
revoke insert, update, delete on table public.user_entitlements from authenticated;
grant select on table public.user_entitlements to authenticated;
grant select, insert, update, delete on table public.user_entitlements to service_role;

commit;
;

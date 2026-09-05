-- Harden subscription event storage.
--
-- Subscription events are payment-provider webhook/audit records. They are
-- written and read only by trusted server-side Edge Functions using the
-- service_role key. Mobile and web clients must not access this table directly.

begin;

do $$
declare
  r record;
begin
  if to_regclass('public.subscription_events') is null then
    return;
  end if;

  alter table public.subscription_events enable row level security;

  revoke all privileges on table public.subscription_events from public;
  revoke all privileges on table public.subscription_events from anon;
  revoke all privileges on table public.subscription_events from authenticated;

  grant select, insert, update, delete on table public.subscription_events to service_role;

  for r in
    select policyname
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'subscription_events'
  loop
    execute format('drop policy if exists %I on public.subscription_events', r.policyname);
  end loop;
end;
$$;

commit;;

begin;

-- Harden browser-originated audit writes after the AAL2 rollout.
--
-- `public.is_active_admin()` intentionally returns true for every active
-- allow-listed Control Site role after AAL2. That is too broad for direct
-- inserts into the append-only admin audit table. Limited operational roles
-- may view or troubleshoot within their scoped surfaces, but they must not be
-- able to write arbitrary audit records from the browser.
create or replace function public.admin_can_insert_audit_log()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(current_setting('request.jwt.claim.role', true), '') = 'service_role'
    or (
      auth.uid() is not null
      and coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      and exists (
        select 1
        from public.admin_users as admin_user
        where admin_user.admin_user_id = auth.uid()
          and admin_user.is_active = true
          and admin_user.role in ('owner', 'admin', 'billing', 'compliance')
      )
    );
$$;

revoke all on function public.admin_can_insert_audit_log()
  from public, anon;
grant execute on function public.admin_can_insert_audit_log()
  to authenticated, service_role;
grant insert on table public.admin_audit_log
  to authenticated;

alter table public.admin_audit_log enable row level security;

drop policy if exists "admin_audit_log_insert_active_admin"
  on public.admin_audit_log;
drop policy if exists "admin_audit_log_insert_aal2_admin"
  on public.admin_audit_log;
drop policy if exists "admin_audit_log_insert_privileged_aal2_admin"
  on public.admin_audit_log;

create policy "admin_audit_log_insert_privileged_aal2_admin"
on public.admin_audit_log
for insert
to authenticated
with check (public.admin_can_insert_audit_log());

commit;

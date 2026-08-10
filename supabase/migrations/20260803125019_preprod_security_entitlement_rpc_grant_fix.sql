-- Pre-production security repair follow-up: ensure the client bootstrap RPC
-- remains authenticated-only after the entitlement/admin-helper hardening.

begin;

revoke all on function public.ensure_my_free_entitlement() from public, anon, authenticated, service_role;
grant execute on function public.ensure_my_free_entitlement() to authenticated;

commit;
;

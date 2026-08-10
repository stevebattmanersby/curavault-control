-- Restore entitlement parity objects that exist in the linked project but were
-- missing from the recovered shared baseline replay.
--
-- These definitions were inspected read-only from curavault-clean:
-- - user_entitlements_updated_at_idx:
--   CREATE INDEX user_entitlements_updated_at_idx ON public.user_entitlements USING btree (updated_at)
-- - user_entitlements_limits_check:
--   CHECK (((max_storage_mb >= 0) AND (max_family_members >= 0))) validated

begin;

do $$
declare
  v_index_definition text;
  v_expected_index_definition constant text :=
    'CREATE INDEX user_entitlements_updated_at_idx ON public.user_entitlements USING btree (updated_at)';
begin
  select pg_get_indexdef(i.indexrelid)
  into v_index_definition
  from pg_index i
  join pg_class idx on idx.oid = i.indexrelid
  join pg_namespace ns on ns.oid = idx.relnamespace
  where ns.nspname = 'public'
    and idx.relname = 'user_entitlements_updated_at_idx';

  if v_index_definition is not null
     and v_index_definition <> v_expected_index_definition then
    raise exception 'existing user_entitlements_updated_at_idx definition mismatch: %',
      v_index_definition;
  end if;
end $$;

create index if not exists user_entitlements_updated_at_idx
  on public.user_entitlements using btree (updated_at);

do $$
declare
  v_constraint_definition text;
  v_constraint_validated boolean;
  v_expected_constraint_definition constant text :=
    'CHECK (((max_storage_mb >= 0) AND (max_family_members >= 0)))';
begin
  select pg_get_constraintdef(c.oid), c.convalidated
  into v_constraint_definition, v_constraint_validated
  from pg_constraint c
  join pg_class tbl on tbl.oid = c.conrelid
  join pg_namespace ns on ns.oid = tbl.relnamespace
  where ns.nspname = 'public'
    and tbl.relname = 'user_entitlements'
    and c.conname = 'user_entitlements_limits_check';

  if v_constraint_definition is not null then
    if v_constraint_definition <> v_expected_constraint_definition then
      raise exception 'existing user_entitlements_limits_check definition mismatch: %',
        v_constraint_definition;
    end if;

    if not v_constraint_validated then
      alter table public.user_entitlements
        validate constraint user_entitlements_limits_check;
    end if;

    return;
  end if;

  alter table public.user_entitlements
    add constraint user_entitlements_limits_check
    check ((max_storage_mb >= 0) and (max_family_members >= 0));
end $$;

do $$
declare
  v_constraint_definition text;
  v_constraint_validated boolean;
  v_expected_constraint_definition constant text :=
    'CHECK (((max_storage_mb >= 0) AND (max_family_members >= 0)))';
begin
  select pg_get_constraintdef(c.oid), c.convalidated
  into v_constraint_definition, v_constraint_validated
  from pg_constraint c
  join pg_class tbl on tbl.oid = c.conrelid
  join pg_namespace ns on ns.oid = tbl.relnamespace
  where ns.nspname = 'public'
    and tbl.relname = 'user_entitlements'
    and c.conname = 'user_entitlements_limits_check';

  if v_constraint_definition <> v_expected_constraint_definition
     or not v_constraint_validated then
    raise exception 'user_entitlements_limits_check was not created with the expected validated definition';
  end if;
end $$;

commit;

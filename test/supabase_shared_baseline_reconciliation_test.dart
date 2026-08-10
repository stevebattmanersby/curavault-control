import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shared Supabase baseline reconciliation', () {
    late final File userEntitlementsBaseline;
    late final File coreHealthBaseline;
    late final File billingFoundationBaseline;
    late final File parityMigration;
    late final String paritySql;

    setUpAll(() {
      userEntitlementsBaseline = File(
        'supabase/migrations/20260317_0001_user_entitlements.sql',
      );
      coreHealthBaseline = File(
        'supabase/migrations/20260329_0002_core_health_tables.sql',
      );
      billingFoundationBaseline = File(
        'supabase/migrations/20260504110000_billing_foundation.sql',
      );

      final parityMigrations = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) =>
              file.path.endsWith('_entitlement_parity_baseline_objects.sql'))
          .toList();

      expect(parityMigrations, hasLength(1));
      parityMigration = parityMigrations.single;
      paritySql = parityMigration.readAsStringSync();
    });

    test('restores the exact shared baseline migration files', () {
      expect(userEntitlementsBaseline.existsSync(), isTrue);
      expect(coreHealthBaseline.existsSync(), isTrue);
      expect(billingFoundationBaseline.existsSync(), isTrue);

      final entitlementSql = userEntitlementsBaseline.readAsStringSync();
      final coreSql = coreHealthBaseline.readAsStringSync();
      final billingSql = billingFoundationBaseline.readAsStringSync();

      expect(
        entitlementSql,
        contains('create table if not exists public.user_entitlements'),
      );
      expect(entitlementSql, contains('plan in (\'free\', \'plus\', \'pro\')'));
      expect(
        entitlementSql,
        contains('create trigger trg_user_entitlements_updated_at'),
      );

      expect(coreSql,
          contains('create table if not exists public.family_members'));
      expect(coreSql,
          contains('create table if not exists public.medical_records'));
      expect(coreSql,
          contains('create table if not exists public.medical_documents'));

      expect(
        billingSql,
        contains('create table if not exists public.subscription_events'),
      );
      expect(billingSql,
          contains('create table if not exists public.stripe_customers'));
    });

    test('creates the missing entitlement parity objects', () {
      expect(
        paritySql,
        contains('create index if not exists user_entitlements_updated_at_idx'),
      );
      expect(
        paritySql,
        contains('on public.user_entitlements using btree (updated_at)'),
      );
      expect(
        paritySql,
        contains('add constraint user_entitlements_limits_check'),
      );
      expect(
        paritySql,
        contains('check ((max_storage_mb >= 0) and (max_family_members >= 0))'),
      );
    });

    test('matches the inspected production definitions', () {
      expect(
        paritySql,
        contains(
          'CREATE INDEX user_entitlements_updated_at_idx ON public.user_entitlements USING btree (updated_at)',
        ),
      );
      expect(
        paritySql,
        contains(
            'CHECK (((max_storage_mb >= 0) AND (max_family_members >= 0)))'),
      );
      expect(paritySql,
          contains('validate constraint user_entitlements_limits_check'));
    });

    test('fails closed instead of accepting conflicting objects', () {
      expect(
        paritySql,
        contains(
            'existing user_entitlements_updated_at_idx definition mismatch'),
      );
      expect(
        paritySql,
        contains('existing user_entitlements_limits_check definition mismatch'),
      );
      expect(
        paritySql,
        contains('was not created with the expected validated definition'),
      );
      expect(paritySql, isNot(contains('drop index')));
      expect(paritySql,
          isNot(contains('drop constraint user_entitlements_limits_check')));
    });

    test('does not mutate entitlement rows', () {
      expect(paritySql.toLowerCase(),
          isNot(contains('insert into public.user_entitlements')));
      expect(paritySql.toLowerCase(),
          isNot(contains('update public.user_entitlements')));
      expect(paritySql.toLowerCase(),
          isNot(contains('delete from public.user_entitlements')));
    });
  });
}

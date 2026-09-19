import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Control engineering framework contract', () {
    late final String agents;
    late final String execution;
    late final String matrix;
    late final String adversarial;
    late final String tiers;
    late final String releaseFuture;
    late final String validationScript;

    setUpAll(() {
      agents = File('AGENTS.md').readAsStringSync();
      execution = File('docs/development/CODEX_EXECUTION_CONTRACT.md')
          .readAsStringSync();
      matrix = File('docs/development/CHANGE_RISK_AND_VALIDATION_MATRIX.md')
          .readAsStringSync();
      adversarial = File('docs/development/CODEX_ADVERSARIAL_REVIEW.md')
          .readAsStringSync();
      tiers = File('docs/development/VALIDATION_TIERS.md').readAsStringSync();
      releaseFuture =
          File('docs/development/RELEASE_CONTROL_FUTURE_CONTRACT.md')
              .readAsStringSync();
      validationScript =
          File('tool/control_validation_tier.sh').readAsStringSync();
    });

    test('preserves existing AGENTS constitution and discovers framework docs',
        () {
      expect(agents, contains('Never push directly to `main`'));
      expect(agents, contains('Preserve the existing Supabase authentication'));
      expect(agents, contains('CODEX_EXECUTION_CONTRACT.md'));
      expect(agents, contains('CHANGE_RISK_AND_VALIDATION_MATRIX.md'));
      expect(agents, contains('CODEX_ADVERSARIAL_REVIEW.md'));
    });

    test('defines Control-specific execution and production gates', () {
      for (final role in [
        'owner',
        'admin',
        'billing',
        'compliance',
        'support',
        'read_only',
      ]) {
        expect(execution, contains(role));
      }
      expect(execution, contains('AAL2'));
      final normalizedExecution = execution.toLowerCase();
      expect(normalizedExecution, contains('inactive admins are denied'));
      expect(normalizedExecution,
          contains('ordinary authenticated users are denied'));
      expect(normalizedExecution, contains('anonymous users are denied'));
      expect(execution, contains('Merge authorization is separate'));
      expect(execution, contains('Production migration authorization'));
      expect(execution, contains('PR #8'));
    });

    test('requires disposable runtime proof for HIGH security changes', () {
      for (final term in [
        'auth.uid()',
        'auth.jwt()',
        'AAL',
        'RBAC',
        'RLS',
        'service_role',
        'SECURITY DEFINER',
        'grants or policies',
        'support-session mutations',
        'billing or compliance mutations',
      ]) {
        expect(matrix, contains(term));
      }
      expect(matrix,
          contains('Static SQL or Dart inspection alone is insufficient'));
      expect(matrix, contains('realistic Supabase/PostgREST claim semantics'));
    });

    test('requires operational truth for production Control features', () {
      for (final term in [
        'Production operational truth',
        'the production data source exists',
        'the schema matches the client contract',
        'visible filters alter the authoritative backend query',
        'server-side authorization matches UI authorization',
        'mutations have an existing executable backend contract',
        'NOT INSTRUMENTED',
        'UNKNOWN',
        'ERROR',
        'Synthetic, sample, seed, mock, or development data must never be created in production',
      ]) {
        expect(execution, contains(term));
      }
      for (final term in [
        'production data source exists',
        'visible filters alter authoritative backend predicates',
        'synthetic/sample/dev data is not created in production',
      ]) {
        expect(matrix, contains(term));
      }
    });

    test('requires cross-repo contract and admin action completeness', () {
      for (final term in [
        'Cross-repository contract verification',
        'current `curavult-app` main',
        'current production Supabase schema/functions',
        'current Control implementation',
        'Legacy compatibility fields must not be selected as authoritative',
        'Administrative action completeness',
        'production RPC or Edge Function exists',
        'concurrency/idempotency where relevant',
        'downstream user effect',
        'production blocker',
      ]) {
        expect(execution, contains(term));
      }
      expect(matrix, contains('production Supabase schema/functions'));
      expect(matrix, contains('canonical/effective fields or resolvers'));
    });

    test('locks metric integrity and PHI minimisation rules', () {
      for (final term in [
        'Metric integrity',
        'exact source, aggregation, date/window semantics, freshness',
        'authoritative, derived, estimated, or unavailable',
        'Hard-coded health states',
        'PHI minimisation',
        'Normal Control operations manage account and service metadata',
        'Access to raw health content requires a separate explicit architecture',
      ]) {
        expect(execution, contains(term));
      }
    });

    test('defines adversarial review attacks and verdicts', () {
      for (final verdict in ['PASS TO MERGE', 'WAIT', 'FAIL']) {
        expect(adversarial, contains(verdict));
      }
      for (final attack in [
        'AAL bypass',
        'role escalation',
        'inactive-admin access',
        '`support` privilege leakage',
        '`read_only` privilege leakage',
        'audit forgery',
        '`service_role` exposure',
        'migration ordering',
        'rollback and recovery',
        'fabricated production metrics',
        'visible filters that do not alter the authoritative backend query',
        'placeholder or mock-only admin mutations',
        'legacy compatibility fields',
      ]) {
        expect(adversarial, contains(attack));
      }
    });

    test('keeps Tier 3 explicit and separate from development validation', () {
      expect(tiers, contains('Tier 1 - Development'));
      expect(tiers, contains('Tier 2 - PR Gate'));
      expect(tiers, contains('Tier 3 - Release'));
      expect(tiers, contains('Tier 3 must be explicitly requested'));
      expect(validationScript, contains('--confirm-release-gate'));
      expect(validationScript, contains('Tier 3 requires'));
    });

    test('documents Release Control as future observability only', () {
      expect(releaseFuture, contains('CONTROL-RELEASE-01'));
      for (final channel in ['Android', 'iOS', 'Web', 'Backend', 'Control']) {
        expect(releaseFuture, contains(channel));
      }
      for (final gate in [
        'NOT_STARTED',
        'IN_PROGRESS',
        'WAITING_EXTERNAL',
        'WAITING_HUMAN',
        'PASS',
        'FAIL',
        'BLOCKED',
        'SUPERSEDED',
      ]) {
        expect(releaseFuture, contains(gate));
      }
      expect(releaseFuture, contains('must not include buttons'));
    });
  });
}

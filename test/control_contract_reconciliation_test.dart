import 'dart:convert';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_admin_queries.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  final stamp = DateTime.utc(2026, 10, 5);
  final admin = AdminUser(
      id: '00000000-0000-4000-8000-000000000001',
      email: 'synthetic@example.invalid',
      role: AdminRole.owner,
      isActive: true,
      requireStepUp: false,
      createdAt: stamp,
      updatedAt: stamp);
  setUp(() async {
    requests.clear();
    await Supabase.initialize(
        url: 'https://contract-test.invalid',
        publishableKey: 'synthetic',
        debug: false,
        authOptions: FlutterAuthClientOptions(
            pkceAsyncStorage: _MemoryStorage(),
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),
            autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/admin_get_ai_usage_summary')) {
            return http.Response(
                jsonEncode([
                  {'total_request_count': 3, 'input_tokens': 17}
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (path.endsWith('/admin_get_storage_summary')) {
            return http.Response(
                jsonEncode([
                  {'total_document_count': 2, 'total_storage_used_mb': 5}
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (path.endsWith('/admin_get_billing_summary')) {
            return http.Response(
                jsonEncode([
                  {
                    'plan': 'starter',
                    'billing_status': 'active',
                    'subscription_provider': 'internal',
                    'user_count': 2
                  }
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (path.endsWith('/revenuecat_sync_health_v1')) {
            return http.Response(jsonEncode({'webhook_event_rows': 4}), 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (path.endsWith('/admin_users')) {
            return http.Response(
                jsonEncode({
                  'admin_user_id': admin.id,
                  'email': admin.email,
                  'role': 'owner',
                  'is_active': true,
                  'require_step_up': false,
                  'created_at': stamp.toIso8601String(),
                  'updated_at': stamp.toIso8601String(),
                  'theme_preference': 'system'
                }),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (path.startsWith('/rest/v1/marketing_') ||
              path.endsWith('/revenuecat_webhook_events')) {
            return http.Response('[]', 200, request: request, headers: {
              'content-type': 'application/json',
              'content-range': '0-0/0'
            });
          }
          return http.Response('{"code":"unexpected_contract"}', 500,
              request: request);
        }));
  });
  tearDown(() async {
    await Supabase.instance.dispose();
  });
  test(
      'AI and storage use supported V1 once, preserve source and parsed values',
      () async {
    final queries = SupabaseAdminQueries();
    final ai = await queries.getAIUsage(
        admin: admin,
        query: const AiUsageQuery(range: AdminDateRangePreset.days30));
    final storage = await queries.getStorageUsage(
        admin: admin,
        query: const StorageQuery(range: AdminDateRangePreset.days30));
    expect(ai.inputTokensThisMonth, 17);
    expect(ai.source, 'admin_get_ai_usage_summary');
    expect(ai.sourceNote, contains('Partial'));
    expect(storage.value.totalStorageUsedBytes, 5 * 1048576);
    expect(requests.map((r) => r.url.path), [
      '/rest/v1/rpc/admin_get_ai_usage_summary',
      '/rest/v1/rpc/admin_get_storage_summary'
    ]);
  });
  test(
      'billing aggregate avoids account-scoped entitlement scan and unknown store zeros',
      () async {
    final billing = await SupabaseAdminQueries().getBillingSummary(
        admin: admin,
        query: const BillingQuery(range: AdminDateRangePreset.days30));
    expect(billing.revenueCat, isNull);
    expect(billing.revenueCat?.entitlementsRows, isNull);
    expect(billing.revenueCat?.activeEntitlementsRows, isNull);
    expect(requests.where((r) => r.url.path.endsWith('/user_entitlements')),
        isEmpty);
    expect(
        requests
            .where((r) => r.url.path.endsWith('/revenuecat_sync_health_v1')),
        isEmpty);
  });
  test(
      'CMS future asset capability stays unavailable without probing missing relation',
      () async {
    final cms = await SupabaseAdminRepository().getWebsiteCmsStatus();
    final asset =
        cms.rows.singleWhere((r) => r.tableName == 'asset_library_backend');
    expect(asset.exists, false);
    expect(asset.rowCount, isNull);
    expect(asset.status, WebsiteCmsTableOverallStatus.missingTable);
    expect(requests.where((r) => r.url.path.endsWith('/asset_library_backend')),
        isEmpty);
  });
  test(
      'billing diagnostics preserve service-only events and absent Stripe source',
      () async {
    final billing =
        await SupabaseAdminRepository(queries: _FixtureQueries(admin))
            .getBillingSnapshot(
                query: const BillingQuery(range: AdminDateRangePreset.days30));
    final sources = billing.diagnostics!.dataSources;
    for (final table in [
      'user_entitlements',
      'subscription_events',
      'stripe_webhook_events'
    ]) {
      expect(sources.singleWhere((s) => s.queryOrTable == table).kind,
          AdminDataSourceKind.notInstrumented);
      expect(requests.where((r) => r.url.path.endsWith('/$table')), isEmpty);
    }
  });
}

class _FixtureQueries extends SupabaseAdminQueries {
  _FixtureQueries(this.admin);
  final AdminUser admin;
  @override
  Future<AdminUser> getCurrentAdminUser() async => admin;
}

class _MemoryStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

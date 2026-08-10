import 'package:curavault_admin/admin/data/admin_repository.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/mock_data/mock_fallback_data.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/data/models/cms_models.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_admin_queries.dart';
import 'package:curavault_admin/admin/utils/audit_redactor.dart';
import 'package:curavault_admin/admin/utils/client_context.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed repository implementation.
///
/// It queries only privacy-safe summary tables/views and enforces RBAC.
///
/// Supabase-connected builds fail closed when live admin-safe views/RPCs are
/// missing. Mock fallback is only available when explicitly enabled for local
/// test/demo builds with CURAVAULT_ALLOW_MOCK_FALLBACK=true.
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(
      {SupabaseAdminQueries? queries, AdminRepository? fallback})
      : _queries = queries ?? SupabaseAdminQueries(),
        _fallback = fallback ?? MockFallbackData.create();

  final SupabaseAdminQueries _queries;
  final AdminRepository _fallback;

  static const bool _allowMockFallback = bool.fromEnvironment(
    'CURAVAULT_ALLOW_MOCK_FALLBACK',
    defaultValue: false,
  );
  static bool get _mustFailClosed => kReleaseMode || !_allowMockFallback;

  final Map<AdminDataSourceKey, AdminDataSourceStatus> _sources =
      <AdminDataSourceKey, AdminDataSourceStatus>{};

  AdminDataSourceStatus getSource(AdminDataSourceKey key) =>
      _sources[key] ??
      const AdminDataSourceStatus(kind: AdminDataSourceKind.live);

  void _set(AdminDataSourceKey key, AdminDataSourceStatus status) {
    _sources[key] = status;
  }

  void _setLive(AdminDataSourceKey key,
      {required String queryName, int? rowCount, String? message}) {
    _set(
      key,
      AdminDataSourceStatus(
        kind: AdminDataSourceKind.live,
        message: message,
        queryName: queryName,
        rowCount: rowCount,
        lastRefreshedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _setMock(AdminDataSourceKey key,
      {required String queryName, int? rowCount, String? message}) {
    _set(
      key,
      AdminDataSourceStatus(
        kind: AdminDataSourceKind.mock,
        message: message ?? 'Using mock fallback (debug only).',
        queryName: queryName,
        rowCount: rowCount,
        lastRefreshedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _setError(AdminDataSourceKey key,
      {required String queryName, required Object error}) {
    _set(
      key,
      AdminDataSourceStatus(
        kind: AdminDataSourceKind.error,
        queryName: queryName,
        lastRefreshedAt: DateTime.now().toUtc(),
        safeErrorMessage: formatAdminSafeError(error),
      ),
    );
  }

  AdminUser? _cachedAdmin;

  Future<AdminUser> _admin() async =>
      _cachedAdmin ??= await _queries.getCurrentAdminUser();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool _isMissingRelationError(Object e) {
    // PostgREST/Supabase messages differ by environment; be deliberately
    // permissive so missing optional instrumentation degrades cleanly.
    final msg = e.toString().toLowerCase();
    return msg.contains('pgrst106') ||
        msg.contains('pgrst202') ||
        msg.contains('pgrst205') ||
        msg.contains('invalid schema') ||
        msg.contains('schema cache') ||
        msg.contains('could not find the function') ||
        msg.contains('could not find the table') ||
        (msg.contains('relation') && msg.contains('does not exist')) ||
        (msg.contains('function') && msg.contains('does not exist')) ||
        (msg.contains('table') && msg.contains('does not exist')) ||
        msg.contains('404');
  }

  Never _throwNotInstrumented(AdminDataSourceKey key, {String? queryName}) {
    final status = AdminDataSourceStatus(
      kind: AdminDataSourceKind.notInstrumented,
      message: 'This data source is not instrumented yet.',
      queryName: queryName,
      lastRefreshedAt: DateTime.now().toUtc(),
    );
    _set(key, status);
    throw AdminNotInstrumentedException(status.message!);
  }

  DateTime? _tryParseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<int> _safeCountTable(SupabaseClient client, String table) async {
    // This project’s current supabase_flutter version doesn’t expose count
    // headers/options consistently across platforms.
    //
    // Marketing tables should be small; we cap the fetch size defensively.
    const cap = 5000;
    final dynamic res = await client.from(table).select('id').limit(cap);

    if (res is List) return res.length;
    if (res is PostgrestResponse) {
      final data = res.data;
      if (data is List) return data.length;
    }
    return 0;
  }

  @override
  Future<AdminUser> getCurrentAdmin() => _queries.getCurrentAdminUser();

  @override
  Future<void> createAuditLog({required AdminAuditLogCreate entry}) async {
    final c = _client;
    if (c == null) throw StateError('Supabase not initialized; cannot audit.');
    final row = <String, dynamic>{
      // Matches public.admin_audit_log schema.
      'admin_user_id': entry.adminUserId,
      'admin_email': c.auth.currentUser?.email,
      if (entry.targetUserId != null) 'target_user_id': entry.targetUserId,
      'action_type': entry.actionType,
      'result': entry.result,
      if (entry.previousValue != null)
        'prev': AdminAuditRedactor.redactMap(entry.previousValue!),
      if (entry.newValue != null)
        'next': AdminAuditRedactor.redactMap(entry.newValue!),
      if (entry.reason != null) 'reason': entry.reason,
      if (entry.ticketReference != null) 'ticket_id': entry.ticketReference,
      if (AdminClientContext.ipAddress != null)
        'ip': AdminClientContext.ipAddress,
      if (AdminClientContext.userAgent != null)
        'user_agent': AdminClientContext.userAgent,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    await c.from('admin_audit_log').insert(row);
  }

  @override
  Future<List<UserAccountSummary>> listUsers(
      {required UserListQuery query, required int limit}) async {
    try {
      final admin = await _admin();
      final res =
          await _queries.getUsersList(admin: admin, query: query, limit: limit);
      _setLive(AdminDataSourceKey.users,
          queryName: 'admin_get_user_usage_summary', rowCount: res.length);
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listUsers failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.users,
              queryName: 'admin_get_user_usage_summary');
        _setMock(AdminDataSourceKey.users,
            queryName: 'admin_get_user_usage_summary',
            message: 'Using mock fallback (debug only).');
        return _fallback.listUsers(query: query, limit: limit);
      }
      _setError(AdminDataSourceKey.users,
          queryName: 'admin_get_user_usage_summary', error: e);
      rethrow;
    }
  }

  @override
  Future<UserAccountDetail> getUserDetail({required String userId}) async {
    try {
      final admin = await _admin();
      final res =
          await _queries.getUserAccountDetail(admin: admin, userId: userId);
      _setLive(AdminDataSourceKey.users,
          queryName: SupabaseAdminQueries.rpcUserAccountDetail, rowCount: 1);
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getUserDetail failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.users,
              queryName: SupabaseAdminQueries.rpcUserAccountDetail);
        _setMock(AdminDataSourceKey.users,
            queryName: SupabaseAdminQueries.rpcUserAccountDetail,
            message: 'User detail is mocked (debug only).');
        return _fallback.getUserDetail(userId: userId);
      }
      _setError(AdminDataSourceKey.users,
          queryName: SupabaseAdminQueries.rpcUserAccountDetail, error: e);
      rethrow;
    }
  }

  @override
  Future<void> performUserAdminAction(
      {required AdminActionRequest request}) async {
    try {
      final admin = await _admin();
      await _queries.performUserAdminAction(admin: admin, request: request);
      _setLive(AdminDataSourceKey.users,
          queryName: SupabaseAdminQueries.rpcPerformUserAction, rowCount: 1);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.performUserAdminAction failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.users,
              queryName: SupabaseAdminQueries.rpcPerformUserAction);
        _setMock(AdminDataSourceKey.users,
            queryName: SupabaseAdminQueries.rpcPerformUserAction,
            message: 'User admin actions are mocked (debug only).');
        return _fallback.performUserAdminAction(request: request);
      }
      _setError(AdminDataSourceKey.users,
          queryName: SupabaseAdminQueries.rpcPerformUserAction, error: e);
      rethrow;
    }
  }

  @override
  Future<List<AuditLogEntry>> listAuditLogs(
      {required AuditLogQuery query, required int limit}) async {
    try {
      final admin = await _admin();
      final res =
          await _queries.getAuditLogs(admin: admin, query: query, limit: limit);
      // Audit logs are always live when possible; treat missing as not instrumented in release.
      _setLive(AdminDataSourceKey.auditLogs,
          queryName: 'admin_audit_log', rowCount: res.length);
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listAuditLogs failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.auditLogs,
              queryName: 'admin_audit_log');
        _setMock(AdminDataSourceKey.auditLogs, queryName: 'admin_audit_log');
        return _fallback.listAuditLogs(query: query, limit: limit);
      }
      _setError(AdminDataSourceKey.auditLogs,
          queryName: 'admin_audit_log', error: e);
      rethrow;
    }
  }

  @override
  Future<AuditSummarySnapshot> getAuditSummary() async {
    try {
      final admin = await _admin();
      final row = await _queries.getAuditSummaryRow(admin: admin);
      final snap = AuditSummarySnapshot(
        totalAuditEvents: (row?['total_audit_events'] as num?)?.toInt() ?? 0,
        auditEvents24h: (row?['audit_events_24h'] as num?)?.toInt() ?? 0,
        failedAdminActions24h:
            (row?['failed_admin_actions_24h'] as num?)?.toInt() ?? 0,
        latestAuditEventAt:
            DateTime.tryParse((row?['latest_audit_event_at'] ?? '').toString()),
        generatedAt: DateTime.now().toUtc(),
      );
      _setLive(AdminDataSourceKey.auditLogs,
          queryName: 'admin_get_audit_summary', rowCount: row == null ? 0 : 1);
      return snap;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getAuditSummary failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.auditLogs,
              queryName: 'admin_get_audit_summary');
        _setMock(AdminDataSourceKey.auditLogs,
            queryName: 'admin_get_audit_summary');
        return _fallback.getAuditSummary();
      }
      _setError(AdminDataSourceKey.auditLogs,
          queryName: 'admin_get_audit_summary', error: e);
      rethrow;
    }
  }

  @override
  Future<List<SupportSessionSummary>> listSupportSessions(
      {required SupportQueueQuery query, required int limit}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getSupportSessions(
          admin: admin, query: query, limit: limit);
      _setLive(AdminDataSourceKey.support,
          queryName: 'admin_support_sessions', rowCount: res.length);
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listSupportSessions failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.support,
              queryName: 'admin_support_sessions');
        _setMock(AdminDataSourceKey.support,
            queryName: 'admin_support_sessions');
        return _fallback.listSupportSessions(query: query, limit: limit);
      }
      _setError(AdminDataSourceKey.support,
          queryName: 'admin_support_sessions', error: e);
      rethrow;
    }
  }

  @override
  Future<SupportSummarySnapshot> getSupportSummary() async {
    try {
      final admin = await _admin();
      final row = await _queries.getSupportSummaryRow(admin: admin);
      final snap = SupportSummarySnapshot(
        totalSessions: (row?['total_sessions'] as num?)?.toInt() ?? 0,
        openSessions: (row?['open_sessions'] as num?)?.toInt() ?? 0,
        activeSessions: (row?['active_sessions'] as num?)?.toInt() ?? 0,
        closedSessions: (row?['closed_sessions'] as num?)?.toInt() ?? 0,
        expiredSessions: (row?['expired_sessions'] as num?)?.toInt() ?? 0,
        latestSessionAt:
            DateTime.tryParse((row?['latest_session_at'] ?? '').toString()),
        generatedAt: DateTime.now().toUtc(),
      );
      _setLive(AdminDataSourceKey.support,
          queryName: 'admin_get_support_summary',
          rowCount: row == null ? 0 : 1);
      return snap;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getSupportSummary failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.support,
              queryName: 'admin_get_support_summary');
        _setMock(AdminDataSourceKey.support,
            queryName: 'admin_get_support_summary');
        return _fallback.getSupportSummary();
      }
      _setError(AdminDataSourceKey.support,
          queryName: 'admin_get_support_summary', error: e);
      rethrow;
    }
  }

  @override
  Future<SupportSessionDetail> getSupportSessionDetail(
      {required String supportSessionId}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getSupportSessionDetail(
          admin: admin, supportSessionId: supportSessionId);
      _setLive(AdminDataSourceKey.support,
          queryName: SupabaseAdminQueries.rpcSupportSessionDetail, rowCount: 1);
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getSupportSessionDetail failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.support,
              queryName: SupabaseAdminQueries.rpcSupportSessionDetail);
        _setMock(AdminDataSourceKey.support,
            queryName: SupabaseAdminQueries.rpcSupportSessionDetail,
            message: 'Support session detail is mocked (debug only).');
        return _fallback.getSupportSessionDetail(
            supportSessionId: supportSessionId);
      }
      _setError(AdminDataSourceKey.support,
          queryName: SupabaseAdminQueries.rpcSupportSessionDetail, error: e);
      rethrow;
    }
  }

  @override
  Future<DiagnosticsReport> runDiagnostics({required String userId}) async {
    try {
      final admin = await _admin();
      final res =
          await _queries.runUserDiagnostics(admin: admin, userId: userId);
      _setLive(AdminDataSourceKey.support,
          queryName: SupabaseAdminQueries.rpcRunUserDiagnostics,
          rowCount: res.checks.length);
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.runDiagnostics failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.support,
              queryName: SupabaseAdminQueries.rpcRunUserDiagnostics);
        _setMock(AdminDataSourceKey.support,
            queryName: SupabaseAdminQueries.rpcRunUserDiagnostics,
            message: 'Diagnostics are mocked (debug only).');
        return _fallback.runDiagnostics(userId: userId);
      }
      _setError(AdminDataSourceKey.support,
          queryName: SupabaseAdminQueries.rpcRunUserDiagnostics, error: e);
      rethrow;
    }
  }

  @override
  Future<void> performSupportAction(
      {required SupportActionRequest request}) async {
    try {
      final admin = await _admin();
      await _queries.performSupportAction(admin: admin, request: request);
      _setLive(AdminDataSourceKey.support,
          queryName: SupabaseAdminQueries.rpcPerformSupportAction, rowCount: 1);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.performSupportAction failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.support,
              queryName: SupabaseAdminQueries.rpcPerformSupportAction);
        _setMock(AdminDataSourceKey.support,
            queryName: SupabaseAdminQueries.rpcPerformSupportAction,
            message: 'Support actions are mocked (debug only).');
        return _fallback.performSupportAction(request: request);
      }
      _setError(AdminDataSourceKey.support,
          queryName: SupabaseAdminQueries.rpcPerformSupportAction, error: e);
      rethrow;
    }
  }

  @override
  Future<DashboardSnapshot> getDashboardSnapshot(
      {required DashboardQuery query}) async {
    try {
      final admin = await _admin();
      final res =
          await _queries.getDashboardMetrics(admin: admin, query: query);
      _setLive(AdminDataSourceKey.dashboard,
          queryName: 'admin_get_dashboard_metrics', rowCount: 1);
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getDashboardSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.dashboard,
              queryName: 'admin_get_dashboard_metrics');
        _setMock(AdminDataSourceKey.dashboard,
            queryName: 'admin_get_dashboard_metrics');
        return _fallback.getDashboardSnapshot(query: query);
      }
      _setError(AdminDataSourceKey.dashboard,
          queryName: 'admin_get_dashboard_metrics', error: e);
      rethrow;
    }
  }

  @override
  Future<List<PlanOverviewRow>> listPlansOverview({required int limit}) async {
    try {
      final admin = await _admin();
      final rows = await _queries.getPlanPermissionSummaryRows(admin: admin);

      // Map aggregate summary rows into existing UI model.
      final out = <PlanOverviewRow>[];
      for (final r in rows.take(limit)) {
        final plan = (r['plan'] ?? 'unknown').toString();
        out.add(
          PlanOverviewRow(
            planName: plan,
            monthlyPriceUsd: 0,
            storageLimitBytes:
                ((r['storage_limit_mb'] as num?)?.toInt() ?? 0) * 1048576,
            aiTokenLimitMonthly: (r['ai_token_limit'] as num?)?.toInt() ?? 0,
            profileLimit: (r['profile_limit'] as num?)?.toInt() ?? 0,
            uploadLimit: null,
            exportAccess: false,
            aiAccess: false,
            activeUsers: (r['active_count'] as num?)?.toInt() ?? 0,
            trialUsers: 0,
            paidUsers: 0,
            cancelledUsers: 0,
          ),
        );
      }

      _setLive(AdminDataSourceKey.plansPermissions,
          queryName: 'admin_get_plan_permission_summary', rowCount: out.length);
      return out;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listPlansOverview failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.plansPermissions,
              queryName: 'admin_get_plan_permission_summary');
        _setMock(AdminDataSourceKey.plansPermissions,
            queryName: 'admin_get_plan_permission_summary');
        return _fallback.listPlansOverview(limit: limit);
      }
      _setError(AdminDataSourceKey.plansPermissions,
          queryName: 'admin_get_plan_permission_summary', error: e);
      rethrow;
    }
  }

  @override
  Future<UserEntitlements> getUserEntitlements({required String userId}) async {
    try {
      final admin = await _admin();
      final detail =
          await _queries.getUserAccountDetail(admin: admin, userId: userId);
      final flags = await _queries.getFeatureFlags(
          admin: admin, limit: FeatureFlagKey.values.length);
      final featureFlags = <FeatureFlagKey, bool>{
        for (final flag in flags) flag.key: flag.enabled,
      };

      _setLive(AdminDataSourceKey.plansPermissions,
          queryName: SupabaseAdminQueries.rpcUserAccountDetail, rowCount: 1);
      return UserEntitlements(
        userId: detail.userId,
        currentPlan: detail.plan,
        billingStatus: detail.billingStatus,
        subscriptionProvider: detail.subscriptionProvider,
        trialStart: null,
        trialEnd: null,
        storageLimitBytes: detail.storageLimitBytes,
        aiTokenLimitMonthly: detail.aiTokenLimitThisMonth,
        profileLimit: detail.profileLimit,
        uploadLimit: detail.uploadLimit,
        featureFlags: featureFlags,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getUserEntitlements failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.plansPermissions,
              queryName: SupabaseAdminQueries.rpcUserAccountDetail);
        _setMock(AdminDataSourceKey.plansPermissions,
            queryName: SupabaseAdminQueries.rpcUserAccountDetail,
            message: 'User entitlements are mocked (debug only).');
        return _fallback.getUserEntitlements(userId: userId);
      }
      _setError(AdminDataSourceKey.plansPermissions,
          queryName: SupabaseAdminQueries.rpcUserAccountDetail, error: e);
      rethrow;
    }
  }

  @override
  Future<List<FeatureFlagDefinition>> listFeatureFlags(
      {required int limit}) async {
    try {
      final admin = await _admin();
      final rows = await _queries.getFeatureFlags(admin: admin, limit: limit);
      _setLive(AdminDataSourceKey.plansPermissions,
          queryName: 'admin_feature_flags', rowCount: rows.length);
      return rows;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listFeatureFlags failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.plansPermissions,
              queryName: 'admin_feature_flags');
        _setMock(AdminDataSourceKey.plansPermissions,
            queryName: 'admin_feature_flags',
            message: 'Feature flags are mocked (debug only).');
        return _fallback.listFeatureFlags(limit: limit);
      }
      _setError(AdminDataSourceKey.plansPermissions,
          queryName: 'admin_feature_flags', error: e);
      rethrow;
    }
  }

  @override
  Future<List<LimitOverrideRow>> listLimitOverrides(
      {required int limit}) async {
    if (_mustFailClosed)
      _throwNotInstrumented(AdminDataSourceKey.plansPermissions,
          queryName: 'limit_overrides');
    _setMock(AdminDataSourceKey.plansPermissions,
        queryName: 'limit_overrides',
        message: 'Limit overrides are mocked (debug only).');
    return _fallback.listLimitOverrides(limit: limit);
  }

  @override
  Future<UsageAnalyticsSnapshot> getUsageAnalyticsSnapshot(
      {required UsageAnalyticsQuery query}) async {
    try {
      final admin = await _admin();
      final res =
          await _queries.getUsageAnalyticsSummary(admin: admin, query: query);
      _setLive(AdminDataSourceKey.usageAnalytics,
          queryName: SupabaseAdminQueries.rpcUsageEventsSummary,
          rowCount: res.featureUsage.length);
      return res;
    } catch (e) {
      debugPrint(
          'SupabaseAdminRepository.getUsageAnalyticsSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.usageAnalytics,
              queryName: 'admin_get_usage_events_summary');
        _setMock(AdminDataSourceKey.usageAnalytics,
            queryName: 'admin_get_usage_events_summary');
        return _fallback.getUsageAnalyticsSnapshot(query: query);
      }
      _setError(AdminDataSourceKey.usageAnalytics,
          queryName: 'admin_get_usage_events_summary', error: e);
      rethrow;
    }
  }

  @override
  Future<StorageSnapshot> getStorageSnapshot(
      {required StorageQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getStorageUsage(admin: admin, query: query);
      _setLive(AdminDataSourceKey.storage, queryName: res.name, rowCount: 1);
      return res.value;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getStorageSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.storage,
              queryName: SupabaseAdminQueries.rpcStorageSummaryV2);
        _setMock(AdminDataSourceKey.storage,
            queryName: SupabaseAdminQueries.rpcStorageSummaryV2);
        return _fallback.getStorageSnapshot(query: query);
      }
      _setError(AdminDataSourceKey.storage,
          queryName: SupabaseAdminQueries.rpcStorageSummaryV2, error: e);
      rethrow;
    }
  }

  @override
  Future<AiUsageSnapshot> getAiUsageSnapshot(
      {required AiUsageQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getAIUsage(admin: admin, query: query);
      _setLive(
        AdminDataSourceKey.aiUsage,
        queryName: res.source,
        rowCount: 1,
        message: res.sourceNote,
      );
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getAiUsageSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.aiUsage,
              queryName: SupabaseAdminQueries.rpcAiUsageSummaryV2);
        _setMock(AdminDataSourceKey.aiUsage,
            queryName: SupabaseAdminQueries.rpcAiUsageSummaryV2);
        return _fallback.getAiUsageSnapshot(query: query);
      }
      _setError(AdminDataSourceKey.aiUsage,
          queryName: SupabaseAdminQueries.rpcAiUsageSummaryV2, error: e);
      rethrow;
    }
  }

  @override
  Future<BillingSnapshot> getBillingSnapshot(
      {required BillingQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getBillingSummary(admin: admin, query: query);
      final diag = await _probeBillingDataSources(res.diagnostics);
      final withDiag = BillingSnapshot(
        query: res.query,
        overview: res.overview,
        subscriptions: res.subscriptions,
        trials: res.trials,
        failedPayments: res.failedPayments,
        revenueByPlan: res.revenueByPlan,
        revenueByCountry: res.revenueByCountry,
        revenueCat: res.revenueCat,
        diagnostics: diag,
        generatedAt: res.generatedAt,
      );

      _setLive(
        AdminDataSourceKey.billing,
        queryName: diag?.summarySource ?? res.diagnostics?.summarySource ?? 'admin_get_billing_summary',
        rowCount: (diag?.dataSources.isNotEmpty ?? false) ? diag!.dataSources.length : 1,
        message: 'Billing diagnostics are privacy-safe; revenue is shown only when instrumented.',
      );
      return withDiag;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getBillingSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.billing,
              queryName: 'admin_get_billing_summary');
        _setMock(AdminDataSourceKey.billing,
            queryName: 'admin_get_billing_summary');
        return _fallback.getBillingSnapshot(query: query);
      }
      _setError(AdminDataSourceKey.billing,
          queryName: 'admin_get_billing_summary', error: e);
      rethrow;
    }
  }

  Future<BillingDiagnostics?> _probeBillingDataSources(
      BillingDiagnostics? base) async {
    final client = _client;
    if (client == null) return base;

    final now = DateTime.now().toUtc();
    final out = <BillingDataSourceStatusRow>[];

    Future<void> addCount(String name, String table,
        {String? note,
        Map<String, dynamic>? eq,
        int cap = 5000}) async {
      try {
        dynamic q = client.from(table).select('id').limit(cap);
        if (eq != null) {
          for (final e in eq.entries) {
            q = q.eq(e.key, e.value);
          }
        }
        final dynamic res = await q;
        int? n;
        if (res is List) n = res.length;
        if (res is PostgrestResponse) {
          final data = res.data;
          if (data is List) n = data.length;
        }
        final cappedNote = (n != null && n >= cap)
            ? 'Count capped at $cap rows for safety.'
            : null;
        out.add(BillingDataSourceStatusRow(
            name: name,
            queryOrTable: table,
            kind: AdminDataSourceKind.live,
            rowCount: n,
            lastRefreshedAt: now,
            safeError: cappedNote ?? note));
      } catch (e) {
        final kind = _isMissingRelationError(e)
            ? AdminDataSourceKind.notInstrumented
            : AdminDataSourceKind.error;
        out.add(BillingDataSourceStatusRow(
            name: name,
            queryOrTable: table,
            kind: kind,
            rowCount: null,
            lastRefreshedAt: now,
            safeError: formatAdminSafeError(e)));
      }
    }

    // Summary RPC is already represented in `base.summarySource`.
    out.add(BillingDataSourceStatusRow(
        name: 'Billing summary',
        queryOrTable: base?.summarySource ?? 'admin_get_billing_summary',
        kind: AdminDataSourceKind.live,
        rowCount: null,
        lastRefreshedAt: now));

    await addCount('Entitlements', 'user_entitlements', cap: 5000);
    await addCount('Entitlements (RevenueCat)', 'user_entitlements',
        eq: {'provider': 'revenuecat'}, cap: 5000);
    await addCount('Subscription events', 'subscription_events', cap: 5000);
    await addCount('RevenueCat webhooks', 'revenuecat_webhook_events', cap: 5000);

    // Stripe tables are not expected in this project; probe defensively.
    await addCount('Stripe events', 'stripe_webhook_events', cap: 2000);

    if (base == null)
      return BillingDiagnostics(
          summarySource: 'admin_get_billing_summary',
          revenueSource: BillingRevenueSource.unknown,
          sections: const {},
          dataSources: out);

    return BillingDiagnostics(
      summarySource: base.summarySource,
      revenueSource: base.revenueSource,
      sections: base.sections,
      dataSources: out,
    );
  }

  @override
  Future<ComplianceSnapshot> getComplianceSnapshot(
      {required ComplianceQuery query}) async {
    try {
      final admin = await _admin();
      final res =
          await _queries.getComplianceRequests(admin: admin, query: query);
      _setLive(AdminDataSourceKey.compliance,
          queryName: 'admin_get_compliance_summary',
          rowCount: res.exportRequests.length + res.deletionRequests.length);
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getComplianceSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.compliance,
              queryName: 'admin_get_compliance_summary');
        _setMock(AdminDataSourceKey.compliance,
            queryName: 'admin_get_compliance_summary');
        return _fallback.getComplianceSnapshot(query: query);
      }
      _setError(AdminDataSourceKey.compliance,
          queryName: 'admin_get_compliance_summary', error: e);
      rethrow;
    }
  }

  @override
  Future<void> performComplianceAction(
      {required ComplianceActionRequest request}) async {
    try {
      final admin = await _admin();
      await _queries.performComplianceAction(admin: admin, request: request);
      _setLive(AdminDataSourceKey.compliance,
          queryName: SupabaseAdminQueries.rpcPerformComplianceAction,
          rowCount: 1);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.performComplianceAction failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.compliance,
              queryName: SupabaseAdminQueries.rpcPerformComplianceAction);
        _setMock(AdminDataSourceKey.compliance,
            queryName: SupabaseAdminQueries.rpcPerformComplianceAction,
            message: 'Compliance actions are mocked (debug only).');
        return _fallback.performComplianceAction(request: request);
      }
      _setError(AdminDataSourceKey.compliance,
          queryName: SupabaseAdminQueries.rpcPerformComplianceAction, error: e);
      rethrow;
    }
  }

  @override
  Future<SystemHealthSnapshot> getSystemHealthSnapshot(
      {required SystemHealthQuery query}) async {
    try {
      final admin = await _admin();
      final rowRes = await _queries.getSystemHealthSummaryRow(admin: admin);
      final row = rowRes.value;

      // Empty / missing: treat as no data yet (not an error).
      final recentUsage =
          (row?['recent_usage_events_24h'] ?? row?['usage_events_24h']) as num?;
      final recentErrors =
          (row?['recent_errors_24h'] ?? row?['error_events_24h']) as num?;
      final failedUploads =
          (row?['failed_upload_events_24h'] as num?)?.toInt() ?? 0;
      final failedSyncs =
          (row?['failed_sync_events_24h'] as num?)?.toInt() ?? 0;

      final usage = recentUsage?.toInt() ?? 0;
      final errors = recentErrors?.toInt() ?? 0;
      final errorRate = usage <= 0 ? 0.0 : (errors / usage).clamp(0.0, 1.0);

      ServiceHealthStatus statusFromRate() {
        if (usage == 0) return ServiceHealthStatus.unknown;
        if (errorRate < 0.02) return ServiceHealthStatus.healthy;
        if (errorRate < 0.08) return ServiceHealthStatus.degraded;
        return ServiceHealthStatus.down;
      }

      final overviewStatus = statusFromRate();

      final snap = SystemHealthSnapshot(
        query: query,
        overview: SystemOverviewMetrics(
          apiStatus: overviewStatus,
          databaseStatus: ServiceHealthStatus.healthy,
          storageStatus: overviewStatus,
          authStatus: ServiceHealthStatus.healthy,
          aiServiceStatus: ServiceHealthStatus.unknown,
          lastSuccessfulScheduledJob: DateTime.now().toUtc(),
          errorRateLast24h: errorRate,
          failedUploadsLast24h: failedUploads,
          failedSyncsLast24h: failedSyncs,
        ),
        apiEndpoints: const [],
        sync: SyncHealthMetrics(
            successfulSyncs: 0,
            failedSyncs: failedSyncs,
            usersWithRepeatedSyncFailure: 0,
            avgSyncDurationMs: 0,
            lastSyncJobStatus: usage == 0 ? 'unknown' : 'ok'),
        upload: UploadHealthMetrics(
            uploadAttempts: 0,
            uploadSuccessRate: usage == 0 ? 0 : (1.0 - errorRate),
            uploadFailureRate: errorRate,
            averageUploadSizeBucket: '—',
            storageErrors: 0,
            permissionErrors: 0,
            timeoutErrors: 0),
        ai: const AiServiceHealthMetrics(
            aiRequests: 0,
            aiSuccessRate: 0,
            aiFailureRate: 0,
            averageLatencyMs: 0,
            errorCodes: {},
            rateLimitEvents: 0),
        appVersions: const [],
        errorLogs: const [],
        generatedAt: DateTime.now().toUtc(),
      );

      _setLive(AdminDataSourceKey.systemHealth,
          queryName: rowRes.name, rowCount: row == null ? 0 : 1);
      return snap;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getSystemHealthSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed)
          _throwNotInstrumented(AdminDataSourceKey.systemHealth,
              queryName: SupabaseAdminQueries.rpcSystemHealthSummary);
        _setMock(AdminDataSourceKey.systemHealth,
            queryName: SupabaseAdminQueries.rpcSystemHealthSummary);
        return _fallback.getSystemHealthSnapshot(query: query);
      }
      _setError(AdminDataSourceKey.systemHealth,
          queryName: SupabaseAdminQueries.rpcSystemHealthSummary, error: e);
      rethrow;
    }
  }

  @override
  Future<WebsiteCmsStatusSnapshot> getWebsiteCmsStatus() async {
    final client = _client;
    if (client == null) throw StateError('Supabase not initialized/configured.');

    const uiConnectedByTable = <String, bool>{
      'marketing_pages': true,
      'marketing_sections': true,
      'marketing_blog_posts': true,
      'marketing_faqs': true,
      'marketing_pricing_plans': true,
      'marketing_testimonials': true,
      'marketing_campaigns': true,
      'marketing_seo_settings': true,
      'marketing_media_assets': true,
    };

    const tables = <String>[
      'marketing_pages',
      'marketing_sections',
      'marketing_blog_posts',
      'marketing_faqs',
      'marketing_pricing_plans',
      'marketing_testimonials',
      'marketing_campaigns',
      'marketing_seo_settings',
      'marketing_media_assets',
    ];

    try {
      final rows = <WebsiteCmsTableStatusRow>[];
      for (final table in tables) {
        final uiConnected = uiConnectedByTable[table] ?? false;
        try {
          final rowCount = await _safeCountTable(client, table);

          DateTime? latestUpdatedAt;
          try {
            final latest = await client
                .from(table)
                .select('updated_at')
                .order('updated_at', ascending: false)
                .limit(1)
                .maybeSingle();
            latestUpdatedAt = _tryParseDateTime(latest?['updated_at']);
          } catch (e) {
            // It's OK if `updated_at` doesn't exist or isn't accessible.
            debugPrint('Website CMS status: failed to read latest updated_at for $table: $e');
          }

          // RLS enabled is not reliably queryable via PostgREST from the client.
          // Return null (unknown) rather than a wrong value.
          final bool? rlsEnabled = null;

          final status = !uiConnected
              ? WebsiteCmsTableOverallStatus.missingUi
              : (rowCount == 0
                  ? WebsiteCmsTableOverallStatus.empty
                  : WebsiteCmsTableOverallStatus.live);

          rows.add(
            WebsiteCmsTableStatusRow(
              tableName: table,
              exists: true,
              uiConnected: uiConnected,
              rowCount: rowCount,
              latestUpdatedAt: latestUpdatedAt,
              rlsEnabled: rlsEnabled,
              status: status,
            ),
          );
        } catch (e) {
          if (_isMissingRelationError(e)) {
            rows.add(
              WebsiteCmsTableStatusRow(
                tableName: table,
                exists: false,
                uiConnected: uiConnected,
                rowCount: null,
                latestUpdatedAt: null,
                rlsEnabled: null,
                status: WebsiteCmsTableOverallStatus.missingTable,
                safeErrorMessage: null,
              ),
            );
          } else {
            rows.add(
              WebsiteCmsTableStatusRow(
                tableName: table,
                exists: true,
                uiConnected: uiConnected,
                rowCount: null,
                latestUpdatedAt: null,
                rlsEnabled: null,
                status: WebsiteCmsTableOverallStatus.error,
                safeErrorMessage: formatAdminSafeError(e),
              ),
            );
          }
        }
      }

      final snap = WebsiteCmsStatusSnapshot(rows: rows, generatedAt: DateTime.now().toUtc());
      _setLive(AdminDataSourceKey.websiteCms, queryName: 'marketing tables probe', rowCount: rows.length);
      return snap;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getWebsiteCmsStatus failed: $e');
      _setError(AdminDataSourceKey.websiteCms, queryName: 'marketing tables probe', error: e);
      rethrow;
    }
  }

  @override
  Future<MarketingCmsSnapshot> getMarketingCmsSnapshot() async {
    final client = _client;
    if (client == null) throw StateError('Supabase not initialized/configured.');

    try {
      final pageRows = await client
          .from('marketing_pages')
          .select('id, slug, title, status, template, excerpt, seo_title, seo_description, published_at, scheduled_for, updated_at, created_at')
          .order('updated_at', ascending: false);
      final sectionRows = await client
          .from('marketing_sections')
          .select('id, page_id, section_key, section_type, sort_order, status, eyebrow, title, body, updated_at')
          .order('sort_order', ascending: true);
      final categoryRows = await client.from('marketing_blog_categories').select('id, slug, name, description, is_active').order('sort_order', ascending: true);
      final postRows = await client
          .from('marketing_blog_posts')
          .select('id, slug, title, status, excerpt, category_id, seo_title, seo_description, published_at, scheduled_for, updated_at, created_at')
          .order('updated_at', ascending: false);

      final snapshot = MarketingCmsSnapshot(
        pages: _asList(pageRows).map(_marketingPageFromRow).toList(),
        sections: _asList(sectionRows).map(_marketingSectionFromRow).toList(),
        categories: _asList(categoryRows).map(_marketingCategoryFromRow).toList(),
        blogPosts: _asList(postRows).map(_marketingBlogPostFromRow).toList(),
        generatedAt: DateTime.now().toUtc(),
      );
      _setLive(AdminDataSourceKey.websiteCms, queryName: 'marketing CMS snapshot', rowCount: snapshot.pages.length + snapshot.sections.length + snapshot.blogPosts.length);
      return snapshot;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getMarketingCmsSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (_mustFailClosed) _throwNotInstrumented(AdminDataSourceKey.websiteCms, queryName: 'marketing CMS snapshot');
        _setMock(AdminDataSourceKey.websiteCms, queryName: 'marketing CMS snapshot');
        return _fallback.getMarketingCmsSnapshot();
      }
      _setError(AdminDataSourceKey.websiteCms, queryName: 'marketing CMS snapshot', error: e);
      rethrow;
    }
  }

  @override
  Future<void> saveMarketingPage({required MarketingPageDraft draft}) async {
    final client = _client;
    if (client == null) throw StateError('Supabase not initialized/configured.');
    final admin = await _admin();
    final isUpdate = draft.id != null;
    final row = <String, dynamic>{
      'slug': draft.slug,
      'title': draft.title,
      'status': draft.status.value,
      'template': draft.template,
      'excerpt': _blankToNull(draft.excerpt),
      'seo_title': _blankToNull(draft.seoTitle),
      'seo_description': _blankToNull(draft.seoDescription),
      'scheduled_for': draft.scheduledFor?.toUtc().toIso8601String(),
      'updated_by': admin.id,
      if (!isUpdate) 'created_by': admin.id,
    };
    if (isUpdate) {
      await client.from('marketing_pages').update(row).eq('id', draft.id!);
    } else {
      await client.from('marketing_pages').insert(row);
    }
    await _auditCmsAction(
      actionType: isUpdate ? 'cms_page_updated' : 'cms_page_created',
      resourceType: 'marketing_page',
      resourceId: draft.id,
      newValue: {'slug': draft.slug, 'status': draft.status.value},
    );
  }

  @override
  Future<void> saveMarketingSection({required MarketingSectionDraft draft}) async {
    final client = _client;
    if (client == null) throw StateError('Supabase not initialized/configured.');
    final admin = await _admin();
    final isUpdate = draft.id != null;
    final row = <String, dynamic>{
      'page_id': draft.pageId,
      'section_key': draft.sectionKey,
      'section_type': draft.sectionType,
      'sort_order': draft.sortOrder,
      'status': draft.status.value,
      'eyebrow': _blankToNull(draft.eyebrow),
      'title': _blankToNull(draft.title),
      'body': _blankToNull(draft.body),
      'updated_by': admin.id,
      if (!isUpdate) 'created_by': admin.id,
    };
    if (isUpdate) {
      await client.from('marketing_sections').update(row).eq('id', draft.id!);
    } else {
      await client.from('marketing_sections').insert(row);
    }
    await _auditCmsAction(
      actionType: isUpdate ? 'cms_section_updated' : 'cms_section_created',
      resourceType: 'marketing_section',
      resourceId: draft.id,
      newValue: {'page_id': draft.pageId, 'section_key': draft.sectionKey, 'status': draft.status.value},
    );
  }

  @override
  Future<void> saveMarketingBlogPost({required MarketingBlogPostDraft draft}) async {
    final client = _client;
    if (client == null) throw StateError('Supabase not initialized/configured.');
    final admin = await _admin();
    final isUpdate = draft.id != null;
    final row = <String, dynamic>{
      'slug': draft.slug,
      'title': draft.title,
      'status': draft.status.value,
      'excerpt': _blankToNull(draft.excerpt),
      'body_markdown': _blankToNull(draft.bodyMarkdown),
      'category_id': _blankToNull(draft.categoryId),
      'seo_title': _blankToNull(draft.seoTitle),
      'seo_description': _blankToNull(draft.seoDescription),
      'scheduled_for': draft.scheduledFor?.toUtc().toIso8601String(),
      'updated_by': admin.id,
      if (!isUpdate) 'created_by': admin.id,
    };
    if (isUpdate) {
      await client.from('marketing_blog_posts').update(row).eq('id', draft.id!);
    } else {
      await client.from('marketing_blog_posts').insert(row);
    }
    await _auditCmsAction(
      actionType: isUpdate ? 'cms_blog_post_updated' : 'cms_blog_post_created',
      resourceType: 'marketing_blog_post',
      resourceId: draft.id,
      newValue: {'slug': draft.slug, 'status': draft.status.value},
    );
  }

  @override
  Future<void> updateMarketingContentStatus({required String resourceType, required String resourceId, required MarketingContentStatus status}) async {
    final client = _client;
    if (client == null) throw StateError('Supabase not initialized/configured.');
    final admin = await _admin();
    final now = DateTime.now().toUtc().toIso8601String();
    final table = switch (resourceType) {
      'page' => 'marketing_pages',
      'blog_post' => 'marketing_blog_posts',
      _ => throw ArgumentError.value(resourceType, 'resourceType', 'Unsupported CMS resource type'),
    };
    final row = <String, dynamic>{
      'status': status.value,
      'updated_by': admin.id,
      if (status == MarketingContentStatus.published) ...{
        'published_at': now,
        'published_by': admin.id,
        'scheduled_for': null,
        'archived_at': null,
      },
      if (status == MarketingContentStatus.draft) ...{
        'scheduled_for': null,
        'archived_at': null,
      },
      if (status == MarketingContentStatus.archived) 'archived_at': now,
    };
    await client.from(table).update(row).eq('id', resourceId);
    await _auditCmsAction(
      actionType: switch (status) {
        MarketingContentStatus.published => 'cms_${resourceType}_published',
        MarketingContentStatus.archived => 'cms_${resourceType}_archived',
        MarketingContentStatus.draft => 'cms_${resourceType}_unpublished',
        MarketingContentStatus.review => 'cms_${resourceType}_sent_to_review',
        MarketingContentStatus.scheduled => 'cms_${resourceType}_scheduled',
      },
      resourceType: 'marketing_$resourceType',
      resourceId: resourceId,
      newValue: {'status': status.value},
    );
  }

  List<Map<String, dynamic>> _asList(dynamic rows) {
    if (rows is List) return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    return const [];
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  DateTime _requiredDate(dynamic value) => _tryParseDateTime(value) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  MarketingPageRow _marketingPageFromRow(Map<String, dynamic> row) => MarketingPageRow(
        id: row['id']?.toString() ?? '',
        slug: row['slug']?.toString() ?? '',
        title: row['title']?.toString() ?? 'Untitled page',
        status: MarketingContentStatus.parse(row['status']?.toString()),
        template: row['template']?.toString(),
        excerpt: row['excerpt']?.toString(),
        seoTitle: row['seo_title']?.toString(),
        seoDescription: row['seo_description']?.toString(),
        publishedAt: _tryParseDateTime(row['published_at']),
        scheduledFor: _tryParseDateTime(row['scheduled_for']),
        updatedAt: _requiredDate(row['updated_at']),
        createdAt: _requiredDate(row['created_at']),
      );

  MarketingPageSectionRow _marketingSectionFromRow(Map<String, dynamic> row) => MarketingPageSectionRow(
        id: row['id']?.toString() ?? '',
        pageId: row['page_id']?.toString() ?? '',
        sectionKey: row['section_key']?.toString() ?? '',
        sectionType: row['section_type']?.toString() ?? 'content',
        sortOrder: row['sort_order'] is int ? row['sort_order'] as int : int.tryParse(row['sort_order']?.toString() ?? '') ?? 0,
        status: MarketingContentStatus.parse(row['status']?.toString()),
        eyebrow: row['eyebrow']?.toString(),
        title: row['title']?.toString(),
        body: row['body']?.toString(),
        updatedAt: _requiredDate(row['updated_at']),
      );

  MarketingBlogCategoryRow _marketingCategoryFromRow(Map<String, dynamic> row) => MarketingBlogCategoryRow(
        id: row['id']?.toString() ?? '',
        slug: row['slug']?.toString() ?? '',
        name: row['name']?.toString() ?? 'Uncategorised',
        description: row['description']?.toString(),
        isActive: row['is_active'] == true,
      );

  MarketingBlogPostRow _marketingBlogPostFromRow(Map<String, dynamic> row) => MarketingBlogPostRow(
        id: row['id']?.toString() ?? '',
        slug: row['slug']?.toString() ?? '',
        title: row['title']?.toString() ?? 'Untitled post',
        status: MarketingContentStatus.parse(row['status']?.toString()),
        excerpt: row['excerpt']?.toString(),
        categoryId: row['category_id']?.toString(),
        seoTitle: row['seo_title']?.toString(),
        seoDescription: row['seo_description']?.toString(),
        publishedAt: _tryParseDateTime(row['published_at']),
        scheduledFor: _tryParseDateTime(row['scheduled_for']),
        updatedAt: _requiredDate(row['updated_at']),
        createdAt: _requiredDate(row['created_at']),
      );

  Future<void> _auditCmsAction({required String actionType, required String resourceType, String? resourceId, Map<String, dynamic>? newValue}) async {
    final admin = await _admin();
    await createAuditLog(
      entry: AdminAuditLogCreate(
        adminUserId: admin.id,
        actionType: actionType,
        result: 'success',
        newValue: <String, dynamic>{
          'resource_type': resourceType,
          if (resourceId != null) 'resource_id': resourceId,
          if (newValue != null) ...newValue,
        },
      ),
    );
  }

  @override
  Future<SecurityChecklistSnapshot> getSecurityChecklistSnapshot() async {
    // Not part of the requested list, but never show mock silently in release.
    if (_mustFailClosed) throw AdminNotInstrumentedException();
    return _fallback.getSecurityChecklistSnapshot();
  }
}

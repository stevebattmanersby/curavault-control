import 'package:curavault_admin/admin/data/admin_repository.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/mock_data/mock_fallback_data.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_admin_queries.dart';
import 'package:curavault_admin/admin/utils/audit_redactor.dart';
import 'package:curavault_admin/admin/utils/client_context.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed repository implementation.
///
/// It queries only privacy-safe summary tables/views and enforces RBAC.
///
/// If a required view/RPC isn't deployed yet, it falls back to mock data via
/// [MockFallbackData] (clearly separated), while still keeping audit logging live.
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository({SupabaseAdminQueries? queries, AdminRepository? fallback})
      : _queries = queries ?? SupabaseAdminQueries(),
        _fallback = fallback ?? MockFallbackData.create();

  final SupabaseAdminQueries _queries;
  final AdminRepository _fallback;

  final Map<AdminDataSourceKey, AdminDataSourceStatus> _sources = <AdminDataSourceKey, AdminDataSourceStatus>{};

  AdminDataSourceStatus getSource(AdminDataSourceKey key) =>
      _sources[key] ?? const AdminDataSourceStatus(kind: AdminDataSourceKind.live);

  void _set(AdminDataSourceKey key, AdminDataSourceStatus status) {
    _sources[key] = status;
  }

  AdminUser? _cachedAdmin;

  Future<AdminUser> _admin() async => _cachedAdmin ??= await _queries.getCurrentAdminUser();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool _isMissingRelationError(Object e) {
    // PostgrestException message differs by environment; be permissive.
    final msg = e.toString().toLowerCase();
    return msg.contains('relation') && msg.contains('does not exist') || msg.contains('404');
  }

  Never _throwNotInstrumented(AdminDataSourceKey key) {
    final status = const AdminDataSourceStatus(kind: AdminDataSourceKind.notInstrumented, message: 'This data source is not instrumented yet.');
    _set(key, status);
    throw AdminNotInstrumentedException(status.message!);
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
      'result': entry.result ?? 'success',
      if (entry.previousValue != null) 'prev': AdminAuditRedactor.redactMap(entry.previousValue!),
      if (entry.newValue != null) 'next': AdminAuditRedactor.redactMap(entry.newValue!),
      if (entry.reason != null) 'reason': entry.reason,
      if (entry.ticketReference != null) 'ticket_id': entry.ticketReference,
      if (AdminClientContext.ipAddress != null) 'ip': AdminClientContext.ipAddress,
      if (AdminClientContext.userAgent != null) 'user_agent': AdminClientContext.userAgent,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    await c.from('admin_audit_log').insert(row);
  }

  @override
  Future<List<UserAccountSummary>> listUsers({required UserListQuery query, required int limit}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getUsersList(admin: admin, query: query, limit: limit);
      _set(AdminDataSourceKey.users, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listUsers failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.users);
        _set(AdminDataSourceKey.users, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.listUsers(query: query, limit: limit);
      }
      _set(AdminDataSourceKey.users, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<UserAccountDetail> getUserDetail({required String userId}) async {
    // Until a dedicated safe view exists, use mock fallback.
    // (The UI already treats this as privacy-safe; do NOT query raw tables here.)
    if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.users);
    _set(AdminDataSourceKey.users, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'User detail is mocked (debug only).'));
    return _fallback.getUserDetail(userId: userId);
  }

  @override
  Future<void> performUserAdminAction({required AdminActionRequest request}) async {
    // Sensitive actions should be executed server-side (RPC/edge function) with
    // enforced RBAC + mandatory audit logging.
    //
    // Until the RPC is deployed, keep mock behavior (still audited in UI layer).
    if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.users);
    _set(AdminDataSourceKey.users, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'User admin actions are mocked (debug only).'));
    return _fallback.performUserAdminAction(request: request);
  }

  @override
  Future<List<AuditLogEntry>> listAuditLogs({required AuditLogQuery query, required int limit}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getAuditLogs(admin: admin, query: query, limit: limit);
      // Audit logs are always live when possible; treat missing as not instrumented in release.
      _set(AdminDataSourceKey.auditLogs, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listAuditLogs failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.auditLogs);
        _set(AdminDataSourceKey.auditLogs, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.listAuditLogs(query: query, limit: limit);
      }
      _set(AdminDataSourceKey.auditLogs, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
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
        failedAdminActions24h: (row?['failed_admin_actions_24h'] as num?)?.toInt() ?? 0,
        latestAuditEventAt: DateTime.tryParse((row?['latest_audit_event_at'] ?? '').toString()),
        generatedAt: DateTime.now().toUtc(),
      );
      _set(AdminDataSourceKey.auditLogs, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return snap;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getAuditSummary failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.auditLogs);
        _set(AdminDataSourceKey.auditLogs, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getAuditSummary();
      }
      _set(AdminDataSourceKey.auditLogs, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<List<SupportSessionSummary>> listSupportSessions({required SupportQueueQuery query, required int limit}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getSupportSessions(admin: admin, query: query, limit: limit);
      _set(AdminDataSourceKey.support, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listSupportSessions failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.support);
        _set(AdminDataSourceKey.support, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.listSupportSessions(query: query, limit: limit);
      }
      _set(AdminDataSourceKey.support, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
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
        latestSessionAt: DateTime.tryParse((row?['latest_session_at'] ?? '').toString()),
        generatedAt: DateTime.now().toUtc(),
      );
      _set(AdminDataSourceKey.support, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return snap;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getSupportSummary failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.support);
        _set(AdminDataSourceKey.support, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getSupportSummary();
      }
      _set(AdminDataSourceKey.support, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<SupportSessionDetail> getSupportSessionDetail({required String supportSessionId}) async {
    if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.support);
    _set(AdminDataSourceKey.support, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Support session detail is mocked (debug only).'));
    return _fallback.getSupportSessionDetail(supportSessionId: supportSessionId);
  }

  @override
  Future<DiagnosticsReport> runDiagnostics({required String userId}) async => _fallback.runDiagnostics(userId: userId);

  @override
  Future<void> performSupportAction({required SupportActionRequest request}) async => _fallback.performSupportAction(request: request);

  @override
  Future<DashboardSnapshot> getDashboardSnapshot({required DashboardQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getDashboardMetrics(admin: admin, query: query);
      _set(AdminDataSourceKey.dashboard, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getDashboardSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.dashboard);
        _set(AdminDataSourceKey.dashboard, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getDashboardSnapshot(query: query);
      }
      _set(AdminDataSourceKey.dashboard, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
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
            storageLimitBytes: ((r['storage_limit_mb'] as num?)?.toInt() ?? 0) * 1048576,
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

      _set(AdminDataSourceKey.plansPermissions, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return out;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listPlansOverview failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.plansPermissions);
        _set(AdminDataSourceKey.plansPermissions, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.listPlansOverview(limit: limit);
      }
      _set(AdminDataSourceKey.plansPermissions, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<UserEntitlements> getUserEntitlements({required String userId}) async {
    if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.plansPermissions);
    _set(AdminDataSourceKey.plansPermissions, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'User entitlements are mocked (debug only).'));
    return _fallback.getUserEntitlements(userId: userId);
  }

  @override
  Future<List<FeatureFlagDefinition>> listFeatureFlags({required int limit}) async {
    if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.plansPermissions);
    _set(AdminDataSourceKey.plansPermissions, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Feature flags are mocked (debug only).'));
    return _fallback.listFeatureFlags(limit: limit);
  }

  @override
  Future<List<LimitOverrideRow>> listLimitOverrides({required int limit}) async {
    if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.plansPermissions);
    _set(AdminDataSourceKey.plansPermissions, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Limit overrides are mocked (debug only).'));
    return _fallback.listLimitOverrides(limit: limit);
  }

  @override
  Future<UsageAnalyticsSnapshot> getUsageAnalyticsSnapshot({required UsageAnalyticsQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getUsageAnalyticsSummary(admin: admin, query: query);
      _set(AdminDataSourceKey.usageAnalytics, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getUsageAnalyticsSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.usageAnalytics);
        _set(AdminDataSourceKey.usageAnalytics, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getUsageAnalyticsSnapshot(query: query);
      }
      _set(AdminDataSourceKey.usageAnalytics, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<StorageSnapshot> getStorageSnapshot({required StorageQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getStorageUsage(admin: admin, query: query);
      _set(AdminDataSourceKey.storage, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getStorageSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.storage);
        _set(AdminDataSourceKey.storage, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getStorageSnapshot(query: query);
      }
      _set(AdminDataSourceKey.storage, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<AiUsageSnapshot> getAiUsageSnapshot({required AiUsageQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getAIUsage(admin: admin, query: query);
      _set(AdminDataSourceKey.aiUsage, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getAiUsageSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.aiUsage);
        _set(AdminDataSourceKey.aiUsage, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getAiUsageSnapshot(query: query);
      }
      _set(AdminDataSourceKey.aiUsage, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<BillingSnapshot> getBillingSnapshot({required BillingQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getBillingSummary(admin: admin, query: query);
      _set(AdminDataSourceKey.billing, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getBillingSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.billing);
        _set(AdminDataSourceKey.billing, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getBillingSnapshot(query: query);
      }
      _set(AdminDataSourceKey.billing, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<ComplianceSnapshot> getComplianceSnapshot({required ComplianceQuery query}) async {
    try {
      final admin = await _admin();
      final res = await _queries.getComplianceRequests(admin: admin, query: query);
      _set(AdminDataSourceKey.compliance, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return res;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getComplianceSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.compliance);
        _set(AdminDataSourceKey.compliance, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getComplianceSnapshot(query: query);
      }
      _set(AdminDataSourceKey.compliance, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<void> performComplianceAction({required ComplianceActionRequest request}) async {
    if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.compliance);
    _set(AdminDataSourceKey.compliance, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Compliance actions are mocked (debug only).'));
    return _fallback.performComplianceAction(request: request);
  }

  @override
  Future<SystemHealthSnapshot> getSystemHealthSnapshot({required SystemHealthQuery query}) async {
    try {
      final admin = await _admin();
      final row = await _queries.getSystemHealthSummaryRow(admin: admin);

      // Empty / missing: treat as no data yet (not an error).
      final recentUsage = (row?['recent_usage_events_24h'] ?? row?['usage_events_24h']) as num?;
      final recentErrors = (row?['recent_errors_24h'] ?? row?['error_events_24h']) as num?;
      final failedUploads = (row?['failed_upload_events_24h'] as num?)?.toInt() ?? 0;
      final failedSyncs = (row?['failed_sync_events_24h'] as num?)?.toInt() ?? 0;

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
        sync: SyncHealthMetrics(successfulSyncs: 0, failedSyncs: failedSyncs, usersWithRepeatedSyncFailure: 0, avgSyncDurationMs: 0, lastSyncJobStatus: usage == 0 ? 'unknown' : 'ok'),
        upload: UploadHealthMetrics(uploadAttempts: 0, uploadSuccessRate: usage == 0 ? 0 : (1.0 - errorRate), uploadFailureRate: errorRate, averageUploadSizeBucket: '—', storageErrors: 0, permissionErrors: 0, timeoutErrors: 0),
        ai: const AiServiceHealthMetrics(aiRequests: 0, aiSuccessRate: 0, aiFailureRate: 0, averageLatencyMs: 0, errorCodes: {}, rateLimitEvents: 0),
        appVersions: const [],
        errorLogs: const [],
        generatedAt: DateTime.now().toUtc(),
      );

      _set(AdminDataSourceKey.systemHealth, const AdminDataSourceStatus(kind: AdminDataSourceKind.live));
      return snap;
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getSystemHealthSnapshot failed: $e');
      if (_isMissingRelationError(e)) {
        if (kReleaseMode) _throwNotInstrumented(AdminDataSourceKey.systemHealth);
        _set(AdminDataSourceKey.systemHealth, const AdminDataSourceStatus(kind: AdminDataSourceKind.mock, message: 'Using mock fallback (debug only).'));
        return _fallback.getSystemHealthSnapshot(query: query);
      }
      _set(AdminDataSourceKey.systemHealth, AdminDataSourceStatus(kind: AdminDataSourceKind.error, message: e.toString()));
      rethrow;
    }
  }

  @override
  Future<SecurityChecklistSnapshot> getSecurityChecklistSnapshot() async {
    // Not part of the requested list, but never show mock silently in release.
    if (kReleaseMode) throw AdminNotInstrumentedException();
    return _fallback.getSecurityChecklistSnapshot();
  }
}

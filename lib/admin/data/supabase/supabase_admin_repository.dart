import 'package:curavault_admin/admin/data/admin_repository.dart';
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
      return await _queries.getUsersList(admin: admin, query: query, limit: limit);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listUsers failed: $e');
      if (_isMissingRelationError(e)) return _fallback.listUsers(query: query, limit: limit);
      rethrow;
    }
  }

  @override
  Future<UserAccountDetail> getUserDetail({required String userId}) async {
    // Until a dedicated safe view exists, use mock fallback.
    // (The UI already treats this as privacy-safe; do NOT query raw tables here.)
    return _fallback.getUserDetail(userId: userId);
  }

  @override
  Future<void> performUserAdminAction({required AdminActionRequest request}) async {
    // Sensitive actions should be executed server-side (RPC/edge function) with
    // enforced RBAC + mandatory audit logging.
    //
    // Until the RPC is deployed, keep mock behavior (still audited in UI layer).
    return _fallback.performUserAdminAction(request: request);
  }

  @override
  Future<List<AuditLogEntry>> listAuditLogs({required AuditLogQuery query, required int limit}) async {
    try {
      final admin = await _admin();
      return await _queries.getAuditLogs(admin: admin, query: query, limit: limit);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listAuditLogs failed: $e');
      if (_isMissingRelationError(e)) return _fallback.listAuditLogs(query: query, limit: limit);
      rethrow;
    }
  }

  @override
  Future<List<SupportSessionSummary>> listSupportSessions({required SupportQueueQuery query, required int limit}) async {
    try {
      final admin = await _admin();
      return await _queries.getSupportSessions(admin: admin, query: query, limit: limit);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.listSupportSessions failed: $e');
      if (_isMissingRelationError(e)) return _fallback.listSupportSessions(query: query, limit: limit);
      rethrow;
    }
  }

  @override
  Future<SupportSessionDetail> getSupportSessionDetail({required String supportSessionId}) async {
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
      return await _queries.getDashboardMetrics(admin: admin, query: query);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getDashboardSnapshot failed: $e');
      if (_isMissingRelationError(e)) return _fallback.getDashboardSnapshot(query: query);
      rethrow;
    }
  }

  @override
  Future<List<PlanOverviewRow>> listPlansOverview({required int limit}) async => _fallback.listPlansOverview(limit: limit);

  @override
  Future<UserEntitlements> getUserEntitlements({required String userId}) async => _fallback.getUserEntitlements(userId: userId);

  @override
  Future<List<FeatureFlagDefinition>> listFeatureFlags({required int limit}) async => _fallback.listFeatureFlags(limit: limit);

  @override
  Future<List<LimitOverrideRow>> listLimitOverrides({required int limit}) async => _fallback.listLimitOverrides(limit: limit);

  @override
  Future<UsageAnalyticsSnapshot> getUsageAnalyticsSnapshot({required UsageAnalyticsQuery query}) async {
    try {
      final admin = await _admin();
      return await _queries.getUsageAnalyticsSummary(admin: admin, query: query);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getUsageAnalyticsSnapshot failed: $e');
      if (_isMissingRelationError(e)) return _fallback.getUsageAnalyticsSnapshot(query: query);
      rethrow;
    }
  }

  @override
  Future<StorageSnapshot> getStorageSnapshot({required StorageQuery query}) async {
    try {
      final admin = await _admin();
      return await _queries.getStorageUsage(admin: admin, query: query);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getStorageSnapshot failed: $e');
      if (_isMissingRelationError(e)) return _fallback.getStorageSnapshot(query: query);
      rethrow;
    }
  }

  @override
  Future<AiUsageSnapshot> getAiUsageSnapshot({required AiUsageQuery query}) async {
    try {
      final admin = await _admin();
      return await _queries.getAIUsage(admin: admin, query: query);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getAiUsageSnapshot failed: $e');
      if (_isMissingRelationError(e)) return _fallback.getAiUsageSnapshot(query: query);
      rethrow;
    }
  }

  @override
  Future<BillingSnapshot> getBillingSnapshot({required BillingQuery query}) async {
    try {
      final admin = await _admin();
      return await _queries.getBillingSummary(admin: admin, query: query);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getBillingSnapshot failed: $e');
      if (_isMissingRelationError(e)) return _fallback.getBillingSnapshot(query: query);
      rethrow;
    }
  }

  @override
  Future<ComplianceSnapshot> getComplianceSnapshot({required ComplianceQuery query}) async {
    try {
      final admin = await _admin();
      return await _queries.getComplianceRequests(admin: admin, query: query);
    } catch (e) {
      debugPrint('SupabaseAdminRepository.getComplianceSnapshot failed: $e');
      if (_isMissingRelationError(e)) return _fallback.getComplianceSnapshot(query: query);
      rethrow;
    }
  }

  @override
  Future<void> performComplianceAction({required ComplianceActionRequest request}) async => _fallback.performComplianceAction(request: request);

  @override
  Future<SystemHealthSnapshot> getSystemHealthSnapshot({required SystemHealthQuery query}) async => _fallback.getSystemHealthSnapshot(query: query);

  @override
  Future<SecurityChecklistSnapshot> getSecurityChecklistSnapshot() async => _fallback.getSecurityChecklistSnapshot();
}

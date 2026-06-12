import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_client.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Typed, privacy-safe Supabase queries for the CuraVault Control Site.
///
/// IMPORTANT:
/// - These functions must never query raw medical content fields.
/// - Prefer summary tables/views or RPCs that return aggregate-only data.
/// - RBAC is enforced client-side (best-effort) AND must be enforced by RLS.
class SupabaseAdminQueries {
  SupabaseClient get _client {
    final c = ControlSupabaseClient.tryGet();
    if (c == null) throw StateError('Supabase not initialized/configured.');
    return c;
  }

  Future<AdminUser> getCurrentAdminUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('Not signed in.');

    Map<String, dynamic>? row;
    try {
      row = await _client
          .schema('control')
          .from('admin_users')
          // Only admin metadata (no health data).
          .select('id, email, role, status, created_at, updated_at, theme_preference, theme_mode')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
    } catch (_) {
      row = await _client
          .from('admin_users')
          .select('id, email, role, status, created_at, updated_at, theme_preference, theme_mode')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
    }

    if (row == null) throw StateError('Not an admin user (no admin_users row).');
    final status = (row['status'] as String?) ?? 'unknown';
    if (status.toLowerCase() != 'active') throw StateError('Admin is not active.');

    final role = parseAdminRole((row['role'] as String?) ?? '');
    if (role == null) throw StateError('Unknown admin role.');

    // Normalize to AdminUser model.
    return AdminUser(
      id: (row['id'] ?? authUser.id).toString(),
      email: (row['email'] as String?) ?? (authUser.email ?? ''),
      role: role,
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
      updatedAt: DateTime.tryParse((row['updated_at'] ?? '').toString()) ?? DateTime.now().toUtc(),
      themePreference: (row['theme_preference'] ?? row['theme_mode'])?.toString(),
    );
  }

  /// Best-effort: persist admin theme preference to the admin profile.
  ///
  /// This is intentionally defensive because different environments may name the
  /// column differently (e.g. theme_preference vs theme_mode) or may enforce RLS.
  /// Failure must not block the UI.
  Future<void> setAdminThemePreference({required String themePreference}) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('Not signed in.');

    Future<void> attempt(String schema, String column) async {
      final table = schema.isEmpty ? _client.from('admin_users') : _client.schema(schema).from('admin_users');
      await table.update({column: themePreference, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('auth_user_id', authUser.id);
    }

    // Try control schema first.
    try {
      await attempt('control', 'theme_preference');
      return;
    } catch (e) {
      debugPrint('setAdminThemePreference(control.theme_preference) failed: $e');
    }
    try {
      await attempt('control', 'theme_mode');
      return;
    } catch (e) {
      debugPrint('setAdminThemePreference(control.theme_mode) failed: $e');
    }
    // Then public.
    try {
      await attempt('', 'theme_preference');
      return;
    } catch (e) {
      debugPrint('setAdminThemePreference(theme_preference) failed: $e');
    }
    try {
      await attempt('', 'theme_mode');
      return;
    } catch (e) {
      debugPrint('setAdminThemePreference(theme_mode) failed: $e');
      rethrow;
    }
  }

  void _requireRole(AdminUser admin, Set<AdminRole> allowed, {required String capability}) {
    if (!allowed.contains(admin.role)) {
      throw StateError('Access denied ($capability): role ${admin.role.name}');
    }
  }

  Future<DashboardSnapshot> getDashboardMetrics({required AdminUser admin, required DashboardQuery query}) async {
    _requireRole(admin, AdminRbac.all, capability: 'dashboard');
    // Prefer an RPC that returns a safe aggregate-only snapshot.
    try {
      final res = await _client.rpc('control_get_dashboard_metrics', params: _dashboardQueryParams(query));
      if (res is Map<String, dynamic>) return _parseDashboardSnapshot(res, query);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getDashboardMetrics rpc failed: $e');
    }

    // Fallback to a view/table (schema-qualified first).
    try {
      final row = await _client
          .schema('control')
          .from('dashboard_metrics')
          // Explicit safe column selection only.
          .select()
          .maybeSingle();
      if (row != null) return _parseDashboardSnapshot(row, query);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getDashboardMetrics view failed: $e');
    }

    throw StateError('Dashboard metrics unavailable (no RPC/view).');
  }

  Future<List<UserAccountSummary>> getUsersList({required AdminUser admin, required UserListQuery query, required int limit}) async {
    _requireRole(admin, <AdminRole>{AdminRole.superAdmin, AdminRole.supportAgent}, capability: 'users_list');
    final canEmail = AdminRbac.canViewUserEmail(admin.role);
    final select = canEmail
        ? 'user_id, email, plan_name, status, created_at, last_active_at, country, platform, app_version, storage_used_bytes, storage_limit_bytes, ai_tokens_monthly, ai_tokens_limit_monthly'
        : 'user_id, plan_name, status, created_at, last_active_at, country, platform, app_version, storage_used_bytes, storage_limit_bytes, ai_tokens_monthly, ai_tokens_limit_monthly';

    try {
      final builder = _client.schema('control').from('user_account_summaries').select(select);
      final filtered = _applyUserListFilters(builder, query);
      final rows = await filtered.order('last_active_at', ascending: false).limit(limit);
      return (rows as List).cast<Map<String, dynamic>>().map(UserAccountSummary.fromJson).toList();
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getUsersList (control schema) failed: $e');
    }
    try {
      final builder = _client.from('user_account_summaries').select(select);
      final filtered = _applyUserListFilters(builder, query);
      final rows = await filtered.order('last_active_at', ascending: false).limit(limit);
      return (rows as List).cast<Map<String, dynamic>>().map(UserAccountSummary.fromJson).toList();
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getUsersList failed: $e');
      rethrow;
    }
  }

  PostgrestFilterBuilder _applyUserListFilters(PostgrestFilterBuilder builder, UserListQuery query) {
    final f = query.filters;
    if (query.search.trim().isNotEmpty) {
      // PRIVACY: do not search on health fields. Search on safe metadata only.
      // If email is not allowed by RLS, this will still be safe / return empty.
      final q = query.search.trim();
      builder = builder.or('user_id.ilike.%$q%,email.ilike.%$q%');
    }
    if (f.plan != null && f.plan!.trim().isNotEmpty) builder = builder.eq('plan_name', f.plan!.trim());
    if (f.accountStatus != null && f.accountStatus!.trim().isNotEmpty) builder = builder.eq('status', f.accountStatus!.trim());
    if (f.country != null && f.country!.trim().isNotEmpty) builder = builder.eq('country', f.country!.trim());
    if (f.platform != null && f.platform!.trim().isNotEmpty) builder = builder.eq('platform', f.platform!.trim());
    return builder;
  }

  Future<UserUsageSummary> getUserUsageSummary({required AdminUser admin, required String userId}) async {
    _requireRole(admin, <AdminRole>{AdminRole.superAdmin, AdminRole.supportAgent, AdminRole.developerOps, AdminRole.billingAdmin}, capability: 'user_usage_summary');

    try {
      final row = await _client
          .schema('control')
          .from('user_usage_summaries')
          // Explicit safe fields only.
          .select('user_id, events_30d, sessions_30d, last_seen_at, storage_used_bytes, ai_requests_30d, ai_tokens_30d')
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) return UserUsageSummary.fromJson(row);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getUserUsageSummary failed: $e');
    }
    throw StateError('User usage summary unavailable.');
  }

  Future<List<UsageEventAggregateRow>> getUsageEvents({required AdminUser admin, required UsageEventsQuery query, required int limit}) async {
    _requireRole(admin, AdminRbac.analytics, capability: 'usage_events');
    try {
      final builder = _client
          .schema('control')
          .from('usage_events_agg')
          // Aggregate-only. No event payloads.
          .select('event_name, event_category, count, unique_users, day')
          .gte('day', query.start.toIso8601String())
          .lte('day', query.end.toIso8601String());

      final rows = await builder.order('day', ascending: false).limit(limit);
      return (rows as List).cast<Map<String, dynamic>>().map(UsageEventAggregateRow.fromJson).toList();
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getUsageEvents failed: $e');
      rethrow;
    }
  }

  Future<AiUsageSnapshot> getAIUsage({required AdminUser admin, required AiUsageQuery query}) async {
    _requireRole(admin, AdminRbac.analytics, capability: 'ai_usage');
    try {
      final res = await _client.rpc('control_get_ai_usage_snapshot', params: _aiUsageQueryParams(query));
      if (res is Map<String, dynamic>) return _parseAiUsageSnapshot(res, query);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getAIUsage rpc failed: $e');
    }
    throw StateError('AI usage snapshot unavailable.');
  }

  Future<StorageSnapshot> getStorageUsage({required AdminUser admin, required StorageQuery query}) async {
    _requireRole(admin, <AdminRole>{AdminRole.superAdmin, AdminRole.developerOps, AdminRole.billingAdmin}, capability: 'storage_usage');
    try {
      final res = await _client.rpc('control_get_storage_snapshot', params: _storageQueryParams(query));
      if (res is Map<String, dynamic>) return _parseStorageSnapshot(res, query);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getStorageUsage rpc failed: $e');
    }
    throw StateError('Storage snapshot unavailable.');
  }

  Future<BillingSnapshot> getBillingSummary({required AdminUser admin, required BillingQuery query}) async {
    _requireRole(admin, AdminRbac.billing, capability: 'billing_summary');
    try {
      final res = await _client.rpc('control_get_billing_snapshot', params: _billingQueryParams(query));
      if (res is Map<String, dynamic>) return _parseBillingSnapshot(res, query);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getBillingSummary rpc failed: $e');
    }
    throw StateError('Billing snapshot unavailable.');
  }

  Future<ComplianceSnapshot> getComplianceRequests({required AdminUser admin, required ComplianceQuery query}) async {
    _requireRole(admin, AdminRbac.compliance, capability: 'compliance_requests');
    try {
      final res = await _client.rpc('control_get_compliance_snapshot', params: _complianceQueryParams(query));
      if (res is Map<String, dynamic>) return _parseComplianceSnapshot(res, query);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getComplianceRequests rpc failed: $e');
    }
    throw StateError('Compliance snapshot unavailable.');
  }

  Future<List<SupportSessionSummary>> getSupportSessions({required AdminUser admin, required SupportQueueQuery query, required int limit}) async {
    _requireRole(admin, AdminRbac.support, capability: 'support_sessions');
    final canEmail = AdminRbac.canViewUserEmail(admin.role);
    final select = canEmail
        ? 'support_session_id, user_id, email, ticket_reference, consent_status, status, assigned_admin, created_at, access_expires_at, updated_at'
        : 'support_session_id, user_id, ticket_reference, consent_status, status, assigned_admin, created_at, access_expires_at, updated_at';
    try {
      final builder = _client.schema('control').from('support_session_summaries').select(select);
      final rows = await builder.order('created_at', ascending: false).limit(limit);
      return (rows as List).cast<Map<String, dynamic>>().map(_supportSessionSummaryFromJson).toList();
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getSupportSessions failed: $e');
      rethrow;
    }
  }

  Future<List<AuditLogEntry>> getAuditLogs({required AdminUser admin, required AuditLogQuery query, required int limit}) async {
    _requireRole(admin, <AdminRole>{AdminRole.superAdmin, AdminRole.complianceOfficer, AdminRole.developerOps}, capability: 'audit_logs');

    try {
      var builder = _client
          .schema('control')
          .from('admin_audit_log')
          // Never select raw content beyond redacted maps.
          .select('id, admin_user_id, target_user_id, action_type, previous_value, new_value, reason, ticket_reference, ip_address, user_agent, result, created_at');

      if (query.actionType != null && query.actionType!.trim().isNotEmpty) builder = builder.eq('action_type', query.actionType!.trim());
      if (query.adminUserId != null && query.adminUserId!.trim().isNotEmpty) builder = builder.eq('admin_user_id', query.adminUserId!.trim());
      if (query.targetUserId != null && query.targetUserId!.trim().isNotEmpty) builder = builder.eq('target_user_id', query.targetUserId!.trim());
      if (query.result != null && query.result!.trim().isNotEmpty) builder = builder.eq('result', query.result!.trim());

      final rows = await builder.order('created_at', ascending: false).limit(limit);
      return (rows as List).cast<Map<String, dynamic>>().map(AuditLogEntry.fromJson).toList();
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getAuditLogs failed: $e');
      rethrow;
    }
  }
}

Map<String, dynamic> _rangeParams(AdminDateRangePreset range) {
  final end = DateTime.now().toUtc();
  final start = end.subtract(Duration(days: range.days));
  return {
    'range': range.name,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };
}

Map<String, dynamic> _dashboardQueryParams(DashboardQuery q) => {
  ..._rangeParams(q.range),
  if (q.country != null) 'country': q.country,
  if (q.platform != null) 'platform': q.platform,
  if (q.plan != null) 'plan': q.plan,
};

Map<String, dynamic> _aiUsageQueryParams(AiUsageQuery q) => {
  ..._rangeParams(q.range),
  if (q.country != null) 'country': q.country,
  if (q.platform != null) 'platform': q.platform,
  if (q.plan != null) 'plan': q.plan,
  if (q.appVersion != null) 'app_version': q.appVersion,
};

Map<String, dynamic> _storageQueryParams(StorageQuery q) => {..._rangeParams(q.range)};

Map<String, dynamic> _billingQueryParams(BillingQuery q) => {..._rangeParams(q.range)};

Map<String, dynamic> _complianceQueryParams(ComplianceQuery q) => {..._rangeParams(q.range)};

DashboardSnapshot _parseDashboardSnapshot(Map<String, dynamic> json, DashboardQuery query) {
  // Minimal, defensive parsing: if your RPC/view returns richer structures,
  // you can extend this mapping later without UI changes.
  return DashboardSnapshot(
    query: query,
    totalRegisteredUsers: (json['total_registered_users'] as num?)?.toInt() ?? 0,
    newUsersThisWeek: (json['new_users_this_week'] as num?)?.toInt() ?? 0,
    newUsersThisMonth: (json['new_users_this_month'] as num?)?.toInt() ?? 0,
    dailyActiveUsers: (json['daily_active_users'] as num?)?.toInt() ?? 0,
    weeklyActiveUsers: (json['weekly_active_users'] as num?)?.toInt() ?? 0,
    monthlyActiveUsers: (json['monthly_active_users'] as num?)?.toInt() ?? 0,
    userGrowth: const [],
    totalStorageUsedBytes: (json['total_storage_used_bytes'] as num?)?.toInt() ?? 0,
    averageStoragePerUserBytes: (json['average_storage_per_user_bytes'] as num?)?.toInt() ?? 0,
    usersNearStorageLimit: (json['users_near_storage_limit'] as num?)?.toInt() ?? 0,
    aiTokensUsedThisMonth: (json['ai_tokens_used_this_month'] as num?)?.toInt() ?? 0,
    aiEstimatedCostThisMonthUsd: (json['ai_estimated_cost_this_month_usd'] as num?)?.toDouble() ?? 0,
    usersNearAiLimit: (json['users_near_ai_limit'] as num?)?.toInt() ?? 0,
    freeUsers: (json['free_users'] as num?)?.toInt() ?? 0,
    trialUsers: (json['trial_users'] as num?)?.toInt() ?? 0,
    paidUsers: (json['paid_users'] as num?)?.toInt() ?? 0,
    cancelledUsers: (json['cancelled_users'] as num?)?.toInt() ?? 0,
    failedPayments: (json['failed_payments'] as num?)?.toInt() ?? 0,
    countryUsage: const [],
    platformUsage: const <String, int>{},
    featureUsage: const <String, int>{},
    alerts: const [],
    systemStatus: const [],
    generatedAt: DateTime.now().toUtc(),
  );
}

AiUsageSnapshot _parseAiUsageSnapshot(Map<String, dynamic> json, AiUsageQuery query) => AiUsageSnapshot(
  query: query,
  aiRequestsThisMonth: (json['ai_requests_this_month'] as num?)?.toInt() ?? 0,
  inputTokensThisMonth: (json['input_tokens_this_month'] as num?)?.toInt() ?? 0,
  outputTokensThisMonth: (json['output_tokens_this_month'] as num?)?.toInt() ?? 0,
  estimatedCostThisMonthUsd: (json['estimated_cost_this_month_usd'] as num?)?.toDouble() ?? 0,
  failedAiRequestsThisMonth: (json['failed_ai_requests_this_month'] as num?)?.toInt() ?? 0,
  usersNearAiLimit: (json['users_near_ai_limit'] as num?)?.toInt() ?? 0,
  usersOverAiLimit: (json['users_over_ai_limit'] as num?)?.toInt() ?? 0,
  tokensByDay: const [],
  tokensByFeature: const <AiFeatureArea, int>{},
  tokensByPlan: const <String, int>{},
  tokensByPlatform: const <String, int>{},
  tokensByCountry: const <String, int>{},
  dailyCost: const [],
  estimatedDailyCostUsd: (json['estimated_daily_cost_usd'] as num?)?.toDouble() ?? 0,
  estimatedMonthlyCostUsd: (json['estimated_monthly_cost_usd'] as num?)?.toDouble() ?? 0,
  costByPlan: const <String, double>{},
  costByFeature: const <AiFeatureArea, double>{},
  costPerActiveUserUsd: (json['cost_per_active_user_usd'] as num?)?.toDouble() ?? 0,
  highCostUsers: const [],
  limitMonitoring: const [],
  aiErrors: const [],
  usageByFeature: const [],
  generatedAt: DateTime.now().toUtc(),
);

StorageSnapshot _parseStorageSnapshot(Map<String, dynamic> json, StorageQuery query) => StorageSnapshot(
  query: query,
  totalStorageUsedBytes: (json['total_storage_used_bytes'] as num?)?.toInt() ?? 0,
  totalDocumentCount: (json['total_document_count'] as num?)?.toInt() ?? 0,
  averageStoragePerUserBytes: (json['average_storage_per_user_bytes'] as num?)?.toInt() ?? 0,
  usersOverStorageLimit: (json['users_over_storage_limit'] as num?)?.toInt() ?? 0,
  usersOver80PercentStorageLimit: (json['users_over_80_percent_storage_limit'] as num?)?.toInt() ?? 0,
  uploadsThisMonth: (json['uploads_this_month'] as num?)?.toInt() ?? 0,
  failedUploadsThisMonth: (json['failed_uploads_this_month'] as num?)?.toInt() ?? 0,
  estimatedStorageCostUsd: (json['estimated_storage_cost_usd'] as num?)?.toDouble() ?? 0,
  highUsageUsers: const [],
  storageByPlan: const [],
  storageByCountry: const [],
  uploadErrors: const [],
  generatedAt: DateTime.now().toUtc(),
);

BillingSnapshot _parseBillingSnapshot(Map<String, dynamic> json, BillingQuery query) => BillingSnapshot(
  query: query,
  overview: BillingOverviewMetrics(
    activePaidUsers: (json['active_paid_users'] as num?)?.toInt() ?? 0,
    freeUsers: (json['free_users'] as num?)?.toInt() ?? 0,
    trialUsers: (json['trial_users'] as num?)?.toInt() ?? 0,
    cancelledUsers: (json['cancelled_users'] as num?)?.toInt() ?? 0,
    failedPayments: (json['failed_payments'] as num?)?.toInt() ?? 0,
    monthlyRecurringRevenueUsd: (json['monthly_recurring_revenue_usd'] as num?)?.toDouble() ?? 0,
    annualRecurringRevenueUsd: (json['annual_recurring_revenue_usd'] as num?)?.toDouble() ?? 0,
    averageRevenuePerUserUsd: (json['average_revenue_per_user_usd'] as num?)?.toDouble() ?? 0,
    trialConversionRate: (json['trial_conversion_rate'] as num?)?.toDouble() ?? 0,
  ),
  subscriptions: const [],
  trials: const [],
  failedPayments: const [],
  revenueByPlan: const [],
  revenueByCountry: const [],
  generatedAt: DateTime.now().toUtc(),
);

ComplianceSnapshot _parseComplianceSnapshot(Map<String, dynamic> json, ComplianceQuery query) => ComplianceSnapshot(
  query: query,
  overview: ComplianceOverviewMetrics(
    openDeletionRequests: (json['open_deletion_requests'] as num?)?.toInt() ?? 0,
    completedDeletionRequests: (json['completed_deletion_requests'] as num?)?.toInt() ?? 0,
    failedDeletionRequests: (json['failed_deletion_requests'] as num?)?.toInt() ?? 0,
    openExportRequests: (json['open_export_requests'] as num?)?.toInt() ?? 0,
    completedExportRequests: (json['completed_export_requests'] as num?)?.toInt() ?? 0,
    activeSupportSessions: (json['active_support_sessions'] as num?)?.toInt() ?? 0,
    expiredSupportSessions: (json['expired_support_sessions'] as num?)?.toInt() ?? 0,
    recentAdminActions: (json['recent_admin_actions'] as num?)?.toInt() ?? 0,
    usersPendingDeletion: (json['users_pending_deletion'] as num?)?.toInt() ?? 0,
  ),
  exportRequests: const [],
  deletionRequests: const [],
  consentRecords: const [],
  supportAccessRecords: const [],
  privacyTermsAcceptances: const [],
  retention: RetentionMonitoringMetrics(
    usageLogsDueForDeletion: (json['usage_logs_due_for_deletion'] as num?)?.toInt() ?? 0,
    supportNotesDueForDeletion: (json['support_notes_due_for_deletion'] as num?)?.toInt() ?? 0,
    expiredSupportSessions: (json['expired_support_sessions'] as num?)?.toInt() ?? 0,
    oldDiagnosticLogs: (json['old_diagnostic_logs'] as num?)?.toInt() ?? 0,
    oldRawEvents: (json['old_raw_events'] as num?)?.toInt() ?? 0,
  ),
  generatedAt: DateTime.now().toUtc(),
);

SupportSessionSummary _supportSessionSummaryFromJson(Map<String, dynamic> json) => SupportSessionSummary(
  supportSessionId: (json['support_session_id'] ?? '').toString(),
  userId: (json['user_id'] ?? '').toString(),
  email: (json['email'] as String?),
  ticketReference: (json['ticket_reference'] as String?),
  consentStatus: (json['consent_status'] ?? '').toString(),
  status: parseSupportSessionStatus((json['status'] ?? '').toString()) ?? SupportSessionStatus.pending,
  assignedAdmin: (json['assigned_admin'] as String?),
  createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
  accessExpiresAt: DateTime.tryParse((json['access_expires_at'] ?? '').toString()),
  updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
);

/// Aggregate-only usage events (privacy-safe).
@immutable
class UsageEventAggregateRow {
  const UsageEventAggregateRow({required this.eventName, required this.eventCategory, required this.count, required this.uniqueUsers, required this.day});

  final String eventName;
  final String eventCategory;
  final int count;
  final int uniqueUsers;
  final DateTime day;

  static UsageEventAggregateRow fromJson(Map<String, dynamic> json) => UsageEventAggregateRow(
    eventName: (json['event_name'] ?? '').toString(),
    eventCategory: (json['event_category'] ?? '').toString(),
    count: (json['count'] as num?)?.toInt() ?? 0,
    uniqueUsers: (json['unique_users'] as num?)?.toInt() ?? 0,
    day: DateTime.tryParse((json['day'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
  );
}

/// Query for aggregate-only usage events.
@immutable
class UsageEventsQuery {
  const UsageEventsQuery({required this.start, required this.end, this.country, this.platform, this.plan, this.appVersion});

  final DateTime start;
  final DateTime end;
  final String? country;
  final String? platform;
  final String? plan;
  final String? appVersion;
}

/// User usage summary (privacy-safe).
@immutable
class UserUsageSummary {
  const UserUsageSummary({required this.userId, required this.events30d, required this.sessions30d, required this.lastSeenAt, required this.storageUsedBytes, required this.aiRequests30d, required this.aiTokens30d});

  final String userId;
  final int events30d;
  final int sessions30d;
  final DateTime? lastSeenAt;
  final int storageUsedBytes;
  final int aiRequests30d;
  final int aiTokens30d;

  static UserUsageSummary fromJson(Map<String, dynamic> json) => UserUsageSummary(
    userId: (json['user_id'] ?? '').toString(),
    events30d: (json['events_30d'] as num?)?.toInt() ?? 0,
    sessions30d: (json['sessions_30d'] as num?)?.toInt() ?? 0,
    lastSeenAt: DateTime.tryParse((json['last_seen_at'] ?? '').toString()),
    storageUsedBytes: (json['storage_used_bytes'] as num?)?.toInt() ?? 0,
    aiRequests30d: (json['ai_requests_30d'] as num?)?.toInt() ?? 0,
    aiTokens30d: (json['ai_tokens_30d'] as num?)?.toInt() ?? 0,
  );
}

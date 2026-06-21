import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_client.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper to return a value plus which RPC/view provided it.
@immutable
class AdminQueryResult<T> {
  const AdminQueryResult({required this.name, required this.value});
  final String name;
  final T value;
}

/// Typed, privacy-safe Supabase queries for the CuraVault Control Site.
///
/// IMPORTANT:
/// - These functions must never query raw medical content fields.
/// - Prefer summary tables/views or RPCs that return aggregate-only data.
/// - RBAC is enforced client-side (best-effort) AND must be enforced by RLS.
class SupabaseAdminQueries {
  static const String rpcDashboardMetrics = 'admin_get_dashboard_metrics';
  static const String rpcUserUsageSummary = 'admin_get_user_usage_summary';
  static const String rpcUsageEventsSummary = 'admin_get_usage_events_summary';
  static const String rpcBillingSummary = 'admin_get_billing_summary';
  static const String rpcCountryUsageSummary = 'admin_get_country_usage_summary';
  static const String rpcStorageSummaryV2 = 'admin_get_storage_summary_v2';
  static const String rpcStorageSummaryV1 = 'admin_get_storage_summary';
  static const String rpcAiUsageSummary = 'admin_get_ai_usage_summary';
  static const String rpcSupportSummary = 'admin_get_support_summary';
  static const String rpcAuditSummary = 'admin_get_audit_summary';
  static const String rpcSystemHealthSummary = 'admin_get_system_health_summary';
  static const String rpcSystemHealthSummaryV2 = 'admin_get_system_health_summary_v2';
  static const String rpcComplianceSummary = 'admin_get_compliance_summary';
  static const String rpcPlanPermissionSummary = 'admin_get_plan_permission_summary';

  AiFeatureArea? _parseAiFeatureArea(String raw) {
    final v = raw.trim().toLowerCase();
    return switch (v) {
      'ai_assistant' || 'assistant' || 'aiassistant' => AiFeatureArea.aiAssistant,
      'document_summary' || 'documentsummary' || 'doc_summary' => AiFeatureArea.documentSummary,
      'timeline_summary' || 'timelinesummary' => AiFeatureArea.timelineSummary,
      'search_helper' || 'searchhelper' || 'search' => AiFeatureArea.searchHelper,
      'appointment_helper' || 'appointmenthelper' || 'appointments' => AiFeatureArea.appointmentHelper,
      'health_organisation_helper' || 'healthorganizationhelper' || 'health_organization_helper' || 'organisation_helper' || 'organization_helper' => AiFeatureArea.healthOrganisationHelper,
      'export_helper' || 'exporthelper' || 'export' => AiFeatureArea.exportHelper,
      _ => null,
    };
  }

  SupabaseClient get _client {
    final c = ControlSupabaseClient.tryGet();
    if (c == null) throw StateError('Supabase not initialized/configured.');
    return c;
  }

  Future<AdminUser> getCurrentAdminUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('Not signed in.');

    // Bootstrapped schema is `public.admin_users` with:
    // - admin_user_id (Supabase Auth user id)
    // - role (enum type: admin_role)
    // - is_active
    final row = await _client
        .from('admin_users')
        // Only admin metadata (no health data).
        // IMPORTANT: column is named `role` (type `admin_role`).
        .select('admin_user_id, email, display_name, role, is_active, require_step_up, created_at, updated_at, theme_preference, theme_mode')
        .eq('admin_user_id', authUser.id)
        // Enforce allow-list rule at the query level.
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) throw StateError('Not an active admin user (no matching admin_users row).');
    // Row already filtered by is_active=true, but keep defensive checks.
    final isActive = row['is_active'] == true;
    if (!isActive) throw StateError('Admin is not active.');

    final role = parseAdminRole((row['role'] as String?) ?? '');
    if (role == null) throw StateError('Unknown admin role.');

    // Normalize to AdminUser model.
    return AdminUser(
      id: (row['admin_user_id'] ?? authUser.id).toString(),
      email: (row['email'] as String?) ?? (authUser.email ?? ''),
      displayName: (row['display_name'] as String?)?.trim().isEmpty == true ? null : (row['display_name'] as String?),
      role: role,
      isActive: isActive,
      requireStepUp: row['require_step_up'] == true,
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

    Future<void> attempt(String column) async => _client
        .from('admin_users')
        .update({column: themePreference, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('admin_user_id', authUser.id);

    // Best-effort only. Many deployments don't include a theme column.
    // Never let this block the UI.
    try {
      await attempt('theme_preference');
      return;
    } catch (e) {
      debugPrint('setAdminThemePreference(theme_preference) failed: $e');
    }
    try {
      await attempt('theme_mode');
      return;
    } catch (e) {
      debugPrint('setAdminThemePreference(theme_mode) failed: $e');
    }
  }

  void _requireRole(AdminUser admin, Set<AdminRole> allowed, {required String capability}) {
    if (!allowed.contains(admin.role)) {
      throw StateError('Access denied ($capability): role ${admin.role.name}');
    }
  }

  Future<DashboardSnapshot> getDashboardMetrics({required AdminUser admin, required DashboardQuery query}) async {
    _requireRole(admin, AdminRbac.all, capability: 'dashboard');

    // Preferred: admin-safe reporting RPC (aggregate-only).
    try {
      final res = await _client.rpc(rpcDashboardMetrics);
      if (res is List && res.isEmpty) {
        final featureUsage = <String, int>{
          'User profiles': 0,
          'Family members': 0,
          'Medical records': 0,
          'Appointments': 0,
          'Medications': 0,
          'Vaccinations': 0,
          'Blood pressure entries': 0,
          'Documents': 0,
          'Insurance cards': 0,
          'Usage events': 0,
          'Audit events': 0,
          'Support sessions': 0,
          'Compliance requests': 0,
        };
        return _parseDashboardSnapshot(
          {
            'total_registered_users': 0,
            'feature_usage': featureUsage,
            'generated_at': DateTime.now().toUtc().toIso8601String(),
          },
          query,
        );
      }

      // IMPORTANT: admin_get_dashboard_metrics() returns a TABLE, so Supabase
      // returns a List<Map<String,dynamic>> (even if it's a single row).
      final Map<String, dynamic>? row = switch (res) {
        final Map m => m.cast<String, dynamic>(),
        final List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, dynamic>(),
        _ => null,
      };

      if (row != null) {
        num? readNum(List<String> keys) {
          for (final k in keys) {
            final v = row[k];
            if (v is num) return v;
            if (v != null) {
              final parsed = num.tryParse(v.toString());
              if (parsed != null) return parsed;
            }
          }
          return null;
        }

        // Adapt RPC output into the existing DashboardSnapshot shape.
        // Field names MUST match the migration return names exactly.
        final featureUsage = <String, int>{
          'User profiles': (readNum(['total_user_profiles', 'total_profiles'])?.toInt()) ?? 0,
          'Family members': (readNum(['total_family_members'])?.toInt()) ?? 0,
          'Medical records': (readNum(['total_medical_records', 'total_medical_records_count'])?.toInt()) ?? 0,
          'Appointments': (readNum(['total_appointments', 'total_appointments_count'])?.toInt()) ?? 0,
          'Medications': (readNum(['total_medications', 'total_medications_count'])?.toInt()) ?? 0,
          'Vaccinations': (readNum(['total_vaccinations', 'total_vaccinations_count'])?.toInt()) ?? 0,
          'Blood pressure entries': (readNum(['total_blood_pressure_entries', 'total_blood_pressure_entries_count'])?.toInt()) ?? 0,
          'Documents': (readNum(['total_medical_documents', 'total_medical_documents_count'])?.toInt()) ?? 0,
          'Insurance cards': (readNum(['total_insurance_cards'])?.toInt()) ?? 0,
          'Usage events': (readNum(['total_usage_events', 'total_usage_events_count'])?.toInt()) ?? 0,
          'Audit events': (readNum(['total_audit_events', 'total_audit_events_count'])?.toInt()) ?? 0,
          'Support sessions': (readNum(['total_support_sessions', 'total_support_sessions_count'])?.toInt()) ?? 0,
          'Compliance requests': (readNum(['total_compliance_requests', 'total_compliance_requests_count'])?.toInt()) ?? 0,
        };

        final adapted = <String, dynamic>{
          'total_registered_users': readNum(['total_auth_users', 'total_registered_users']) ?? row['total_auth_users'],
          'feature_usage': featureUsage,
          'generated_at': DateTime.now().toUtc().toIso8601String(),
        };
        return _parseDashboardSnapshot(adapted, query);
      }
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getDashboardMetrics admin_get_dashboard_metrics failed: $e');
    }

    // Legacy: older control_* RPC/view (optional; may not exist).
    try {
      final res = await _client.rpc('control_get_dashboard_metrics', params: _dashboardQueryParams(query));
      if (res is Map<String, dynamic>) return _parseDashboardSnapshot(res, query);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getDashboardMetrics legacy rpc failed: $e');
    }

    throw StateError('Dashboard metrics unavailable (no admin-safe RPC deployed).');
  }

  Future<List<UserAccountSummary>> getUsersList({required AdminUser admin, required UserListQuery query, required int limit}) async {
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.support}, capability: 'users_list');

    // Preferred: admin-safe reporting RPC.
    try {
      final canEmail = AdminRbac.canViewUserEmail(admin.role);
      final res = await _client.rpc(rpcUserUsageSummary);
      if (res is List) {
        final rows = res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();

        List<Map<String, dynamic>> filtered = rows;
        final q = query.search.trim();
        if (q.isNotEmpty) {
          filtered = rows.where((r) {
            final id = (r['user_id'] ?? '').toString();
            final email = (r['email'] ?? '').toString();
            if (id.toLowerCase().contains(q.toLowerCase())) return true;
            if (canEmail && email.toLowerCase().contains(q.toLowerCase())) return true;
            return false;
          }).toList();
        }

        return filtered.take(limit).map((r) {
          return UserAccountSummary(
            userId: (r['user_id'] ?? '').toString(),
            email: canEmail ? (r['email'] as String?) : null,
            country: '—',
            plan: '—',
            accountStatus: 'unknown',
            storageUsedBytes: 0,
            storageLimitBytes: 0,
            aiTokensThisMonth: 0,
            aiTokenLimitThisMonth: 0,
            profileCount: (r['profile_count'] as num?)?.toInt() ?? 0,
            recordCount: (r['medical_record_count'] as num?)?.toInt() ?? 0,
            documentCount: (r['medical_document_count'] as num?)?.toInt() ?? 0,
            appointmentCount: (r['appointment_count'] as num?)?.toInt() ?? 0,
            medicationCount: (r['medication_count'] as num?)?.toInt() ?? 0,
            vaccinationCount: (r['vaccination_count'] as num?)?.toInt() ?? 0,
            lastSyncAt: null,
            lastActiveAt: DateTime.tryParse((r['last_sign_in_at'] ?? '').toString()),
            platform: '—',
            appVersion: '—',
            failedSyncCount7d: 0,
            failedUploadCount7d: 0,
            lastKnownErrorCode: null,
            billingStatus: '—',
            subscriptionProvider: '—',
            createdAt: DateTime.tryParse((r['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
            updatedAt: DateTime.now().toUtc(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getUsersList admin_get_user_usage_summary failed: $e');
    }

    // Legacy: safe summary views (optional / may not be deployed).
    final canEmail = AdminRbac.canViewUserEmail(admin.role);
    final select = canEmail
        ? 'user_id, email, plan_name, status, created_at, last_active_at, country, platform, app_version, storage_used_bytes, storage_limit_bytes, ai_tokens_monthly, ai_tokens_limit_monthly'
        : 'user_id, plan_name, status, created_at, last_active_at, country, platform, app_version, storage_used_bytes, storage_limit_bytes, ai_tokens_monthly, ai_tokens_limit_monthly';

    final builder = _client.schema('control').from('user_account_summaries').select(select);
    final filtered = _applyUserListFilters(builder, query);
    final rows = await filtered.order('last_active_at', ascending: false).limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(UserAccountSummary.fromJson).toList();
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
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.support, AdminRole.admin, AdminRole.billing}, capability: 'user_usage_summary');

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
      final res = await _client.rpc('admin_get_ai_usage_summary');
      final Map<String, dynamic>? row = switch (res) {
        final Map m => m.cast<String, dynamic>(),
        final List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, dynamic>(),
        _ => null,
      };

      // Empty result = no data collected yet.
      if (row == null) {
        return AiUsageSnapshot(
          query: query,
          aiRequestsThisMonth: 0,
          inputTokensThisMonth: 0,
          outputTokensThisMonth: 0,
          estimatedCostThisMonthUsd: 0,
          failedAiRequestsThisMonth: 0,
          usersNearAiLimit: 0,
          usersOverAiLimit: 0,
          tokensByDay: const [],
          tokensByFeature: const <AiFeatureArea, int>{},
          tokensByPlan: const <String, int>{},
          tokensByPlatform: const <String, int>{},
          tokensByCountry: const <String, int>{},
          dailyCost: const [],
          estimatedDailyCostUsd: 0,
          estimatedMonthlyCostUsd: 0,
          costByPlan: const <String, double>{},
          costByFeature: const <AiFeatureArea, double>{},
          costPerActiveUserUsd: 0,
          highCostUsers: const [],
          limitMonitoring: const [],
          aiErrors: const [],
          usageByFeature: const [],
          generatedAt: DateTime.now().toUtc(),
        );
      }

      // New RPC (ai_usage_events-based) returns: total_request_count, tokens, cost,
      // plus JSON aggregates. Older environments may still return legacy keys.
      final totalRequests = (row['total_request_count'] as num?)?.toInt() ?? (row['ai_request_count'] as num?)?.toInt() ?? 0;
      final inputTokens = (row['input_tokens'] as num?)?.toInt() ?? 0;
      final outputTokens = (row['output_tokens'] as num?)?.toInt() ?? 0;
      final estimatedCost = (row['estimated_cost'] as num?)?.toDouble() ?? 0;

      int failedRequests = (row['failed_ai_requests'] as num?)?.toInt() ?? 0;
      if (failedRequests == 0 && row['failures_by_error_code'] != null) {
        try {
          final failures = row['failures_by_error_code'];
          if (failures is List) {
            failedRequests = failures.fold<int>(0, (sum, e) => sum + ((e is Map ? (e['failure_count'] as num?)?.toInt() : null) ?? 0));
          }
        } catch (e) {
          debugPrint('SupabaseAdminQueries.getAIUsage failed to parse failures_by_error_code: $e');
        }
      }

      List<AiFeatureUsageRow> usageByFeature = const [];
      if (row['usage_by_feature_area'] is List) {
        try {
          final list = (row['usage_by_feature_area'] as List).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          usageByFeature = list
              .map((m) {
                final feature = _parseAiFeatureArea((m['feature_area'] as String?) ?? '') ?? AiFeatureArea.aiAssistant;
                return AiFeatureUsageRow(
                  featureArea: feature,
                  requests: (m['request_count'] as num?)?.toInt() ?? 0,
                  inputTokens: (m['input_tokens'] as num?)?.toInt() ?? 0,
                  outputTokens: (m['output_tokens'] as num?)?.toInt() ?? 0,
                  failedRequests: (m['failed_request_count'] as num?)?.toInt() ?? 0,
                  estimatedCostUsd: (m['estimated_cost'] as num?)?.toDouble() ?? 0,
                );
              })
              .toList();
        } catch (e) {
          debugPrint('SupabaseAdminQueries.getAIUsage failed to parse usage_by_feature_area: $e');
        }
      }

      return AiUsageSnapshot(
        query: query,
        aiRequestsThisMonth: totalRequests,
        inputTokensThisMonth: inputTokens,
        outputTokensThisMonth: outputTokens,
        estimatedCostThisMonthUsd: estimatedCost,
        failedAiRequestsThisMonth: failedRequests,
        // The new aggregate RPC intentionally does not expose per-user limit monitoring.
        usersNearAiLimit: (row['users_near_ai_limit'] as num?)?.toInt() ?? 0,
        usersOverAiLimit: (row['users_over_ai_limit'] as num?)?.toInt() ?? 0,
        tokensByDay: const [],
        tokensByFeature: const <AiFeatureArea, int>{},
        tokensByPlan: const <String, int>{},
        tokensByPlatform: const <String, int>{},
        tokensByCountry: const <String, int>{},
        dailyCost: const [],
        estimatedDailyCostUsd: 0,
        estimatedMonthlyCostUsd: 0,
        costByPlan: const <String, double>{},
        costByFeature: const <AiFeatureArea, double>{},
        costPerActiveUserUsd: 0,
        highCostUsers: const [],
        limitMonitoring: const [],
        aiErrors: const [],
        usageByFeature: usageByFeature,
        generatedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getAIUsage admin_get_ai_usage_summary failed: $e');
      rethrow;
    }
  }

  Future<AdminQueryResult<StorageSnapshot>> getStorageUsage({required AdminUser admin, required StorageQuery query}) async {
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.admin, AdminRole.billing}, capability: 'storage_usage');

    try {
      dynamic res;
      String rpcName = rpcStorageSummaryV2;
      try {
        // Prefer v2 (privacy-safe storage metadata table + better failure counting).
        res = await _client.rpc(rpcStorageSummaryV2);
      } catch (e) {
        debugPrint('SupabaseAdminQueries.getStorageUsage admin_get_storage_summary_v2 not available: $e');
        rpcName = rpcStorageSummaryV1;
        res = await _client.rpc(rpcStorageSummaryV1);
      }
      final Map<String, dynamic>? row = switch (res) {
        final Map m => m.cast<String, dynamic>(),
        final List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, dynamic>(),
        _ => null,
      };

      if (row == null) {
        return AdminQueryResult(
          name: rpcName,
          value: StorageSnapshot(
          query: query,
          totalStorageUsedBytes: 0,
          totalDocumentCount: 0,
          averageStoragePerUserBytes: 0,
          usersOverStorageLimit: 0,
          usersOver80PercentStorageLimit: 0,
          uploadsThisMonth: 0,
          failedUploadsThisMonth: 0,
          estimatedStorageCostUsd: 0,
          highUsageUsers: const [],
          storageByPlan: const [],
          storageByCountry: const [],
          uploadErrors: const [],
          generatedAt: DateTime.now().toUtc(),
          ),
        );
      }

      final totalStorageMb = (row['total_storage_used_mb'] as num?)?.toInt() ?? 0;
      final avgMb = (row['average_storage_per_user_mb'] as num?)?.toInt() ?? 0;

      // v2 adds better upload failure counters; keep old field names supported.
      final failedUploads24h = (row['failed_upload_events_24h'] as num?)?.toInt() ?? 0;
      final failedUploadsTotal = (row['failed_upload_count'] as num?)?.toInt();

      return AdminQueryResult(
        name: rpcName,
        value: StorageSnapshot(
        query: query,
        totalStorageUsedBytes: totalStorageMb * 1048576,
        totalDocumentCount: (row['total_document_count'] as num?)?.toInt() ?? 0,
        averageStoragePerUserBytes: avgMb * 1048576,
        usersOverStorageLimit: (row['users_over_storage_limit'] as num?)?.toInt() ?? 0,
        usersOver80PercentStorageLimit: (row['users_near_storage_limit'] as num?)?.toInt() ?? 0,
        uploadsThisMonth: 0,
        // We don't currently have a true month window in the RPC. Prefer v2 total
        // if present; otherwise use the legacy 24h counter.
        failedUploadsThisMonth: failedUploadsTotal ?? failedUploads24h,
        estimatedStorageCostUsd: 0,
        highUsageUsers: const [],
        storageByPlan: const [],
        storageByCountry: const [],
        uploadErrors: const [],
        generatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getStorageUsage admin_get_storage_summary failed: $e');
      rethrow;
    }
  }

  Future<BillingSnapshot> getBillingSummary({required AdminUser admin, required BillingQuery query}) async {
    _requireRole(admin, AdminRbac.billing, capability: 'billing_summary');

    // Preferred: admin-safe billing summary RPC.
    try {
      final res = await _client.rpc('admin_get_billing_summary');
      if (res is List) {
        final rows = res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        // Empty list is not a failure: it simply means no billing-related rows
        // have been collected yet.
        if (rows.isEmpty) {
          return BillingSnapshot(
            query: query,
            overview: const BillingOverviewMetrics(
              activePaidUsers: 0,
              freeUsers: 0,
              trialUsers: 0,
              cancelledUsers: 0,
              failedPayments: 0,
              monthlyRecurringRevenueUsd: 0,
              annualRecurringRevenueUsd: 0,
              averageRevenuePerUserUsd: 0,
              trialConversionRate: 0,
            ),
            subscriptions: const [],
            trials: const [],
            failedPayments: const [],
            revenueByPlan: const [],
            revenueByCountry: const [],
            generatedAt: DateTime.now().toUtc(),
          );
        }

        int sumUserCount(bool Function(Map<String, dynamic> r) pred) => rows.where(pred).fold<int>(0, (a, r) => a + ((r['user_count'] as num?)?.toInt() ?? 0));

        final activePaidUsers = sumUserCount((r) {
          final plan = (r['plan'] ?? '').toString().toLowerCase();
          final status = (r['billing_status'] ?? '').toString().toLowerCase();
          return status == 'active' && plan != 'free';
        });
        final freeUsers = sumUserCount((r) => (r['plan'] ?? '').toString().toLowerCase() == 'free');
        final trialUsers = sumUserCount((r) => (r['billing_status'] ?? '').toString().toLowerCase() == 'trialing');
        final cancelledUsers = sumUserCount((r) {
          final s = (r['billing_status'] ?? '').toString().toLowerCase();
          return s == 'canceled' || s == 'cancelled';
        });
        final failedPayments = sumUserCount((r) {
          final s = (r['billing_status'] ?? '').toString().toLowerCase();
          return s == 'past_due' || s == 'retrying';
        });

        return BillingSnapshot(
          query: query,
          overview: BillingOverviewMetrics(
            activePaidUsers: activePaidUsers,
            freeUsers: freeUsers,
            trialUsers: trialUsers,
            cancelledUsers: cancelledUsers,
            failedPayments: failedPayments,
            monthlyRecurringRevenueUsd: 0,
            annualRecurringRevenueUsd: 0,
            averageRevenuePerUserUsd: 0,
            trialConversionRate: 0,
          ),
          subscriptions: const [],
          trials: const [],
          failedPayments: const [],
          revenueByPlan: const [],
          revenueByCountry: const [],
          generatedAt: DateTime.now().toUtc(),
        );
      }
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getBillingSummary admin_get_billing_summary failed: $e');
    }

    // Legacy snapshot RPC (optional).
    try {
      final res = await _client.rpc('control_get_billing_snapshot', params: _billingQueryParams(query));
      if (res is Map<String, dynamic>) return _parseBillingSnapshot(res, query);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getBillingSummary legacy rpc failed: $e');
    }
    throw StateError('Billing summary unavailable (no admin-safe RPC deployed).');
  }

  Future<UsageAnalyticsSnapshot> getUsageAnalyticsSummary({required AdminUser admin, required UsageAnalyticsQuery query}) async {
    _requireRole(admin, AdminRbac.analytics, capability: 'usage_events_summary');

    final res = await _client.rpc(rpcUsageEventsSummary);
    if (res is! List) throw StateError('Unexpected usage summary RPC response.');
    final rows = res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();

    // Empty list is not an error; it simply means no usage events collected yet.
    if (rows.isEmpty) {
      return UsageAnalyticsSnapshot(
        query: query,
        totalEvents: 0,
        activeUsers: 0,
        sessions: 0,
        avgSessionDurationSeconds: 0,
        featureUsageByCategory: const {},
        conversions: const UsageOverviewConversions(signupToFirstProfile: 0, firstProfileToFirstUpload: 0, firstUploadToRecurring: 0, upgradePromptViews: 0, upgradeClicks: 0),
        featureUsage: const [],
        screenUsage: const [],
        funnels: const [],
        retention: const UsageRetentionSnapshot(day1: 0, day7: 0, day30: 0, weeklyRetention: 0),
        countryUsage: const [],
        platformUsage: const {},
        generatedAt: DateTime.now().toUtc(),
      );
    }

    int eventCountOf(Map<String, dynamic> r) => (r['event_count'] as num?)?.toInt() ?? (r['count'] as num?)?.toInt() ?? 0;
    int uniqueUsersOf(Map<String, dynamic> r) => (r['unique_user_count'] as num?)?.toInt() ?? (r['unique_users'] as num?)?.toInt() ?? 0;

    final totalEvents = rows.fold<int>(0, (a, r) => a + eventCountOf(r));

    final featureUsage = <UsageFeatureUsageRow>[];
    for (final r in rows.take(50)) {
      final name = (r['event_name'] ?? 'unknown').toString();
      final featureArea = (r['feature_area'] ?? '').toString().trim();
      final label = featureArea.isEmpty ? name : '$featureArea • $name';
      featureUsage.add(UsageFeatureUsageRow(feature: label, eventCount: eventCountOf(r), uniqueUsers: uniqueUsersOf(r)));
    }

    final platformUsage = <String, int>{};
    for (final r in rows) {
      final c = eventCountOf(r);
      final platform = (r['platform'] ?? '').toString().trim();
      if (platform.isNotEmpty) platformUsage[platform] = (platformUsage[platform] ?? 0) + c;
    }

    // Preferred: country usage summary RPC.
    final countryUsage = await _getCountryUsageSummary(admin: admin);

    return UsageAnalyticsSnapshot(
      query: query,
      totalEvents: totalEvents,
      activeUsers: 0,
      sessions: 0,
      avgSessionDurationSeconds: 0,
      featureUsageByCategory: const {},
      conversions: const UsageOverviewConversions(signupToFirstProfile: 0, firstProfileToFirstUpload: 0, firstUploadToRecurring: 0, upgradePromptViews: 0, upgradeClicks: 0),
      featureUsage: featureUsage,
      screenUsage: const [],
      funnels: const [],
      retention: const UsageRetentionSnapshot(day1: 0, day7: 0, day30: 0, weeklyRetention: 0),
      countryUsage: countryUsage,
      platformUsage: platformUsage,
      generatedAt: DateTime.now().toUtc(),
    );
  }

  Future<List<CountryUsageRow>> _getCountryUsageSummary({required AdminUser admin}) async {
    _requireRole(admin, AdminRbac.analytics, capability: 'country_usage_summary');
    try {
      final res = await _client.rpc('admin_get_country_usage_summary');
      if (res is! List) return const [];
      final rows = res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
      return rows
          .map(
            (r) => CountryUsageRow(
              country: (r['country'] ?? '—').toString(),
              totalUsers: (r['user_count'] as num?)?.toInt() ?? 0,
              activeUsers: (r['active_user_count'] as num?)?.toInt() ?? 0,
              storageUsedBytes: ((r['storage_used_mb'] as num?)?.toInt() ?? 0) * 1048576,
              aiTokensUsed: (r['ai_tokens_used'] as num?)?.toInt() ?? 0,
              paidUsers: 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.totalUsers.compareTo(a.totalUsers));
    } catch (e) {
      debugPrint('SupabaseAdminQueries._getCountryUsageSummary admin_get_country_usage_summary failed: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getPlanPermissionSummaryRows({required AdminUser admin}) async {
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.admin, AdminRole.billing}, capability: 'plan_permission_summary');
    final res = await _client.rpc('admin_get_plan_permission_summary');
    if (res is! List) return const [];
    return res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>?> getSupportSummaryRow({required AdminUser admin}) async {
    _requireRole(admin, AdminRbac.support, capability: 'support_summary');
    final res = await _client.rpc('admin_get_support_summary');
    return switch (res) {
      final Map m => m.cast<String, dynamic>(),
      final List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, dynamic>(),
      _ => null,
    };
  }

  Future<Map<String, dynamic>?> getAuditSummaryRow({required AdminUser admin}) async {
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.compliance}, capability: 'audit_summary');
    final res = await _client.rpc('admin_get_audit_summary');
    return switch (res) {
      final Map m => m.cast<String, dynamic>(),
      final List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, dynamic>(),
      _ => null,
    };
  }

  Future<AdminQueryResult<Map<String, dynamic>?>> getSystemHealthSummaryRow({required AdminUser admin}) async {
    _requireRole(admin, AdminRbac.analytics, capability: 'system_health_summary');
    try {
      final res = await _client.rpc(rpcSystemHealthSummary);
      final row = switch (res) {
        final Map m => m.cast<String, dynamic>(),
        final List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, dynamic>(),
        _ => null,
      };
      return AdminQueryResult(name: rpcSystemHealthSummary, value: row);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getSystemHealthSummaryRow admin_get_system_health_summary failed: $e');
      // Try v2 if deployed.
      final res = await _client.rpc(rpcSystemHealthSummaryV2);
      final row = switch (res) {
        final Map m => m.cast<String, dynamic>(),
        final List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, dynamic>(),
        _ => null,
      };
      return AdminQueryResult(name: rpcSystemHealthSummaryV2, value: row);
    }
  }

  Future<ComplianceSnapshot> getComplianceRequests({required AdminUser admin, required ComplianceQuery query}) async {
    _requireRole(admin, AdminRbac.compliance, capability: 'compliance_requests');

    try {
      final res = await _client.rpc('admin_get_compliance_summary');
      final Map<String, dynamic>? row = switch (res) {
        final Map m => m.cast<String, dynamic>(),
        final List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, dynamic>(),
        _ => null,
      };

      // If the compliance requests table isn't deployed, this RPC still returns a
      // row of zeros (by design). Treat that as “no data collected yet”, not an error.
      final total = (row?['total_requests'] as num?)?.toInt() ?? 0;
      final open = (row?['open_requests'] as num?)?.toInt() ?? 0;
      final inProgress = (row?['in_progress_requests'] as num?)?.toInt() ?? 0;
      final completed = (row?['completed_requests'] as num?)?.toInt() ?? 0;
      final failed = (row?['failed_requests'] as num?)?.toInt() ?? 0;
      final deletion = (row?['deletion_requests'] as num?)?.toInt() ?? 0;
      final export = (row?['export_requests'] as num?)?.toInt() ?? 0;

      // The current Control Site UI has many “detail” tabs; those are intentionally
      // left empty until dedicated admin-safe list RPCs are added.
      return ComplianceSnapshot(
        query: query,
        overview: ComplianceOverviewMetrics(
          openDeletionRequests: deletion,
          completedDeletionRequests: 0,
          failedDeletionRequests: 0,
          openExportRequests: export,
          completedExportRequests: 0,
          activeSupportSessions: 0,
          expiredSupportSessions: 0,
          recentAdminActions: 0,
          usersPendingDeletion: open,
        ),
        exportRequests: const [],
        deletionRequests: const [],
        consentRecords: const [],
        supportAccessRecords: const [],
        privacyTermsAcceptances: const [],
        retention: const RetentionMonitoringMetrics(
          usageLogsDueForDeletion: 0,
          supportNotesDueForDeletion: 0,
          expiredSupportSessions: 0,
          oldDiagnosticLogs: 0,
          oldRawEvents: 0,
        ),
        generatedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getComplianceRequests admin_get_compliance_summary failed: $e');
      rethrow;
    }
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
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.compliance}, capability: 'audit_logs');

    try {
      var builder = _client
          .from('admin_audit_log')
          // Never select raw content beyond redacted maps.
          .select('id, admin_user_id, target_user_id, action_type, prev, next, reason, ticket_id, ip, user_agent, result, created_at');

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
  // Defensive parsing for aggregate-only structures.
  //
  // This accepts multiple possible server shapes so the dashboard can be wired
  // incrementally:
  // - user_growth: [{date/day, value}] or {"2026-06-01": 123}
  // - country_usage: [{country, total_users, active_users, storage_used_bytes, ai_tokens_used, paid_users}]
  // - platform_usage: {"iOS": 12, "Android": 34} or [{platform, count}]
  // - feature_usage: {"upload": 12} or [{feature, count}]
  // - alerts: [{type, count, severity, note}]
  // - system_status: [{label, status, detail, updated_at}]

  DateTime parseDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
  }

  int parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double parseDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  List<DashboardTimeseriesPoint> parseTimeseries(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      final out = <DashboardTimeseriesPoint>[];
      for (final raw in v) {
        if (raw is Map) {
          final m = raw.cast<String, dynamic>();
          final d = m['date'] ?? m['day'] ?? m['t'] ?? m['x'];
          final value = m['value'] ?? m['count'] ?? m['y'];
          out.add(DashboardTimeseriesPoint(date: parseDate(d), value: parseInt(value)));
        }
      }
      out.sort((a, b) => a.date.compareTo(b.date));
      return out;
    }
    if (v is Map) {
      final out = <DashboardTimeseriesPoint>[];
      for (final e in v.entries) {
        out.add(DashboardTimeseriesPoint(date: parseDate(e.key), value: parseInt(e.value)));
      }
      out.sort((a, b) => a.date.compareTo(b.date));
      return out;
    }
    return const [];
  }

  Map<String, int> parseStringIntMap(dynamic v, {String keyField = 'key', String valueField = 'value'}) {
    if (v == null) return const {};
    if (v is Map) {
      final out = <String, int>{};
      for (final e in v.entries) {
        out[e.key.toString()] = parseInt(e.value);
      }
      return out;
    }
    if (v is List) {
      final out = <String, int>{};
      for (final raw in v) {
        if (raw is Map) {
          final m = raw.cast<String, dynamic>();
          final k = (m[keyField] ?? m['platform'] ?? m['feature'] ?? m['name'] ?? '').toString();
          if (k.trim().isEmpty) continue;
          out[k] = parseInt(m[valueField] ?? m['count'] ?? m['value']);
        }
      }
      return out;
    }
    return const {};
  }

  List<CountryUsageRow> parseCountryUsage(dynamic v) {
    if (v is! List) return const [];
    final out = <CountryUsageRow>[];
    for (final raw in v) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      out.add(
        CountryUsageRow(
          country: (m['country'] ?? m['country_code'] ?? m['c'] ?? '—').toString(),
          totalUsers: parseInt(m['total_users'] ?? m['totalUsers'] ?? m['users_total'] ?? m['users']),
          activeUsers: parseInt(m['active_users'] ?? m['activeUsers'] ?? m['users_active'] ?? m['active']),
          storageUsedBytes: parseInt(m['storage_used_bytes'] ?? m['storageUsedBytes'] ?? m['storage_bytes']),
          aiTokensUsed: parseInt(m['ai_tokens_used'] ?? m['aiTokensUsed'] ?? m['ai_tokens']),
          paidUsers: parseInt(m['paid_users'] ?? m['paidUsers'] ?? m['users_paid'] ?? m['paid']),
        ),
      );
    }
    out.sort((a, b) => b.totalUsers.compareTo(a.totalUsers));
    return out;
  }

  List<AlertRow> parseAlerts(dynamic v) {
    if (v is! List) return const [];
    final out = <AlertRow>[];
    for (final raw in v) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      out.add(
        AlertRow(
          type: (m['type'] ?? m['alert_type'] ?? m['name'] ?? 'Alert').toString(),
          count: parseInt(m['count'] ?? m['total'] ?? m['n']),
          severity: (m['severity'] ?? m['level'] ?? 'low').toString(),
          // PRIVACY: never render arbitrary note text from server if it could include user content.
          // Keep the model field but default to empty unless it's clearly a controlled string.
          note: (m['note'] ?? '').toString(),
        ),
      );
    }
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  List<SystemStatusCard> parseSystemStatus(dynamic v) {
    if (v is! List) return const [];
    final out = <SystemStatusCard>[];
    for (final raw in v) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      out.add(
        SystemStatusCard(
          label: (m['label'] ?? m['service'] ?? m['name'] ?? 'Service').toString(),
          status: (m['status'] ?? m['state'] ?? 'ok').toString(),
          detail: (m['detail'] ?? m['message'] ?? '').toString(),
          updatedAt: parseDate(m['updated_at'] ?? m['updatedAt'] ?? m['ts'] ?? m['timestamp']),
        ),
      );
    }
    return out;
  }

  return DashboardSnapshot(
    query: query,
    totalRegisteredUsers: parseInt(json['total_registered_users'] ?? json['totalRegisteredUsers']),
    newUsersThisWeek: parseInt(json['new_users_this_week'] ?? json['newUsersThisWeek']),
    newUsersThisMonth: parseInt(json['new_users_this_month'] ?? json['newUsersThisMonth']),
    dailyActiveUsers: parseInt(json['daily_active_users'] ?? json['dailyActiveUsers']),
    weeklyActiveUsers: parseInt(json['weekly_active_users'] ?? json['weeklyActiveUsers']),
    monthlyActiveUsers: parseInt(json['monthly_active_users'] ?? json['monthlyActiveUsers']),
    userGrowth: parseTimeseries(json['user_growth'] ?? json['user_growth_daily'] ?? json['registered_users_by_day'] ?? json['users_over_time']),
    totalStorageUsedBytes: parseInt(json['total_storage_used_bytes'] ?? json['totalStorageUsedBytes']),
    averageStoragePerUserBytes: parseInt(json['average_storage_per_user_bytes'] ?? json['averageStoragePerUserBytes']),
    usersNearStorageLimit: parseInt(json['users_near_storage_limit'] ?? json['usersNearStorageLimit']),
    aiTokensUsedThisMonth: parseInt(json['ai_tokens_used_this_month'] ?? json['aiTokensUsedThisMonth']),
    aiEstimatedCostThisMonthUsd: parseDouble(json['ai_estimated_cost_this_month_usd'] ?? json['aiEstimatedCostThisMonthUsd']),
    usersNearAiLimit: parseInt(json['users_near_ai_limit'] ?? json['usersNearAiLimit']),
    freeUsers: parseInt(json['free_users'] ?? json['freeUsers']),
    trialUsers: parseInt(json['trial_users'] ?? json['trialUsers']),
    paidUsers: parseInt(json['paid_users'] ?? json['paidUsers']),
    cancelledUsers: parseInt(json['cancelled_users'] ?? json['cancelledUsers']),
    failedPayments: parseInt(json['failed_payments'] ?? json['failedPayments']),
    countryUsage: parseCountryUsage(json['country_usage'] ?? json['countries'] ?? json['country_breakdown']),
    platformUsage: parseStringIntMap(json['platform_usage'] ?? json['platforms'], keyField: 'platform', valueField: 'count'),
    featureUsage: parseStringIntMap(json['feature_usage'] ?? json['features'], keyField: 'feature', valueField: 'count'),
    alerts: parseAlerts(json['alerts'] ?? json['operational_alerts']),
    systemStatus: parseSystemStatus(json['system_status'] ?? json['services']),
    generatedAt: parseDate(json['generated_at'] ?? json['generatedAt'] ?? DateTime.now().toUtc().toIso8601String()),
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

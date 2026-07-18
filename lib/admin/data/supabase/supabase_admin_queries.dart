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
  static const String rpcCountryUsageSummary =
      'admin_get_country_usage_summary';
  static const String rpcStorageSummaryV2 = 'admin_get_storage_summary_v2';
  static const String rpcStorageSummaryV1 = 'admin_get_storage_summary';
  static const String rpcAiUsageSummaryV1 = 'admin_get_ai_usage_summary';
  static const String rpcAiUsageSummaryV2 = 'admin_get_ai_usage_summary_v2';
  static const String rpcSupportSummary = 'admin_get_support_summary';
  static const String rpcAuditSummary = 'admin_get_audit_summary';
  static const String rpcSystemHealthSummary =
      'admin_get_system_health_summary';
  static const String rpcSystemHealthSummaryV2 =
      'admin_get_system_health_summary_v2';
  static const String rpcComplianceSummary = 'admin_get_compliance_summary';
  static const String rpcPlanPermissionSummary =
      'admin_get_plan_permission_summary';
  static const String rpcUserAccountDetail = 'admin_get_user_account_detail';
  static const String rpcRunUserDiagnostics = 'admin_run_user_diagnostics';
  static const String rpcPerformUserAction = 'admin_perform_user_action';
  static const String rpcSupportSessionDetail =
      'admin_get_support_session_detail';
  static const String rpcPerformSupportAction = 'admin_perform_support_action';
  static const String rpcPerformComplianceAction =
      'admin_perform_compliance_action';

  AiFeatureArea? _parseAiFeatureArea(String raw) {
    final v = raw.trim().toLowerCase();
    return switch (v) {
      'ai_assistant' ||
      'assistant' ||
      'aiassistant' =>
        AiFeatureArea.aiAssistant,
      'document_summary' ||
      'documentsummary' ||
      'doc_summary' =>
        AiFeatureArea.documentSummary,
      'timeline_summary' || 'timelinesummary' => AiFeatureArea.timelineSummary,
      'search_helper' ||
      'searchhelper' ||
      'search' =>
        AiFeatureArea.searchHelper,
      'appointment_helper' ||
      'appointmenthelper' ||
      'appointments' =>
        AiFeatureArea.appointmentHelper,
      'health_organisation_helper' ||
      'healthorganizationhelper' ||
      'health_organization_helper' ||
      'organisation_helper' ||
      'organization_helper' =>
        AiFeatureArea.healthOrganisationHelper,
      'export_helper' ||
      'exporthelper' ||
      'export' =>
        AiFeatureArea.exportHelper,
      _ => null,
    };
  }

  SupabaseClient get _client {
    final c = ControlSupabaseClient.tryGet();
    if (c == null) throw StateError('Supabase not initialized/configured.');
    return c;
  }

  DateTime? _tryParseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
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
        .select(
            'admin_user_id, email, display_name, role, is_active, require_step_up, created_at, updated_at')
        .eq('admin_user_id', authUser.id)
        // Enforce allow-list rule at the query level.
        .eq('is_active', true)
        .maybeSingle();

    if (row == null)
      throw StateError(
          'Not an active admin user (no matching admin_users row).');
    // Row already filtered by is_active=true, but keep defensive checks.
    final isActive = row['is_active'] == true;
    if (!isActive) throw StateError('Admin is not active.');

    final role = parseAdminRole((row['role'] as String?) ?? '');
    if (role == null) throw StateError('Unknown admin role.');

    String? themePreference;
    for (final column in const ['theme_preference', 'theme_mode']) {
      try {
        final themeRow = await _client
            .from('admin_users')
            .select(column)
            .eq('admin_user_id', authUser.id)
            .maybeSingle();
        themePreference = themeRow?[column]?.toString();
        if (themePreference != null && themePreference.trim().isNotEmpty) {
          break;
        }
      } catch (e) {
        debugPrint('getCurrentAdminUser($column) skipped: $e');
      }
    }

    // Normalize to AdminUser model.
    return AdminUser(
      id: (row['admin_user_id'] ?? authUser.id).toString(),
      email: (row['email'] as String?) ?? (authUser.email ?? ''),
      displayName: (row['display_name'] as String?)?.trim().isEmpty == true
          ? null
          : (row['display_name'] as String?),
      role: role,
      isActive: isActive,
      requireStepUp: row['require_step_up'] == true,
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
      updatedAt: DateTime.tryParse((row['updated_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      themePreference: themePreference,
    );
  }

  /// Best-effort: persist admin theme preference to the admin profile.
  ///
  /// This is intentionally defensive because different environments may name the
  /// column differently (e.g. theme_preference vs theme_mode) or may enforce RLS.
  /// Failure must not block the UI.
  Future<void> setAdminThemePreference(
      {required String themePreference}) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('Not signed in.');

    Future<void> attempt(String column) async =>
        _client.from('admin_users').update({
          column: themePreference,
          'updated_at': DateTime.now().toUtc().toIso8601String()
        }).eq('admin_user_id', authUser.id);

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

  void _requireRole(AdminUser admin, Set<AdminRole> allowed,
      {required String capability}) {
    if (!allowed.contains(admin.role)) {
      throw StateError('Access denied ($capability): role ${admin.role.name}');
    }
  }

  Future<DashboardSnapshot> getDashboardMetrics(
      {required AdminUser admin, required DashboardQuery query}) async {
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
      final row = _firstRpcRow(res);

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
          'User profiles':
              (readNum(['total_user_profiles', 'total_profiles'])?.toInt()) ??
                  0,
          'Family members': (readNum(['total_family_members'])?.toInt()) ?? 0,
          'Medical records':
              (readNum(['total_medical_records', 'total_medical_records_count'])
                      ?.toInt()) ??
                  0,
          'Appointments':
              (readNum(['total_appointments', 'total_appointments_count'])
                      ?.toInt()) ??
                  0,
          'Medications':
              (readNum(['total_medications', 'total_medications_count'])
                      ?.toInt()) ??
                  0,
          'Vaccinations':
              (readNum(['total_vaccinations', 'total_vaccinations_count'])
                      ?.toInt()) ??
                  0,
          'Blood pressure entries': (readNum([
                'total_blood_pressure_entries',
                'total_blood_pressure_entries_count'
              ])?.toInt()) ??
              0,
          'Documents': (readNum([
                'total_medical_documents',
                'total_medical_documents_count'
              ])?.toInt()) ??
              0,
          'Insurance cards': (readNum(['total_insurance_cards'])?.toInt()) ?? 0,
          'Usage events':
              (readNum(['total_usage_events', 'total_usage_events_count'])
                      ?.toInt()) ??
                  0,
          'Audit events':
              (readNum(['total_audit_events', 'total_audit_events_count'])
                      ?.toInt()) ??
                  0,
          'Support sessions': (readNum([
                'total_support_sessions',
                'total_support_sessions_count'
              ])?.toInt()) ??
              0,
          'Compliance requests': (readNum([
                'total_compliance_requests',
                'total_compliance_requests_count'
              ])?.toInt()) ??
              0,
        };

        final adapted = <String, dynamic>{
          'total_registered_users':
              readNum(['total_auth_users', 'total_registered_users']) ??
                  row['total_auth_users'],
          'feature_usage': featureUsage,
          'generated_at': DateTime.now().toUtc().toIso8601String(),
        };
        return _parseDashboardSnapshot(adapted, query);
      }
    } catch (e) {
      debugPrint(
          'SupabaseAdminQueries.getDashboardMetrics admin_get_dashboard_metrics failed: $e');
    }

    // Legacy: older control_* RPC/view (optional; may not exist).
    try {
      final res = await _client.rpc('control_get_dashboard_metrics',
          params: _dashboardQueryParams(query));
      if (res is Map<String, dynamic>)
        return _parseDashboardSnapshot(res, query);
    } catch (e) {
      debugPrint(
          'SupabaseAdminQueries.getDashboardMetrics legacy rpc failed: $e');
    }

    throw StateError(
        'Dashboard metrics unavailable (no admin-safe RPC deployed).');
  }

  Future<List<UserAccountSummary>> getUsersList(
      {required AdminUser admin,
      required UserListQuery query,
      required int limit}) async {
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.support},
        capability: 'users_list');

    // Preferred: admin-safe reporting RPC.
    try {
      final canEmail = AdminRbac.canViewUserEmail(admin.role);
      final res = await _client.rpc(rpcUserUsageSummary);
      if (res is List) {
        final rows =
            res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();

        List<Map<String, dynamic>> filtered = rows;
        final q = query.search.trim();
        if (q.isNotEmpty) {
          filtered = rows.where((r) {
            final id = (r['user_id'] ?? '').toString();
            final email = (r['email'] ?? '').toString();
            if (id.toLowerCase().contains(q.toLowerCase())) return true;
            if (canEmail && email.toLowerCase().contains(q.toLowerCase()))
              return true;
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
            lastActiveAt:
                DateTime.tryParse((r['last_sign_in_at'] ?? '').toString()),
            platform: '—',
            appVersion: '—',
            failedSyncCount7d: 0,
            failedUploadCount7d: 0,
            lastKnownErrorCode: null,
            billingStatus: '—',
            subscriptionProvider: '—',
            createdAt: DateTime.tryParse((r['created_at'] ?? '').toString()) ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
            updatedAt: DateTime.now().toUtc(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint(
          'SupabaseAdminQueries.getUsersList admin_get_user_usage_summary failed: $e');
    }

    // Legacy: safe summary views (optional / may not be deployed).
    final canEmail = AdminRbac.canViewUserEmail(admin.role);
    final select = canEmail
        ? 'user_id, email, plan_name, status, created_at, last_active_at, country, platform, app_version, storage_used_bytes, storage_limit_bytes, ai_tokens_monthly, ai_tokens_limit_monthly'
        : 'user_id, plan_name, status, created_at, last_active_at, country, platform, app_version, storage_used_bytes, storage_limit_bytes, ai_tokens_monthly, ai_tokens_limit_monthly';

    final builder =
        _client.schema('control').from('user_account_summaries').select(select);
    final filtered = _applyUserListFilters(builder, query);
    final rows =
        await filtered.order('last_active_at', ascending: false).limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UserAccountSummary.fromJson)
        .toList();
  }

  PostgrestFilterBuilder _applyUserListFilters(
      PostgrestFilterBuilder builder, UserListQuery query) {
    final f = query.filters;
    if (query.search.trim().isNotEmpty) {
      // PRIVACY: do not search on health fields. Search on safe metadata only.
      // If email is not allowed by RLS, this will still be safe / return empty.
      final q = query.search.trim();
      builder = builder.or('user_id.ilike.%$q%,email.ilike.%$q%');
    }
    if (f.plan != null && f.plan!.trim().isNotEmpty)
      builder = builder.eq('plan_name', f.plan!.trim());
    if (f.accountStatus != null && f.accountStatus!.trim().isNotEmpty)
      builder = builder.eq('status', f.accountStatus!.trim());
    if (f.country != null && f.country!.trim().isNotEmpty)
      builder = builder.eq('country', f.country!.trim());
    if (f.platform != null && f.platform!.trim().isNotEmpty)
      builder = builder.eq('platform', f.platform!.trim());
    return builder;
  }

  Future<UserUsageSummary> getUserUsageSummary(
      {required AdminUser admin, required String userId}) async {
    _requireRole(
        admin,
        <AdminRole>{
          AdminRole.owner,
          AdminRole.support,
          AdminRole.admin,
          AdminRole.billing
        },
        capability: 'user_usage_summary');

    try {
      final row = await _client
          .schema('control')
          .from('user_usage_summaries')
          // Explicit safe fields only.
          .select(
              'user_id, events_30d, sessions_30d, last_seen_at, storage_used_bytes, ai_requests_30d, ai_tokens_30d')
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) return UserUsageSummary.fromJson(row);
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getUserUsageSummary failed: $e');
    }
    throw StateError('User usage summary unavailable.');
  }

  Future<UserAccountDetail> getUserAccountDetail(
      {required AdminUser admin, required String userId}) async {
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.support},
        capability: 'user_detail');
    final row = await _rpcSingleRow(
      rpcUserAccountDetail,
      params: {
        'p_user_id': userId,
        'p_include_email': AdminRbac.canViewUserEmail(admin.role)
      },
    );
    if (row == null) throw StateError('User detail unavailable.');
    return _userAccountDetailFromJson(row);
  }

  Future<DiagnosticsReport> runUserDiagnostics(
      {required AdminUser admin, required String userId}) async {
    _requireRole(admin, AdminRbac.support, capability: 'user_diagnostics');
    final res =
        await _client.rpc(rpcRunUserDiagnostics, params: {'p_user_id': userId});
    final rows = (res is List)
        ? res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const <Map<String, dynamic>>[];
    final checks = rows.map(_diagnosticCheckFromJson).toList();
    return DiagnosticsReport(
        userId: userId, generatedAt: DateTime.now().toUtc(), checks: checks);
  }

  Future<void> performUserAdminAction(
      {required AdminUser admin, required AdminActionRequest request}) async {
    _requireRole(
        admin, <AdminRole>{AdminRole.owner, AdminRole.admin, AdminRole.support},
        capability: 'user_admin_action');
    await _client.rpc(
      rpcPerformUserAction,
      params: {
        'p_target_user_id': request.userId,
        'p_action': request.action,
        'p_reason': request.reason,
        'p_ticket_id': request.ticketReference,
        'p_parameters': request.parameters ?? const <String, dynamic>{},
      },
    );
  }

  Future<List<UsageEventAggregateRow>> getUsageEvents(
      {required AdminUser admin,
      required UsageEventsQuery query,
      required int limit}) async {
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
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(UsageEventAggregateRow.fromJson)
          .toList();
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getUsageEvents failed: $e');
      rethrow;
    }
  }

  Future<AiUsageSnapshot> getAIUsage(
      {required AdminUser admin, required AiUsageQuery query}) async {
    _requireRole(admin, AdminRbac.analytics, capability: 'ai_usage');

    try {
      dynamic res;
      String rpcName = rpcAiUsageSummaryV2;
      try {
        res = await _client.rpc(rpcAiUsageSummaryV2);
      } catch (e) {
        debugPrint(
            'SupabaseAdminQueries.getAIUsage admin_get_ai_usage_summary_v2 not available: $e');
        rpcName = rpcAiUsageSummaryV1;
        res = await _client.rpc(rpcAiUsageSummaryV1);
      }

      final row = _firstRpcRow(res);

      // Empty result = no data collected yet.
      if (row == null) {
        return AiUsageSnapshot(
          query: query,
          source: rpcName,
          sourceNote: rpcName == rpcAiUsageSummaryV1
              ? 'Partial: legacy token-only AI usage summary; provider/service split not available.'
              : null,
          aiRequestsThisMonth: 0,
          inputTokensThisMonth: 0,
          outputTokensThisMonth: 0,
          estimatedCostThisMonthUsd: 0,
          pagesProcessedThisMonth: 0,
          filesProcessedThisMonth: 0,
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
          usageByProvider: const [],
          usageByService: const [],
          usageByProviderService: const [],
          usageByModelV2: const [],
          failuresByProvider: const [],
          failuresByErrorCode: const [],
          dailyUsage: const [],
          generatedAt: DateTime.now().toUtc(),
        );
      }

      return (rpcName == rpcAiUsageSummaryV2)
          ? _parseAiUsageV2(query: query, row: row, rpcName: rpcName)
          : _parseAiUsageLegacy(query: query, row: row, rpcName: rpcName);
    } catch (e) {
      debugPrint(
          'SupabaseAdminQueries.getAIUsage admin_get_ai_usage_summary(_v2) failed: $e');
      rethrow;
    }
  }

  AiUsageSnapshot _parseAiUsageLegacy(
      {required AiUsageQuery query,
      required Map<String, dynamic> row,
      required String rpcName}) {
    final totalRequests = (row['total_request_count'] as num?)?.toInt() ??
        (row['ai_request_count'] as num?)?.toInt() ??
        0;
    final inputTokens = (row['input_tokens'] as num?)?.toInt() ?? 0;
    final outputTokens = (row['output_tokens'] as num?)?.toInt() ?? 0;
    final estimatedCost = (row['estimated_cost'] as num?)?.toDouble() ?? 0;

    int failedRequests = (row['failed_ai_requests'] as num?)?.toInt() ?? 0;
    if (failedRequests == 0 && row['failures_by_error_code'] != null) {
      try {
        final failures = row['failures_by_error_code'];
        if (failures is List) {
          failedRequests = failures.fold<int>(
              0,
              (sum, e) =>
                  sum +
                  ((e is Map
                          ? (e['failure_count'] as num?)?.toInt()
                          : null) ??
                      0));
        }
      } catch (e) {
        debugPrint(
            'SupabaseAdminQueries._parseAiUsageLegacy failed to parse failures_by_error_code: $e');
      }
    }

    List<AiFeatureUsageRow> usageByFeature = const [];
    if (row['usage_by_feature_area'] is List) {
      try {
        final list = (row['usage_by_feature_area'] as List)
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        usageByFeature = list.map((m) {
          final feature =
              _parseAiFeatureArea((m['feature_area'] as String?) ?? '') ??
                  AiFeatureArea.aiAssistant;
          return AiFeatureUsageRow(
            featureArea: feature,
            requests: (m['request_count'] as num?)?.toInt() ?? 0,
            inputTokens: (m['input_tokens'] as num?)?.toInt() ?? 0,
            outputTokens: (m['output_tokens'] as num?)?.toInt() ?? 0,
            failedRequests: (m['failed_request_count'] as num?)?.toInt() ?? 0,
            estimatedCostUsd: (m['estimated_cost'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      } catch (e) {
        debugPrint(
            'SupabaseAdminQueries._parseAiUsageLegacy failed to parse usage_by_feature_area: $e');
      }
    }

    return AiUsageSnapshot(
      query: query,
      source: rpcName,
      sourceNote:
          'Partial: legacy token-only AI usage summary; provider/service split not available.',
      aiRequestsThisMonth: totalRequests,
      inputTokensThisMonth: inputTokens,
      outputTokensThisMonth: outputTokens,
      estimatedCostThisMonthUsd: estimatedCost,
      pagesProcessedThisMonth: 0,
      filesProcessedThisMonth: 0,
      failedAiRequestsThisMonth: failedRequests,
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
      usageByProvider: const [],
      usageByService: const [],
      usageByProviderService: const [],
      usageByModelV2: const [],
      failuresByProvider: const [],
      failuresByErrorCode: const [],
      dailyUsage: const [],
      generatedAt: DateTime.now().toUtc(),
    );
  }

  AiUsageSnapshot _parseAiUsageV2(
      {required AiUsageQuery query,
      required Map<String, dynamic> row,
      required String rpcName}) {
    List<Map<String, dynamic>> _asListOfMaps(Object? v) {
      if (v is! List) return const [];
      return v
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList(growable: false);
    }

    final totalRequests = (row['total_request_count'] as num?)?.toInt() ?? 0;
    final totalCost = (row['total_cost_usd'] as num?)?.toDouble() ?? 0;
    final inputTokens = (row['total_input_tokens'] as num?)?.toInt() ?? 0;
    final outputTokens = (row['total_output_tokens'] as num?)?.toInt() ?? 0;
    final pagesProcessed = (row['total_pages_processed'] as num?)?.toInt() ?? 0;
    final filesProcessed = (row['total_files_processed'] as num?)?.toInt() ?? 0;
    final failures = (row['total_failures'] as num?)?.toInt() ?? 0;

    final usageByFeatureArea = _asListOfMaps(row['usage_by_feature_area']).map((m) {
      final feature =
          _parseAiFeatureArea((m['feature_area'] as String?) ?? '') ??
              AiFeatureArea.aiAssistant;
      return AiFeatureUsageRow(
        featureArea: feature,
        requests: (m['request_count'] as num?)?.toInt() ?? 0,
        inputTokens: 0,
        outputTokens: 0,
        failedRequests: (m['failed_request_count'] as num?)?.toInt() ?? 0,
        estimatedCostUsd:
            (m['estimated_cost_usd'] as num?)?.toDouble() ?? 0,
      );
    }).toList(growable: false);

    AiProviderServiceUsageRow _psRow(Map<String, dynamic> m,
        {String? defaultProvider, String? defaultService}) {
      return AiProviderServiceUsageRow(
        provider: (m['provider'] as String?) ?? defaultProvider ?? 'unknown',
        service: (m['service'] as String?) ?? defaultService ?? 'unknown',
        requestCount: (m['request_count'] as num?)?.toInt() ?? 0,
        estimatedCostUsd: (m['estimated_cost_usd'] as num?)?.toDouble() ?? 0,
        inputTokens: (m['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (m['output_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: (m['total_tokens'] as num?)?.toInt() ?? 0,
        pagesProcessed: (m['pages_processed'] as num?)?.toInt() ?? 0,
        filesProcessed: (m['files_processed'] as num?)?.toInt() ?? 0,
        imagesProcessed: (m['images_processed'] as num?)?.toInt() ?? 0,
        failedRequestCount: (m['failed_request_count'] as num?)?.toInt() ?? 0,
      );
    }

    final usageByProvider = _asListOfMaps(row['usage_by_provider'])
        .map((m) => _psRow(m, defaultService: 'unknown'))
        .toList(growable: false);

    final usageByService = _asListOfMaps(row['usage_by_service'])
        .map((m) => _psRow(m, defaultProvider: 'unknown'))
        .toList(growable: false);

    final usageByProviderService = _asListOfMaps(row['usage_by_provider_service'])
        .map((m) => _psRow(m))
        .toList(growable: false);

    final usageByModelV2 = _asListOfMaps(row['usage_by_model']).map((m) {
      return AiModelUsageRowV2(
        provider: (m['provider'] as String?) ?? 'unknown',
        service: (m['service'] as String?) ?? 'unknown',
        model: (m['model'] as String?) ?? 'unknown',
        requestCount: (m['request_count'] as num?)?.toInt() ?? 0,
        inputTokens: (m['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (m['output_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: (m['total_tokens'] as num?)?.toInt() ?? 0,
        estimatedCostUsd: (m['estimated_cost_usd'] as num?)?.toDouble() ?? 0,
        failedRequestCount: (m['failed_request_count'] as num?)?.toInt() ?? 0,
      );
    }).toList(growable: false);

    final failuresByProvider = _asListOfMaps(row['failures_by_provider'])
        .map((m) => AiProviderServiceUsageRow(
              provider: (m['provider'] as String?) ?? 'unknown',
              service: (m['service'] as String?) ?? 'unknown',
              requestCount: 0,
              estimatedCostUsd: 0,
              inputTokens: 0,
              outputTokens: 0,
              totalTokens: 0,
              pagesProcessed: 0,
              filesProcessed: 0,
              imagesProcessed: 0,
              failedRequestCount: (m['failure_count'] as num?)?.toInt() ?? 0,
            ))
        .toList(growable: false);

    final failuresByErrorCode = _asListOfMaps(row['failures_by_error_code'])
        .map((m) => AiFailureBreakdownRow(
              provider: (m['provider'] as String?) ?? 'unknown',
              service: (m['service'] as String?) ?? 'unknown',
              errorCode: (m['error_code'] as String?) ?? 'unknown',
              failureCount: (m['failure_count'] as num?)?.toInt() ?? 0,
            ))
        .toList(growable: false);

    final dailyUsage = _asListOfMaps(row['daily_usage']).map((m) {
      DateTime day;
      try {
        day = DateTime.parse((m['day'] as String?) ?? '').toUtc();
      } catch (_) {
        day = DateTime.now().toUtc();
      }
      return AiDailyUsageRow(
        day: day,
        requestCount: (m['request_count'] as num?)?.toInt() ?? 0,
        estimatedCostUsd: (m['estimated_cost_usd'] as num?)?.toDouble() ?? 0,
        totalTokens: (m['total_tokens'] as num?)?.toInt() ?? 0,
        pagesProcessed: (m['pages_processed'] as num?)?.toInt() ?? 0,
        filesProcessed: (m['files_processed'] as num?)?.toInt() ?? 0,
        imagesProcessed: (m['images_processed'] as num?)?.toInt() ?? 0,
        failures: (m['failures'] as num?)?.toInt() ?? 0,
      );
    }).toList(growable: false);

    return AiUsageSnapshot(
      query: query,
      source: rpcName,
      sourceNote: null,
      aiRequestsThisMonth: totalRequests,
      inputTokensThisMonth: inputTokens,
      outputTokensThisMonth: outputTokens,
      estimatedCostThisMonthUsd: totalCost,
      pagesProcessedThisMonth: pagesProcessed,
      filesProcessedThisMonth: filesProcessed,
      failedAiRequestsThisMonth: failures,
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
      usageByFeature: usageByFeatureArea,
      usageByProvider: usageByProvider,
      usageByService: usageByService,
      usageByProviderService: usageByProviderService,
      usageByModelV2: usageByModelV2,
      failuresByProvider: failuresByProvider,
      failuresByErrorCode: failuresByErrorCode,
      dailyUsage: dailyUsage,
      generatedAt: DateTime.now().toUtc(),
    );
  }

  Future<AdminQueryResult<StorageSnapshot>> getStorageUsage(
      {required AdminUser admin, required StorageQuery query}) async {
    _requireRole(
        admin, <AdminRole>{AdminRole.owner, AdminRole.admin, AdminRole.billing},
        capability: 'storage_usage');

    try {
      dynamic res;
      String rpcName = rpcStorageSummaryV2;
      try {
        // Prefer v2 (privacy-safe storage metadata table + better failure counting).
        res = await _client.rpc(rpcStorageSummaryV2);
      } catch (e) {
        debugPrint(
            'SupabaseAdminQueries.getStorageUsage admin_get_storage_summary_v2 not available: $e');
        rpcName = rpcStorageSummaryV1;
        res = await _client.rpc(rpcStorageSummaryV1);
      }
      final row = _firstRpcRow(res);

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

      final totalStorageMb =
          (row['total_storage_used_mb'] as num?)?.toInt() ?? 0;
      final avgMb = (row['average_storage_per_user_mb'] as num?)?.toInt() ?? 0;

      // v2 adds better upload failure counters; keep old field names supported.
      final failedUploads24h =
          (row['failed_upload_events_24h'] as num?)?.toInt() ?? 0;
      final failedUploadsTotal = (row['failed_upload_count'] as num?)?.toInt();

      return AdminQueryResult(
        name: rpcName,
        value: StorageSnapshot(
          query: query,
          totalStorageUsedBytes: totalStorageMb * 1048576,
          totalDocumentCount:
              (row['total_document_count'] as num?)?.toInt() ?? 0,
          averageStoragePerUserBytes: avgMb * 1048576,
          usersOverStorageLimit:
              (row['users_over_storage_limit'] as num?)?.toInt() ?? 0,
          usersOver80PercentStorageLimit:
              (row['users_near_storage_limit'] as num?)?.toInt() ?? 0,
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
      debugPrint(
          'SupabaseAdminQueries.getStorageUsage admin_get_storage_summary failed: $e');
      rethrow;
    }
  }

  Future<BillingSnapshot> getBillingSummary(
      {required AdminUser admin, required BillingQuery query}) async {
    _requireRole(admin, AdminRbac.billing, capability: 'billing_summary');

    // Preferred: admin-safe billing summary RPC.
    try {
      final res = await _client.rpc('admin_get_billing_summary');
      if (res is List) {
        final rows =
            res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
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
              revenueMetricsInstrumented: false,
              revenueMetricsNote: 'Revenue not instrumented yet.',
            ),
            subscriptions: const [],
            trials: const [],
            failedPayments: const [],
            revenueByPlan: const [],
            revenueByCountry: const [],
            diagnostics: BillingDiagnostics(
              summarySource: 'admin_get_billing_summary',
              revenueSource: BillingRevenueSource.none,
              sections: {
                'Overview': const BillingSectionStatus(state: BillingSectionState.empty, message: 'No billing rows have been recorded yet.', requiredSource: 'user_entitlements'),
                'Subscriptions': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Subscription detail view is not instrumented yet.', requiredSource: 'subscription_events + detail RPC'),
                'Trials': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Trial detail view is not instrumented yet.', requiredSource: 'subscription_events + detail RPC'),
                'Failed payments': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Failed payment detail view is not instrumented yet.', requiredSource: 'subscription_events + detail RPC'),
                'Revenue by plan': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Revenue reporting is not instrumented yet.', requiredSource: 'RevenueCat or Stripe revenue feed'),
                'Revenue by country': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Revenue reporting is not instrumented yet.', requiredSource: 'RevenueCat or Stripe revenue feed'),
              },
              dataSources: const [],
            ),
            generatedAt: DateTime.now().toUtc(),
          );
        }

        int sumBy(bool Function(Map<String, dynamic> r) pred, String field) =>
            rows.where(pred).fold<int>(0, (a, r) => a + ((r[field] as num?)?.toInt() ?? 0));

        int sumUserCount(bool Function(Map<String, dynamic> r) pred) =>
            rows.where(pred).fold<int>(0, (a, r) => a + ((r['user_count'] as num?)?.toInt() ?? 0));

        final freeUsers = sumUserCount((r) => (r['plan'] ?? '').toString().toLowerCase() == 'free');
        final trialUsers = sumUserCount((r) => (r['billing_status'] ?? '').toString().toLowerCase() == 'trialing');
        final cancelledUsers = sumUserCount((r) {
          final s = (r['billing_status'] ?? '').toString().toLowerCase();
          return s == 'canceled' || s == 'cancelled' || s == 'expired';
        });
        final activePaidUsers = sumUserCount((r) {
          final plan = (r['plan'] ?? '').toString().toLowerCase();
          final status = (r['billing_status'] ?? '').toString().toLowerCase();
          return status == 'active' && plan != 'free';
        });
        // Prefer failed_payment_count (derived from subscription_events) over guessing from status.
        final failedPayments = rows.fold<int>(0, (a, r) => a + ((r['failed_payment_count'] as num?)?.toInt() ?? 0));

        BillingRevenueSource revenueSource = BillingRevenueSource.unknown;
        final providers = rows
            .map((r) => (r['subscription_provider'] ?? '').toString().trim().toLowerCase())
            .where((p) => p.isNotEmpty)
            .toSet();
        if (providers.contains('revenuecat')) revenueSource = BillingRevenueSource.revenueCat;
        else if (providers.contains('stripe')) revenueSource = BillingRevenueSource.stripe;
        else if (providers.contains('manual') || providers.contains('manual/admin') || providers.contains('manual_admin')) revenueSource = BillingRevenueSource.manualEntitlement;
        else if (providers.isEmpty || (providers.length == 1 && providers.first == 'unknown')) revenueSource = BillingRevenueSource.none;

        final revenueCat = await _tryGetRevenueCatSyncHealth();
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
            revenueMetricsInstrumented: false,
            revenueMetricsNote: 'Revenue not instrumented yet (no RevenueCat/Stripe revenue feed in admin summary RPC).',
          ),
          subscriptions: const [],
          trials: const [],
          failedPayments: const [],
          revenueByPlan: const [],
          revenueByCountry: const [],
          revenueCat: revenueCat,
          diagnostics: BillingDiagnostics(
            summarySource: 'admin_get_billing_summary',
            revenueSource: revenueSource,
            sections: {
              'Overview': BillingSectionStatus(state: BillingSectionState.live, message: 'Counts are derived from admin_get_billing_summary aggregates (user_entitlements + subscription_events).', requiredSource: 'admin_get_billing_summary'),
              'Subscriptions': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Subscriptions table needs a privacy-safe detail RPC/view (not deployed).', requiredSource: 'admin_get_subscriptions_detail (RPC/view)'),
              'Trials': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Trials table needs a privacy-safe detail RPC/view (not deployed).', requiredSource: 'admin_get_trials_detail (RPC/view)'),
              'Failed payments': BillingSectionStatus(state: failedPayments > 0 ? BillingSectionState.partial : BillingSectionState.notInstrumented, message: failedPayments > 0 ? 'Failed payment count is derived from subscription_events; row-level detail is not instrumented.' : 'Failed payment detail view is not instrumented yet.', requiredSource: 'subscription_events + detail RPC'),
              'Revenue by plan': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Revenue by plan is not instrumented yet.', requiredSource: 'RevenueCat/Stripe revenue rollups'),
              'Revenue by country': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Revenue by country is not instrumented yet.', requiredSource: 'RevenueCat/Stripe revenue rollups'),
            },
            dataSources: const [],
          ),
          generatedAt: DateTime.now().toUtc(),
        );
      }
    } catch (e) {
      debugPrint(
          'SupabaseAdminQueries.getBillingSummary admin_get_billing_summary failed: $e');
    }

    // Legacy snapshot RPC (optional).
    try {
      final res = await _client.rpc('control_get_billing_snapshot',
          params: _billingQueryParams(query));
      if (res is Map<String, dynamic>) {
        final snapshot = _parseBillingSnapshot(res, query);
        final revenueCat = await _tryGetRevenueCatSyncHealth();
        final revenueInstrumented = snapshot.overview.monthlyRecurringRevenueUsd > 0 || snapshot.overview.annualRecurringRevenueUsd > 0;
        final overview = snapshot.overview.revenueMetricsInstrumented
            ? snapshot.overview
            : BillingOverviewMetrics(
                activePaidUsers: snapshot.overview.activePaidUsers,
                freeUsers: snapshot.overview.freeUsers,
                trialUsers: snapshot.overview.trialUsers,
                cancelledUsers: snapshot.overview.cancelledUsers,
                failedPayments: snapshot.overview.failedPayments,
                monthlyRecurringRevenueUsd: snapshot.overview.monthlyRecurringRevenueUsd,
                annualRecurringRevenueUsd: snapshot.overview.annualRecurringRevenueUsd,
                averageRevenuePerUserUsd: snapshot.overview.averageRevenuePerUserUsd,
                trialConversionRate: snapshot.overview.trialConversionRate,
                revenueMetricsInstrumented: revenueInstrumented,
                revenueMetricsNote: revenueInstrumented ? null : 'Revenue not instrumented yet.',
              );
        return BillingSnapshot(
          query: snapshot.query,
          overview: overview,
          subscriptions: snapshot.subscriptions,
          trials: snapshot.trials,
          failedPayments: snapshot.failedPayments,
          revenueByPlan: snapshot.revenueByPlan,
          revenueByCountry: snapshot.revenueByCountry,
          revenueCat: revenueCat,
          diagnostics: BillingDiagnostics(
            summarySource: 'control_get_billing_snapshot',
            revenueSource: revenueInstrumented ? BillingRevenueSource.unknown : BillingRevenueSource.none,
            sections: {
              'Overview': const BillingSectionStatus(state: BillingSectionState.partial, message: 'Legacy billing snapshot RPC is present, but detail tables are not wired in this build.', requiredSource: 'control_get_billing_snapshot'),
              'Subscriptions': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Subscriptions table is not instrumented yet.', requiredSource: 'admin_get_subscriptions_detail (RPC/view)'),
              'Trials': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Trials table is not instrumented yet.', requiredSource: 'admin_get_trials_detail (RPC/view)'),
              'Failed payments': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Failed payments table is not instrumented yet.', requiredSource: 'subscription_events + detail RPC'),
              'Revenue by plan': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Revenue by plan is not instrumented yet.', requiredSource: 'RevenueCat/Stripe revenue rollups'),
              'Revenue by country': const BillingSectionStatus(state: BillingSectionState.notInstrumented, message: 'Revenue by country is not instrumented yet.', requiredSource: 'RevenueCat/Stripe revenue rollups'),
            },
            dataSources: const [],
          ),
          generatedAt: snapshot.generatedAt,
        );
      }
    } catch (e) {
      debugPrint(
          'SupabaseAdminQueries.getBillingSummary legacy rpc failed: $e');
    }
    throw StateError(
        'Billing summary unavailable (no admin-safe RPC deployed).');
  }

  Future<RevenueCatSyncHealth?> _tryGetRevenueCatSyncHealth() async {
    final c = _client;
    try {
      // Prefer the small, aggregate-only view if present.
      final viewRow = await c.from('revenuecat_sync_health_v1').select().maybeSingle();

      int readInt(String k) {
        final v = viewRow?[k];
        if (v is num) return v.toInt();
        return int.tryParse((v ?? '0').toString()) ?? 0;
      }

      DateTime? readDt(String k) {
        final v = viewRow?[k];
        if (v == null) return null;
        if (v is DateTime) return v;
        return DateTime.tryParse(v.toString());
      }

      // Latest event processing result (safe string only).
      String? latestResult;
      DateTime? latestProcessed;
      DateTime? latestReceived;
      try {
        final latest = await c
            .from('revenuecat_webhook_events')
            .select('created_at, processed_at, processing_result')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        latestResult = latest?['processing_result']?.toString();
        latestProcessed = _tryParseDateTime(latest?['processed_at']);
        latestReceived = _tryParseDateTime(latest?['created_at']);
      } catch (e) {
        debugPrint('RevenueCatSyncHealth latest webhook fetch skipped: $e');
      }

      // Count entitlements rows + active subset (cap-based; small table expected).
      int entitlements = 0;
      int activeEntitlements = 0;
      final storeBreakdown = <String, int>{};
      try {
        final dynamic rows = await c
            .from('user_entitlements')
            .select('user_id, provider, store, status, subscription_status')
            .eq('provider', 'revenuecat')
            .limit(5000);
        if (rows is List) {
          entitlements = rows.length;
          for (final r in rows) {
            if (r is! Map) continue;
            final status = (r['status'] ?? r['subscription_status'] ?? '')
                .toString()
                .toLowerCase();
            if (status == 'active') {
              activeEntitlements++;
              final store = (r['store'] ?? 'unknown').toString().trim();
              storeBreakdown[store.isEmpty ? 'unknown' : store] =
                  (storeBreakdown[store.isEmpty ? 'unknown' : store] ?? 0) + 1;
            }
          }
        }
      } catch (e) {
        debugPrint('RevenueCatSyncHealth entitlements scan skipped: $e');
      }

      return RevenueCatSyncHealth(
        webhookEventRows: readInt('webhook_event_rows'),
        latestWebhookReceivedAt: latestReceived ?? readDt('latest_webhook_received_at'),
        latestWebhookProcessedAt: latestProcessed ?? readDt('latest_webhook_processed_at'),
        webhookFailedRows: readInt('webhook_failed_rows'),
        webhookUnmappedAppUserIdRows: readInt('webhook_unmapped_app_user_id_rows'),
        entitlementsRows: entitlements,
        activeEntitlementsRows: activeEntitlements,
        latestWebhookProcessingResult: latestResult,
        storeBreakdown: storeBreakdown,
      );
    } catch (e) {
      // View/table not deployed yet or blocked by RLS.
      debugPrint('RevenueCatSyncHealth unavailable: $e');
      return null;
    }
  }

  Future<UsageAnalyticsSnapshot> getUsageAnalyticsSummary(
      {required AdminUser admin, required UsageAnalyticsQuery query}) async {
    _requireRole(admin, AdminRbac.analytics,
        capability: 'usage_events_summary');

    final res = await _client.rpc(rpcUsageEventsSummary);
    if (res is! List)
      throw StateError('Unexpected usage summary RPC response.');
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
        conversions: const UsageOverviewConversions(
            signupToFirstProfile: 0,
            firstProfileToFirstUpload: 0,
            firstUploadToRecurring: 0,
            upgradePromptViews: 0,
            upgradeClicks: 0),
        featureUsage: const [],
        screenUsage: const [],
        funnels: const [],
        retention: const UsageRetentionSnapshot(
            day1: 0, day7: 0, day30: 0, weeklyRetention: 0),
        countryUsage: const [],
        platformUsage: const {},
        generatedAt: DateTime.now().toUtc(),
      );
    }

    int eventCountOf(Map<String, dynamic> r) =>
        (r['event_count'] as num?)?.toInt() ??
        (r['count'] as num?)?.toInt() ??
        0;
    int uniqueUsersOf(Map<String, dynamic> r) =>
        (r['unique_user_count'] as num?)?.toInt() ??
        (r['unique_users'] as num?)?.toInt() ??
        0;

    final totalEvents = rows.fold<int>(0, (a, r) => a + eventCountOf(r));

    final featureUsage = <UsageFeatureUsageRow>[];
    for (final r in rows.take(50)) {
      final name = (r['event_name'] ?? 'unknown').toString();
      final featureArea = (r['feature_area'] ?? '').toString().trim();
      final label = featureArea.isEmpty ? name : '$featureArea • $name';
      featureUsage.add(UsageFeatureUsageRow(
          feature: label,
          eventCount: eventCountOf(r),
          uniqueUsers: uniqueUsersOf(r)));
    }

    final platformUsage = <String, int>{};
    for (final r in rows) {
      final c = eventCountOf(r);
      final platform = (r['platform'] ?? '').toString().trim();
      if (platform.isNotEmpty)
        platformUsage[platform] = (platformUsage[platform] ?? 0) + c;
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
      conversions: const UsageOverviewConversions(
          signupToFirstProfile: 0,
          firstProfileToFirstUpload: 0,
          firstUploadToRecurring: 0,
          upgradePromptViews: 0,
          upgradeClicks: 0),
      featureUsage: featureUsage,
      screenUsage: const [],
      funnels: const [],
      retention: const UsageRetentionSnapshot(
          day1: 0, day7: 0, day30: 0, weeklyRetention: 0),
      countryUsage: countryUsage,
      platformUsage: platformUsage,
      generatedAt: DateTime.now().toUtc(),
    );
  }

  Future<List<CountryUsageRow>> _getCountryUsageSummary(
      {required AdminUser admin}) async {
    _requireRole(admin, AdminRbac.analytics,
        capability: 'country_usage_summary');
    try {
      final res = await _client.rpc('admin_get_country_usage_summary');
      if (res is! List) return const [];
      final rows =
          res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
      return rows
          .map(
            (r) => CountryUsageRow(
              country: (r['country'] ?? '—').toString(),
              totalUsers: (r['user_count'] as num?)?.toInt() ?? 0,
              activeUsers: (r['active_user_count'] as num?)?.toInt() ?? 0,
              storageUsedBytes:
                  ((r['storage_used_mb'] as num?)?.toInt() ?? 0) * 1048576,
              aiTokensUsed: (r['ai_tokens_used'] as num?)?.toInt() ?? 0,
              paidUsers: 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.totalUsers.compareTo(a.totalUsers));
    } catch (e) {
      debugPrint(
          'SupabaseAdminQueries._getCountryUsageSummary admin_get_country_usage_summary failed: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getPlanPermissionSummaryRows(
      {required AdminUser admin}) async {
    _requireRole(
        admin, <AdminRole>{AdminRole.owner, AdminRole.admin, AdminRole.billing},
        capability: 'plan_permission_summary');
    final res = await _client.rpc('admin_get_plan_permission_summary');
    if (res is! List) return const [];
    return res.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<List<FeatureFlagDefinition>> getFeatureFlags(
      {required AdminUser admin, required int limit}) async {
    _requireRole(admin, AdminRbac.all, capability: 'feature_flags');
    final rows = await _client
        .from('admin_feature_flags')
        .select('key, enabled, description, updated_at')
        .order('key')
        .limit(limit);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_featureFlagFromJson)
        .whereType<FeatureFlagDefinition>()
        .toList();
  }

  Future<Map<String, dynamic>?> getSupportSummaryRow(
      {required AdminUser admin}) async {
    _requireRole(admin, AdminRbac.support, capability: 'support_summary');
    final res = await _client.rpc('admin_get_support_summary');
    return _firstRpcRow(res);
  }

  Future<Map<String, dynamic>?> getAuditSummaryRow(
      {required AdminUser admin}) async {
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.compliance},
        capability: 'audit_summary');
    final res = await _client.rpc('admin_get_audit_summary');
    return _firstRpcRow(res);
  }

  Future<AdminQueryResult<Map<String, dynamic>?>> getSystemHealthSummaryRow(
      {required AdminUser admin}) async {
    _requireRole(admin, AdminRbac.analytics,
        capability: 'system_health_summary');
    try {
      final res = await _client.rpc(rpcSystemHealthSummary);
      final row = _firstRpcRow(res);
      return AdminQueryResult(name: rpcSystemHealthSummary, value: row);
    } catch (e) {
      debugPrint(
          'SupabaseAdminQueries.getSystemHealthSummaryRow admin_get_system_health_summary failed: $e');
      // Try v2 if deployed.
      final res = await _client.rpc(rpcSystemHealthSummaryV2);
      final row = _firstRpcRow(res);
      return AdminQueryResult(name: rpcSystemHealthSummaryV2, value: row);
    }
  }

  Future<ComplianceSnapshot> getComplianceRequests(
      {required AdminUser admin, required ComplianceQuery query}) async {
    _requireRole(admin, AdminRbac.compliance,
        capability: 'compliance_requests');

    try {
      final res = await _client.rpc('admin_get_compliance_summary');
      final row = _firstRpcRow(res);

      // If the compliance requests table isn't deployed, this RPC still returns a
      // row of zeros (by design). Treat that as “no data collected yet”, not an error.
      final open = (row?['open_requests'] as num?)?.toInt() ?? 0;
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
      debugPrint(
          'SupabaseAdminQueries.getComplianceRequests admin_get_compliance_summary failed: $e');
      rethrow;
    }
  }

  Future<List<SupportSessionSummary>> getSupportSessions(
      {required AdminUser admin,
      required SupportQueueQuery query,
      required int limit}) async {
    _requireRole(admin, AdminRbac.support, capability: 'support_sessions');
    try {
      final builder = _client.from('admin_support_sessions').select(
          'id, target_user_id, status, opened_by_admin_user_id, closed_at, ticket_id, created_at, updated_at');
      final rows =
          await builder.order('created_at', ascending: false).limit(limit);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_supportSessionSummaryFromAdminSessionJson)
          .toList();
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getSupportSessions failed: $e');
      rethrow;
    }
  }

  Future<SupportSessionDetail> getSupportSessionDetail(
      {required AdminUser admin, required String supportSessionId}) async {
    _requireRole(admin, AdminRbac.support,
        capability: 'support_session_detail');
    final row = await _rpcSingleRow(
      rpcSupportSessionDetail,
      params: {
        'p_support_session_id': supportSessionId,
        'p_include_email': AdminRbac.canViewUserEmail(admin.role)
      },
    );
    if (row == null) throw StateError('Support session detail unavailable.');
    return _supportSessionDetailFromJson(row);
  }

  Future<void> performSupportAction(
      {required AdminUser admin, required SupportActionRequest request}) async {
    _requireRole(admin, AdminRbac.support, capability: 'support_action');
    await _client.rpc(
      rpcPerformSupportAction,
      params: {
        'p_support_session_id': request.supportSessionId,
        'p_target_user_id': request.userId,
        'p_action': request.action.name,
        'p_reason': request.reason,
        'p_ticket_id': request.ticketReference,
        'p_parameters': request.parameters ?? const <String, dynamic>{},
      },
    );
  }

  Future<void> performComplianceAction(
      {required AdminUser admin,
      required ComplianceActionRequest request}) async {
    _requireRole(admin, AdminRbac.compliance, capability: 'compliance_action');
    await _client.rpc(
      rpcPerformComplianceAction,
      params: {
        'p_target_user_id': request.userId,
        'p_request_id': request.requestId,
        'p_action': request.action.name,
        'p_reason': request.reason,
        'p_ticket_id': request.ticketReference,
        'p_parameters': request.parameters ?? const <String, dynamic>{},
      },
    );
  }

  Future<List<AuditLogEntry>> getAuditLogs(
      {required AdminUser admin,
      required AuditLogQuery query,
      required int limit}) async {
    _requireRole(admin, <AdminRole>{AdminRole.owner, AdminRole.compliance},
        capability: 'audit_logs');

    try {
      var builder = _client
          .from('admin_audit_log')
          // Never select raw content beyond redacted maps.
          .select(
              'id, admin_user_id, target_user_id, action_type, prev, next, reason, ticket_id, ip, user_agent, result, created_at');

      if (query.actionType != null && query.actionType!.trim().isNotEmpty)
        builder = builder.eq('action_type', query.actionType!.trim());
      if (query.adminUserId != null && query.adminUserId!.trim().isNotEmpty)
        builder = builder.eq('admin_user_id', query.adminUserId!.trim());
      if (query.targetUserId != null && query.targetUserId!.trim().isNotEmpty)
        builder = builder.eq('target_user_id', query.targetUserId!.trim());
      if (query.result != null && query.result!.trim().isNotEmpty)
        builder = builder.eq('result', query.result!.trim());

      final rows =
          await builder.order('created_at', ascending: false).limit(limit);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(AuditLogEntry.fromJson)
          .toList();
    } catch (e) {
      debugPrint('SupabaseAdminQueries.getAuditLogs failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _rpcSingleRow(String functionName,
      {Map<String, dynamic>? params}) async {
    final res = await _client.rpc(functionName, params: params);
    return _firstRpcRow(res);
  }

  Map<String, dynamic>? _firstRpcRow(Object? res) {
    if (res is Map) return res.cast<String, dynamic>();
    if (res is List && res.isNotEmpty && res.first is Map) {
      return (res.first as Map).cast<String, dynamic>();
    }
    return null;
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

Map<String, dynamic> _billingQueryParams(BillingQuery q) =>
    {..._rangeParams(q.range)};

DashboardSnapshot _parseDashboardSnapshot(
    Map<String, dynamic> json, DashboardQuery query) {
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
    if (v == null)
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
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
          out.add(DashboardTimeseriesPoint(
              date: parseDate(d), value: parseInt(value)));
        }
      }
      out.sort((a, b) => a.date.compareTo(b.date));
      return out;
    }
    if (v is Map) {
      final out = <DashboardTimeseriesPoint>[];
      for (final e in v.entries) {
        out.add(DashboardTimeseriesPoint(
            date: parseDate(e.key), value: parseInt(e.value)));
      }
      out.sort((a, b) => a.date.compareTo(b.date));
      return out;
    }
    return const [];
  }

  Map<String, int> parseStringIntMap(dynamic v,
      {String keyField = 'key', String valueField = 'value'}) {
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
          final k =
              (m[keyField] ?? m['platform'] ?? m['feature'] ?? m['name'] ?? '')
                  .toString();
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
          country:
              (m['country'] ?? m['country_code'] ?? m['c'] ?? '—').toString(),
          totalUsers: parseInt(m['total_users'] ??
              m['totalUsers'] ??
              m['users_total'] ??
              m['users']),
          activeUsers: parseInt(m['active_users'] ??
              m['activeUsers'] ??
              m['users_active'] ??
              m['active']),
          storageUsedBytes: parseInt(m['storage_used_bytes'] ??
              m['storageUsedBytes'] ??
              m['storage_bytes']),
          aiTokensUsed: parseInt(
              m['ai_tokens_used'] ?? m['aiTokensUsed'] ?? m['ai_tokens']),
          paidUsers: parseInt(m['paid_users'] ??
              m['paidUsers'] ??
              m['users_paid'] ??
              m['paid']),
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
          type:
              (m['type'] ?? m['alert_type'] ?? m['name'] ?? 'Alert').toString(),
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
          label:
              (m['label'] ?? m['service'] ?? m['name'] ?? 'Service').toString(),
          status: (m['status'] ?? m['state'] ?? 'ok').toString(),
          detail: (m['detail'] ?? m['message'] ?? '').toString(),
          updatedAt: parseDate(
              m['updated_at'] ?? m['updatedAt'] ?? m['ts'] ?? m['timestamp']),
        ),
      );
    }
    return out;
  }

  return DashboardSnapshot(
    query: query,
    totalRegisteredUsers: parseInt(
        json['total_registered_users'] ?? json['totalRegisteredUsers']),
    newUsersThisWeek:
        parseInt(json['new_users_this_week'] ?? json['newUsersThisWeek']),
    newUsersThisMonth:
        parseInt(json['new_users_this_month'] ?? json['newUsersThisMonth']),
    dailyActiveUsers:
        parseInt(json['daily_active_users'] ?? json['dailyActiveUsers']),
    weeklyActiveUsers:
        parseInt(json['weekly_active_users'] ?? json['weeklyActiveUsers']),
    monthlyActiveUsers:
        parseInt(json['monthly_active_users'] ?? json['monthlyActiveUsers']),
    userGrowth: parseTimeseries(json['user_growth'] ??
        json['user_growth_daily'] ??
        json['registered_users_by_day'] ??
        json['users_over_time']),
    totalStorageUsedBytes: parseInt(
        json['total_storage_used_bytes'] ?? json['totalStorageUsedBytes']),
    averageStoragePerUserBytes: parseInt(
        json['average_storage_per_user_bytes'] ??
            json['averageStoragePerUserBytes']),
    usersNearStorageLimit: parseInt(
        json['users_near_storage_limit'] ?? json['usersNearStorageLimit']),
    aiTokensUsedThisMonth: parseInt(
        json['ai_tokens_used_this_month'] ?? json['aiTokensUsedThisMonth']),
    aiEstimatedCostThisMonthUsd: parseDouble(
        json['ai_estimated_cost_this_month_usd'] ??
            json['aiEstimatedCostThisMonthUsd']),
    usersNearAiLimit:
        parseInt(json['users_near_ai_limit'] ?? json['usersNearAiLimit']),
    freeUsers: parseInt(json['free_users'] ?? json['freeUsers']),
    trialUsers: parseInt(json['trial_users'] ?? json['trialUsers']),
    paidUsers: parseInt(json['paid_users'] ?? json['paidUsers']),
    cancelledUsers: parseInt(json['cancelled_users'] ?? json['cancelledUsers']),
    failedPayments: parseInt(json['failed_payments'] ?? json['failedPayments']),
    countryUsage: parseCountryUsage(json['country_usage'] ??
        json['countries'] ??
        json['country_breakdown']),
    platformUsage: parseStringIntMap(
        json['platform_usage'] ?? json['platforms'],
        keyField: 'platform',
        valueField: 'count'),
    featureUsage: parseStringIntMap(json['feature_usage'] ?? json['features'],
        keyField: 'feature', valueField: 'count'),
    alerts: parseAlerts(json['alerts'] ?? json['operational_alerts']),
    systemStatus: parseSystemStatus(json['system_status'] ?? json['services']),
    generatedAt: parseDate(json['generated_at'] ??
        json['generatedAt'] ??
        DateTime.now().toUtc().toIso8601String()),
  );
}

BillingSnapshot _parseBillingSnapshot(
        Map<String, dynamic> json, BillingQuery query) =>
    BillingSnapshot(
      query: query,
      overview: BillingOverviewMetrics(
        activePaidUsers: (json['active_paid_users'] as num?)?.toInt() ?? 0,
        freeUsers: (json['free_users'] as num?)?.toInt() ?? 0,
        trialUsers: (json['trial_users'] as num?)?.toInt() ?? 0,
        cancelledUsers: (json['cancelled_users'] as num?)?.toInt() ?? 0,
        failedPayments: (json['failed_payments'] as num?)?.toInt() ?? 0,
        monthlyRecurringRevenueUsd:
            (json['monthly_recurring_revenue_usd'] as num?)?.toDouble() ?? 0,
        annualRecurringRevenueUsd:
            (json['annual_recurring_revenue_usd'] as num?)?.toDouble() ?? 0,
        averageRevenuePerUserUsd:
            (json['average_revenue_per_user_usd'] as num?)?.toDouble() ?? 0,
        trialConversionRate:
            (json['trial_conversion_rate'] as num?)?.toDouble() ?? 0,
      ),
      subscriptions: const [],
      trials: const [],
      failedPayments: const [],
      revenueByPlan: const [],
      revenueByCountry: const [],
      revenueCat: null,
      generatedAt: DateTime.now().toUtc(),
    );

SupportSessionSummary _supportSessionSummaryFromAdminSessionJson(
    Map<String, dynamic> json) {
  final rawStatus = (json['status'] ?? '').toString();
  final status = switch (rawStatus) {
    'open' => SupportSessionStatus.active,
    'closed' => SupportSessionStatus.closed,
    _ => parseSupportSessionStatus(rawStatus) ?? SupportSessionStatus.pending,
  };
  return SupportSessionSummary(
    supportSessionId: (json['id'] ?? '').toString(),
    userId: (json['target_user_id'] ?? '').toString(),
    ticketReference: json['ticket_id']?.toString(),
    consentStatus:
        status == SupportSessionStatus.active ? 'on_file' : 'missing',
    status: status,
    assignedAdmin: json['opened_by_admin_user_id']?.toString(),
    createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
    accessExpiresAt: DateTime.tryParse((json['closed_at'] ?? '').toString()),
    updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
  );
}

UserAccountDetail _userAccountDetailFromJson(Map<String, dynamic> json) =>
    UserAccountDetail(
      userId: (json['user_id'] ?? '').toString(),
      email: json['email']?.toString(),
      country: (json['country'] ?? '—').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
      lastLoginAt: DateTime.tryParse((json['last_login_at'] ?? '').toString()),
      lastActiveAt:
          DateTime.tryParse((json['last_active_at'] ?? '').toString()),
      accountStatus: (json['account_status'] ?? 'unknown').toString(),
      plan: (json['plan'] ?? '—').toString(),
      billingStatus: (json['billing_status'] ?? 'unknown').toString(),
      subscriptionProvider:
          (json['subscription_provider'] ?? 'unknown').toString(),
      profileCount: (json['profile_count'] as num?)?.toInt() ?? 0,
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
      appointmentCount: (json['appointment_count'] as num?)?.toInt() ?? 0,
      medicationCount: (json['medication_count'] as num?)?.toInt() ?? 0,
      vaccinationCount: (json['vaccination_count'] as num?)?.toInt() ?? 0,
      documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
      storageUsedBytes: (json['storage_used_bytes'] as num?)?.toInt() ?? 0,
      aiTokensUsedThisMonth:
          (json['ai_tokens_used_this_month'] as num?)?.toInt() ?? 0,
      aiRequestsThisMonth:
          (json['ai_requests_this_month'] as num?)?.toInt() ?? 0,
      platform: (json['platform'] ?? '—').toString(),
      appVersion: (json['app_version'] ?? '—').toString(),
      lastSyncAt: DateTime.tryParse((json['last_sync_at'] ?? '').toString()),
      failedSyncCount30d: (json['failed_sync_count_30d'] as num?)?.toInt() ?? 0,
      failedUploadCount30d:
          (json['failed_upload_count_30d'] as num?)?.toInt() ?? 0,
      lastKnownErrorCode: json['last_known_error_code']?.toString(),
      deviceType: (json['device_type'] ?? '—').toString(),
      osVersion: (json['os_version'] ?? '—').toString(),
      storageLimitBytes: (json['storage_limit_bytes'] as num?)?.toInt() ?? 0,
      aiTokenLimitThisMonth:
          (json['ai_token_limit_this_month'] as num?)?.toInt() ?? 0,
      profileLimit: (json['profile_limit'] as num?)?.toInt() ?? 0,
      uploadLimit: (json['upload_limit'] as num?)?.toInt(),
      openSupportSessions:
          (json['open_support_sessions'] as num?)?.toInt() ?? 0,
      consentStatus: (json['consent_status'] ?? 'unknown').toString(),
      ticketReference: json['ticket_reference']?.toString(),
      supportNotes: json['support_notes']?.toString(),
    );

SupportSessionDetail _supportSessionDetailFromJson(Map<String, dynamic> json) =>
    SupportSessionDetail(
      supportSessionId: (json['support_session_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      email: json['email']?.toString(),
      accountStatus: (json['account_status'] ?? 'unknown').toString(),
      plan: (json['plan'] ?? '—').toString(),
      appVersion: (json['app_version'] ?? '—').toString(),
      platform: (json['platform'] ?? '—').toString(),
      country: (json['country'] ?? '—').toString(),
      lastLoginAt: DateTime.tryParse((json['last_login_at'] ?? '').toString()),
      lastSyncAt: DateTime.tryParse((json['last_sync_at'] ?? '').toString()),
      failedSyncCount: (json['failed_sync_count'] as num?)?.toInt() ?? 0,
      failedUploadCount: (json['failed_upload_count'] as num?)?.toInt() ?? 0,
      storageUsedBytes: (json['storage_used_bytes'] as num?)?.toInt() ?? 0,
      storageLimitBytes: (json['storage_limit_bytes'] as num?)?.toInt() ?? 0,
      aiTokensUsed: (json['ai_tokens_used'] as num?)?.toInt() ?? 0,
      aiLimit: (json['ai_limit'] as num?)?.toInt() ?? 0,
      openErrors: ((json['open_errors'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      recentTechnicalEvents: const [],
      adminNotes: json['admin_notes']?.toString(),
      consentWindowStatus:
          (json['consent_window_status'] ?? 'unknown').toString(),
      status: parseSupportSessionStatus((json['status'] ?? '').toString()) ??
          SupportSessionStatus.pending,
      accessExpiresAt:
          DateTime.tryParse((json['access_expires_at'] ?? '').toString()),
      ticketReference: json['ticket_reference']?.toString(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
      assignedAdmin: json['assigned_admin']?.toString(),
    );

DiagnosticCheck _diagnosticCheckFromJson(Map<String, dynamic> json) {
  final status = switch ((json['status'] ?? '').toString()) {
    'pass' => DiagnosticStatus.pass,
    'fail' => DiagnosticStatus.fail,
    _ => DiagnosticStatus.warning,
  };
  return DiagnosticCheck(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? 'Diagnostic check').toString(),
    status: status,
    explanation: (json['explanation'] ?? '').toString(),
    suggestedAction: (json['suggested_action'] ?? '').toString(),
  );
}

FeatureFlagDefinition? _featureFlagFromJson(Map<String, dynamic> json) {
  final key = _featureFlagKeyFromApiKey((json['key'] ?? '').toString());
  if (key == null) return null;
  return FeatureFlagDefinition(
    key: key,
    enabled: json['enabled'] == true,
    description: (json['description'] ?? '').toString(),
    updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
  );
}

FeatureFlagKey? _featureFlagKeyFromApiKey(String raw) {
  final normalized = raw.trim();
  for (final key in FeatureFlagKey.values) {
    if (key.apiKey == normalized) return key;
  }
  return null;
}

/// Aggregate-only usage events (privacy-safe).
@immutable
class UsageEventAggregateRow {
  const UsageEventAggregateRow(
      {required this.eventName,
      required this.eventCategory,
      required this.count,
      required this.uniqueUsers,
      required this.day});

  final String eventName;
  final String eventCategory;
  final int count;
  final int uniqueUsers;
  final DateTime day;

  static UsageEventAggregateRow fromJson(Map<String, dynamic> json) =>
      UsageEventAggregateRow(
        eventName: (json['event_name'] ?? '').toString(),
        eventCategory: (json['event_category'] ?? '').toString(),
        count: (json['count'] as num?)?.toInt() ?? 0,
        uniqueUsers: (json['unique_users'] as num?)?.toInt() ?? 0,
        day: DateTime.tryParse((json['day'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
      );
}

/// Query for aggregate-only usage events.
@immutable
class UsageEventsQuery {
  const UsageEventsQuery(
      {required this.start,
      required this.end,
      this.country,
      this.platform,
      this.plan,
      this.appVersion});

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
  const UserUsageSummary(
      {required this.userId,
      required this.events30d,
      required this.sessions30d,
      required this.lastSeenAt,
      required this.storageUsedBytes,
      required this.aiRequests30d,
      required this.aiTokens30d});

  final String userId;
  final int events30d;
  final int sessions30d;
  final DateTime? lastSeenAt;
  final int storageUsedBytes;
  final int aiRequests30d;
  final int aiTokens30d;

  static UserUsageSummary fromJson(Map<String, dynamic> json) =>
      UserUsageSummary(
        userId: (json['user_id'] ?? '').toString(),
        events30d: (json['events_30d'] as num?)?.toInt() ?? 0,
        sessions30d: (json['sessions_30d'] as num?)?.toInt() ?? 0,
        lastSeenAt: DateTime.tryParse((json['last_seen_at'] ?? '').toString()),
        storageUsedBytes: (json['storage_used_bytes'] as num?)?.toInt() ?? 0,
        aiRequests30d: (json['ai_requests_30d'] as num?)?.toInt() ?? 0,
        aiTokens30d: (json['ai_tokens_30d'] as num?)?.toInt() ?? 0,
      );
}

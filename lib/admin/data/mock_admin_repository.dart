import 'dart:math';

import 'package:curavault_admin/admin/data/admin_repository.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/utils/audit_redactor.dart';
import 'package:curavault_admin/admin/utils/client_context.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAdminRepository implements AdminRepository {
  MockAdminRepository({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;
  final _rng = Random(7);

  final List<AuditLogEntry> _auditLogs = [];

  late final List<SupportSessionSummary> _supportSessions = _buildSupportSessions();
  late final List<FeatureFlagDefinition> _featureFlags = _buildFeatureFlags();
  late final List<LimitOverrideRow> _limitOverrides = _buildLimitOverrides();

  late final List<DataExportRequestRow> _exportRequests = _buildExportRequests();
  late final List<DeletionRequestRow> _deletionRequests = _buildDeletionRequests();
  late final List<ConsentRecordRow> _consentRecords = _buildConsentRecords();
  late final List<SupportAccessRecordRow> _supportAccessRecords = _buildSupportAccessRecords();
  late final List<PrivacyTermsAcceptanceRow> _policyAcceptances = _buildPolicyAcceptances();

  static String _pseudonymize(String raw) {
    // Deterministic, non-reversible pseudonym for UI tables.
    var h = 2166136261;
    for (final c in raw.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0x7fffffff;
    }
    return 'p_${h.toRadixString(16).padLeft(8, '0')}';
  }

  ServiceHealthStatus _randomStatus({double healthyBias = 0.82}) {
    final r = _rng.nextDouble();
    if (r < healthyBias) return ServiceHealthStatus.healthy;
    if (r < healthyBias + 0.14) return ServiceHealthStatus.degraded;
    if (r < healthyBias + 0.18) return ServiceHealthStatus.down;
    return ServiceHealthStatus.unknown;
  }

  List<FeatureFlagDefinition> _buildFeatureFlags() {
    final t = _now;
    return [
      FeatureFlagDefinition(key: FeatureFlagKey.aiAssistant, enabled: true, description: 'Enable AI assistant surfaces (no content exposure in control site).', updatedAt: t.subtract(const Duration(days: 2))),
      FeatureFlagDefinition(key: FeatureFlagKey.documentUploads, enabled: true, description: 'Allow document uploads in consumer app.', updatedAt: t.subtract(const Duration(days: 5))),
      FeatureFlagDefinition(key: FeatureFlagKey.export, enabled: true, description: 'Enable exports (consumer app + compliance workflows).', updatedAt: t.subtract(const Duration(days: 7))),
      FeatureFlagDefinition(key: FeatureFlagKey.timeline, enabled: true, description: 'Timeline UI module.', updatedAt: t.subtract(const Duration(days: 9))),
      FeatureFlagDefinition(key: FeatureFlagKey.bodyMap, enabled: false, description: 'Body map module (gated beta).', updatedAt: t.subtract(const Duration(days: 3))),
      FeatureFlagDefinition(key: FeatureFlagKey.familyProfiles, enabled: true, description: 'Family profiles feature.', updatedAt: t.subtract(const Duration(days: 14))),
      FeatureFlagDefinition(key: FeatureFlagKey.preventativeCare, enabled: false, description: 'Preventative care insights module.', updatedAt: t.subtract(const Duration(days: 10))),
      FeatureFlagDefinition(key: FeatureFlagKey.betaFeatures, enabled: true, description: 'General beta access (UI gated).', updatedAt: t.subtract(const Duration(days: 1))),
    ];
  }

  List<LimitOverrideRow> _buildLimitOverrides() {
    final t = _now;
    return [
      LimitOverrideRow(
        overrideId: 'ovr_1001',
        userId: 'usr_100012',
        planName: 'premium',
        limitKey: 'storage_limit_bytes',
        previousValue: '15 GB',
        newValue: '25 GB',
        reason: 'Goodwill extension for sync regressions',
        ticketReference: 'SUP-9021',
        createdAt: t.subtract(const Duration(days: 3)),
        updatedAt: t.subtract(const Duration(days: 3)),
        expiresAt: t.add(const Duration(days: 27)),
      ),
      LimitOverrideRow(
        overrideId: 'ovr_1002',
        userId: 'usr_100044',
        planName: 'family',
        limitKey: 'ai_token_limit_monthly',
        previousValue: '1,000,000',
        newValue: '1,750,000',
        reason: 'Temporarily increase AI limit for onboarding support',
        ticketReference: null,
        createdAt: t.subtract(const Duration(days: 8)),
        updatedAt: t.subtract(const Duration(days: 7)),
        expiresAt: null,
      ),
    ];
  }

  List<SupportSessionSummary> _buildSupportSessions() {
    final t = _now;
    final statuses = SupportSessionStatus.values;
    return List.generate(28, (i) {
      final status = statuses[i % statuses.length];
      final created = t.subtract(Duration(hours: 2 + (i * 7)));
      final expires = switch (status) {
        SupportSessionStatus.active => created.add(const Duration(minutes: 45)),
        SupportSessionStatus.pending => created.add(const Duration(minutes: 20)),
        SupportSessionStatus.expired => created.add(const Duration(minutes: 15)),
        SupportSessionStatus.closed => created.add(const Duration(minutes: 30)),
        SupportSessionStatus.revoked => created.add(const Duration(minutes: 30)),
      };
      return SupportSessionSummary(
        supportSessionId: 'ss_${2000 + i}',
        userId: 'usr_${(100000 + (i % 30)).toString()}',
        email: (i % 3 == 0) ? 'user${i % 30}@example.com' : null,
        ticketReference: (i % 4 == 0) ? 'SUP-${9000 + i}' : null,
        consentStatus: (i % 9 == 0) ? 'missing' : (i % 7 == 0) ? 'revoked' : 'on_file',
        status: status,
        assignedAdmin: (i % 5 == 0) ? 'admin_01' : (i % 2 == 0) ? 'admin_03' : null,
        createdAt: created,
        accessExpiresAt: expires,
        updatedAt: created.add(Duration(minutes: 2 + (i % 18))),
      );
    });
  }

  List<DataExportRequestRow> _buildExportRequests() {
    final t = _now;
    return List.generate(34, (i) {
      final status = switch (i % 5) {
        0 => ComplianceRequestStatus.open,
        1 => ComplianceRequestStatus.inProgress,
        2 => ComplianceRequestStatus.completed,
        3 => ComplianceRequestStatus.failed,
        _ => ComplianceRequestStatus.open,
      };
      final requested = t.subtract(Duration(days: 1 + (i % 25), hours: i % 18));
      final completedAt = (status == ComplianceRequestStatus.completed) ? requested.add(Duration(hours: 5 + (i % 10))) : null;
      final failureReason = (status == ComplianceRequestStatus.failed) ? (i % 2 == 0 ? 'Upstream job timeout' : 'Missing verification step') : null;
      return DataExportRequestRow(
        requestId: 'exp_${9000 + i}',
        userId: 'usr_${100000 + (i % 80)}',
        email: (i % 4 == 0) ? 'export_user_${i % 80}@example.com' : null,
        status: status,
        requestedAt: requested,
        completedAt: completedAt,
        verifiedBy: (status == ComplianceRequestStatus.completed) ? ((i % 3 == 0) ? 'admin_01' : 'admin_09') : null,
        failureReason: failureReason,
        notes: (i % 7 == 0) ? 'User requested export for portability.' : null,
      );
    })..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  List<DeletionRequestRow> _buildDeletionRequests() {
    final t = _now;
    return List.generate(28, (i) {
      final status = switch (i % 6) {
        0 => ComplianceRequestStatus.open,
        1 => ComplianceRequestStatus.inProgress,
        2 => ComplianceRequestStatus.completed,
        3 => ComplianceRequestStatus.completed,
        4 => ComplianceRequestStatus.failed,
        _ => ComplianceRequestStatus.open,
      };
      final requested = t.subtract(Duration(days: 2 + (i % 35), hours: (i * 3) % 24));
      final completedAt = (status == ComplianceRequestStatus.completed) ? requested.add(Duration(days: 1 + (i % 4))) : null;
      final retentionException = (i % 11 == 0);
      final failedReason = (status == ComplianceRequestStatus.failed) ? (retentionException ? 'Retention exception: billing dispute hold' : 'Workflow job failed') : null;
      return DeletionRequestRow(
        requestId: 'del_${7000 + i}',
        userId: 'usr_${100050 + (i % 90)}',
        email: (i % 5 == 0) ? 'delete_user_${i % 90}@example.com' : null,
        status: status,
        requestedAt: requested,
        completedAt: completedAt,
        failedReason: failedReason,
        retentionException: retentionException,
        verifiedBy: (status == ComplianceRequestStatus.completed) ? ((i % 3 == 0) ? 'admin_01' : 'admin_09') : null,
      );
    })..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  List<ConsentRecordRow> _buildConsentRecords() {
    final t = _now;
    final types = const ['support_access', 'terms', 'privacy_policy', 'analytics_opt_in'];
    final sources = const ['in_app', 'web', 'support_flow'];
    final countries = const ['US', 'CA', 'GB', 'DE', 'AU', 'SG'];
    return List.generate(60, (i) {
      final accepted = t.subtract(Duration(days: _rng.nextInt(120), hours: _rng.nextInt(24)));
      final revoked = (_rng.nextDouble() < 0.08) ? accepted.add(Duration(days: 2 + _rng.nextInt(25))) : null;
      return ConsentRecordRow(
        userId: 'usr_${100000 + (i % 120)}',
        consentType: types[i % types.length],
        version: 'v${1 + (i % 3)}.${_rng.nextInt(8)}',
        acceptedAt: accepted,
        revokedAt: revoked,
        source: sources[i % sources.length],
        country: countries[(i * 7) % countries.length],
      );
    })..sort((a, b) => b.acceptedAt.compareTo(a.acceptedAt));
  }

  List<SupportAccessRecordRow> _buildSupportAccessRecords() {
    final t = _now;
    final statuses = const ['pending', 'active', 'expired', 'closed', 'revoked'];
    return List.generate(40, (i) {
      final status = statuses[i % statuses.length];
      final granted = status == 'active' || status == 'expired' || status == 'closed';
      final grantedAt = granted ? t.subtract(Duration(hours: 1 + (i * 9))) : null;
      final expiresAt = (status == 'active' || status == 'expired') ? (grantedAt?.add(const Duration(minutes: 45))) : null;
      return SupportAccessRecordRow(
        userId: 'usr_${100000 + (i % 90)}',
        adminUser: (i % 3 == 0) ? 'admin_01' : (i % 2 == 0) ? 'admin_03' : 'admin_09',
        consentGranted: granted,
        consentGrantedAt: grantedAt,
        accessExpiresAt: expiresAt,
        status: status,
        ticketReference: (i % 4 == 0) ? 'SUP-${9100 + i}' : null,
      );
    });
  }

  List<PrivacyTermsAcceptanceRow> _buildPolicyAcceptances() {
    final t = _now;
    final countries = const ['US', 'CA', 'GB', 'DE', 'AU', 'SG'];
    return List.generate(80, (i) {
      final accepted = t.subtract(Duration(days: _rng.nextInt(220), hours: _rng.nextInt(24)));
      return PrivacyTermsAcceptanceRow(
        userId: 'usr_${99000 + i}',
        privacyPolicyVersion: '2025.${1 + (i % 6)}',
        termsVersion: '2025.${1 + ((i + 2) % 6)}',
        acceptedAt: accepted,
        country: countries[i % countries.length],
      );
    })..sort((a, b) => b.acceptedAt.compareTo(a.acceptedAt));
  }

  @override
  Future<AdminUser> getCurrentAdmin() async {
    final t = _now;
    return AdminUser(
      id: 'admin_01',
      email: 'admin@curavault.internal',
      displayName: 'Mock Admin',
      role: AdminRole.support,
      isActive: true,
      requireStepUp: false,
      createdAt: t.subtract(const Duration(days: 90)),
      updatedAt: t,
    );
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _insertAuditRowToSupabase(Map<String, dynamic> row) async {
    final c = _client;
    if (c == null) return;
    try {
      await c.from('admin_audit_log').insert(row);
    } catch (e) {
      debugPrint('MockAdminRepository audit insert failed: $e');
      // Fail-closed: if audit logging is unavailable, the associated admin
      // action must be considered failed.
      throw StateError('Audit log write failed');
    }
  }

  @override
  Future<void> createAuditLog({required AdminAuditLogCreate entry}) async {
    final now = DateTime.now();
    final redactedPrev = AdminAuditRedactor.redactMap(entry.previousValue);
    final redactedNew = AdminAuditRedactor.redactMap(entry.newValue);

    final row = {
      ...entry.toInsertJson(),
      if (redactedPrev != null) 'prev': redactedPrev,
      if (redactedNew != null) 'next': redactedNew,
      if (entry.ipAddress == null && AdminClientContext.ipAddress != null) 'ip': AdminClientContext.ipAddress,
      if (entry.userAgent == null && AdminClientContext.userAgent != null) 'user_agent': AdminClientContext.userAgent,
      'created_at': now.toUtc().toIso8601String(),
    };

    _auditLogs.insert(
      0,
      AuditLogEntry(
        id: 'audit_${now.microsecondsSinceEpoch}',
        adminUserId: entry.adminUserId,
        targetUserId: entry.targetUserId,
        actionType: entry.actionType,
        previousValue: redactedPrev,
        newValue: redactedNew,
        reason: entry.reason,
        ticketReference: entry.ticketReference,
        ipAddress: row['ip']?.toString(),
        userAgent: row['user_agent']?.toString(),
        result: entry.result,
        createdAt: now,
      ),
    );

    await _insertAuditRowToSupabase(row);
  }

  @override
  Future<SystemHealthSnapshot> getSystemHealthSnapshot({required SystemHealthQuery query}) async {
    final t = _now;

    final api = _randomStatus(healthyBias: 0.86);
    final db = _randomStatus(healthyBias: 0.90);
    final storage = _randomStatus(healthyBias: 0.80);
    final auth = _randomStatus(healthyBias: 0.92);
    final ai = _randomStatus(healthyBias: 0.84);

    final overview = SystemOverviewMetrics(
      apiStatus: api,
      databaseStatus: db,
      storageStatus: storage,
      authStatus: auth,
      aiServiceStatus: ai,
      lastSuccessfulScheduledJob: t.subtract(Duration(minutes: 14 + _rng.nextInt(90))),
      errorRateLast24h: (0.002 + _rng.nextDouble() * 0.014).clamp(0.0, 1.0),
      failedUploadsLast24h: 8 + _rng.nextInt(120),
      failedSyncsLast24h: 5 + _rng.nextInt(90),
    );

    final endpoints = <String>[
      'auth.session.refresh',
      'profiles.list',
      'documents.upload.init',
      'documents.upload.complete',
      'records.sync.pull',
      'records.sync.push',
      'ai.proxy.chat',
      'billing.subscription.status',
      'compliance.export.request',
    ].map((name) {
      final req = 500 + _rng.nextInt(9000);
      final err = _rng.nextInt(max(1, (req * 0.02).round()));
      final avg = 70 + _rng.nextInt(420);
      final p95 = avg + 90 + _rng.nextInt(900);
      final status = (err / req) > 0.03 ? ServiceHealthStatus.degraded : ServiceHealthStatus.healthy;
      final lastFail = (err > 0 && _rng.nextDouble() < 0.75) ? t.subtract(Duration(minutes: 10 + _rng.nextInt(700))) : null;
      return ApiHealthEndpointRow(endpointName: name, requestCount: req, errorCount: err, avgLatencyMs: avg, p95LatencyMs: p95, lastFailureAt: lastFail, status: status);
    }).toList()
      ..sort((a, b) => b.errorCount.compareTo(a.errorCount));

    final syncMetrics = SyncHealthMetrics(
      successfulSyncs: 12000 + _rng.nextInt(40000),
      failedSyncs: 45 + _rng.nextInt(850),
      usersWithRepeatedSyncFailure: 3 + _rng.nextInt(80),
      avgSyncDurationMs: 620 + _rng.nextInt(1800),
      lastSyncJobStatus: (_rng.nextDouble() < 0.88) ? 'success' : 'degraded',
    );

    final uploadAttempts = 8000 + _rng.nextInt(25000);
    final failureRate = (0.01 + _rng.nextDouble() * 0.05).clamp(0.0, 1.0);
    final uploadMetrics = UploadHealthMetrics(
      uploadAttempts: uploadAttempts,
      uploadSuccessRate: (1 - failureRate).clamp(0.0, 1.0),
      uploadFailureRate: failureRate,
      averageUploadSizeBucket: ['<1MB', '1–5MB', '5–25MB', '25–100MB'][_rng.nextInt(4)],
      storageErrors: 5 + _rng.nextInt(90),
      permissionErrors: 1 + _rng.nextInt(40),
      timeoutErrors: 6 + _rng.nextInt(120),
    );

    final aiReq = 25000 + _rng.nextInt(150000);
    final aiFailure = (0.004 + _rng.nextDouble() * 0.02).clamp(0.0, 1.0);
    final aiMetrics = AiServiceHealthMetrics(
      aiRequests: aiReq,
      aiSuccessRate: (1 - aiFailure).clamp(0.0, 1.0),
      aiFailureRate: aiFailure,
      averageLatencyMs: 380 + _rng.nextInt(1400),
      errorCodes: {
        'rate_limited': 20 + _rng.nextInt(260),
        'upstream_timeout': 6 + _rng.nextInt(130),
        'invalid_request': 2 + _rng.nextInt(45),
        'provider_5xx': 3 + _rng.nextInt(90),
      },
      rateLimitEvents: 25 + _rng.nextInt(400),
    );

    final versions = <List<String>>[
      const ['1.9.2', 'iOS'],
      const ['1.9.2', 'Android'],
      const ['1.9.1', 'iOS'],
      const ['1.9.1', 'Android'],
      const ['1.8.9', 'iOS'],
      const ['1.8.9', 'Android'],
    ].map((v) {
      final active = 250 + _rng.nextInt(6000);
      final errRate = (0.001 + _rng.nextDouble() * 0.03).clamp(0.0, 1.0);
      final failedUp = (errRate * active * 0.25).round() + _rng.nextInt(12);
      final failedSy = (errRate * active * 0.20).round() + _rng.nextInt(10);
      final recommend = v[0] == '1.8.9' || errRate > 0.018;
      return AppVersionHealthRow(appVersion: v[0], platform: v[1], activeUsers: active, errorRate: errRate, failedUploads: failedUp, failedSyncs: failedSy, upgradeRecommended: recommend);
    }).toList()
      ..sort((a, b) => b.activeUsers.compareTo(a.activeUsers));

    final featureAreas = const ['auth', 'sync', 'upload', 'ai', 'billing', 'compliance', 'notifications', 'onboarding'];
    final platforms = const ['iOS', 'Android', 'Web'];
    final errorCodes = const ['E_AUTH_401', 'E_SYNC_CONFLICT', 'E_UPLOAD_TIMEOUT', 'E_STORAGE_QUOTA', 'E_AI_RATE_LIMIT', 'E_AI_UPSTREAM', 'E_DB_TIMEOUT', 'E_NETWORK'];
    final results = const ['recovered', 'retrying', 'failed'];

    final logs = List.generate(60, (i) {
      final severity = switch (i % 10) {
        0 => SystemErrorSeverity.critical,
        1 => SystemErrorSeverity.error,
        2 => SystemErrorSeverity.error,
        3 => SystemErrorSeverity.warning,
        _ => SystemErrorSeverity.info,
      };
      final ts = t.subtract(Duration(minutes: 8 + (i * (2 + _rng.nextInt(8)))));
      final platform = platforms[(i + 1) % platforms.length];
      final appV = (platform == 'Web') ? 'web' : (i % 4 == 0 ? '1.8.9' : (i % 2 == 0 ? '1.9.1' : '1.9.2'));
      return SystemErrorLogRow(
        timestamp: ts,
        errorCode: errorCodes[(i * 3) % errorCodes.length],
        featureArea: featureAreas[(i * 5) % featureAreas.length],
        platform: platform,
        appVersion: appV,
        userIdPseudonym: _pseudonymize('usr_${100000 + (i % 180)}'),
        result: results[(i + 2) % results.length],
        severity: severity,
      );
    })..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return SystemHealthSnapshot(
      query: query,
      overview: overview,
      apiEndpoints: endpoints,
      sync: syncMetrics,
      upload: uploadMetrics,
      ai: aiMetrics,
      appVersions: versions,
      errorLogs: logs,
      generatedAt: t,
    );
  }

  @override
  Future<List<UserAccountSummary>> listUsers({required UserListQuery query, required int limit}) async {
    final t = _now;
    final base = List.generate(
      max(30, limit),
      (i) {
        final used = _rng.nextInt(12 * 1024 * 1024 * 1024);
        final limitBytes = 15 * 1024 * 1024 * 1024;
        final plan = (i % 4 == 0)
            ? 'Enterprise'
            : (i % 4 == 1)
            ? 'Team'
            : (i % 4 == 2)
            ? 'Pro'
            : 'Free';
        final status = (i % 11 == 0) ? 'suspended' : (i % 7 == 0) ? 'locked' : 'active';
         final aiLimit = switch (plan) {
           'Enterprise' => 5000000,
           'Team' => 2000000,
           'Pro' => 1000000,
           _ => 200000,
         };
         return UserAccountSummary(
          userId: 'usr_${(100000 + i).toString()}',
          email: (i % 3 == 0) ? 'user$i@example.com' : null,
          country: ['US', 'CA', 'GB', 'DE', 'AU', 'SG'][i % 6],
          plan: plan,
          accountStatus: status,
          storageUsedBytes: used,
          storageLimitBytes: limitBytes,
          aiTokensThisMonth: 5000 + _rng.nextInt(800000),
           aiTokenLimitThisMonth: aiLimit,
          profileCount: 1 + _rng.nextInt(4),
          recordCount: 5 + _rng.nextInt(120),
          documentCount: 0 + _rng.nextInt(50),
          appointmentCount: 0 + _rng.nextInt(60),
          medicationCount: 0 + _rng.nextInt(30),
          vaccinationCount: 0 + _rng.nextInt(25),
          lastSyncAt: t.subtract(Duration(hours: _rng.nextInt(24 * 15))),
           lastActiveAt: t.subtract(Duration(hours: _rng.nextInt(24 * 7))),
          platform: ['iOS', 'Android', 'Web'][i % 3],
          appVersion: ['2.6.1', '2.7.0', '2.7.1'][i % 3],
           failedSyncCount7d: _rng.nextInt(12),
           failedUploadCount7d: _rng.nextInt(10),
           lastKnownErrorCode: (i % 8 == 0) ? 'SYNC_TIMEOUT' : null,
           billingStatus: (i % 5 == 0) ? 'past_due' : 'active',
           subscriptionProvider: (i % 4 == 0) ? 'apple' : (i % 4 == 1) ? 'google' : (i % 4 == 2) ? 'stripe' : 'none',
          createdAt: t.subtract(Duration(days: 365 - i)),
          updatedAt: t.subtract(Duration(hours: i)),
        );
      },
    );

    final q = query.search.trim().toLowerCase();
    var filtered = q.isEmpty
        ? base
        : base.where((u) => u.userId.toLowerCase().contains(q) || (u.email?.toLowerCase().contains(q) ?? false)).toList();

    final f = query.filters;
    if (f.country != null) filtered = filtered.where((u) => u.country == f.country).toList();
    if (f.plan != null) filtered = filtered.where((u) => u.plan == f.plan).toList();
    if (f.accountStatus != null) filtered = filtered.where((u) => u.accountStatus == f.accountStatus).toList();
    if (f.platform != null) filtered = filtered.where((u) => u.platform == f.platform).toList();
    if (f.storageNearLimit == true) {
      filtered = filtered.where((u) => u.storageLimitBytes > 0 && (u.storageUsedBytes / u.storageLimitBytes) >= 0.85).toList();
    }
    if (f.aiNearLimit == true) {
      filtered = filtered.where((u) => u.aiTokenLimitThisMonth > 0 && (u.aiTokensThisMonth / u.aiTokenLimitThisMonth) >= 0.85).toList();
    }
    if (f.failedSyncs == true) filtered = filtered.where((u) => u.failedSyncCount7d > 0).toList();
    if (f.failedUploads == true) filtered = filtered.where((u) => u.failedUploadCount7d > 0).toList();
    if (f.billingFailed == true) filtered = filtered.where((u) => u.billingStatus == 'past_due').toList();
    if (f.createdRange != null) {
      filtered = filtered.where((u) => !u.createdAt.isBefore(f.createdRange!.start) && !u.createdAt.isAfter(f.createdRange!.end)).toList();
    }
    if (f.lastActiveRange != null) {
      filtered = filtered.where((u) {
        final la = u.lastActiveAt;
        if (la == null) return false;
        return !la.isBefore(f.lastActiveRange!.start) && !la.isAfter(f.lastActiveRange!.end);
      }).toList();
    }

    return filtered.take(limit).toList();
  }

  @override
  Future<UserAccountDetail> getUserDetail({required String userId}) async {
    // Start from the same safe summary as listUsers, then expand with additional
    // non-health diagnostics.
    final list = await listUsers(query: const UserListQuery(search: '', filters: UserListFilters()), limit: 200);
    final u = list.firstWhere((x) => x.userId == userId, orElse: () => list.first);
    final now = _now;
    return UserAccountDetail(
      userId: u.userId,
      email: u.email,
      country: u.country,
      createdAt: u.createdAt,
      lastLoginAt: now.subtract(Duration(hours: 1 + _rng.nextInt(24 * 30))),
      lastActiveAt: u.lastActiveAt,
      accountStatus: u.accountStatus,
      plan: u.plan,
      billingStatus: u.billingStatus,
      subscriptionProvider: u.subscriptionProvider,
      profileCount: u.profileCount,
      recordCount: u.recordCount,
      appointmentCount: u.appointmentCount,
      medicationCount: u.medicationCount,
      vaccinationCount: u.vaccinationCount,
      documentCount: u.documentCount,
      storageUsedBytes: u.storageUsedBytes,
      aiTokensUsedThisMonth: u.aiTokensThisMonth,
      aiRequestsThisMonth: (u.aiTokensThisMonth / 3500).round(),
      platform: u.platform,
      appVersion: u.appVersion,
      lastSyncAt: u.lastSyncAt,
      failedSyncCount30d: u.failedSyncCount7d + _rng.nextInt(15),
      failedUploadCount30d: u.failedUploadCount7d + _rng.nextInt(12),
      lastKnownErrorCode: u.lastKnownErrorCode,
      deviceType: ['Phone', 'Tablet', 'Desktop'][_rng.nextInt(3)],
      osVersion: switch (u.platform) {
        'iOS' => 'iOS 17.x',
        'Android' => 'Android 14.x',
        _ => 'Web',
      },
      storageLimitBytes: u.storageLimitBytes,
      aiTokenLimitThisMonth: u.aiTokenLimitThisMonth,
      profileLimit: switch (u.plan) {
        'Enterprise' => 50,
        'Team' => 20,
        'Pro' => 10,
        _ => 3,
      },
      uploadLimit: null,
      openSupportSessions: (u.failedSyncCount7d > 0 || u.failedUploadCount7d > 0) ? 1 : 0,
      consentStatus: 'on_file',
      ticketReference: (u.billingStatus == 'past_due') ? 'BILL-${1000 + _rng.nextInt(900)}' : null,
      supportNotes: (u.failedSyncCount7d > 3) ? 'User reports intermittent background sync failures.' : null,
    );
  }

  // ------------------------------
  // AI usage
  // ------------------------------

  @override
  Future<AiUsageSnapshot> getAiUsageSnapshot({required AiUsageQuery query}) async {
    final days = query.range.days;
    final end = DateTime(_now.year, _now.month, _now.day);
    final start = end.subtract(Duration(days: days - 1));
    final featureAreas = AiFeatureArea.values;

    // Build daily tokens
    final tokensByDay = <AiTokensTimeseriesPoint>[];
    var totalInput = 0;
    var totalOutput = 0;
    for (var i = 0; i < days; i++) {
      final d = start.add(Duration(days: i));
      final base = 250000 + _rng.nextInt(180000);
      final weekdayFactor = (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) ? 0.72 : 1.0;
      final input = (base * 0.55 * weekdayFactor).round();
      final output = (base * 0.45 * weekdayFactor).round();
      totalInput += input;
      totalOutput += output;
      tokensByDay.add(AiTokensTimeseriesPoint(day: d, inputTokens: input, outputTokens: output));
    }

    // Requests: assume ~3.3k tokens/request average, with noise.
    final totalTokens = totalInput + totalOutput;
    final aiRequests = max(1, (totalTokens / (2800 + _rng.nextInt(1400))).round());
    final failed = max(0, (aiRequests * (0.02 + (_rng.nextDouble() * 0.03))).round());

    // Feature breakdown
    final tokensByFeature = <AiFeatureArea, int>{};
    var remaining = totalTokens;
    for (var i = 0; i < featureAreas.length; i++) {
      final f = featureAreas[i];
      final share = i == featureAreas.length - 1 ? remaining : max(0, (totalTokens * (0.08 + _rng.nextDouble() * 0.18)).round());
      final v = min(remaining, share);
      tokensByFeature[f] = v;
      remaining -= v;
    }

    final tokensByPlan = <String, int>{
      'Free': (totalTokens * 0.22).round(),
      'Pro': (totalTokens * 0.36).round(),
      'Team': (totalTokens * 0.26).round(),
      'Enterprise': (totalTokens * 0.16).round(),
    };

    final tokensByPlatform = <String, int>{
      'iOS': (totalTokens * 0.48).round(),
      'Android': (totalTokens * 0.42).round(),
      'Web': (totalTokens * 0.10).round(),
    };

    final tokensByCountry = <String, int>{
      'US': (totalTokens * 0.44).round(),
      'CA': (totalTokens * 0.08).round(),
      'GB': (totalTokens * 0.10).round(),
      'DE': (totalTokens * 0.09).round(),
      'AU': (totalTokens * 0.12).round(),
      'SG': (totalTokens * 0.06).round(),
      'Other': (totalTokens * 0.11).round(),
    };

    // Cost model (mock)
    const usdPer1kTokens = 0.012;
    final estMonthlyCost = (totalTokens / 1000) * usdPer1kTokens;
    final dailyCost = <AiCostTimeseriesPoint>[];
    for (final p in tokensByDay) {
      final c = (p.totalTokens / 1000) * usdPer1kTokens;
      dailyCost.add(AiCostTimeseriesPoint(day: p.day, estimatedCostUsd: c));
    }
    final estDaily = dailyCost.isEmpty ? 0.0 : dailyCost.last.estimatedCostUsd;

    final costByPlan = <String, double>{
      for (final e in tokensByPlan.entries) e.key: (e.value / 1000) * usdPer1kTokens,
    };

    final costByFeature = <AiFeatureArea, double>{
      for (final e in tokensByFeature.entries) e.key: (e.value / 1000) * usdPer1kTokens,
    };

    final activeUsers = 7800 + _rng.nextInt(2500);
    final costPerActiveUser = activeUsers <= 0 ? 0.0 : (estMonthlyCost / activeUsers);

    final highCostUsers = List.generate(12, (i) {
      final plan = (i % 4 == 0)
          ? 'Enterprise'
          : (i % 4 == 1)
              ? 'Team'
              : (i % 4 == 2)
                  ? 'Pro'
                  : 'Free';
      final userTokens = 180000 + _rng.nextInt(2200000);
      final req = max(1, (userTokens / (2600 + _rng.nextInt(1500))).round());
      return AiHighCostUserRow(
        userId: 'usr_${100800 + i}',
        email: (i % 3 == 0) ? 'highcost$i@example.com' : null,
        plan: plan,
        estimatedCostUsd: (userTokens / 1000) * usdPer1kTokens,
        totalTokens: userTokens,
        aiRequests: req,
        lastAiRequestAt: _now.subtract(Duration(hours: 1 + _rng.nextInt(24 * 10))),
      );
    })..sort((a, b) => b.estimatedCostUsd.compareTo(a.estimatedCostUsd));

    final limitMonitoring = List.generate(40, (i) {
      final plan = (i % 4 == 0)
          ? 'Enterprise'
          : (i % 4 == 1)
              ? 'Team'
              : (i % 4 == 2)
                  ? 'Pro'
                  : 'Free';
      final limit = switch (plan) {
        'Enterprise' => 5000000,
        'Team' => 2000000,
        'Pro' => 1000000,
        _ => 200000,
      };
      final used = (limit * (0.4 + _rng.nextDouble() * 0.9)).round();
      final requests = max(1, (used / (2800 + _rng.nextInt(1400))).round());
      return AiLimitMonitoringRow(
        userId: 'usr_${102000 + i}',
        email: (i % 3 == 0) ? 'limit$i@example.com' : null,
        plan: plan,
        monthlyTokenLimit: limit,
        tokensUsed: used,
        aiRequests: requests,
        limitReachedCount: (used >= limit) ? (1 + _rng.nextInt(4)) : _rng.nextInt(2),
        lastAiRequestAt: _now.subtract(Duration(hours: _rng.nextInt(24 * 20))),
      );
    })
      ..sort((a, b) {
        final ap = a.monthlyTokenLimit <= 0 ? 0 : a.tokensUsed / a.monthlyTokenLimit;
        final bp = b.monthlyTokenLimit <= 0 ? 0 : b.tokensUsed / b.monthlyTokenLimit;
        return bp.compareTo(ap);
      });

    final usersNearLimit = limitMonitoring.where((r) => r.monthlyTokenLimit > 0 && (r.tokensUsed / r.monthlyTokenLimit) >= 0.85 && r.tokensUsed < r.monthlyTokenLimit).length;
    final usersOverLimit = limitMonitoring.where((r) => r.tokensUsed >= r.monthlyTokenLimit).length;

    final models = const ['gpt-4o-mini', 'gpt-4o', 'o3-mini'];
    final errorCodes = const ['RATE_LIMIT', 'TIMEOUT', 'UPSTREAM_5XX', 'POLICY_BLOCK', 'BAD_REQUEST', 'MODEL_OVERLOADED'];
    final aiErrors = List.generate(55, (i) {
      final feature = featureAreas[i % featureAreas.length];
      final model = models[(i + 1) % models.length];
      final code = errorCodes[_rng.nextInt(errorCodes.length)];
      final result = (code == 'POLICY_BLOCK') ? 'blocked' : 'failed';
      final platform = ['iOS', 'Android', 'Web'][i % 3];
      final version = ['2.6.1', '2.7.0', '2.7.1'][_rng.nextInt(3)];
      return AiErrorRow(
        occurredAt: _now.subtract(Duration(minutes: 15 + (i * 37))),
        userPseudonym: _pseudonymize('usr_${100000 + (i % 70)}'),
        featureArea: feature,
        model: model,
        errorCode: code,
        result: result,
        platform: platform,
        appVersion: version,
      );
    });

    final usageByFeature = <AiFeatureUsageRow>[];
    for (final f in featureAreas) {
      final ftokens = tokensByFeature[f] ?? 0;
      final req = max(1, (ftokens / (2700 + _rng.nextInt(1600))).round());
      final failedReq = max(0, (req * (0.015 + _rng.nextDouble() * 0.04)).round());
      final input = (ftokens * (0.55 + _rng.nextDouble() * 0.1)).round().clamp(0, ftokens);
      final output = (ftokens - input).clamp(0, ftokens);
      usageByFeature.add(
        AiFeatureUsageRow(
          featureArea: f,
          requests: req,
          inputTokens: input,
          outputTokens: output,
          failedRequests: failedReq,
          estimatedCostUsd: (ftokens / 1000) * usdPer1kTokens,
        ),
      );
    }
    usageByFeature.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));

    return AiUsageSnapshot(
      query: query,
      aiRequestsThisMonth: aiRequests,
      inputTokensThisMonth: totalInput,
      outputTokensThisMonth: totalOutput,
      estimatedCostThisMonthUsd: estMonthlyCost,
      failedAiRequestsThisMonth: failed,
      usersNearAiLimit: usersNearLimit,
      usersOverAiLimit: usersOverLimit,
      tokensByDay: tokensByDay,
      tokensByFeature: tokensByFeature,
      tokensByPlan: tokensByPlan,
      tokensByPlatform: tokensByPlatform,
      tokensByCountry: tokensByCountry,
      dailyCost: dailyCost,
      estimatedDailyCostUsd: estDaily,
      estimatedMonthlyCostUsd: estMonthlyCost,
      costByPlan: costByPlan,
      costByFeature: costByFeature,
      costPerActiveUserUsd: costPerActiveUser,
      highCostUsers: highCostUsers,
      limitMonitoring: limitMonitoring,
      aiErrors: aiErrors,
      usageByFeature: usageByFeature,
      generatedAt: _now,
    );
  }

  // ------------------------------
  // Billing
  // ------------------------------

  @override
  Future<BillingSnapshot> getBillingSnapshot({required BillingQuery query}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    // Mock population sized to feel plausible.
    final activePaid = 920 + _rng.nextInt(180);
    final free = 5400 + _rng.nextInt(900);
    final trials = 210 + _rng.nextInt(65);
    final cancelled = 420 + _rng.nextInt(110);
    final failedPayments = 18 + _rng.nextInt(18);

    final mrr = (activePaid * (8.5 + _rng.nextDouble() * 5.5));
    final arr = mrr * 12;
    final arpu = activePaid <= 0 ? 0.0 : (mrr / activePaid);
    final trialConversion = 0.22 + _rng.nextDouble() * 0.18;

    final overview = BillingOverviewMetrics(
      activePaidUsers: activePaid,
      freeUsers: free,
      trialUsers: trials,
      cancelledUsers: cancelled,
      failedPayments: failedPayments,
      monthlyRecurringRevenueUsd: mrr,
      annualRecurringRevenueUsd: arr,
      averageRevenuePerUserUsd: arpu,
      trialConversionRate: trialConversion,
    );

    final countries = ['US', 'CA', 'GB', 'DE', 'AU', 'SG', 'FR', 'ES', 'BR', 'IN'];
    final plans = ['free', 'premium', 'family', 'team', 'enterprise'];
    final providers = BillingSubscriptionProvider.values;

    // Subscriptions
    final subs = List.generate(85, (i) {
      final userId = 'usr_${120000 + i}';
      final plan = (i % 7 == 0) ? 'family' : (i % 5 == 0) ? 'enterprise' : (i % 3 == 0) ? 'premium' : 'free';
      final provider = providers[(i + 1) % providers.length];
      final start = _now.subtract(Duration(days: 10 + _rng.nextInt(540)));
      final renewal = _rng.nextBool() ? _now.add(Duration(days: 2 + _rng.nextInt(40))) : null;
      final cancelledDate = (plan != 'free' && _rng.nextDouble() < 0.12) ? _now.subtract(Duration(days: 1 + _rng.nextInt(45))) : null;
      final status = cancelledDate != null
          ? 'cancelled'
          : (_rng.nextDouble() < 0.06)
              ? 'past_due'
              : (plan == 'free')
                  ? 'free'
                  : 'active';
      final failures = status == 'past_due' ? (1 + _rng.nextInt(4)) : (_rng.nextDouble() < 0.1 ? 1 : 0);
      final country = countries[(i * 3) % countries.length];
      final manualComp = provider == BillingSubscriptionProvider.manual && plan != 'free';
      return SubscriptionRow(
        userId: userId,
        email: (i % 3 == 0) ? 'billing_user_$i@example.com' : null,
        plan: plan,
        billingStatus: status,
        provider: provider,
        subscriptionStart: start,
        renewalDate: renewal,
        cancelledDate: cancelledDate,
        paymentFailureCount: failures,
        country: country,
        manualCompAccess: manualComp,
        billingNote: (i % 11 == 0) ? 'Requested invoice resend.' : null,
      );
    });

    // Trials
    final trialsRows = List.generate(55, (i) {
      final userId = 'usr_${121200 + i}';
      final plan = (i % 2 == 0) ? 'premium' : 'family';
      final start = _now.subtract(Duration(days: 1 + _rng.nextInt(10)));
      final end = start.add(const Duration(days: 14));
      final usage = ['Low', 'Medium', 'High'][_rng.nextInt(3)];
      final clicked = _rng.nextDouble() < 0.42;
      final converted = _rng.nextDouble() < (clicked ? 0.32 : 0.18);
      return TrialRow(userId: userId, plan: plan, trialStart: start, trialEnd: end, usageLevel: usage, upgradePromptClicked: clicked, converted: converted);
    });

    // Failed payments
    final failed = List.generate(38, (i) {
      final userId = 'usr_${121900 + i}';
      final plan = (i % 3 == 0) ? 'premium' : (i % 3 == 1) ? 'family' : 'enterprise';
      final provider = providers[(i + 2) % providers.length];
      final failures = 1 + _rng.nextInt(5);
      return FailedPaymentRow(
        userId: userId,
        email: (i % 2 == 0) ? 'pastdue_$i@example.com' : null,
        plan: plan,
        provider: provider,
        failureDate: _now.subtract(Duration(hours: 8 + (i * 7))),
        failureCount: failures,
        billingStatus: failures >= 3 ? 'past_due' : 'retrying',
        accountRestrictionStatus: failures >= 4 ? 'restricted' : 'normal',
      );
    });

    // Revenue by plan
    final revenueByPlan = <RevenueByPlanRow>[
      RevenueByPlanRow(plan: 'premium', users: 520, mrrUsd: 520 * 9.99, arrUsd: 520 * 9.99 * 12, churnRate: 0.032),
      RevenueByPlanRow(plan: 'family', users: 240, mrrUsd: 240 * 14.99, arrUsd: 240 * 14.99 * 12, churnRate: 0.027),
      RevenueByPlanRow(plan: 'enterprise', users: 58, mrrUsd: 58 * 39.0, arrUsd: 58 * 39.0 * 12, churnRate: 0.018),
      RevenueByPlanRow(plan: 'team', users: 110, mrrUsd: 110 * 19.0, arrUsd: 110 * 19.0 * 12, churnRate: 0.024),
      RevenueByPlanRow(plan: 'free', users: 6100, mrrUsd: 0, arrUsd: 0, churnRate: 0.0),
    ];

    // Revenue by country (group <10 into Other)
    final rawCountries = <RevenueByCountryRow>[];
    for (final c in countries) {
      final users = 4 + _rng.nextInt(420);
      final avgMrr = 8.0 + _rng.nextDouble() * 6.0;
      final mrrUsd = users * avgMrr;
      rawCountries.add(RevenueByCountryRow(country: c, users: users, mrrUsd: mrrUsd, arrUsd: mrrUsd * 12));
    }

    final grouped = <RevenueByCountryRow>[];
    var otherUsers = 0;
    var otherMrr = 0.0;
    var otherArr = 0.0;
    for (final r in rawCountries) {
      if (r.users < 10) {
        otherUsers += r.users;
        otherMrr += r.mrrUsd;
        otherArr += r.arrUsd;
      } else {
        grouped.add(r);
      }
    }
    if (otherUsers > 0) grouped.add(RevenueByCountryRow(country: 'Other', users: otherUsers, mrrUsd: otherMrr, arrUsd: otherArr));
    grouped.sort((a, b) => b.mrrUsd.compareTo(a.mrrUsd));

    // Apply query filters in-memory for mock.
    Iterable<SubscriptionRow> filteredSubs = subs;
    if (query.country != null && query.country!.trim().isNotEmpty) filteredSubs = filteredSubs.where((s) => s.country == query.country);
    if (query.plan != null && query.plan!.trim().isNotEmpty) filteredSubs = filteredSubs.where((s) => s.plan == query.plan);
    if (query.provider != null) filteredSubs = filteredSubs.where((s) => s.provider == query.provider);

    return BillingSnapshot(
      query: query,
      overview: overview,
      subscriptions: filteredSubs.toList(),
      trials: trialsRows.where((t) => query.plan == null ? true : t.plan == query.plan).toList(),
      failedPayments: failed.where((f) => query.plan == null ? true : f.plan == query.plan).toList(),
      revenueByPlan: revenueByPlan,
      revenueByCountry: grouped,
      generatedAt: _now,
    );
  }

  @override
  Future<void> performUserAdminAction({required AdminActionRequest request}) async {
    // Mock-only: no-op. A real implementation must call a Postgres function or
    // edge function that performs the action + writes audit logs.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    // Apply a tiny bit of mock state to make UI feel real.
    // Only updates feature flags / overrides lists used by Plans & Permissions pages.
    if (request.action.startsWith('FeatureFlag:')) {
      final keyStr = (request.parameters?['flag'] ?? '').toString();
      final enabled = (request.parameters?['enabled'] as bool?) ?? false;
      final match = FeatureFlagKey.values.where((e) => e.apiKey == keyStr);
      if (match.isNotEmpty) {
        final k = match.first;
        final idx = _featureFlags.indexWhere((f) => f.key == k);
        if (idx != -1) {
          _featureFlags[idx] = _featureFlags[idx].copyWith(enabled: enabled, updatedAt: _now);
        }
      }
    }

    await createAuditLog(
      entry: AdminAuditLogCreate(
        adminUserId: request.actorAdminId,
        targetUserId: request.userId,
        actionType: _mapUserAdminActionType(request.action),
        previousValue: {
          if (request.parameters != null && request.parameters!.containsKey('previous')) 'previous': request.parameters!['previous'],
          'action': request.action,
        },
        newValue: {
          'action': request.action,
          if (request.parameters != null) ...request.parameters!,
        },
        reason: request.reason,
        ticketReference: request.ticketReference,
        result: 'success',
      ),
    );
  }

  String _mapUserAdminActionType(String action) {
    final a = action.toLowerCase();
    if (a.contains('billing') && a.contains('add note')) return 'billing_note_added';
    if (a.contains('change plan')) return 'plan_changed';
    if (a.contains('extend trial')) return 'trial_extended';
    if (a.contains('storage')) return 'storage_limit_changed';
    if (a.contains('ai') && a.contains('limit')) return 'ai_limit_changed';
    if (a.contains('featureflag') || a.contains('feature flag')) return 'feature_flag_changed';
    if (a.contains('suspend') && !a.contains('unsuspend')) return 'account_suspended';
    if (a.contains('unsuspend')) return 'account_unsuspended';
    if (a.contains('force logout')) return 'force_logout_triggered';
    if (a.contains('revoke') && a.contains('session')) return 'sessions_revoked';
    return 'admin_action';
  }

  // ------------------------------
  // Compliance
  // ------------------------------

  @override
  Future<ComplianceSnapshot> getComplianceSnapshot({required ComplianceQuery query}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    // Overview cards
    final openDeletion = _deletionRequests.where((r) => r.status == ComplianceRequestStatus.open || r.status == ComplianceRequestStatus.inProgress).length;
    final completedDeletion = _deletionRequests.where((r) => r.status == ComplianceRequestStatus.completed).length;
    final failedDeletion = _deletionRequests.where((r) => r.status == ComplianceRequestStatus.failed).length;
    final openExport = _exportRequests.where((r) => r.status == ComplianceRequestStatus.open || r.status == ComplianceRequestStatus.inProgress).length;
    final completedExport = _exportRequests.where((r) => r.status == ComplianceRequestStatus.completed).length;

    final activeSupport = _supportSessions.where((s) => s.status == SupportSessionStatus.active).length;
    final expiredSupport = _supportSessions.where((s) => s.status == SupportSessionStatus.expired).length;

    final recentAdminActions = 28 + _rng.nextInt(60);
    final usersPendingDeletion = _deletionRequests.where((r) => r.status != ComplianceRequestStatus.completed).map((e) => e.userId).toSet().length;

    final overview = ComplianceOverviewMetrics(
      openDeletionRequests: openDeletion,
      completedDeletionRequests: completedDeletion,
      failedDeletionRequests: failedDeletion,
      openExportRequests: openExport,
      completedExportRequests: completedExport,
      activeSupportSessions: activeSupport,
      expiredSupportSessions: expiredSupport,
      recentAdminActions: recentAdminActions,
      usersPendingDeletion: usersPendingDeletion,
    );

    final retention = RetentionMonitoringMetrics(
      usageLogsDueForDeletion: 120000 + _rng.nextInt(80000),
      supportNotesDueForDeletion: 3200 + _rng.nextInt(1800),
      expiredSupportSessions: expiredSupport,
      oldDiagnosticLogs: 18000 + _rng.nextInt(9000),
      oldRawEvents: 820000 + _rng.nextInt(240000),
    );

    return ComplianceSnapshot(
      query: query,
      overview: overview,
      exportRequests: _exportRequests.take(80).toList(),
      deletionRequests: _deletionRequests.take(80).toList(),
      consentRecords: _consentRecords.take(120).toList(),
      supportAccessRecords: _supportAccessRecords.take(120).toList(),
      privacyTermsAcceptances: _policyAcceptances.take(120).toList(),
      retention: retention,
      generatedAt: _now,
    );
  }

  @override
  Future<void> performComplianceAction({required ComplianceActionRequest request}) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));

    // Mandatory audit row (best-effort; never include health content).
    await createAuditLog(
      entry: AdminAuditLogCreate(
        adminUserId: request.actorAdminId,
        targetUserId: request.userId,
        actionType: _mapComplianceActionType(request.action),
        previousValue: {'request_id': request.requestId},
        newValue: {
          'action': request.action.label,
          if (request.requestId != null) 'request_id': request.requestId,
          if (request.parameters != null) ...request.parameters!,
        },
        reason: request.reason,
        ticketReference: request.ticketReference,
        result: 'success',
      ),
    );

    final now = _now;
    final requestId = request.requestId;

    switch (request.action) {
      case ComplianceAction.markExportInProgress: {
        if (requestId == null) return;
        final idx = _exportRequests.indexWhere((r) => r.requestId == requestId);
        if (idx == -1) return;
        _exportRequests[idx] = _exportRequests[idx].copyWith(status: ComplianceRequestStatus.inProgress, clearFailureReason: true);
        return;
      }
      case ComplianceAction.markExportComplete: {
        if (requestId == null) return;
        final idx = _exportRequests.indexWhere((r) => r.requestId == requestId);
        if (idx == -1) return;
        _exportRequests[idx] = _exportRequests[idx].copyWith(status: ComplianceRequestStatus.completed, completedAt: now, verifiedBy: request.actorAdminId, clearFailureReason: true);
        return;
      }
      case ComplianceAction.markDeletionInProgress: {
        if (requestId == null) return;
        final idx = _deletionRequests.indexWhere((r) => r.requestId == requestId);
        if (idx == -1) return;
        _deletionRequests[idx] = _deletionRequests[idx].copyWith(status: ComplianceRequestStatus.inProgress, clearFailedReason: true);
        return;
      }
      case ComplianceAction.markDeletionComplete: {
        if (requestId == null) return;
        final idx = _deletionRequests.indexWhere((r) => r.requestId == requestId);
        if (idx == -1) return;
        _deletionRequests[idx] = _deletionRequests[idx].copyWith(status: ComplianceRequestStatus.completed, completedAt: now, verifiedBy: request.actorAdminId, clearFailedReason: true);
        return;
      }
      case ComplianceAction.recordFailureReason: {
        if (requestId == null) return;
        var idx = _exportRequests.indexWhere((r) => r.requestId == requestId);
        if (idx != -1) {
          _exportRequests[idx] = _exportRequests[idx].copyWith(status: ComplianceRequestStatus.failed, failureReason: request.reason, clearCompletedAt: true, clearVerifiedBy: true);
          return;
        }
        idx = _deletionRequests.indexWhere((r) => r.requestId == requestId);
        if (idx != -1) {
          _deletionRequests[idx] = _deletionRequests[idx].copyWith(status: ComplianceRequestStatus.failed, failedReason: request.reason, clearCompletedAt: true, clearVerifiedBy: true);
        }
        return;
      }
      case ComplianceAction.addComplianceNote: {
        if (requestId == null) return;
        final note = (request.parameters?['note'] ?? '').toString().trim();
        if (note.isEmpty) return;
        final idx = _exportRequests.indexWhere((r) => r.requestId == requestId);
        if (idx == -1) return;
        final prev = _exportRequests[idx].notes;
        final merged = (prev == null || prev.trim().isEmpty) ? note : '$prev\n—\n$note';
        _exportRequests[idx] = _exportRequests[idx].copyWith(notes: merged);
        return;
      }
      case ComplianceAction.closeSupportAccess: {
        if (requestId == null) return;
        var idx = _supportAccessRecords.indexWhere((r) => r.ticketReference == requestId);
        if (idx == -1) {
          idx = _supportAccessRecords.indexWhere((r) => '${r.userId}:${r.adminUser}:${r.accessExpiresAt?.millisecondsSinceEpoch ?? 0}' == requestId);
        }
        if (idx == -1) return;
        _supportAccessRecords[idx] = _supportAccessRecords[idx].copyWith(status: 'closed', clearAccessExpiresAt: true);
        return;
      }
    }
  }

  String _mapComplianceActionType(ComplianceAction action) {
    switch (action) {
      case ComplianceAction.markExportComplete:
        return 'export_request_marked_complete';
      case ComplianceAction.markDeletionComplete:
        return 'deletion_request_marked_complete';
      case ComplianceAction.addComplianceNote:
        return 'compliance_request_updated';
      default:
        return 'compliance_request_updated';
    }
  }

  @override
  Future<List<PlanOverviewRow>> listPlansOverview({required int limit}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    // Example plans requested.
    final rows = <PlanOverviewRow>[
      PlanOverviewRow(planName: 'free', monthlyPriceUsd: 0, storageLimitBytes: 5 * 1024 * 1024 * 1024, aiTokenLimitMonthly: 200000, profileLimit: 3, uploadLimit: 40, exportAccess: false, aiAccess: true, activeUsers: 640, trialUsers: 0, paidUsers: 0, cancelledUsers: 34),
      PlanOverviewRow(planName: 'launch_free_6_months', monthlyPriceUsd: 0, storageLimitBytes: 15 * 1024 * 1024 * 1024, aiTokenLimitMonthly: 500000, profileLimit: 5, uploadLimit: 120, exportAccess: true, aiAccess: true, activeUsers: 120, trialUsers: 95, paidUsers: 0, cancelledUsers: 4),
      PlanOverviewRow(planName: 'premium', monthlyPriceUsd: 9.99, storageLimitBytes: 50 * 1024 * 1024 * 1024, aiTokenLimitMonthly: 1500000, profileLimit: 10, uploadLimit: null, exportAccess: true, aiAccess: true, activeUsers: 210, trialUsers: 22, paidUsers: 185, cancelledUsers: 18),
      PlanOverviewRow(planName: 'family', monthlyPriceUsd: 14.99, storageLimitBytes: 120 * 1024 * 1024 * 1024, aiTokenLimitMonthly: 2500000, profileLimit: 20, uploadLimit: null, exportAccess: true, aiAccess: true, activeUsers: 90, trialUsers: 8, paidUsers: 76, cancelledUsers: 6),
      PlanOverviewRow(planName: 'admin_test', monthlyPriceUsd: 0, storageLimitBytes: 10 * 1024 * 1024 * 1024, aiTokenLimitMonthly: 800000, profileLimit: 5, uploadLimit: 80, exportAccess: true, aiAccess: true, activeUsers: 7, trialUsers: 0, paidUsers: 0, cancelledUsers: 0),
      PlanOverviewRow(planName: 'suspended', monthlyPriceUsd: 0, storageLimitBytes: 0, aiTokenLimitMonthly: 0, profileLimit: 0, uploadLimit: 0, exportAccess: false, aiAccess: false, activeUsers: 0, trialUsers: 0, paidUsers: 0, cancelledUsers: 42),
    ];
    return rows.take(limit).toList();
  }

  @override
  Future<UserEntitlements> getUserEntitlements({required String userId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final u = await getUserDetail(userId: userId);
    final now = _now;
    final plan = switch (u.plan.toLowerCase()) {
      'enterprise' || 'team' || 'pro' => 'premium',
      'free' => 'free',
      _ => u.plan.toLowerCase().replaceAll(' ', '_'),
    };
    final trialStart = (u.billingStatus == 'active' && plan == 'launch_free_6_months') ? now.subtract(const Duration(days: 12)) : (u.billingStatus == 'active' && plan == 'premium' && _rng.nextBool()) ? now.subtract(const Duration(days: 7)) : null;
    final trialEnd = (trialStart != null) ? trialStart.add(const Duration(days: 14)) : null;

    final defaultStorage = switch (plan) {
      'free' => 5 * 1024 * 1024 * 1024,
      'launch_free_6_months' => 15 * 1024 * 1024 * 1024,
      'premium' => 50 * 1024 * 1024 * 1024,
      'family' => 120 * 1024 * 1024 * 1024,
      'admin_test' => 10 * 1024 * 1024 * 1024,
      'suspended' => 0,
      _ => 15 * 1024 * 1024 * 1024,
    };
    final defaultAi = switch (plan) {
      'free' => 200000,
      'launch_free_6_months' => 500000,
      'premium' => 1500000,
      'family' => 2500000,
      'admin_test' => 800000,
      'suspended' => 0,
      _ => 500000,
    };
    final defaultProfiles = switch (plan) {
      'free' => 3,
      'launch_free_6_months' => 5,
      'premium' => 10,
      'family' => 20,
      'admin_test' => 5,
      'suspended' => 0,
      _ => 5,
    };

    final flags = <FeatureFlagKey, bool>{
      for (final f in _featureFlags) f.key: f.enabled,
    };

    // Simple per-user overrides in mock.
    if (u.accountStatus == 'suspended' || u.accountStatus == 'locked') {
      flags[FeatureFlagKey.documentUploads] = false;
      flags[FeatureFlagKey.aiAssistant] = false;
      flags[FeatureFlagKey.export] = false;
    }

    return UserEntitlements(
      userId: u.userId,
      currentPlan: plan,
      billingStatus: u.billingStatus,
      subscriptionProvider: u.subscriptionProvider,
      trialStart: trialStart,
      trialEnd: trialEnd,
      storageLimitBytes: defaultStorage,
      aiTokenLimitMonthly: defaultAi,
      profileLimit: defaultProfiles,
      uploadLimit: (plan == 'free' || plan == 'launch_free_6_months') ? 120 : null,
      featureFlags: flags,
      updatedAt: now,
    );
  }

  @override
  Future<List<FeatureFlagDefinition>> listFeatureFlags({required int limit}) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return _featureFlags.take(limit).toList();
  }

  @override
  Future<List<LimitOverrideRow>> listLimitOverrides({required int limit}) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _limitOverrides.take(limit).toList();
  }

  // ------------------------------
  // Usage analytics
  // ------------------------------

  @override
  Future<UsageAnalyticsSnapshot> getUsageAnalyticsSnapshot({required UsageAnalyticsQuery query}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    // Only derived from safe account summaries. Never content.
    final users = await listUsers(query: const UserListQuery(search: '', filters: UserListFilters()), limit: 600);
    List<UserAccountSummary> filtered = users;
    if (query.country != null) filtered = filtered.where((u) => u.country == query.country).toList();
    if (query.platform != null) filtered = filtered.where((u) => u.platform == query.platform).toList();
    if (query.plan != null) filtered = filtered.where((u) => u.plan.toLowerCase() == query.plan!.toLowerCase()).toList();
    if (query.appVersion != null) filtered = filtered.where((u) => u.appVersion == query.appVersion).toList();

    final now = _now;
    final activeUsers = filtered.where((u) => (u.lastActiveAt?.isAfter(now.subtract(Duration(days: query.range.days))) ?? false)).length;

    // Build rough event/session estimates.
    final days = query.range.days;
    final avgEventsPerActiveUserPerDay = switch (query.range) {
      AdminDateRangePreset.today => 28,
      AdminDateRangePreset.days7 => 18,
      AdminDateRangePreset.days30 => 12,
      AdminDateRangePreset.days90 => 8,
    };
    final sessionsPerActiveUserPerDay = switch (query.range) {
      AdminDateRangePreset.today => 1.6,
      AdminDateRangePreset.days7 => 1.2,
      AdminDateRangePreset.days30 => 0.9,
      AdminDateRangePreset.days90 => 0.7,
    };

    final totalEvents = (activeUsers * days * avgEventsPerActiveUserPerDay * (0.9 + (_rng.nextDouble() * 0.2))).round();
    final sessions = (activeUsers * days * sessionsPerActiveUserPerDay * (0.9 + (_rng.nextDouble() * 0.2))).round();
    final avgSessionDurationSeconds = (420 + _rng.nextInt(240));

    // Feature usage by category (high-level only).
    final featureUsageByCategory = <String, int>{
      'Core tracking': (totalEvents * 0.28).round(),
      'Documents': (totalEvents * 0.20).round(),
      'Search & navigation': (totalEvents * 0.18).round(),
      'AI assistant': (totalEvents * 0.16).round(),
      'Settings & account': (totalEvents * 0.10).round(),
      'Exports': (totalEvents * 0.08).round(),
    };

    // Conversions are expressed as rates (0..1).
    double clamp01(double v) => v.clamp(0.0, 1.0);
    final signupToFirstProfile = clamp01(0.64 + (_rng.nextDouble() * 0.08));
    final firstProfileToFirstUpload = clamp01(0.38 + (_rng.nextDouble() * 0.10));
    final firstUploadToRecurring = clamp01(0.22 + (_rng.nextDouble() * 0.08));

    final upgradePromptViews = (activeUsers * (0.6 + _rng.nextDouble()) * (days / 7)).round();
    final upgradeClicks = (upgradePromptViews * (0.05 + _rng.nextDouble() * 0.05)).round();

    final conversions = UsageOverviewConversions(
      signupToFirstProfile: signupToFirstProfile,
      firstProfileToFirstUpload: firstProfileToFirstUpload,
      firstUploadToRecurring: firstUploadToRecurring,
      upgradePromptViews: upgradePromptViews,
      upgradeClicks: upgradeClicks,
    );

    // Feature usage counts (explicit list requested).
    int ev(int base) => (base * (days / 30) * (0.85 + _rng.nextDouble() * 0.3)).round();
    int uu(int base) => (base * (0.9 + _rng.nextDouble() * 0.2)).round().clamp(1, max(1, activeUsers));

    final featureUsage = <UsageFeatureUsageRow>[
      UsageFeatureUsageRow(feature: 'Documents', eventCount: ev(totalEvents ~/ 8), uniqueUsers: uu((activeUsers * 0.52).round())),
      UsageFeatureUsageRow(feature: 'Appointments', eventCount: ev(totalEvents ~/ 18), uniqueUsers: uu((activeUsers * 0.18).round())),
      UsageFeatureUsageRow(feature: 'Medications', eventCount: ev(totalEvents ~/ 20), uniqueUsers: uu((activeUsers * 0.16).round())),
      UsageFeatureUsageRow(feature: 'Vaccinations', eventCount: ev(totalEvents ~/ 26), uniqueUsers: uu((activeUsers * 0.12).round())),
      UsageFeatureUsageRow(feature: 'Blood Pressure', eventCount: ev(totalEvents ~/ 14), uniqueUsers: uu((activeUsers * 0.22).round())),
      UsageFeatureUsageRow(feature: 'Timeline', eventCount: ev(totalEvents ~/ 10), uniqueUsers: uu((activeUsers * 0.44).round())),
      UsageFeatureUsageRow(feature: 'Body Map', eventCount: ev(totalEvents ~/ 28), uniqueUsers: uu((activeUsers * 0.10).round())),
      UsageFeatureUsageRow(feature: 'AI Assistant', eventCount: ev(totalEvents ~/ 7), uniqueUsers: uu((activeUsers * 0.34).round())),
      UsageFeatureUsageRow(feature: 'Search', eventCount: ev(totalEvents ~/ 9), uniqueUsers: uu((activeUsers * 0.62).round())),
      UsageFeatureUsageRow(feature: 'Export', eventCount: ev(totalEvents ~/ 30), uniqueUsers: uu((activeUsers * 0.08).round())),
      UsageFeatureUsageRow(feature: 'Settings', eventCount: ev(totalEvents ~/ 22), uniqueUsers: uu((activeUsers * 0.28).round())),
      UsageFeatureUsageRow(feature: 'Account deletion page', eventCount: ev(max(80, totalEvents ~/ 220)), uniqueUsers: uu(max(6, (activeUsers * 0.01).round()))),
      UsageFeatureUsageRow(feature: 'Data export page', eventCount: ev(max(180, totalEvents ~/ 140)), uniqueUsers: uu(max(12, (activeUsers * 0.02).round()))),
    ];

    featureUsage.sort((a, b) => b.eventCount.compareTo(a.eventCount));

    final screenUsage = <UsageScreenUsageRow>[
      UsageScreenUsageRow(screenName: 'Home', views: ev(totalEvents ~/ 6), uniqueUsers: uu((activeUsers * 0.70).round()), avgDurationSeconds: 62 + _rng.nextInt(40), exitRate: 0.22 + _rng.nextDouble() * 0.08, errorCount: _rng.nextInt(30)),
      UsageScreenUsageRow(screenName: 'Profiles', views: ev(totalEvents ~/ 10), uniqueUsers: uu((activeUsers * 0.46).round()), avgDurationSeconds: 54 + _rng.nextInt(35), exitRate: 0.18 + _rng.nextDouble() * 0.06, errorCount: _rng.nextInt(24)),
      UsageScreenUsageRow(screenName: 'Documents', views: ev(totalEvents ~/ 9), uniqueUsers: uu((activeUsers * 0.50).round()), avgDurationSeconds: 78 + _rng.nextInt(60), exitRate: 0.25 + _rng.nextDouble() * 0.08, errorCount: _rng.nextInt(40)),
      UsageScreenUsageRow(screenName: 'Upload', views: ev(totalEvents ~/ 22), uniqueUsers: uu((activeUsers * 0.16).round()), avgDurationSeconds: 92 + _rng.nextInt(70), exitRate: 0.34 + _rng.nextDouble() * 0.10, errorCount: _rng.nextInt(65)),
      UsageScreenUsageRow(screenName: 'AI Assistant', views: ev(totalEvents ~/ 8), uniqueUsers: uu((activeUsers * 0.34).round()), avgDurationSeconds: 110 + _rng.nextInt(90), exitRate: 0.20 + _rng.nextDouble() * 0.10, errorCount: _rng.nextInt(32)),
      UsageScreenUsageRow(screenName: 'Search', views: ev(totalEvents ~/ 7), uniqueUsers: uu((activeUsers * 0.62).round()), avgDurationSeconds: 24 + _rng.nextInt(20), exitRate: 0.40 + _rng.nextDouble() * 0.12, errorCount: _rng.nextInt(22)),
      UsageScreenUsageRow(screenName: 'Settings', views: ev(totalEvents ~/ 20), uniqueUsers: uu((activeUsers * 0.28).round()), avgDurationSeconds: 34 + _rng.nextInt(26), exitRate: 0.30 + _rng.nextDouble() * 0.10, errorCount: _rng.nextInt(20)),
      UsageScreenUsageRow(screenName: 'Billing / Upgrade', views: ev(max(350, totalEvents ~/ 90)), uniqueUsers: uu(max(50, (activeUsers * 0.06).round())), avgDurationSeconds: 40 + _rng.nextInt(30), exitRate: 0.44 + _rng.nextDouble() * 0.12, errorCount: _rng.nextInt(18)),
    ];
    screenUsage.sort((a, b) => b.views.compareTo(a.views));

    int funnelCount(int base) => (base * (0.9 + _rng.nextDouble() * 0.2)).round();
    int step(int previous, double keepRate) => max(0, (previous * keepRate).round());

    final signup0 = funnelCount(max(80, (activeUsers * 0.35).round()));
    final signup1 = step(signup0, 0.86);
    final signup2 = step(signup1, signupToFirstProfile);
    final signup3 = step(signup2, 0.72);
    final signup4 = step(signup3, firstProfileToFirstUpload);
    final signup5 = step(signup4, 0.58);
    final funnels = <UsageFunnel>[
      UsageFunnel(
        name: 'Signup Activation',
        steps: [
          UsageFunnelStep(label: 'Account created', count: signup0),
          UsageFunnelStep(label: 'Email verified', count: signup1),
          UsageFunnelStep(label: 'First profile created', count: signup2),
          UsageFunnelStep(label: 'First record added', count: signup3),
          UsageFunnelStep(label: 'First document uploaded', count: signup4),
          UsageFunnelStep(label: 'Returned within 7 days', count: signup5),
        ],
      ),
      () {
        final up0 = funnelCount(max(100, (activeUsers * 0.20).round()));
        final up1 = step(up0, 0.82);
        final up2 = step(up1, 0.74);
        final up3 = step(up2, 0.08 + _rng.nextDouble() * 0.07);
        return UsageFunnel(
          name: 'Upload Flow',
          steps: [
            UsageFunnelStep(label: 'Upload started', count: up0),
            UsageFunnelStep(label: 'File selected', count: up1),
            UsageFunnelStep(label: 'Upload completed', count: up2),
            UsageFunnelStep(label: 'Upload failed', count: up3),
          ],
        );
      }(),
      () {
        final ai0 = funnelCount(max(120, (activeUsers * 0.24).round()));
        final ai1 = step(ai0, 0.78);
        final ai2 = step(ai1, 0.70);
        final ai3 = step(ai2, 0.06 + _rng.nextDouble() * 0.04);
        final ai4 = step(ai3, 0.30 + _rng.nextDouble() * 0.25);
        return UsageFunnel(
          name: 'AI Flow',
          steps: [
            UsageFunnelStep(label: 'AI opened', count: ai0),
            UsageFunnelStep(label: 'AI request sent', count: ai1),
            UsageFunnelStep(label: 'AI response completed', count: ai2),
            UsageFunnelStep(label: 'Limit reached', count: ai3),
            UsageFunnelStep(label: 'Upgrade clicked', count: ai4),
          ],
        );
      }(),
    ];

    // Retention: keep privacy-safe aggregated rates only.
    final retention = UsageRetentionSnapshot(
      day1: clamp01(0.34 + _rng.nextDouble() * 0.08),
      day7: clamp01(0.19 + _rng.nextDouble() * 0.06),
      day30: clamp01(0.10 + _rng.nextDouble() * 0.05),
      weeklyRetention: clamp01(0.24 + _rng.nextDouble() * 0.07),
    );

    // Country usage must group <10-user countries into "Other".
    final countryUsage = _buildCountryUsage(filtered);

    // Platform usage
    final platformUsage = <String, int>{'iOS': 0, 'Android': 0, 'Web': 0};
    for (final u in filtered) {
      platformUsage[u.platform] = (platformUsage[u.platform] ?? 0) + 1;
    }

    return UsageAnalyticsSnapshot(
      query: query,
      totalEvents: totalEvents,
      activeUsers: activeUsers,
      sessions: sessions,
      avgSessionDurationSeconds: avgSessionDurationSeconds,
      featureUsageByCategory: featureUsageByCategory,
      conversions: conversions,
      featureUsage: featureUsage,
      screenUsage: screenUsage,
      funnels: funnels,
      retention: retention,
      countryUsage: countryUsage,
      platformUsage: platformUsage,
      generatedAt: now,
    );
  }

  @override
  Future<List<SupportSessionSummary>> listSupportSessions({required SupportQueueQuery query, required int limit}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final q = query.search.trim().toLowerCase();
    var list = _supportSessions;
    if (q.isNotEmpty) {
      list = list
          .where((s) =>
              s.supportSessionId.toLowerCase().contains(q) ||
              s.userId.toLowerCase().contains(q) ||
              (s.email?.toLowerCase().contains(q) ?? false) ||
              (s.ticketReference?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    final f = query.filters;
    if (f.status != null) list = list.where((s) => s.status == f.status).toList();
    if (f.consentStatus != null) list = list.where((s) => s.consentStatus == f.consentStatus).toList();
    if (f.assignedAdminId != null) list = list.where((s) => s.assignedAdmin == f.assignedAdminId).toList();
    if (f.onlyExpiringSoon == true) {
      final now = _now;
      list = list.where((s) {
        final exp = s.accessExpiresAt;
        if (exp == null) return false;
        return exp.isAfter(now) && exp.isBefore(now.add(const Duration(minutes: 15)));
      }).toList();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(limit).toList();
  }

  @override
  Future<SupportSummarySnapshot> getSupportSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final now = _now;

    int countWhere(bool Function(SupportSessionSummary s) pred) => _supportSessions.where(pred).length;
    final latest = _supportSessions.isEmpty ? null : _supportSessions.map((s) => s.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);

    return SupportSummarySnapshot(
      totalSessions: _supportSessions.length,
      openSessions: countWhere((s) => s.status == SupportSessionStatus.pending),
      activeSessions: countWhere((s) => s.status == SupportSessionStatus.active),
      closedSessions: countWhere((s) => s.status == SupportSessionStatus.closed),
      expiredSessions: countWhere((s) => s.status == SupportSessionStatus.expired),
      latestSessionAt: latest,
      generatedAt: now,
    );
  }

  @override
  Future<SupportSessionDetail> getSupportSessionDetail({required String supportSessionId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final s = _supportSessions.firstWhere((x) => x.supportSessionId == supportSessionId, orElse: () => _supportSessions.first);
    final u = await getUserDetail(userId: s.userId);
    final now = _now;
    final events = <TechnicalEvent>[
      TechnicalEvent(timestamp: now.subtract(const Duration(minutes: 12)), type: 'sync', message: 'Background sync completed.', code: 'SYNC_OK'),
      if ((u.failedSyncCount30d) > 6) TechnicalEvent(timestamp: now.subtract(const Duration(hours: 3)), type: 'sync', message: 'Sync timeout after 30s.', code: 'SYNC_TIMEOUT'),
      if ((u.failedUploadCount30d) > 6) TechnicalEvent(timestamp: now.subtract(const Duration(hours: 8)), type: 'upload', message: 'Upload failed: network reset.', code: 'UPLOAD_CONN_RESET'),
      if (u.billingStatus == 'past_due') TechnicalEvent(timestamp: now.subtract(const Duration(days: 1)), type: 'billing', message: 'Payment failed; account may be blocked.', code: 'PAYMENT_PAST_DUE'),
      TechnicalEvent(timestamp: now.subtract(const Duration(days: 2)), type: 'auth', message: 'Session refreshed successfully.', code: 'AUTH_REFRESH_OK'),
    ];

    final openErrors = <String>[
      if (u.lastKnownErrorCode != null) u.lastKnownErrorCode!,
      if (u.failedSyncCount30d >= 10) 'REPEATED_SYNC_FAILURES',
      if (u.failedUploadCount30d >= 10) 'REPEATED_UPLOAD_FAILURES',
      if (u.billingStatus == 'past_due') 'PAYMENT_BLOCK',
    ];

    final consentWindowStatus = switch (s.consentStatus) {
      'on_file' => (s.status == SupportSessionStatus.active) ? 'active' : 'on_file',
      'revoked' => 'revoked',
      'missing' => 'missing',
      _ => 'unknown',
    };

    return SupportSessionDetail(
      supportSessionId: s.supportSessionId,
      userId: s.userId,
      email: s.email,
      accountStatus: u.accountStatus,
      plan: u.plan,
      appVersion: u.appVersion,
      platform: u.platform,
      country: u.country,
      lastLoginAt: u.lastLoginAt,
      lastSyncAt: u.lastSyncAt,
      failedSyncCount: u.failedSyncCount30d,
      failedUploadCount: u.failedUploadCount30d,
      storageUsedBytes: u.storageUsedBytes,
      storageLimitBytes: u.storageLimitBytes,
      aiTokensUsed: u.aiTokensUsedThisMonth,
      aiLimit: u.aiTokenLimitThisMonth,
      openErrors: openErrors,
      recentTechnicalEvents: events..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
      adminNotes: u.supportNotes,
      consentWindowStatus: consentWindowStatus,
      status: s.status,
      accessExpiresAt: s.accessExpiresAt,
      ticketReference: s.ticketReference,
      updatedAt: s.updatedAt,
      assignedAdmin: s.assignedAdmin,
    );
  }

  @override
  Future<DiagnosticsReport> runDiagnostics({required String userId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final u = await getUserDetail(userId: userId);
    final now = _now;

    DiagnosticStatus statusOf(bool ok, {bool warnOnly = false}) {
      if (ok) return DiagnosticStatus.pass;
      return warnOnly ? DiagnosticStatus.warning : DiagnosticStatus.fail;
    }

    final overStorage = u.storageUsedBytes > u.storageLimitBytes;
    final overAi = u.aiTokensUsedThisMonth > u.aiTokenLimitThisMonth;
    final lastSyncRecent = (u.lastSyncAt != null) && u.lastSyncAt!.isAfter(now.subtract(const Duration(days: 2)));
    final repeatedErrors = (u.failedSyncCount30d + u.failedUploadCount30d) >= 12;
    final paymentBlocked = u.billingStatus == 'past_due';
    final adminSuspension = u.accountStatus == 'suspended' || u.accountStatus == 'locked';
    final supportedVersion = !_isAppVersionTooOld(u.appVersion);

    final checks = <DiagnosticCheck>[
      DiagnosticCheck(id: 'account_exists', title: 'Account exists', status: DiagnosticStatus.pass, explanation: 'User account metadata is present in the control summary.', suggestedAction: 'Proceed with troubleshooting.'),
      DiagnosticCheck(id: 'email_verified', title: 'Email verified', status: (u.email == null) ? DiagnosticStatus.warning : DiagnosticStatus.pass, explanation: (u.email == null) ? 'Email is hidden for your role or not on file.' : 'Email present in safe summary.', suggestedAction: 'If user cannot sign in, resend verification email.'),
      DiagnosticCheck(id: 'account_active', title: 'Account active', status: statusOf(!(adminSuspension)), explanation: adminSuspension ? 'Account is suspended/locked by admin policy.' : 'Account status is active.', suggestedAction: adminSuspension ? 'Unsuspend account if appropriate.' : 'No action needed.'),
      DiagnosticCheck(id: 'subscription_active', title: 'Subscription active', status: statusOf(!paymentBlocked, warnOnly: true), explanation: paymentBlocked ? 'Billing status is past_due; features may be blocked.' : 'Billing status is active.', suggestedAction: paymentBlocked ? 'Resolve billing failure or extend trial.' : 'No action needed.'),
      DiagnosticCheck(id: 'storage_over_limit', title: 'Storage not over limit', status: statusOf(!overStorage, warnOnly: false), explanation: overStorage ? 'User is over their storage quota; uploads may be blocked.' : 'Storage usage is within quota.', suggestedAction: overStorage ? 'Temporarily increase storage limit or advise cleanup.' : 'No action needed.'),
      DiagnosticCheck(id: 'ai_over_limit', title: 'AI not over limit', status: statusOf(!overAi, warnOnly: true), explanation: overAi ? 'AI usage exceeds limit this month; assistant may be blocked.' : 'AI usage is within limit.', suggestedAction: overAi ? 'Temporarily increase AI limit if policy allows.' : 'No action needed.'),
      DiagnosticCheck(id: 'last_sync_success', title: 'Last sync successful', status: statusOf(lastSyncRecent, warnOnly: true), explanation: lastSyncRecent ? 'Last sync is recent.' : 'Last sync is stale or missing.', suggestedAction: 'Ask user to open the app and trigger sync; check errors.'),
      DiagnosticCheck(id: 'upload_service_healthy', title: 'Upload service healthy', status: DiagnosticStatus.pass, explanation: 'No service outage flagged in mock telemetry.', suggestedAction: 'If uploads fail, revoke sessions and retry.'),
      DiagnosticCheck(id: 'app_version_supported', title: 'App version supported', status: statusOf(supportedVersion, warnOnly: true), explanation: supportedVersion ? 'App version appears supported.' : 'App version is older than the supported floor.', suggestedAction: 'Ask user to update the app.'),
      DiagnosticCheck(id: 'platform_supported', title: 'Platform supported', status: DiagnosticStatus.pass, explanation: 'Platform is in the supported set.', suggestedAction: 'No action needed.'),
      DiagnosticCheck(id: 'repeated_error_codes', title: 'No recent repeated error codes', status: statusOf(!repeatedErrors, warnOnly: true), explanation: repeatedErrors ? 'Repeated failures detected over last 30d.' : 'No repeated error patterns detected.', suggestedAction: repeatedErrors ? 'Collect logs (metadata), escalate to engineering.' : 'No action needed.'),
      DiagnosticCheck(id: 'payment_failure_block', title: 'No payment failure block', status: statusOf(!paymentBlocked, warnOnly: true), explanation: paymentBlocked ? 'Payment failures may block sync/AI.' : 'No payment blocks detected.', suggestedAction: paymentBlocked ? 'Billing admin review recommended.' : 'No action needed.'),
      DiagnosticCheck(id: 'admin_suspension', title: 'No admin suspension', status: statusOf(!adminSuspension, warnOnly: false), explanation: adminSuspension ? 'Account is currently suspended/locked.' : 'No admin suspension flags.', suggestedAction: adminSuspension ? 'Unsuspend if verified and permitted.' : 'No action needed.'),
    ];

    return DiagnosticsReport(userId: u.userId, generatedAt: now, checks: checks);
  }

  bool _isAppVersionTooOld(String version) {
    // Very rough semantic: anything below 2.6.0 is considered old in this mock.
    final parts = version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    if (parts[0] != 2) return parts[0] < 2;
    if (parts[1] != 6) return parts[1] < 6;
    return parts[2] < 0;
  }

  @override
  Future<void> performSupportAction({required SupportActionRequest request}) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    // Update mock session status for close/revoke flows.
    final idx = _supportSessions.indexWhere((s) => s.supportSessionId == request.supportSessionId);
    if (idx == -1) return;
    final current = _supportSessions[idx];

    SupportSessionStatus? next;
    if (request.action == SupportAction.closeSupportSession) next = SupportSessionStatus.closed;
    if (next != null) {
      _supportSessions[idx] = SupportSessionSummary(
        supportSessionId: current.supportSessionId,
        userId: current.userId,
        email: current.email,
        ticketReference: current.ticketReference,
        consentStatus: current.consentStatus,
        status: next,
        assignedAdmin: current.assignedAdmin,
        createdAt: current.createdAt,
        accessExpiresAt: current.accessExpiresAt,
        updatedAt: _now,
      );
    }

    await createAuditLog(
      entry: AdminAuditLogCreate(
        adminUserId: request.actorAdminId,
        targetUserId: request.userId,
        actionType: _mapSupportActionType(request.action),
        previousValue: {'support_session_status': current.status.label},
        newValue: {
          'support_session_id': request.supportSessionId,
          'action': request.action.label,
          if (request.parameters != null) ...request.parameters!,
        },
        reason: request.reason,
        ticketReference: request.ticketReference,
        result: 'success',
      ),
    );
  }

  String _mapSupportActionType(SupportAction action) {
    switch (action) {
      case SupportAction.closeSupportSession:
        return 'support_session_closed';
      case SupportAction.addSupportNote:
        return 'support_note_added';
      case SupportAction.forceLogout:
        return 'force_logout_triggered';
      case SupportAction.revokeActiveSessions:
        return 'sessions_revoked';
      case SupportAction.extendTrial:
        return 'trial_extended';
      case SupportAction.temporarilyIncreaseStorageLimit:
        return 'storage_limit_changed';
      case SupportAction.temporarilyIncreaseAiLimit:
        return 'ai_limit_changed';
      case SupportAction.suspendAccount:
        return 'account_suspended';
      case SupportAction.unsuspendAccount:
        return 'account_unsuspended';
      case SupportAction.resendVerificationEmail:
        return 'support_action';
    }
  }

  @override
  Future<List<AuditLogEntry>> listAuditLogs({required AuditLogQuery query, required int limit}) async {
    // If Supabase is configured, prefer live audit logs.
    final c = _client;
    if (c != null) {
      try {
        PostgrestFilterBuilder<dynamic> q;
        try {
          q = c.from('admin_audit_log').select('*');
        } catch (_) {
          q = c.from('admin_audit_log').select('*');
        }

        if (query.adminUserId != null && query.adminUserId!.trim().isNotEmpty) q = q.ilike('admin_user_id', '%${query.adminUserId!.trim()}%');
        if (query.targetUserId != null && query.targetUserId!.trim().isNotEmpty) q = q.ilike('target_user_id', '%${query.targetUserId!.trim()}%');
        if (query.actionType != null && query.actionType!.trim().isNotEmpty) q = q.eq('action_type', query.actionType!.trim());
        if (query.result != null && query.result!.trim().isNotEmpty) q = q.eq('result', query.result!.trim());
        if (query.createdRange != null) {
          q = q.gte('created_at', query.createdRange!.start.toUtc().toIso8601String());
          q = q.lte('created_at', query.createdRange!.end.toUtc().toIso8601String());
        }

        final res = await q.order('created_at', ascending: false).limit(limit);
        final list = (res as List).cast<Map<String, dynamic>>();
        return list.map(AuditLogEntry.fromJson).toList(growable: false);
      } catch (e) {
        debugPrint('MockAdminRepository.listAuditLogs Supabase fallback to local: $e');
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    Iterable<AuditLogEntry> logs = _auditLogs;
    if (query.adminUserId != null && query.adminUserId!.trim().isNotEmpty) {
      final q = query.adminUserId!.trim();
      logs = logs.where((l) => l.adminUserId.contains(q));
    }
    if (query.targetUserId != null && query.targetUserId!.trim().isNotEmpty) {
      final q = query.targetUserId!.trim();
      logs = logs.where((l) => (l.targetUserId ?? '').contains(q));
    }
    if (query.actionType != null && query.actionType!.trim().isNotEmpty) {
      final q = query.actionType!.trim();
      logs = logs.where((l) => l.actionType == q);
    }
    if (query.result != null && query.result!.trim().isNotEmpty) {
      final q = query.result!.trim();
      logs = logs.where((l) => l.result == q);
    }
    if (query.createdRange != null) {
      final start = query.createdRange!.start;
      final end = query.createdRange!.end;
      logs = logs.where((l) => !l.createdAt.isBefore(start) && !l.createdAt.isAfter(end));
    }
    return logs.take(limit).toList(growable: false);
  }

  @override
  Future<AuditSummarySnapshot> getAuditSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final now = _now;
    final total = _auditLogs.length;
    final audit24h = _auditLogs.where((e) => e.createdAt.isAfter(now.subtract(const Duration(hours: 24)))).length;
    final failed24h = _auditLogs
        .where((e) => e.createdAt.isAfter(now.subtract(const Duration(hours: 24))) && e.result.toLowerCase() != 'success')
        .length;

    DateTime? latest;
    for (final e in _auditLogs) {
      if (latest == null || e.createdAt.isAfter(latest)) latest = e.createdAt;
    }

    return AuditSummarySnapshot(
      totalAuditEvents: total,
      auditEvents24h: audit24h,
      failedAdminActions24h: failed24h,
      latestAuditEventAt: latest,
      generatedAt: now,
    );
  }

  @override
  Future<DashboardSnapshot> getDashboardSnapshot({required DashboardQuery query}) async {
    // Privacy-safe: derived exclusively from aggregated account metadata.
    final users = await listUsers(query: const UserListQuery(search: '', filters: UserListFilters()), limit: 300);

    List<UserAccountSummary> filtered = users;
    if (query.country != null) filtered = filtered.where((u) => u.country == query.country).toList();
    if (query.platform != null) filtered = filtered.where((u) => u.platform == query.platform).toList();
    if (query.plan != null) filtered = filtered.where((u) => _planCategory(u) == query.plan).toList();

    final totalRegisteredUsers = filtered.length;

    final totalStorageUsedBytes = filtered.fold<int>(0, (acc, u) => acc + u.storageUsedBytes);
    final averageStoragePerUserBytes = totalRegisteredUsers == 0 ? 0 : (totalStorageUsedBytes / totalRegisteredUsers).round();

    final usersNearStorageLimit = filtered.where((u) {
      if (u.storageLimitBytes <= 0) return false;
      final ratio = u.storageUsedBytes / u.storageLimitBytes;
      return ratio >= 0.85;
    }).length;

    final aiTokensUsedThisMonth = filtered.fold<int>(0, (acc, u) => acc + u.aiTokensThisMonth);

    // A deliberately rough, executive-level estimate.
    // If/when wired to Supabase, this should come from a billing/usage summary view.
    final aiEstimatedCostThisMonthUsd = aiTokensUsedThisMonth / 1e6 * 2.50;

    final usersNearAiLimit = filtered.where((u) => u.aiTokensThisMonth >= 750000).length;

    final freeUsers = filtered.where((u) => _planCategory(u) == 'Free').length;
    final trialUsers = filtered.where((u) => _planCategory(u) == 'Trial').length;
    final paidUsers = filtered.where((u) => _planCategory(u) == 'Paid').length;
    final cancelledUsers = filtered.where((u) => _planCategory(u) == 'Cancelled').length;
    final failedPayments = filtered.where((u) => u.billingStatus == 'past_due').length;

    final now = _now;
    final newUsersThisWeek = filtered.where((u) => u.createdAt.isAfter(now.subtract(const Duration(days: 7)))).length;
    final newUsersThisMonth = filtered.where((u) => u.createdAt.isAfter(now.subtract(const Duration(days: 30)))).length;

    // Active users are mock signals based on lastActiveAt recency.
    final dailyActiveUsers = filtered.where((u) => (u.lastActiveAt?.isAfter(now.subtract(const Duration(days: 1))) ?? false)).length;
    final weeklyActiveUsers = filtered.where((u) => (u.lastActiveAt?.isAfter(now.subtract(const Duration(days: 7))) ?? false)).length;
    final monthlyActiveUsers = filtered.where((u) => (u.lastActiveAt?.isAfter(now.subtract(const Duration(days: 30))) ?? false)).length;

    final userGrowth = _buildGrowthSeries(totalRegisteredUsers: totalRegisteredUsers, rangeDays: query.range.days, now: now);

    final platformUsage = <String, int>{'iOS': 0, 'Android': 0, 'Web': 0};
    for (final u in filtered) {
      platformUsage[u.platform] = (platformUsage[u.platform] ?? 0) + 1;
    }

    final featureUsage = _buildFeatureUsage(filtered, query.range);
    final countryUsage = _buildCountryUsage(filtered);
    final alerts = _buildAlerts(filtered);
    final systemStatus = _buildSystemStatus(now);

    return DashboardSnapshot(
      query: query,
      totalRegisteredUsers: totalRegisteredUsers,
      newUsersThisWeek: newUsersThisWeek,
      newUsersThisMonth: newUsersThisMonth,
      dailyActiveUsers: dailyActiveUsers,
      weeklyActiveUsers: weeklyActiveUsers,
      monthlyActiveUsers: monthlyActiveUsers,
      userGrowth: userGrowth,
      totalStorageUsedBytes: totalStorageUsedBytes,
      averageStoragePerUserBytes: averageStoragePerUserBytes,
      usersNearStorageLimit: usersNearStorageLimit,
      aiTokensUsedThisMonth: aiTokensUsedThisMonth,
      aiEstimatedCostThisMonthUsd: aiEstimatedCostThisMonthUsd,
      usersNearAiLimit: usersNearAiLimit,
      freeUsers: freeUsers,
      trialUsers: trialUsers,
      paidUsers: paidUsers,
      cancelledUsers: cancelledUsers,
      failedPayments: failedPayments,
      countryUsage: countryUsage,
      platformUsage: platformUsage,
      featureUsage: featureUsage,
      alerts: alerts,
      systemStatus: systemStatus,
      generatedAt: now,
    );
  }

  String _planCategory(UserAccountSummary u) {
    // Keep this mapping aligned with control-site billing summary views.
    if (u.accountStatus == 'locked' || u.accountStatus == 'suspended') return 'Cancelled';
    if (u.plan.toLowerCase() == 'free') return 'Free';
    if (u.plan.toLowerCase().contains('trial')) return 'Trial';
    return 'Paid';
  }

  List<DashboardTimeseriesPoint> _buildGrowthSeries({required int totalRegisteredUsers, required int rangeDays, required DateTime now}) {
    if (rangeDays <= 1) {
      return [DashboardTimeseriesPoint(date: DateTime(now.year, now.month, now.day), value: totalRegisteredUsers)];
    }

    // Build a smooth-ish curve ending at totalRegisteredUsers.
    final points = <DashboardTimeseriesPoint>[];
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: rangeDays - 1));
    final base = (totalRegisteredUsers * 0.82).round().clamp(0, totalRegisteredUsers);
    for (int i = 0; i < rangeDays; i++) {
      final d = start.add(Duration(days: i));
      final t = i / (rangeDays - 1);
      final growth = base + ((totalRegisteredUsers - base) * (0.25 + 0.75 * t)).round();
      // Add small deterministic wobble.
      final wobble = ((i % 5) - 2) * (rangeDays >= 30 ? 3 : 1);
      points.add(DashboardTimeseriesPoint(date: d, value: (growth + wobble).clamp(0, totalRegisteredUsers)));
    }
    return points;
  }

  Map<String, int> _buildFeatureUsage(List<UserAccountSummary> users, AdminDateRangePreset range) {
    // Only show totals / event counts. No content.
    final multiplier = switch (range) {
      AdminDateRangePreset.today => 1,
      AdminDateRangePreset.days7 => 6,
      AdminDateRangePreset.days30 => 20,
      AdminDateRangePreset.days90 => 55,
    };

    int scaled(int base) => (base * multiplier * 0.7).round();

    final documents = users.fold<int>(0, (a, u) => a + u.documentCount);
    final appointments = users.fold<int>(0, (a, u) => a + u.appointmentCount);
    final meds = users.fold<int>(0, (a, u) => a + u.medicationCount);
    final vax = users.fold<int>(0, (a, u) => a + u.vaccinationCount);

    return {
      'Documents': scaled(documents + 40),
      'Appointments': scaled(appointments + 30),
      'Medications': scaled(meds + 25),
      'Vaccinations': scaled(vax + 18),
      'Blood Pressure': scaled((users.length * 8) + 45),
      'Timeline': scaled((users.length * 12) + 70),
      'Body Map': scaled((users.length * 4) + 22),
      'AI Assistant': scaled((users.fold<int>(0, (a, u) => a + (u.aiTokensThisMonth ~/ 4000))) + 60),
      'Search': scaled((users.length * 18) + 90),
      'Export': scaled((users.length * 2) + 12),
    };
  }

  List<CountryUsageRow> _buildCountryUsage(List<UserAccountSummary> users) {
    // Group <10-user countries into "Other" to reduce re-identification risk.
    final byCountry = <String, List<UserAccountSummary>>{};
    for (final u in users) {
      (byCountry[u.country] ??= []).add(u);
    }

    final rows = <CountryUsageRow>[];
    var otherUsers = <UserAccountSummary>[];
    byCountry.forEach((country, list) {
      if (list.length < 10) {
        otherUsers = [...otherUsers, ...list];
        return;
      }
      rows.add(_countryRow(country, list));
    });

    if (otherUsers.isNotEmpty) {
      rows.add(_countryRow('Other', otherUsers));
    }

    rows.sort((a, b) => b.totalUsers.compareTo(a.totalUsers));
    return rows;
  }

  CountryUsageRow _countryRow(String country, List<UserAccountSummary> list) {
    final now = _now;
    final totalUsers = list.length;
    final activeUsers = list.where((u) => (u.lastActiveAt?.isAfter(now.subtract(const Duration(days: 30))) ?? false)).length;
    final storageUsedBytes = list.fold<int>(0, (a, u) => a + u.storageUsedBytes);
    final aiTokensUsed = list.fold<int>(0, (a, u) => a + u.aiTokensThisMonth);
    final paidUsers = list.where((u) => _planCategory(u) == 'Paid').length;
    return CountryUsageRow(
      country: country,
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      storageUsedBytes: storageUsedBytes,
      aiTokensUsed: aiTokensUsed,
      paidUsers: paidUsers,
    );
  }

  List<AlertRow> _buildAlerts(List<UserAccountSummary> users) {
    final overStorage = users.where((u) => u.storageLimitBytes > 0 && u.storageUsedBytes > u.storageLimitBytes).length;
    final nearAi = users.where((u) => u.aiTokensThisMonth >= 750000).length;
    final paymentFailures = users.where((u) => u.billingStatus == 'past_due').length;

    // Mock operational alerts derived from failures.
    final highFailedUploadRate = users.where((u) => u.failedUploadCount7d >= 6).length;
    final highFailedSyncRate = users.where((u) => u.failedSyncCount7d >= 6).length;

    // Suspicious spikes: extremely high tokens + some failures.
    final suspiciousSpikes = users.where((u) => u.aiTokensThisMonth >= 900000 && (u.failedSyncCount7d + u.failedUploadCount7d) >= 6).length;

    return [
      AlertRow(type: 'Users over storage limit', count: overStorage, severity: overStorage > 0 ? 'high' : 'low', note: 'Requires support outreach or plan upgrade.'),
      AlertRow(type: 'Users near AI limit', count: nearAi, severity: nearAi >= 3 ? 'medium' : 'low', note: 'Monitor usage or adjust limits per plan.'),
      AlertRow(type: 'High failed upload rate', count: highFailedUploadRate, severity: highFailedUploadRate >= 5 ? 'medium' : 'low', note: 'Investigate client/network regressions.'),
      AlertRow(type: 'High failed sync rate', count: highFailedSyncRate, severity: highFailedSyncRate >= 6 ? 'medium' : 'low', note: 'Check background jobs and client retries.'),
      AlertRow(type: 'Payment failures', count: paymentFailures, severity: paymentFailures > 0 ? 'high' : 'low', note: 'Review dunning & billing webhooks.'),
      AlertRow(type: 'Suspicious usage spikes', count: suspiciousSpikes, severity: suspiciousSpikes > 0 ? 'high' : 'low', note: 'Check abuse signals and rate limits.'),
    ];
  }

  List<SystemStatusCard> _buildSystemStatus(DateTime now) {
    String s(int i) => (i % 13 == 0) ? 'Warn' : 'OK';
    return [
      SystemStatusCard(label: 'App API status', status: s(1), detail: 'Latency stable; errors within threshold.', updatedAt: now.subtract(const Duration(minutes: 3))),
      SystemStatusCard(label: 'Supabase status', status: 'OK', detail: 'Auth + DB reachable (mock).', updatedAt: now.subtract(const Duration(minutes: 5))),
      SystemStatusCard(label: 'Storage status', status: s(2), detail: 'Upload success rate 99.2% (mock).', updatedAt: now.subtract(const Duration(minutes: 7))),
      SystemStatusCard(label: 'AI service status', status: s(3), detail: 'No elevated timeouts (mock).', updatedAt: now.subtract(const Duration(minutes: 9))),
      SystemStatusCard(label: 'Last sync job status', status: 'OK', detail: 'Last run succeeded.', updatedAt: now.subtract(const Duration(minutes: 12))),
      SystemStatusCard(label: 'Error rate (24h)', status: s(4), detail: '0.7% requests errored (mock).', updatedAt: now.subtract(const Duration(minutes: 4))),
    ];
  }

  // ------------------------------
  // Storage
  // ------------------------------

  @override
  Future<StorageSnapshot> getStorageSnapshot({required StorageQuery query}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));

    final users = await listUsers(query: const UserListQuery(search: '', filters: UserListFilters()), limit: 700);
    final totalStorage = users.fold<int>(0, (sum, u) => sum + u.storageUsedBytes);
    final totalDocs = users.fold<int>(0, (sum, u) => sum + u.documentCount);
    final avgStoragePerUser = users.isEmpty ? 0 : (totalStorage / users.length).round();

    int overLimit = 0;
    int over80 = 0;
    for (final u in users) {
      if (u.storageLimitBytes <= 0) continue;
      final pct = u.storageUsedBytes / u.storageLimitBytes;
      if (pct > 1.0) overLimit++;
      if (pct >= 0.8) over80++;
    }

    // Month metrics: approximate based on selected range.
    final uploadsThisMonth = (users.length * (0.18 + _rng.nextDouble() * 0.10) * 30).round();
    final failedUploadsThisMonth = (uploadsThisMonth * (0.015 + _rng.nextDouble() * 0.02)).round();

    // Rough storage cost: choose an internal blended rate per GB-month.
    final gb = 1024 * 1024 * 1024;
    const blendedUsdPerGbMonth = 0.018; // mock-only; tune to your provider blend
    final estimatedCost = (totalStorage / gb) * blendedUsdPerGbMonth;

    // High usage users
    final highUsage = users
        .map(
          (u) => StorageHighUsageUserRow(
            userId: u.userId,
            email: u.email,
            country: u.country,
            plan: u.plan,
            storageUsedBytes: u.storageUsedBytes,
            storageLimitBytes: u.storageLimitBytes,
            documentCount: u.documentCount,
            lastUploadAt: _now.subtract(Duration(days: _rng.nextInt(40), hours: _rng.nextInt(24))),
            failedUploadCount: u.failedUploadCount7d + _rng.nextInt(12),
            accountStatus: u.accountStatus,
          ),
        )
        .toList();
    highUsage.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));

    // Storage by plan
    final byPlanMap = <String, List<UserAccountSummary>>{};
    for (final u in users) {
      byPlanMap.putIfAbsent(u.plan, () => []).add(u);
    }
    final byPlan = byPlanMap.entries.map((e) {
      final list = e.value;
      final total = list.fold<int>(0, (sum, u) => sum + u.storageUsedBytes);
      final avg = list.isEmpty ? 0 : (total / list.length).round();
      int near = 0;
      int over = 0;
      for (final u in list) {
        if (u.storageLimitBytes <= 0) continue;
        final pct = u.storageUsedBytes / u.storageLimitBytes;
        if (pct >= 0.8) near++;
        if (pct > 1.0) over++;
      }
      return StorageByPlanRow(plan: e.key, users: list.length, totalStorageBytes: total, avgStoragePerUserBytes: avg, usersNearLimit: near, usersOverLimit: over);
    }).toList();
    byPlan.sort((a, b) => b.totalStorageBytes.compareTo(a.totalStorageBytes));

    // Storage by country (group <10 into Other)
    final byCountryMap = <String, List<UserAccountSummary>>{};
    for (final u in users) {
      byCountryMap.putIfAbsent(u.country, () => []).add(u);
    }
    final otherUsers = <UserAccountSummary>[];
    final countries = <StorageByCountryRow>[];
    for (final e in byCountryMap.entries) {
      if (e.value.length < 10) {
        otherUsers.addAll(e.value);
        continue;
      }
      final total = e.value.fold<int>(0, (sum, u) => sum + u.storageUsedBytes);
      final docs = e.value.fold<int>(0, (sum, u) => sum + u.documentCount);
      final paid = e.value.where((u) => u.plan.toLowerCase().contains('pro') || u.plan.toLowerCase().contains('team') || u.plan.toLowerCase().contains('enterprise') || u.plan.toLowerCase().contains('premium') || u.plan.toLowerCase().contains('family')).length;
      countries.add(StorageByCountryRow(country: e.key, users: e.value.length, totalStorageBytes: total, avgStorageBytes: (total / e.value.length).round(), documentCount: docs, paidUsers: paid));
    }
    if (otherUsers.isNotEmpty) {
      final total = otherUsers.fold<int>(0, (sum, u) => sum + u.storageUsedBytes);
      final docs = otherUsers.fold<int>(0, (sum, u) => sum + u.documentCount);
      final paid = otherUsers.where((u) => u.plan.toLowerCase().contains('pro') || u.plan.toLowerCase().contains('team') || u.plan.toLowerCase().contains('enterprise') || u.plan.toLowerCase().contains('premium') || u.plan.toLowerCase().contains('family')).length;
      countries.add(StorageByCountryRow(country: 'Other', users: otherUsers.length, totalStorageBytes: total, avgStorageBytes: (total / otherUsers.length).round(), documentCount: docs, paidUsers: paid));
    }
    countries.sort((a, b) => b.totalStorageBytes.compareTo(a.totalStorageBytes));

    // Upload errors (safe only)
    String pseudo(String raw) {
      final n = raw.replaceAll(RegExp(r'[^0-9]'), '');
      final tail = (n.length >= 4) ? n.substring(n.length - 4) : n.padLeft(4, '0');
      return 'U-***$tail';
    }

    final errorCodes = const ['UPLOAD_TIMEOUT', 'QUOTA_EXCEEDED', 'NETWORK_LOSS', 'INVALID_MIME', 'SIGNED_URL_FAILED', 'SERVER_5XX'];
    final buckets = const ['<1MB', '1–10MB', '10–50MB', '50–200MB', '>200MB'];
    final results = const ['failed', 'retry_scheduled', 'blocked', 'resolved'];
    final uploadErrors = List.generate(40, (i) {
      final u = users[(i * 13) % users.length];
      return StorageUploadErrorRow(
        occurredAt: _now.subtract(Duration(hours: i * 5 + _rng.nextInt(4))),
        userPseudonym: pseudo(u.userId),
        platform: u.platform,
        appVersion: u.appVersion,
        errorCode: errorCodes[_rng.nextInt(errorCodes.length)],
        result: results[_rng.nextInt(results.length)],
        fileSizeBucket: buckets[_rng.nextInt(buckets.length)],
        storageUsedBytesAtTime: u.storageUsedBytes,
      );
    });

    uploadErrors.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return StorageSnapshot(
      query: query,
      totalStorageUsedBytes: totalStorage,
      totalDocumentCount: totalDocs,
      averageStoragePerUserBytes: avgStoragePerUser,
      usersOverStorageLimit: overLimit,
      usersOver80PercentStorageLimit: over80,
      uploadsThisMonth: uploadsThisMonth,
      failedUploadsThisMonth: failedUploadsThisMonth,
      estimatedStorageCostUsd: estimatedCost,
      highUsageUsers: highUsage.take(60).toList(),
      storageByPlan: byPlan,
      storageByCountry: countries,
      uploadErrors: uploadErrors,
      generatedAt: _now,
    );
  }

  @override
  Future<SecurityChecklistSnapshot> getSecurityChecklistSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    // Best-effort: if we can read audit logs through RLS as the current admin,
    // audit logging is likely configured correctly.
    DateTime? lastAuditAt;
    DateTime? lastLoginAt;
    try {
      final logs = await listAuditLogs(query: const AuditLogQuery(), limit: 50);
      if (logs.isNotEmpty) {
        lastAuditAt = logs.first.createdAt;
        final login = logs.firstWhere(
          (l) => l.actionType == 'admin_login' && l.result == 'success',
          orElse: () => logs.first,
        );
        if (login.actionType == 'admin_login') lastLoginAt = login.createdAt;
      }
    } catch (e) {
      debugPrint('MockAdminRepository.getSecurityChecklistSnapshot audit probe failed: $e');
    }

    final active = _supportSessions.where((s) => s.status == SupportSessionStatus.active).length;
    final expired = _supportSessions.where((s) => s.status == SupportSessionStatus.expired).length;

    // This mock repository cannot truly validate RLS. We return null to avoid a
    // false sense of certainty.
    return SecurityChecklistSnapshot(
      rlsEnabled: null,
      adminAuthEnabled: true,
      auditLoggingEnabled: true,
      noServiceRoleKeyDetected: true,
      noRawHealthTableAccessDetected: true,
      lastAdminLoginAt: lastLoginAt,
      lastAuditEventAt: lastAuditAt,
      activeSupportSessions: active,
      expiredSupportSessions: expired,
    );
  }
}

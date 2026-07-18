import 'dart:async';

import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_client.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/utils/http_probe.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/nav.dart';
import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner-only production readiness & data health verification.
///
/// This page is intentionally privacy-safe:
/// - It never renders raw payload values from RPCs.
/// - It only shows row counts, field names, durations, and allow-listed aggregates.
class ProductionReadinessPage extends StatefulWidget {
  const ProductionReadinessPage({super.key});

  @override
  State<ProductionReadinessPage> createState() => _ProductionReadinessPageState();
}

class _ProductionReadinessPageState extends State<ProductionReadinessPage> {
  static const Map<String, String> _rpcChecks = <String, String>{
    'admin_get_dashboard_metrics()': 'admin_get_dashboard_metrics',
    'admin_get_user_usage_summary()': 'admin_get_user_usage_summary',
    'admin_get_usage_events_summary()': 'admin_get_usage_events_summary',
    'admin_get_ai_usage_summary()': 'admin_get_ai_usage_summary',
    'admin_get_ai_usage_summary_v2()': 'admin_get_ai_usage_summary_v2',
    'admin_get_billing_summary()': 'admin_get_billing_summary',
    'admin_get_country_usage_summary()': 'admin_get_country_usage_summary',
    'admin_get_storage_summary()': 'admin_get_storage_summary',
    'admin_get_compliance_summary()': 'admin_get_compliance_summary',
    'admin_get_support_summary()': 'admin_get_support_summary',
    'admin_get_plan_permission_summary()': 'admin_get_plan_permission_summary',
    'admin_get_audit_summary()': 'admin_get_audit_summary',
    'admin_get_system_health_summary()': 'admin_get_system_health_summary',
  };

  // Only these aggregate keys may display numeric values.
  static const Set<String> _dashboardAllowListedAggregateKeys = <String>{
    'total_users',
    'active_users',
    'new_users',
    'new_users_7d',
    'usage_events_30d',
    'documents_30d',
    'support_sessions_open',
    'audit_events_30d',
    'ai_requests_30d',
  };

  bool _isRunning = false;
  DateTime? _lastRunAt;
  String? _fatalError;

  bool? _isActiveAdmin;
  String? _isActiveAdminError;

  final Map<String, _RpcProbeResult> _rpcResults = <String, _RpcProbeResult>{};
  Map<String, num>? _dashboardAllowListedAggregates;

  HttpProbeResult? _revenueCatWebhookProbe;
  String? _revenueCatWebhookProbeError;
  Map<String, dynamic>? _revenueCatHealthRow;
  String? _revenueCatHealthError;

  @override
  void initState() {
    super.initState();
    // In release, do not auto-run. In debug, auto-run once for convenience.
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runAll());
    }
  }

  Future<void> _runAll() async {
    if (_isRunning) return;
    final auth = context.read<AdminAuthStore>();
    if (!auth.isAuthorized || auth.role != AdminRole.owner) return;

    setState(() {
      _isRunning = true;
      _fatalError = null;
      _isActiveAdmin = null;
      _isActiveAdminError = null;
      _rpcResults.clear();
      _dashboardAllowListedAggregates = null;
    });

    try {
      final client = ControlSupabaseClient.tryGet();
      if (client == null) throw StateError('Supabase client unavailable (not initialized or blocked by security guard).');

      // Check: public.is_active_admin() (boolean).
      try {
        final started = DateTime.now();
        final res = await client.rpc('is_active_admin');
        final durMs = DateTime.now().difference(started).inMilliseconds;
        if (!mounted) return;
        setState(() {
          _isActiveAdmin = res is bool ? res : null;
          _isActiveAdminError = (res is bool) ? null : 'Unexpected response type (${res.runtimeType}) after ${durMs}ms';
        });
      } catch (e) {
        debugPrint('ProductionReadiness: is_active_admin() failed: $e');
        if (!mounted) return;
        setState(() {
          _isActiveAdmin = null;
          _isActiveAdminError = formatAdminSafeError(e);
        });
      }

      // RPC checks: run sequentially to be gentle on rate limits, but still measure duration.
      for (final entry in _rpcChecks.entries) {
        final label = entry.key;
        final fn = entry.value;
        final r = await _callRpc(client, fn);
        if (!mounted) return;
        setState(() => _rpcResults[label] = r);
        if (fn == 'admin_get_dashboard_metrics') {
          final allowListed = _extractAllowListedAggregates(r.rawResult);
          if (allowListed != null && allowListed.isNotEmpty) {
            setState(() => _dashboardAllowListedAggregates = allowListed);
          }
        }
      }

      // RevenueCat deployment checks (privacy-safe aggregates only).
      await _probeRevenueCat(client);

      if (!mounted) return;
      setState(() => _lastRunAt = DateTime.now().toUtc());
    } catch (e) {
      debugPrint('ProductionReadiness: fatal: $e');
      if (!mounted) return;
      setState(() => _fatalError = formatAdminSafeError(e));
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _probeRevenueCat(SupabaseClient client) async {
    // 1) Webhook edge function deployed check (GET is privacy-safe).
    try {
      final base = SupabaseConfig.resolvedSupabaseProjectUrl;
      final url = Uri.parse(base).replace(path: '/functions/v1/revenuecat_webhook');
      final res = await httpProbe(url, method: 'GET');
      if (!mounted) return;
      setState(() {
        _revenueCatWebhookProbe = res;
        _revenueCatWebhookProbeError = res.ok ? null : (res.message ?? res.exceptionType);
      });
    } catch (e) {
      debugPrint('ProductionReadiness: RevenueCat webhook probe failed: $e');
      if (!mounted) return;
      setState(() {
        _revenueCatWebhookProbe = null;
        _revenueCatWebhookProbeError = formatAdminSafeError(e);
      });
    }

    // 2) Aggregate-only sync health view.
    try {
      final row = await client.from('revenuecat_sync_health_v1').select().maybeSingle();
      if (!mounted) return;
      setState(() {
        _revenueCatHealthRow = row;
        _revenueCatHealthError = null;
      });
    } catch (e) {
      debugPrint('ProductionReadiness: revenuecat_sync_health_v1 unavailable: $e');
      if (!mounted) return;
      setState(() {
        _revenueCatHealthRow = null;
        _revenueCatHealthError = formatAdminSafeError(e);
      });
    }
  }

  Future<_RpcProbeResult> _callRpc(SupabaseClient client, String functionName) async {
    final started = DateTime.now();
    try {
      final res = await client.rpc(functionName);
      return _RpcProbeResult.ok(
        rawResult: res,
        rowCount: _safeRowCount(res),
        payloadKeys: _safePayloadKeys(res),
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    } catch (e) {
      debugPrint('ProductionReadiness: RPC $functionName failed: $e');
      return _RpcProbeResult.err(
        safeErrorMessage: formatAdminSafeError(e),
        durationMs: DateTime.now().difference(started).inMilliseconds,
      );
    }
  }

  int _safeRowCount(Object? result) {
    if (result == null) return 0;
    if (result is List) return result.length;
    if (result is Map) return 1;
    return 1;
  }

  List<String> _safePayloadKeys(Object? result) {
    if (result is Map) return result.keys.map((k) => k.toString()).toList()..sort();
    if (result is List) {
      if (result.isEmpty) return const <String>[];
      final first = result.first;
      if (first is Map) return first.keys.map((k) => k.toString()).toList()..sort();
    }
    return const <String>[];
  }

  Map<String, num>? _extractAllowListedAggregates(Object? rpcResult) {
    // Only allow-listed numeric aggregates.
    if (rpcResult is Map) {
      final out = <String, num>{};
      for (final e in rpcResult.entries) {
        final k = e.key.toString();
        if (!_dashboardAllowListedAggregateKeys.contains(k)) continue;
        final v = e.value;
        if (v is num) out[k] = v;
      }
      return out;
    }
    if (rpcResult is List && rpcResult.isNotEmpty && rpcResult.first is Map) {
      final first = rpcResult.first as Map;
      final out = <String, num>{};
      for (final e in first.entries) {
        final k = e.key.toString();
        if (!_dashboardAllowListedAggregateKeys.contains(k)) continue;
        final v = e.value;
        if (v is num) out[k] = v;
      }
      return out;
    }
    return null;
  }

  int? _readHealthInt(String key) {
    final v = _revenueCatHealthRow?[key];
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthStore>();
    final store = context.watch<AdminStore>();
    final cs = Theme.of(context).colorScheme;

    // Router already enforces owner-only for this route. Keep defensive UI gate.
    if (!auth.isSignedIn) return const SizedBox.shrink();
    if (!auth.isAuthorized || auth.role != AdminRole.owner) {
      return AdminPageScaffold(
        title: 'Production Readiness',
        subtitle: 'Access denied.',
        child: AdminCard(child: Text('Owner access required.', style: Theme.of(context).textTheme.bodyMedium)),
      );
    }

    final clientAvailable = ControlSupabaseClient.tryGet() != null;
    final url = SupabaseConfig.resolvedSupabaseProjectUrl;
    final urlHost = SupabaseConfig.resolvedSupabaseHost;
    final urlHasRestSuffix = url.contains('/rest/v1') || url.endsWith('/rest/v1');

    final configSource = SupabaseConfig.configSourceSummary;
    final serviceRoleDetected = SupabaseConfig.serviceRoleDetected || AdminAuthStore.supabaseServiceRoleKey.isNotEmpty;

    final dataSources = <_PageSourceRowData>[
      _PageSourceRowData(label: 'Dashboard', route: AppRoutes.dashboard, key: AdminDataSourceKey.dashboard),
      _PageSourceRowData(label: 'Users', route: AppRoutes.users, key: AdminDataSourceKey.users),
      _PageSourceRowData(label: 'Usage Analytics', route: AppRoutes.usageAnalytics, key: AdminDataSourceKey.usageAnalytics),
      _PageSourceRowData(label: 'Storage', route: AppRoutes.storage, key: AdminDataSourceKey.storage),
      _PageSourceRowData(label: 'AI Usage', route: AppRoutes.aiUsage, key: AdminDataSourceKey.aiUsage),
      _PageSourceRowData(label: 'Billing', route: AppRoutes.billing, key: AdminDataSourceKey.billing),
      _PageSourceRowData(label: 'Support', route: AppRoutes.support, key: AdminDataSourceKey.support),
      _PageSourceRowData(label: 'Compliance', route: AppRoutes.compliance, key: AdminDataSourceKey.compliance),
      _PageSourceRowData(label: 'System Health', route: AppRoutes.systemHealth, key: AdminDataSourceKey.systemHealth),
      _PageSourceRowData(label: 'Audit Logs', route: AppRoutes.auditLogs, key: AdminDataSourceKey.auditLogs),
      _PageSourceRowData(label: 'Plans & Permissions', route: AppRoutes.plansPermissions, key: AdminDataSourceKey.plansPermissions),
      _PageSourceRowData(label: 'Website/CMS Status', route: AppRoutes.websiteStatus, key: AdminDataSourceKey.websiteCms),
    ];

    final anyMock = dataSources.any((r) => store.dataSource(r.key).kind == AdminDataSourceKind.mock);
    final anyNotInstrumented = dataSources.any((r) => store.dataSource(r.key).kind == AdminDataSourceKind.notInstrumented);
    final anyError = dataSources.any((r) => store.dataSource(r.key).kind == AdminDataSourceKind.error);

    final rbacPass = AdminRbac.canAccessRoute(auth.role!, AppRoutes.productionReadiness);

    return AdminPageScaffold(
      title: 'Production Readiness',
      subtitle: 'Owner-only release-safe checks (no raw payloads; aggregates only).',
      actions: [
        FilledButton.icon(
          onPressed: _isRunning ? null : _runAll,
          icon: Icon(Icons.play_arrow_rounded, color: cs.onPrimary),
          label: Text(
            _isRunning ? 'Running…' : 'Run checks',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800),
          ),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
        ),
      ],
      child: ListView(
        children: [
          AdminCard(
            header: Row(
              children: [
                Icon(Icons.webhook_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Text('RevenueCat readiness', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy-safe verification: function deployment probe + aggregate webhook/entitlement counters. No raw payloads are shown.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MiniKpi(
                      label: 'Webhook function',
                      value: _revenueCatWebhookProbe == null
                          ? '—'
                          : (_revenueCatWebhookProbe!.ok ? 'Reachable' : 'Unreachable'),
                      icon: Icons.http,
                      tone: _revenueCatWebhookProbe == null
                          ? _MiniKpiTone.neutral
                          : (_revenueCatWebhookProbe!.ok ? _MiniKpiTone.good : _MiniKpiTone.bad),
                      hint: _revenueCatWebhookProbe == null
                          ? null
                          : 'HTTP ${_revenueCatWebhookProbe!.statusCode ?? '-'} ${_revenueCatWebhookProbeError ?? ''}'.trim(),
                    ),
                    _MiniKpi(
                      label: 'Webhook rows',
                      value: _readHealthInt('webhook_event_rows')?.toString() ?? '—',
                      icon: Icons.table_rows_outlined,
                    ),
                    _MiniKpi(
                      label: 'Failed webhooks',
                      value: _readHealthInt('webhook_failed_rows')?.toString() ?? '—',
                      icon: Icons.error_outline_rounded,
                      tone: (_readHealthInt('webhook_failed_rows') ?? 0) > 0 ? _MiniKpiTone.bad : _MiniKpiTone.neutral,
                    ),
                    _MiniKpi(
                      label: 'Unmapped app_user_id',
                      value: _readHealthInt('webhook_unmapped_app_user_id_rows')?.toString() ?? '—',
                      icon: Icons.link_off_rounded,
                      tone: (_readHealthInt('webhook_unmapped_app_user_id_rows') ?? 0) > 0 ? _MiniKpiTone.warn : _MiniKpiTone.neutral,
                    ),
                  ],
                ),
                if (_revenueCatHealthError != null || _revenueCatWebhookProbeError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Notes: ${(_revenueCatHealthError ?? '').isNotEmpty ? 'healthView=$_revenueCatHealthError ' : ''}${(_revenueCatWebhookProbeError ?? '').isNotEmpty ? 'webhookProbe=$_revenueCatWebhookProbeError' : ''}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (anyMock || kReleaseMode)
            _WarningBanner(
              severity: anyMock ? _WarningSeverity.danger : _WarningSeverity.info,
              title: anyMock ? 'Mock data detected' : 'Release verification',
              message: anyMock
                  ? 'One or more pages are reporting a Mock data source. This must never happen in production.'
                  : 'This page is designed to work in release builds. Use it to validate live instrumentation before launch.',
            ),
          if (serviceRoleDetected)
            _WarningBanner(
              severity: _WarningSeverity.danger,
              title: 'SECURITY: Service role key detected',
              message: 'A SUPABASE_SERVICE_ROLE_KEY appears present in the client build. The app should fail closed. Remove it immediately.',
            ),
          if (_fatalError != null)
            _WarningBanner(
              severity: _WarningSeverity.danger,
              title: 'Fatal error',
              message: _fatalError!,
            ),
          AdminCard(
            header: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), gradient: LinearGradient(colors: [cs.primary, cs.tertiary])),
                  child: Icon(Icons.tune_rounded, color: cs.onPrimary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('A) Config checks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'config source used', value: configSource),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Supabase host', value: urlHost.isEmpty ? '—' : urlHost),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'anon/publishable key present', value: SupabaseConfig.resolvedAnonKeyPresent ? 'yes' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'service role key detected', value: serviceRoleDetected ? 'yes (BLOCKER)' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'CONTROL_SITE_BASE_URL present', value: SupabaseConfig.resolvedControlSiteBaseUrlPresent ? 'yes' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Supabase initialized', value: (SupabaseConfig.isInitialized && clientAvailable) ? 'yes' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'old wrong Supabase URL absent', value: urlHasRestSuffix ? 'no (BLOCKER)' : 'yes'),
                if (SupabaseConfig.runtimeJsonLoadAttempted) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'runtimeJson load', value: SupabaseConfig.runtimeJsonLoadError == null ? 'ok' : 'error'),
                  if (SupabaseConfig.runtimeJsonLoadError != null) ...[
                    const SizedBox(height: 6),
                    Text('runtimeJson error: ${SupabaseConfig.runtimeJsonLoadError}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            header: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), gradient: LinearGradient(colors: [cs.secondary, cs.primary])),
                  child: Icon(Icons.verified_user_outlined, color: cs.onPrimary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('B) Auth / admin checks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'signed in', value: auth.isSignedIn ? 'yes' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'auth.uid present', value: (auth.authUid ?? '').isNotEmpty ? 'yes' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'admin_users row found', value: auth.loginDiagnostics.adminUsersRowFound ? 'yes' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'role', value: auth.role?.name ?? '—'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'is_active', value: auth.isActive == true ? 'true' : 'false'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: Text('is_active_admin() result', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
                    _StatusPill(
                      kind: (_isActiveAdminError != null)
                          ? _PillKind.error
                          : (_isActiveAdmin == true)
                              ? _PillKind.ok
                              : (_isActiveAdmin == false)
                                  ? _PillKind.warn
                                  : _PillKind.neutral,
                      label: _isActiveAdminError != null ? 'error' : (_isActiveAdmin == null ? 'not run' : _isActiveAdmin == true ? 'true' : 'false'),
                    ),
                  ],
                ),
                if (_isActiveAdminError != null) ...[
                  const SizedBox(height: 6),
                  Text(_isActiveAdminError!, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'route RBAC check', value: rbacPass ? 'pass' : 'fail'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            header: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), gradient: LinearGradient(colors: [cs.tertiary, cs.secondary])),
                  child: Icon(Icons.api_rounded, color: cs.onPrimary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('C) RPC checks (admin session)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                if (_lastRunAt != null)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: _StatusPill(kind: _PillKind.neutral, label: 'Last: ${AdminFormatters.dateTime(_lastRunAt)}'),
                  ),
              ],
            ),
            child: Column(
              children: [
                for (final label in _rpcChecks.keys) ...[
                  _RpcRow(label: label, result: _rpcResults[label]),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
          if (_dashboardAllowListedAggregates != null && _dashboardAllowListedAggregates!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AdminCard(
              header: Text('Allow-listed dashboard aggregates', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _dashboardAllowListedAggregates!.entries
                    .map((e) => _MetricChip(label: e.key, value: e.value.toString()))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            header: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), gradient: LinearGradient(colors: [cs.primary, cs.secondary])),
                  child: Icon(Icons.table_chart_outlined, color: cs.onPrimary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('D) Page data-source checks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            child: Column(
              children: [
                if (anyMock)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _StatusPill(kind: _PillKind.error, label: 'Mock detected (BLOCKER)'),
                  )
                else if (anyError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _StatusPill(kind: _PillKind.warn, label: 'Some data sources error'),
                  )
                else if (anyNotInstrumented)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _StatusPill(kind: _PillKind.warn, label: 'Some sources not instrumented'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _StatusPill(kind: _PillKind.ok, label: 'All sources Live'),
                  ),
                SizedBox(
                  height: 460,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 980,
                        child: ListView.separated(
                          itemCount: dataSources.length + 1,
                          separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _TableHeaderRow(columns: const <String>['Page', 'Data source kind', 'Query/RPC', 'Row count', 'Last refreshed', 'Safe error']);
                            }
                            final row = dataSources[index - 1];
                            final st = store.dataSource(row.key);
                            return _TableDataRow(
                              pageLabel: row.label,
                              kind: st.kind.name,
                              query: st.queryName ?? '—',
                              rowCount: st.rowCount?.toString() ?? '—',
                              refreshed: AdminFormatters.dateTime(st.lastRefreshedAt),
                              error: st.safeErrorMessage ?? st.message ?? '—',
                              onTap: () => context.go(row.route),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            header: Text('E) Known-count verification (aggregates only)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This section only displays allow-listed aggregate counts when available. If a count is missing, it will show “not provided”.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                _KnownCountRow(label: 'auth users', value: _dashboardAllowListedAggregates?['total_users']),
                _KnownCountRow(label: 'family members', value: _dashboardAllowListedAggregates?['family_members']),
                _KnownCountRow(label: 'appointments', value: _dashboardAllowListedAggregates?['appointments']),
                _KnownCountRow(label: 'medications', value: _dashboardAllowListedAggregates?['medications']),
                _KnownCountRow(label: 'vaccinations', value: _dashboardAllowListedAggregates?['vaccinations']),
                _KnownCountRow(label: 'documents', value: _dashboardAllowListedAggregates?['documents_30d']),
                _KnownCountRow(label: 'usage events', value: _dashboardAllowListedAggregates?['usage_events_30d']),
                _KnownCountRow(label: 'entitlements', value: _dashboardAllowListedAggregates?['entitlements']),
                _KnownCountRow(label: 'audit events', value: _dashboardAllowListedAggregates?['audit_events_30d']),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            header: Text('F) Mock detection', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'release mode', value: kReleaseMode ? 'yes' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'any data source = Mock', value: anyMock ? 'yes (BLOCKER)' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'any data source = Not instrumented', value: anyNotInstrumented ? 'yes (warning)' : 'no'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'any data source = Error', value: anyError ? 'yes (warning)' : 'no'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'If you ever see Mock in release, check build flags (CURAVAULT_ALLOW_MOCK_FALLBACK) and whether backend RPCs/views are deployed.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageSourceRowData {
  const _PageSourceRowData({required this.label, required this.route, required this.key});
  final String label;
  final String route;
  final AdminDataSourceKey key;
}

@immutable
class _RpcProbeResult {
  const _RpcProbeResult._({required this.ok, required this.rowCount, required this.payloadKeys, required this.durationMs, this.safeErrorMessage, this.rawResult});
  final bool ok;
  final int rowCount;
  final List<String> payloadKeys;
  final int durationMs;
  final String? safeErrorMessage;
  final Object? rawResult;

  factory _RpcProbeResult.ok({required Object? rawResult, required int rowCount, required List<String> payloadKeys, required int durationMs}) =>
      _RpcProbeResult._(ok: true, rowCount: rowCount, payloadKeys: payloadKeys, durationMs: durationMs, rawResult: rawResult);

  factory _RpcProbeResult.err({required String safeErrorMessage, required int durationMs}) =>
      _RpcProbeResult._(ok: false, rowCount: 0, payloadKeys: const <String>[], durationMs: durationMs, safeErrorMessage: safeErrorMessage);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700))),
        const SizedBox(width: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(value, textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

enum _PillKind { ok, warn, error, neutral }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.kind, required this.label});
  final _PillKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    IconData icon;
    switch (kind) {
      case _PillKind.ok:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        icon = Icons.check_circle_outline;
        break;
      case _PillKind.warn:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        icon = Icons.warning_amber_rounded;
        break;
      case _PillKind.error:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        icon = Icons.error_outline;
        break;
      case _PillKind.neutral:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        icon = Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RpcRow extends StatelessWidget {
  const _RpcRow({required this.label, required this.result});
  final String label;
  final _RpcProbeResult? result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = result;

    final pill = (r == null)
        ? const _StatusPill(kind: _PillKind.neutral, label: 'not run')
        : r.ok
            ? const _StatusPill(kind: _PillKind.ok, label: 'success')
            : const _StatusPill(kind: _PillKind.error, label: 'failed');

    final sourceStatus = (r == null)
        ? '—'
        : (!r.ok)
            ? 'Error'
            : (r.rowCount == 0)
                ? 'Empty'
                : 'Live';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900))),
              pill,
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'row count', value: r == null ? '—' : '${r.rowCount}'),
              _MetricChip(label: 'fields', value: r == null ? '—' : (r.payloadKeys.isEmpty ? '—' : r.payloadKeys.join(', '))),
              _MetricChip(label: 'duration', value: r == null ? '—' : '${r.durationMs}ms'),
              _MetricChip(label: 'status', value: sourceStatus),
            ],
          ),
          if (r != null && !r.ok && (r.safeErrorMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.safeErrorMessage!, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

enum _MiniKpiTone { neutral, good, warn, bad }

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.label, required this.value, required this.icon, this.tone = _MiniKpiTone.neutral, this.hint});
  final String label;
  final String value;
  final IconData icon;
  final _MiniKpiTone tone;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surface;
    final border = cs.outlineVariant.withValues(alpha: 0.35);

    Color iconColor;
    switch (tone) {
      case _MiniKpiTone.good:
        iconColor = Colors.green;
        break;
      case _MiniKpiTone.warn:
        iconColor = cs.tertiary;
        break;
      case _MiniKpiTone.bad:
        iconColor = cs.error;
        break;
      case _MiniKpiTone.neutral:
        iconColor = cs.primary;
        break;
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );

    if (hint == null || hint!.trim().isEmpty) return content;
    return Tooltip(message: hint!, child: content);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(value, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

enum _WarningSeverity { info, danger }

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.severity, required this.title, required this.message});
  final _WarningSeverity severity;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = severity == _WarningSeverity.danger ? cs.errorContainer : cs.surfaceContainerHighest;
    final fg = severity == _WarningSeverity.danger ? cs.onErrorContainer : cs.onSurface;
    final icon = severity == _WarningSeverity.danger ? Icons.warning_amber_rounded : Icons.info_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({required this.columns});
  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: columns
            .map(
              (c) => Expanded(
                child: Text(c, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TableDataRow extends StatelessWidget {
  const _TableDataRow({required this.pageLabel, required this.kind, required this.query, required this.rowCount, required this.refreshed, required this.error, required this.onTap});

  final String pageLabel;
  final String kind;
  final String query;
  final String rowCount;
  final String refreshed;
  final String error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: cs.primary.withValues(alpha: 0.06),
      hoverColor: cs.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text(pageLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800))),
            Expanded(child: Text(kind, style: Theme.of(context).textTheme.labelLarge)),
            Expanded(child: Text(query, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge)),
            Expanded(child: Text(rowCount, style: Theme.of(context).textTheme.labelLarge)),
            Expanded(child: Text(refreshed, style: Theme.of(context).textTheme.labelLarge)),
            Expanded(child: Text(error, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
          ],
        ),
      ),
    );
  }
}

class _KnownCountRow extends StatelessWidget {
  const _KnownCountRow({required this.label, required this.value});
  final String label;
  final num? value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700))),
          Text(value == null ? 'not provided' : value.toString(), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

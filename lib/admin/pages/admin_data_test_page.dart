import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_client.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDataTestPage extends StatefulWidget {
  const AdminDataTestPage({super.key});

  @override
  State<AdminDataTestPage> createState() => _AdminDataTestPageState();
}

class _AdminDataTestPageState extends State<AdminDataTestPage> {
  static const _rpcNames = <String, String>{
    'admin_get_dashboard_metrics()': 'admin_get_dashboard_metrics',
    'admin_get_user_usage_summary()': 'admin_get_user_usage_summary',
    'admin_get_usage_events_summary()': 'admin_get_usage_events_summary',
    'admin_get_billing_summary()': 'admin_get_billing_summary',
    'admin_get_country_usage_summary()': 'admin_get_country_usage_summary',
    'admin_get_system_health_summary()': 'admin_get_system_health_summary',
  };

  bool _isLoading = false;
  bool? _isActiveAdmin;
  Object? _activeAdminError;

  final Map<String, _RpcTestResult> _results = {};

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  String _roleLabel(AdminRole? role) {
    if (role == null) return '—';
    return switch (role) {
      AdminRole.owner => 'owner',
      AdminRole.admin => 'admin',
      AdminRole.support => 'support',
      AdminRole.billing => 'billing',
      AdminRole.compliance => 'compliance',
      AdminRole.readOnly => 'read_only',
    };
  }

  Future<void> _run() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _activeAdminError = null;
      _isActiveAdmin = null;
      _results.clear();
    });

    try {
      final client = ControlSupabaseClient.tryGet();
      if (client == null) {
        throw StateError('Supabase client unavailable (not initialized or blocked by security guard).');
      }

      // Verify public.is_active_admin() is callable and returns a boolean.
      try {
        final res = await client.rpc('is_active_admin');
        setState(() => _isActiveAdmin = (res is bool) ? res : null);
      } catch (e) {
        debugPrint('AdminDataTest: is_active_admin() failed: $e');
        setState(() {
          _activeAdminError = e;
          _isActiveAdmin = null;
        });
      }

      for (final entry in _rpcNames.entries) {
        final label = entry.key;
        final fn = entry.value;
        final result = await _callRpc(client, fn);
        if (!mounted) return;
        setState(() => _results[label] = result);
      }
    } catch (e) {
      debugPrint('AdminDataTest: fatal: $e');
      if (!mounted) return;
      setState(() {
        _activeAdminError ??= e;
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<_RpcTestResult> _callRpc(SupabaseClient client, String functionName) async {
    final startedAt = DateTime.now();
    try {
      final res = await client.rpc(functionName);
      final rowCount = _safeRowCount(res);
      return _RpcTestResult.ok(rowCount: rowCount, durationMs: DateTime.now().difference(startedAt).inMilliseconds);
    } catch (e) {
      debugPrint('AdminDataTest: RPC $functionName failed: $e');
      return _RpcTestResult.err(safeMessage: _safeErrorMessage(e), durationMs: DateTime.now().difference(startedAt).inMilliseconds);
    }
  }

  int _safeRowCount(Object? result) {
    // IMPORTANT: never print the payload; only report row counts.
    if (result == null) return 0;
    if (result is List) return result.length;
    if (result is Map) return 1;
    return 1;
  }

  String _safeErrorMessage(Object e) {
    if (e is PostgrestException) {
      final message = (e.message).trim();
      final code = (e.code ?? '').trim();
      final base = code.isEmpty ? message : '$code: $message';
      return base.isEmpty ? 'Request failed.' : _truncate(base, 220);
    }
    return _truncate(e.toString(), 220);
  }

  String _truncate(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthStore>();
    final cs = Theme.of(context).colorScheme;

    // Router already enforces this, but we keep a defensive UI gate too.
    if (!auth.isSignedIn) {
      return const SizedBox.shrink();
    }
    if (!auth.isAuthorized) {
      return AdminPageScaffold(
        title: 'Admin Data Test',
        subtitle: 'Access denied.',
        child: AdminCard(
          child: Text('You must be an authenticated active admin to view this page.', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    return AdminPageScaffold(
      title: 'Admin Data Test',
      subtitle: 'Dev-only: verifies admin-safe reporting RPCs (row counts only).',
      actions: [
        FilledButton.icon(
          onPressed: _isLoading ? null : _run,
          icon: Icon(Icons.refresh, color: cs.onPrimary),
          label: Text('Run tests', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
        ),
      ],
      child: ListView(
        children: [
          if (!kDebugMode)
            AdminCard(
              child: Text(
                'This is a dev-only page. Build is not in debug mode, so tests are disabled.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            AdminCard(
              header: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), gradient: LinearGradient(colors: [cs.primary, cs.tertiary])),
                    child: Icon(Icons.data_usage, color: cs.onPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('Session + gate checks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'auth.uid()', value: auth.authUid ?? '—'),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(label: 'admin role', value: _roleLabel(auth.role)),
                  const SizedBox(height: AppSpacing.md),
                  Text('public.is_active_admin()', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: AppSpacing.sm),
                  if (_activeAdminError != null)
                    _Pill(
                      icon: Icons.error_outline,
                      label: _safeErrorMessage(_activeAdminError!),
                      background: cs.errorContainer,
                      foreground: cs.onErrorContainer,
                    )
                  else
                    _Pill(
                      icon: (_isActiveAdmin == true) ? Icons.check_circle_outline : Icons.help_outline,
                      label: (_isActiveAdmin == null) ? 'not checked' : (_isActiveAdmin == true ? 'true' : 'false'),
                      background: (_isActiveAdmin == true) ? cs.primaryContainer : cs.surfaceContainerHighest,
                      foreground: (_isActiveAdmin == true) ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            header: Row(
              children: [
                Expanded(child: Text('Reporting RPC tests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                if (kDebugMode)
                  _Pill(
                    icon: _isLoading ? Icons.hourglass_bottom : Icons.bolt,
                    label: _isLoading ? 'running…' : 'ready',
                    background: _isLoading ? cs.surfaceContainerHighest : cs.secondaryContainer,
                    foreground: _isLoading ? cs.onSurfaceVariant : cs.onSecondaryContainer,
                  ),
              ],
            ),
            child: Column(
              children: _rpcNames.keys.map((label) {
                final r = _results[label];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RpcRow(label: label, result: r),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            child: Text(
              'Privacy guardrails: this page only reports PASS/FAIL and row counts. It never renders the RPC payload, and it must never expose raw health content (names, values, documents, AI prompts/responses, search text).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpcRow extends StatelessWidget {
  const _RpcRow({required this.label, required this.result});
  final String label;
  final _RpcTestResult? result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final icon = result == null
        ? Icons.help_outline
        : (result!.isOk ? Icons.check_circle_outline : Icons.error_outline);
    final badgeBg = result == null
        ? cs.surfaceContainerHighest
        : (result!.isOk ? cs.primaryContainer : cs.errorContainer);
    final badgeFg = result == null
        ? cs.onSurfaceVariant
        : (result!.isOk ? cs.onPrimaryContainer : cs.onErrorContainer);

    final trailing = result == null
        ? 'not run'
        : (result!.isOk ? '${result!.rowCount} row(s)' : result!.safeMessage);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          _Pill(icon: icon, label: label, background: badgeBg, foreground: badgeFg),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(trailing, style: t.bodyMedium?.copyWith(color: cs.onSurface, height: 1.25))),
          if (result != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text('${result!.durationMs}ms', style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.background, required this.foreground});
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Text(label, style: t.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _RpcTestResult {
  const _RpcTestResult._({required this.isOk, required this.rowCount, required this.safeMessage, required this.durationMs});
  final bool isOk;
  final int rowCount;
  final String safeMessage;
  final int durationMs;

  factory _RpcTestResult.ok({required int rowCount, required int durationMs}) => _RpcTestResult._(isOk: true, rowCount: rowCount, safeMessage: '', durationMs: durationMs);
  factory _RpcTestResult.err({required String safeMessage, required int durationMs}) => _RpcTestResult._(isOk: false, rowCount: 0, safeMessage: safeMessage, durationMs: durationMs);
}

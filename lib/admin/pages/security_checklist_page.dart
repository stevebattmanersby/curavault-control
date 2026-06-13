import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/jwt_inspector.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/supabase/supabase_config.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SecurityChecklistPage extends StatelessWidget {
  const SecurityChecklistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final auth = context.watch<AdminAuthStore>();
    final snap = store.securityChecklist;
    final isLoading = store.isLoading || store.isSecurityChecklistLoading;

    final anonKey = SupabaseConfig.anonKey;
    final roleClaim = JwtInspector.tryGetRoleClaim(anonKey);
    final noServiceRoleKeyDetected =
        AdminAuthStore.supabaseServiceRoleKey.isEmpty && (roleClaim == null || roleClaim.toLowerCase() != 'service_role');

    return AdminPageScaffold(
      title: 'Security Checklist',
      subtitle: 'Defense-in-depth signals for privacy, RLS, and audit logging (best-effort, no PHI).',
      actions: [
        IconButton(
          onPressed: () => context.read<AdminStore>().refreshSecurityChecklist(),
          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
          splashColor: Colors.transparent,
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          tooltip: 'Refresh',
        ),
      ],
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : snap == null
              ? _SecurityChecklistEmptyState(
                  noServiceRoleKeyDetected: noServiceRoleKeyDetected,
                  auth: auth,
                )
              : _SecurityChecklistBody(
                  snapshot: snap,
                  auth: auth,
                  noServiceRoleKeyDetected: noServiceRoleKeyDetected,
                ),
    );
  }
}

class _SecurityChecklistEmptyState extends StatelessWidget {
  const _SecurityChecklistEmptyState({required this.noServiceRoleKeyDetected, required this.auth});
  final bool noServiceRoleKeyDetected;
  final AdminAuthStore auth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security_outlined, size: 44, color: cs.onSurfaceVariant),
              const SizedBox(height: AppSpacing.sm),
              Text('No checklist data yet.', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Refresh to load security posture signals. The control site never reads medical content or document names.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ChecklistGrid(
                items: [
                  _ChecklistItem(title: 'Admin auth enabled', ok: auth.isAuthorized, detail: auth.isAuthorized ? 'Authenticated + allow-listed + active + known role' : (auth.accessDeniedReason ?? 'Not authorized')),
                  _ChecklistItem(title: 'No service role key in frontend', ok: noServiceRoleKeyDetected, detail: noServiceRoleKeyDetected ? 'OK (client build does not include service role key)' : 'BLOCKED: service role key detected'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityChecklistBody extends StatelessWidget {
  const _SecurityChecklistBody({required this.snapshot, required this.auth, required this.noServiceRoleKeyDetected});

  final SecurityChecklistSnapshot snapshot;
  final AdminAuthStore auth;
  final bool noServiceRoleKeyDetected;

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final rlsSignal = snapshot.rlsEnabled;
    final rlsOk = rlsSignal == null ? null : rlsSignal;

    final items = <_ChecklistItem>[
      _ChecklistItem(
        title: 'RLS enabled',
        ok: rlsOk,
        detail: rlsOk == null
            ? 'Not verifiable from client. Validate via Supabase policies for all control tables.'
            : (rlsOk ? 'OK' : 'FAIL: RLS appears disabled'),
      ),
      _ChecklistItem(
        title: 'Admin auth enabled',
        ok: auth.isAuthorized,
        detail: auth.isAuthorized ? 'Authenticated + allow-listed + active + known role' : (auth.accessDeniedReason ?? 'Not authorized'),
      ),
      _ChecklistItem(
        title: 'Audit logging enabled',
        ok: snapshot.auditLoggingEnabled,
        detail: snapshot.auditLoggingEnabled ? 'Audit insert probe succeeded (best-effort)' : 'FAIL: audit insert probe failed',
      ),
      _ChecklistItem(
        title: 'No service role key detected in frontend',
        ok: noServiceRoleKeyDetected,
        detail: noServiceRoleKeyDetected ? 'OK (client build)' : 'BLOCKED: service role key detected',
      ),
      _ChecklistItem(
        title: 'No raw health table access from frontend',
        ok: snapshot.noRawHealthTableAccessDetected,
        detail: snapshot.noRawHealthTableAccessDetected ? 'OK (codebase uses privacy-safe models only)' : 'FAIL: potential raw table access detected',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _ChecklistGrid(items: items),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Operational signals', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: [
                  _MetricPill(label: 'Last admin login', value: _fmtDate(snapshot.lastAdminLoginAt)),
                  _MetricPill(label: 'Last audit event', value: _fmtDate(snapshot.lastAuditEventAt)),
                  _MetricPill(label: 'Active support sessions', value: snapshot.activeSupportSessions.toString()),
                  _MetricPill(label: 'Expired support sessions', value: snapshot.expiredSupportSessions.toString()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Notes: this page is intentionally conservative. If a signal is “unknown”, validate server-side (RLS policies, grants, and views).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.md),
                 Text('Debug: anon JWT role claim = ${JwtInspector.tryGetRoleClaim(SupabaseConfig.anonKey) ?? 'n/a'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistGrid extends StatelessWidget {
  const _ChecklistGrid({required this.items});
  final List<_ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 760 ? 2 : 1;
        return GridView.count(
          crossAxisCount: cols,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: cols == 1 ? 2.8 : 2.6,
          children: items.map((i) => _ChecklistCard(item: i)).toList(growable: false),
        );
      },
    );
  }
}

class _ChecklistItem {
  const _ChecklistItem({required this.title, required this.ok, required this.detail});
  final String title;
  final bool? ok;
  final String detail;
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.item});
  final _ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = item.ok;

    final (icon, status, statusColor) = switch (ok) {
      true => (Icons.check_circle_outline, 'OK', cs.tertiary),
      false => (Icons.error_outline, 'FAIL', cs.error),
      null => (Icons.help_outline, 'UNKNOWN', cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                    const SizedBox(width: AppSpacing.sm),
                    Text(status, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: statusColor, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.detail, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: AppSpacing.sm),
          Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

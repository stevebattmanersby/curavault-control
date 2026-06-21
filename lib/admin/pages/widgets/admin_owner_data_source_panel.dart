import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';

/// Owner-only diagnostics panel.
///
/// Privacy rules:
/// - Shows only operational metadata (source kind, RPC/view name, row counts, timestamps)
/// - Shows only admin-safe error messages
class AdminOwnerDataSourcePanel extends StatelessWidget {
  const AdminOwnerDataSourcePanel({super.key, required this.store, required this.dataSourceKey, required this.title});

  final AdminStore store;
  final AdminDataSourceKey dataSourceKey;
  final String title;

  @override
  Widget build(BuildContext context) {
    final admin = store.currentAdmin;
    if (admin == null || admin.role != AdminRole.owner) return const SizedBox.shrink();

    final status = store.dataSource(dataSourceKey);
    final cs = Theme.of(context).colorScheme;

    Widget kv(String k, String v, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 160, child: Text(k, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
            Expanded(child: SelectableText(v, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: valueColor ?? cs.onSurface, fontWeight: FontWeight.w700))),
          ],
        ),
      );
    }

    final kindLabel = switch (status.kind) {
      AdminDataSourceKind.live => 'live',
      AdminDataSourceKind.mock => 'mock',
      AdminDataSourceKind.notInstrumented => 'not instrumented',
      AdminDataSourceKind.error => 'error',
    };

    final refreshed = status.lastRefreshedAt == null ? '—' : formatDateTimeShort(status.lastRefreshedAt);
    final rowCount = status.rowCount?.toString() ?? '—';

    final tone = switch (status.kind) {
      AdminDataSourceKind.live => cs.primary,
      AdminDataSourceKind.mock => cs.tertiary,
      AdminDataSourceKind.notInstrumented => cs.onSurfaceVariant,
      AdminDataSourceKind.error => cs.error,
    };

    return AdminCard(
      header: Row(
        children: [
          Text('$title • Data source status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          AdminDataSourceBadge(status: status),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kv('data source', kindLabel, valueColor: tone),
          kv('RPC / query name', status.queryName ?? '—'),
          kv('row count', rowCount),
          kv('last refreshed', refreshed),
          if ((status.safeErrorMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.error.withValues(alpha: 0.28)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: cs.error),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(status.safeErrorMessage!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

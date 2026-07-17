import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/pages/widgets/admin_owner_data_source_panel.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WebsiteCmsStatusPage extends StatelessWidget {
  const WebsiteCmsStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final snap = store.websiteCms;
    final isLoading = store.isLoading || store.isWebsiteCmsLoading;

    return AdminPageScaffold(
      title: 'Website/CMS Status',
      subtitle: 'Live status of marketing tables (counts + timestamps only; no page body/content_json).',
      actions: [
        AdminDataSourceBadge(status: store.dataSource(AdminDataSourceKey.websiteCms)),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: () => context.read<AdminStore>().refreshWebsiteCmsStatus(),
          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
          splashColor: Colors.transparent,
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          tooltip: 'Refresh',
        ),
      ],
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminOwnerDataSourcePanel(store: store, dataSourceKey: AdminDataSourceKey.websiteCms, title: 'Website/CMS status'),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: store.dataSource(AdminDataSourceKey.websiteCms).kind == AdminDataSourceKind.notInstrumented
                      ? const AdminNotInstrumentedPanel()
                      : store.dataSource(AdminDataSourceKey.websiteCms).kind == AdminDataSourceKind.error
                          ? Center(
                              child: Text(
                                store.dataSource(AdminDataSourceKey.websiteCms).safeErrorMessage ?? 'Failed to load website/CMS status.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            )
                          : snap == null
                              ? const _EmptyWebsiteCmsStatusState()
                              : _WebsiteCmsStatusTable(snapshot: snap),
                ),
              ],
            ),
    );
  }
}

class _EmptyWebsiteCmsStatusState extends StatelessWidget {
  const _EmptyWebsiteCmsStatusState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.web_outlined, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text('No status data yet.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try refresh to probe the live marketing tables.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WebsiteCmsStatusTable extends StatelessWidget {
  const _WebsiteCmsStatusTable({required this.snapshot});
  final WebsiteCmsStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = snapshot.rows;

    return AdminCard(
      header: Row(
        children: [
          Text('Marketing tables', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('Generated ${AdminFormatters.dateTime(snapshot.generatedAt)}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
              border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 980),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length + 1,
                    separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline.withValues(alpha: 0.18)),
                    itemBuilder: (context, index) {
                      if (index == 0) return const _WebsiteCmsStatusHeaderRow();
                      final row = rows[index - 1];
                      return _WebsiteCmsStatusDataRow(row: row);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebsiteCmsStatusHeaderRow extends StatelessWidget {
  const _WebsiteCmsStatusHeaderRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Row(
        children: [
          _Cell(width: 240, child: Text('Table', style: style)),
          _Cell(width: 90, child: Text('Exists', style: style)),
          _Cell(width: 110, child: Text('Row count', style: style)),
          _Cell(width: 210, child: Text('Latest updated_at', style: style)),
          _Cell(width: 120, child: Text('RLS enabled', style: style)),
          _Cell(width: 160, child: Text('UI connected', style: style)),
          _Cell(width: 140, child: Text('Status', style: style)),
        ],
      ),
    );
  }
}

class _WebsiteCmsStatusDataRow extends StatelessWidget {
  const _WebsiteCmsStatusDataRow({required this.row});
  final WebsiteCmsTableStatusRow row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final existsLabel = row.exists ? 'Yes' : 'No';
    final countLabel = row.rowCount == null ? '—' : AdminFormatters.compactInt(row.rowCount!);
    final updatedLabel = row.latestUpdatedAt == null ? '—' : AdminFormatters.dateTime(row.latestUpdatedAt);
    final rlsLabel = row.rlsEnabled == null ? '—' : (row.rlsEnabled! ? 'Yes' : 'No');
    final uiLabel = row.uiConnected ? 'Yes' : 'No';

    final statusChip = _StatusChip(status: row.status);

    final rowWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      child: Row(
        children: [
          _Cell(
            width: 240,
            child: Text(row.tableName, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          _Cell(width: 90, child: Text(existsLabel, style: textTheme.bodyMedium?.copyWith(color: row.exists ? cs.onSurface : cs.error))),
          _Cell(width: 110, child: Text(countLabel, style: textTheme.bodyMedium)),
          _Cell(width: 210, child: Text(updatedLabel, style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          _Cell(width: 120, child: Text(rlsLabel, style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          _Cell(width: 160, child: Text(uiLabel, style: textTheme.bodyMedium?.copyWith(color: row.uiConnected ? cs.onSurface : cs.onSurfaceVariant))),
          _Cell(width: 140, child: Align(alignment: Alignment.centerLeft, child: statusChip)),
        ],
      ),
    );

    final err = (row.safeErrorMessage ?? '').trim();
    if (err.isEmpty) return rowWidget;

    return Tooltip(
      message: err,
      child: rowWidget,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final WebsiteCmsTableOverallStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    switch (status) {
      case WebsiteCmsTableOverallStatus.live:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        icon = Icons.check_circle_outline;
        break;
      case WebsiteCmsTableOverallStatus.empty:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        icon = Icons.inbox_outlined;
        break;
      case WebsiteCmsTableOverallStatus.missingUi:
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        icon = Icons.web_asset_off_outlined;
        break;
      case WebsiteCmsTableOverallStatus.missingTable:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        icon = Icons.table_chart_outlined;
        break;
      case WebsiteCmsTableOverallStatus.error:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: fg.withValues(alpha: 0.14))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(status.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

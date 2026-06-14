import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/audit_redactor.dart';
import 'package:curavault_admin/admin/utils/csv_export.dart';
import 'package:curavault_admin/admin/utils/file_saver.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  late final TextEditingController _adminCtrl;
  late final TextEditingController _targetCtrl;

  @override
  void initState() {
    super.initState();
    final q = context.read<AdminStore>().auditLogQuery;
    _adminCtrl = TextEditingController(text: q.adminUserId ?? '');
    _targetCtrl = TextEditingController(text: q.targetUserId ?? '');
  }

  @override
  void dispose() {
    _adminCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final auth = context.watch<AdminAuthStore>();
    final logs = store.auditLogs;
    final cs = Theme.of(context).colorScheme;

    final canExport = auth.role != null && AdminRbac.canExportAuditCsv(auth.role!);

    return AdminPageScaffold(
      title: 'Audit Logs',
      subtitle: 'Mandatory admin audit trail (metadata only, redacted as needed).',
      actions: [
        AdminDataSourceBadge(status: store.dataSource(AdminDataSourceKey.auditLogs)),
        const SizedBox(width: AppSpacing.sm),
        if (canExport)
          TextButton.icon(
            onPressed: logs.isEmpty
                ? null
                : () async {
                    final csv = AdminCsvExport.auditLogsToCsv(logs);
                    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
                    await AdminFileSaver.saveTextFile(filename: 'curavault_audit_logs_$stamp.csv', contents: csv);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Audit log CSV exported${_exportHintSuffix(context)}')),
                    );
                  },
            icon: Icon(Icons.download_outlined, color: cs.onSurface),
            label: Text('Export CSV', style: TextStyle(color: cs.onSurface)),
            style: TextButton.styleFrom(
              backgroundColor: cs.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: store.isAuditLogsLoading ? null : () => store.refreshAuditLogs(),
          icon: Icon(Icons.refresh, color: cs.onSurface),
          splashColor: Colors.transparent,
          highlightColor: cs.primary.withValues(alpha: 0.06),
          hoverColor: cs.primary.withValues(alpha: 0.06),
          tooltip: 'Refresh',
        ),
      ],
      child: Column(
        children: [
          if (store.dataSource(AdminDataSourceKey.auditLogs).kind == AdminDataSourceKind.notInstrumented)
            const Expanded(child: AdminNotInstrumentedPanel())
          else ...[
            if (store.auditSummary != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AdminCard(
                  header: Text('Audit summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  child: Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _Kpi(label: 'Total', value: formatCompactInt(store.auditSummary!.totalAuditEvents)),
                      _Kpi(label: '24h', value: formatCompactInt(store.auditSummary!.auditEvents24h)),
                      _Kpi(label: 'Failed 24h', value: formatCompactInt(store.auditSummary!.failedAdminActions24h)),
                      _Kpi(label: 'Latest', value: formatDateTimeShort(store.auditSummary!.latestAuditEventAt)),
                    ],
                  ),
                ),
              ),
            AdminCard(
              header: Row(
                children: [
                  Text('Filters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(
                    store.isAuditLogsLoading ? 'Loading…' : '${logs.length} loaded',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _adminCtrl,
                    decoration: const InputDecoration(labelText: 'Admin user id'),
                    onChanged: (v) => store.setAuditLogQuery(store.auditLogQuery.copyWith(adminUserId: v.trim(), clearAdminUserId: v.trim().isEmpty)),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _targetCtrl,
                    decoration: const InputDecoration(labelText: 'Target user id'),
                    onChanged: (v) => store.setAuditLogQuery(store.auditLogQuery.copyWith(targetUserId: v.trim(), clearTargetUserId: v.trim().isEmpty)),
                  ),
                ),
                _SelectFilterChip(
                  label: 'Action type',
                  value: store.auditLogQuery.actionType,
                  options: const [
                    'admin_login',
                    'failed_admin_login',
                    'user_viewed',
                    'plan_changed',
                    'trial_extended',
                    'storage_limit_changed',
                    'ai_limit_changed',
                    'feature_flag_changed',
                    'account_suspended',
                    'account_unsuspended',
                    'force_logout_triggered',
                    'sessions_revoked',
                    'support_session_opened',
                    'support_session_closed',
                    'support_note_added',
                    'billing_note_added',
                    'compliance_request_updated',
                    'export_request_marked_complete',
                    'deletion_request_marked_complete',
                    'settings_changed',
                    'admin_user_invited',
                    'admin_role_changed',
                    'admin_disabled',
                  ],
                  onChanged: (v) => store.setAuditLogQuery(store.auditLogQuery.copyWith(actionType: v, clearActionType: v == null)),
                ),
                _SelectFilterChip(
                  label: 'Result',
                  value: store.auditLogQuery.result,
                  options: const ['success', 'failure'],
                  onChanged: (v) => store.setAuditLogQuery(store.auditLogQuery.copyWith(result: v, clearResult: v == null)),
                ),
                _DateFilterChip(
                  label: 'Date',
                  range: store.auditLogQuery.createdRange,
                  onChanged: (r) => store.setAuditLogQuery(store.auditLogQuery.copyWith(createdRange: r, clearCreatedRange: r == null)),
                ),
                TextButton(
                  onPressed: () async {
                    _adminCtrl.text = '';
                    _targetCtrl.text = '';
                    await store.setAuditLogQuery(const AuditLogQuery());
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AdminCard(
              header: Row(
                children: [
                  Text('Events', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('Newest first', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        store.isAuditLogsLoading ? 'Loading…' : 'No matching audit log rows.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerTheme.color),
                      itemBuilder: (context, index) => _AuditLogTile(entry: logs[index]),
                    ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  static String _exportHintSuffix(BuildContext context) =>
      MediaQuery.of(context).size.width < 420 ? '' : (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android) ? ' (copied to clipboard)' : '';
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFail = entry.result.toLowerCase() == 'failure';
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isFail ? cs.errorContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(isFail ? Icons.error_outline : Icons.fact_check_outlined, color: isFail ? cs.onErrorContainer : cs.onSurfaceVariant, size: 18),
      ),
      title: Text(entry.actionType, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
      subtitle: Text(
        'Admin: ${entry.adminUserId}${entry.targetUserId == null ? '' : ' • Target: ${entry.targetUserId}'} • ${formatDateTimeShort(entry.createdAt)}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: _ResultPill(result: entry.result),
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetaChip(label: 'Ticket', value: entry.ticketReference ?? '—'),
            _MetaChip(label: 'IP', value: entry.ipAddress ?? '—'),
            _MetaChip(label: 'UA', value: entry.userAgent == null ? '—' : _truncate(entry.userAgent!, 40)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (entry.reason != null && entry.reason!.trim().isNotEmpty)
          Text('Reason: ${entry.reason}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
        if ((entry.previousValue != null) || (entry.newValue != null)) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _JsonPanel(title: 'Previous (redacted)', value: AdminAuditRedactor.jsonStringOrNull(entry.previousValue))),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _JsonPanel(title: 'New (redacted)', value: AdminAuditRedactor.jsonStringOrNull(entry.newValue))),
              ],
            ),
            // (rest of the page widgets remain unchanged)
          ],
      ],
    );
  }

  static String _truncate(String v, int max) => v.length <= max ? v : '${v.substring(0, max)}…';
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.result});
  final String result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFail = result.toLowerCase() == 'failure';
    final bg = isFail ? cs.errorContainer : cs.primary.withValues(alpha: 0.12);
    final fg = isFail ? cs.onErrorContainer : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(result, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
      child: Text('$label: $value', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}

class _JsonPanel extends StatelessWidget {
  const _JsonPanel({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          SelectableText(value.isEmpty ? '—' : value, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35)),
        ],
      ),
    );
  }
}

class _SelectFilterChip extends StatelessWidget {
  const _SelectFilterChip({required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (v) => onChanged(v == '__clear__' ? null : v),
      itemBuilder: (context) => [
        const PopupMenuItem(value: '__clear__', child: Text('Any')),
        ...options.map((o) => PopupMenuItem(value: o, child: Text(o))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ${value ?? 'Any'}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurface)),
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({required this.label, required this.range, required this.onChanged});
  final String label;
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = range == null ? 'Any' : '${AdminFormatters.date(range!.start)} → ${AdminFormatters.date(range!.end)}';
    return TextButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 1),
          initialDateRange: range,
        );
        onChanged(picked);
      },
      icon: Icon(Icons.date_range_outlined, color: cs.onSurface),
      label: Text('$label: $text', style: TextStyle(color: cs.onSurface)),
      style: TextButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

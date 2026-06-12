import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/pages/widgets/admin_change_confirm_sheet.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CompliancePage extends StatefulWidget {
  const CompliancePage({super.key});

  @override
  State<CompliancePage> createState() => _CompliancePageState();
}

class _CompliancePageState extends State<CompliancePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final store = context.watch<AdminStore>();
    final snap = store.compliance;
    final role = context.watch<AdminAuthStore>().role ?? AdminRole.executiveReadonly;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compliance', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Track privacy, deletion, export, consent, and admin-access workflows. No health content is shown.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _ComplianceToolbar(role: role),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            dividerColor: cs.outlineVariant.withValues(alpha: 0.35),
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Data exports'),
              Tab(text: 'Deletions'),
              Tab(text: 'Consent records'),
              Tab(text: 'Support access'),
              Tab(text: 'Privacy/Terms acceptance'),
              Tab(text: 'Retention'),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ComplianceOverviewTab(overview: snap?.overview, isLoading: store.isComplianceLoading, generatedAt: snap?.generatedAt),
                  _ExportRequestsTab(rows: snap?.exportRequests ?? const [], isLoading: store.isComplianceLoading, role: role),
                  _DeletionRequestsTab(rows: snap?.deletionRequests ?? const [], isLoading: store.isComplianceLoading, role: role),
                  _ConsentRecordsTab(rows: snap?.consentRecords ?? const [], isLoading: store.isComplianceLoading),
                  _SupportAccessRecordsTab(rows: snap?.supportAccessRecords ?? const [], isLoading: store.isComplianceLoading, role: role),
                  _PolicyAcceptanceTab(rows: snap?.privacyTermsAcceptances ?? const [], isLoading: store.isComplianceLoading),
                  _RetentionTab(metrics: snap?.retention, isLoading: store.isComplianceLoading, generatedAt: snap?.generatedAt),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplianceToolbar extends StatelessWidget {
  const _ComplianceToolbar({required this.role});
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final store = context.watch<AdminStore>();
    final q = store.complianceQuery;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PillButton(
          icon: Icons.date_range,
          label: q.range.label,
          onPressed: () async {
            final picked = await showModalBottomSheet<AdminDateRangePreset>(
              context: context,
              showDragHandle: true,
              builder: (context) => const _RangeSheet(),
            );
            if (picked == null) return;
            await context.read<AdminStore>().setComplianceQuery(q.copyWith(range: picked));
          },
        ),
        _PillButton(
          icon: Icons.refresh,
          label: 'Refresh',
          onPressed: () => context.read<AdminStore>().refreshCompliance(),
        ),
        if (!AdminRbac.canViewComplianceEmail(role))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Email hidden for this role', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}

class _RangeSheet extends StatelessWidget {
  const _RangeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date range', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final p in AdminDateRangePreset.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.label),
                leading: const Icon(Icons.calendar_month),
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: cs.onSurface),
      label: Text(label, style: TextStyle(color: cs.onSurface)),
    );
  }
}

class _ComplianceOverviewTab extends StatelessWidget {
  const _ComplianceOverviewTab({required this.overview, required this.isLoading, required this.generatedAt});
  final ComplianceOverviewMetrics? overview;
  final bool isLoading;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final o = overview;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LoadingBanner(isLoading: isLoading, generatedAt: generatedAt),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 1200 ? 4 : constraints.maxWidth >= 860 ? 3 : 2;
            final cards = <Widget>[
              _MetricCard(label: 'Open deletion requests', value: o?.openDeletionRequests ?? 0, icon: Icons.delete_outline),
              _MetricCard(label: 'Completed deletions', value: o?.completedDeletionRequests ?? 0, icon: Icons.check_circle_outline),
              _MetricCard(label: 'Failed deletions', value: o?.failedDeletionRequests ?? 0, icon: Icons.error_outline, emphasize: true),
              _MetricCard(label: 'Open export requests', value: o?.openExportRequests ?? 0, icon: Icons.download_outlined),
              _MetricCard(label: 'Completed exports', value: o?.completedExportRequests ?? 0, icon: Icons.verified_outlined),
              _MetricCard(label: 'Active support sessions', value: o?.activeSupportSessions ?? 0, icon: Icons.support_agent_outlined),
              _MetricCard(label: 'Expired support sessions', value: o?.expiredSupportSessions ?? 0, icon: Icons.timer_off_outlined),
              _MetricCard(label: 'Recent admin actions', value: o?.recentAdminActions ?? 0, icon: Icons.manage_history_outlined),
              _MetricCard(label: 'Users pending deletion', value: o?.usersPendingDeletion ?? 0, icon: Icons.person_remove_outlined),
            ];
            return _Grid(cols: cols, children: cards);
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'All compliance views are aggregate/metadata-only. Do not add any health content to this section.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportRequestsTab extends StatelessWidget {
  const _ExportRequestsTab({required this.rows, required this.isLoading, required this.role});
  final List<DataExportRequestRow> rows;
  final bool isLoading;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final canSeeEmail = AdminRbac.canViewComplianceEmail(role);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _TabHeader(title: 'Data Export Requests', subtitle: 'Track export workflows without exposing user content.'),
        _LoadingBanner(isLoading: isLoading, generatedAt: null),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1100),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
              columns: [
                const DataColumn(label: Text('Request ID')),
                const DataColumn(label: Text('User ID')),
                if (canSeeEmail) const DataColumn(label: Text('Email')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('Requested at')),
                const DataColumn(label: Text('Completed at')),
                const DataColumn(label: Text('Verified by')),
                const DataColumn(label: Text('Failure reason')),
                const DataColumn(label: Text('Notes')),
                const DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(r.requestId)),
                      DataCell(Text(r.userId)),
                      if (canSeeEmail) DataCell(Text(r.email ?? '—')),
                      DataCell(_StatusChip(status: r.status.label)),
                      DataCell(Text(AdminFormatters.dateTime(r.requestedAt))),
                      DataCell(Text(AdminFormatters.dateTime(r.completedAt))),
                      DataCell(Text(r.verifiedBy ?? '—')),
                      DataCell(Text(r.failureReason ?? '—')),
                      // PRIVACY: never render free-text notes in the control site UI.
                      DataCell(Text(r.notes?.trim().isNotEmpty == true ? 'Present (redacted)' : '—')),
                      DataCell(_ExportActionsCell(row: r, role: role)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeletionRequestsTab extends StatelessWidget {
  const _DeletionRequestsTab({required this.rows, required this.isLoading, required this.role});
  final List<DeletionRequestRow> rows;
  final bool isLoading;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final canSeeEmail = AdminRbac.canViewComplianceEmail(role);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _TabHeader(title: 'Deletion Requests', subtitle: 'Track account deletion workflows without exposing health content.'),
        _LoadingBanner(isLoading: isLoading, generatedAt: null),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1200),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
              columns: [
                const DataColumn(label: Text('Request ID')),
                const DataColumn(label: Text('User ID')),
                if (canSeeEmail) const DataColumn(label: Text('Email')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('Requested at')),
                const DataColumn(label: Text('Completed at')),
                const DataColumn(label: Text('Failed reason')),
                const DataColumn(label: Text('Retention exception')),
                const DataColumn(label: Text('Verified by')),
                const DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(r.requestId)),
                      DataCell(Text(r.userId)),
                      if (canSeeEmail) DataCell(Text(r.email ?? '—')),
                      DataCell(_StatusChip(status: r.status.label)),
                      DataCell(Text(AdminFormatters.dateTime(r.requestedAt))),
                      DataCell(Text(AdminFormatters.dateTime(r.completedAt))),
                      DataCell(Text(r.failedReason ?? '—')),
                      DataCell(Text(r.retentionException ? 'Yes' : 'No')),
                      DataCell(Text(r.verifiedBy ?? '—')),
                      DataCell(_DeletionActionsCell(row: r, role: role)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsentRecordsTab extends StatelessWidget {
  const _ConsentRecordsTab({required this.rows, required this.isLoading});
  final List<ConsentRecordRow> rows;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _TabHeader(title: 'Consent Records', subtitle: 'Consent metadata only (type/version/timestamps/source).'),
        _LoadingBanner(isLoading: isLoading, generatedAt: null),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
              columns: const [
                DataColumn(label: Text('User ID')),
                DataColumn(label: Text('Consent type')),
                DataColumn(label: Text('Version')),
                DataColumn(label: Text('Accepted at')),
                DataColumn(label: Text('Revoked at')),
                DataColumn(label: Text('Source')),
                DataColumn(label: Text('Country')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(r.userId)),
                      DataCell(Text(r.consentType)),
                      DataCell(Text(r.version)),
                      DataCell(Text(AdminFormatters.dateTime(r.acceptedAt))),
                      DataCell(Text(AdminFormatters.dateTime(r.revokedAt))),
                      DataCell(Text(r.source)),
                      DataCell(Text(r.country)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportAccessRecordsTab extends StatelessWidget {
  const _SupportAccessRecordsTab({required this.rows, required this.isLoading, required this.role});
  final List<SupportAccessRecordRow> rows;
  final bool isLoading;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _TabHeader(title: 'Support Access Records', subtitle: 'Track admin support-access windows (consent + expiry).'),
        _LoadingBanner(isLoading: isLoading, generatedAt: null),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1150),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
              columns: const [
                DataColumn(label: Text('User ID')),
                DataColumn(label: Text('Admin user')),
                DataColumn(label: Text('Consent granted')),
                DataColumn(label: Text('Consent granted at')),
                DataColumn(label: Text('Access expires at')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Ticket reference')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(r.userId)),
                      DataCell(Text(r.adminUser)),
                      DataCell(Text(r.consentGranted ? 'Yes' : 'No')),
                      DataCell(Text(AdminFormatters.dateTime(r.consentGrantedAt))),
                      DataCell(Text(AdminFormatters.dateTime(r.accessExpiresAt))),
                      DataCell(_StatusChip(status: r.status)),
                      DataCell(Text(r.ticketReference ?? '—')),
                      DataCell(_SupportAccessActionsCell(row: r, role: role)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PolicyAcceptanceTab extends StatelessWidget {
  const _PolicyAcceptanceTab({required this.rows, required this.isLoading});
  final List<PrivacyTermsAcceptanceRow> rows;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _TabHeader(title: 'Privacy/Terms Version Acceptance', subtitle: 'Only version numbers and timestamps.'),
        _LoadingBanner(isLoading: isLoading, generatedAt: null),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 980),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
              columns: const [
                DataColumn(label: Text('User ID')),
                DataColumn(label: Text('Privacy policy version')),
                DataColumn(label: Text('Terms version')),
                DataColumn(label: Text('Accepted at')),
                DataColumn(label: Text('Country')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(r.userId)),
                      DataCell(Text(r.privacyPolicyVersion)),
                      DataCell(Text(r.termsVersion)),
                      DataCell(Text(AdminFormatters.dateTime(r.acceptedAt))),
                      DataCell(Text(r.country)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RetentionTab extends StatelessWidget {
  const _RetentionTab({required this.metrics, required this.isLoading, required this.generatedAt});
  final RetentionMonitoringMetrics? metrics;
  final bool isLoading;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = metrics;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LoadingBanner(isLoading: isLoading, generatedAt: generatedAt),
        const SizedBox(height: 14),
        _RetentionRow(label: 'Usage logs due for deletion', value: m == null ? '—' : formatCompactInt(m.usageLogsDueForDeletion)),
        _RetentionRow(label: 'Support notes due for deletion', value: m == null ? '—' : formatCompactInt(m.supportNotesDueForDeletion)),
        _RetentionRow(label: 'Expired support sessions', value: m == null ? '—' : formatCompactInt(m.expiredSupportSessions)),
        _RetentionRow(label: 'Old diagnostic logs', value: m == null ? '—' : formatCompactInt(m.oldDiagnosticLogs)),
        _RetentionRow(label: 'Old raw events', value: m == null ? '—' : formatCompactInt(m.oldRawEvents)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Text(
            'Retention monitoring is metadata-only and should be backed by server-side deletion jobs and safe summary views.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _RetentionRow extends StatelessWidget {
  const _RetentionRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner({required this.isLoading, required this.generatedAt});
  final bool isLoading;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (isLoading) ...[
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
            const SizedBox(width: 10),
            Expanded(child: Text('Refreshing…', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
          ] else ...[
            Icon(Icons.schedule, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                generatedAt == null ? 'Showing latest snapshot.' : 'Generated ${AdminFormatters.relativeTime(generatedAt!)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, this.emphasize = false});
  final String label;
  final int value;
  final IconData icon;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasize ? cs.errorContainer.withValues(alpha: 0.25) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
            ],
          ),
          const SizedBox(height: 10),
          Text(formatCompactInt(value), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.cols, required this.children});
  final int cols;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      rows.add(
        Row(
          children: [
            for (var j = 0; j < cols; j++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: j == cols - 1 ? 0 : 12, bottom: 12),
                  child: i + j < children.length ? children[i + j] : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normalized = status.trim().toLowerCase();
    final (bg, fg) = switch (normalized) {
      'completed' || 'done' => (cs.primaryContainer.withValues(alpha: 0.55), cs.onPrimaryContainer),
      'failed' => (cs.errorContainer.withValues(alpha: 0.65), cs.onErrorContainer),
      'in_progress' || 'inprogress' => (cs.tertiaryContainer.withValues(alpha: 0.55), cs.onTertiaryContainer),
      'active' => (cs.secondaryContainer.withValues(alpha: 0.55), cs.onSecondaryContainer),
      'expired' => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      'closed' || 'revoked' => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35))),
      child: Text(normalized, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}

class _ExportActionsCell extends StatelessWidget {
  const _ExportActionsCell({required this.row, required this.role});
  final DataExportRequestRow row;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final canAct = role == AdminRole.superAdmin || role == AdminRole.complianceOfficer;
    if (!canAct) {
      return const Text('—');
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) async {
        try {
          final admin = context.read<AdminStore>().currentAdmin;
          if (admin == null) return;
          switch (value) {
            case 'in_progress':
              final conf = await AdminChangeConfirmSheet.show(
                context,
                title: 'Mark export in progress',
                summary: 'This marks the request as being processed. A reason is required and will be audit-logged.',
                previousValue: row.status.label,
                newValue: ComplianceRequestStatus.inProgress.label,
                confirmLabel: 'Mark in progress',
              );
              if (conf == null) return;
              await context.read<AdminStore>().performComplianceAction(
                    ComplianceActionRequest(
                      actorAdminId: admin.id,
                      actorRole: admin.role,
                      userId: row.userId,
                      action: ComplianceAction.markExportInProgress,
                      reason: conf.reason,
                      ticketReference: conf.ticketReference,
                      requestId: row.requestId,
                    ),
                  );
            case 'complete':
              final conf = await AdminChangeConfirmSheet.show(
                context,
                title: 'Mark export complete',
                summary: 'Only mark complete once the export has been verified. A reason is required and will be audit-logged.',
                previousValue: row.status.label,
                newValue: ComplianceRequestStatus.completed.label,
                confirmLabel: 'Mark complete',
              );
              if (conf == null) return;
              await context.read<AdminStore>().performComplianceAction(
                    ComplianceActionRequest(
                      actorAdminId: admin.id,
                      actorRole: admin.role,
                      userId: row.userId,
                      action: ComplianceAction.markExportComplete,
                      reason: conf.reason,
                      ticketReference: conf.ticketReference,
                      requestId: row.requestId,
                    ),
                  );
            case 'fail':
              final conf = await AdminChangeConfirmSheet.show(
                context,
                title: 'Record failure reason',
                summary: 'This marks the request as failed. Use the reason field for the failure reason (audit logged).',
                previousValue: row.status.label,
                newValue: ComplianceRequestStatus.failed.label,
                confirmLabel: 'Record failure',
              );
              if (conf == null) return;
              await context.read<AdminStore>().performComplianceAction(
                    ComplianceActionRequest(
                      actorAdminId: admin.id,
                      actorRole: admin.role,
                      userId: row.userId,
                      action: ComplianceAction.recordFailureReason,
                      reason: conf.reason,
                      ticketReference: conf.ticketReference,
                      requestId: row.requestId,
                    ),
                  );
            case 'note':
              final note = await _TextEntrySheet.show(context, title: 'Add compliance note', label: 'Note', hint: 'Add a short compliance note (no health content)…');
              if (note == null) return;
              final conf = await AdminChangeConfirmSheet.show(
                context,
                title: 'Confirm note',
                summary: 'Reason is required and will be audit-logged. The note will be attached to this request.',
                previousValue: row.notes ?? '—',
                newValue: note,
                confirmLabel: 'Add note',
              );
              if (conf == null) return;
              await context.read<AdminStore>().performComplianceAction(
                    ComplianceActionRequest(
                      actorAdminId: admin.id,
                      actorRole: admin.role,
                      userId: row.userId,
                      action: ComplianceAction.addComplianceNote,
                      reason: conf.reason,
                      ticketReference: conf.ticketReference,
                      requestId: row.requestId,
                      parameters: {'note': note},
                    ),
                  );
          }
        } catch (e) {
          debugPrint('Export action failed: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed. See logs.')));
          }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'in_progress', child: Text('Mark in progress')),
        PopupMenuItem(value: 'complete', child: Text('Mark complete')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'fail', child: Text('Record failure reason')),
        PopupMenuItem(value: 'note', child: Text('Add compliance note')),
      ],
    );
  }
}

class _DeletionActionsCell extends StatelessWidget {
  const _DeletionActionsCell({required this.row, required this.role});
  final DeletionRequestRow row;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final canAct = role == AdminRole.superAdmin || role == AdminRole.complianceOfficer;
    if (!canAct) return const Text('—');

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) async {
        try {
          final admin = context.read<AdminStore>().currentAdmin;
          if (admin == null) return;
          switch (value) {
            case 'in_progress':
              final conf = await AdminChangeConfirmSheet.show(
                context,
                title: 'Mark deletion in progress',
                summary: 'This marks the request as being processed. A reason is required and will be audit-logged.',
                previousValue: row.status.label,
                newValue: ComplianceRequestStatus.inProgress.label,
                confirmLabel: 'Mark in progress',
              );
              if (conf == null) return;
              await context.read<AdminStore>().performComplianceAction(
                    ComplianceActionRequest(
                      actorAdminId: admin.id,
                      actorRole: admin.role,
                      userId: row.userId,
                      action: ComplianceAction.markDeletionInProgress,
                      reason: conf.reason,
                      ticketReference: conf.ticketReference,
                      requestId: row.requestId,
                    ),
                  );
            case 'complete':
              final conf = await AdminChangeConfirmSheet.show(
                context,
                title: 'Mark deletion complete',
                summary: 'Only mark complete once the deletion workflow has been verified. A reason is required.',
                previousValue: row.status.label,
                newValue: ComplianceRequestStatus.completed.label,
                confirmLabel: 'Mark complete',
              );
              if (conf == null) return;
              await context.read<AdminStore>().performComplianceAction(
                    ComplianceActionRequest(
                      actorAdminId: admin.id,
                      actorRole: admin.role,
                      userId: row.userId,
                      action: ComplianceAction.markDeletionComplete,
                      reason: conf.reason,
                      ticketReference: conf.ticketReference,
                      requestId: row.requestId,
                    ),
                  );
            case 'fail':
              final conf = await AdminChangeConfirmSheet.show(
                context,
                title: 'Record failure reason',
                summary: 'This marks the request as failed. Use the reason field for the failure reason (audit logged).',
                previousValue: row.status.label,
                newValue: ComplianceRequestStatus.failed.label,
                confirmLabel: 'Record failure',
              );
              if (conf == null) return;
              await context.read<AdminStore>().performComplianceAction(
                    ComplianceActionRequest(
                      actorAdminId: admin.id,
                      actorRole: admin.role,
                      userId: row.userId,
                      action: ComplianceAction.recordFailureReason,
                      reason: conf.reason,
                      ticketReference: conf.ticketReference,
                      requestId: row.requestId,
                    ),
                  );
          }
        } catch (e) {
          debugPrint('Deletion action failed: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed. See logs.')));
          }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'in_progress', child: Text('Mark in progress')),
        PopupMenuItem(value: 'complete', child: Text('Mark complete')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'fail', child: Text('Record failure reason')),
      ],
    );
  }
}

class _SupportAccessActionsCell extends StatelessWidget {
  const _SupportAccessActionsCell({required this.row, required this.role});
  final SupportAccessRecordRow row;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final canAct = role == AdminRole.superAdmin || role == AdminRole.complianceOfficer || role == AdminRole.supportAgent;
    if (!canAct) return const Text('—');
    final id = row.ticketReference ?? '${row.userId}:${row.adminUser}:${row.accessExpiresAt?.millisecondsSinceEpoch ?? 0}';

    return OutlinedButton.icon(
      onPressed: row.status.toLowerCase() == 'active'
          ? () async {
              try {
                final admin = context.read<AdminStore>().currentAdmin;
                if (admin == null) return;
                final conf = await AdminChangeConfirmSheet.show(
                  context,
                  title: 'Close support access',
                  summary: 'This immediately closes the access window. A reason is required and will be audit-logged.',
                  previousValue: row.status,
                  newValue: 'closed',
                  confirmLabel: 'Close access',
                );
                if (conf == null) return;
                await context.read<AdminStore>().performComplianceAction(
                      ComplianceActionRequest(
                        actorAdminId: admin.id,
                        actorRole: admin.role,
                        userId: row.userId,
                        action: ComplianceAction.closeSupportAccess,
                        reason: conf.reason,
                        ticketReference: conf.ticketReference,
                        requestId: id,
                      ),
                    );
              } catch (e) {
                debugPrint('Close support access failed: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed. See logs.')));
                }
              }
            }
          : null,
      icon: const Icon(Icons.close),
      label: const Text('Close'),
    );
  }
}

class _TextEntrySheet extends StatefulWidget {
  const _TextEntrySheet({required this.title, required this.label, required this.hint});
  final String title;
  final String label;
  final String hint;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required String hint,
  }) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: _TextEntrySheet(title: title, label: label, hint: hint),
        ),
      );

  @override
  State<_TextEntrySheet> createState() => _TextEntrySheetState();
}

class _TextEntrySheetState extends State<_TextEntrySheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isEmpty) {
      setState(() => _error = '${widget.label} is required.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(labelText: widget.label, hintText: widget.hint, errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: cs.onSurface)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text('Continue', style: TextStyle(color: cs.onPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

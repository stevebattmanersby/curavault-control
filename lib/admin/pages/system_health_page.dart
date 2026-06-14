import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SystemHealthPage extends StatelessWidget {
  const SystemHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final snap = store.systemHealth;
    final isLoading = store.isLoading || store.isSystemHealthLoading;

    return AdminPageScaffold(
      title: 'System Health',
      subtitle: 'Reliability, sync/upload health, AI service health, and technical error logs (no user content).',
      actions: [
        AdminDataSourceBadge(status: store.dataSource(AdminDataSourceKey.systemHealth)),
        const SizedBox(width: AppSpacing.sm),
        _SystemHealthFiltersBar(query: store.systemHealthQuery, onChanged: store.setSystemHealthQuery),
        IconButton(
          onPressed: () => context.read<AdminStore>().refreshSystemHealth(),
          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
          splashColor: Colors.transparent,
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          tooltip: 'Refresh',
        ),
      ],
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : store.dataSource(AdminDataSourceKey.systemHealth).kind == AdminDataSourceKind.notInstrumented
              ? const AdminNotInstrumentedPanel()
              : snap == null
                  ? _EmptySystemHealthState(query: store.systemHealthQuery)
                  : _SystemHealthTabs(snapshot: snap),
    );
  }
}

class _EmptySystemHealthState extends StatelessWidget {
  const _EmptySystemHealthState({required this.query});
  final SystemHealthQuery query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor_heart_outlined, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text('No system health data yet.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No system health aggregates collected yet (${query.range.label}).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SystemHealthFiltersBar extends StatelessWidget {
  const _SystemHealthFiltersBar({required this.query, required this.onChanged});
  final SystemHealthQuery query;
  final ValueChanged<SystemHealthQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AdminDateRangePreset>(
            value: query.range,
            borderRadius: BorderRadius.circular(AppRadius.md),
            icon: Icon(Icons.expand_more, color: cs.onSurfaceVariant, size: 18),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface),
            items: [
              for (final r in AdminDateRangePreset.values) DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (v) {
              if (v == null) return;
              onChanged(query.copyWith(range: v));
            },
          ),
        ),
      ),
    );
  }
}

class _SystemHealthTabs extends StatelessWidget {
  const _SystemHealthTabs({required this.snapshot});
  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          const _SystemHealthTabBar(),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TabBarView(
              children: [
                _SystemOverviewTab(snapshot: snapshot),
                _ApiHealthTab(snapshot: snapshot),
                _SyncHealthTab(snapshot: snapshot),
                _UploadHealthTab(snapshot: snapshot),
                _AiServiceHealthTab(snapshot: snapshot),
                _AppVersionHealthTab(snapshot: snapshot),
                _ErrorLogsTab(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemHealthTabBar extends StatelessWidget {
  const _SystemHealthTabBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: TabBar(
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: cs.primaryContainer.withValues(alpha: 0.65),
        ),
        labelColor: cs.onPrimaryContainer,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'API Health'),
          Tab(text: 'Sync Health'),
          Tab(text: 'Upload Health'),
          Tab(text: 'AI Service'),
          Tab(text: 'App Versions'),
          Tab(text: 'Error Logs'),
        ],
      ),
    );
  }
}

class _SystemOverviewTab extends StatelessWidget {
  const _SystemOverviewTab({required this.snapshot});
  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final o = snapshot.overview;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'System Overview', subtitle: 'High-level service status and operational signals (no user content).'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              _StatusCard(title: 'API status', status: o.apiStatus, icon: Icons.api_outlined),
              _StatusCard(title: 'Database status', status: o.databaseStatus, icon: Icons.storage_outlined),
              _StatusCard(title: 'Storage status', status: o.storageStatus, icon: Icons.cloud_outlined),
              _StatusCard(title: 'Auth status', status: o.authStatus, icon: Icons.lock_outline),
              _StatusCard(title: 'AI service status', status: o.aiServiceStatus, icon: Icons.smart_toy_outlined),
              _InfoCard(
                title: 'Last successful scheduled job',
                value: AdminFormatters.dateTime(o.lastSuccessfulScheduledJob),
                icon: Icons.schedule_outlined,
              ),
              _InfoCard(title: 'Error rate (24h)', value: _formatPct(o.errorRateLast24h), icon: Icons.query_stats_outlined, emphasize: o.errorRateLast24h > 0.015),
              _InfoCard(title: 'Failed uploads (24h)', value: AdminFormatters.compactInt(o.failedUploadsLast24h), icon: Icons.upload_outlined, emphasize: o.failedUploadsLast24h > 80),
              _InfoCard(title: 'Failed syncs (24h)', value: AdminFormatters.compactInt(o.failedSyncsLast24h), icon: Icons.sync_problem_outlined, emphasize: o.failedSyncsLast24h > 70),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Top API endpoints by errors', subtitle: 'Aggregated request/error counts and latency percentiles.'),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: SizedBox(
              height: 240,
              child: _ApiErrorsBarChart(rows: snapshot.apiEndpoints.take(6).toList(), primary: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiErrorsBarChart extends StatelessWidget {
  const _ApiErrorsBarChart({required this.rows, required this.primary});
  final List<ApiHealthEndpointRow> rows;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (rows.isEmpty) return Center(child: Text('No endpoint data', style: Theme.of(context).textTheme.bodyMedium));

    final maxY = rows.map((e) => e.errorCount).fold<int>(0, (a, b) => a > b ? a : b).toDouble().clamp(1, double.infinity);
    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).clamp(1, double.infinity)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, meta) => Text(AdminFormatters.compactInt(v.round()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, meta) {
                final i = v.round().clamp(0, rows.length - 1);
                final short = rows[i].endpointName.split('.').last;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(short, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: rows[i].errorCount.toDouble(),
                  width: 16,
                  color: primary,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY * 1.15, color: cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final row = rows[group.x.toInt()];
              return BarTooltipItem(
                '${row.endpointName}\nErrors: ${AdminFormatters.compactInt(row.errorCount)}\nRequests: ${AdminFormatters.compactInt(row.requestCount)}\np95: ${row.p95LatencyMs}ms',
                Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurface),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ApiHealthTab extends StatelessWidget {
  const _ApiHealthTab({required this.snapshot});
  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.apiEndpoints;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'API Health', subtitle: 'Endpoint-level reliability and latency (aggregate-only).'),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
                dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                columns: const [
                  DataColumn(label: Text('Endpoint')),
                  DataColumn(label: Text('Requests')),
                  DataColumn(label: Text('Errors')),
                  DataColumn(label: Text('Avg latency')),
                  DataColumn(label: Text('p95 latency')),
                  DataColumn(label: Text('Last failure')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(r.endpointName)),
                        DataCell(Text(AdminFormatters.compactInt(r.requestCount))),
                        DataCell(Text(AdminFormatters.compactInt(r.errorCount))),
                        DataCell(Text('${r.avgLatencyMs}ms')),
                        DataCell(Text('${r.p95LatencyMs}ms')),
                        DataCell(Text(r.lastFailureAt == null ? '—' : AdminFormatters.dateTime(r.lastFailureAt!))),
                        DataCell(_StatusPill(status: r.status)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncHealthTab extends StatelessWidget {
  const _SyncHealthTab({required this.snapshot});
  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot.sync;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Sync Health', subtitle: 'Reliability and job status for background sync workflows.'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              _InfoCard(title: 'Successful syncs', value: AdminFormatters.compactInt(s.successfulSyncs), icon: Icons.sync_outlined),
              _InfoCard(title: 'Failed syncs', value: AdminFormatters.compactInt(s.failedSyncs), icon: Icons.sync_problem_outlined, emphasize: s.failedSyncs > 300),
              _InfoCard(title: 'Users w/ repeated failure', value: AdminFormatters.compactInt(s.usersWithRepeatedSyncFailure), icon: Icons.person_outline, emphasize: s.usersWithRepeatedSyncFailure > 20),
              _InfoCard(title: 'Avg sync duration', value: '${(s.avgSyncDurationMs / 1000).toStringAsFixed(1)}s', icon: Icons.timer_outlined),
              _InfoCard(title: 'Last sync job status', value: s.lastSyncJobStatus, icon: Icons.badge_outlined, emphasize: s.lastSyncJobStatus != 'success'),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadHealthTab extends StatelessWidget {
  const _UploadHealthTab({required this.snapshot});
  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final u = snapshot.upload;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Upload Health', subtitle: 'Upload reliability without file names or contents.'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              _InfoCard(title: 'Upload attempts', value: AdminFormatters.compactInt(u.uploadAttempts), icon: Icons.upload_outlined),
              _InfoCard(title: 'Upload success rate', value: _formatPct(u.uploadSuccessRate), icon: Icons.check_circle_outline),
              _InfoCard(title: 'Upload failure rate', value: _formatPct(u.uploadFailureRate), icon: Icons.error_outline, emphasize: u.uploadFailureRate > 0.035),
              _InfoCard(title: 'Avg upload size bucket', value: u.averageUploadSizeBucket, icon: Icons.data_usage_outlined),
              _InfoCard(title: 'Storage errors', value: AdminFormatters.compactInt(u.storageErrors), icon: Icons.cloud_off_outlined, emphasize: u.storageErrors > 40),
              _InfoCard(title: 'Permission errors', value: AdminFormatters.compactInt(u.permissionErrors), icon: Icons.no_accounts_outlined),
              _InfoCard(title: 'Timeout errors', value: AdminFormatters.compactInt(u.timeoutErrors), icon: Icons.timer_off_outlined, emphasize: u.timeoutErrors > 60),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiServiceHealthTab extends StatelessWidget {
  const _AiServiceHealthTab({required this.snapshot});
  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final a = snapshot.ai;
    final cs = Theme.of(context).colorScheme;
    final entries = a.errorCodes.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'AI Service Health', subtitle: 'Service reliability and error codes (never prompts or outputs).'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              _InfoCard(title: 'AI requests', value: AdminFormatters.compactInt(a.aiRequests), icon: Icons.smart_toy_outlined),
              _InfoCard(title: 'AI success rate', value: _formatPct(a.aiSuccessRate), icon: Icons.check_circle_outline),
              _InfoCard(title: 'AI failure rate', value: _formatPct(a.aiFailureRate), icon: Icons.error_outline, emphasize: a.aiFailureRate > 0.012),
              _InfoCard(title: 'Avg latency', value: '${a.averageLatencyMs}ms', icon: Icons.timer_outlined, emphasize: a.averageLatencyMs > 1200),
              _InfoCard(title: 'Rate limit events', value: AdminFormatters.compactInt(a.rateLimitEvents), icon: Icons.speed_outlined, emphasize: a.rateLimitEvents > 250),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'Error codes', subtitle: 'Counts aggregated for the selected range.'),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
                dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                columns: const [
                  DataColumn(label: Text('Error code')),
                  DataColumn(label: Text('Count')),
                ],
                rows: [
                  for (final e in entries)
                    DataRow(
                      cells: [
                        DataCell(Text(e.key)),
                        DataCell(Text(AdminFormatters.compactInt(e.value))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppVersionHealthTab extends StatelessWidget {
  const _AppVersionHealthTab({required this.snapshot});
  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.appVersions;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'App Version Health', subtitle: 'Active users and reliability signals by version & platform.'),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
                dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                columns: const [
                  DataColumn(label: Text('App version')),
                  DataColumn(label: Text('Platform')),
                  DataColumn(label: Text('Active users')),
                  DataColumn(label: Text('Error rate')),
                  DataColumn(label: Text('Failed uploads')),
                  DataColumn(label: Text('Failed syncs')),
                  DataColumn(label: Text('Upgrade recommended')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(r.appVersion)),
                        DataCell(Text(r.platform)),
                        DataCell(Text(AdminFormatters.compactInt(r.activeUsers))),
                        DataCell(Text(_formatPct(r.errorRate))),
                        DataCell(Text(AdminFormatters.compactInt(r.failedUploads))),
                        DataCell(Text(AdminFormatters.compactInt(r.failedSyncs))),
                        DataCell(
                          Text(
                            r.upgradeRecommended ? 'Yes' : 'No',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: r.upgradeRecommended ? cs.error : cs.onSurface),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorLogsTab extends StatelessWidget {
  const _ErrorLogsTab({required this.snapshot});
  final SystemHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.errorLogs;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Error Logs',
            subtitle: 'Technical metadata only: timestamp, codes, platform/version, pseudonymized user id, result, severity.',
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
                dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                columns: const [
                  DataColumn(label: Text('Timestamp')),
                  DataColumn(label: Text('Error code')),
                  DataColumn(label: Text('Feature area')),
                  DataColumn(label: Text('Platform')),
                  DataColumn(label: Text('App version')),
                  DataColumn(label: Text('User id (pseudo)')),
                  DataColumn(label: Text('Result')),
                  DataColumn(label: Text('Severity')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(AdminFormatters.dateTime(r.timestamp))),
                        DataCell(Text(r.errorCode)),
                        DataCell(Text(r.featureArea)),
                        DataCell(Text(r.platform)),
                        DataCell(Text(r.appVersion)),
                        DataCell(Text(r.userIdPseudonym)),
                        DataCell(Text(r.result)),
                        DataCell(_SeverityPill(severity: r.severity)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int columns = 1;
        if (w >= 1240) columns = 3;
        else if (w >= 860) columns = 2;
        final tileW = (w - (AppSpacing.md * (columns - 1))) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final c in children) SizedBox(width: tileW, child: c),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value, required this.icon, this.emphasize = false});
  final String title;
  final String value;
  final IconData icon;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: emphasize ? 0.45 : 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: emphasize ? cs.errorContainer.withValues(alpha: 0.55) : cs.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: emphasize ? cs.onErrorContainer : cs.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.status, required this.icon});
  final String title;
  final ServiceHealthStatus status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = _statusColors(context, status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: colors.iconBg, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Icon(icon, color: colors.iconFg, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(status.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: colors.text)),
                    const SizedBox(width: 10),
                    _StatusDot(color: colors.dot),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final ServiceHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = _statusColors(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.iconBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(status.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800)),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.severity});
  final SystemErrorSeverity severity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, border, fg) = switch (severity) {
      SystemErrorSeverity.info => (cs.surfaceContainerHighest.withValues(alpha: 0.55), cs.outline.withValues(alpha: 0.22), cs.onSurface),
      SystemErrorSeverity.warning => (cs.tertiaryContainer.withValues(alpha: 0.55), cs.tertiary.withValues(alpha: 0.35), cs.onTertiaryContainer),
      SystemErrorSeverity.error => (cs.errorContainer.withValues(alpha: 0.55), cs.error.withValues(alpha: 0.35), cs.onErrorContainer),
      SystemErrorSeverity.critical => (cs.errorContainer.withValues(alpha: 0.85), cs.error.withValues(alpha: 0.55), cs.onErrorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: border)),
      child: Text(severity.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w900)),
    );
  }
}

({Color bg, Color border, Color iconBg, Color iconFg, Color dot, Color text}) _statusColors(BuildContext context, ServiceHealthStatus status) {
  final cs = Theme.of(context).colorScheme;
  return switch (status) {
    ServiceHealthStatus.healthy => (
        bg: cs.primaryContainer.withValues(alpha: 0.22),
        border: cs.primary.withValues(alpha: 0.22),
        iconBg: cs.primaryContainer.withValues(alpha: 0.65),
        iconFg: cs.onPrimaryContainer,
        dot: cs.primary,
        text: cs.onSurface,
      ),
    ServiceHealthStatus.degraded => (
        bg: cs.tertiaryContainer.withValues(alpha: 0.22),
        border: cs.tertiary.withValues(alpha: 0.22),
        iconBg: cs.tertiaryContainer.withValues(alpha: 0.65),
        iconFg: cs.onTertiaryContainer,
        dot: cs.tertiary,
        text: cs.onSurface,
      ),
    ServiceHealthStatus.down => (
        bg: cs.errorContainer.withValues(alpha: 0.22),
        border: cs.error.withValues(alpha: 0.25),
        iconBg: cs.errorContainer.withValues(alpha: 0.65),
        iconFg: cs.onErrorContainer,
        dot: cs.error,
        text: cs.onSurface,
      ),
    ServiceHealthStatus.unknown => (
        bg: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: cs.outline.withValues(alpha: 0.22),
        iconBg: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        iconFg: cs.onSurface,
        dot: cs.onSurfaceVariant,
        text: cs.onSurface,
      ),
  };
}

String _formatPct(double value) => '${(value * 100).toStringAsFixed(2)}%';

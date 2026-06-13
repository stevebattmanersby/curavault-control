import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final snap = store.storage;
    final isLoading = store.isLoading || store.isStorageLoading;

    return AdminPageScaffold(
      title: 'Storage',
      subtitle: 'Usage, limits, cost, and upload reliability (privacy-safe; no file names/URLs/paths).',
      actions: [
        _StorageFiltersBar(query: store.storageQuery, onChanged: store.setStorageQuery),
        IconButton(
          onPressed: () => context.read<AdminStore>().refreshStorage(),
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_outlined, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No storage data yet.', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Connect Supabase summary views or refresh to load mock data.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : _StorageTabs(snapshot: snap),
    );
  }
}

class _StorageFiltersBar extends StatelessWidget {
  const _StorageFiltersBar({required this.query, required this.onChanged});
  final StorageQuery query;
  final ValueChanged<StorageQuery> onChanged;

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

class _StorageTabs extends StatelessWidget {
  const _StorageTabs({required this.snapshot});
  final StorageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const _StorageTabBar(),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TabBarView(
              children: [
                _StorageOverviewTab(snapshot: snapshot),
                _HighUsageUsersTab(snapshot: snapshot),
                _StorageByPlanTab(snapshot: snapshot),
                _StorageByCountryTab(snapshot: snapshot),
                _UploadErrorsTab(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageTabBar extends StatelessWidget {
  const _StorageTabBar();

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
          Tab(text: 'High usage users'),
          Tab(text: 'By plan'),
          Tab(text: 'By country'),
          Tab(text: 'Upload errors'),
        ],
      ),
    );
  }
}

class _StorageOverviewTab extends StatelessWidget {
  const _StorageOverviewTab({required this.snapshot});
  final StorageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Storage Overview',
            subtitle: 'Aggregated usage and reliability signals. No file metadata that could reveal health details.',
            trailing: Text('Generated ${formatDateTimeShort(snapshot.generatedAt)}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              MetricTile(label: 'Total storage used', value: formatBytes(snapshot.totalStorageUsedBytes), icon: Icons.storage_outlined),
              MetricTile(label: 'Total document count', value: formatCompactInt(snapshot.totalDocumentCount), icon: Icons.description_outlined),
              MetricTile(label: 'Average storage per user', value: formatBytes(snapshot.averageStoragePerUserBytes), icon: Icons.stacked_bar_chart_outlined),
              MetricTile(label: 'Users over storage limit', value: formatCompactInt(snapshot.usersOverStorageLimit), icon: Icons.block_outlined),
              MetricTile(label: 'Users >80% of limit', value: formatCompactInt(snapshot.usersOver80PercentStorageLimit), icon: Icons.warning_amber_outlined),
              MetricTile(label: 'Uploads this month', value: formatCompactInt(snapshot.uploadsThisMonth), icon: Icons.cloud_upload_outlined),
              MetricTile(label: 'Failed uploads this month', value: formatCompactInt(snapshot.failedUploadsThisMonth), icon: Icons.cloud_off_outlined),
              MetricTile(label: 'Estimated storage cost', value: AdminFormatters.usd(snapshot.estimatedStorageCostUsd), icon: Icons.payments_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AdminCard(
                  header: Row(
                    children: [
                      Text('Storage by plan (top)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Icon(Icons.bar_chart_outlined, color: cs.onSurfaceVariant, size: 18),
                    ],
                  ),
                  child: SizedBox(height: 240, child: _StorageByPlanBarChart(rows: snapshot.storageByPlan.take(6).toList())),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AdminCard(
                  header: Row(
                    children: [
                      Text('Recent upload errors', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Icon(Icons.error_outline, color: cs.onSurfaceVariant, size: 18),
                    ],
                  ),
                  child: _RecentUploadErrorsMiniList(errors: snapshot.uploadErrors.take(6).toList()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            header: Row(
              children: [
                Text('Policy reminder', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Icon(Icons.privacy_tip_outlined, color: cs.onSurfaceVariant, size: 18),
              ],
            ),
            child: Text(
              'This section intentionally excludes file names, URLs, previews, paths, and document categories. All insights are derived from summary tables/views only.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighUsageUsersTab extends StatelessWidget {
  const _HighUsageUsersTab({required this.snapshot});
  final StorageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AdminAuthStore>().role ?? AdminRole.readOnly;
    final canViewEmail = AdminRbac.canViewUserEmail(role);
    final cs = Theme.of(context).colorScheme;

    final rows = snapshot.highUsageUsers;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('High usage users', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
                  ),
                  child: Text('Sorted by % used', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyState(label: 'No high usage rows available.')
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingTextStyle: Theme.of(context).textTheme.labelLarge,
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                      columns: [
                        const DataColumn(label: Text('User ID')),
                        if (canViewEmail) const DataColumn(label: Text('Email')),
                        const DataColumn(label: Text('Country')),
                        const DataColumn(label: Text('Plan')),
                        const DataColumn(label: Text('Storage used')),
                        const DataColumn(label: Text('Storage limit')),
                        const DataColumn(label: Text('% used')),
                        const DataColumn(label: Text('Document count')),
                        const DataColumn(label: Text('Last upload date')),
                        const DataColumn(label: Text('Failed upload count')),
                        const DataColumn(label: Text('Account status')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r.userId)),
                              if (canViewEmail) DataCell(Text(r.email ?? '—')),
                              DataCell(Text(r.country)),
                              DataCell(Text(r.plan)),
                              DataCell(Text(formatBytes(r.storageUsedBytes))),
                              DataCell(Text(formatBytes(r.storageLimitBytes))),
                              DataCell(_PercentPill(value: r.percentUsed)),
                              DataCell(Text(formatCompactInt(r.documentCount))),
                              DataCell(Text(formatDateTimeShort(r.lastUploadAt))),
                              DataCell(Text(formatCompactInt(r.failedUploadCount))),
                              DataCell(_StatusPill(status: r.accountStatus)),
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

class _StorageByPlanTab extends StatelessWidget {
  const _StorageByPlanTab({required this.snapshot});
  final StorageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = snapshot.storageByPlan;

    return Column(
      children: [
        AdminCard(
          header: Row(
            children: [
              Text('Storage by plan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('Top plans by usage', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          child: SizedBox(height: 220, child: _StorageByPlanBarChart(rows: rows.take(8).toList())),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: rows.isEmpty
                ? const _EmptyState(label: 'No plan breakdown rows available.')
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingTextStyle: Theme.of(context).textTheme.labelLarge,
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                      columns: const [
                        DataColumn(label: Text('Plan')),
                        DataColumn(label: Text('Users')),
                        DataColumn(label: Text('Total storage')),
                        DataColumn(label: Text('Avg storage per user')),
                        DataColumn(label: Text('Users near limit')),
                        DataColumn(label: Text('Users over limit')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r.plan)),
                              DataCell(Text(formatCompactInt(r.users))),
                              DataCell(Text(formatBytes(r.totalStorageBytes))),
                              DataCell(Text(formatBytes(r.avgStoragePerUserBytes))),
                              DataCell(Text(formatCompactInt(r.usersNearLimit))),
                              DataCell(Text(formatCompactInt(r.usersOverLimit))),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _StorageByCountryTab extends StatelessWidget {
  const _StorageByCountryTab({required this.snapshot});
  final StorageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = snapshot.storageByCountry;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('Storage by country', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                Text('Countries with <10 users grouped into “Other”.', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyState(label: 'No country rows available.')
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingTextStyle: Theme.of(context).textTheme.labelLarge,
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                      columns: const [
                        DataColumn(label: Text('Country')),
                        DataColumn(label: Text('Users')),
                        DataColumn(label: Text('Total storage')),
                        DataColumn(label: Text('Average storage')),
                        DataColumn(label: Text('Document count')),
                        DataColumn(label: Text('Paid users')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r.country)),
                              DataCell(Text(formatCompactInt(r.users))),
                              DataCell(Text(formatBytes(r.totalStorageBytes))),
                              DataCell(Text(formatBytes(r.avgStorageBytes))),
                              DataCell(Text(formatCompactInt(r.documentCount))),
                              DataCell(Text(formatCompactInt(r.paidUsers))),
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

class _UploadErrorsTab extends StatelessWidget {
  const _UploadErrorsTab({required this.snapshot});
  final StorageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = snapshot.uploadErrors;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('Upload errors', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
                  ),
                  child: Text('User IDs are pseudonymized', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onTertiaryContainer)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyState(label: 'No upload error rows available.')
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingTextStyle: Theme.of(context).textTheme.labelLarge,
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                      columns: const [
                        DataColumn(label: Text('Date/time')),
                        DataColumn(label: Text('User ID pseudonym')),
                        DataColumn(label: Text('Platform')),
                        DataColumn(label: Text('App version')),
                        DataColumn(label: Text('Error code')),
                        DataColumn(label: Text('Result')),
                        DataColumn(label: Text('File size bucket')),
                        DataColumn(label: Text('Storage used at time')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(formatDateTimeShort(r.occurredAt))),
                              DataCell(Text(r.userPseudonym)),
                              DataCell(Text(r.platform)),
                              DataCell(Text(r.appVersion)),
                              DataCell(Text(r.errorCode)),
                              DataCell(_ResultPill(result: r.result)),
                              DataCell(Text(r.fileSizeBucket)),
                              DataCell(Text(formatBytes(r.storageUsedBytesAtTime))),
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

class _StorageByPlanBarChart extends StatelessWidget {
  const _StorageByPlanBarChart({required this.rows});
  final List<StorageByPlanRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final maxBytes = rows.map((e) => e.totalStorageBytes).reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxBytes / 4),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxBytes / 4,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(formatBytes(value.round()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= rows.length) return const SizedBox.shrink();
                final label = rows[idx].plan;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final r = rows[group.x.toInt()];
              return BarTooltipItem('${r.plan}\n${formatBytes(r.totalStorageBytes)}', Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurface));
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: rows[i].totalStorageBytes.toDouble(),
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  color: cs.primary,
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxBytes, color: cs.surfaceContainerHighest.withValues(alpha: 0.55)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecentUploadErrorsMiniList extends StatelessWidget {
  const _RecentUploadErrorsMiniList({required this.errors});
  final List<StorageUploadErrorRow> errors;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (errors.isEmpty) {
      return Text('No recent errors.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant));
    }
    return Column(
      children: [
        for (final e in errors)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _ResultDot(result: e.result),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.errorCode} • ${e.platform} ${e.appVersion}', style: Theme.of(context).textTheme.labelLarge, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('${formatDateTimeShort(e.occurredAt)} • ${e.fileSizeBucket} • ${formatBytes(e.storageUsedBytesAtTime)} used', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ResultPill(result: e.result),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResultDot extends StatelessWidget {
  const _ResultDot({required this.result});
  final String result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (result) {
      'failed' => cs.error,
      'blocked' => cs.tertiary,
      'retry_scheduled' => cs.secondary,
      _ => cs.primary,
    };
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)));
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.result});
  final String result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = switch (result) {
      'failed' => cs.errorContainer.withValues(alpha: 0.75),
      'blocked' => cs.tertiaryContainer.withValues(alpha: 0.75),
      'retry_scheduled' => cs.secondaryContainer.withValues(alpha: 0.75),
      _ => cs.primaryContainer.withValues(alpha: 0.75),
    };
    final fg = switch (result) {
      'failed' => cs.onErrorContainer,
      'blocked' => cs.onTertiaryContainer,
      'retry_scheduled' => cs.onSecondaryContainer,
      _ => cs.onPrimaryContainer,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35))),
      child: Text(result, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

class _PercentPill extends StatelessWidget {
  const _PercentPill({required this.value});
  final double value; // 0..+

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (value * 100).round();
    final tone = value > 1.0
        ? 3
        : value >= 0.8
            ? 2
            : value >= 0.6
                ? 1
                : 0;
    final bg = switch (tone) {
      3 => cs.errorContainer.withValues(alpha: 0.75),
      2 => cs.tertiaryContainer.withValues(alpha: 0.75),
      1 => cs.secondaryContainer.withValues(alpha: 0.65),
      _ => cs.surfaceContainerHighest.withValues(alpha: 0.65),
    };
    final fg = switch (tone) {
      3 => cs.onErrorContainer,
      2 => cs.onTertiaryContainer,
      1 => cs.onSecondaryContainer,
      _ => cs.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35))),
      child: Text('$pct%', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lower = status.toLowerCase();
    final bg = switch (lower) {
      'active' => cs.primaryContainer.withValues(alpha: 0.65),
      'locked' => cs.tertiaryContainer.withValues(alpha: 0.65),
      'suspended' => cs.errorContainer.withValues(alpha: 0.65),
      _ => cs.surfaceContainerHighest.withValues(alpha: 0.65),
    };
    final fg = switch (lower) {
      'active' => cs.onPrimaryContainer,
      'locked' => cs.onTertiaryContainer,
      'suspended' => cs.onErrorContainer,
      _ => cs.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35))),
      child: Text(status, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
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
        final columns = w >= 1200
            ? 4
            : w >= 900
                ? 3
                : 2;
        final tileW = (w - ((columns - 1) * AppSpacing.md)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: tileW.clamp(260, 520), child: child),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: cs.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

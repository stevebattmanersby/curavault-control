import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final isLoading = store.isLoading || store.isDashboardLoading;
    final dash = store.dashboard;
    final cs = Theme.of(context).colorScheme;

    return AdminPageScaffold(
      title: 'Dashboard',
      subtitle: 'Executive overview (privacy-safe summaries only).',
      actions: [
        _DashboardFiltersBar(query: store.dashboardQuery, onChanged: store.setDashboardQuery),
        IconButton(
          onPressed: () {
            context.read<AdminStore>().bootstrap();
          },
          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
          splashColor: Colors.transparent,
          highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          tooltip: 'Refresh',
        ),
      ],
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DataSourceStatusPanel(store: store),
                  const SizedBox(height: AppSpacing.lg),
                  if (store.dashboardLoad.hasError)
                    AdminCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, color: cs.error),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dashboard query failed', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text('Query: ${store.dashboardLoad.queryName ?? 'unknown'}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                                const SizedBox(height: 6),
                                Text(store.dashboardLoad.error ?? 'Unknown error', style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (dash == null && !store.dashboardLoad.hasError)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 56),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.query_stats, size: 44, color: cs.onSurfaceVariant),
                            const SizedBox(height: AppSpacing.sm),
                            Text('No data collected yet.', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Once aggregates are available, metrics will appear here.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  if (dash != null) _DashboardBody(dash: dash),
                ],
              ),
            ),
    );
  }
}

class _DataSourceStatusPanel extends StatelessWidget {
  const _DataSourceStatusPanel({required this.store});
  final AdminStore store;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget row({required String label, required AdminDataLoadStatus status}) {
      final ok = status.isOk;
      final icon = ok ? Icons.check_circle_outline : status.hasError ? Icons.error_outline : status.attempted ? Icons.hourglass_empty : Icons.help_outline;
      final iconColor = ok ? cs.primary : status.hasError ? cs.error : cs.onSurfaceVariant;
      final value = ok ? 'Yes' : status.hasError ? 'No (error)' : status.attempted ? 'No (loading/empty)' : 'No';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
            Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ok ? cs.primary : cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return AdminCard(
      header: Row(
        children: [
          Text('Data source status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('Admin-safe RPCs only', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
      child: Column(
        children: [
          row(label: 'Dashboard metrics loaded', status: store.dashboardLoad),
          row(label: 'User summary loaded', status: store.userSummaryLoad),
          row(label: 'Usage events loaded', status: store.usageEventsLoad),
          row(label: 'Billing summary loaded', status: store.billingLoad),
          if (store.userSummaryLoad.hasError || store.usageEventsLoad.hasError || store.billingLoad.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Errors', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (store.userSummaryLoad.hasError) _StatusErrorLine(name: store.userSummaryLoad.queryName, message: store.userSummaryLoad.error),
                  if (store.usageEventsLoad.hasError) _StatusErrorLine(name: store.usageEventsLoad.queryName, message: store.usageEventsLoad.error),
                  if (store.billingLoad.hasError) _StatusErrorLine(name: store.billingLoad.queryName, message: store.billingLoad.error),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusErrorLine extends StatelessWidget {
  const _StatusErrorLine({required this.name, required this.message});
  final String? name;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: cs.error),
          const SizedBox(width: 8),
          Expanded(child: Text('${name ?? 'unknown'}: ${message ?? 'Unknown error'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dash});
  final DashboardSnapshot dash;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'User Growth', subtitle: 'Acquisition and engagement signals for the selected range.'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              MetricTile(label: 'Total registered users', value: formatCompactInt(dash.totalRegisteredUsers), icon: Icons.people_alt_outlined),
              MetricTile(label: 'New users this week', value: formatCompactInt(dash.newUsersThisWeek), icon: Icons.person_add_alt_1_outlined),
              MetricTile(label: 'New users this month', value: formatCompactInt(dash.newUsersThisMonth), icon: Icons.person_add_outlined),
              MetricTile(label: 'Daily active users', value: formatCompactInt(dash.dailyActiveUsers), icon: Icons.today_outlined),
              MetricTile(label: 'Weekly active users', value: formatCompactInt(dash.weeklyActiveUsers), icon: Icons.calendar_view_week_outlined),
              MetricTile(label: 'Monthly active users', value: formatCompactInt(dash.monthlyActiveUsers), icon: Icons.date_range_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdminCard(
            header: Row(
              children: [
                Text('Registered users over time', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Generated ${formatDateTimeShort(dash.generatedAt)}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            child: SizedBox(height: 260, child: _UserGrowthLineChart(series: dash.userGrowth)),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Usage', subtitle: 'Storage and AI usage totals only. No content or prompts.'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              MetricTile(label: 'Total storage used', value: formatBytes(dash.totalStorageUsedBytes), icon: Icons.storage_outlined),
              MetricTile(label: 'Avg storage per user', value: formatBytes(dash.averageStoragePerUserBytes), icon: Icons.stacked_bar_chart_outlined),
              MetricTile(label: 'Users near storage limit', value: formatCompactInt(dash.usersNearStorageLimit), icon: Icons.warning_amber_outlined),
              MetricTile(label: 'AI tokens used (month)', value: formatCompactInt(dash.aiTokensUsedThisMonth), icon: Icons.auto_awesome_outlined),
              MetricTile(label: 'AI est. cost (month)', value: '\$${dash.aiEstimatedCostThisMonthUsd.toStringAsFixed(2)}', icon: Icons.payments_outlined),
              MetricTile(label: 'Users near AI limit', value: formatCompactInt(dash.usersNearAiLimit), icon: Icons.shield_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Plans', subtitle: 'Distribution by plan category.'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              MetricTile(label: 'Free users', value: formatCompactInt(dash.freeUsers), icon: Icons.savings_outlined),
              MetricTile(label: 'Trial users', value: formatCompactInt(dash.trialUsers), icon: Icons.timelapse_outlined),
              MetricTile(label: 'Paid users', value: formatCompactInt(dash.paidUsers), icon: Icons.workspace_premium_outlined),
              MetricTile(label: 'Cancelled users', value: formatCompactInt(dash.cancelledUsers), icon: Icons.cancel_outlined),
              MetricTile(label: 'Failed payments', value: formatCompactInt(dash.failedPayments), icon: Icons.report_gmailerrorred_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Country Usage', subtitle: 'Countries with <10 users are grouped into “Other”.'),
          const SizedBox(height: AppSpacing.md),
          _CountryUsageTable(rows: dash.countryUsage),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Platform Usage', subtitle: 'Account distribution by platform.'),
          const SizedBox(height: AppSpacing.md),
          AdminCard(child: SizedBox(height: 240, child: _PlatformPieChart(platformUsage: dash.platformUsage))),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Feature Usage', subtitle: 'Event totals only. No user content.'),
          const SizedBox(height: AppSpacing.md),
          AdminCard(child: SizedBox(height: 280, child: _FeatureBarChart(featureUsage: dash.featureUsage))),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Alerts', subtitle: 'Operational issues that require attention.'),
          const SizedBox(height: AppSpacing.md),
          _AlertsTable(rows: dash.alerts),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'System Status', subtitle: 'High-level service health (mock until live wiring).'),
          const SizedBox(height: AppSpacing.md),
          _SystemStatusGrid(items: dash.systemStatus),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _DashboardFiltersBar extends StatelessWidget {
  const _DashboardFiltersBar({required this.query, required this.onChanged});

  final DashboardQuery query;
  final ValueChanged<DashboardQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
                  for (final r in AdminDateRangePreset.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  onChanged(query.copyWith(range: v));
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () => _showFiltersSheet(context, query),
            icon: Icon(Icons.filter_alt_outlined, color: cs.onSurface),
            tooltip: 'Filters',
            splashColor: Colors.transparent,
            highlightColor: cs.primary.withValues(alpha: 0.06),
            hoverColor: cs.primary.withValues(alpha: 0.06),
          ),
        ],
      ),
    );
  }

  Future<void> _showFiltersSheet(BuildContext context, DashboardQuery query) async {
    final result = await showModalBottomSheet<DashboardQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DashboardFiltersSheet(initial: query),
    );
    if (result != null) onChanged(result);
  }
}

class _DashboardFiltersSheet extends StatefulWidget {
  const _DashboardFiltersSheet({required this.initial});
  final DashboardQuery initial;

  @override
  State<_DashboardFiltersSheet> createState() => _DashboardFiltersSheetState();
}

class _DashboardFiltersSheetState extends State<_DashboardFiltersSheet> {
  late DashboardQuery _q;

  @override
  void initState() {
    super.initState();
    _q = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: cs.onSurface),
                  splashColor: Colors.transparent,
                  highlightColor: cs.primary.withValues(alpha: 0.06),
                  hoverColor: cs.primary.withValues(alpha: 0.06),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _FilterChips(
              title: 'Country',
              value: _q.country,
              options: const ['US', 'CA', 'GB', 'DE', 'AU', 'SG'],
              onChanged: (v) => setState(() => _q = v == null ? _q.copyWith(clearCountry: true) : _q.copyWith(country: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _FilterChips(
              title: 'Platform',
              value: _q.platform,
              options: const ['iOS', 'Android', 'Web'],
              onChanged: (v) => setState(() => _q = v == null ? _q.copyWith(clearPlatform: true) : _q.copyWith(platform: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _FilterChips(
              title: 'Plan',
              value: _q.plan,
              options: const ['Free', 'Trial', 'Paid', 'Cancelled'],
              onChanged: (v) => setState(() => _q = v == null ? _q.copyWith(clearPlan: true) : _q.copyWith(plan: v)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _q = DashboardQuery(range: _q.range)),
                    icon: Icon(Icons.restart_alt, color: cs.onSurface),
                    label: Text('Reset', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
                    style: OutlinedButton.styleFrom(
                      splashFactory: NoSplash.splashFactory,
                      side: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_q),
                    icon: Icon(Icons.check, color: cs.onPrimary),
                    label: Text('Apply', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary)),
                    style: FilledButton.styleFrom(
                      splashFactory: NoSplash.splashFactory,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.title, required this.value, required this.options, required this.onChanged});

  final String title;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: value == null,
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: value == null ? cs.onPrimaryContainer : cs.onSurface),
              selectedColor: cs.primaryContainer,
              backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              showCheckmark: false,
              onSelected: (_) => onChanged(null),
            ),
            for (final o in options)
              ChoiceChip(
                label: Text(o),
                selected: value == o,
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: value == o ? cs.onPrimaryContainer : cs.onSurface),
                selectedColor: cs.primaryContainer,
                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                showCheckmark: false,
                onSelected: (_) => onChanged(o),
              ),
          ],
        ),
      ],
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

class _UserGrowthLineChart extends StatelessWidget {
  const _UserGrowthLineChart({required this.series});
  final List<DashboardTimeseriesPoint> series;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (series.isEmpty) return Center(child: Text('No data collected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)));

    final spots = <FlSpot>[];
    for (int i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i].value.toDouble()));
    }

    final maxY = series.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxY * 1.12).clamp(1, double.infinity),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).clamp(1, double.infinity)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, meta) => Text(formatCompactInt(v.round()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (series.length / 4).clamp(1, double.infinity).toDouble(),
              getTitlesWidget: (v, meta) {
                final i = v.round().clamp(0, series.length - 1);
                final d = series[i].date;
                final label = series.length <= 7 ? '${d.month}/${d.day}' : '${d.month}/${d.day}';
                return Padding(padding: const EdgeInsets.only(top: 8), child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.surface,
            getTooltipItems: (items) {
              return items.map((it) {
                final i = it.x.round().clamp(0, series.length - 1);
                final d = series[i].date;
                return LineTooltipItem('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}\n${formatCompactInt(it.y.round())} users', Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurface));
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cs.primary,
            barWidth: 3,
            dotData: FlDotData(show: series.length <= 14),
            belowBarData: BarAreaData(show: true, color: cs.primary.withValues(alpha: 0.10)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }
}

class _PlatformPieChart extends StatelessWidget {
  const _PlatformPieChart({required this.platformUsage});
  final Map<String, int> platformUsage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = platformUsage.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return Center(child: Text('No data collected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)));

    final colors = <String, Color>{
      'iOS': cs.primary,
      'Android': cs.tertiary,
      'Web': cs.secondary,
    };

    final sections = platformUsage.entries.map((e) {
      final value = e.value.toDouble();
      final pct = (value / total * 100);
      return PieChartSectionData(
        value: value,
        title: pct < 8 ? '' : '${pct.toStringAsFixed(0)}%',
        radius: 70,
        titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
        color: colors[e.key] ?? cs.primary,
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 32,
              sectionsSpace: 2,
              startDegreeOffset: -90,
              borderData: FlBorderData(show: false),
            ),
            swapAnimationDuration: const Duration(milliseconds: 250),
            swapAnimationCurve: Curves.easeOutCubic,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final e in platformUsage.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key] ?? cs.primary, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.key, style: Theme.of(context).textTheme.labelLarge)),
                      Text(formatCompactInt(e.value), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureBarChart extends StatelessWidget {
  const _FeatureBarChart({required this.featureUsage});
  final Map<String, int> featureUsage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (featureUsage.isEmpty) return Center(child: Text('No data collected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)));

    final entries = featureUsage.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entries.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b).toDouble();

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < entries.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: entries[i].value.toDouble(),
              width: 14,
              borderRadius: BorderRadius.circular(6),
              color: cs.primary,
              backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: cs.primary.withValues(alpha: 0.08)),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: maxY * 1.12,
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY / 4).clamp(1, double.infinity)),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final name = entries[group.x.toInt()].key;
              return BarTooltipItem('$name\n${formatCompactInt(rod.toY.round())}', Theme.of(context).textTheme.labelMedium!.copyWith(color: cs.onSurface));
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, meta) => Text(formatCompactInt(v.round()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)))),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                final label = entries[i].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    width: 62,
                    child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: groups,
      ),
      swapAnimationDuration: const Duration(milliseconds: 250),
      swapAnimationCurve: Curves.easeOutCubic,
    );
  }
}

class _CountryUsageTable extends StatelessWidget {
  const _CountryUsageTable({required this.rows});
  final List<CountryUsageRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminCard(
      header: Row(
        children: [
          Text('Country breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('Counts only', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No data collected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('Country')),
                  DataColumn(label: Text('Total users'), numeric: true),
                  DataColumn(label: Text('Active users'), numeric: true),
                  DataColumn(label: Text('Storage used'), numeric: true),
                  DataColumn(label: Text('AI tokens'), numeric: true),
                  DataColumn(label: Text('Paid users'), numeric: true),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(r.country)),
                        DataCell(Text(formatCompactInt(r.totalUsers))),
                        DataCell(Text(formatCompactInt(r.activeUsers))),
                        DataCell(Text(formatBytes(r.storageUsedBytes))),
                        DataCell(Text(formatCompactInt(r.aiTokensUsed))),
                        DataCell(Text(formatCompactInt(r.paidUsers))),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _AlertsTable extends StatelessWidget {
  const _AlertsTable({required this.rows});
  final List<AlertRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color severityColor(String s) => switch (s) {
      'high' => cs.error,
      'medium' => cs.tertiary,
      _ => cs.onSurfaceVariant,
    };

    return AdminCard(
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No data collected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 64,
                columns: const [
                  DataColumn(label: Text('Alert')),
                  DataColumn(label: Text('Count'), numeric: true),
                  DataColumn(label: Text('Severity')),
                  DataColumn(label: Text('Operational note')),
                ],
                rows: [
                  for (final r in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(r.type)),
                        DataCell(Text(formatCompactInt(r.count))),
                        DataCell(Text(r.severity.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: severityColor(r.severity), fontWeight: FontWeight.w800))),
                        // PRIVACY: avoid rendering free-text notes (could include user content).
                        DataCell(SizedBox(width: 380, child: Text(r.note.trim().isEmpty ? '—' : 'Redacted', maxLines: 1, overflow: TextOverflow.ellipsis))),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _SystemStatusGrid extends StatelessWidget {
  const _SystemStatusGrid({required this.items});
  final List<SystemStatusCard> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return AdminCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(child: Text('No data collected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
        ),
      );
    }
    Color statusColor(String s) => switch (s.toLowerCase()) {
      'down' => cs.error,
      'warn' => cs.tertiary,
      _ => cs.primary,
    };

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
            for (final it in items)
              SizedBox(
                width: tileW,
                child: AdminCard(
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: statusColor(it.status), borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(it.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
                                const SizedBox(width: AppSpacing.sm),
                                Text(it.status.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: statusColor(it.status), fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(it.detail, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            Text('Updated ${formatDateTimeShort(it.updatedAt)}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

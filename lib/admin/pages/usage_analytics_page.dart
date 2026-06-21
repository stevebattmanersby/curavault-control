import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/admin/pages/widgets/admin_owner_data_source_panel.dart';
import 'package:curavault_admin/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UsageAnalyticsPage extends StatelessWidget {
  const UsageAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final snap = store.usageAnalytics;
    final isLoading = store.isLoading || store.isUsageAnalyticsLoading;

    return AdminPageScaffold(
      title: 'Usage Analytics',
      subtitle: 'Product usage signals (privacy-safe; never content).',
      actions: [
        AdminDataSourceBadge(status: store.dataSource(AdminDataSourceKey.usageAnalytics)),
        const SizedBox(width: AppSpacing.sm),
        _UsageAnalyticsFiltersBar(query: store.usageAnalyticsQuery, onChanged: store.setUsageAnalyticsQuery),
        IconButton(
          onPressed: () => context.read<AdminStore>().refreshUsageAnalytics(),
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
                AdminOwnerDataSourcePanel(store: store, dataSourceKey: AdminDataSourceKey.usageAnalytics, title: 'Usage Analytics'),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: store.dataSource(AdminDataSourceKey.usageAnalytics).kind == AdminDataSourceKind.notInstrumented
                      ? const AdminNotInstrumentedPanel()
                      : store.dataSource(AdminDataSourceKey.usageAnalytics).kind == AdminDataSourceKind.error
                          ? Center(child: Text(store.dataSource(AdminDataSourceKey.usageAnalytics).safeErrorMessage ?? 'Failed to load usage analytics.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                          : (snap == null || snap.totalEvents == 0)
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.insights_outlined, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text('No usage data has been collected yet.', style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text('Once events are collected, this page will show aggregate-only usage signals.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                )
                              : _UsageAnalyticsTabs(snapshot: snap),
                ),
              ],
            ),
    );
  }
}

class _UsageAnalyticsTabs extends StatelessWidget {
  const _UsageAnalyticsTabs({required this.snapshot});
  final UsageAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          const _UsageAnalyticsTabBar(),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TabBarView(
              children: [
                _UsageOverviewTab(snapshot: snapshot),
                _UsageFeatureUsageTab(snapshot: snapshot),
                _UsageScreenUsageTab(snapshot: snapshot),
                _UsageFunnelsTab(snapshot: snapshot),
                _UsageRetentionTab(snapshot: snapshot),
                _UsageCountryTab(snapshot: snapshot),
                _UsagePlatformTab(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageAnalyticsTabBar extends StatelessWidget {
  const _UsageAnalyticsTabBar();

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
          Tab(text: 'Feature usage'),
          Tab(text: 'Screen usage'),
          Tab(text: 'Funnels'),
          Tab(text: 'Retention'),
          Tab(text: 'Country'),
          Tab(text: 'Platform'),
        ],
      ),
    );
  }
}

class _UsageAnalyticsFiltersBar extends StatelessWidget {
  const _UsageAnalyticsFiltersBar({required this.query, required this.onChanged});
  final UsageAnalyticsQuery query;
  final ValueChanged<UsageAnalyticsQuery> onChanged;

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
                  for (final r in AdminDateRangePreset.values) DropdownMenuItem(value: r, child: Text(r.label)),
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

  Future<void> _showFiltersSheet(BuildContext context, UsageAnalyticsQuery query) async {
    final res = await showModalBottomSheet<UsageAnalyticsQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UsageAnalyticsFiltersSheet(initial: query),
    );
    if (res != null) onChanged(res);
  }
}

class _UsageAnalyticsFiltersSheet extends StatefulWidget {
  const _UsageAnalyticsFiltersSheet({required this.initial});
  final UsageAnalyticsQuery initial;

  @override
  State<_UsageAnalyticsFiltersSheet> createState() => _UsageAnalyticsFiltersSheetState();
}

class _UsageAnalyticsFiltersSheetState extends State<_UsageAnalyticsFiltersSheet> {
  late UsageAnalyticsQuery _q;

  @override
  void initState() {
    super.initState();
    _q = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final countries = const ['US', 'CA', 'GB', 'DE', 'AU', 'SG'];
    final platforms = const ['iOS', 'Android', 'Web'];
    final plans = const ['Free', 'Pro', 'Team', 'Enterprise'];
    final versions = const ['2.6.1', '2.7.0', '2.7.1'];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Filters', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
              Text(
                'Analytics are always aggregated. Filters narrow cohorts; they never reveal content.',
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterChips< String?>(
                title: 'Country',
                value: _q.country,
                options: [null, ...countries],
                labelOf: (v) => v ?? 'All',
                onChanged: (v) => setState(() => _q = _q.copyWith(country: v, clearCountry: v == null)),
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterChips<String?>(
                title: 'Platform',
                value: _q.platform,
                options: [null, ...platforms],
                labelOf: (v) => v ?? 'All',
                onChanged: (v) => setState(() => _q = _q.copyWith(platform: v, clearPlatform: v == null)),
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterChips<String?>(
                title: 'Plan',
                value: _q.plan,
                options: [null, ...plans],
                labelOf: (v) => v ?? 'All',
                onChanged: (v) => setState(() => _q = _q.copyWith(plan: v, clearPlan: v == null)),
              ),
              const SizedBox(height: AppSpacing.md),
              _FilterChips<String?>(
                title: 'App version',
                value: _q.appVersion,
                options: [null, ...versions],
                labelOf: (v) => v ?? 'All',
                onChanged: (v) => setState(() => _q = _q.copyWith(appVersion: v, clearAppVersion: v == null)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _q = const UsageAnalyticsQuery(range: AdminDateRangePreset.days30)),
                      child: Text('Reset', style: TextStyle(color: cs.onSurface)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_q),
                      child: Text('Apply', style: TextStyle(color: cs.onPrimary)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChips<T> extends StatelessWidget {
  const _FilterChips({required this.title, required this.value, required this.options, required this.labelOf, required this.onChanged});
  final String title;
  final T value;
  final List<T> options;
  final String Function(T v) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final opt in options)
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(labelOf(opt)),
                ),
                selected: opt == value,
                labelStyle: t.labelLarge?.copyWith(color: (opt == value) ? cs.onPrimaryContainer : cs.onSurface),
                selectedColor: cs.primaryContainer,
                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.18)),
                onSelected: (_) => onChanged(opt),
              ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------
// Tabs
// ------------------------------

class _UsageOverviewTab extends StatelessWidget {
  const _UsageOverviewTab({required this.snapshot});
  final UsageAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Overview', subtitle: 'High-level engagement and conversion metrics for the selected cohort.'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              MetricTile(label: 'Total events', value: formatCompactInt(snapshot.totalEvents), icon: Icons.bolt_outlined),
              MetricTile(label: 'Active users', value: formatCompactInt(snapshot.activeUsers), icon: Icons.people_alt_outlined),
              MetricTile(label: 'Sessions', value: formatCompactInt(snapshot.sessions), icon: Icons.play_circle_outline),
              MetricTile(label: 'Avg session duration', value: _formatDuration(snapshot.avgSessionDurationSeconds), icon: Icons.timer_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdminCard(
            header: Row(
              children: [
                Text('Feature usage by category', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('Generated ${formatDateTimeShort(snapshot.generatedAt)}', style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            child: SizedBox(height: 260, child: _CategoryDonutChart(data: snapshot.featureUsageByCategory)),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(title: 'Conversions & upgrades', subtitle: 'Rates are aggregated and never tied to user content.'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              _RateTile(label: 'Signup → First profile', rate: snapshot.conversions.signupToFirstProfile, icon: Icons.person_add_alt_1_outlined),
              _RateTile(label: 'First profile → First upload', rate: snapshot.conversions.firstProfileToFirstUpload, icon: Icons.upload_file_outlined),
              _RateTile(label: 'First upload → Recurring usage', rate: snapshot.conversions.firstUploadToRecurring, icon: Icons.repeat_rounded),
              MetricTile(label: 'Upgrade prompt views', value: formatCompactInt(snapshot.conversions.upgradePromptViews), icon: Icons.new_releases_outlined),
              MetricTile(label: 'Upgrade clicks', value: formatCompactInt(snapshot.conversions.upgradeClicks), icon: Icons.ads_click_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AdminCard(
            header: Text('Privacy guardrails', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            child: Text(
              'This section never shows search queries, AI prompts/responses, document names, or any medical content. Only aggregated counts, rates, and cohort-level diagnostics are displayed.',
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _UsageFeatureUsageTab extends StatelessWidget {
  const _UsageFeatureUsageTab({required this.snapshot});
  final UsageAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Feature Usage', subtitle: 'Event totals only. No prompts, names, or content.'),
          const SizedBox(height: AppSpacing.md),
          AdminCard(
            header: Text('Top features (events)', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            child: SizedBox(height: 320, child: _FeatureBarChart(rows: snapshot.featureUsage.take(10).toList())),
          ),
          const SizedBox(height: AppSpacing.md),
          _FeatureUsageTable(rows: snapshot.featureUsage),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _UsageScreenUsageTab extends StatelessWidget {
  const _UsageScreenUsageTab({required this.snapshot});
  final UsageAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Page/Screen Usage', subtitle: 'Views, unique users, duration, exits, and errors.'),
          const SizedBox(height: AppSpacing.md),
          _ScreenUsageTable(rows: snapshot.screenUsage),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _UsageFunnelsTab extends StatelessWidget {
  const _UsageFunnelsTab({required this.snapshot});
  final UsageAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Funnels', subtitle: 'Drop-offs by step to identify friction (no content).'),
          const SizedBox(height: AppSpacing.md),
          for (final funnel in snapshot.funnels) ...[
            _FunnelCard(funnel: funnel),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _UsageRetentionTab extends StatelessWidget {
  const _UsageRetentionTab({required this.snapshot});
  final UsageAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Retention', subtitle: 'Cohort-level retention rates (aggregated).'),
          const SizedBox(height: AppSpacing.md),
          _MetricsGrid(
            children: [
              _RateTile(label: 'Day 1 retention', rate: snapshot.retention.day1, icon: Icons.filter_1_outlined),
              _RateTile(label: 'Day 7 retention', rate: snapshot.retention.day7, icon: Icons.filter_7_outlined),
              _RateTile(label: 'Day 30 retention', rate: snapshot.retention.day30, icon: Icons.calendar_month_outlined),
              _RateTile(label: 'Weekly retention', rate: snapshot.retention.weeklyRetention, icon: Icons.calendar_view_week_outlined),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdminCard(child: SizedBox(height: 240, child: _RetentionBars(retention: snapshot.retention))),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _UsageCountryTab extends StatelessWidget {
  const _UsageCountryTab({required this.snapshot});
  final UsageAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Country Usage', subtitle: 'Countries with <10 users are grouped as “Other”.'),
          const SizedBox(height: AppSpacing.md),
          _CountryUsageTable(rows: snapshot.countryUsage),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _UsagePlatformTab extends StatelessWidget {
  const _UsagePlatformTab({required this.snapshot});
  final UsageAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Platform Usage', subtitle: 'Aggregated account distribution.'),
          const SizedBox(height: AppSpacing.md),
          AdminCard(
            header: Text('Distribution', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            child: SizedBox(height: 240, child: _PlatformPieChart(platformUsage: snapshot.platformUsage)),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ------------------------------
// Shared UI widgets
// ------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= AdminBreakpoints.desktop ? 4 : width >= AdminBreakpoints.tablet ? 2 : 1;
    return GridView.count(
      crossAxisCount: cols,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.9,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({required this.label, required this.rate, required this.icon});
  final String label;
  final double rate;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final pct = (rate * 100).clamp(0, 100).toStringAsFixed(0);
    return MetricTile(label: label, value: '$pct%', icon: icon, deltaLabel: _rateLabel(rate));
  }

  String _rateLabel(double r) {
    if (r >= 0.65) return 'Strong';
    if (r >= 0.40) return 'Healthy';
    if (r >= 0.22) return 'Needs attention';
    return 'Critical';
  }
}

String _formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m <= 0) return '${seconds}s';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}

// ------------------------------
// Charts
// ------------------------------

class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Center(child: Text('No data', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)));
    }

    final total = entries.fold<int>(0, (a, e) => a + e.value);
    final palette = <Color>[cs.primary, cs.secondary, cs.tertiary ?? cs.primary, cs.primaryContainer, cs.secondaryContainer, cs.tertiaryContainer ?? cs.secondaryContainer];

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 56,
              sections: [
                for (int i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: palette[i % palette.length].withValues(alpha: 0.9),
                    title: '',
                    radius: 52,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length].withValues(alpha: 0.9), borderRadius: BorderRadius.circular(99))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entries[i].key, style: Theme.of(context).textTheme.labelLarge)),
                      Text('${((entries[i].value / total) * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
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
  const _FeatureBarChart({required this.rows});
  final List<UsageFeatureUsageRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxV = rows.map((e) => e.eventCount).fold<int>(0, (a, b) => a > b ? a : b).clamp(1, 1 << 31);

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= rows.length) return const SizedBox.shrink();
                final label = rows[idx].feature;
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(label.length > 10 ? '${label.substring(0, 10)}…' : label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
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
                  toY: rows[i].eventCount.toDouble(),
                  color: cs.primary,
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxV.toDouble(), color: cs.surfaceContainerHighest.withValues(alpha: 0.45)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RetentionBars extends StatelessWidget {
  const _RetentionBars({required this.retention});
  final UsageRetentionSnapshot retention;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <(String, double)>[
      ('D1', retention.day1),
      ('D7', retention.day7),
      ('D30', retention.day30),
      ('Weekly', retention.weeklyRetention),
    ];

    return BarChart(
      BarChartData(
        maxY: 1,
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 0.25, getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.35), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 0.25,
              getTitlesWidget: (value, meta) => Text('${(value * 100).toInt()}%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= items.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(items[i].$1, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: items[i].$2, color: cs.secondary, width: 18, borderRadius: BorderRadius.circular(6)),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlatformPieChart extends StatelessWidget {
  const _PlatformPieChart({required this.platformUsage});
  final Map<String, int> platformUsage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = platformUsage.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    if (total == 0) return const SizedBox.shrink();

    final colors = <Color>[cs.primary, cs.secondary, cs.tertiary ?? cs.primaryContainer];
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 52,
              sections: [
                for (int i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: colors[i % colors.length].withValues(alpha: 0.92),
                    title: '',
                    radius: 48,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length].withValues(alpha: 0.92), borderRadius: BorderRadius.circular(99))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entries[i].key, style: Theme.of(context).textTheme.labelLarge)),
                      Text(formatCompactInt(entries[i].value), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
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

// ------------------------------
// Tables & cards
// ------------------------------

class _FeatureUsageTable extends StatelessWidget {
  const _FeatureUsageTable({required this.rows});
  final List<UsageFeatureUsageRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return AdminCard(
      header: Text('All features', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      padding: const EdgeInsets.all(0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: t.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
          dataTextStyle: t.labelLarge?.copyWith(color: cs.onSurface),
          columns: const [
            DataColumn(label: Text('Feature')),
            DataColumn(label: Text('Events')),
            DataColumn(label: Text('Unique users')),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                cells: [
                  DataCell(Text(r.feature)),
                  DataCell(Text(formatCompactInt(r.eventCount))),
                  DataCell(Text(formatCompactInt(r.uniqueUsers))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ScreenUsageTable extends StatelessWidget {
  const _ScreenUsageTable({required this.rows});
  final List<UsageScreenUsageRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return AdminCard(
      padding: const EdgeInsets.all(0),
      header: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text('Screens', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: t.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
          dataTextStyle: t.labelLarge?.copyWith(color: cs.onSurface),
          columns: const [
            DataColumn(label: Text('Screen name')),
            DataColumn(label: Text('Views')),
            DataColumn(label: Text('Unique users')),
            DataColumn(label: Text('Avg duration')),
            DataColumn(label: Text('Exit rate')),
            DataColumn(label: Text('Error count')),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                cells: [
                  DataCell(Text(r.screenName)),
                  DataCell(Text(formatCompactInt(r.views))),
                  DataCell(Text(formatCompactInt(r.uniqueUsers))),
                  DataCell(Text(_formatDuration(r.avgDurationSeconds))),
                  DataCell(Text('${(r.exitRate * 100).toStringAsFixed(0)}%')),
                  DataCell(Text(formatCompactInt(r.errorCount))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.funnel});
  final UsageFunnel funnel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final maxCount = funnel.steps.map((e) => e.count).fold<int>(0, (a, b) => a > b ? a : b).clamp(1, 1 << 31);

    return AdminCard(
      header: Row(
        children: [
          Text(funnel.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('Top step: ${formatCompactInt(maxCount)}', style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < funnel.steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _FunnelStepRow(
                index: i,
                step: funnel.steps[i],
                maxCount: maxCount,
                previous: i == 0 ? null : funnel.steps[i - 1],
              ),
            ),
        ],
      ),
    );
  }
}

class _FunnelStepRow extends StatelessWidget {
  const _FunnelStepRow({required this.index, required this.step, required this.maxCount, required this.previous});
  final int index;
  final UsageFunnelStep step;
  final int maxCount;
  final UsageFunnelStep? previous;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ratio = (step.count / maxCount).clamp(0.0, 1.0);
    final stepRate = (previous == null || previous!.count == 0) ? null : (step.count / previous!.count).clamp(0.0, 1.0);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: cs.outline.withValues(alpha: 0.2))),
          alignment: Alignment.center,
          child: Text('${index + 1}', style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: Text(step.label, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 90,
          child: Text(formatCompactInt(step.count), textAlign: TextAlign.right, style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 86,
          child: Text(
            stepRate == null ? '—' : '${(stepRate * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _CountryUsageTable extends StatelessWidget {
  const _CountryUsageTable({required this.rows});
  final List<CountryUsageRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return AdminCard(
      padding: const EdgeInsets.all(0),
      header: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text('Countries', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: t.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
          dataTextStyle: t.labelLarge?.copyWith(color: cs.onSurface),
          columns: const [
            DataColumn(label: Text('Country')),
            DataColumn(label: Text('Total users')),
            DataColumn(label: Text('Active (30d)')),
            DataColumn(label: Text('Storage used')),
            DataColumn(label: Text('AI tokens (month)')),
            DataColumn(label: Text('Paid users')),
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
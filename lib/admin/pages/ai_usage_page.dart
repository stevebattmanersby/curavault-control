import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/state/admin_theme_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AiUsagePage extends StatelessWidget {
  const AiUsagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final snap = store.aiUsage;
    final isLoading = store.isLoading || store.isAiUsageLoading;

    return AdminPageScaffold(
      title: 'AI Usage',
      subtitle: 'Tokens, cost, limits, and errors (privacy-safe; never prompts or outputs).',
      actions: [
        _AiUsageFiltersBar(query: store.aiUsageQuery, onChanged: store.setAiUsageQuery),
        IconButton(
          onPressed: () => context.read<AdminStore>().refreshAiUsage(),
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
              ? _EmptyAiUsageState(query: store.aiUsageQuery)
              : _AiUsageTabs(snapshot: snap),
    );
  }
}

class _EmptyAiUsageState extends StatelessWidget {
  const _EmptyAiUsageState({required this.query});
  final AiUsageQuery query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text('No AI usage data yet.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Connect Supabase summary views or refresh to load mock aggregates (${query.range.label}).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AiUsageTabs extends StatelessWidget {
  const _AiUsageTabs({required this.snapshot});
  final AiUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          const _AiUsageTabBar(),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: TabBarView(
              children: [
                _AiOverviewTab(snapshot: snapshot),
                _TokenUsageTab(snapshot: snapshot),
                _CostMonitoringTab(snapshot: snapshot),
                _LimitMonitoringTab(snapshot: snapshot),
                _AiErrorsTab(snapshot: snapshot),
                _UsageByFeatureTab(snapshot: snapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiUsageTabBar extends StatelessWidget {
  const _AiUsageTabBar();

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
          Tab(text: 'AI overview'),
          Tab(text: 'Token usage'),
          Tab(text: 'Cost monitoring'),
          Tab(text: 'Limit monitoring'),
          Tab(text: 'AI errors'),
          Tab(text: 'Usage by feature'),
        ],
      ),
    );
  }
}

class _AiUsageFiltersBar extends StatelessWidget {
  const _AiUsageFiltersBar({required this.query, required this.onChanged});
  final AiUsageQuery query;
  final ValueChanged<AiUsageQuery> onChanged;

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

  Future<void> _showFiltersSheet(BuildContext context, AiUsageQuery query) async {
    final res = await showModalBottomSheet<AiUsageQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AiUsageFiltersSheet(initial: query),
    );
    if (res != null) onChanged(res);
  }
}

class _AiUsageFiltersSheet extends StatefulWidget {
  const _AiUsageFiltersSheet({required this.initial});
  final AiUsageQuery initial;

  @override
  State<_AiUsageFiltersSheet> createState() => _AiUsageFiltersSheetState();
}

class _AiUsageFiltersSheetState extends State<_AiUsageFiltersSheet> {
  late AiUsageQuery _q;

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
          boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Filters', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  splashColor: Colors.transparent,
                  highlightColor: cs.primary.withValues(alpha: 0.06),
                  hoverColor: cs.primary.withValues(alpha: 0.06),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('All AI metrics are aggregates only (no prompt/output content).', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FilterChip(
                  label: 'Country',
                  value: _q.country,
                  options: countries,
                  onChanged: (v) => setState(() => _q = _q.copyWith(country: v, clearCountry: v == null)),
                ),
                _FilterChip(
                  label: 'Platform',
                  value: _q.platform,
                  options: platforms,
                  onChanged: (v) => setState(() => _q = _q.copyWith(platform: v, clearPlatform: v == null)),
                ),
                _FilterChip(
                  label: 'Plan',
                  value: _q.plan,
                  options: plans,
                  onChanged: (v) => setState(() => _q = _q.copyWith(plan: v, clearPlan: v == null)),
                ),
                _FilterChip(
                  label: 'App version',
                  value: _q.appVersion,
                  options: versions,
                  onChanged: (v) => setState(() => _q = _q.copyWith(appVersion: v, clearAppVersion: v == null)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _q = AiUsageQuery(range: _q.range)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: Text('Clear', style: t.labelLarge?.copyWith(color: cs.onSurface)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_q),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: Text('Apply', style: t.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800)),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              hint: Text('Any', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
              icon: Icon(Icons.expand_more, color: cs.onSurfaceVariant, size: 18),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Any')),
                for (final o in options) DropdownMenuItem<String?>(value: o, child: Text(o)),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiOverviewTab extends StatelessWidget {
  const _AiOverviewTab({required this.snapshot});
  final AiUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AdminCard(
          aiEmphasis: isAiTheme,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: cs.onSurfaceVariant, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Privacy rule: this workspace shows only counts, tokens, model names, feature areas, costs, and error codes. It never displays or stores prompts/responses or any health content.',
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricCard(title: 'AI requests (month)', value: formatCompactInt(snapshot.aiRequestsThisMonth), icon: Icons.call_made, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Input tokens (month)', value: formatCompactInt(snapshot.inputTokensThisMonth), icon: Icons.keyboard_alt_outlined, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Output tokens (month)', value: formatCompactInt(snapshot.outputTokensThisMonth), icon: Icons.auto_awesome_outlined, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Total tokens (month)', value: formatCompactInt(snapshot.totalTokensThisMonth), icon: Icons.stacked_line_chart_outlined, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Estimated cost (month)', value: AdminFormatters.usd(snapshot.estimatedCostThisMonthUsd), icon: Icons.payments_outlined, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Avg tokens / request', value: snapshot.avgTokensPerRequest.toStringAsFixed(0), icon: Icons.functions_outlined, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Failed AI requests', value: formatCompactInt(snapshot.failedAiRequestsThisMonth), icon: Icons.error_outline, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Users near AI limit', value: formatCompactInt(snapshot.usersNearAiLimit), icon: Icons.warning_amber_outlined, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Users over AI limit', value: formatCompactInt(snapshot.usersOverAiLimit), icon: Icons.block_outlined, aiEmphasis: isAiTheme),
          ],
        ),
        if (isAiTheme && (snapshot.usersNearAiLimit > 0 || snapshot.usersOverAiLimit > 0)) ...[
          const SizedBox(height: AppSpacing.md),
          _AiLimitAlertBox(usersNearLimit: snapshot.usersNearAiLimit, usersOverLimit: snapshot.usersOverAiLimit),
        ],
        const SizedBox(height: AppSpacing.md),
        _Panel(
          title: 'Tokens by day',
          subtitle: 'Input vs output token totals (aggregate).',
          child: SizedBox(height: 220, child: _TokensByDayLineChart(points: snapshot.tokensByDay)),
        ),
      ],
    );
  }
}

class _TokenUsageTab extends StatelessWidget {
  const _TokenUsageTab({required this.snapshot});
  final AiUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Panel(title: 'Tokens by day', subtitle: 'Total input + output tokens per day.', child: SizedBox(height: 220, child: _TotalTokensByDayLineChart(points: snapshot.tokensByDay))),
        const SizedBox(height: AppSpacing.md),
        _Panel(title: 'Tokens by feature', subtitle: 'Feature area share (no content).', child: SizedBox(height: 240, child: _TokensByFeatureBarChart(data: snapshot.tokensByFeature))),
        const SizedBox(height: AppSpacing.md),
        _Panel(title: 'Tokens by plan', subtitle: 'Plan cohort totals.', child: SizedBox(height: 220, child: _TokensByStringBarChart(data: snapshot.tokensByPlan))),
        const SizedBox(height: AppSpacing.md),
        _Panel(title: 'Tokens by platform', subtitle: 'iOS / Android / Web.', child: SizedBox(height: 220, child: _TokensByStringBarChart(data: snapshot.tokensByPlatform))),
        const SizedBox(height: AppSpacing.md),
        _Panel(title: 'Tokens by country', subtitle: 'Country-level totals (aggregated).', child: SizedBox(height: 240, child: _TokensByStringBarChart(data: snapshot.tokensByCountry))),
      ],
    );
  }
}

class _CostMonitoringTab extends StatelessWidget {
  const _CostMonitoringTab({required this.snapshot});
  final AiUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final role = context.watch<AdminAuthStore>().role ?? AdminRole.readOnly;
    final canViewEmail = AdminRbac.canViewUserEmail(role);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricCard(title: 'Estimated daily cost', value: AdminFormatters.usd(snapshot.estimatedDailyCostUsd), icon: Icons.show_chart_outlined, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Estimated monthly cost', value: AdminFormatters.usd(snapshot.estimatedMonthlyCostUsd), icon: Icons.calendar_month_outlined, aiEmphasis: isAiTheme),
            _MetricCard(title: 'Cost per active user', value: AdminFormatters.usd(snapshot.costPerActiveUserUsd), icon: Icons.person_outline, aiEmphasis: isAiTheme),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Panel(title: 'Estimated daily cost', subtitle: 'Daily estimated AI cost (aggregate).', child: SizedBox(height: 220, child: _DailyCostLineChart(points: snapshot.dailyCost))),
        const SizedBox(height: AppSpacing.md),
        _Panel(title: 'Cost by plan', subtitle: 'Monthly estimated cost by plan.', child: SizedBox(height: 220, child: _CostByPlanBarChart(data: snapshot.costByPlan))),
        const SizedBox(height: AppSpacing.md),
        _Panel(title: 'Cost by feature', subtitle: 'Feature area cost drivers.', child: SizedBox(height: 240, child: _CostByFeatureBarChart(data: snapshot.costByFeature))),
        const SizedBox(height: AppSpacing.md),
        AdminCard(
          aiEmphasis: isAiTheme,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    Expanded(child: Text('High-cost users', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isAiTheme ? context.tokens.aiAccent : cs.tertiaryContainer).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: (isAiTheme ? context.tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Cost-only; no content',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: isAiTheme ? context.tokens.textPrimary : cs.onTertiaryContainer, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  headingTextStyle: Theme.of(context).textTheme.labelLarge,
                  dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                  columns: [
                    const DataColumn(label: Text('User ID')),
                    if (canViewEmail) const DataColumn(label: Text('Email')),
                    const DataColumn(label: Text('Plan')),
                    const DataColumn(label: Text('Est. cost')),
                    const DataColumn(label: Text('Tokens')),
                    const DataColumn(label: Text('AI requests')),
                    const DataColumn(label: Text('Last AI request')),
                  ],
                  rows: [
                    for (final r in snapshot.highCostUsers)
                      DataRow(
                        cells: [
                          DataCell(Text(r.userId)),
                          if (canViewEmail) DataCell(Text(r.email ?? '—')),
                          DataCell(Text(r.plan)),
                          DataCell(Text(AdminFormatters.usd(r.estimatedCostUsd))),
                          DataCell(Text(formatCompactInt(r.totalTokens))),
                          DataCell(Text(formatCompactInt(r.aiRequests))),
                          DataCell(Text(formatDateTimeShort(r.lastAiRequestAt))),
                        ],
                      ),
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

class _LimitMonitoringTab extends StatelessWidget {
  const _LimitMonitoringTab({required this.snapshot});
  final AiUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final role = context.watch<AdminAuthStore>().role ?? AdminRole.readOnly;
    final canViewEmail = AdminRbac.canViewUserEmail(role);

    final rows = snapshot.limitMonitoring;
    return AdminCard(
      aiEmphasis: isAiTheme,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('Limit monitoring', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isAiTheme ? context.tokens.aiAccent : cs.surfaceContainerHighest).withValues(alpha: isAiTheme ? 0.10 : 1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: (isAiTheme ? context.tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.45)),
                  ),
                  child: Text('Sorted by % used', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          if (isAiTheme && (snapshot.usersNearAiLimit > 0 || snapshot.usersOverAiLimit > 0)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _AiLimitAlertBox(usersNearLimit: snapshot.usersNearAiLimit, usersOverLimit: snapshot.usersOverAiLimit, compact: true),
            ),
          ],
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyState(label: 'No limit monitoring rows available.')
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
                        const DataColumn(label: Text('Plan')),
                        const DataColumn(label: Text('Monthly token limit')),
                        const DataColumn(label: Text('Tokens used')),
                        const DataColumn(label: Text('Remaining tokens')),
                        const DataColumn(label: Text('AI requests')),
                        const DataColumn(label: Text('Limit reached count')),
                        const DataColumn(label: Text('Last AI request')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r.userId)),
                              if (canViewEmail) DataCell(Text(r.email ?? '—')),
                              DataCell(Text(r.plan)),
                              DataCell(Text(formatCompactInt(r.monthlyTokenLimit))),
                              DataCell(Row(children: [
                                Text(formatCompactInt(r.tokensUsed)),
                                const SizedBox(width: 10),
                                _LimitUsagePill(used: r.tokensUsed, limit: r.monthlyTokenLimit),
                              ])),
                              DataCell(Text(formatCompactInt(r.remainingTokens))),
                              DataCell(Text(formatCompactInt(r.aiRequests))),
                              DataCell(Text(r.limitReachedCount.toString())),
                              DataCell(Text(formatDateTimeShort(r.lastAiRequestAt))),
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

class _AiErrorsTab extends StatelessWidget {
  const _AiErrorsTab({required this.snapshot});
  final AiUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final rows = snapshot.aiErrors;
    return AdminCard(
      aiEmphasis: isAiTheme,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('AI errors', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isAiTheme ? context.tokens.aiAccent : cs.tertiaryContainer).withValues(alpha: isAiTheme ? 0.12 : 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: (isAiTheme ? context.tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.45)),
                  ),
                  child: Text('User IDs are pseudonymized', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyState(label: 'No AI error rows available.')
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
                        DataColumn(label: Text('Feature area')),
                        DataColumn(label: Text('Model')),
                        DataColumn(label: Text('Error code')),
                        DataColumn(label: Text('Result')),
                        DataColumn(label: Text('Platform')),
                        DataColumn(label: Text('App version')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(formatDateTimeShort(r.occurredAt))),
                              DataCell(Text(r.userPseudonym)),
                              DataCell(Text(r.featureArea.label)),
                              DataCell(Text(r.model)),
                              DataCell(Text(r.errorCode)),
                              DataCell(_ResultPill(result: r.result)),
                              DataCell(Text(r.platform)),
                              DataCell(Text(r.appVersion)),
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

class _UsageByFeatureTab extends StatelessWidget {
  const _UsageByFeatureTab({required this.snapshot});
  final AiUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final rows = snapshot.usageByFeature;
    return AdminCard(
      aiEmphasis: isAiTheme,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('Usage by feature', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isAiTheme ? context.tokens.aiAccent : cs.surfaceContainerHighest).withValues(alpha: isAiTheme ? 0.10 : 1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: (isAiTheme ? context.tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.45)),
                  ),
                  child: Text('Sorted by tokens', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyState(label: 'No feature usage rows available.')
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingTextStyle: Theme.of(context).textTheme.labelLarge,
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                      columns: const [
                        DataColumn(label: Text('Feature area')),
                        DataColumn(label: Text('Requests')),
                        DataColumn(label: Text('Input tokens')),
                        DataColumn(label: Text('Output tokens')),
                        DataColumn(label: Text('Total tokens')),
                        DataColumn(label: Text('Failed requests')),
                        DataColumn(label: Text('Fail rate')),
                        DataColumn(label: Text('Est. cost')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r.featureArea.label)),
                              DataCell(Text(formatCompactInt(r.requests))),
                              DataCell(Text(formatCompactInt(r.inputTokens))),
                              DataCell(Text(formatCompactInt(r.outputTokens))),
                              DataCell(Text(formatCompactInt(r.totalTokens))),
                              DataCell(Text(formatCompactInt(r.failedRequests))),
                              DataCell(Text('${(r.failRate * 100).toStringAsFixed(1)}%')),
                              DataCell(Text(AdminFormatters.usd(r.estimatedCostUsd))),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon, required this.aiEmphasis});
  final String title;
  final String value;
  final IconData icon;
  final bool aiEmphasis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final w = MediaQuery.sizeOf(context).width;
    final isNarrow = w < 980;
    final double cardWidth = isNarrow ? (w - 48) / 2 : 260.0;

    return SizedBox(
      width: cardWidth,
      child: AdminCard(
        aiEmphasis: aiEmphasis,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: aiEmphasis
                    ? LinearGradient(colors: [tokens.primary.withValues(alpha: 0.30), tokens.aiAccent.withValues(alpha: 0.26)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: aiEmphasis ? null : cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: (aiEmphasis ? tokens.borderGlow : cs.outline).withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: aiEmphasis ? tokens.textPrimary : cs.onPrimaryContainer, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    return AdminCard(
      aiEmphasis: isAiTheme,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AiLimitAlertBox extends StatelessWidget {
  const _AiLimitAlertBox({required this.usersNearLimit, required this.usersOverLimit, this.compact = false});
  final int usersNearLimit;
  final int usersOverLimit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final over = usersOverLimit;
    final near = usersNearLimit;

    final headline = over > 0 ? 'AI limit exceeded' : 'AI limit nearing';
    final detail = over > 0
        ? '$over users are currently over their AI limit. These requests should be blocked or queued (by policy).' // aggregate-only
        : '$near users are within 15% of their AI limit. Consider monitoring and proactive outreach.';

    // Red/pink warning style in AI theme; still readable.
    final bg = cs.errorContainer.withValues(alpha: 0.55);
    final border = Color.lerp(cs.error, tokens.borderGlow, 0.25)?.withValues(alpha: 0.75) ?? cs.error.withValues(alpha: 0.75);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border, width: 1),
        boxShadow: [BoxShadow(color: cs.error.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Icon(over > 0 ? Icons.report_gmailerrorred_outlined : Icons.warning_amber_outlined, color: cs.onErrorContainer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: t.labelLarge?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(detail, style: t.bodySmall?.copyWith(color: cs.onErrorContainer.withValues(alpha: 0.92), height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.error.withValues(alpha: 0.35)),
            ),
            child: Text(over > 0 ? 'Over: $over' : 'Near: $near', style: t.labelMedium?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _LimitUsagePill extends StatelessWidget {
  const _LimitUsagePill({required this.used, required this.limit});
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final tokens = context.tokens;
    final pct = (limit <= 0) ? 0.0 : (used / limit);
    final bg = pct >= 1.0
        ? cs.errorContainer
        : (pct >= 0.85)
            ? cs.tertiaryContainer
            : cs.surfaceContainerHighest;
    final fg = pct >= 1.0
        ? cs.onErrorContainer
        : (pct >= 0.85)
            ? cs.onTertiaryContainer
            : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: isAiTheme
            ? LinearGradient(
                colors: [
                  (pct >= 1.0 ? cs.error : (pct >= 0.85 ? tokens.warning : tokens.aiAccent)).withValues(alpha: 0.26),
                  (pct >= 1.0 ? cs.error : tokens.primary).withValues(alpha: 0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isAiTheme ? null : bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (isAiTheme ? tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.35)),
      ),
      child: Text('${(pct * 100).clamp(0, 999).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.result});
  final String result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = result.toLowerCase();
    final (bg, fg) = switch (r) {
      'blocked' => (cs.tertiaryContainer, cs.onTertiaryContainer),
      'failed' => (cs.errorContainer, cs.onErrorContainer),
      'ok' => (cs.primaryContainer, cs.onPrimaryContainer),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Text(result, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

// ------------------------------
// Charts
// ------------------------------

class _TokensByDayLineChart extends StatelessWidget {
  const _TokensByDayLineChart({required this.points});
  final List<AiTokensTimeseriesPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final maxY = points.map((e) => e.totalTokens).reduce((a, b) => a > b ? a : b).toDouble();
    final spotsIn = <FlSpot>[];
    final spotsOut = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spotsIn.add(FlSpot(i.toDouble(), points[i].inputTokens.toDouble()));
      spotsOut.add(FlSpot(i.toDouble(), points[i].outputTokens.toDouble()));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.15,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: (isAiTheme ? tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.14), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(formatCompactInt(value.round()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: points.length <= 10 ? 1 : (points.length / 6).roundToDouble(),
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final d = points[idx].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${d.month}/${d.day}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spotsIn,
            isCurved: true,
            barWidth: 3,
            color: isAiTheme ? tokens.primary : cs.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: (isAiTheme ? tokens.primary : cs.primary).withValues(alpha: isAiTheme ? 0.14 : 0.10)),
          ),
          LineChartBarData(
            spots: spotsOut,
            isCurved: true,
            barWidth: 3,
            color: isAiTheme ? tokens.aiAccent : cs.tertiary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: (isAiTheme ? tokens.aiAccent : cs.tertiary).withValues(alpha: isAiTheme ? 0.12 : 0.08)),
          ),
        ],
      ),
    );
  }
}

class _TotalTokensByDayLineChart extends StatelessWidget {
  const _TotalTokensByDayLineChart({required this.points});
  final List<AiTokensTimeseriesPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final maxY = points.map((e) => e.totalTokens).reduce((a, b) => a > b ? a : b).toDouble();
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].totalTokens.toDouble()));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.15,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: (isAiTheme ? tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.14), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(formatCompactInt(value.round()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: points.length <= 10 ? 1 : (points.length / 6).roundToDouble(),
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final d = points[idx].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${d.month}/${d.day}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            color: isAiTheme ? tokens.primary : cs.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: (isAiTheme ? tokens.primary : cs.primary).withValues(alpha: isAiTheme ? 0.14 : 0.10)),
          ),
        ],
      ),
    );
  }
}

class _TokensByFeatureBarChart extends StatelessWidget {
  const _TokensByFeatureBarChart({required this.data});
  final Map<AiFeatureArea, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: entries.length * 92,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(color: (isAiTheme ? tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.14), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(formatCompactInt(value.round()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                    final label = entries[i].key.label;
                    final short = label.length <= 12 ? label : '${label.substring(0, 12)}…';
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(short, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < entries.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value.toDouble(),
                      width: 18,
                      borderRadius: BorderRadius.circular(8),
                      gradient: isAiTheme ? LinearGradient(colors: [tokens.aiAccent, tokens.primary], begin: Alignment.bottomCenter, end: Alignment.topCenter) : null,
                      color: isAiTheme ? null : cs.primary,
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: (isAiTheme ? tokens.surfaceElevated : cs.surfaceContainerHighest).withValues(alpha: 0.45)),
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

class _TokensByStringBarChart extends StatelessWidget {
  const _TokensByStringBarChart({required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: entries.length * 88,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(color: (isAiTheme ? tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.14), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(formatCompactInt(value.round()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(entries[i].key, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < entries.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value.toDouble(),
                      width: 18,
                      borderRadius: BorderRadius.circular(8),
                      gradient: isAiTheme ? LinearGradient(colors: [tokens.aiAccent, tokens.primary], begin: Alignment.bottomCenter, end: Alignment.topCenter) : null,
                      color: isAiTheme ? null : cs.primary,
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: (isAiTheme ? tokens.surfaceElevated : cs.surfaceContainerHighest).withValues(alpha: 0.45)),
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

class _DailyCostLineChart extends StatelessWidget {
  const _DailyCostLineChart({required this.points});
  final List<AiCostTimeseriesPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final maxY = points.map((e) => e.estimatedCostUsd).reduce((a, b) => a > b ? a : b);
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].estimatedCostUsd));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: (isAiTheme ? tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.14), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(AdminFormatters.usd(value.toDouble()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: points.length <= 10 ? 1 : (points.length / 6).roundToDouble(),
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                final d = points[idx].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${d.month}/${d.day}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            color: isAiTheme ? tokens.primary : cs.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: (isAiTheme ? tokens.primary : cs.primary).withValues(alpha: isAiTheme ? 0.14 : 0.10)),
          ),
        ],
      ),
    );
  }
}

class _CostByPlanBarChart extends StatelessWidget {
  const _CostByPlanBarChart({required this.data});
  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: entries.length * 88,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(color: (isAiTheme ? tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.14), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(AdminFormatters.usd(value.toDouble()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(entries[i].key, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < entries.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value,
                      width: 18,
                      borderRadius: BorderRadius.circular(8),
                      gradient: isAiTheme ? LinearGradient(colors: [tokens.aiAccent, tokens.primary], begin: Alignment.bottomCenter, end: Alignment.topCenter) : null,
                      color: isAiTheme ? null : cs.primary,
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: (isAiTheme ? tokens.surfaceElevated : cs.surfaceContainerHighest).withValues(alpha: 0.45)),
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

class _CostByFeatureBarChart extends StatelessWidget {
  const _CostByFeatureBarChart({required this.data});
  final Map<AiFeatureArea, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isAiTheme = context.select<AdminThemeStore, bool>((s) => s.mode == AdminThemeMode.ai);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: entries.length * 96,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(color: (isAiTheme ? tokens.borderGlow : cs.outlineVariant).withValues(alpha: 0.14), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(AdminFormatters.usd(value.toDouble()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                    final label = entries[i].key.label;
                    final short = label.length <= 12 ? label : '${label.substring(0, 12)}…';
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(short, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textSecondary)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < entries.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value,
                      width: 18,
                      borderRadius: BorderRadius.circular(8),
                      gradient: isAiTheme ? LinearGradient(colors: [tokens.aiAccent, tokens.primary], begin: Alignment.bottomCenter, end: Alignment.topCenter) : null,
                      color: isAiTheme ? null : cs.primary,
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: (isAiTheme ? tokens.surfaceElevated : cs.surfaceContainerHighest).withValues(alpha: 0.45)),
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

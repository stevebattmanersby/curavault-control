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

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
    final billing = store.billing;
    final role = context.watch<AdminAuthStore>().role ?? AdminRole.readOnly;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Billing', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Track plans, trials, paid users, payment failures, and revenue. No health data is shown.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _BillingToolbar(role: role),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            dividerColor: cs.outlineVariant.withValues(alpha: 0.35),
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Subscriptions'),
              Tab(text: 'Trials'),
              Tab(text: 'Failed payments'),
              Tab(text: 'Revenue by plan'),
              Tab(text: 'Revenue by country'),
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
                  _BillingOverviewTab(overview: billing?.overview, isLoading: store.isBillingLoading, generatedAt: billing?.generatedAt),
                  _SubscriptionsTab(rows: billing?.subscriptions ?? const [], isLoading: store.isBillingLoading, role: role),
                  _TrialsTab(rows: billing?.trials ?? const [], isLoading: store.isBillingLoading, role: role),
                  _FailedPaymentsTab(rows: billing?.failedPayments ?? const [], isLoading: store.isBillingLoading, role: role),
                  _RevenueByPlanTab(rows: billing?.revenueByPlan ?? const [], isLoading: store.isBillingLoading),
                  _RevenueByCountryTab(rows: billing?.revenueByCountry ?? const [], isLoading: store.isBillingLoading),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingToolbar extends StatelessWidget {
  const _BillingToolbar({required this.role});
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final cs = Theme.of(context).colorScheme;
    final q = store.billingQuery;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _RangePill(
          label: q.range.label,
          onPressed: () async {
            final preset = await showModalBottomSheet<AdminDateRangePreset>(
              context: context,
              showDragHandle: true,
              builder: (context) => const _RangeSheet(),
            );
            if (preset == null) return;
            await context.read<AdminStore>().setBillingQuery(q.copyWith(range: preset));
          },
        ),
        _FilterPill(
          label: q.country == null && q.plan == null && q.provider == null ? 'Filters' : 'Filters • active',
          icon: Icons.tune,
          onPressed: () async {
            final next = await showModalBottomSheet<BillingQuery>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: _BillingFiltersSheet(initial: q),
              ),
            );
            if (next == null) return;
            await context.read<AdminStore>().setBillingQuery(next);
          },
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => context.read<AdminStore>().refreshBilling(),
          icon: Icon(Icons.refresh, color: cs.onSurface),
        ),
        if (!AdminRbac.canPerformBillingAction(role, BillingAdminAction.addBillingNote))
          _HintBadge(label: 'Read-only for your role', icon: Icons.lock_outline)
        else
          const _HintBadge(label: 'Actions are audited', icon: Icons.verified_user_outlined),
      ],
    );
  }
}

class _HintBadge extends StatelessWidget {
  const _HintBadge({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.calendar_today_outlined, size: 18, color: cs.onSurface),
      label: Text(label, style: TextStyle(color: cs.onSurface)),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: cs.onSurface),
      label: Text(label, style: TextStyle(color: cs.onSurface)),
    );
  }
}

class _RangeSheet extends StatelessWidget {
  const _RangeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final p in AdminDateRangePreset.values)
            ListTile(
              title: Text(p.label),
              onTap: () => Navigator.of(context).pop(p),
            ),
        ],
      ),
    );
  }
}

class _BillingFiltersSheet extends StatefulWidget {
  const _BillingFiltersSheet({required this.initial});
  final BillingQuery initial;

  @override
  State<_BillingFiltersSheet> createState() => _BillingFiltersSheetState();
}

class _BillingFiltersSheetState extends State<_BillingFiltersSheet> {
  late String? _country;
  late String? _plan;
  late BillingSubscriptionProvider? _provider;

  @override
  void initState() {
    super.initState();
    _country = widget.initial.country;
    _plan = widget.initial.plan;
    _provider = widget.initial.provider;
  }

  void _apply() {
    Navigator.of(context).pop(widget.initial.copyWith(country: _country, plan: _plan, provider: _provider));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Billing filters', style: t.titleLarge),
            const SizedBox(height: 8),
            Text('These filters only scope billing summaries and never reveal health content.', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _country,
              decoration: const InputDecoration(labelText: 'Country'),
              items: const <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(value: null, child: Text('All')),
                DropdownMenuItem(value: 'US', child: Text('US')),
                DropdownMenuItem(value: 'CA', child: Text('CA')),
                DropdownMenuItem(value: 'GB', child: Text('GB')),
                DropdownMenuItem(value: 'DE', child: Text('DE')),
                DropdownMenuItem(value: 'AU', child: Text('AU')),
              ],
              onChanged: (v) => setState(() => _country = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _plan,
              decoration: const InputDecoration(labelText: 'Plan'),
              items: const <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(value: null, child: Text('All')),
                DropdownMenuItem(value: 'free', child: Text('free')),
                DropdownMenuItem(value: 'premium', child: Text('premium')),
                DropdownMenuItem(value: 'family', child: Text('family')),
                DropdownMenuItem(value: 'team', child: Text('team')),
                DropdownMenuItem(value: 'enterprise', child: Text('enterprise')),
              ],
              onChanged: (v) => setState(() => _plan = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BillingSubscriptionProvider?>(
              value: _provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: [
                const DropdownMenuItem<BillingSubscriptionProvider?>(value: null, child: Text('All')),
                for (final p in BillingSubscriptionProvider.values) DropdownMenuItem<BillingSubscriptionProvider?>(value: p, child: Text(p.label)),
              ],
              onChanged: (v) => setState(() => _provider = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(widget.initial.copyWith(clearCountry: true, clearPlan: true, clearProvider: true)),
                    child: Text('Clear', style: TextStyle(color: cs.onSurface)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: Text('Apply', style: TextStyle(color: cs.onPrimary)),
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

class _BillingOverviewTab extends StatelessWidget {
  const _BillingOverviewTab({required this.overview, required this.isLoading, required this.generatedAt});
  final BillingOverviewMetrics? overview;
  final bool isLoading;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    if (isLoading && overview == null) return const _LoadingState();
    final cs = Theme.of(context).colorScheme;
    final o = overview;
    if (o == null) return const _EmptyState(label: 'No usage data has been collected yet.');

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(title: 'Active paid users', value: AdminFormatters.compactInt(o.activePaidUsers), icon: Icons.verified_outlined),
            _MetricCard(title: 'Free users', value: AdminFormatters.compactInt(o.freeUsers), icon: Icons.group_outlined),
            _MetricCard(title: 'Trial users', value: AdminFormatters.compactInt(o.trialUsers), icon: Icons.hourglass_top_outlined),
            _MetricCard(title: 'Cancelled users', value: AdminFormatters.compactInt(o.cancelledUsers), icon: Icons.cancel_outlined),
            _MetricCard(title: 'Failed payments', value: AdminFormatters.compactInt(o.failedPayments), icon: Icons.warning_amber_outlined),
            _MetricCard(title: 'MRR', value: AdminFormatters.usd(o.monthlyRecurringRevenueUsd), icon: Icons.trending_up_outlined),
            _MetricCard(title: 'ARR', value: AdminFormatters.usd(o.annualRecurringRevenueUsd), icon: Icons.insights_outlined),
            _MetricCard(title: 'ARPU', value: AdminFormatters.usd(o.averageRevenuePerUserUsd), icon: Icons.payments_outlined),
            _MetricCard(title: 'Trial conversion', value: _formatPct(o.trialConversionRate), icon: Icons.compare_arrows_outlined),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This section surfaces billing metadata only. No invoices, payment methods, addresses, or health content are visible.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              if (generatedAt != null)
                Text(
                  'Updated ${AdminFormatters.relativeTime(generatedAt!)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubscriptionsTab extends StatelessWidget {
  const _SubscriptionsTab({required this.rows, required this.isLoading, required this.role});
  final List<SubscriptionRow> rows;
  final bool isLoading;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSeeEmail = AdminRbac.canViewBillingEmail(role);

    if (isLoading && rows.isEmpty) return const _LoadingState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text('Subscriptions', style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState(label: 'No subscriptions found for the current filters.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingTextStyle: Theme.of(context).textTheme.labelLarge,
                    dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                    columns: [
                      const DataColumn(label: Text('User ID')),
                      if (canSeeEmail) const DataColumn(label: Text('Email')),
                      const DataColumn(label: Text('Plan')),
                      const DataColumn(label: Text('Billing status')),
                      const DataColumn(label: Text('Provider')),
                      const DataColumn(label: Text('Subscription start')),
                      const DataColumn(label: Text('Renewal date')),
                      const DataColumn(label: Text('Cancelled date')),
                      const DataColumn(label: Text('Failure count')),
                      const DataColumn(label: Text('Country')),
                      const DataColumn(label: Text('Manual comp')),
                      const DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          cells: [
                            DataCell(Text(r.userId)),
                            if (canSeeEmail) DataCell(Text(r.email ?? '—')),
                            DataCell(Text(r.plan)),
                            DataCell(_StatusPill(text: r.billingStatus)),
                            DataCell(Text(r.provider.label)),
                            DataCell(Text(AdminFormatters.dateTime(r.subscriptionStart))),
                            DataCell(Text(AdminFormatters.dateTime(r.renewalDate))),
                            DataCell(Text(AdminFormatters.dateTime(r.cancelledDate))),
                            DataCell(Text('${r.paymentFailureCount}')),
                            DataCell(Text(r.country)),
                            DataCell(
                              Icon(r.manualCompAccess ? Icons.check_circle : Icons.do_not_disturb_on_outlined, color: r.manualCompAccess ? cs.primary : cs.onSurfaceVariant, size: 18),
                            ),
                            DataCell(_BillingActionsMenu(userId: r.userId, role: role, hasManualComp: r.manualCompAccess, currentPlan: r.plan)),
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

class _TrialsTab extends StatelessWidget {
  const _TrialsTab({required this.rows, required this.isLoading, required this.role});
  final List<TrialRow> rows;
  final bool isLoading;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    if (isLoading && rows.isEmpty) return const _LoadingState();
    final cs = Theme.of(context).colorScheme;
    final canExtend = AdminRbac.canPerformBillingAction(role, BillingAdminAction.extendTrial);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(child: Text('Trials', style: Theme.of(context).textTheme.titleMedium)),
              if (!canExtend)
                Text('Read-only', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState(label: 'No trials found for the current filters.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingTextStyle: Theme.of(context).textTheme.labelLarge,
                    dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                    columns: [
                      const DataColumn(label: Text('User ID')),
                      const DataColumn(label: Text('Plan')),
                      const DataColumn(label: Text('Trial start')),
                      const DataColumn(label: Text('Trial end')),
                      const DataColumn(label: Text('Days remaining')),
                      const DataColumn(label: Text('Usage level')),
                      const DataColumn(label: Text('Upgrade clicked')),
                      const DataColumn(label: Text('Converted')),
                      const DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          cells: [
                            DataCell(Text(r.userId)),
                            DataCell(Text(r.plan)),
                            DataCell(Text(AdminFormatters.dateTime(r.trialStart))),
                            DataCell(Text(AdminFormatters.dateTime(r.trialEnd))),
                            DataCell(Text('${r.daysRemaining}')),
                            DataCell(Text(r.usageLevel)),
                            DataCell(Icon(r.upgradePromptClicked ? Icons.check_circle : Icons.close, size: 18, color: r.upgradePromptClicked ? cs.primary : cs.onSurfaceVariant)),
                            DataCell(Icon(r.converted ? Icons.check_circle : Icons.close, size: 18, color: r.converted ? cs.primary : cs.onSurfaceVariant)),
                            DataCell(_ExtendTrialButton(enabled: canExtend, userId: r.userId, currentEnd: r.trialEnd)),
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

class _FailedPaymentsTab extends StatelessWidget {
  const _FailedPaymentsTab({required this.rows, required this.isLoading, required this.role});
  final List<FailedPaymentRow> rows;
  final bool isLoading;
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    if (isLoading && rows.isEmpty) return const _LoadingState();
    final cs = Theme.of(context).colorScheme;
    final canSeeEmail = AdminRbac.canViewBillingEmail(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text('Failed payments', style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState(label: 'No failed payments found for the current filters.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingTextStyle: Theme.of(context).textTheme.labelLarge,
                    dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                    columns: [
                      const DataColumn(label: Text('User ID')),
                      if (canSeeEmail) const DataColumn(label: Text('Email')),
                      const DataColumn(label: Text('Plan')),
                      const DataColumn(label: Text('Provider')),
                      const DataColumn(label: Text('Failure date')),
                      const DataColumn(label: Text('Failure count')),
                      const DataColumn(label: Text('Billing status')),
                      const DataColumn(label: Text('Restriction status')),
                      const DataColumn(label: Text('Actions')),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          cells: [
                            DataCell(Text(r.userId)),
                            if (canSeeEmail) DataCell(Text(r.email ?? '—')),
                            DataCell(Text(r.plan)),
                            DataCell(Text(r.provider.label)),
                            DataCell(Text(AdminFormatters.dateTime(r.failureDate))),
                            DataCell(Text('${r.failureCount}')),
                            DataCell(_StatusPill(text: r.billingStatus)),
                            DataCell(_StatusPill(text: r.accountRestrictionStatus)),
                            DataCell(_BillingActionsMenu(userId: r.userId, role: role, hasManualComp: false, currentPlan: r.plan)),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Text(
            'Note: This table is metadata-only. No payment method details are displayed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _RevenueByPlanTab extends StatelessWidget {
  const _RevenueByPlanTab({required this.rows, required this.isLoading});
  final List<RevenueByPlanRow> rows;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && rows.isEmpty) return const _LoadingState();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text('Revenue by plan', style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState(label: 'No revenue rows found.')
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
                      DataColumn(label: Text('MRR')),
                      DataColumn(label: Text('ARR')),
                      DataColumn(label: Text('Churn')),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          cells: [
                            DataCell(Text(r.plan)),
                            DataCell(Text(AdminFormatters.compactInt(r.users))),
                            DataCell(Text(AdminFormatters.usd(r.mrrUsd))),
                            DataCell(Text(AdminFormatters.usd(r.arrUsd))),
                            DataCell(Text(_formatPct(r.churnRate))),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Text(
            'Revenue figures are aggregated and intended for internal monitoring, not financial reporting.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _RevenueByCountryTab extends StatelessWidget {
  const _RevenueByCountryTab({required this.rows, required this.isLoading});
  final List<RevenueByCountryRow> rows;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && rows.isEmpty) return const _LoadingState();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text('Revenue by country', style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState(label: 'No revenue rows found.')
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
                      DataColumn(label: Text('MRR')),
                      DataColumn(label: Text('ARR')),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          cells: [
                            DataCell(Text(r.country)),
                            DataCell(Text(AdminFormatters.compactInt(r.users))),
                            DataCell(Text(AdminFormatters.usd(r.mrrUsd))),
                            DataCell(Text(AdminFormatters.usd(r.arrUsd))),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Text(
            'Privacy rule: Countries with fewer than 10 users are grouped into “Other”.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _BillingActionsMenu extends StatelessWidget {
  const _BillingActionsMenu({required this.userId, required this.role, required this.hasManualComp, required this.currentPlan});
  final String userId;
  final AdminRole role;
  final bool hasManualComp;
  final String currentPlan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canChangePlan = AdminRbac.canPerformBillingAction(role, BillingAdminAction.changePlan);
    final canComp = AdminRbac.canPerformBillingAction(role, BillingAdminAction.grantManualCompAccess);
    final canNote = AdminRbac.canPerformBillingAction(role, BillingAdminAction.addBillingNote);

    final enabled = canChangePlan || canComp || canNote;

    return PopupMenuButton<_BillingAction>(
      enabled: enabled,
      icon: Icon(Icons.more_horiz, color: enabled ? cs.onSurface : cs.onSurfaceVariant),
      onSelected: (a) async {
        switch (a) {
          case _BillingAction.changePlan:
            await _handleChangePlan(context);
            return;
          case _BillingAction.grantManualComp:
            await _handleManualComp(context, grant: true);
            return;
          case _BillingAction.revokeManualComp:
            await _handleManualComp(context, grant: false);
            return;
          case _BillingAction.addBillingNote:
            await _handleAddNote(context);
            return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: _BillingAction.changePlan, enabled: canChangePlan, child: const Text('Change plan')),
        PopupMenuItem(value: _BillingAction.grantManualComp, enabled: canComp && !hasManualComp, child: const Text('Mark manual comp access')),
        PopupMenuItem(value: _BillingAction.revokeManualComp, enabled: canComp && hasManualComp, child: const Text('Remove manual comp access')),
        PopupMenuItem(value: _BillingAction.addBillingNote, enabled: canNote, child: const Text('Add billing note')),
      ],
    );
  }

  Future<void> _handleChangePlan(BuildContext context) async {
    final store = context.read<AdminStore>();
    final actorId = store.currentAdmin?.id ?? 'unknown_admin';

    final plan = await showDialog<String>(
      context: context,
      builder: (context) => _PlanPickerDialog(currentPlan: currentPlan),
    );
    if (plan == null || plan == currentPlan) return;

    final confirm = await AdminChangeConfirmSheet.show(
      context,
      title: 'Change plan',
      summary: 'Updates billing entitlements only. This action is audited.',
      previousValue: currentPlan,
      newValue: plan,
      confirmLabel: 'Change plan',
    );
    if (confirm == null) return;

    try {
      await store.performUserAdminAction(
        AdminActionRequest(
          actorAdminId: actorId,
          actorRole: role,
          userId: userId,
          action: 'Billing: Change plan',
          reason: confirm.reason,
          ticketReference: confirm.ticketReference,
          parameters: {'previous_plan': currentPlan, 'new_plan': plan},
        ),
      );
      await store.refreshBilling();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan change recorded (audited).')));
    } catch (e) {
      debugPrint('Billing change plan failed: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to change plan.')));
    }
  }

  Future<void> _handleManualComp(BuildContext context, {required bool grant}) async {
    final store = context.read<AdminStore>();
    final actorId = store.currentAdmin?.id ?? 'unknown_admin';

    final confirm = await AdminChangeConfirmSheet.show(
      context,
      title: grant ? 'Grant manual comp access' : 'Revoke manual comp access',
      summary: 'Manual comp access is a billing override. This action is audited.',
      previousValue: hasManualComp ? 'enabled' : 'disabled',
      newValue: grant ? 'enabled' : 'disabled',
      confirmLabel: grant ? 'Grant' : 'Revoke',
    );
    if (confirm == null) return;

    try {
      await store.performUserAdminAction(
        AdminActionRequest(
          actorAdminId: actorId,
          actorRole: role,
          userId: userId,
          action: grant ? 'Billing: Manual comp grant' : 'Billing: Manual comp revoke',
          reason: confirm.reason,
          ticketReference: confirm.ticketReference,
          parameters: {'manual_comp': grant, 'previous': hasManualComp},
        ),
      );
      await store.refreshBilling();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual comp access updated (audited).')));
    } catch (e) {
      debugPrint('Billing manual comp failed: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update manual comp access.')));
    }
  }

  Future<void> _handleAddNote(BuildContext context) async {
    final store = context.read<AdminStore>();
    final actorId = store.currentAdmin?.id ?? 'unknown_admin';

    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: const _BillingNoteSheet(),
      ),
    );
    if (note == null || note.trim().isEmpty) return;

    final confirm = await AdminChangeConfirmSheet.show(
      context,
      title: 'Add billing note',
      summary: 'Notes should never contain health data. This action is audited.',
      previousValue: '—',
      newValue: note.trim(),
      confirmLabel: 'Add note',
    );
    if (confirm == null) return;

    try {
      await store.performUserAdminAction(
        AdminActionRequest(
          actorAdminId: actorId,
          actorRole: role,
          userId: userId,
          action: 'Billing: Add note',
          reason: confirm.reason,
          ticketReference: confirm.ticketReference,
          parameters: {'note': note.trim()},
        ),
      );
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Billing note recorded (audited).')));
    } catch (e) {
      debugPrint('Billing add note failed: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add billing note.')));
    }
  }
}

enum _BillingAction { changePlan, grantManualComp, revokeManualComp, addBillingNote }

class _ExtendTrialButton extends StatelessWidget {
  const _ExtendTrialButton({required this.enabled, required this.userId, required this.currentEnd});
  final bool enabled;
  final String userId;
  final DateTime currentEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: enabled
          ? () async {
              final extraDays = await showDialog<int>(
                context: context,
                builder: (context) => const _ExtendTrialDialog(),
              );
              if (extraDays == null) return;

              final newEnd = currentEnd.add(Duration(days: extraDays));
              final store = context.read<AdminStore>();
              final role = context.read<AdminAuthStore>().role ?? AdminRole.readOnly;
              final actorId = store.currentAdmin?.id ?? 'unknown_admin';

              final confirm = await AdminChangeConfirmSheet.show(
                context,
                title: 'Extend trial',
                summary: 'Extends trial end date. This action is audited.',
                previousValue: AdminFormatters.dateTime(currentEnd),
                newValue: AdminFormatters.dateTime(newEnd),
                confirmLabel: 'Extend',
              );
              if (confirm == null) return;

              try {
                await store.performUserAdminAction(
                  AdminActionRequest(
                    actorAdminId: actorId,
                    actorRole: role,
                    userId: userId,
                    action: 'Billing: Extend trial',
                    reason: confirm.reason,
                    ticketReference: confirm.ticketReference,
                    parameters: {
                      'previous_trial_end': currentEnd.toIso8601String(),
                      'new_trial_end': newEnd.toIso8601String(),
                      'days_added': extraDays,
                    },
                  ),
                );
                await store.refreshBilling();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trial extended (audited).')));
              } catch (e) {
                debugPrint('Extend trial failed: $e');
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to extend trial.')));
              }
            }
          : null,
      icon: Icon(Icons.add, size: 16, color: enabled ? cs.primary : cs.onSurfaceVariant),
      label: Text('Extend', style: TextStyle(color: enabled ? cs.primary : cs.onSurfaceVariant)),
    );
  }
}

class _ExtendTrialDialog extends StatelessWidget {
  const _ExtendTrialDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Extend trial'),
      content: const Text('Choose how many days to extend the trial by.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(7), child: const Text('+7 days')),
        TextButton(onPressed: () => Navigator.of(context).pop(14), child: const Text('+14 days')),
      ],
    );
  }
}

class _PlanPickerDialog extends StatelessWidget {
  const _PlanPickerDialog({required this.currentPlan});
  final String currentPlan;

  @override
  Widget build(BuildContext context) {
    const plans = ['free', 'premium', 'family', 'team', 'enterprise'];
    return AlertDialog(
      title: const Text('Change plan'),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in plans)
              RadioListTile<String>(
                value: p,
                groupValue: currentPlan,
                onChanged: (v) => Navigator.of(context).pop(v),
                title: Text(p),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
}

class _BillingNoteSheet extends StatefulWidget {
  const _BillingNoteSheet();

  @override
  State<_BillingNoteSheet> createState() => _BillingNoteSheetState();
}

class _BillingNoteSheetState extends State<_BillingNoteSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Note cannot be empty.');
      return;
    }
    if (text.length > 400) {
      setState(() => _error = 'Please keep notes under 400 characters.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Billing note', style: t.titleLarge),
            const SizedBox(height: 8),
            Text('Do not include health data or sensitive personal information.', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(labelText: 'Note', hintText: 'e.g. Customer requested invoice resend…', errorText: _error),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final isNarrow = w < 980;
    final double cardWidth = isNarrow ? (w - 48) / 2 : 260.0;

    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
              ),
              child: Icon(icon, color: cs.onPrimaryContainer, size: 18),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = text.trim().toLowerCase();
    final tone = switch (v) {
      'active' || 'normal' => cs.primaryContainer.withValues(alpha: 0.75),
      'past_due' || 'retrying' || 'restricted' => cs.tertiaryContainer.withValues(alpha: 0.75),
      'cancelled' => cs.surfaceContainerHighest,
      _ => cs.surfaceContainerHighest,
    };
    final fg = switch (v) {
      'active' || 'normal' => cs.onPrimaryContainer,
      'past_due' || 'retrying' || 'restricted' => cs.onTertiaryContainer,
      'cancelled' => cs.onSurfaceVariant,
      _ => cs.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator()));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ),
    );
  }
}

String _formatPct(double v) {
  final clamped = v.clamp(0.0, 1.0);
  return '${(clamped * 100).toStringAsFixed(1)}%';
}

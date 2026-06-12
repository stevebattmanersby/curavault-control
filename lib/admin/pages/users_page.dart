import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: context.read<AdminStore>().userQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = context.select<AdminStore, List<UserAccountSummary>>((s) => s.users);
    final filters = context.select<AdminStore, UserListFilters>((s) => s.userFilters);
    final cs = Theme.of(context).colorScheme;

    return AdminPageScaffold(
      title: 'Users',
      subtitle: 'Account health and usage signals. Medical content is never shown here.',
      actions: [
        _UsersFilterButton(filters: filters),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 360,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => context.read<AdminStore>().setUserQuery(v),
            decoration: InputDecoration(
              hintText: 'Search by user ID${_emailSearchHint(context)}',
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            ),
          ),
        ),
      ],
      child: AdminCard(
        header: Row(
          children: [
            Text('User summaries', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${users.length} results', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
            dataTextStyle: Theme.of(context).textTheme.labelLarge,
            columns: [
              const DataColumn(label: Text('User ID')),
              if (_canShowEmail(context)) const DataColumn(label: Text('Email')),
              const DataColumn(label: Text('Country')),
              const DataColumn(label: Text('Plan')),
              const DataColumn(label: Text('Account status')),
              const DataColumn(label: Text('Storage used')),
              const DataColumn(label: Text('Storage limit')),
              const DataColumn(label: Text('AI tokens (mo)')),
              const DataColumn(label: Text('AI limit')),
              const DataColumn(label: Text('Profiles')),
              const DataColumn(label: Text('Documents')),
              const DataColumn(label: Text('Records')),
              const DataColumn(label: Text('Last active')),
              const DataColumn(label: Text('Last sync')),
              const DataColumn(label: Text('Platform')),
              const DataColumn(label: Text('App ver')),
              const DataColumn(label: Text('Billing status')),
            ],
            rows: [
              for (final u in users)
                DataRow(
                  onSelectChanged: (_) => context.go('/users/${u.userId}'),
                  cells: [
                    DataCell(SelectableText(u.userId)),
                    if (_canShowEmail(context)) DataCell(Text(u.email ?? '—')),
                    DataCell(Text(u.country)),
                    DataCell(Text(u.plan)),
                    DataCell(_StatusPill(value: u.accountStatus)),
                    DataCell(Text(formatBytes(u.storageUsedBytes))),
                    DataCell(Text(formatBytes(u.storageLimitBytes))),
                    DataCell(_LimitCell(used: u.aiTokensThisMonth, limit: u.aiTokenLimitThisMonth, formatter: formatCompactInt)),
                    DataCell(Text(formatCompactInt(u.aiTokenLimitThisMonth))),
                    DataCell(Text(u.profileCount.toString())),
                    DataCell(Text(u.documentCount.toString())),
                    DataCell(Text(u.recordCount.toString())),
                    DataCell(Text(formatDateTimeShort(u.lastActiveAt))),
                    DataCell(Text(formatDateTimeShort(u.lastSyncAt))),
                    DataCell(Text(u.platform)),
                    DataCell(Text(u.appVersion)),
                    DataCell(Text(u.billingStatus)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _canShowEmail(BuildContext context) {
    final role = context.read<AdminStore>().currentAdmin?.role;
    if (role == null) return false;
    return AdminRbac.canViewUserEmail(role);
  }

  static String _emailSearchHint(BuildContext context) => _canShowEmail(context) ? ' or email' : '';
}

class _UsersFilterButton extends StatelessWidget {
  const _UsersFilterButton({required this.filters});

  final UserListFilters filters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final activeCount = <Object?>[
      filters.country,
      filters.plan,
      filters.accountStatus,
      filters.platform,
      filters.storageNearLimit,
      filters.aiNearLimit,
      filters.failedSyncs,
      filters.failedUploads,
      filters.billingFailed,
      filters.createdRange,
      filters.lastActiveRange,
    ].where((v) => v != null).length;

    return TextButton.icon(
      onPressed: () async {
        final res = await showModalBottomSheet<UserListFilters>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => UsersFilterSheet(initial: filters),
        );
        if (res != null && context.mounted) await context.read<AdminStore>().setUserFilters(res);
      },
      icon: Icon(Icons.tune, color: cs.onSurface),
      label: Text(activeCount == 0 ? 'Filters' : 'Filters ($activeCount)', style: TextStyle(color: cs.onSurface)),
      style: TextButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }
}

class UsersFilterSheet extends StatefulWidget {
  const UsersFilterSheet({super.key, required this.initial});

  final UserListFilters initial;

  @override
  State<UsersFilterSheet> createState() => _UsersFilterSheetState();
}

class _UsersFilterSheetState extends State<UsersFilterSheet> {
  late UserListFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Filters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _filters = const UserListFilters()),
                    style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _SelectChip(
                    label: 'Country',
                    value: _filters.country,
                    options: const ['US', 'CA', 'GB', 'DE', 'AU', 'SG'],
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(country: v, clearCountry: v == null)),
                  ),
                  _SelectChip(
                    label: 'Plan',
                    value: _filters.plan,
                    options: const ['Enterprise', 'Team', 'Pro', 'Free'],
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(plan: v, clearPlan: v == null)),
                  ),
                  _SelectChip(
                    label: 'Account status',
                    value: _filters.accountStatus,
                    options: const ['active', 'locked', 'suspended'],
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(accountStatus: v, clearAccountStatus: v == null)),
                  ),
                  _SelectChip(
                    label: 'Platform',
                    value: _filters.platform,
                    options: const ['iOS', 'Android', 'Web'],
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(platform: v, clearPlatform: v == null)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _FlagChip(
                    label: 'Storage near limit',
                    value: _filters.storageNearLimit == true,
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(storageNearLimit: v, clearStorageNearLimit: !v)),
                  ),
                  _FlagChip(
                    label: 'AI near limit',
                    value: _filters.aiNearLimit == true,
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(aiNearLimit: v, clearAiNearLimit: !v)),
                  ),
                  _FlagChip(
                    label: 'Failed syncs',
                    value: _filters.failedSyncs == true,
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(failedSyncs: v, clearFailedSyncs: !v)),
                  ),
                  _FlagChip(
                    label: 'Failed uploads',
                    value: _filters.failedUploads == true,
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(failedUploads: v, clearFailedUploads: !v)),
                  ),
                  _FlagChip(
                    label: 'Billing failed',
                    value: _filters.billingFailed == true,
                    onChanged: (v) => setState(() => _filters = _filters.copyWith(billingFailed: v, clearBillingFailed: !v)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _DateRangeChip(
                    label: 'Created date',
                    range: _filters.createdRange,
                    onPick: () async {
                      final res = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _filters.createdRange,
                      );
                      if (res != null && mounted) setState(() => _filters = _filters.copyWith(createdRange: res));
                    },
                    onClear: () => setState(() => _filters = _filters.copyWith(clearCreatedRange: true)),
                  ),
                  _DateRangeChip(
                    label: 'Last active date',
                    range: _filters.lastActiveRange,
                    onPick: () async {
                      final res = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _filters.lastActiveRange,
                      );
                      if (res != null && mounted) setState(() => _filters = _filters.copyWith(lastActiveRange: res));
                    },
                    onClear: () => setState(() => _filters = _filters.copyWith(clearLastActiveRange: true)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'These filters operate on metadata and aggregate diagnostics only. No health content is ever accessed.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.pop(_filters),
                    style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                    child: const Text('Apply'),
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

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: AppSpacing.md),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox.shrink(),
            hint: Text('Any', style: TextStyle(color: cs.onSurfaceVariant)),
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o,
                  child: Text(o),
                ),
            ],
            onChanged: onChanged,
          ),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: () => onChanged(null),
              icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
              splashColor: Colors.transparent,
              highlightColor: cs.primary.withValues(alpha: 0.06),
              hoverColor: cs.primary.withValues(alpha: 0.06),
              tooltip: 'Clear',
            ),
          ],
        ],
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      label: Text(label),
      onSelected: onChanged,
      showCheckmark: false,
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({required this.label, required this.range, required this.onPick, required this.onClear});

  final String label;
  final DateTimeRange? range;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = range == null ? 'Any' : '${formatDateShort(range!.start)} – ${formatDateShort(range!.end)}';
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: Icon(Icons.date_range, color: cs.onSurface),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: $text', style: TextStyle(color: cs.onSurface)),
          if (range != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: onClear,
              icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
              splashColor: Colors.transparent,
              highlightColor: cs.primary.withValues(alpha: 0.06),
              hoverColor: cs.primary.withValues(alpha: 0.06),
            ),
          ],
        ],
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      ),
    );
  }
}

class _LimitCell extends StatelessWidget {
  const _LimitCell({required this.used, required this.limit, required this.formatter});

  final int used;
  final int limit;
  final String Function(int) formatter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (limit <= 0) return Text(formatter(used));
    final ratio = used / limit;
    final color = ratio >= 1.0
        ? Colors.red
        : ratio >= 0.85
        ? Colors.orange
        : cs.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatter(used)),
        const SizedBox(width: 6),
        Icon(Icons.circle, size: 8, color: color),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value.toLowerCase();
    final isBad = v.contains('suspend') || v.contains('lock');
    final bg = isBad ? Colors.red.withValues(alpha: 0.12) : cs.primary.withValues(alpha: 0.12);
    final fg = isBad ? Colors.red : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(value, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

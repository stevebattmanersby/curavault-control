import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/admin/data/supabase/supabase_client.dart';
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
  bool _isLoading = false;
  String? _loadError;
  List<_AdminUserUsageSummaryRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: context.read<AdminStore>().userQuery);
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Keep the store in sync (other pages may depend on it), but the table on
    // this page is backed by the admin-safe RPC.
    context.read<AdminStore>().setUserQuery(_searchController.text);
    setState(() {});
  }

  Future<void> _load() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final client = ControlSupabaseClient.tryGet();
      if (client == null) throw StateError('Supabase not initialized.');
      final res = await client.rpc('admin_get_user_usage_summary');
      if (res is! List) throw StateError('Unexpected RPC response.');
      final rows = res.cast<Map>().map((e) => _AdminUserUsageSummaryRow.fromJson(e.cast<String, dynamic>())).toList();
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = context.select<AdminStore, UserListFilters>((s) => s.userFilters);
    final cs = Theme.of(context).colorScheme;

    final canEmail = _canShowEmail(context);
    final q = _searchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _rows
        : _rows.where((r) {
            if (r.userId.toLowerCase().contains(q)) return true;
            if (canEmail && (r.email ?? '').toLowerCase().contains(q)) return true;
            return false;
          }).toList();

    return AdminPageScaffold(
      title: 'Users',
      subtitle: 'Account health and usage signals. Medical content is never shown here.',
      actions: [
        _UsersFilterButton(filters: filters),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: _load,
          icon: Icon(Icons.refresh, color: cs.onSurface),
          tooltip: 'Refresh',
          splashColor: Colors.transparent,
          highlightColor: cs.primary.withValues(alpha: 0.06),
          hoverColor: cs.primary.withValues(alpha: 0.06),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 360,
          child: TextField(
            controller: _searchController,
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
            Text('${filtered.length} results', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        child: _isLoading
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator())))
            : _loadError != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load user usage summary.\n${_loadError!}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  )
                : filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No usage data has been collected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                          dataTextStyle: Theme.of(context).textTheme.labelLarge,
                          columns: [
                            const DataColumn(label: Text('User ID')),
                            if (canEmail) const DataColumn(label: Text('Email')),
                            const DataColumn(label: Text('Created')),
                            const DataColumn(label: Text('Last sign-in')),
                            const DataColumn(label: Text('Profiles'), numeric: true),
                            const DataColumn(label: Text('Family'), numeric: true),
                            const DataColumn(label: Text('Records'), numeric: true),
                            const DataColumn(label: Text('Appts'), numeric: true),
                            const DataColumn(label: Text('Meds'), numeric: true),
                            const DataColumn(label: Text('Vax'), numeric: true),
                            const DataColumn(label: Text('BP'), numeric: true),
                            const DataColumn(label: Text('Docs'), numeric: true),
                            const DataColumn(label: Text('Usage events'), numeric: true),
                            const DataColumn(label: Text('Entitlements'), numeric: true),
                            const DataColumn(label: Text('Sub events'), numeric: true),
                          ],
                          rows: [
                            for (final r in filtered)
                              DataRow(
                                onSelectChanged: (_) => context.go('/users/${r.userId}'),
                                cells: [
                                  DataCell(SelectableText(r.userId)),
                                  if (canEmail) DataCell(Text(r.email ?? '—')),
                                  DataCell(Text(formatDateTimeShort(r.createdAt))),
                                  DataCell(Text(formatDateTimeShort(r.lastSignInAt))),
                                  DataCell(Text(formatCompactInt(r.profileCount))),
                                  DataCell(Text(formatCompactInt(r.familyMemberCount))),
                                  DataCell(Text(formatCompactInt(r.medicalRecordCount))),
                                  DataCell(Text(formatCompactInt(r.appointmentCount))),
                                  DataCell(Text(formatCompactInt(r.medicationCount))),
                                  DataCell(Text(formatCompactInt(r.vaccinationCount))),
                                  DataCell(Text(formatCompactInt(r.bloodPressureEntryCount))),
                                  DataCell(Text(formatCompactInt(r.medicalDocumentCount))),
                                  DataCell(Text(formatCompactInt(r.usageEventCount))),
                                  DataCell(Text(formatCompactInt(r.entitlementCount))),
                                  DataCell(Text(formatCompactInt(r.subscriptionEventCount))),
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

class _AdminUserUsageSummaryRow {
  const _AdminUserUsageSummaryRow({
    required this.userId,
    required this.email,
    required this.createdAt,
    required this.lastSignInAt,
    required this.profileCount,
    required this.familyMemberCount,
    required this.medicalRecordCount,
    required this.appointmentCount,
    required this.medicationCount,
    required this.vaccinationCount,
    required this.bloodPressureEntryCount,
    required this.medicalDocumentCount,
    required this.usageEventCount,
    required this.entitlementCount,
    required this.subscriptionEventCount,
  });

  final String userId;
  final String? email;
  final DateTime createdAt;
  final DateTime? lastSignInAt;
  final int profileCount;
  final int familyMemberCount;
  final int medicalRecordCount;
  final int appointmentCount;
  final int medicationCount;
  final int vaccinationCount;
  final int bloodPressureEntryCount;
  final int medicalDocumentCount;
  final int usageEventCount;
  final int entitlementCount;
  final int subscriptionEventCount;

  static int _i(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  static _AdminUserUsageSummaryRow fromJson(Map<String, dynamic> json) => _AdminUserUsageSummaryRow(
        userId: (json['user_id'] ?? '').toString(),
        email: json['email']?.toString(),
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
        lastSignInAt: DateTime.tryParse((json['last_sign_in_at'] ?? '').toString()),
        profileCount: _i(json['profile_count']),
        familyMemberCount: _i(json['family_member_count']),
        medicalRecordCount: _i(json['medical_record_count']),
        appointmentCount: _i(json['appointment_count']),
        medicationCount: _i(json['medication_count']),
        vaccinationCount: _i(json['vaccination_count']),
        bloodPressureEntryCount: _i(json['blood_pressure_entry_count']),
        medicalDocumentCount: _i(json['medical_document_count']),
        usageEventCount: _i(json['usage_event_count']),
        entitlementCount: _i(json['entitlement_count']),
        subscriptionEventCount: _i(json['subscription_event_count']),
      );
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

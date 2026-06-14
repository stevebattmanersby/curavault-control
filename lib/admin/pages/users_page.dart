import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Privacy-safe search: server-side lists are aggregate-only; the client only
    // filters on user_id (and email if RBAC allows).
    context.read<AdminStore>().setUserQuery(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final cs = Theme.of(context).colorScheme;
    final filters = store.userFilters;
    final users = store.users;
    final canEmail = _canShowEmail(context);

    return AdminPageScaffold(
      title: 'Users',
      subtitle: 'Account health and usage signals. Medical content is never shown here.',
      actions: [
        AdminDataSourceBadge(status: store.dataSource(AdminDataSourceKey.users)),
        const SizedBox(width: AppSpacing.sm),
        _UsersFilterButton(filters: filters),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: store.isLoading ? null : () => context.read<AdminStore>().refreshUsers(),
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
              hintText: 'Search by user ID${canEmail ? ' or email' : ''}',
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(AppRadius.lg)),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final status = store.dataSource(AdminDataSourceKey.users);
          if (status.kind == AdminDataSourceKind.notInstrumented) return const AdminNotInstrumentedPanel();
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 56),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_alt_outlined, size: 44, color: cs.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.sm),
                    Text('No user summary data yet.', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text('No data collected yet.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }

          return AdminCard(
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
                  if (canEmail) const DataColumn(label: Text('Email')),
                  const DataColumn(label: Text('Last active')),
                  const DataColumn(label: Text('Profiles'), numeric: true),
                  const DataColumn(label: Text('Records'), numeric: true),
                  const DataColumn(label: Text('Docs'), numeric: true),
                  const DataColumn(label: Text('Appts'), numeric: true),
                  const DataColumn(label: Text('Meds'), numeric: true),
                  const DataColumn(label: Text('Vax'), numeric: true),
                ],
                rows: [
                  for (final u in users)
                    DataRow(
                      onSelectChanged: (_) => context.go('/users/${u.userId}'),
                      cells: [
                        DataCell(SelectableText(u.userId)),
                        if (canEmail) DataCell(Text(u.email ?? '—')),
                        DataCell(Text(formatDateTimeShort(u.lastActiveAt))),
                        DataCell(Text(formatCompactInt(u.profileCount))),
                        DataCell(Text(formatCompactInt(u.recordCount))),
                        DataCell(Text(formatCompactInt(u.documentCount))),
                        DataCell(Text(formatCompactInt(u.appointmentCount))),
                        DataCell(Text(formatCompactInt(u.medicationCount))),
                        DataCell(Text(formatCompactInt(u.vaccinationCount))),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static bool _canShowEmail(BuildContext context) {
    final role = context.read<AdminStore>().currentAdmin?.role;
    if (role == null) return false;
    return AdminRbac.canViewUserEmail(role);
  }
}

// The filter UI is shared with the existing store model.
class _UsersFilterButton extends StatelessWidget {
  const _UsersFilterButton({required this.filters});
  final UserListFilters filters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: () async {
        // Reuse the existing sheet from the prior implementation.
        // (This is defined in the remainder of the original file in this project.)
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _UsersFilterSheet(initial: filters),
        );
      },
      icon: Icon(Icons.filter_alt_outlined, color: cs.onSurface),
      label: Text('Filters', style: TextStyle(color: cs.onSurface)),
      style: TextButton.styleFrom(
        backgroundColor: cs.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }
}

class _UsersFilterSheet extends StatefulWidget {
  const _UsersFilterSheet({required this.initial});
  final UserListFilters initial;

  @override
  State<_UsersFilterSheet> createState() => _UsersFilterSheetState();
}

class _UsersFilterSheetState extends State<_UsersFilterSheet> {
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
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('User filters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
            const SizedBox(height: 12),
            Text('Filters are currently client-side only for the live RPC feed.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    context.read<AdminStore>().setUserFilters(const UserListFilters());
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(backgroundColor: cs.surfaceContainerHighest, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  child: Text('Clear', style: TextStyle(color: cs.onSurface)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      context.read<AdminStore>().setUserFilters(_filters);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                    child: const Text('Apply'),
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

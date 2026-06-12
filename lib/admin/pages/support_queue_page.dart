import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SupportQueuePage extends StatefulWidget {
  const SupportQueuePage({super.key});

  @override
  State<SupportQueuePage> createState() => _SupportQueuePageState();
}

class _SupportQueuePageState extends State<SupportQueuePage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<AdminStore>().supportQuery);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.select<AdminStore, List<SupportSessionSummary>>((s) => s.supportSessions);
    final filters = context.select<AdminStore, SupportQueueFilters>((s) => s.supportFilters);
    final cs = Theme.of(context).colorScheme;

    return AdminPageScaffold(
      title: 'Support',
      subtitle: 'Privacy-safe troubleshooting. No user health content is accessible here.',
      actions: [
        _SupportFilterButton(filters: filters),
        const SizedBox(width: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => context.go('/support/diagnostics'),
          icon: Icon(Icons.rule, color: cs.onSurface),
          label: Text('Diagnostics', style: TextStyle(color: cs.onSurface)),
          style: TextButton.styleFrom(
            backgroundColor: cs.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 360,
          child: TextField(
            controller: _search,
            onChanged: (v) => context.read<AdminStore>().setSupportQuery(v),
            decoration: InputDecoration(
              hintText: 'Search by session ID, user ID${_emailSearchHint(context)}, ticket ref…',
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            ),
          ),
        ),
      ],
      child: AdminCard(
        header: Row(
          children: [
            Text('Support queue', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${sessions.length} results', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
            dataTextStyle: Theme.of(context).textTheme.labelLarge,
            columns: [
              const DataColumn(label: Text('Support session ID')),
              const DataColumn(label: Text('User ID')),
              if (_canShowEmail(context)) const DataColumn(label: Text('Email')),
              const DataColumn(label: Text('Ticket reference')),
              const DataColumn(label: Text('Consent status')),
              const DataColumn(label: Text('Status')),
              const DataColumn(label: Text('Assigned admin')),
              const DataColumn(label: Text('Created at')),
              const DataColumn(label: Text('Access expires at')),
              const DataColumn(label: Text('Last updated')),
            ],
            rows: [
              for (final s in sessions)
                DataRow(
                  onSelectChanged: (_) => context.go('/support/${s.supportSessionId}'),
                  cells: [
                    DataCell(SelectableText(s.supportSessionId)),
                    DataCell(SelectableText(s.userId)),
                    if (_canShowEmail(context)) DataCell(Text(s.email ?? '—')),
                    DataCell(Text(s.ticketReference ?? '—')),
                    DataCell(_ConsentPill(status: s.consentStatus)),
                    DataCell(_SupportStatusPill(status: s.status)),
                    DataCell(Text(s.assignedAdmin ?? '—')),
                    DataCell(Text(formatDateTimeShort(s.createdAt))),
                    DataCell(Text(formatDateTimeShort(s.accessExpiresAt))),
                    DataCell(Text(formatDateTimeShort(s.updatedAt))),
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

  static String _emailSearchHint(BuildContext context) => _canShowEmail(context) ? ', email' : '';
}

class _SupportFilterButton extends StatelessWidget {
  const _SupportFilterButton({required this.filters});

  final SupportQueueFilters filters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeCount = <Object?>[
      filters.status,
      filters.consentStatus,
      filters.assignedAdminId,
      filters.onlyExpiringSoon,
    ].where((v) => v != null).length;

    return TextButton.icon(
      onPressed: () async {
        final res = await showModalBottomSheet<SupportQueueFilters>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SupportQueueFilterSheet(initial: filters),
        );
        if (res != null && context.mounted) await context.read<AdminStore>().setSupportFilters(res);
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

class SupportQueueFilterSheet extends StatefulWidget {
  const SupportQueueFilterSheet({super.key, required this.initial});

  final SupportQueueFilters initial;

  @override
  State<SupportQueueFilterSheet> createState() => _SupportQueueFilterSheetState();
}

class _SupportQueueFilterSheetState extends State<SupportQueueFilterSheet> {
  late SupportQueueFilters _filters;

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
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Support queue filters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    splashColor: Colors.transparent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ChoiceChip<SupportSessionStatus?>(
                    label: 'Any status',
                    selected: _filters.status == null,
                    onSelected: () => setState(() => _filters = _filters.copyWith(clearStatus: true)),
                  ),
                  for (final st in SupportSessionStatus.values)
                    _ChoiceChip<SupportSessionStatus>(
                      label: st.label,
                      selected: _filters.status == st,
                      onSelected: () => setState(() => _filters = _filters.copyWith(status: st)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ChoiceChip<String?>(
                    label: 'Any consent',
                    selected: _filters.consentStatus == null,
                    onSelected: () => setState(() => _filters = _filters.copyWith(clearConsentStatus: true)),
                  ),
                  for (final c in const ['on_file', 'missing', 'revoked'])
                    _ChoiceChip<String>(
                      label: c,
                      selected: _filters.consentStatus == c,
                      onSelected: () => setState(() => _filters = _filters.copyWith(consentStatus: c)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile.adaptive(
                value: _filters.onlyExpiringSoon ?? false,
                onChanged: (v) => setState(() => _filters = _filters.copyWith(onlyExpiringSoon: v == true ? true : null)),
                title: Text('Expiring in next 15 minutes', style: Theme.of(context).textTheme.labelLarge),
                subtitle: Text('Helps prioritize active access windows.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _filters = const SupportQueueFilters()),
                      child: Text('Clear', style: TextStyle(color: cs.onSurface)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => context.pop(_filters),
                      child: Text('Apply filters', style: TextStyle(color: cs.onPrimary)),
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

class _ChoiceChip<T> extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.selected, required this.onSelected});
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(999),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? cs.primaryContainer : cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _SupportStatusPill extends StatelessWidget {
  const _SupportStatusPill({required this.status});
  final SupportSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      SupportSessionStatus.pending => (cs.secondaryContainer, cs.onSecondaryContainer),
      SupportSessionStatus.active => (cs.primaryContainer, cs.onPrimaryContainer),
      SupportSessionStatus.expired => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      SupportSessionStatus.closed => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      SupportSessionStatus.revoked => (cs.errorContainer, cs.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _ConsentPill extends StatelessWidget {
  const _ConsentPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final norm = status.trim().toLowerCase();
    final (bg, fg) = switch (norm) {
      'on_file' => (cs.primaryContainer, cs.onPrimaryContainer),
      'missing' => (cs.errorContainer, cs.onErrorContainer),
      'revoked' => (cs.errorContainer, cs.onErrorContainer),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(norm, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

void debugSupport(String message) {
  if (kDebugMode) debugPrint(message);
}

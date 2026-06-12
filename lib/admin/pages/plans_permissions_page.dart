import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/pages/widgets/admin_change_confirm_sheet.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PlansPermissionsPage extends StatefulWidget {
  const PlansPermissionsPage({super.key});

  @override
  State<PlansPermissionsPage> createState() => _PlansPermissionsPageState();
}

class _PlansPermissionsPageState extends State<PlansPermissionsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = context.watch<AdminAuthStore>().role ?? AdminRole.executiveReadonly;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plans & Permissions', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Manage plan entitlements, feature access, and limit overrides. This console never shows health content.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _PolicyBanner(role: role),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            dividerColor: cs.outlineVariant.withValues(alpha: 0.35),
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Plans overview'),
              Tab(text: 'User plan editor'),
              Tab(text: 'Feature flags'),
              Tab(text: 'Limit overrides'),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _PlansOverviewTab(),
                _UserPlanEditorTab(),
                _FeatureFlagsTab(),
                _LimitOverridesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyBanner extends StatelessWidget {
  const _PolicyBanner({required this.role});
  final AdminRole role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final canChangePlans = AdminRbac.canPerformUserAction(role, AdminUserAction.changePlan);
    final canSuspend = AdminRbac.canPerformUserAction(role, AdminUserAction.suspendAccount);
    final canAdjustLimits = AdminRbac.canPerformUserAction(role, AdminUserAction.adjustStorageLimit) || AdminRbac.canPerformUserAction(role, AdminUserAction.adjustAiLimit);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Permissions in effect', style: t.titleMedium),
                const SizedBox(height: 6),
                Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    _Badge(label: canChangePlans ? 'Can change plans' : 'Plan changes: request-only', tone: canChangePlans ? _BadgeTone.ok : _BadgeTone.warn),
                    _Badge(label: canAdjustLimits ? 'Can adjust limits' : 'Limit edits: request-only', tone: canAdjustLimits ? _BadgeTone.ok : _BadgeTone.warn),
                    _Badge(label: canSuspend ? 'Can suspend accounts' : 'Suspend: super admin only', tone: canSuspend ? _BadgeTone.ok : _BadgeTone.neutral),
                    const _Badge(label: 'Health content: never shown', tone: _BadgeTone.neutral),
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

enum _BadgeTone { ok, warn, neutral }

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});
  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = switch (tone) {
      _BadgeTone.ok => cs.primaryContainer.withValues(alpha: 0.8),
      _BadgeTone.warn => cs.tertiaryContainer.withValues(alpha: 0.8),
      _BadgeTone.neutral => cs.surface,
    };
    final fg = switch (tone) {
      _BadgeTone.ok => cs.onPrimaryContainer,
      _BadgeTone.warn => cs.onTertiaryContainer,
      _BadgeTone.neutral => cs.onSurface,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

class _PlansOverviewTab extends StatelessWidget {
  const _PlansOverviewTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final cs = Theme.of(context).colorScheme;
    final rows = store.plansOverview;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('Plans overview', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => context.read<AdminStore>().refreshPlansOverview(),
                  icon: Icon(Icons.refresh, color: cs.onSurface),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyState(label: 'No plan rows loaded yet.')
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingTextStyle: Theme.of(context).textTheme.labelLarge,
                      dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                      columns: const [
                        DataColumn(label: Text('Plan name')),
                        DataColumn(label: Text('Monthly price')),
                        DataColumn(label: Text('Storage limit')),
                        DataColumn(label: Text('AI token limit')),
                        DataColumn(label: Text('Profile limit')),
                        DataColumn(label: Text('Upload limit')),
                        DataColumn(label: Text('Export')),
                        DataColumn(label: Text('AI access')),
                        DataColumn(label: Text('Active')),
                        DataColumn(label: Text('Trial')),
                        DataColumn(label: Text('Paid')),
                        DataColumn(label: Text('Cancelled')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r.planName)),
                              DataCell(Text(r.monthlyPriceUsd == 0 ? '—' : AdminFormatters.usd(r.monthlyPriceUsd))),
                              DataCell(Text(AdminFormatters.bytes(r.storageLimitBytes))),
                              DataCell(Text(AdminFormatters.compactInt(r.aiTokenLimitMonthly))),
                              DataCell(Text('${r.profileLimit}')),
                              DataCell(Text(r.uploadLimit == null ? '—' : '${r.uploadLimit}')),
                              DataCell(Icon(r.exportAccess ? Icons.check_circle : Icons.block, color: r.exportAccess ? cs.primary : cs.onSurfaceVariant)),
                              DataCell(Icon(r.aiAccess ? Icons.check_circle : Icons.block, color: r.aiAccess ? cs.primary : cs.onSurfaceVariant)),
                              DataCell(Text(AdminFormatters.compactInt(r.activeUsers))),
                              DataCell(Text(AdminFormatters.compactInt(r.trialUsers))),
                              DataCell(Text(AdminFormatters.compactInt(r.paidUsers))),
                              DataCell(Text(AdminFormatters.compactInt(r.cancelledUsers))),
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

class _UserPlanEditorTab extends StatefulWidget {
  const _UserPlanEditorTab();

  @override
  State<_UserPlanEditorTab> createState() => _UserPlanEditorTabState();
}

class _UserPlanEditorTabState extends State<_UserPlanEditorTab> {
  final _controller = TextEditingController();
  UserEntitlements? _entitlements;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = _controller.text.trim();
    if (userId.isEmpty) {
      setState(() => _error = 'Enter a user ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ent = await context.read<AdminStore>().getUserEntitlements(userId);
      if (!mounted) return;
      setState(() => _entitlements = ent);
      if (ent == null) setState(() => _error = 'User entitlements not found.');
    } catch (e) {
      debugPrint('UserPlanEditorTab._load failed: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to load entitlements.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = context.watch<AdminAuthStore>().role ?? AdminRole.executiveReadonly;
    final store = context.watch<AdminStore>();
    final actorId = store.currentAdmin?.id ?? 'unknown_admin';

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lookup user', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'User ID',
                        hintText: 'e.g. usr_100012',
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: Icon(Icons.search, color: cs.onPrimary),
                    label: Text(_loading ? 'Loading…' : 'Load', style: TextStyle(color: cs.onPrimary)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_entitlements != null)
          _UserPlanEditorPanel(
            entitlements: _entitlements!,
            actorAdminId: actorId,
            role: role,
            onEntitlementsChanged: (next) => setState(() => _entitlements = next),
          ),
      ],
    );
  }
}

class _UserPlanEditorPanel extends StatelessWidget {
  const _UserPlanEditorPanel({
    required this.entitlements,
    required this.actorAdminId,
    required this.role,
    required this.onEntitlementsChanged,
  });

  final UserEntitlements entitlements;
  final String actorAdminId;
  final AdminRole role;
  final ValueChanged<UserEntitlements> onEntitlementsChanged;

  Future<void> _applyAction(
    BuildContext context, {
    required AdminUserAction action,
    required String title,
    required String summary,
    required String previousValue,
    required String newValue,
    required String actionLabel,
    required Map<String, dynamic> parameters,
    UserEntitlements Function(UserEntitlements current)? optimisticUpdate,
  }) async {
    final allowed = AdminRbac.canPerformUserAction(role, action);
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to apply this change.')));
      return;
    }

    final confirm = await AdminChangeConfirmSheet.show(
      context,
      title: title,
      summary: summary,
      previousValue: previousValue,
      newValue: newValue,
      confirmLabel: 'Apply',
    );
    if (confirm == null) return;

    if (optimisticUpdate != null) {
      onEntitlementsChanged(optimisticUpdate(entitlements));
    }

    try {
      await context.read<AdminStore>().performUserAdminAction(
            AdminActionRequest(
              actorAdminId: actorAdminId,
              actorRole: role,
              userId: entitlements.userId,
              action: actionLabel,
              reason: confirm.reason,
              ticketReference: confirm.ticketReference,
              parameters: {
                'previous': previousValue,
                'new': newValue,
                ...parameters,
              },
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Change applied (audited).')));
    } catch (e) {
      debugPrint('UserPlanEditorPanel action failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to apply change.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final canChangePlan = AdminRbac.canPerformUserAction(role, AdminUserAction.changePlan);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('User plan editor', style: t.titleMedium)),
              _RoleHint(role: role),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(label: 'User', value: entitlements.userId),
              _InfoChip(label: 'Current plan', value: entitlements.currentPlan),
              _InfoChip(label: 'Billing status', value: entitlements.billingStatus),
              _InfoChip(label: 'Provider', value: entitlements.subscriptionProvider),
              _InfoChip(label: 'Trial start', value: entitlements.trialStart == null ? '—' : AdminFormatters.date(entitlements.trialStart!)),
              _InfoChip(label: 'Trial end', value: entitlements.trialEnd == null ? '—' : AdminFormatters.date(entitlements.trialEnd!)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Limits', style: t.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _LimitCard(label: 'Storage limit', value: AdminFormatters.bytes(entitlements.storageLimitBytes), icon: Icons.cloud_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _LimitCard(label: 'AI token limit', value: AdminFormatters.compactInt(entitlements.aiTokenLimitMonthly), icon: Icons.auto_awesome_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _LimitCard(label: 'Profile limit', value: '${entitlements.profileLimit}', icon: Icons.groups_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _LimitCard(label: 'Upload limit', value: entitlements.uploadLimit?.toString() ?? '—', icon: Icons.upload_file_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Actions', style: t.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                label: 'Change plan',
                icon: Icons.swap_horiz,
                enabled: canChangePlan,
                onPressed: () async {
                  final next = await _PlanPickerSheet.show(context, current: entitlements.currentPlan);
                  if (next == null || next == entitlements.currentPlan) return;
                  await _applyAction(
                    context,
                    action: AdminUserAction.changePlan,
                    title: 'Change plan',
                    summary: 'Updates plan entitlements & default limits. No health content is accessed.',
                    previousValue: entitlements.currentPlan,
                    newValue: next,
                    actionLabel: 'Plans: Change plan',
                    parameters: {'plan': next},
                    optimisticUpdate: (cur) => cur.copyWith(currentPlan: next, updatedAt: DateTime.now()),
                  );
                },
              ),
              _ActionButton(
                label: 'Extend trial',
                icon: Icons.timelapse,
                enabled: AdminRbac.canPerformUserAction(role, AdminUserAction.extendTrial),
                onPressed: () async {
                  final days = await _ExtendTrialSheet.show(context);
                  if (days == null) return;
                  final prev = entitlements.trialEnd == null ? '—' : AdminFormatters.date(entitlements.trialEnd!);
                  final nextEnd = (entitlements.trialEnd ?? DateTime.now()).add(Duration(days: days));
                  await _applyAction(
                    context,
                    action: AdminUserAction.extendTrial,
                    title: 'Extend trial',
                    summary: 'Extends the trial window (billing-safe).',
                    previousValue: prev,
                    newValue: AdminFormatters.date(nextEnd),
                    actionLabel: 'Plans: Extend trial',
                    parameters: {'extend_days': days},
                    optimisticUpdate: (cur) => cur.copyWith(trialStart: cur.trialStart ?? DateTime.now(), trialEnd: nextEnd, updatedAt: DateTime.now()),
                  );
                },
              ),
              _ActionButton(
                label: 'Adjust storage limit',
                icon: Icons.cloud_upload_outlined,
                enabled: AdminRbac.canPerformUserAction(role, AdminUserAction.adjustStorageLimit),
                onPressed: () async {
                  final nextBytes = await _LimitInputSheet.showBytes(context, title: 'Adjust storage limit', initialBytes: entitlements.storageLimitBytes);
                  if (nextBytes == null || nextBytes == entitlements.storageLimitBytes) return;
                  await _applyAction(
                    context,
                    action: AdminUserAction.adjustStorageLimit,
                    title: 'Adjust storage limit',
                    summary: 'Applies a per-user override. Consider adding an expiry.',
                    previousValue: AdminFormatters.bytes(entitlements.storageLimitBytes),
                    newValue: AdminFormatters.bytes(nextBytes),
                    actionLabel: 'Plans: Override storage limit',
                    parameters: {'storage_limit_bytes': nextBytes},
                    optimisticUpdate: (cur) => cur.copyWith(storageLimitBytes: nextBytes, updatedAt: DateTime.now()),
                  );
                },
              ),
              _ActionButton(
                label: 'Adjust AI token limit',
                icon: Icons.auto_awesome,
                enabled: AdminRbac.canPerformUserAction(role, AdminUserAction.adjustAiLimit),
                onPressed: () async {
                  final nextTokens = await _LimitInputSheet.showInt(context, title: 'Adjust AI token limit (monthly)', initial: entitlements.aiTokenLimitMonthly);
                  if (nextTokens == null || nextTokens == entitlements.aiTokenLimitMonthly) return;
                  await _applyAction(
                    context,
                    action: AdminUserAction.adjustAiLimit,
                    title: 'Adjust AI token limit',
                    summary: 'Applies a per-user override. Ensure this aligns with billing policy.',
                    previousValue: AdminFormatters.compactInt(entitlements.aiTokenLimitMonthly),
                    newValue: AdminFormatters.compactInt(nextTokens),
                    actionLabel: 'Plans: Override AI limit',
                    parameters: {'ai_token_limit_monthly': nextTokens},
                    optimisticUpdate: (cur) => cur.copyWith(aiTokenLimitMonthly: nextTokens, updatedAt: DateTime.now()),
                  );
                },
              ),
              _ActionButton(
                label: 'Enable beta feature',
                icon: Icons.flare_outlined,
                enabled: AdminRbac.canPerformUserAction(role, AdminUserAction.adjustAiLimit),
                onPressed: () async {
                  final prev = entitlements.featureFlags[FeatureFlagKey.betaFeatures] == true;
                  if (prev) return;
                  await _applyAction(
                    context,
                    action: AdminUserAction.adjustAiLimit,
                    title: 'Enable beta features (per user)',
                    summary: 'Turns on beta feature surfaces for this user only.',
                    previousValue: 'off',
                    newValue: 'on',
                    actionLabel: 'Plans: Set user feature flag',
                    parameters: {'flag': FeatureFlagKey.betaFeatures.apiKey, 'enabled': true},
                    optimisticUpdate: (cur) => cur.copyWith(featureFlags: {...cur.featureFlags, FeatureFlagKey.betaFeatures: true}, updatedAt: DateTime.now()),
                  );
                },
              ),
              _ActionButton(
                label: 'Disable AI access',
                icon: Icons.block,
                enabled: AdminRbac.canPerformUserAction(role, AdminUserAction.adjustAiLimit),
                onPressed: () async {
                  final prev = entitlements.featureFlags[FeatureFlagKey.aiAssistant] == true;
                  if (!prev) return;
                  await _applyAction(
                    context,
                    action: AdminUserAction.adjustAiLimit,
                    title: 'Disable AI access (per user)',
                    summary: 'Turns off AI assistant access for this user.',
                    previousValue: 'on',
                    newValue: 'off',
                    actionLabel: 'Plans: Set user feature flag',
                    parameters: {'flag': FeatureFlagKey.aiAssistant.apiKey, 'enabled': false},
                    optimisticUpdate: (cur) => cur.copyWith(featureFlags: {...cur.featureFlags, FeatureFlagKey.aiAssistant: false}, updatedAt: DateTime.now()),
                  );
                },
              ),
              _ActionButton(
                label: 'Disable uploads',
                icon: Icons.upload_file,
                enabled: AdminRbac.canPerformUserAction(role, AdminUserAction.adjustStorageLimit),
                onPressed: () async {
                  final prev = entitlements.featureFlags[FeatureFlagKey.documentUploads] == true;
                  if (!prev) return;
                  await _applyAction(
                    context,
                    action: AdminUserAction.adjustStorageLimit,
                    title: 'Disable document uploads (per user)',
                    summary: 'Turns off uploads for this user without touching content.',
                    previousValue: 'on',
                    newValue: 'off',
                    actionLabel: 'Plans: Set user feature flag',
                    parameters: {'flag': FeatureFlagKey.documentUploads.apiKey, 'enabled': false},
                    optimisticUpdate: (cur) => cur.copyWith(featureFlags: {...cur.featureFlags, FeatureFlagKey.documentUploads: false}, updatedAt: DateTime.now()),
                  );
                },
              ),
              _ActionButton(
                label: 'Restore default limits',
                icon: Icons.restore,
                enabled: AdminRbac.canPerformUserAction(role, AdminUserAction.adjustStorageLimit),
                onPressed: () async {
                  await _applyAction(
                    context,
                    action: AdminUserAction.adjustStorageLimit,
                    title: 'Restore default limits',
                    summary: 'Clears per-user overrides and resets to plan defaults.',
                    previousValue: 'Overrides present (if any)',
                    newValue: 'Plan defaults',
                    actionLabel: 'Plans: Restore defaults',
                    parameters: const {'restore_defaults': true},
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Feature flags (effective)', style: t.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in entitlements.featureFlags.entries)
                _FlagPill(label: entry.key.label, enabled: entry.value),
            ],
          ),
          if (!canChangePlan)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                'Note: You can view entitlements, but billing-impacting actions are request-only for your role.',
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleHint extends StatelessWidget {
  const _RoleHint({required this.role});
  final AdminRole role;

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
          Icon(Icons.badge_outlined, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(role.name, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: t.labelLarge),
        ],
      ),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 3),
                Text(value, style: t.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.enabled, required this.onPressed});
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, color: enabled ? cs.onSurface : cs.onSurfaceVariant),
        label: Text(label, style: TextStyle(color: enabled ? cs.onSurface : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _FlagPill extends StatelessWidget {
  const _FlagPill({required this.label, required this.enabled});
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: enabled ? cs.primaryContainer.withValues(alpha: 0.85) : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(enabled ? Icons.toggle_on : Icons.toggle_off, size: 18, color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _FeatureFlagsTab extends StatelessWidget {
  const _FeatureFlagsTab();

  Future<void> _toggle(BuildContext context, FeatureFlagDefinition flag, bool enabled) async {
    final role = context.read<AdminAuthStore>().role ?? AdminRole.executiveReadonly;
    final store = context.read<AdminStore>();
    final actorId = store.currentAdmin?.id ?? 'unknown_admin';

    // For now, only super_admin can toggle global flags.
    if (role != AdminRole.superAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request-only: only super_admin can change global flags.')));
      return;
    }

    final confirm = await AdminChangeConfirmSheet.show(
      context,
      title: 'Change feature flag',
      summary: 'This updates global feature availability. It never reads any user health content.',
      previousValue: flag.enabled ? 'enabled' : 'disabled',
      newValue: enabled ? 'enabled' : 'disabled',
      confirmLabel: 'Apply',
    );
    if (confirm == null) return;

    try {
      await store.performUserAdminAction(
        AdminActionRequest(
          actorAdminId: actorId,
          actorRole: role,
          userId: 'system',
          action: 'FeatureFlag: Set',
          reason: confirm.reason,
          ticketReference: confirm.ticketReference,
          parameters: {
            'flag': flag.key.apiKey,
            'enabled': enabled,
            'previous': flag.enabled,
            'new': enabled,
          },
        ),
      );
      await store.refreshFeatureFlags();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flag updated (audited).')));
    } catch (e) {
      debugPrint('FeatureFlagsTab toggle failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update flag.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final cs = Theme.of(context).colorScheme;
    final role = context.watch<AdminAuthStore>().role ?? AdminRole.executiveReadonly;
    final flags = store.featureFlags;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Feature flags', style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => context.read<AdminStore>().refreshFeatureFlags(),
                icon: Icon(Icons.refresh, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            role == AdminRole.superAdmin
                ? 'Toggling a flag affects all users. All changes are audited.'
                : 'Read-only for your role. You can request changes via your support/billing workflow.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: flags.isEmpty
                ? const _EmptyState(label: 'No flags loaded yet.')
                : ListView.separated(
                    itemCount: flags.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final f = flags[i];
                      return _FlagRow(
                        flag: f,
                        canEdit: role == AdminRole.superAdmin,
                        onToggle: (v) => _toggle(context, f, v),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({required this.flag, required this.canEdit, required this.onToggle});
  final FeatureFlagDefinition flag;
  final bool canEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(flag.key.label, style: t.titleSmall),
                const SizedBox(height: 4),
                Text(flag.description, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text('Updated ${AdminFormatters.relativeTime(flag.updatedAt)}', style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: flag.enabled,
            onChanged: canEdit ? onToggle : null,
          ),
        ],
      ),
    );
  }
}

class _LimitOverridesTab extends StatelessWidget {
  const _LimitOverridesTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final cs = Theme.of(context).colorScheme;
    final rows = store.limitOverrides;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('Limit overrides', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => context.read<AdminStore>().refreshLimitOverrides(),
                  icon: Icon(Icons.refresh, color: cs.onSurface),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyState(label: 'No overrides loaded.')
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      columns: const [
                        DataColumn(label: Text('Override ID')),
                        DataColumn(label: Text('User ID')),
                        DataColumn(label: Text('Plan')),
                        DataColumn(label: Text('Limit key')),
                        DataColumn(label: Text('Previous')),
                        DataColumn(label: Text('New')),
                        DataColumn(label: Text('Expires')),
                        DataColumn(label: Text('Ticket')),
                        DataColumn(label: Text('Reason')),
                        DataColumn(label: Text('Created')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r.overrideId)),
                              DataCell(Text(r.userId)),
                              DataCell(Text(r.planName)),
                              DataCell(Text(r.limitKey)),
                              DataCell(Text(r.previousValue)),
                              DataCell(Text(r.newValue)),
                              DataCell(Text(r.expiresAt == null ? '—' : AdminFormatters.date(r.expiresAt!))),
                              DataCell(Text(r.ticketReference ?? '—')),
                              DataCell(SizedBox(width: 260, child: Text(r.reason, overflow: TextOverflow.ellipsis))),
                              DataCell(Text(AdminFormatters.dateTime(r.createdAt))),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 28, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _PlanPickerSheet extends StatefulWidget {
  const _PlanPickerSheet({required this.current});
  final String current;

  static Future<String?> show(BuildContext context, {required String current}) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _PlanPickerSheet(current: current),
      );

  @override
  State<_PlanPickerSheet> createState() => _PlanPickerSheetState();
}

class _PlanPickerSheetState extends State<_PlanPickerSheet> {
  late String _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final plans = const ['free', 'launch_free_6_months', 'premium', 'family', 'admin_test', 'suspended'];
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom, left: 20, right: 20, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final p in plans)
              RadioListTile<String>(
                value: p,
                groupValue: _selected,
                title: Text(p),
                onChanged: (v) => setState(() => _selected = v ?? _selected),
              ),
            const SizedBox(height: 12),
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
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text('Use this plan', style: TextStyle(color: cs.onPrimary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ExtendTrialSheet extends StatefulWidget {
  const _ExtendTrialSheet();

  static Future<int?> show(BuildContext context) => showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => const _ExtendTrialSheet(),
      );

  @override
  State<_ExtendTrialSheet> createState() => _ExtendTrialSheetState();
}

class _ExtendTrialSheetState extends State<_ExtendTrialSheet> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Extend trial', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                for (final d in const [3, 7, 14, 30])
                  ChoiceChip(
                    label: Text('+$d days'),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
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
                    onPressed: () => Navigator.of(context).pop(_days),
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

class _LimitInputSheet extends StatefulWidget {
  const _LimitInputSheet._({required this.title, required this.initialText, required this.keyboardType});
  final String title;
  final String initialText;
  final TextInputType keyboardType;

  static Future<int?> showInt(BuildContext context, {required String title, required int initial}) => showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _LimitInputSheet._(title: title, initialText: initial.toString(), keyboardType: TextInputType.number),
      );

  static Future<int?> showBytes(BuildContext context, {required String title, required int initialBytes}) => showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _LimitInputSheet._(title: title, initialText: initialBytes.toString(), keyboardType: TextInputType.number),
      );

  @override
  State<_LimitInputSheet> createState() => _LimitInputSheetState();
}

class _LimitInputSheetState extends State<_LimitInputSheet> {
  late final _controller = TextEditingController(text: widget.initialText);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final v = int.tryParse(raw);
    if (v == null || v < 0) {
      setState(() => _error = 'Enter a valid non-negative number.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom, left: 20, right: 20, top: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: widget.keyboardType,
              decoration: InputDecoration(
                labelText: 'New value',
                hintText: 'Enter numeric value',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
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
                    child: Text('Use value', style: TextStyle(color: cs.onPrimary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

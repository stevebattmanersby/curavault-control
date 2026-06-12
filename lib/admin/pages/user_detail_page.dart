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

class UserDetailPage extends StatelessWidget {
  const UserDetailPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'User detail',
      subtitle: 'Privacy-safe account metadata and diagnostics only.',
      actions: [
        IconButton(
          onPressed: () => context.go('/users'),
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          splashColor: Colors.transparent,
          tooltip: 'Back to users',
        ),
      ],
      child: FutureBuilder<UserAccountDetail?>(
        future: context.read<AdminStore>().getUserDetail(userId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _LoadingUserDetail();
          }
          final u = snap.data;
          if (u == null) {
            return _ErrorState(userId: userId);
          }
          return _UserDetailBody(detail: u);
        },
      ),
    );
  }
}

class _LoadingUserDetail extends StatelessWidget {
  const _LoadingUserDetail();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Loading user…', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminCard(
      header: Text('User not found', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No summary record was found for $userId.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.go('/users'),
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            label: Text('Back to users', style: TextStyle(color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _UserDetailBody extends StatelessWidget {
  const _UserDetailBody({required this.detail});

  final UserAccountDetail detail;

  @override
  Widget build(BuildContext context) {
    final canShowEmail = _canShowEmail(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        AdminCard(
          header: Row(
            children: [
              Text('Account summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              _StatusPill(value: detail.accountStatus),
            ],
          ),
          child: _KeyValueGrid(
            rows: [
              ('User ID', detail.userId),
              if (canShowEmail) ('Email', detail.email ?? '—'),
              ('Country', detail.country),
              ('Created', formatDateTimeShort(detail.createdAt)),
              ('Last login', formatDateTimeShort(detail.lastLoginAt)),
              ('Last active', formatDateTimeShort(detail.lastActiveAt)),
              ('Plan', detail.plan),
              ('Billing status', detail.billingStatus),
              ('Subscription provider', detail.subscriptionProvider),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminCard(
          header: Text('Usage summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          child: _KeyValueGrid(
            rows: [
              ('Family profiles', detail.profileCount.toString()),
              ('Records', detail.recordCount.toString()),
              ('Appointments', detail.appointmentCount.toString()),
              ('Medications', detail.medicationCount.toString()),
              ('Vaccinations', detail.vaccinationCount.toString()),
              ('Documents', detail.documentCount.toString()),
              ('Storage used', formatBytes(detail.storageUsedBytes)),
              ('AI tokens (mo)', formatCompactInt(detail.aiTokensUsedThisMonth)),
              ('AI requests (mo)', formatCompactInt(detail.aiRequestsThisMonth)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminCard(
          header: Text('Technical diagnostics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          child: _KeyValueGrid(
            rows: [
              ('Platform', detail.platform),
              ('App version', detail.appVersion),
              ('Last sync', formatDateTimeShort(detail.lastSyncAt)),
              ('Failed syncs (30d)', detail.failedSyncCount30d.toString()),
              ('Failed uploads (30d)', detail.failedUploadCount30d.toString()),
              ('Last error code', detail.lastKnownErrorCode ?? '—'),
              ('Device type', detail.deviceType),
              ('OS version', detail.osVersion),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminCard(
          header: Text('Limits', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          child: _KeyValueGrid(
            rows: [
              ('Storage limit', formatBytes(detail.storageLimitBytes)),
              ('AI token limit (mo)', formatCompactInt(detail.aiTokenLimitThisMonth)),
              ('Profile limit', detail.profileLimit.toString()),
              ('Upload limit', detail.uploadLimit?.toString() ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AdminCard(
          header: Text('Support status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          child: _KeyValueGrid(
            rows: [
              ('Open support sessions', detail.openSupportSessions.toString()),
              ('Consent status', detail.consentStatus),
              ('Ticket reference', detail.ticketReference ?? '—'),
              // PRIVACY: never render free-text notes in the control site UI.
              // Notes can accidentally contain health content.
              ('Support notes', detail.supportNotes?.trim().isNotEmpty == true ? 'Present (redacted)' : '—'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _AdminActionsCard(userId: detail.userId),
        const SizedBox(height: AppSpacing.lg),
        _PrivacyNoticeCard(),
      ],
    );
  }

  bool _canShowEmail(BuildContext context) {
    final role = context.read<AdminStore>().currentAdmin?.role;
    if (role == null) return false;
    return AdminRbac.canViewUserEmail(role);
  }
}

class _KeyValueGrid extends StatelessWidget {
  const _KeyValueGrid({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          children: [
            for (final (k, v) in rows)
              SizedBox(
                width: cols == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - (AppSpacing.lg * (cols - 1))) / cols,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SelectableText(v, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminActionsCard extends StatelessWidget {
  const _AdminActionsCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = context.read<AdminStore>().currentAdmin?.role;
    if (role == null) {
      return AdminCard(
        header: Text('Admin actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        child: Text('No admin role loaded.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      );
    }

    final actions = AdminUserAction.values.where((a) => AdminRbac.canPerformUserAction(role, a)).toList();
    return AdminCard(
      header: Text('Admin actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All actions require a reason and are written to the audit log. This UI never displays health content.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final a in actions)
                OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AdminActionConfirmSheet(userId: userId, action: a, role: role),
                  ),
                  icon: Icon(_iconFor(a), color: cs.onSurface),
                  label: Text(a.label, style: TextStyle(color: cs.onSurface)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AdminUserAction a) => switch (a) {
    AdminUserAction.changePlan => Icons.auto_awesome_mosaic_outlined,
    AdminUserAction.extendTrial => Icons.hourglass_top,
    AdminUserAction.adjustStorageLimit => Icons.storage_outlined,
    AdminUserAction.adjustAiLimit => Icons.smart_toy_outlined,
    AdminUserAction.suspendAccount => Icons.block,
    AdminUserAction.unsuspendAccount => Icons.lock_open,
    AdminUserAction.forceLogout => Icons.logout,
    AdminUserAction.revokeSessions => Icons.key_off,
    AdminUserAction.startSupportSession => Icons.support_agent,
    AdminUserAction.closeSupportSession => Icons.check_circle_outline,
    AdminUserAction.triggerComplianceExport => Icons.download_for_offline_outlined,
    AdminUserAction.triggerDeletionWorkflow => Icons.delete_outline,
  };
}

class AdminActionConfirmSheet extends StatefulWidget {
  const AdminActionConfirmSheet({super.key, required this.userId, required this.action, required this.role});

  final String userId;
  final AdminUserAction action;
  final AdminRole role;

  @override
  State<AdminActionConfirmSheet> createState() => _AdminActionConfirmSheetState();
}

class _AdminActionConfirmSheetState extends State<AdminActionConfirmSheet> {
  late final TextEditingController _reason;
  late final TextEditingController _ticket;
  late final TextEditingController _param;
  bool _confirm = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reason = TextEditingController();
    _ticket = TextEditingController();
    _param = TextEditingController();
  }

  @override
  void dispose() {
    _reason.dispose();
    _ticket.dispose();
    _param.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needsParam = widget.action == AdminUserAction.changePlan ||
        widget.action == AdminUserAction.adjustStorageLimit ||
        widget.action == AdminUserAction.adjustAiLimit ||
        widget.action == AdminUserAction.extendTrial;

    String paramLabel() => switch (widget.action) {
      AdminUserAction.changePlan => 'New plan',
      AdminUserAction.extendTrial => 'Extension (days)',
      AdminUserAction.adjustStorageLimit => 'New storage limit (bytes)',
      AdminUserAction.adjustAiLimit => 'New AI token limit (month)',
      _ => 'Parameter',
    };

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
                  Expanded(
                    child: Text(widget.action.label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : () => context.pop(),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    splashColor: Colors.transparent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Target user: ${widget.userId}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.lg),
              if (needsParam) ...[
                TextField(
                  controller: _param,
                  decoration: InputDecoration(
                    labelText: paramLabel(),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                controller: _reason,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Reason (required)',
                  hintText: 'Explain why this action is necessary…',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _ticket,
                decoration: InputDecoration(
                  labelText: 'Ticket reference (optional)',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Checkbox(
                    value: _confirm,
                    onChanged: _submitting ? null : (v) => setState(() => _confirm = v ?? false),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  Expanded(
                    child: Text(
                      'I confirm this action is authorized and will be audit logged.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : () async {
                        final reason = _reason.text.trim();
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required.')));
                          return;
                        }
                        if (!_confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm to continue.')));
                          return;
                        }
                        setState(() => _submitting = true);
                        try {
                          final admin = context.read<AdminStore>().currentAdmin;
                          if (admin == null) throw Exception('Admin profile not loaded');

                          final params = <String, dynamic>{};
                          if (needsParam && _param.text.trim().isNotEmpty) {
                            params['value'] = _param.text.trim();
                          }

                          await context.read<AdminStore>().performUserAdminAction(
                                AdminActionRequest(
                                  actorAdminId: admin.id,
                                  actorRole: widget.role,
                                  userId: widget.userId,
                                  action: widget.action.label,
                                  reason: reason,
                                  ticketReference: _ticket.text.trim().isEmpty ? null : _ticket.text.trim(),
                                  parameters: params.isEmpty ? null : params,
                                ),
                              );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action recorded.')));
                          context.pop();
                        } catch (e) {
                          debugPrint('Admin action failed: $e');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      },
                      style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                      child: _submitting
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                          : const Text('Confirm'),
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

class _PrivacyNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminCard(
      header: Text('Privacy boundaries', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      child: Text(
        'This control site intentionally never shows health record content (names, titles, values, document previews, AI prompts/responses, or search queries). Only safe account metadata, aggregated counts, and technical diagnostics are displayed.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
      ),
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
      child: Text(value, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

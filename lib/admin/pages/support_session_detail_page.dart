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

class SupportSessionDetailPage extends StatefulWidget {
  const SupportSessionDetailPage({super.key, required this.supportSessionId});
  final String supportSessionId;

  @override
  State<SupportSessionDetailPage> createState() => _SupportSessionDetailPageState();
}

class _SupportSessionDetailPageState extends State<SupportSessionDetailPage> {
  bool _loading = false;
  SupportSessionDetail? _detail;
  DiagnosticsReport? _diagnostics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await context.read<AdminStore>().getSupportSessionDetail(widget.supportSessionId);
      if (!mounted) return;
      setState(() => _detail = res);
    } catch (e) {
      debugPrint('SupportSessionDetailPage load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final detail = _detail;
    final role = context.read<AdminStore>().currentAdmin?.role;
    final canEmail = role != null && AdminRbac.canViewUserEmail(role);

    return AdminPageScaffold(
      title: 'Support session',
      subtitle: 'Diagnostics and account metadata only. Health content is never displayed.',
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/support/diagnostics${detail == null ? '' : '?userId=${Uri.encodeComponent(detail.userId)}'}'),
          icon: Icon(Icons.rule, color: cs.onSurface),
          label: Text('Diagnostics', style: TextStyle(color: cs.onSurface)),
          style: TextButton.styleFrom(
            backgroundColor: cs.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: detail == null ? null : () => _openActionSheet(SupportAction.closeSupportSession),
          icon: Icon(Icons.check_circle_outline, color: cs.onSurface),
          label: Text('Close', style: TextStyle(color: cs.onSurface)),
        ),
      ],
      child: _loading && detail == null
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : detail == null
              ? AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Session not found', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Try returning to the queue and selecting a session again.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () => context.pop(),
                        icon: Icon(Icons.arrow_back, color: cs.onSurface),
                        label: Text('Back', style: TextStyle(color: cs.onSurface)),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _MiniStat(label: 'Session ID', value: detail.supportSessionId),
                        _MiniStat(label: 'Status', value: detail.status.label),
                        _MiniStat(label: 'Consent', value: detail.consentWindowStatus),
                        _MiniStat(label: 'Access expires', value: formatDateTimeShort(detail.accessExpiresAt)),
                        _MiniStat(label: 'Assigned', value: detail.assignedAdmin ?? '—'),
                        _MiniStat(label: 'Last updated', value: formatDateTimeShort(detail.updatedAt)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TwoCol(
                      left: _SessionUserCard(detail: detail, canEmail: canEmail),
                      right: _SessionUsageCard(detail: detail),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TwoCol(
                      left: _OpenErrorsCard(openErrors: detail.openErrors),
                      right: _ActionsCard(role: role, onAction: _openActionSheet),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AdminCard(
                      header: Text('Recent technical events', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      child: _EventsTable(events: detail.recentTechnicalEvents),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AdminCard(
                      header: Text('Diagnostics checker', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      child: _DiagnosticsPanel(
                        report: _diagnostics,
                        isLoading: _loading && _diagnostics == null,
                        onRun: () async {
                          setState(() => _loading = true);
                          try {
                            final rep = await context.read<AdminStore>().runDiagnostics(detail.userId);
                            if (!mounted) return;
                            setState(() => _diagnostics = rep);
                          } catch (e) {
                            debugPrint('Run diagnostics failed: $e');
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AdminCard(
                      header: Text('Admin notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      // PRIVACY: never render free-text notes in the control site UI.
                      // Notes can accidentally contain health content.
                      child: Text(
                        detail.adminNotes?.trim().isNotEmpty == true ? 'Present (redacted)' : '—',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                      ),
                    ),
                  ],
                ),
    );
  }

  void _openActionSheet(SupportAction action) {
    final store = context.read<AdminStore>();
    final admin = store.currentAdmin;
    final detail = _detail;
    if (admin == null || detail == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupportActionConfirmSheet(
        supportSessionId: detail.supportSessionId,
        userId: detail.userId,
        action: action,
        actorAdminId: admin.id,
        actorRole: admin.role,
        ticketReference: detail.ticketReference,
      ),
    ).then((_) => _load());
  }
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < AdminBreakpoints.tablet) {
          return Column(children: [left, const SizedBox(height: AppSpacing.md), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: left), const SizedBox(width: AppSpacing.md), Expanded(child: right)],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SessionUserCard extends StatelessWidget {
  const _SessionUserCard({required this.detail, required this.canEmail});
  final SupportSessionDetail detail;
  final bool canEmail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminCard(
      header: Text('Account metadata', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      child: Column(
        children: [
          _KV(label: 'User ID', value: detail.userId),
          if (canEmail) _KV(label: 'Email', value: detail.email ?? '—') else _KV(label: 'Email', value: 'Hidden by role'),
          _KV(label: 'Account status', value: detail.accountStatus),
          _KV(label: 'Plan', value: detail.plan),
          _KV(label: 'App version', value: detail.appVersion),
          _KV(label: 'Platform', value: detail.platform),
          _KV(label: 'Country', value: detail.country),
          _KV(label: 'Last login', value: formatDateTimeShort(detail.lastLoginAt)),
          _KV(label: 'Last sync', value: formatDateTimeShort(detail.lastSyncAt)),
          _KV(label: 'Failed sync count', value: detail.failedSyncCount.toString()),
          _KV(label: 'Failed upload count', value: detail.failedUploadCount.toString()),
          _KV(label: 'Consent window', value: detail.consentWindowStatus),
          _KV(label: 'Ticket', value: detail.ticketReference ?? '—'),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'This view contains only operational metadata. No health records are accessible from the control site.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionUsageCard extends StatelessWidget {
  const _SessionUsageCard({required this.detail});
  final SupportSessionDetail detail;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      header: Text('Usage + limits', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      child: Column(
        children: [
          _KV(label: 'Storage used', value: formatBytes(detail.storageUsedBytes)),
          _KV(label: 'Storage limit', value: formatBytes(detail.storageLimitBytes)),
          _KV(label: 'AI tokens used (mo)', value: formatCompactInt(detail.aiTokensUsed)),
          _KV(label: 'AI limit', value: formatCompactInt(detail.aiLimit)),
        ],
      ),
    );
  }
}

class _OpenErrorsCard extends StatelessWidget {
  const _OpenErrorsCard({required this.openErrors});
  final List<String> openErrors;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminCard(
      header: Text('Open errors', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      child: openErrors.isEmpty
          ? Text('No open errors flagged.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final e in openErrors) _CodeChip(code: e),
              ],
            ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(999)),
      child: Text(code, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w800)),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.role, required this.onAction});
  final AdminRole? role;
  final void Function(SupportAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AdminCard(
      header: Text('Support actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Every action requires a reason, confirmation, and is written to the audit log.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final a in SupportAction.values)
                _ActionButton(
                  icon: _iconFor(a),
                  label: a.label,
                  enabled: role != null && AdminRbac.canPerformSupportAction(role!, a),
                  onPressed: () => onAction(a),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(SupportAction a) => switch (a) {
    SupportAction.resendVerificationEmail => Icons.email_outlined,
    SupportAction.forceLogout => Icons.logout,
    SupportAction.revokeActiveSessions => Icons.key_off,
    SupportAction.extendTrial => Icons.hourglass_top,
    SupportAction.temporarilyIncreaseStorageLimit => Icons.storage_outlined,
    SupportAction.temporarilyIncreaseAiLimit => Icons.smart_toy_outlined,
    SupportAction.suspendAccount => Icons.block,
    SupportAction.unsuspendAccount => Icons.lock_open,
    SupportAction.addSupportNote => Icons.sticky_note_2_outlined,
    SupportAction.closeSupportSession => Icons.check_circle_outline,
  };
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.enabled, required this.onPressed});
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: cs.onSurface),
      label: Text(label, style: TextStyle(color: cs.onSurface)),
    );
  }
}

class _EventsTable extends StatelessWidget {
  const _EventsTable({required this.events});
  final List<TechnicalEvent> events;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (events.isEmpty) {
      return Text('No events recorded.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
        dataTextStyle: Theme.of(context).textTheme.labelLarge,
        columns: const [
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Details')),
        ],
        rows: [
          for (final e in events)
            DataRow(
              cells: [
                DataCell(Text(formatDateTimeShort(e.timestamp))),
                DataCell(Text(e.type)),
                DataCell(Text(e.code ?? '—')),
                // PRIVACY: do not render raw event messages (they may contain user content).
                DataCell(Text(e.message.trim().isEmpty ? '—' : 'Redacted')),
              ],
            ),
        ],
      ),
    );
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({required this.report, required this.isLoading, required this.onRun});
  final DiagnosticsReport? report;
  final bool isLoading;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rep = report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: isLoading ? null : onRun,
              icon: Icon(Icons.play_arrow, color: cs.onPrimary),
              label: Text(isLoading ? 'Running…' : 'Run checks', style: TextStyle(color: cs.onPrimary)),
            ),
            const SizedBox(width: AppSpacing.md),
            if (rep != null)
              Text('Generated ${formatDateTimeShort(rep.generatedAt)}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (rep == null)
          Text('Run checks to generate a privacy-safe diagnostic report.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
        else
          Column(
            children: [
              for (final c in rep.checks) _DiagnosticCheckTile(check: c),
            ],
          ),
      ],
    );
  }
}

class _DiagnosticCheckTile extends StatelessWidget {
  const _DiagnosticCheckTile({required this.check});
  final DiagnosticCheck check;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = switch (check.status) {
      DiagnosticStatus.pass => (Icons.check_circle, cs.primary),
      DiagnosticStatus.warning => (Icons.warning_amber_rounded, cs.tertiary),
      DiagnosticStatus.fail => (Icons.error, cs.error),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(check.title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800))),
                    Text(check.status.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(check.explanation, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
                const SizedBox(height: 6),
                Text('Suggested: ${check.suggestedAction}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
          const SizedBox(width: AppSpacing.md),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class SupportActionConfirmSheet extends StatefulWidget {
  const SupportActionConfirmSheet({
    super.key,
    required this.supportSessionId,
    required this.userId,
    required this.action,
    required this.actorAdminId,
    required this.actorRole,
    required this.ticketReference,
  });

  final String supportSessionId;
  final String userId;
  final SupportAction action;
  final String actorAdminId;
  final AdminRole actorRole;
  final String? ticketReference;

  @override
  State<SupportActionConfirmSheet> createState() => _SupportActionConfirmSheetState();
}

class _SupportActionConfirmSheetState extends State<SupportActionConfirmSheet> {
  late final TextEditingController _reason;
  late final TextEditingController _param;
  bool _confirm = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reason = TextEditingController();
    _param = TextEditingController();
  }

  @override
  void dispose() {
    _reason.dispose();
    _param.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final needsParam = widget.action == SupportAction.extendTrial ||
        widget.action == SupportAction.temporarilyIncreaseStorageLimit ||
        widget.action == SupportAction.temporarilyIncreaseAiLimit ||
        widget.action == SupportAction.addSupportNote;

    String paramLabel() => switch (widget.action) {
      SupportAction.extendTrial => 'Extension (days)',
      SupportAction.temporarilyIncreaseStorageLimit => 'New storage limit (bytes)',
      SupportAction.temporarilyIncreaseAiLimit => 'New AI token limit (month)',
      SupportAction.addSupportNote => 'Support note',
      _ => 'Parameter',
    };

    final paramMultiline = widget.action == SupportAction.addSupportNote;

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
                  Expanded(child: Text(widget.action.label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(
                    onPressed: _submitting ? null : () => context.pop(),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    splashColor: Colors.transparent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Support session: ${widget.supportSessionId}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              Text('Target user: ${widget.userId}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.lg),
              if (needsParam) ...[
                TextField(
                  controller: _param,
                  minLines: paramMultiline ? 2 : 1,
                  maxLines: paramMultiline ? 5 : 1,
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
              CheckboxListTile(
                value: _confirm,
                onChanged: _submitting ? null : (v) => setState(() => _confirm = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text('I confirm this is appropriate and auditable', style: Theme.of(context).textTheme.labelLarge),
                subtitle: Text('This action will be recorded in the admin audit log.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => context.pop(),
                      child: Text('Cancel', style: TextStyle(color: cs.onSurface)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting
                          ? null
                          : () async {
                              final reason = _reason.text.trim();
                              if (reason.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required.')));
                                return;
                              }
                              if (!_confirm) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm to proceed.')));
                                return;
                              }
                              setState(() => _submitting = true);
                              try {
                                final params = <String, dynamic>{};
                                final p = _param.text.trim();
                                if (p.isNotEmpty) params['value'] = p;
                                await context.read<AdminStore>().performSupportAction(
                                      SupportActionRequest(
                                        actorAdminId: widget.actorAdminId,
                                        actorRole: widget.actorRole,
                                        supportSessionId: widget.supportSessionId,
                                        userId: widget.userId,
                                        action: widget.action,
                                        reason: reason,
                                        ticketReference: widget.ticketReference,
                                        parameters: params.isEmpty ? null : params,
                                      ),
                                    );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action completed: ${widget.action.label}')));
                                context.pop();
                              } catch (e) {
                                debugPrint('Support action failed: $e');
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed.')));
                              } finally {
                                if (mounted) setState(() => _submitting = false);
                              }
                            },
                      child: Text(_submitting ? 'Working…' : 'Confirm action', style: TextStyle(color: cs.onPrimary)),
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

void debugSupportDetail(String message) {
  if (kDebugMode) debugPrint(message);
}

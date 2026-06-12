import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/pages/support_session_detail_page.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class DiagnosticsCheckerPage extends StatefulWidget {
  const DiagnosticsCheckerPage({super.key, this.initialUserId});
  final String? initialUserId;

  @override
  State<DiagnosticsCheckerPage> createState() => _DiagnosticsCheckerPageState();
}

class _DiagnosticsCheckerPageState extends State<DiagnosticsCheckerPage> {
  late final TextEditingController _userId;
  bool _loading = false;
  DiagnosticsReport? _report;

  @override
  void initState() {
    super.initState();
    _userId = TextEditingController(text: widget.initialUserId ?? '');
    if ((widget.initialUserId ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final id = _userId.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a user ID.')));
      return;
    }
    setState(() {
      _loading = true;
      _report = null;
    });
    try {
      final rep = await context.read<AdminStore>().runDiagnostics(id);
      if (!mounted) return;
      setState(() => _report = rep);
    } catch (e) {
      debugPrint('DiagnosticsCheckerPage run failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diagnostics failed.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rep = _report;
    final admin = context.read<AdminStore>().currentAdmin;
    final role = admin?.role;

    return AdminPageScaffold(
      title: 'Diagnostics checker',
      subtitle: 'Run privacy-safe checks (account, plan, sync, limits, blocks).',
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/support'),
          icon: Icon(Icons.support_agent_outlined, color: cs.onSurface),
          label: Text('Queue', style: TextStyle(color: cs.onSurface)),
          style: TextButton.styleFrom(
            backgroundColor: cs.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          ),
        ),
      ],
      child: ListView(
        children: [
          AdminCard(
            header: Text('Run checks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userId,
                        decoration: InputDecoration(
                          labelText: 'User ID',
                          hintText: 'e.g. usr_100012',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _run(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _loading ? null : _run,
                      icon: Icon(Icons.play_arrow, color: cs.onPrimary),
                      label: Text(_loading ? 'Running…' : 'Run', style: TextStyle(color: cs.onPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'These checks are generated only from safe summary tables/views. No health content is queried or shown.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (rep == null)
            AdminCard(
              header: Text('Results', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              child: Text('Run a user ID to see results.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            )
          else ...[
            AdminCard(
              header: Row(
                children: [
                  Expanded(child: Text('Results for ${rep.userId}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  Text('Generated ${formatDateTimeShort(rep.generatedAt)}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              child: Column(
                children: [
                  for (final c in rep.checks) _DiagnosticRow(check: c),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminCard(
              header: Text('Recommended actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final a in SupportAction.values)
                    if (a != SupportAction.closeSupportSession)
                      _SupportActionChip(
                        action: a,
                        enabled: role != null && AdminRbac.canPerformSupportAction(role, a),
                        userIdController: _userId,
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.check});
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

class _SupportActionChip extends StatelessWidget {
  const _SupportActionChip({required this.action, required this.enabled, required this.userIdController});
  final SupportAction action;
  final bool enabled;
  final TextEditingController userIdController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: !enabled
          ? null
          : () {
              final store = context.read<AdminStore>();
              final admin = store.currentAdmin;
              final userId = userIdController.text.trim();
              if (admin == null || userId.isEmpty) return;
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => SupportActionConfirmSheet(
                  supportSessionId: 'diagnostics_only',
                  userId: userId,
                  action: action,
                  actorAdminId: admin.id,
                  actorRole: admin.role,
                  ticketReference: null,
                ),
              );
            },
      borderRadius: BorderRadius.circular(999),
      splashColor: Colors.transparent,
      highlightColor: cs.primary.withValues(alpha: 0.06),
      hoverColor: cs.primary.withValues(alpha: 0.06),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: enabled ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Text(action.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: enabled ? cs.onSurfaceVariant : cs.onSurfaceVariant.withValues(alpha: 0.6))),
      ),
    );
  }
}

void debugDiagnostics(String message) {
  if (kDebugMode) debugPrint(message);
}

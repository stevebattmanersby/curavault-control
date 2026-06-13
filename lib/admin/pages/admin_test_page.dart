import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/nav.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AdminTestPage extends StatelessWidget {
  const AdminTestPage({super.key});

  String _roleLabel(AdminRole? role) {
    if (role == null) return '—';
    return switch (role) {
      AdminRole.owner => 'owner',
      AdminRole.admin => 'admin',
      AdminRole.support => 'support',
      AdminRole.billing => 'billing',
      AdminRole.compliance => 'compliance',
      AdminRole.readOnly => 'read_only',
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthStore>();
    final cs = Theme.of(context).colorScheme;

    final email = auth.adminEmail ?? '—';
    final displayName = (auth.adminDisplayName ?? '').trim().isEmpty ? '—' : auth.adminDisplayName!;
    final role = auth.role;
    final status = auth.adminStatus ?? '—';
    final isActive = auth.isActive;
    final requireStepUp = auth.requireStepUp;

    return AdminPageScaffold(
      title: 'Admin Test',
      subtitle: 'Post-login verification (allow-list + role + active status).',
      actions: [
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.dashboard),
          icon: Icon(Icons.arrow_forward, color: cs.onPrimary),
          label: Text('Continue', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
        ),
      ],
      child: ListView(
        children: [
          AdminCard(
            header: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                  ),
                  child: Icon(Icons.verified_user_outlined, color: cs.onPrimary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Current admin session', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Email', value: email),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Name', value: displayName),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Role', value: _roleLabel(role)),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Active', value: (isActive == true) ? 'true' : 'false'),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Step-up', value: (requireStepUp == true) ? 'true' : 'false'),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: (isActive == true) ? cs.primaryContainer.withValues(alpha: 0.55) : cs.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    (isActive == true)
                        ? 'Access gate passed. You are allow-listed and active.'
                        : 'Access gate not passed. This account is not active/allow-listed.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: (isActive == true) ? cs.onPrimaryContainer : cs.onErrorContainer),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(label: 'Status', value: status),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'This screen shows only admin metadata. The control site must never query or expose raw health tables in the frontend.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

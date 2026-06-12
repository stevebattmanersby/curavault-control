import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AdminAuthStore>();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(Icons.block, color: cs.onErrorContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text('Access denied', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  auth.accessDeniedReason ?? 'Your account does not have permission to use the CuraVault Control Site.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      onPressed: auth.isSignedIn ? auth.signOut : null,
                      icon: Icon(Icons.logout, color: cs.onPrimary),
                      label: Text('Logout', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'If you believe this is an error, contact a super admin to add/activate your account in admin_users.',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/widgets/theme_selector.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminTopBar extends StatelessWidget {
  const AdminTopBar({super.key, required this.isDesktop, required this.onMenuPressed});

  final bool isDesktop;
  final VoidCallback onMenuPressed;

  static const String environment = String.fromEnvironment('CURAVAULT_ENV', defaultValue: 'DEV');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AdminAuthStore>();
    final email = auth.adminEmail ?? '—';
    final role = auth.role;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.tokens.surface,
        border: Border(bottom: BorderSide(color: context.tokens.border, width: 1)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              onPressed: onMenuPressed,
              icon: Icon(Icons.menu, color: cs.onSurface),
              splashColor: Colors.transparent,
              highlightColor: cs.primary.withValues(alpha: 0.06),
              hoverColor: cs.primary.withValues(alpha: 0.06),
            ),
          if (!isDesktop) const SizedBox(width: 6),
          _EnvironmentBadge(value: environment),
          const Spacer(),
          const ThemeSelector(compact: true),
          const SizedBox(width: AppSpacing.sm),
          _UserChip(email: email, role: role),
          const SizedBox(width: AppSpacing.sm),
          TextButton.icon(
            onPressed: () {
              auth.signOut();
            },
            icon: Icon(Icons.logout, color: cs.onSurface),
            label: Text('Logout', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
            style: TextButton.styleFrom(
              splashFactory: NoSplash.splashFactory,
              foregroundColor: cs.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentBadge extends StatelessWidget {
  const _EnvironmentBadge({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isProd = value.toUpperCase() == 'PROD';
    final bg = isProd ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = isProd ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isProd ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          Text(value.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.email, required this.role});
  final String email;
  final AdminRole? role;

  String _roleLabel(AdminRole? role) {
    switch (role) {
      case AdminRole.owner:
        return 'owner';
      case AdminRole.admin:
        return 'admin';
      case AdminRole.support:
        return 'support';
      case AdminRole.billing:
        return 'billing';
      case AdminRole.compliance:
        return 'compliance';
      case AdminRole.readOnly:
        return 'read_only';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                Text(
                  _roleLabel(role),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.85), height: 1.1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

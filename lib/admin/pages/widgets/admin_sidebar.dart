import 'package:curavault_admin/nav.dart';
import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/state/admin_theme_store.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key, required this.currentLocation, required this.onNavigate});

  final String currentLocation;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final role = context.watch<AdminAuthStore>().role;
    final themeStore = context.watch<AdminThemeStore>();

    bool allowed(String route) => role != null && (AdminRbac.routeAccess[route]?.contains(role) ?? false);

    return Material(
      color: context.tokens.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                        gradient: LinearGradient(colors: [context.tokens.primary, context.tokens.secondary]),
                    ),
                    child: Icon(Icons.shield_outlined, color: cs.onPrimary, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CuraVault', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text('Admin Console', style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
                children: [
                  if (allowed(AppRoutes.dashboard)) _SidebarItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: AppRoutes.dashboard, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.users)) _SidebarItem(label: 'Users', icon: Icons.people_alt_outlined, route: AppRoutes.users, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.support)) _SidebarItem(label: 'Support', icon: Icons.support_agent_outlined, route: AppRoutes.support, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.plansPermissions)) _SidebarItem(label: 'Plans & Permissions', icon: Icons.admin_panel_settings_outlined, route: AppRoutes.plansPermissions, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.usageAnalytics)) _SidebarItem(label: 'Usage Analytics', icon: Icons.insights_outlined, route: AppRoutes.usageAnalytics, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.storage)) _SidebarItem(label: 'Storage', icon: Icons.cloud_outlined, route: AppRoutes.storage, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.aiUsage)) _SidebarItem(label: 'AI Usage', icon: Icons.smart_toy_outlined, route: AppRoutes.aiUsage, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.billing)) _SidebarItem(label: 'Billing', icon: Icons.receipt_long_outlined, route: AppRoutes.billing, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.compliance)) _SidebarItem(label: 'Compliance', icon: Icons.verified_user_outlined, route: AppRoutes.compliance, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.systemHealth)) _SidebarItem(label: 'System Health', icon: Icons.monitor_heart_outlined, route: AppRoutes.systemHealth, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.auditLogs)) _SidebarItem(label: 'Audit Logs', icon: Icons.fact_check_outlined, route: AppRoutes.auditLogs, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.securityChecklist)) _SidebarItem(label: 'Security Checklist', icon: Icons.security_outlined, route: AppRoutes.securityChecklist, currentLocation: currentLocation, onNavigate: onNavigate),
                  if (allowed(AppRoutes.settings)) _SidebarItem(label: 'Settings', icon: Icons.settings_outlined, route: AppRoutes.settings, currentLocation: currentLocation, onNavigate: onNavigate),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.tokens.surfaceElevated.withValues(alpha: themeStore.mode == AdminThemeMode.ai ? 0.55 : 1),
                  border: Border.all(color: themeStore.mode == AdminThemeMode.ai ? context.tokens.borderGlow.withValues(alpha: 0.55) : context.tokens.border, width: 1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: themeStore.mode == AdminThemeMode.ai ? context.tokens.glowShadow : context.tokens.cardShadow,
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: cs.onSurfaceVariant, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Privacy-safe view\nNo medical content exposed',
                        style: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Tooltip(
                      message: 'Theme: ${themeStore.mode.label} (click to cycle)',
                      child: IconButton(
                        onPressed: () => themeStore.cycleMode(),
                        icon: Icon(
                          switch (themeStore.mode) {
                            AdminThemeMode.light => Icons.wb_sunny_outlined,
                            AdminThemeMode.dark => Icons.nightlight_outlined,
                            AdminThemeMode.ai => Icons.auto_awesome,
                          },
                          color: cs.onSurfaceVariant,
                          size: 18,
                        ),
                        splashColor: Colors.transparent,
                        highlightColor: cs.primary.withValues(alpha: 0.06),
                        hoverColor: cs.primary.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.label, required this.icon, required this.route, required this.currentLocation, required this.onNavigate});

  final String label;
  final IconData icon;
  final String route;
  final String currentLocation;
  final VoidCallback onNavigate;

  bool _isSelected(String location) => location == route || location.startsWith('$route/') || location.startsWith('$route?');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _isSelected(currentLocation);
    final bg = selected ? cs.primaryContainer : Colors.transparent;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          context.go(route);
          onNavigate();
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: Colors.transparent,
        highlightColor: cs.primary.withValues(alpha: 0.06),
        hoverColor: cs.primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg))),
            ],
          ),
        ),
      ),
    );
  }
}

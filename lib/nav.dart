import 'package:curavault_admin/admin/pages/admin_shell.dart';
import 'package:curavault_admin/admin/pages/ai_usage_page.dart';
import 'package:curavault_admin/admin/pages/audit_logs_page.dart';
import 'package:curavault_admin/admin/pages/billing_page.dart';
import 'package:curavault_admin/admin/pages/compliance_page.dart';
import 'package:curavault_admin/admin/pages/dashboard_page.dart';
import 'package:curavault_admin/admin/pages/loading_page.dart';
import 'package:curavault_admin/admin/pages/login_page.dart';
import 'package:curavault_admin/admin/pages/plans_permissions_page.dart';
import 'package:curavault_admin/admin/pages/settings_page.dart';
import 'package:curavault_admin/admin/pages/security_checklist_page.dart';
import 'package:curavault_admin/admin/pages/storage_page.dart';
import 'package:curavault_admin/admin/pages/support_queue_page.dart';
import 'package:curavault_admin/admin/pages/support_session_detail_page.dart';
import 'package:curavault_admin/admin/pages/diagnostics_checker_page.dart';
import 'package:curavault_admin/admin/pages/system_health_page.dart';
import 'package:curavault_admin/admin/pages/unauthorized_page.dart';
import 'package:curavault_admin/admin/pages/usage_analytics_page.dart';
import 'package:curavault_admin/admin/pages/users_page.dart';
import 'package:curavault_admin/admin/pages/user_detail_page.dart';
import 'package:curavault_admin/admin/pages/admin_test_page.dart';
import 'package:curavault_admin/admin/pages/reset_password_page.dart';
import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static GoRouter createRouter(AdminAuthStore auth) {
    return GoRouter(
      initialLocation: AppRoutes.loading,
      refreshListenable: auth,
      redirect: (context, state) {
        // IMPORTANT: Supabase recovery links often include query/fragment params.
        // We must decide auth-free routes based on the matched path, not the full
        // URI string, otherwise GoRouter will incorrectly redirect reset links to
        // /login.
        final location = state.uri.toString();
        final matched = state.matchedLocation;

        final isAuthFree = matched == AppRoutes.login || matched == AppRoutes.loading || matched == AppRoutes.resetPassword;
        if (auth.isBootstrapping) return isAuthFree ? null : AppRoutes.loading;

        if (!auth.isSignedIn) {
          return matched == AppRoutes.login ? null : AppRoutes.login;
        }

        if (!auth.isAuthorized) {
          // Signed in but not allow-listed / inactive / unknown role.
          return location == AppRoutes.unauthorized ? null : AppRoutes.unauthorized;
        }

        // Authorized admins should never land on login/loading/unauthorized.
        if (matched == AppRoutes.login || matched == AppRoutes.loading || matched == AppRoutes.unauthorized) {
          // After login, show the admin test page (simple verification screen).
          return AppRoutes.adminTest;
        }

        // RBAC: route-level enforcement.
        final role = auth.role;
        if (role == null) return AppRoutes.unauthorized;
        if (!AdminRbac.canAccessRoute(role, location)) return AppRoutes.unauthorized;

        return null;
      },
      routes: [
        GoRoute(path: AppRoutes.loading, name: 'loading', builder: (context, state) => const LoadingPage()),
        GoRoute(path: AppRoutes.login, name: 'login', builder: (context, state) => const LoginPage()),
        GoRoute(path: AppRoutes.resetPassword, name: 'resetPassword', builder: (context, state) => const ResetPasswordPage()),
        GoRoute(path: AppRoutes.unauthorized, name: 'unauthorized', builder: (context, state) => const UnauthorizedPage()),
        ShellRoute(
          builder: (context, state, child) => AdminShell(currentLocation: state.uri.toString(), child: child),
          routes: [
            GoRoute(path: AppRoutes.dashboard, name: 'dashboard', pageBuilder: (context, state) => const NoTransitionPage(child: DashboardPage())),
            GoRoute(path: AppRoutes.adminTest, name: 'adminTest', pageBuilder: (context, state) => const NoTransitionPage(child: AdminTestPage())),
            GoRoute(
              path: AppRoutes.users,
              name: 'users',
              pageBuilder: (context, state) => const NoTransitionPage(child: UsersPage()),
              routes: [
                GoRoute(
                  path: ':userId',
                  name: 'userDetail',
                  pageBuilder: (context, state) => NoTransitionPage(child: UserDetailPage(userId: state.pathParameters['userId'] ?? '')),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.support,
              name: 'support',
              pageBuilder: (context, state) => const NoTransitionPage(child: SupportQueuePage()),
              routes: [
                GoRoute(
                  path: 'diagnostics',
                  name: 'diagnostics',
                  pageBuilder: (context, state) {
                    final userId = state.uri.queryParameters['userId'];
                    return NoTransitionPage(child: DiagnosticsCheckerPage(initialUserId: userId));
                  },
                ),
                GoRoute(
                  path: ':supportSessionId',
                  name: 'supportSessionDetail',
                  pageBuilder: (context, state) => NoTransitionPage(child: SupportSessionDetailPage(supportSessionId: state.pathParameters['supportSessionId'] ?? '')),
                ),
              ],
            ),
            GoRoute(path: AppRoutes.plansPermissions, name: 'plansPermissions', pageBuilder: (context, state) => const NoTransitionPage(child: PlansPermissionsPage())),
            GoRoute(path: AppRoutes.usageAnalytics, name: 'usageAnalytics', pageBuilder: (context, state) => const NoTransitionPage(child: UsageAnalyticsPage())),
            GoRoute(path: AppRoutes.storage, name: 'storage', pageBuilder: (context, state) => const NoTransitionPage(child: StoragePage())),
            GoRoute(path: AppRoutes.aiUsage, name: 'aiUsage', pageBuilder: (context, state) => const NoTransitionPage(child: AiUsagePage())),
            GoRoute(path: AppRoutes.billing, name: 'billing', pageBuilder: (context, state) => const NoTransitionPage(child: BillingPage())),
            GoRoute(path: AppRoutes.compliance, name: 'compliance', pageBuilder: (context, state) => const NoTransitionPage(child: CompliancePage())),
            GoRoute(path: AppRoutes.systemHealth, name: 'systemHealth', pageBuilder: (context, state) => const NoTransitionPage(child: SystemHealthPage())),
            GoRoute(path: AppRoutes.auditLogs, name: 'auditLogs', pageBuilder: (context, state) => const NoTransitionPage(child: AuditLogsPage())),
            GoRoute(path: AppRoutes.securityChecklist, name: 'securityChecklist', pageBuilder: (context, state) => const NoTransitionPage(child: SecurityChecklistPage())),
            GoRoute(path: AppRoutes.settings, name: 'settings', pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage())),
          ],
        ),
        GoRoute(path: '/', redirect: (_, __) => AppRoutes.dashboard),
      ],
    );
  }
}

class AppRoutes {
  static const String loading = '/loading';
  static const String login = '/login';
  static const String resetPassword = '/reset-password';
  static const String unauthorized = '/unauthorized';
  static const String dashboard = '/dashboard';
  static const String adminTest = '/admin-test';
  static const String users = '/users';
  static const String support = '/support';
  static const String plansPermissions = '/plans-permissions';
  static const String usageAnalytics = '/usage-analytics';
  static const String storage = '/storage';
  static const String aiUsage = '/ai-usage';
  static const String billing = '/billing';
  static const String compliance = '/compliance';
  static const String systemHealth = '/system-health';
  static const String auditLogs = '/audit-logs';
  static const String securityChecklist = '/security-checklist';
  static const String settings = '/settings';
}

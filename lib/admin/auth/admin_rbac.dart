import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/nav.dart';

/// Admin roles supported by the CuraVault Control Site.
///
/// If a role is missing/unknown, access must be denied.
enum AdminRole {
  owner,
  admin,
  support,
  billing,
  compliance,
  readOnly,
}

AdminRole? parseAdminRole(String? value) {
  switch ((value ?? '').trim()) {
    case 'owner':
      return AdminRole.owner;
    case 'admin':
      return AdminRole.admin;
    case 'support':
      return AdminRole.support;
    case 'billing':
      return AdminRole.billing;
    case 'compliance':
      return AdminRole.compliance;
    case 'read_only':
    case 'read-only':
    case 'readonly':
      return AdminRole.readOnly;
    default:
      return null;
  }
}

/// Central policy table: which roles can access which routes.
///
/// Note: This is UI enforcement; database security still must be enforced with
/// RLS + safe summary views.
class AdminRbac {
  static const all = <AdminRole>{AdminRole.owner, AdminRole.admin, AdminRole.support, AdminRole.billing, AdminRole.compliance, AdminRole.readOnly};

  static const support = <AdminRole>{AdminRole.owner, AdminRole.support};
  static const billing = <AdminRole>{AdminRole.owner, AdminRole.billing};
  static const compliance = <AdminRole>{AdminRole.owner, AdminRole.compliance};
  static const ops = <AdminRole>{AdminRole.owner, AdminRole.admin};
  static const analytics = <AdminRole>{AdminRole.owner, AdminRole.admin, AdminRole.readOnly};

  static const Map<String, Set<AdminRole>> routeAccess = {
    AppRoutes.dashboard: all,
    AppRoutes.users: <AdminRole>{AdminRole.owner, AdminRole.support},
    AppRoutes.support: support,
    AppRoutes.plansPermissions: billing,
    AppRoutes.usageAnalytics: analytics,
    AppRoutes.storage: <AdminRole>{AdminRole.owner, AdminRole.admin, AdminRole.billing},
    AppRoutes.aiUsage: analytics,
    AppRoutes.billing: billing,
    AppRoutes.compliance: compliance,
    AppRoutes.systemHealth: ops,
    AppRoutes.auditLogs: <AdminRole>{AdminRole.owner, AdminRole.compliance},
    AppRoutes.securityChecklist: <AdminRole>{AdminRole.owner, AdminRole.compliance, AdminRole.admin},
    AppRoutes.settings: <AdminRole>{AdminRole.owner},
    AppRoutes.adminTest: all,
  };

  static bool canAccessRoute(AdminRole role, String location) {
    // Exact match, or a nested sub-route under a known route.
    for (final entry in routeAccess.entries) {
      final route = entry.key;
      if (location == route || location.startsWith('$route/') || location.startsWith('$route?')) return entry.value.contains(role);
    }
    // Unknown route => deny.
    return false;
  }

  /// Email is considered sensitive metadata and is only visible to specific roles.
  static bool canViewUserEmail(AdminRole role) => switch (role) {
    AdminRole.owner || AdminRole.support || AdminRole.billing || AdminRole.compliance => true,
    _ => false,
  };

  /// Compliance workflows are more sensitive: only compliance + super admins.
  static bool canViewComplianceEmail(AdminRole role) => switch (role) {
    AdminRole.owner || AdminRole.compliance => true,
    _ => false,
  };

  /// Billing email visibility is more restrictive than general user-email visibility.
  ///
  /// This is used for billing tables (subscriptions, failed payments) where email
  /// is only needed for billing workflow.
  static bool canViewBillingEmail(AdminRole role) => switch (role) {
    AdminRole.owner || AdminRole.billing => true,
    _ => false,
  };

  static bool canExportAuditCsv(AdminRole role) => switch (role) {
    AdminRole.owner || AdminRole.compliance => true,
    _ => false,
  };

  static bool canPerformBillingAction(AdminRole role, BillingAdminAction action) {
    switch (action) {
      case BillingAdminAction.extendTrial:
      case BillingAdminAction.changePlan:
      case BillingAdminAction.addBillingNote:
      case BillingAdminAction.grantManualCompAccess:
      case BillingAdminAction.revokeManualCompAccess:
        return role == AdminRole.owner || role == AdminRole.billing;
    }
  }

  /// Admin actions exposed in the UI.
  ///
  /// NOTE: This is UI enforcement only; the database/edge functions must still
  /// enforce permissions (RLS + role checks) and write audit logs.
  static bool canPerformUserAction(AdminRole role, AdminUserAction action) {
    switch (action) {
      case AdminUserAction.changePlan:
      case AdminUserAction.extendTrial:
        return role == AdminRole.owner || role == AdminRole.billing;
      case AdminUserAction.adjustStorageLimit:
      case AdminUserAction.adjustAiLimit:
        return role == AdminRole.owner || role == AdminRole.billing || role == AdminRole.admin;
      case AdminUserAction.suspendAccount:
      case AdminUserAction.unsuspendAccount:
        return role == AdminRole.owner;
      case AdminUserAction.forceLogout:
      case AdminUserAction.revokeSessions:
        return role == AdminRole.owner || role == AdminRole.support || role == AdminRole.admin;
      case AdminUserAction.startSupportSession:
      case AdminUserAction.closeSupportSession:
        return role == AdminRole.owner || role == AdminRole.support;
      case AdminUserAction.triggerComplianceExport:
      case AdminUserAction.triggerDeletionWorkflow:
        return role == AdminRole.owner || role == AdminRole.compliance;
    }
  }

  /// Support-session actions (queue/session detail/diagnostics checker).
  ///
  /// NOTE: UI enforcement only. Server-side must enforce the same policy.
  static bool canPerformSupportAction(AdminRole role, SupportAction action) {
    switch (action) {
      case SupportAction.resendVerificationEmail:
      case SupportAction.forceLogout:
      case SupportAction.revokeActiveSessions:
      case SupportAction.addSupportNote:
      case SupportAction.closeSupportSession:
        return role == AdminRole.owner || role == AdminRole.support;
      case SupportAction.extendTrial:
      case SupportAction.temporarilyIncreaseStorageLimit:
      case SupportAction.temporarilyIncreaseAiLimit:
        // Billing-impacting actions must be explicitly allowed. Support agents are
        // read/triage only unless also granted billing-admin role.
        return role == AdminRole.owner || role == AdminRole.billing;
      case SupportAction.suspendAccount:
      case SupportAction.unsuspendAccount:
        return role == AdminRole.owner;
    }
  }
}

enum BillingAdminAction {
  extendTrial,
  changePlan,
  grantManualCompAccess,
  revokeManualCompAccess,
  addBillingNote,
}

enum AdminUserAction {
  changePlan,
  extendTrial,
  adjustStorageLimit,
  adjustAiLimit,
  suspendAccount,
  unsuspendAccount,
  forceLogout,
  revokeSessions,
  startSupportSession,
  closeSupportSession,
  triggerComplianceExport,
  triggerDeletionWorkflow,
}

extension AdminUserActionX on AdminUserAction {
  String get label => switch (this) {
    AdminUserAction.changePlan => 'Change plan',
    AdminUserAction.extendTrial => 'Extend trial',
    AdminUserAction.adjustStorageLimit => 'Adjust storage limit',
    AdminUserAction.adjustAiLimit => 'Adjust AI limit',
    AdminUserAction.suspendAccount => 'Suspend account',
    AdminUserAction.unsuspendAccount => 'Unsuspend account',
    AdminUserAction.forceLogout => 'Force logout',
    AdminUserAction.revokeSessions => 'Revoke sessions',
    AdminUserAction.startSupportSession => 'Start support session',
    AdminUserAction.closeSupportSession => 'Close support session',
    AdminUserAction.triggerComplianceExport => 'Trigger compliance export',
    AdminUserAction.triggerDeletionWorkflow => 'Trigger deletion workflow',
  };
}

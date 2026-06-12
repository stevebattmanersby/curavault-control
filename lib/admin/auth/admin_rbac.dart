import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/nav.dart';

/// Admin roles supported by the CuraVault Control Site.
///
/// If a role is missing/unknown, access must be denied.
enum AdminRole {
  superAdmin,
  supportAgent,
  billingAdmin,
  productAnalyst,
  complianceOfficer,
  developerOps,
  executiveReadonly,
}

AdminRole? parseAdminRole(String? value) {
  switch ((value ?? '').trim()) {
    case 'super_admin':
      return AdminRole.superAdmin;
    case 'support_agent':
      return AdminRole.supportAgent;
    case 'billing_admin':
      return AdminRole.billingAdmin;
    case 'product_analyst':
      return AdminRole.productAnalyst;
    case 'compliance_officer':
      return AdminRole.complianceOfficer;
    case 'developer_ops':
      return AdminRole.developerOps;
    case 'executive_readonly':
      return AdminRole.executiveReadonly;
    default:
      return null;
  }
}

/// Central policy table: which roles can access which routes.
///
/// Note: This is UI enforcement; database security still must be enforced with
/// RLS + safe summary views.
class AdminRbac {
  static const all = <AdminRole>{
    AdminRole.superAdmin,
    AdminRole.supportAgent,
    AdminRole.billingAdmin,
    AdminRole.productAnalyst,
    AdminRole.complianceOfficer,
    AdminRole.developerOps,
    AdminRole.executiveReadonly,
  };

  static const support = <AdminRole>{AdminRole.superAdmin, AdminRole.supportAgent};
  static const billing = <AdminRole>{AdminRole.superAdmin, AdminRole.billingAdmin};
  static const compliance = <AdminRole>{AdminRole.superAdmin, AdminRole.complianceOfficer};
  static const ops = <AdminRole>{AdminRole.superAdmin, AdminRole.developerOps};
  static const analytics = <AdminRole>{AdminRole.superAdmin, AdminRole.productAnalyst, AdminRole.executiveReadonly};

  static const Map<String, Set<AdminRole>> routeAccess = {
    AppRoutes.dashboard: all,
    AppRoutes.users: <AdminRole>{AdminRole.superAdmin, AdminRole.supportAgent},
    AppRoutes.support: support,
    AppRoutes.plansPermissions: billing,
    AppRoutes.usageAnalytics: analytics,
    AppRoutes.storage: <AdminRole>{AdminRole.superAdmin, AdminRole.developerOps, AdminRole.billingAdmin},
    AppRoutes.aiUsage: analytics,
    AppRoutes.billing: billing,
    AppRoutes.compliance: compliance,
    AppRoutes.systemHealth: ops,
    AppRoutes.auditLogs: <AdminRole>{AdminRole.superAdmin, AdminRole.complianceOfficer, AdminRole.developerOps},
    AppRoutes.securityChecklist: <AdminRole>{AdminRole.superAdmin, AdminRole.complianceOfficer, AdminRole.developerOps},
    AppRoutes.settings: <AdminRole>{AdminRole.superAdmin},
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
    AdminRole.superAdmin || AdminRole.supportAgent || AdminRole.billingAdmin || AdminRole.complianceOfficer => true,
    _ => false,
  };

  /// Compliance workflows are more sensitive: only compliance + super admins.
  static bool canViewComplianceEmail(AdminRole role) => switch (role) {
    AdminRole.superAdmin || AdminRole.complianceOfficer => true,
    _ => false,
  };

  /// Billing email visibility is more restrictive than general user-email visibility.
  ///
  /// This is used for billing tables (subscriptions, failed payments) where email
  /// is only needed for billing workflow.
  static bool canViewBillingEmail(AdminRole role) => switch (role) {
    AdminRole.superAdmin || AdminRole.billingAdmin => true,
    _ => false,
  };

  static bool canExportAuditCsv(AdminRole role) => switch (role) {
    AdminRole.superAdmin || AdminRole.complianceOfficer => true,
    _ => false,
  };

  static bool canPerformBillingAction(AdminRole role, BillingAdminAction action) {
    switch (action) {
      case BillingAdminAction.extendTrial:
      case BillingAdminAction.changePlan:
      case BillingAdminAction.addBillingNote:
      case BillingAdminAction.grantManualCompAccess:
      case BillingAdminAction.revokeManualCompAccess:
        return role == AdminRole.superAdmin || role == AdminRole.billingAdmin;
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
        return role == AdminRole.superAdmin || role == AdminRole.billingAdmin;
      case AdminUserAction.adjustStorageLimit:
      case AdminUserAction.adjustAiLimit:
        return role == AdminRole.superAdmin || role == AdminRole.billingAdmin || role == AdminRole.developerOps;
      case AdminUserAction.suspendAccount:
      case AdminUserAction.unsuspendAccount:
        return role == AdminRole.superAdmin;
      case AdminUserAction.forceLogout:
      case AdminUserAction.revokeSessions:
        return role == AdminRole.superAdmin || role == AdminRole.supportAgent || role == AdminRole.developerOps;
      case AdminUserAction.startSupportSession:
      case AdminUserAction.closeSupportSession:
        return role == AdminRole.superAdmin || role == AdminRole.supportAgent;
      case AdminUserAction.triggerComplianceExport:
      case AdminUserAction.triggerDeletionWorkflow:
        return role == AdminRole.superAdmin || role == AdminRole.complianceOfficer;
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
        return role == AdminRole.superAdmin || role == AdminRole.supportAgent;
      case SupportAction.extendTrial:
      case SupportAction.temporarilyIncreaseStorageLimit:
      case SupportAction.temporarilyIncreaseAiLimit:
        // Billing-impacting actions must be explicitly allowed. Support agents are
        // read/triage only unless also granted billing-admin role.
        return role == AdminRole.superAdmin || role == AdminRole.billingAdmin;
      case SupportAction.suspendAccount:
      case SupportAction.unsuspendAccount:
        return role == AdminRole.superAdmin;
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

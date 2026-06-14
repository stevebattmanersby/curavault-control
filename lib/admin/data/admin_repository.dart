import 'package:curavault_admin/admin/data/models/admin_models.dart';

abstract interface class AdminRepository {
  Future<AdminUser> getCurrentAdmin();

  /// Create a row in `admin_audit_log`.
  ///
  /// Implementations must redact any sensitive content from previous/new values.
  Future<void> createAuditLog({required AdminAuditLogCreate entry});

  /// Privacy-safe list of accounts. Email may be omitted depending on role.
  Future<List<UserAccountSummary>> listUsers({required UserListQuery query, required int limit});

  /// Privacy-safe user detail view.
  ///
  /// IMPORTANT: Must be sourced from safe summary tables/views.
  Future<UserAccountDetail> getUserDetail({required String userId});

  /// Execute an admin action against a user.
  ///
  /// Implementations must:
  /// - Require a reason
  /// - Optionally include ticket reference
  /// - Write an audit log entry
  Future<void> performUserAdminAction({required AdminActionRequest request});

  Future<List<AuditLogEntry>> listAuditLogs({required AuditLogQuery query, required int limit});

  /// Admin-safe audit summary aggregates (counts only).
  Future<AuditSummarySnapshot> getAuditSummary();

  /// Support queue: privacy-safe support sessions (no health content).
  Future<List<SupportSessionSummary>> listSupportSessions({required SupportQueueQuery query, required int limit});

  /// Admin-safe support summary aggregates (counts only).
  Future<SupportSummarySnapshot> getSupportSummary();

  /// Support session detail: account diagnostics + technical events only.
  Future<SupportSessionDetail> getSupportSessionDetail({required String supportSessionId});

  /// Run a diagnostic checker for an account.
  ///
  /// Implementations must not query raw health content.
  Future<DiagnosticsReport> runDiagnostics({required String userId});

  /// Execute an auditable support action.
  ///
  /// Implementations must:
  /// - Require a reason
  /// - Require confirmation (server-side)
  /// - Write to admin_audit_log
  Future<void> performSupportAction({required SupportActionRequest request});

  /// Privacy-safe executive dashboard aggregates.
  ///
  /// IMPORTANT: This must be sourced from summary tables/views in Supabase.
  /// Never query raw health records directly from the admin site.
  Future<DashboardSnapshot> getDashboardSnapshot({required DashboardQuery query});

  // ------------------------------
  // Plans & permissions
  // ------------------------------

  /// Plan catalog + distribution counts.
  ///
  /// IMPORTANT: Must be sourced from safe summary views.
  Future<List<PlanOverviewRow>> listPlansOverview({required int limit});

  /// User entitlements & limits (privacy-safe).
  ///
  /// IMPORTANT: Must be sourced from safe summary views and override tables.
  Future<UserEntitlements> getUserEntitlements({required String userId});

  /// Feature flags available in the system.
  ///
  /// IMPORTANT: Must not include any user health data.
  Future<List<FeatureFlagDefinition>> listFeatureFlags({required int limit});

  /// List limit overrides (privacy-safe).
  Future<List<LimitOverrideRow>> listLimitOverrides({required int limit});

  // ------------------------------
  // Usage analytics
  // ------------------------------

  /// Privacy-safe product analytics.
  ///
  /// IMPORTANT:
  /// - Must be sourced from safe summary tables/views only.
  /// - Never return user-entered content (search queries, AI prompts/responses,
  ///   document names, record contents, etc.).
  Future<UsageAnalyticsSnapshot> getUsageAnalyticsSnapshot({required UsageAnalyticsQuery query});

  // ------------------------------
  // Storage
  // ------------------------------

  /// Privacy-safe storage observability.
  ///
  /// IMPORTANT:
  /// - Must be sourced from safe summary tables/views only.
  /// - Must never return file names, URLs, paths, previews, or document categories.
  Future<StorageSnapshot> getStorageSnapshot({required StorageQuery query});

  // ------------------------------
  // AI usage (privacy-safe)
  // ------------------------------

  /// Privacy-safe AI observability.
  ///
  /// IMPORTANT:
  /// - Must be sourced from safe summary tables/views only.
  /// - Must never return prompts, responses, document text, user-entered notes,
  ///   medical summaries, or search queries.
  Future<AiUsageSnapshot> getAiUsageSnapshot({required AiUsageQuery query});

  // ------------------------------
  // Billing (privacy-safe)
  // ------------------------------

  /// Privacy-safe billing monitoring.
  ///
  /// IMPORTANT:
  /// - Must be sourced from safe billing summary tables/views only.
  /// - Must never return invoice PDFs, card details, addresses, or health content.
  Future<BillingSnapshot> getBillingSnapshot({required BillingQuery query});

  // ------------------------------
  // Compliance (privacy-safe)
  // ------------------------------

  /// Privacy-safe compliance workflows.
  ///
  /// IMPORTANT:
  /// - Must be sourced from safe workflow tables/views only.
  /// - Must never return user-entered health content.
  Future<ComplianceSnapshot> getComplianceSnapshot({required ComplianceQuery query});

  /// Execute an auditable compliance action.
  ///
  /// Implementations must:
  /// - Require a reason
  /// - Write to admin_audit_log
  /// - Enforce RBAC server-side
  Future<void> performComplianceAction({required ComplianceActionRequest request});

  // ------------------------------
  // System health (privacy-safe)
  // ------------------------------

  /// Privacy-safe reliability monitoring.
  ///
  /// IMPORTANT:
  /// - Must be sourced from safe aggregate-only tables/views.
  /// - Must never return raw user input, medical data, file names, AI prompts,
  ///   AI responses, or search queries.
  Future<SystemHealthSnapshot> getSystemHealthSnapshot({required SystemHealthQuery query});

  // ------------------------------
  // Security checklist
  // ------------------------------

  /// Security posture snapshot for the Control Site.
  ///
  /// IMPORTANT: This must not query or expose raw health data.
  Future<SecurityChecklistSnapshot> getSecurityChecklistSnapshot();
}

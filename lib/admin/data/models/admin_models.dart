import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

enum AdminDateRangePreset {
  today,
  days7,
  days30,
  days90;

  int get days => switch (this) {
    AdminDateRangePreset.today => 1,
    AdminDateRangePreset.days7 => 7,
    AdminDateRangePreset.days30 => 30,
    AdminDateRangePreset.days90 => 90,
  };

  String get label => switch (this) {
    AdminDateRangePreset.today => 'Today',
    AdminDateRangePreset.days7 => '7 days',
    AdminDateRangePreset.days30 => '30 days',
    AdminDateRangePreset.days90 => '90 days',
  };
}

// ------------------------------
// Compliance models (privacy-safe)
// ------------------------------

enum ComplianceRequestStatus {
  open,
  inProgress,
  completed,
  failed,
}

extension ComplianceRequestStatusX on ComplianceRequestStatus {
  String get label => switch (this) {
    ComplianceRequestStatus.open => 'open',
    ComplianceRequestStatus.inProgress => 'in_progress',
    ComplianceRequestStatus.completed => 'completed',
    ComplianceRequestStatus.failed => 'failed',
  };
}

ComplianceRequestStatus? parseComplianceRequestStatus(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'open':
    case 'pending':
      return ComplianceRequestStatus.open;
    case 'in_progress':
    case 'inprogress':
      return ComplianceRequestStatus.inProgress;
    case 'completed':
    case 'done':
      return ComplianceRequestStatus.completed;
    case 'failed':
      return ComplianceRequestStatus.failed;
    default:
      return null;
  }
}

@immutable
class ComplianceQuery {
  const ComplianceQuery({required this.range});
  final AdminDateRangePreset range;
  ComplianceQuery copyWith({AdminDateRangePreset? range}) => ComplianceQuery(range: range ?? this.range);
}

@immutable
class ComplianceOverviewMetrics {
  const ComplianceOverviewMetrics({
    required this.openDeletionRequests,
    required this.completedDeletionRequests,
    required this.failedDeletionRequests,
    required this.openExportRequests,
    required this.completedExportRequests,
    required this.activeSupportSessions,
    required this.expiredSupportSessions,
    required this.recentAdminActions,
    required this.usersPendingDeletion,
  });

  final int openDeletionRequests;
  final int completedDeletionRequests;
  final int failedDeletionRequests;
  final int openExportRequests;
  final int completedExportRequests;
  final int activeSupportSessions;
  final int expiredSupportSessions;
  final int recentAdminActions;
  final int usersPendingDeletion;
}

@immutable
class DataExportRequestRow {
  const DataExportRequestRow({
    required this.requestId,
    required this.userId,
    this.email,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.verifiedBy,
    this.failureReason,
    this.notes,
  });

  final String requestId;
  final String userId;
  final String? email; // RBAC-gated
  final ComplianceRequestStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? verifiedBy;
  final String? failureReason;
  final String? notes;

  DataExportRequestRow copyWith({
    ComplianceRequestStatus? status,
    DateTime? requestedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? verifiedBy,
    bool clearVerifiedBy = false,
    String? failureReason,
    bool clearFailureReason = false,
    String? notes,
    bool clearNotes = false,
    String? email,
    bool clearEmail = false,
  }) =>
      DataExportRequestRow(
        requestId: requestId,
        userId: userId,
        email: clearEmail ? null : (email ?? this.email),
        status: status ?? this.status,
        requestedAt: requestedAt ?? this.requestedAt,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        verifiedBy: clearVerifiedBy ? null : (verifiedBy ?? this.verifiedBy),
        failureReason: clearFailureReason ? null : (failureReason ?? this.failureReason),
        notes: clearNotes ? null : (notes ?? this.notes),
      );
}

@immutable
class DeletionRequestRow {
  const DeletionRequestRow({
    required this.requestId,
    required this.userId,
    this.email,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.failedReason,
    required this.retentionException,
    this.verifiedBy,
  });

  final String requestId;
  final String userId;
  final String? email; // RBAC-gated
  final ComplianceRequestStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? failedReason;
  final bool retentionException;
  final String? verifiedBy;

  DeletionRequestRow copyWith({
    ComplianceRequestStatus? status,
    DateTime? requestedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? failedReason,
    bool clearFailedReason = false,
    bool? retentionException,
    String? verifiedBy,
    bool clearVerifiedBy = false,
    String? email,
    bool clearEmail = false,
  }) =>
      DeletionRequestRow(
        requestId: requestId,
        userId: userId,
        email: clearEmail ? null : (email ?? this.email),
        status: status ?? this.status,
        requestedAt: requestedAt ?? this.requestedAt,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        failedReason: clearFailedReason ? null : (failedReason ?? this.failedReason),
        retentionException: retentionException ?? this.retentionException,
        verifiedBy: clearVerifiedBy ? null : (verifiedBy ?? this.verifiedBy),
      );
}

@immutable
class ConsentRecordRow {
  const ConsentRecordRow({
    required this.userId,
    required this.consentType,
    required this.version,
    required this.acceptedAt,
    this.revokedAt,
    required this.source,
    required this.country,
  });

  final String userId;
  final String consentType;
  final String version;
  final DateTime acceptedAt;
  final DateTime? revokedAt;
  final String source;
  final String country;
}

@immutable
class SupportAccessRecordRow {
  const SupportAccessRecordRow({
    required this.userId,
    required this.adminUser,
    required this.consentGranted,
    this.consentGrantedAt,
    this.accessExpiresAt,
    required this.status,
    this.ticketReference,
  });

  final String userId;
  final String adminUser;
  final bool consentGranted;
  final DateTime? consentGrantedAt;
  final DateTime? accessExpiresAt;
  final String status;
  final String? ticketReference;

  SupportAccessRecordRow copyWith({
    bool? consentGranted,
    DateTime? consentGrantedAt,
    bool clearConsentGrantedAt = false,
    DateTime? accessExpiresAt,
    bool clearAccessExpiresAt = false,
    String? status,
    String? ticketReference,
    bool clearTicketReference = false,
  }) =>
      SupportAccessRecordRow(
        userId: userId,
        adminUser: adminUser,
        consentGranted: consentGranted ?? this.consentGranted,
        consentGrantedAt: clearConsentGrantedAt ? null : (consentGrantedAt ?? this.consentGrantedAt),
        accessExpiresAt: clearAccessExpiresAt ? null : (accessExpiresAt ?? this.accessExpiresAt),
        status: status ?? this.status,
        ticketReference: clearTicketReference ? null : (ticketReference ?? this.ticketReference),
      );
}

@immutable
class PrivacyTermsAcceptanceRow {
  const PrivacyTermsAcceptanceRow({
    required this.userId,
    required this.privacyPolicyVersion,
    required this.termsVersion,
    required this.acceptedAt,
    required this.country,
  });

  final String userId;
  final String privacyPolicyVersion;
  final String termsVersion;
  final DateTime acceptedAt;
  final String country;
}

@immutable
class RetentionMonitoringMetrics {
  const RetentionMonitoringMetrics({
    required this.usageLogsDueForDeletion,
    required this.supportNotesDueForDeletion,
    required this.expiredSupportSessions,
    required this.oldDiagnosticLogs,
    required this.oldRawEvents,
  });

  final int usageLogsDueForDeletion;
  final int supportNotesDueForDeletion;
  final int expiredSupportSessions;
  final int oldDiagnosticLogs;
  final int oldRawEvents;
}

enum ComplianceAction {
  markExportInProgress,
  markExportComplete,
  markDeletionInProgress,
  markDeletionComplete,
  recordFailureReason,
  addComplianceNote,
  closeSupportAccess,
}

extension ComplianceActionX on ComplianceAction {
  String get label => switch (this) {
    ComplianceAction.markExportInProgress => 'Mark export in progress',
    ComplianceAction.markExportComplete => 'Mark export complete',
    ComplianceAction.markDeletionInProgress => 'Mark deletion in progress',
    ComplianceAction.markDeletionComplete => 'Mark deletion complete',
    ComplianceAction.recordFailureReason => 'Record failure reason',
    ComplianceAction.addComplianceNote => 'Add compliance note',
    ComplianceAction.closeSupportAccess => 'Close support access',
  };
}

@immutable
class ComplianceActionRequest {
  const ComplianceActionRequest({
    required this.actorAdminId,
    required this.actorRole,
    required this.userId,
    required this.action,
    required this.reason,
    this.ticketReference,
    this.requestId,
    this.parameters,
  });

  final String actorAdminId;
  final AdminRole actorRole;
  final String userId;
  final ComplianceAction action;
  final String reason;
  final String? ticketReference;

  /// Export/deletion request id or support access record id.
  final String? requestId;
  final Map<String, dynamic>? parameters;
}

@immutable
class ComplianceSnapshot {
  const ComplianceSnapshot({
    required this.query,
    required this.overview,
    required this.exportRequests,
    required this.deletionRequests,
    required this.consentRecords,
    required this.supportAccessRecords,
    required this.privacyTermsAcceptances,
    required this.retention,
    required this.generatedAt,
  });

  final ComplianceQuery query;
  final ComplianceOverviewMetrics overview;
  final List<DataExportRequestRow> exportRequests;
  final List<DeletionRequestRow> deletionRequests;
  final List<ConsentRecordRow> consentRecords;
  final List<SupportAccessRecordRow> supportAccessRecords;
  final List<PrivacyTermsAcceptanceRow> privacyTermsAcceptances;
  final RetentionMonitoringMetrics retention;
  final DateTime generatedAt;
}

// ------------------------------
// Billing models (privacy-safe)
// ------------------------------

enum BillingSubscriptionProvider {
  apple,
  google,
  stripe,
  manual,
}

extension BillingSubscriptionProviderX on BillingSubscriptionProvider {
  String get label => switch (this) {
    BillingSubscriptionProvider.apple => 'Apple',
    BillingSubscriptionProvider.google => 'Google',
    BillingSubscriptionProvider.stripe => 'Stripe',
    BillingSubscriptionProvider.manual => 'Manual/Admin',
  };

  String get key => switch (this) {
    BillingSubscriptionProvider.apple => 'apple',
    BillingSubscriptionProvider.google => 'google',
    BillingSubscriptionProvider.stripe => 'stripe',
    BillingSubscriptionProvider.manual => 'manual',
  };

  static BillingSubscriptionProvider? parse(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'apple':
        return BillingSubscriptionProvider.apple;
      case 'google':
        return BillingSubscriptionProvider.google;
      case 'stripe':
        return BillingSubscriptionProvider.stripe;
      case 'manual':
      case 'manual/admin':
      case 'manual_admin':
        return BillingSubscriptionProvider.manual;
      default:
        return null;
    }
  }
}

@immutable
class BillingQuery {
  const BillingQuery({required this.range, this.country, this.plan, this.provider});

  final AdminDateRangePreset range;
  final String? country;
  final String? plan;
  final BillingSubscriptionProvider? provider;

  BillingQuery copyWith({
    AdminDateRangePreset? range,
    String? country,
    bool clearCountry = false,
    String? plan,
    bool clearPlan = false,
    BillingSubscriptionProvider? provider,
    bool clearProvider = false,
  }) =>
      BillingQuery(
        range: range ?? this.range,
        country: clearCountry ? null : (country ?? this.country),
        plan: clearPlan ? null : (plan ?? this.plan),
        provider: clearProvider ? null : (provider ?? this.provider),
      );
}

@immutable
class BillingOverviewMetrics {
  const BillingOverviewMetrics({
    required this.activePaidUsers,
    required this.freeUsers,
    required this.trialUsers,
    required this.cancelledUsers,
    required this.failedPayments,
    required this.monthlyRecurringRevenueUsd,
    required this.annualRecurringRevenueUsd,
    required this.averageRevenuePerUserUsd,
    required this.trialConversionRate,
  });

  final int activePaidUsers;
  final int freeUsers;
  final int trialUsers;
  final int cancelledUsers;
  final int failedPayments;
  final double monthlyRecurringRevenueUsd;
  final double annualRecurringRevenueUsd;
  final double averageRevenuePerUserUsd;
  /// Range [0..1]
  final double trialConversionRate;
}

@immutable
class SubscriptionRow {
  const SubscriptionRow({
    required this.userId,
    this.email,
    required this.plan,
    required this.billingStatus,
    required this.provider,
    required this.subscriptionStart,
    required this.renewalDate,
    this.cancelledDate,
    required this.paymentFailureCount,
    required this.country,
    required this.manualCompAccess,
    this.billingNote,
  });

  final String userId;
  final String? email;
  final String plan;
  final String billingStatus;
  final BillingSubscriptionProvider provider;
  final DateTime subscriptionStart;
  final DateTime? renewalDate;
  final DateTime? cancelledDate;
  final int paymentFailureCount;
  final String country;
  final bool manualCompAccess;
  final String? billingNote;

  SubscriptionRow copyWith({
    String? plan,
    String? billingStatus,
    BillingSubscriptionProvider? provider,
    DateTime? subscriptionStart,
    DateTime? renewalDate,
    bool clearRenewalDate = false,
    DateTime? cancelledDate,
    bool clearCancelledDate = false,
    int? paymentFailureCount,
    String? country,
    bool? manualCompAccess,
    String? billingNote,
    bool clearBillingNote = false,
    String? email,
    bool clearEmail = false,
  }) =>
      SubscriptionRow(
        userId: userId,
        email: clearEmail ? null : (email ?? this.email),
        plan: plan ?? this.plan,
        billingStatus: billingStatus ?? this.billingStatus,
        provider: provider ?? this.provider,
        subscriptionStart: subscriptionStart ?? this.subscriptionStart,
        renewalDate: clearRenewalDate ? null : (renewalDate ?? this.renewalDate),
        cancelledDate: clearCancelledDate ? null : (cancelledDate ?? this.cancelledDate),
        paymentFailureCount: paymentFailureCount ?? this.paymentFailureCount,
        country: country ?? this.country,
        manualCompAccess: manualCompAccess ?? this.manualCompAccess,
        billingNote: clearBillingNote ? null : (billingNote ?? this.billingNote),
      );
}

@immutable
class TrialRow {
  const TrialRow({
    required this.userId,
    required this.plan,
    required this.trialStart,
    required this.trialEnd,
    required this.usageLevel,
    required this.upgradePromptClicked,
    required this.converted,
  });

  final String userId;
  final String plan;
  final DateTime trialStart;
  final DateTime trialEnd;
  /// e.g. "Low" / "Medium" / "High"
  final String usageLevel;
  final bool upgradePromptClicked;
  final bool converted;

  int get daysRemaining {
    final now = DateTime.now();
    final diff = trialEnd.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays;
  }
}

@immutable
class FailedPaymentRow {
  const FailedPaymentRow({
    required this.userId,
    this.email,
    required this.plan,
    required this.provider,
    required this.failureDate,
    required this.failureCount,
    required this.billingStatus,
    required this.accountRestrictionStatus,
  });

  final String userId;
  final String? email;
  final String plan;
  final BillingSubscriptionProvider provider;
  final DateTime failureDate;
  final int failureCount;
  final String billingStatus;
  final String accountRestrictionStatus;
}

@immutable
class RevenueByPlanRow {
  const RevenueByPlanRow({required this.plan, required this.users, required this.mrrUsd, required this.arrUsd, required this.churnRate});

  final String plan;
  final int users;
  final double mrrUsd;
  final double arrUsd;
  /// Range [0..1]
  final double churnRate;
}

@immutable
class RevenueByCountryRow {
  const RevenueByCountryRow({required this.country, required this.users, required this.mrrUsd, required this.arrUsd});

  final String country;
  final int users;
  final double mrrUsd;
  final double arrUsd;
}

@immutable
class BillingSnapshot {
  const BillingSnapshot({
    required this.query,
    required this.overview,
    required this.subscriptions,
    required this.trials,
    required this.failedPayments,
    required this.revenueByPlan,
    required this.revenueByCountry,
    required this.generatedAt,
  });

  final BillingQuery query;
  final BillingOverviewMetrics overview;
  final List<SubscriptionRow> subscriptions;
  final List<TrialRow> trials;
  final List<FailedPaymentRow> failedPayments;
  final List<RevenueByPlanRow> revenueByPlan;
  final List<RevenueByCountryRow> revenueByCountry;
  final DateTime generatedAt;
}

// ------------------------------
// AI usage models (privacy-safe)
// ------------------------------

/// AI feature areas exposed to the consumer app.
///
/// NOTE: These labels must not imply any user content. They are category names
/// only.
enum AiFeatureArea {
  aiAssistant,
  documentSummary,
  timelineSummary,
  searchHelper,
  appointmentHelper,
  healthOrganisationHelper,
  exportHelper,
}

extension AiFeatureAreaX on AiFeatureArea {
  String get label => switch (this) {
    AiFeatureArea.aiAssistant => 'AI assistant',
    AiFeatureArea.documentSummary => 'Document summary',
    AiFeatureArea.timelineSummary => 'Timeline summary',
    AiFeatureArea.searchHelper => 'Search helper',
    AiFeatureArea.appointmentHelper => 'Appointment helper',
    AiFeatureArea.healthOrganisationHelper => 'Health organisation helper',
    AiFeatureArea.exportHelper => 'Export helper',
  };

  String get key => switch (this) {
    AiFeatureArea.aiAssistant => 'ai_assistant',
    AiFeatureArea.documentSummary => 'document_summary',
    AiFeatureArea.timelineSummary => 'timeline_summary',
    AiFeatureArea.searchHelper => 'search_helper',
    AiFeatureArea.appointmentHelper => 'appointment_helper',
    AiFeatureArea.healthOrganisationHelper => 'health_organisation_helper',
    AiFeatureArea.exportHelper => 'export_helper',
  };
}

@immutable
class AiUsageQuery {
  const AiUsageQuery({required this.range, this.country, this.platform, this.plan, this.appVersion});

  final AdminDateRangePreset range;
  final String? country;
  final String? platform;
  final String? plan;
  final String? appVersion;

  AiUsageQuery copyWith({
    AdminDateRangePreset? range,
    String? country,
    bool clearCountry = false,
    String? platform,
    bool clearPlatform = false,
    String? plan,
    bool clearPlan = false,
    String? appVersion,
    bool clearAppVersion = false,
  }) =>
      AiUsageQuery(
        range: range ?? this.range,
        country: clearCountry ? null : (country ?? this.country),
        platform: clearPlatform ? null : (platform ?? this.platform),
        plan: clearPlan ? null : (plan ?? this.plan),
        appVersion: clearAppVersion ? null : (appVersion ?? this.appVersion),
      );
}

@immutable
class AiTokensTimeseriesPoint {
  const AiTokensTimeseriesPoint({required this.day, required this.inputTokens, required this.outputTokens});

  final DateTime day;
  final int inputTokens;
  final int outputTokens;
  int get totalTokens => inputTokens + outputTokens;
}

@immutable
class AiCostTimeseriesPoint {
  const AiCostTimeseriesPoint({required this.day, required this.estimatedCostUsd});
  final DateTime day;
  final double estimatedCostUsd;
}

@immutable
class AiHighCostUserRow {
  const AiHighCostUserRow({
    required this.userId,
    required this.plan,
    required this.estimatedCostUsd,
    required this.totalTokens,
    required this.aiRequests,
    required this.lastAiRequestAt,
    this.email,
  });

  final String userId;
  final String? email; // RBAC-gated
  final String plan;
  final double estimatedCostUsd;
  final int totalTokens;
  final int aiRequests;
  final DateTime? lastAiRequestAt;
}

@immutable
class AiLimitMonitoringRow {
  const AiLimitMonitoringRow({
    required this.userId,
    required this.plan,
    required this.monthlyTokenLimit,
    required this.tokensUsed,
    required this.aiRequests,
    required this.limitReachedCount,
    required this.lastAiRequestAt,
    this.email,
  });

  final String userId;
  final String? email; // RBAC-gated
  final String plan;
  final int monthlyTokenLimit;
  final int tokensUsed;
  final int aiRequests;
  final int limitReachedCount;
  final DateTime? lastAiRequestAt;

  int get remainingTokens => (monthlyTokenLimit - tokensUsed).clamp(0, monthlyTokenLimit).toInt();
}

@immutable
class AiErrorRow {
  const AiErrorRow({
    required this.occurredAt,
    required this.userPseudonym,
    required this.featureArea,
    required this.model,
    required this.errorCode,
    required this.result,
    required this.platform,
    required this.appVersion,
  });

  final DateTime occurredAt;
  final String userPseudonym;
  final AiFeatureArea featureArea;
  final String model;
  final String errorCode;
  final String result;
  final String platform;
  final String appVersion;
}

@immutable
class AiFeatureUsageRow {
  const AiFeatureUsageRow({
    required this.featureArea,
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
    required this.failedRequests,
    required this.estimatedCostUsd,
  });

  final AiFeatureArea featureArea;
  final int requests;
  final int inputTokens;
  final int outputTokens;
  final int failedRequests;
  final double estimatedCostUsd;

  int get totalTokens => inputTokens + outputTokens;
  double get failRate => requests <= 0 ? 0 : (failedRequests / requests);
}

@immutable
class AiUsageSnapshot {
  const AiUsageSnapshot({
    required this.query,
    required this.aiRequestsThisMonth,
    required this.inputTokensThisMonth,
    required this.outputTokensThisMonth,
    required this.estimatedCostThisMonthUsd,
    required this.failedAiRequestsThisMonth,
    required this.usersNearAiLimit,
    required this.usersOverAiLimit,
    required this.tokensByDay,
    required this.tokensByFeature,
    required this.tokensByPlan,
    required this.tokensByPlatform,
    required this.tokensByCountry,
    required this.dailyCost,
    required this.estimatedDailyCostUsd,
    required this.estimatedMonthlyCostUsd,
    required this.costByPlan,
    required this.costByFeature,
    required this.costPerActiveUserUsd,
    required this.highCostUsers,
    required this.limitMonitoring,
    required this.aiErrors,
    required this.usageByFeature,
    required this.generatedAt,
  });

  final AiUsageQuery query;

  // Overview cards
  final int aiRequestsThisMonth;
  final int inputTokensThisMonth;
  final int outputTokensThisMonth;
  int get totalTokensThisMonth => inputTokensThisMonth + outputTokensThisMonth;
  final double estimatedCostThisMonthUsd;
  double get avgTokensPerRequest => aiRequestsThisMonth <= 0 ? 0 : (totalTokensThisMonth / aiRequestsThisMonth);
  final int failedAiRequestsThisMonth;
  final int usersNearAiLimit;
  final int usersOverAiLimit;

  // Token usage
  final List<AiTokensTimeseriesPoint> tokensByDay;
  final Map<AiFeatureArea, int> tokensByFeature;
  final Map<String, int> tokensByPlan;
  final Map<String, int> tokensByPlatform;
  final Map<String, int> tokensByCountry;

  // Cost monitoring
  final List<AiCostTimeseriesPoint> dailyCost;
  final double estimatedDailyCostUsd;
  final double estimatedMonthlyCostUsd;
  final Map<String, double> costByPlan;
  final Map<AiFeatureArea, double> costByFeature;
  final double costPerActiveUserUsd;
  final List<AiHighCostUserRow> highCostUsers;

  // Limit monitoring
  final List<AiLimitMonitoringRow> limitMonitoring;

  // Errors
  final List<AiErrorRow> aiErrors;

  // Usage by feature
  final List<AiFeatureUsageRow> usageByFeature;

  final DateTime generatedAt;
}

// ------------------------------
// Usage analytics models
// ------------------------------

@immutable
class UsageAnalyticsQuery {
  const UsageAnalyticsQuery({
    required this.range,
    this.country,
    this.platform,
    this.plan,
    this.appVersion,
  });

  final AdminDateRangePreset range;
  final String? country;
  final String? platform;
  final String? plan;
  final String? appVersion;

  UsageAnalyticsQuery copyWith({
    AdminDateRangePreset? range,
    String? country,
    bool clearCountry = false,
    String? platform,
    bool clearPlatform = false,
    String? plan,
    bool clearPlan = false,
    String? appVersion,
    bool clearAppVersion = false,
  }) =>
      UsageAnalyticsQuery(
        range: range ?? this.range,
        country: clearCountry ? null : (country ?? this.country),
        platform: clearPlatform ? null : (platform ?? this.platform),
        plan: clearPlan ? null : (plan ?? this.plan),
        appVersion: clearAppVersion ? null : (appVersion ?? this.appVersion),
      );
}

@immutable
class UsageFeatureUsageRow {
  const UsageFeatureUsageRow({required this.feature, required this.eventCount, required this.uniqueUsers});
  final String feature;
  final int eventCount;
  final int uniqueUsers;
}

@immutable
class UsageScreenUsageRow {
  const UsageScreenUsageRow({
    required this.screenName,
    required this.views,
    required this.uniqueUsers,
    required this.avgDurationSeconds,
    required this.exitRate,
    required this.errorCount,
  });

  final String screenName;
  final int views;
  final int uniqueUsers;
  final int avgDurationSeconds;
  final double exitRate; // 0..1
  final int errorCount;
}

@immutable
class UsageFunnelStep {
  const UsageFunnelStep({required this.label, required this.count});
  final String label;
  final int count;
}

@immutable
class UsageFunnel {
  const UsageFunnel({required this.name, required this.steps});
  final String name;
  final List<UsageFunnelStep> steps;
}

@immutable
class UsageRetentionSnapshot {
  const UsageRetentionSnapshot({
    required this.day1,
    required this.day7,
    required this.day30,
    required this.weeklyRetention,
  });

  final double day1; // 0..1
  final double day7; // 0..1
  final double day30; // 0..1
  final double weeklyRetention; // 0..1
}

@immutable
class UsageOverviewConversions {
  const UsageOverviewConversions({
    required this.signupToFirstProfile,
    required this.firstProfileToFirstUpload,
    required this.firstUploadToRecurring,
    required this.upgradePromptViews,
    required this.upgradeClicks,
  });

  final double signupToFirstProfile; // 0..1
  final double firstProfileToFirstUpload; // 0..1
  final double firstUploadToRecurring; // 0..1
  final int upgradePromptViews;
  final int upgradeClicks;
}

@immutable
class UsageAnalyticsSnapshot {
  const UsageAnalyticsSnapshot({
    required this.query,
    required this.totalEvents,
    required this.activeUsers,
    required this.sessions,
    required this.avgSessionDurationSeconds,
    required this.featureUsageByCategory,
    required this.conversions,
    required this.featureUsage,
    required this.screenUsage,
    required this.funnels,
    required this.retention,
    required this.countryUsage,
    required this.platformUsage,
    required this.generatedAt,
  });

  final UsageAnalyticsQuery query;

  // Overview metrics
  final int totalEvents;
  final int activeUsers;
  final int sessions;
  final int avgSessionDurationSeconds;
  final Map<String, int> featureUsageByCategory;
  final UsageOverviewConversions conversions;

  // Tab datasets
  final List<UsageFeatureUsageRow> featureUsage;
  final List<UsageScreenUsageRow> screenUsage;
  final List<UsageFunnel> funnels;
  final UsageRetentionSnapshot retention;
  final List<CountryUsageRow> countryUsage;
  final Map<String, int> platformUsage;

  final DateTime generatedAt;
}

// ------------------------------
// Plans & permissions models
// ------------------------------

enum FeatureFlagKey {
  aiAssistant,
  documentUploads,
  export,
  timeline,
  bodyMap,
  familyProfiles,
  preventativeCare,
  betaFeatures,
}

extension FeatureFlagKeyX on FeatureFlagKey {
  String get label => switch (this) {
    FeatureFlagKey.aiAssistant => 'AI assistant',
    FeatureFlagKey.documentUploads => 'Document uploads',
    FeatureFlagKey.export => 'Export',
    FeatureFlagKey.timeline => 'Timeline',
    FeatureFlagKey.bodyMap => 'Body map',
    FeatureFlagKey.familyProfiles => 'Family profiles',
    FeatureFlagKey.preventativeCare => 'Preventative care',
    FeatureFlagKey.betaFeatures => 'Beta features',
  };

  String get apiKey => switch (this) {
    FeatureFlagKey.aiAssistant => 'ai_assistant',
    FeatureFlagKey.documentUploads => 'document_uploads',
    FeatureFlagKey.export => 'export',
    FeatureFlagKey.timeline => 'timeline',
    FeatureFlagKey.bodyMap => 'body_map',
    FeatureFlagKey.familyProfiles => 'family_profiles',
    FeatureFlagKey.preventativeCare => 'preventative_care',
    FeatureFlagKey.betaFeatures => 'beta_features',
  };
}

@immutable
class PlanOverviewRow {
  const PlanOverviewRow({
    required this.planName,
    required this.monthlyPriceUsd,
    required this.storageLimitBytes,
    required this.aiTokenLimitMonthly,
    required this.profileLimit,
    required this.uploadLimit,
    required this.exportAccess,
    required this.aiAccess,
    required this.activeUsers,
    required this.trialUsers,
    required this.paidUsers,
    required this.cancelledUsers,
  });

  final String planName;
  final double monthlyPriceUsd;
  final int storageLimitBytes;
  final int aiTokenLimitMonthly;
  final int profileLimit;
  final int? uploadLimit;
  final bool exportAccess;
  final bool aiAccess;
  final int activeUsers;
  final int trialUsers;
  final int paidUsers;
  final int cancelledUsers;
}

@immutable
class FeatureFlagDefinition {
  const FeatureFlagDefinition({
    required this.key,
    required this.enabled,
    required this.description,
    required this.updatedAt,
  });

  final FeatureFlagKey key;
  final bool enabled;
  final String description;
  final DateTime updatedAt;

  FeatureFlagDefinition copyWith({bool? enabled, String? description, DateTime? updatedAt}) => FeatureFlagDefinition(
    key: key,
    enabled: enabled ?? this.enabled,
    description: description ?? this.description,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

@immutable
class UserEntitlements {
  const UserEntitlements({
    required this.userId,
    required this.currentPlan,
    required this.billingStatus,
    required this.subscriptionProvider,
    required this.trialStart,
    required this.trialEnd,
    required this.storageLimitBytes,
    required this.aiTokenLimitMonthly,
    required this.profileLimit,
    required this.uploadLimit,
    required this.featureFlags,
    required this.updatedAt,
  });

  final String userId;
  final String currentPlan;
  final String billingStatus;
  final String subscriptionProvider;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final int storageLimitBytes;
  final int aiTokenLimitMonthly;
  final int profileLimit;
  final int? uploadLimit;
  final Map<FeatureFlagKey, bool> featureFlags;
  final DateTime updatedAt;

  UserEntitlements copyWith({
    String? currentPlan,
    String? billingStatus,
    String? subscriptionProvider,
    DateTime? trialStart,
    bool clearTrialStart = false,
    DateTime? trialEnd,
    bool clearTrialEnd = false,
    int? storageLimitBytes,
    int? aiTokenLimitMonthly,
    int? profileLimit,
    int? uploadLimit,
    bool clearUploadLimit = false,
    Map<FeatureFlagKey, bool>? featureFlags,
    DateTime? updatedAt,
  }) =>
      UserEntitlements(
        userId: userId,
        currentPlan: currentPlan ?? this.currentPlan,
        billingStatus: billingStatus ?? this.billingStatus,
        subscriptionProvider: subscriptionProvider ?? this.subscriptionProvider,
        trialStart: clearTrialStart ? null : (trialStart ?? this.trialStart),
        trialEnd: clearTrialEnd ? null : (trialEnd ?? this.trialEnd),
        storageLimitBytes: storageLimitBytes ?? this.storageLimitBytes,
        aiTokenLimitMonthly: aiTokenLimitMonthly ?? this.aiTokenLimitMonthly,
        profileLimit: profileLimit ?? this.profileLimit,
        uploadLimit: clearUploadLimit ? null : (uploadLimit ?? this.uploadLimit),
        featureFlags: featureFlags ?? this.featureFlags,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

@immutable
class LimitOverrideRow {
  const LimitOverrideRow({
    required this.overrideId,
    required this.userId,
    required this.planName,
    required this.limitKey,
    required this.previousValue,
    required this.newValue,
    required this.reason,
    required this.ticketReference,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  final String overrideId;
  final String userId;
  final String planName;
  final String limitKey; // storage_limit_bytes, ai_token_limit_monthly, etc
  final String previousValue;
  final String newValue;
  final String reason;
  final String? ticketReference;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
}

@immutable
class DashboardQuery {
  const DashboardQuery({
    required this.range,
    this.country,
    this.platform,
    this.plan,
  });

  final AdminDateRangePreset range;
  final String? country; // e.g. 'US'
  final String? platform; // iOS/Android/Web
  final String? plan; // Free/Trial/Paid/Cancelled/etc

  DashboardQuery copyWith({AdminDateRangePreset? range, String? country, bool clearCountry = false, String? platform, bool clearPlatform = false, String? plan, bool clearPlan = false}) =>
      DashboardQuery(
        range: range ?? this.range,
        country: clearCountry ? null : (country ?? this.country),
        platform: clearPlatform ? null : (platform ?? this.platform),
        plan: clearPlan ? null : (plan ?? this.plan),
      );
}

@immutable
class DashboardTimeseriesPoint {
  const DashboardTimeseriesPoint({required this.date, required this.value});
  final DateTime date;
  final int value;
}

@immutable
class CountryUsageRow {
  const CountryUsageRow({
    required this.country,
    required this.totalUsers,
    required this.activeUsers,
    required this.storageUsedBytes,
    required this.aiTokensUsed,
    required this.paidUsers,
  });

  final String country;
  final int totalUsers;
  final int activeUsers;
  final int storageUsedBytes;
  final int aiTokensUsed;
  final int paidUsers;
}

@immutable
class AlertRow {
  const AlertRow({required this.type, required this.count, required this.severity, required this.note});

  final String type;
  final int count;
  final String severity; // low/medium/high
  final String note;
}

@immutable
class SystemStatusCard {
  const SystemStatusCard({required this.label, required this.status, required this.detail, required this.updatedAt});

  final String label;
  final String status; // OK/Warn/Down
  final String detail;
  final DateTime updatedAt;
}

@immutable
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.query,
    required this.totalRegisteredUsers,
    required this.newUsersThisWeek,
    required this.newUsersThisMonth,
    required this.dailyActiveUsers,
    required this.weeklyActiveUsers,
    required this.monthlyActiveUsers,
    required this.userGrowth,
    required this.totalStorageUsedBytes,
    required this.averageStoragePerUserBytes,
    required this.usersNearStorageLimit,
    required this.aiTokensUsedThisMonth,
    required this.aiEstimatedCostThisMonthUsd,
    required this.usersNearAiLimit,
    required this.freeUsers,
    required this.trialUsers,
    required this.paidUsers,
    required this.cancelledUsers,
    required this.failedPayments,
    required this.countryUsage,
    required this.platformUsage,
    required this.featureUsage,
    required this.alerts,
    required this.systemStatus,
    required this.generatedAt,
  });

  final DashboardQuery query;

  // User growth cards
  final int totalRegisteredUsers;
  final int newUsersThisWeek;
  final int newUsersThisMonth;
  final int dailyActiveUsers;
  final int weeklyActiveUsers;
  final int monthlyActiveUsers;
  final List<DashboardTimeseriesPoint> userGrowth;

  // Usage cards
  final int totalStorageUsedBytes;
  final int averageStoragePerUserBytes;
  final int usersNearStorageLimit;
  final int aiTokensUsedThisMonth;
  final double aiEstimatedCostThisMonthUsd;
  final int usersNearAiLimit;

  // Plans
  final int freeUsers;
  final int trialUsers;
  final int paidUsers;
  final int cancelledUsers;
  final int failedPayments;

  // Tables/charts
  final List<CountryUsageRow> countryUsage;
  final Map<String, int> platformUsage; // iOS/Android/Web
  final Map<String, int> featureUsage;

  // Alerts
  final List<AlertRow> alerts;

  // System
  final List<SystemStatusCard> systemStatus;

  final DateTime generatedAt;
}

// ------------------------------
// Storage models (privacy-safe)
// ------------------------------

@immutable
class StorageQuery {
  const StorageQuery({required this.range});

  final AdminDateRangePreset range;

  StorageQuery copyWith({AdminDateRangePreset? range}) => StorageQuery(range: range ?? this.range);
}

@immutable
class StorageHighUsageUserRow {
  const StorageHighUsageUserRow({
    required this.userId,
    required this.country,
    required this.plan,
    required this.storageUsedBytes,
    required this.storageLimitBytes,
    required this.documentCount,
    required this.lastUploadAt,
    required this.failedUploadCount,
    required this.accountStatus,
    this.email,
  });

  final String userId;
  final String? email; // only for authorized roles
  final String country;
  final String plan;
  final int storageUsedBytes;
  final int storageLimitBytes;
  final int documentCount;
  final DateTime? lastUploadAt;
  final int failedUploadCount;
  final String accountStatus;

  double get percentUsed => storageLimitBytes <= 0 ? 0 : (storageUsedBytes / storageLimitBytes);
}

@immutable
class StorageByPlanRow {
  const StorageByPlanRow({
    required this.plan,
    required this.users,
    required this.totalStorageBytes,
    required this.avgStoragePerUserBytes,
    required this.usersNearLimit,
    required this.usersOverLimit,
  });

  final String plan;
  final int users;
  final int totalStorageBytes;
  final int avgStoragePerUserBytes;
  final int usersNearLimit;
  final int usersOverLimit;
}

@immutable
class StorageByCountryRow {
  const StorageByCountryRow({
    required this.country,
    required this.users,
    required this.totalStorageBytes,
    required this.avgStorageBytes,
    required this.documentCount,
    required this.paidUsers,
  });

  final String country;
  final int users;
  final int totalStorageBytes;
  final int avgStorageBytes;
  final int documentCount;
  final int paidUsers;
}

@immutable
class StorageUploadErrorRow {
  const StorageUploadErrorRow({
    required this.occurredAt,
    required this.userPseudonym,
    required this.platform,
    required this.appVersion,
    required this.errorCode,
    required this.result,
    required this.fileSizeBucket,
    required this.storageUsedBytesAtTime,
  });

  final DateTime occurredAt;
  final String userPseudonym; // never raw user id
  final String platform;
  final String appVersion;
  final String errorCode;
  final String result;
  final String fileSizeBucket; // e.g. '<1MB', '1–10MB', '10–50MB', '50–200MB', '>200MB'
  final int storageUsedBytesAtTime;
}

@immutable
class StorageSnapshot {
  const StorageSnapshot({
    required this.query,
    required this.totalStorageUsedBytes,
    required this.totalDocumentCount,
    required this.averageStoragePerUserBytes,
    required this.usersOverStorageLimit,
    required this.usersOver80PercentStorageLimit,
    required this.uploadsThisMonth,
    required this.failedUploadsThisMonth,
    required this.estimatedStorageCostUsd,
    required this.highUsageUsers,
    required this.storageByPlan,
    required this.storageByCountry,
    required this.uploadErrors,
    required this.generatedAt,
  });

  final StorageQuery query;
  final int totalStorageUsedBytes;
  final int totalDocumentCount;
  final int averageStoragePerUserBytes;
  final int usersOverStorageLimit;
  final int usersOver80PercentStorageLimit;
  final int uploadsThisMonth;
  final int failedUploadsThisMonth;
  final double estimatedStorageCostUsd;
  final List<StorageHighUsageUserRow> highUsageUsers;
  final List<StorageByPlanRow> storageByPlan;
  final List<StorageByCountryRow> storageByCountry;
  final List<StorageUploadErrorRow> uploadErrors;
  final DateTime generatedAt;
}

@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    required this.isActive,
    required this.requireStepUp,
    required this.createdAt,
    required this.updatedAt,
    this.themePreference,
  });

  final String id;
  final String email;
  final String? displayName;
  final AdminRole role;
  final bool isActive;
  final bool requireStepUp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? themePreference;

  AdminUser copyWith({
    String? id,
    String? email,
    String? displayName,
    AdminRole? role,
    bool? isActive,
    bool? requireStepUp,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? themePreference,
  }) => AdminUser(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    isActive: isActive ?? this.isActive,
    requireStepUp: requireStepUp ?? this.requireStepUp,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    themePreference: themePreference ?? this.themePreference,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    if (displayName != null) 'display_name': displayName,
    'role': role.name,
    'is_active': isActive,
    'require_step_up': requireStepUp,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (themePreference != null) 'theme_preference': themePreference,
  };

  static AdminUser fromJson(Map<String, dynamic> json) => AdminUser(
    id: (json['id'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    displayName: (json['display_name'] as String?)?.trim().isEmpty == true ? null : (json['display_name'] as String?),
    role: parseAdminRole((json['role'] ?? '').toString()) ?? AdminRole.readOnly,
    isActive: json['is_active'] == true,
    requireStepUp: json['require_step_up'] == true,
    createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
    updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
    themePreference: (json['theme_preference'] ?? json['theme_mode'])?.toString(),
  );
}

@immutable
class UserAccountSummary {
  const UserAccountSummary({
    required this.userId,
    required this.country,
    required this.plan,
    required this.accountStatus,
    required this.storageUsedBytes,
    required this.storageLimitBytes,
    required this.aiTokensThisMonth,
    required this.aiTokenLimitThisMonth,
    required this.profileCount,
    required this.recordCount,
    required this.documentCount,
    required this.appointmentCount,
    required this.medicationCount,
    required this.vaccinationCount,
    required this.lastSyncAt,
    required this.lastActiveAt,
    required this.platform,
    required this.appVersion,
    required this.failedSyncCount7d,
    required this.failedUploadCount7d,
    required this.lastKnownErrorCode,
    required this.billingStatus,
    required this.subscriptionProvider,
    this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String? email; // only for authorized roles
  final String country;
  final String plan;
  final String accountStatus;
  final int storageUsedBytes;
  final int storageLimitBytes;
  final int aiTokensThisMonth;
  final int aiTokenLimitThisMonth;
  final int profileCount;
  final int recordCount;
  final int documentCount;
  final int appointmentCount;
  final int medicationCount;
  final int vaccinationCount;
  final DateTime? lastSyncAt;
  final DateTime? lastActiveAt;
  final String platform;
  final String appVersion;
  final int failedSyncCount7d;
  final int failedUploadCount7d;
  final String? lastKnownErrorCode;
  final String billingStatus; // active/past_due/canceled/etc
  final String subscriptionProvider; // stripe/apple/google/none
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAccountSummary copyWith({
    String? userId,
    String? email,
    bool clearEmail = false,
    String? country,
    String? plan,
    String? accountStatus,
    int? storageUsedBytes,
    int? storageLimitBytes,
    int? aiTokensThisMonth,
    int? aiTokenLimitThisMonth,
    int? profileCount,
    int? recordCount,
    int? documentCount,
    int? appointmentCount,
    int? medicationCount,
    int? vaccinationCount,
    DateTime? lastSyncAt,
    DateTime? lastActiveAt,
    String? platform,
    String? appVersion,
    int? failedSyncCount7d,
    int? failedUploadCount7d,
    String? lastKnownErrorCode,
    bool clearLastKnownErrorCode = false,
    String? billingStatus,
    String? subscriptionProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserAccountSummary(
    userId: userId ?? this.userId,
    email: clearEmail ? null : (email ?? this.email),
    country: country ?? this.country,
    plan: plan ?? this.plan,
    accountStatus: accountStatus ?? this.accountStatus,
    storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
    storageLimitBytes: storageLimitBytes ?? this.storageLimitBytes,
    aiTokensThisMonth: aiTokensThisMonth ?? this.aiTokensThisMonth,
    aiTokenLimitThisMonth: aiTokenLimitThisMonth ?? this.aiTokenLimitThisMonth,
    profileCount: profileCount ?? this.profileCount,
    recordCount: recordCount ?? this.recordCount,
    documentCount: documentCount ?? this.documentCount,
    appointmentCount: appointmentCount ?? this.appointmentCount,
    medicationCount: medicationCount ?? this.medicationCount,
    vaccinationCount: vaccinationCount ?? this.vaccinationCount,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    platform: platform ?? this.platform,
    appVersion: appVersion ?? this.appVersion,
    failedSyncCount7d: failedSyncCount7d ?? this.failedSyncCount7d,
    failedUploadCount7d: failedUploadCount7d ?? this.failedUploadCount7d,
    lastKnownErrorCode: clearLastKnownErrorCode ? null : (lastKnownErrorCode ?? this.lastKnownErrorCode),
    billingStatus: billingStatus ?? this.billingStatus,
    subscriptionProvider: subscriptionProvider ?? this.subscriptionProvider,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    if (email != null) 'email': email,
    'country': country,
    'plan': plan,
    'account_status': accountStatus,
    'storage_used_bytes': storageUsedBytes,
    'storage_limit_bytes': storageLimitBytes,
    'ai_tokens_this_month': aiTokensThisMonth,
    'ai_token_limit_this_month': aiTokenLimitThisMonth,
    'profile_count': profileCount,
    'record_count': recordCount,
    'document_count': documentCount,
    'appointment_count': appointmentCount,
    'medication_count': medicationCount,
    'vaccination_count': vaccinationCount,
    'last_sync_at': lastSyncAt?.toIso8601String(),
    'last_active_at': lastActiveAt?.toIso8601String(),
    'platform': platform,
    'app_version': appVersion,
    'failed_sync_count_7d': failedSyncCount7d,
    'failed_upload_count_7d': failedUploadCount7d,
    if (lastKnownErrorCode != null) 'last_known_error_code': lastKnownErrorCode,
    'billing_status': billingStatus,
    'subscription_provider': subscriptionProvider,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static UserAccountSummary fromJson(Map<String, dynamic> json) => UserAccountSummary(
    userId: (json['user_id'] ?? '').toString(),
    email: json['email']?.toString(),
    country: (json['country'] ?? '—').toString(),
    plan: (json['plan'] ?? '—').toString(),
    accountStatus: (json['account_status'] ?? 'unknown').toString(),
    storageUsedBytes: (json['storage_used_bytes'] as num?)?.toInt() ?? 0,
    storageLimitBytes: (json['storage_limit_bytes'] as num?)?.toInt() ?? 0,
    aiTokensThisMonth: (json['ai_tokens_this_month'] as num?)?.toInt() ?? 0,
    aiTokenLimitThisMonth: (json['ai_token_limit_this_month'] as num?)?.toInt() ?? 0,
    profileCount: (json['profile_count'] as num?)?.toInt() ?? 0,
    recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
    documentCount: (json['document_count'] as num?)?.toInt() ?? 0,
    appointmentCount: (json['appointment_count'] as num?)?.toInt() ?? 0,
    medicationCount: (json['medication_count'] as num?)?.toInt() ?? 0,
    vaccinationCount: (json['vaccination_count'] as num?)?.toInt() ?? 0,
    lastSyncAt: DateTime.tryParse((json['last_sync_at'] ?? '').toString()),
    lastActiveAt: DateTime.tryParse((json['last_active_at'] ?? '').toString()),
    platform: (json['platform'] ?? '—').toString(),
    appVersion: (json['app_version'] ?? '—').toString(),
    failedSyncCount7d: (json['failed_sync_count_7d'] as num?)?.toInt() ?? 0,
    failedUploadCount7d: (json['failed_upload_count_7d'] as num?)?.toInt() ?? 0,
    lastKnownErrorCode: json['last_known_error_code']?.toString(),
    billingStatus: (json['billing_status'] ?? 'unknown').toString(),
    subscriptionProvider: (json['subscription_provider'] ?? 'unknown').toString(),
    createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
    updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
  );
}

@immutable
class UserListQuery {
  const UserListQuery({required this.search, required this.filters});

  final String search;
  final UserListFilters filters;

  UserListQuery copyWith({String? search, UserListFilters? filters}) => UserListQuery(search: search ?? this.search, filters: filters ?? this.filters);
}

@immutable
class UserListFilters {
  const UserListFilters({
    this.country,
    this.plan,
    this.accountStatus,
    this.platform,
    this.storageNearLimit,
    this.aiNearLimit,
    this.failedSyncs,
    this.failedUploads,
    this.billingFailed,
    this.createdRange,
    this.lastActiveRange,
  });

  final String? country;
  final String? plan;
  final String? accountStatus;
  final String? platform;
  final bool? storageNearLimit;
  final bool? aiNearLimit;
  final bool? failedSyncs;
  final bool? failedUploads;
  final bool? billingFailed;
  final DateTimeRange? createdRange;
  final DateTimeRange? lastActiveRange;

  UserListFilters copyWith({
    String? country,
    bool clearCountry = false,
    String? plan,
    bool clearPlan = false,
    String? accountStatus,
    bool clearAccountStatus = false,
    String? platform,
    bool clearPlatform = false,
    bool? storageNearLimit,
    bool clearStorageNearLimit = false,
    bool? aiNearLimit,
    bool clearAiNearLimit = false,
    bool? failedSyncs,
    bool clearFailedSyncs = false,
    bool? failedUploads,
    bool clearFailedUploads = false,
    bool? billingFailed,
    bool clearBillingFailed = false,
    DateTimeRange? createdRange,
    bool clearCreatedRange = false,
    DateTimeRange? lastActiveRange,
    bool clearLastActiveRange = false,
  }) => UserListFilters(
    country: clearCountry ? null : (country ?? this.country),
    plan: clearPlan ? null : (plan ?? this.plan),
    accountStatus: clearAccountStatus ? null : (accountStatus ?? this.accountStatus),
    platform: clearPlatform ? null : (platform ?? this.platform),
    storageNearLimit: clearStorageNearLimit ? null : (storageNearLimit ?? this.storageNearLimit),
    aiNearLimit: clearAiNearLimit ? null : (aiNearLimit ?? this.aiNearLimit),
    failedSyncs: clearFailedSyncs ? null : (failedSyncs ?? this.failedSyncs),
    failedUploads: clearFailedUploads ? null : (failedUploads ?? this.failedUploads),
    billingFailed: clearBillingFailed ? null : (billingFailed ?? this.billingFailed),
    createdRange: clearCreatedRange ? null : (createdRange ?? this.createdRange),
    lastActiveRange: clearLastActiveRange ? null : (lastActiveRange ?? this.lastActiveRange),
  );
}

@immutable
class UserAccountDetail {
  const UserAccountDetail({
    required this.userId,
    required this.country,
    required this.createdAt,
    required this.lastLoginAt,
    required this.lastActiveAt,
    required this.accountStatus,
    required this.plan,
    required this.billingStatus,
    required this.subscriptionProvider,
    required this.profileCount,
    required this.recordCount,
    required this.appointmentCount,
    required this.medicationCount,
    required this.vaccinationCount,
    required this.documentCount,
    required this.storageUsedBytes,
    required this.aiTokensUsedThisMonth,
    required this.aiRequestsThisMonth,
    required this.platform,
    required this.appVersion,
    required this.lastSyncAt,
    required this.failedSyncCount30d,
    required this.failedUploadCount30d,
    required this.lastKnownErrorCode,
    required this.deviceType,
    required this.osVersion,
    required this.storageLimitBytes,
    required this.aiTokenLimitThisMonth,
    required this.profileLimit,
    required this.uploadLimit,
    required this.openSupportSessions,
    required this.consentStatus,
    required this.ticketReference,
    required this.supportNotes,
    this.email,
  });

  final String userId;
  final String? email;
  final String country;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final DateTime? lastActiveAt;
  final String accountStatus;
  final String plan;
  final String billingStatus;
  final String subscriptionProvider;

  final int profileCount;
  final int recordCount;
  final int appointmentCount;
  final int medicationCount;
  final int vaccinationCount;
  final int documentCount;
  final int storageUsedBytes;
  final int aiTokensUsedThisMonth;
  final int aiRequestsThisMonth;

  final String platform;
  final String appVersion;
  final DateTime? lastSyncAt;
  final int failedSyncCount30d;
  final int failedUploadCount30d;
  final String? lastKnownErrorCode;
  final String deviceType; // generic only
  final String osVersion; // generic only

  final int storageLimitBytes;
  final int aiTokenLimitThisMonth;
  final int profileLimit;
  final int? uploadLimit;

  final int openSupportSessions;
  final String consentStatus;
  final String? ticketReference;
  final String? supportNotes;
}

@immutable
class AdminActionRequest {
  const AdminActionRequest({
    required this.actorAdminId,
    required this.actorRole,
    required this.userId,
    required this.action,
    required this.reason,
    this.ticketReference,
    this.parameters,
  });

  final String actorAdminId;
  final AdminRole actorRole;
  final String userId;
  final String action;
  final String reason;
  final String? ticketReference;
  final Map<String, dynamic>? parameters;
}

@immutable
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.adminUserId,
    this.targetUserId,
    required this.actionType,
    this.previousValue,
    this.newValue,
    this.reason,
    this.ticketReference,
    this.ipAddress,
    this.userAgent,
    required this.result,
    required this.createdAt,
  });

  final String id;
  final String? targetUserId;
  final String adminUserId;
  final String actionType;
  final Map<String, dynamic>? previousValue;
  final Map<String, dynamic>? newValue;
  final String? reason;
  final String? ticketReference;
  final String? ipAddress;
  final String? userAgent;
  final String result;
  final DateTime createdAt;

  AuditLogEntry copyWith({
    String? id,
    String? targetUserId,
    String? adminUserId,
    String? actionType,
    Map<String, dynamic>? previousValue,
    Map<String, dynamic>? newValue,
    String? reason,
    String? ticketReference,
    String? ipAddress,
    String? userAgent,
    String? result,
    DateTime? createdAt,
  }) => AuditLogEntry(
    id: id ?? this.id,
    adminUserId: adminUserId ?? this.adminUserId,
    targetUserId: targetUserId ?? this.targetUserId,
    actionType: actionType ?? this.actionType,
    previousValue: previousValue ?? this.previousValue,
    newValue: newValue ?? this.newValue,
    reason: reason ?? this.reason,
    ticketReference: ticketReference ?? this.ticketReference,
    ipAddress: ipAddress ?? this.ipAddress,
    userAgent: userAgent ?? this.userAgent,
    result: result ?? this.result,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'admin_user_id': adminUserId,
    'target_user_id': targetUserId,
    'action_type': actionType,
    'prev': previousValue,
    'next': newValue,
    'reason': reason,
    'ticket_id': ticketReference,
    'ip': ipAddress,
    'user_agent': userAgent,
    'result': result,
    'created_at': createdAt.toIso8601String(),
  };

  static AuditLogEntry fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id: (json['id'] ?? '').toString(),
    adminUserId: (json['admin_user_id'] ?? '').toString(),
    targetUserId: json['target_user_id']?.toString(),
    actionType: (json['action_type'] ?? '').toString(),
    previousValue: ((json['prev'] ?? json['previous_value']) as Map?)?.cast<String, dynamic>(),
    newValue: ((json['next'] ?? json['new_value']) as Map?)?.cast<String, dynamic>(),
    reason: json['reason']?.toString(),
    ticketReference: (json['ticket_id'] ?? json['ticket_reference'])?.toString(),
    ipAddress: (json['ip'] ?? json['ip_address'])?.toString(),
    userAgent: json['user_agent']?.toString(),
    result: (json['result'] ?? '').toString(),
    createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal(),
  );
}

@immutable
class AuditLogQuery {
  const AuditLogQuery({this.adminUserId, this.targetUserId, this.actionType, this.result, this.createdRange});
  final String? adminUserId;
  final String? targetUserId;
  final String? actionType;
  final String? result;
  final DateTimeRange? createdRange;

  AuditLogQuery copyWith({
    String? adminUserId,
    bool clearAdminUserId = false,
    String? targetUserId,
    bool clearTargetUserId = false,
    String? actionType,
    bool clearActionType = false,
    String? result,
    bool clearResult = false,
    DateTimeRange? createdRange,
    bool clearCreatedRange = false,
  }) =>
      AuditLogQuery(
        adminUserId: clearAdminUserId ? null : (adminUserId ?? this.adminUserId),
        targetUserId: clearTargetUserId ? null : (targetUserId ?? this.targetUserId),
        actionType: clearActionType ? null : (actionType ?? this.actionType),
        result: clearResult ? null : (result ?? this.result),
        createdRange: clearCreatedRange ? null : (createdRange ?? this.createdRange),
      );
}

@immutable
class AdminAuditLogCreate {
  const AdminAuditLogCreate({
    required this.adminUserId,
    this.targetUserId,
    required this.actionType,
    this.previousValue,
    this.newValue,
    this.reason,
    this.ticketReference,
    this.ipAddress,
    this.userAgent,
    required this.result,
  });

  final String adminUserId;
  final String? targetUserId;
  final String actionType;
  final Map<String, dynamic>? previousValue;
  final Map<String, dynamic>? newValue;
  final String? reason;
  final String? ticketReference;
  final String? ipAddress;
  final String? userAgent;
  final String result;

  Map<String, dynamic> toInsertJson() => {
    'admin_user_id': adminUserId,
    if (targetUserId != null) 'target_user_id': targetUserId,
    'action_type': actionType,
    if (previousValue != null) 'prev': previousValue,
    if (newValue != null) 'next': newValue,
    if (reason != null) 'reason': reason,
    if (ticketReference != null) 'ticket_id': ticketReference,
    if (ipAddress != null) 'ip': ipAddress,
    if (userAgent != null) 'user_agent': userAgent,
    'result': result,
  };
}

// ------------------------------
// Security checklist models
// ------------------------------

@immutable
class SecurityChecklistSnapshot {
  const SecurityChecklistSnapshot({
    required this.rlsEnabled,
    required this.adminAuthEnabled,
    required this.auditLoggingEnabled,
    required this.noServiceRoleKeyDetected,
    required this.noRawHealthTableAccessDetected,
    this.lastAdminLoginAt,
    this.lastAuditEventAt,
    required this.activeSupportSessions,
    required this.expiredSupportSessions,
  });

  /// Best-effort signal. If the client cannot verify, this may be `null`.
  final bool? rlsEnabled;

  /// Whether Supabase auth + admin allow-list checks are operational.
  final bool adminAuthEnabled;

  /// Best-effort signal that audit insert is working.
  final bool auditLoggingEnabled;

  /// Client-side static/runtime check (fail closed if detected).
  final bool noServiceRoleKeyDetected;

  /// Static codebase signal (no `.from('<health_table>')` access).
  final bool noRawHealthTableAccessDetected;

  final DateTime? lastAdminLoginAt;
  final DateTime? lastAuditEventAt;

  final int activeSupportSessions;
  final int expiredSupportSessions;
}

// ------------------------------
// Support / diagnostics models
// ------------------------------

enum SupportSessionStatus {
  pending,
  active,
  expired,
  closed,
  revoked,
}

SupportSessionStatus? parseSupportSessionStatus(String? value) {
  switch ((value ?? '').trim()) {
    case 'pending':
      return SupportSessionStatus.pending;
    case 'active':
      return SupportSessionStatus.active;
    case 'expired':
      return SupportSessionStatus.expired;
    case 'closed':
      return SupportSessionStatus.closed;
    case 'revoked':
      return SupportSessionStatus.revoked;
    default:
      return null;
  }
}

extension SupportSessionStatusX on SupportSessionStatus {
  String get label => switch (this) {
    SupportSessionStatus.pending => 'pending',
    SupportSessionStatus.active => 'active',
    SupportSessionStatus.expired => 'expired',
    SupportSessionStatus.closed => 'closed',
    SupportSessionStatus.revoked => 'revoked',
  };
}

@immutable
class SupportQueueQuery {
  const SupportQueueQuery({required this.search, required this.filters});
  final String search;
  final SupportQueueFilters filters;
}

@immutable
class SupportQueueFilters {
  const SupportQueueFilters({
    this.status,
    this.consentStatus,
    this.assignedAdminId,
    this.onlyExpiringSoon,
  });

  final SupportSessionStatus? status;
  final String? consentStatus; // on_file/missing/revoked/etc
  final String? assignedAdminId;
  final bool? onlyExpiringSoon;

  SupportQueueFilters copyWith({
    SupportSessionStatus? status,
    bool clearStatus = false,
    String? consentStatus,
    bool clearConsentStatus = false,
    String? assignedAdminId,
    bool clearAssignedAdminId = false,
    bool? onlyExpiringSoon,
    bool clearOnlyExpiringSoon = false,
  }) =>
      SupportQueueFilters(
        status: clearStatus ? null : (status ?? this.status),
        consentStatus: clearConsentStatus ? null : (consentStatus ?? this.consentStatus),
        assignedAdminId: clearAssignedAdminId ? null : (assignedAdminId ?? this.assignedAdminId),
        onlyExpiringSoon: clearOnlyExpiringSoon ? null : (onlyExpiringSoon ?? this.onlyExpiringSoon),
      );
}

@immutable
class SupportSessionSummary {
  const SupportSessionSummary({
    required this.supportSessionId,
    required this.userId,
    required this.ticketReference,
    required this.consentStatus,
    required this.status,
    required this.assignedAdmin,
    required this.createdAt,
    required this.accessExpiresAt,
    required this.updatedAt,
    this.email,
  });

  final String supportSessionId;
  final String userId;
  final String? email;
  final String? ticketReference;
  final String consentStatus;
  final SupportSessionStatus status;
  final String? assignedAdmin;
  final DateTime createdAt;
  final DateTime? accessExpiresAt;
  final DateTime updatedAt;
}

@immutable
class SupportSummarySnapshot {
  const SupportSummarySnapshot({
    required this.totalSessions,
    required this.openSessions,
    required this.activeSessions,
    required this.closedSessions,
    required this.expiredSessions,
    this.latestSessionAt,
    required this.generatedAt,
  });

  final int totalSessions;
  final int openSessions;
  final int activeSessions;
  final int closedSessions;
  final int expiredSessions;
  final DateTime? latestSessionAt;
  final DateTime generatedAt;
}

@immutable
class AuditSummarySnapshot {
  const AuditSummarySnapshot({
    required this.totalAuditEvents,
    required this.auditEvents24h,
    required this.failedAdminActions24h,
    this.latestAuditEventAt,
    required this.generatedAt,
  });

  final int totalAuditEvents;
  final int auditEvents24h;
  final int failedAdminActions24h;
  final DateTime? latestAuditEventAt;
  final DateTime generatedAt;
}

@immutable
class TechnicalEvent {
  const TechnicalEvent({
    required this.timestamp,
    required this.type,
    required this.message,
    this.code,
    this.metadata,
  });

  final DateTime timestamp;
  final String type; // sync/upload/auth/billing/etc
  final String message;
  final String? code;
  final Map<String, dynamic>? metadata;
}

@immutable
class SupportSessionDetail {
  const SupportSessionDetail({
    required this.supportSessionId,
    required this.userId,
    required this.accountStatus,
    required this.plan,
    required this.appVersion,
    required this.platform,
    required this.country,
    required this.lastLoginAt,
    required this.lastSyncAt,
    required this.failedSyncCount,
    required this.failedUploadCount,
    required this.storageUsedBytes,
    required this.storageLimitBytes,
    required this.aiTokensUsed,
    required this.aiLimit,
    required this.openErrors,
    required this.recentTechnicalEvents,
    required this.adminNotes,
    required this.consentWindowStatus,
    required this.status,
    required this.accessExpiresAt,
    required this.ticketReference,
    required this.updatedAt,
    this.email,
    this.assignedAdmin,
  });

  final String supportSessionId;
  final String userId;
  final String? email;
  final String accountStatus;
  final String plan;
  final String appVersion;
  final String platform;
  final String country;
  final DateTime? lastLoginAt;
  final DateTime? lastSyncAt;
  final int failedSyncCount;
  final int failedUploadCount;
  final int storageUsedBytes;
  final int storageLimitBytes;
  final int aiTokensUsed;
  final int aiLimit;

  final List<String> openErrors;
  final List<TechnicalEvent> recentTechnicalEvents;
  final String? adminNotes;
  final String consentWindowStatus; // active/expired/revoked/missing

  final SupportSessionStatus status;
  final DateTime? accessExpiresAt;
  final String? ticketReference;
  final DateTime updatedAt;
  final String? assignedAdmin;
}

enum DiagnosticStatus {
  pass,
  warning,
  fail,
}

extension DiagnosticStatusX on DiagnosticStatus {
  String get label => switch (this) {
    DiagnosticStatus.pass => 'pass',
    DiagnosticStatus.warning => 'warning',
    DiagnosticStatus.fail => 'fail',
  };
}

@immutable
class DiagnosticCheck {
  const DiagnosticCheck({required this.id, required this.title, required this.status, required this.explanation, required this.suggestedAction});
  final String id;
  final String title;
  final DiagnosticStatus status;
  final String explanation;
  final String suggestedAction;
}

@immutable
class DiagnosticsReport {
  const DiagnosticsReport({required this.userId, required this.generatedAt, required this.checks});
  final String userId;
  final DateTime generatedAt;
  final List<DiagnosticCheck> checks;
}

enum SupportAction {
  resendVerificationEmail,
  forceLogout,
  revokeActiveSessions,
  extendTrial,
  temporarilyIncreaseStorageLimit,
  temporarilyIncreaseAiLimit,
  suspendAccount,
  unsuspendAccount,
  addSupportNote,
  closeSupportSession,
}

extension SupportActionX on SupportAction {
  String get label => switch (this) {
    SupportAction.resendVerificationEmail => 'Resend verification email',
    SupportAction.forceLogout => 'Force logout',
    SupportAction.revokeActiveSessions => 'Revoke active sessions',
    SupportAction.extendTrial => 'Extend trial',
    SupportAction.temporarilyIncreaseStorageLimit => 'Temporarily increase storage limit',
    SupportAction.temporarilyIncreaseAiLimit => 'Temporarily increase AI limit',
    SupportAction.suspendAccount => 'Suspend account',
    SupportAction.unsuspendAccount => 'Unsuspend account',
    SupportAction.addSupportNote => 'Add support note',
    SupportAction.closeSupportSession => 'Close support session',
  };
}

@immutable
class SupportActionRequest {
  const SupportActionRequest({
    required this.actorAdminId,
    required this.actorRole,
    required this.supportSessionId,
    required this.userId,
    required this.action,
    required this.reason,
    this.ticketReference,
    this.parameters,
  });

  final String actorAdminId;
  final AdminRole actorRole;
  final String supportSessionId;
  final String userId;
  final SupportAction action;
  final String reason;
  final String? ticketReference;
  final Map<String, dynamic>? parameters;
}

// ------------------------------
// System health models (privacy-safe)
// ------------------------------

enum ServiceHealthStatus {
  healthy,
  degraded,
  down,
  unknown,
}

extension ServiceHealthStatusX on ServiceHealthStatus {
  String get label => switch (this) {
    ServiceHealthStatus.healthy => 'healthy',
    ServiceHealthStatus.degraded => 'degraded',
    ServiceHealthStatus.down => 'down',
    ServiceHealthStatus.unknown => 'unknown',
  };
}

enum SystemErrorSeverity {
  info,
  warning,
  error,
  critical,
}

extension SystemErrorSeverityX on SystemErrorSeverity {
  String get label => switch (this) {
    SystemErrorSeverity.info => 'info',
    SystemErrorSeverity.warning => 'warning',
    SystemErrorSeverity.error => 'error',
    SystemErrorSeverity.critical => 'critical',
  };
}

@immutable
class SystemHealthQuery {
  const SystemHealthQuery({required this.range});
  final AdminDateRangePreset range;
  SystemHealthQuery copyWith({AdminDateRangePreset? range}) => SystemHealthQuery(range: range ?? this.range);
}

@immutable
class SystemOverviewMetrics {
  const SystemOverviewMetrics({
    required this.apiStatus,
    required this.databaseStatus,
    required this.storageStatus,
    required this.authStatus,
    required this.aiServiceStatus,
    required this.lastSuccessfulScheduledJob,
    required this.errorRateLast24h,
    required this.failedUploadsLast24h,
    required this.failedSyncsLast24h,
  });

  final ServiceHealthStatus apiStatus;
  final ServiceHealthStatus databaseStatus;
  final ServiceHealthStatus storageStatus;
  final ServiceHealthStatus authStatus;
  final ServiceHealthStatus aiServiceStatus;
  final DateTime lastSuccessfulScheduledJob;
  /// Range [0..1]
  final double errorRateLast24h;
  final int failedUploadsLast24h;
  final int failedSyncsLast24h;
}

@immutable
class ApiHealthEndpointRow {
  const ApiHealthEndpointRow({
    required this.endpointName,
    required this.requestCount,
    required this.errorCount,
    required this.avgLatencyMs,
    required this.p95LatencyMs,
    this.lastFailureAt,
    required this.status,
  });

  final String endpointName;
  final int requestCount;
  final int errorCount;
  final int avgLatencyMs;
  final int p95LatencyMs;
  final DateTime? lastFailureAt;
  final ServiceHealthStatus status;
}

@immutable
class SyncHealthMetrics {
  const SyncHealthMetrics({
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.usersWithRepeatedSyncFailure,
    required this.avgSyncDurationMs,
    required this.lastSyncJobStatus,
  });

  final int successfulSyncs;
  final int failedSyncs;
  final int usersWithRepeatedSyncFailure;
  final int avgSyncDurationMs;
  final String lastSyncJobStatus;
}

@immutable
class UploadHealthMetrics {
  const UploadHealthMetrics({
    required this.uploadAttempts,
    required this.uploadSuccessRate,
    required this.uploadFailureRate,
    required this.averageUploadSizeBucket,
    required this.storageErrors,
    required this.permissionErrors,
    required this.timeoutErrors,
  });

  final int uploadAttempts;
  /// Range [0..1]
  final double uploadSuccessRate;
  /// Range [0..1]
  final double uploadFailureRate;
  final String averageUploadSizeBucket;
  final int storageErrors;
  final int permissionErrors;
  final int timeoutErrors;
}

@immutable
class AiServiceHealthMetrics {
  const AiServiceHealthMetrics({
    required this.aiRequests,
    required this.aiSuccessRate,
    required this.aiFailureRate,
    required this.averageLatencyMs,
    required this.errorCodes,
    required this.rateLimitEvents,
  });

  final int aiRequests;
  /// Range [0..1]
  final double aiSuccessRate;
  /// Range [0..1]
  final double aiFailureRate;
  final int averageLatencyMs;
  final Map<String, int> errorCodes;
  final int rateLimitEvents;
}

@immutable
class AppVersionHealthRow {
  const AppVersionHealthRow({
    required this.appVersion,
    required this.platform,
    required this.activeUsers,
    required this.errorRate,
    required this.failedUploads,
    required this.failedSyncs,
    required this.upgradeRecommended,
  });

  final String appVersion;
  final String platform;
  final int activeUsers;
  /// Range [0..1]
  final double errorRate;
  final int failedUploads;
  final int failedSyncs;
  final bool upgradeRecommended;
}

@immutable
class SystemErrorLogRow {
  const SystemErrorLogRow({
    required this.timestamp,
    required this.errorCode,
    required this.featureArea,
    required this.platform,
    required this.appVersion,
    required this.userIdPseudonym,
    required this.result,
    required this.severity,
  });

  final DateTime timestamp;
  final String errorCode;
  final String featureArea;
  final String platform;
  final String appVersion;
  final String userIdPseudonym;
  final String result;
  final SystemErrorSeverity severity;
}

@immutable
class SystemHealthSnapshot {
  const SystemHealthSnapshot({
    required this.query,
    required this.overview,
    required this.apiEndpoints,
    required this.sync,
    required this.upload,
    required this.ai,
    required this.appVersions,
    required this.errorLogs,
    required this.generatedAt,
  });

  final SystemHealthQuery query;
  final SystemOverviewMetrics overview;
  final List<ApiHealthEndpointRow> apiEndpoints;
  final SyncHealthMetrics sync;
  final UploadHealthMetrics upload;
  final AiServiceHealthMetrics ai;
  final List<AppVersionHealthRow> appVersions;
  final List<SystemErrorLogRow> errorLogs;
  final DateTime generatedAt;
}

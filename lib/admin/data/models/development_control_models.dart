enum DevelopmentRiskLevel { low, medium, high, critical }

enum DevelopmentTaskStatus {
  draft,
  ready,
  queued,
  inProgress,
  awaitingCi,
  awaitingReview,
  changesRequested,
  awaitingApproval,
  approved,
  completed,
  blocked,
  failed,
  cancelled,
}

enum DevelopmentExecutionStatus {
  requested,
  policyCheck,
  rejected,
  queued,
  starting,
  running,
  succeeded,
  failed,
  cancelRequested,
  cancelled,
  timedOut,
}

enum DevelopmentExecutionPolicyDecision { allow, deny, manualReviewRequired }

/// Server-derived readiness only; browser code cannot change any gate.
class CodexWorkerReadiness {
  const CodexWorkerReadiness({
    required this.providerEnabled,
    required this.workerHealthy,
    required this.repositoryRevisionFresh,
    required this.liveWorkerGateEnabled,
    required this.canExecute,
  });

  final bool providerEnabled;
  final bool workerHealthy;
  final bool repositoryRevisionFresh;
  final bool liveWorkerGateEnabled;
  final bool canExecute;

  factory CodexWorkerReadiness.fromMap(Map<String, dynamic> map) =>
      CodexWorkerReadiness(
        providerEnabled: map['provider_enabled'] == true,
        workerHealthy: map['worker_healthy'] == true,
        repositoryRevisionFresh: map['repository_revision_fresh'] == true,
        liveWorkerGateEnabled: map['live_worker_gate_enabled'] == true,
        canExecute: map['can_execute'] == true,
      );
}

String _wireName(Enum value) => value.name.replaceAllMapped(
    RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');

T _parseEnum<T extends Enum>(Iterable<T> values, String? raw, T fallback) =>
    values.firstWhere(
      (value) => _wireName(value) == raw,
      orElse: () => fallback,
    );

extension DevelopmentRiskLevelX on DevelopmentRiskLevel {
  String get value => _wireName(this);
  String get label => switch (this) {
        DevelopmentRiskLevel.low => 'Low',
        DevelopmentRiskLevel.medium => 'Medium',
        DevelopmentRiskLevel.high => 'High',
        DevelopmentRiskLevel.critical => 'Critical',
      };
}

extension DevelopmentTaskStatusX on DevelopmentTaskStatus {
  String get value => _wireName(this);
  String get label => value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

extension DevelopmentExecutionStatusX on DevelopmentExecutionStatus {
  String get value => _wireName(this);
  String get label => value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

extension DevelopmentExecutionPolicyDecisionX
    on DevelopmentExecutionPolicyDecision {
  String get value => _wireName(this);
  String get label => value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class DevelopmentTask {
  const DevelopmentTask({
    required this.id,
    required this.taskKey,
    required this.title,
    required this.originalProductRequest,
    required this.executionPrompt,
    required this.taskType,
    required this.repository,
    required this.baseBranch,
    required this.workingBranch,
    required this.riskLevel,
    required this.status,
    required this.priority,
    required this.manualTestingRequired,
    required this.createdAt,
    required this.updatedAt,
    this.githubPrUrl,
    this.githubCommitSha,
    this.blockerSummary,
    this.failureSummary,
  });

  final String id;
  final String taskKey;
  final String title;
  final String originalProductRequest;
  final String? executionPrompt;
  final String taskType;
  final String repository;
  final String baseBranch;
  final String? workingBranch;
  final DevelopmentRiskLevel riskLevel;
  final DevelopmentTaskStatus status;
  final int priority;
  final bool manualTestingRequired;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? githubPrUrl;
  final String? githubCommitSha;
  final String? blockerSummary;
  final String? failureSummary;

  factory DevelopmentTask.fromMap(Map<String, dynamic> map) => DevelopmentTask(
        id: map['id'] as String,
        taskKey: map['task_key'] as String,
        title: map['title'] as String,
        originalProductRequest:
            map['original_product_request'] as String? ?? '',
        executionPrompt: map['execution_prompt'] as String?,
        taskType: map['task_type'] as String? ?? 'other',
        repository: map['repository'] as String? ?? '',
        baseBranch: map['base_branch'] as String? ?? 'main',
        workingBranch: map['working_branch'] as String?,
        riskLevel: _parseEnum(DevelopmentRiskLevel.values,
            map['risk_level'] as String?, DevelopmentRiskLevel.medium),
        status: _parseEnum(DevelopmentTaskStatus.values,
            map['status'] as String?, DevelopmentTaskStatus.draft),
        priority: (map['priority'] as num?)?.toInt() ?? 3,
        manualTestingRequired: map['manual_testing_required'] as bool? ?? true,
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        updatedAt:
            DateTime.tryParse(map['updated_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        githubPrUrl: map['github_pr_url'] as String?,
        githubCommitSha: map['github_commit_sha'] as String?,
        blockerSummary: map['blocker_summary'] as String?,
        failureSummary: map['failure_summary'] as String?,
      );
}

class DevelopmentPromptTemplate {
  const DevelopmentPromptTemplate(
      {required this.id,
      required this.name,
      required this.description,
      required this.category,
      required this.promptTemplate,
      required this.riskLevel,
      required this.isActive,
      required this.version});
  final String id;
  final String name;
  final String? description;
  final String category;
  final String promptTemplate;
  final DevelopmentRiskLevel riskLevel;
  final bool isActive;
  final int version;

  factory DevelopmentPromptTemplate.fromMap(Map<String, dynamic> map) =>
      DevelopmentPromptTemplate(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        category: map['category'] as String? ?? 'general',
        promptTemplate: map['prompt_template'] as String? ?? '',
        riskLevel: _parseEnum(DevelopmentRiskLevel.values,
            map['default_risk_level'] as String?, DevelopmentRiskLevel.medium),
        isActive: map['is_active'] as bool? ?? true,
        version: (map['version'] as num?)?.toInt() ?? 1,
      );
}

class DevelopmentEvidenceItem {
  const DevelopmentEvidenceItem(
      {required this.id,
      required this.kind,
      required this.label,
      required this.summary,
      required this.recordedAt});
  final String id;
  final String kind;
  final String label;
  final String? summary;
  final DateTime recordedAt;
}

/// Safe execution metadata only. Prompts, product requests, credentials, raw
/// output, and command content are intentionally not modelled here.
class DevelopmentExecutionJob {
  const DevelopmentExecutionJob({
    required this.id,
    required this.taskId,
    required this.jobKey,
    required this.provider,
    required this.executorMode,
    required this.status,
    required this.attemptNumber,
    required this.repository,
    required this.baseBranch,
    required this.createdAt,
    required this.updatedAt,
    this.failureCode,
    this.failureSummary,
    this.resultSummary,
    this.resolvedBaseSha,
    this.changedPaths = const [],
    this.protectedPathChanged = false,
    this.testsSummary,
    this.analyzerSummary,
  });

  final String id;
  final String taskId;
  final String jobKey;
  final String provider;
  final String executorMode;
  final DevelopmentExecutionStatus status;
  final int attemptNumber;
  final String repository;
  final String baseBranch;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? failureCode;
  final String? failureSummary;
  final String? resultSummary;
  final String? resolvedBaseSha;
  final List<String> changedPaths;
  final bool protectedPathChanged;
  final String? testsSummary;
  final String? analyzerSummary;

  factory DevelopmentExecutionJob.fromMap(Map<String, dynamic> map) =>
      DevelopmentExecutionJob(
        id: map['id'] as String,
        taskId: map['task_id'] as String,
        jobKey: map['job_key'] as String,
        provider: map['provider'] as String? ?? 'mock',
        executorMode: map['executor_mode'] as String? ?? 'mock',
        status: _parseEnum(DevelopmentExecutionStatus.values,
            map['status'] as String?, DevelopmentExecutionStatus.requested),
        attemptNumber: (map['attempt_number'] as num?)?.toInt() ?? 1,
        repository: map['repository'] as String? ?? '',
        baseBranch: map['base_branch'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            DateTime.tryParse(map['updated_at'] as String? ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
        failureCode: map['failure_code'] as String?,
        failureSummary: map['failure_summary'] as String?,
        resultSummary: map['result_summary'] as String?,
        resolvedBaseSha: map['resolved_base_sha'] as String?,
        changedPaths: (map['changed_paths'] as List?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const [],
        protectedPathChanged: map['protected_path_changed'] as bool? ?? false,
        testsSummary: map['tests_summary'] as String?,
        analyzerSummary: map['analyzer_summary'] as String?,
      );
}

class DevelopmentExecutionEvent {
  const DevelopmentExecutionEvent({
    required this.id,
    required this.eventType,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String eventType;
  final String summary;
  final DateTime createdAt;

  factory DevelopmentExecutionEvent.fromMap(Map<String, dynamic> map) =>
      DevelopmentExecutionEvent(
        id: map['id'] as String,
        eventType: map['event_type'] as String? ?? 'event',
        summary: map['summary'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class DevelopmentExecutionPolicyRecord {
  const DevelopmentExecutionPolicyRecord({
    required this.decision,
    required this.reasons,
    required this.evaluatedAt,
  });

  final DevelopmentExecutionPolicyDecision decision;
  final List<String> reasons;
  final DateTime evaluatedAt;

  factory DevelopmentExecutionPolicyRecord.fromMap(Map<String, dynamic> map) {
    final rawReasons = map['reasons'];
    return DevelopmentExecutionPolicyRecord(
      decision: _parseEnum(DevelopmentExecutionPolicyDecision.values,
          map['decision'] as String?, DevelopmentExecutionPolicyDecision.deny),
      reasons: rawReasons is List
          ? rawReasons.whereType<String>().toList(growable: false)
          : const [],
      evaluatedAt:
          DateTime.tryParse(map['evaluated_at'] as String? ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

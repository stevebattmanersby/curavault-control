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

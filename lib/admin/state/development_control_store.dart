import 'package:curavault_admin/admin/data/models/development_control_models.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An admin-only workflow and mock-execution metadata surface.
/// Browser code has no provider credential, command, GitHub, or deployment path.
class DevelopmentControlStore extends ChangeNotifier {
  List<DevelopmentTask> _tasks = const [];
  List<DevelopmentPromptTemplate> _prompts = const [];
  List<DevelopmentEvidenceItem> _evidence = const [];
  List<DevelopmentExecutionJob> _runs = const [];
  List<DevelopmentExecutionEvent> _selectedRunEvents = const [];
  DevelopmentExecutionPolicyRecord? _selectedRunPolicy;
  bool _loading = false;
  String? _error;

  List<DevelopmentTask> get tasks => _tasks;
  List<DevelopmentPromptTemplate> get prompts => _prompts;
  List<DevelopmentEvidenceItem> get evidence => _evidence;
  List<DevelopmentExecutionJob> get runs => _runs;
  List<DevelopmentExecutionEvent> get selectedRunEvents => _selectedRunEvents;
  DevelopmentExecutionPolicyRecord? get selectedRunPolicy => _selectedRunPolicy;
  bool get loading => _loading;
  String? get error => _error;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> load({bool includePrompts = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final tasks = await _client
          .from('admin_development_tasks')
          .select()
          .order('updated_at', ascending: false);
      _tasks = (tasks as List)
          .map((row) =>
              DevelopmentTask.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (includePrompts) {
        final prompts = await _client
            .from('admin_development_prompt_templates')
            .select()
            .order('name');
        _prompts = (prompts as List)
            .map((row) => DevelopmentPromptTemplate.fromMap(
                Map<String, dynamic>.from(row as Map)))
            .toList();
      }
    } catch (_) {
      _error = 'Development control records could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> createTask({
    required String title,
    required String request,
    String? prompt,
    required String taskType,
    required String repository,
    required String baseBranch,
    required DevelopmentRiskLevel risk,
    required int priority,
    required bool manualTesting,
  }) async {
    await _client.from('admin_development_tasks').insert({
      'title': title.trim(),
      'original_product_request': request.trim(),
      'execution_prompt':
          prompt?.trim().isEmpty ?? true ? null : prompt!.trim(),
      'task_type': taskType,
      'repository': repository.trim(),
      'base_branch': baseBranch.trim(),
      'risk_level': risk.value,
      'priority': priority,
      'manual_testing_required': manualTesting,
    });
    await load();
  }

  Future<void> savePrompt(
      {required String name,
      required String description,
      required String category,
      required String prompt,
      required DevelopmentRiskLevel risk}) async {
    await _client.from('admin_development_prompt_templates').insert({
      'name': name.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'category': category.trim(),
      'prompt_template': prompt.trim(),
      'default_risk_level': risk.value,
    });
    await load(includePrompts: true);
  }

  Future<void> archivePrompt(DevelopmentPromptTemplate prompt) async {
    await _client
        .from('admin_development_prompt_templates')
        .update({'is_active': false}).eq('id', prompt.id);
    await load(includePrompts: true);
  }

  /// This deliberately queries evidence tables, never task requests/prompts.
  Future<void> loadEvidence() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('admin_development_task_events')
            .select('id,event_type,summary,created_at')
            .order('created_at', ascending: false)
            .limit(100),
        _client
            .from('admin_development_reviews')
            .select('id,review_type,summary,created_at')
            .order('created_at', ascending: false)
            .limit(100),
        _client
            .from('admin_development_checks')
            .select('id,name,summary,recorded_at')
            .order('recorded_at', ascending: false)
            .limit(100),
        _client
            .from('admin_releases')
            .select('id,release_name,notes,created_at')
            .order('created_at', ascending: false)
            .limit(100),
      ]);
      DateTime at(Map<String, dynamic> row, String field) =>
          DateTime.tryParse(row[field] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      List<DevelopmentEvidenceItem> rows(List raw, String kind,
              String labelField, String timeField, String summaryField) =>
          raw.map((item) {
            final row = Map<String, dynamic>.from(item as Map);
            return DevelopmentEvidenceItem(
                id: row['id'] as String,
                kind: kind,
                label: row[labelField] as String? ?? kind,
                summary: row[summaryField] as String?,
                recordedAt: at(row, timeField));
          }).toList();
      _evidence = [
        ...rows(
            results[0] as List, 'Event', 'event_type', 'created_at', 'summary'),
        ...rows(results[1] as List, 'Review', 'review_type', 'created_at',
            'summary'),
        ...rows(results[2] as List, 'Check', 'name', 'recorded_at', 'summary'),
        ...rows(results[3] as List, 'Release', 'release_name', 'created_at',
            'notes'),
      ]..sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
    } catch (_) {
      _error = 'Development evidence could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadRuns() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _client
          .from('admin_development_execution_jobs')
          .select(
              'id,task_id,job_key,provider,executor_mode,status,attempt_number,repository,base_branch,created_at,updated_at,failure_code,failure_summary,result_summary')
          .order('created_at', ascending: false)
          .limit(100);
      _runs = (rows as List)
          .map((row) => DevelopmentExecutionJob.fromMap(
              Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      _error = 'Execution records could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadRunDetail(String jobId) async {
    _loading = true;
    _error = null;
    _selectedRunEvents = const [];
    _selectedRunPolicy = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('admin_development_execution_events')
            .select('id,event_type,summary,created_at')
            .eq('execution_job_id', jobId)
            .order('created_at'),
        _client
            .from('admin_development_execution_policy_decisions')
            .select('decision,reasons,evaluated_at')
            .eq('execution_job_id', jobId)
            .order('evaluated_at', ascending: false)
            .limit(1),
      ]);
      _selectedRunEvents = (results[0] as List)
          .map((row) => DevelopmentExecutionEvent.fromMap(
              Map<String, dynamic>.from(row as Map)))
          .toList();
      final policies = results[1] as List;
      if (policies.isNotEmpty) {
        _selectedRunPolicy = DevelopmentExecutionPolicyRecord.fromMap(
            Map<String, dynamic>.from(policies.first as Map));
      }
    } catch (_) {
      _error = 'Execution evidence could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// The browser submits only a task ID. The database loads task context,
  /// hashes the stored prompt, evaluates policy, and performs mock-only work.
  Future<void> requestMockExecution(String taskId) async {
    try {
      await _client.rpc('admin_request_mock_development_execution', params: {
        'p_task_id': taskId,
      });
      await loadRuns();
    } catch (_) {
      throw StateError('The mock execution request could not be completed.');
    }
  }

  Future<void> cancelMockExecution(String jobId) async {
    try {
      await _client.rpc('admin_cancel_development_execution', params: {
        'p_job_id': jobId,
      });
      await loadRuns();
    } catch (_) {
      throw StateError('The mock execution could not be cancelled.');
    }
  }
}

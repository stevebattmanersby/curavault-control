import 'package:curavault_admin/admin/data/models/development_control_models.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A narrow, admin-only data surface for Phase 1 workflow records.
/// It intentionally has no execution, webhook, GitHub, or secret capability.
class DevelopmentControlStore extends ChangeNotifier {
  List<DevelopmentTask> _tasks = const [];
  List<DevelopmentPromptTemplate> _prompts = const [];
  bool _loading = false;
  String? _error;

  List<DevelopmentTask> get tasks => _tasks;
  List<DevelopmentPromptTemplate> get prompts => _prompts;
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
}

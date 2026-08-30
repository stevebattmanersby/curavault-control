import 'dart:io';

import 'package:curavault_admin/admin/data/models/development_control_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Development control models', () {
    test('uses stable wire values for statuses and risks', () {
      expect(DevelopmentTaskStatus.awaitingApproval.value, 'awaiting_approval');
      expect(DevelopmentRiskLevel.critical.value, 'critical');
      expect(DevelopmentTaskStatus.changesRequested.label, 'Changes Requested');
    });

    test('parses a safe task record', () {
      final task = DevelopmentTask.fromMap({
        'id': 'task-id',
        'task_key': 'CVDEV-000001',
        'title': 'Safe task',
        'original_product_request': 'Use metadata only',
        'risk_level': 'high',
        'status': 'awaiting_approval',
        'created_at': '2026-08-30T12:00:00Z',
        'updated_at': '2026-08-30T12:00:00Z',
      });
      expect(task.riskLevel, DevelopmentRiskLevel.high);
      expect(task.status, DevelopmentTaskStatus.awaitingApproval);
    });

    test('keeps evidence records separate from task prompt records', () {
      final item = DevelopmentEvidenceItem(
          id: 'evidence-id',
          kind: 'Review',
          label: 'security',
          summary: 'Approved',
          recordedAt: DateTime.utc(2026, 8, 30));
      expect(item.kind, 'Review');
      expect(item.summary, 'Approved');
    });
  });

  group('Development control permissions', () {
    late final String rbac;
    late final String nav;
    late final String sidebar;
    late final String page;

    setUpAll(() {
      rbac = File('lib/admin/auth/admin_rbac.dart').readAsStringSync();
      nav = File('lib/nav.dart').readAsStringSync();
      sidebar =
          File('lib/admin/pages/widgets/admin_sidebar.dart').readAsStringSync();
      page = File('lib/admin/pages/development_control_page.dart')
          .readAsStringSync();
    });

    test('keeps owner-only high-risk approval', () {
      expect(rbac, contains('canApproveHighRiskDevelopment'));
      expect(rbac, contains('role == AdminRole.owner'));
    });

    test('keeps support and billing outside development control', () {
      expect(rbac, contains('canViewDevelopmentControl'));
      expect(rbac, contains('canCreateDevelopmentTasks'));
      expect(rbac, contains('AppRoutes.developmentOverview'));
      expect(rbac, contains('AdminRole.owner'));
      expect(rbac, contains('AdminRole.admin'));
    });

    test('allows only compliance security-review submission', () {
      expect(rbac, contains('canSubmitSecurityReview'));
      expect(rbac,
          contains('role == AdminRole.owner || role == AdminRole.compliance'));
    });

    test('wires first-class Development routes and a safe task form', () {
      for (final route in [
        'developmentOverview',
        'developmentTasks',
        'developmentPrompts',
        'developmentReviews',
        'developmentReleases',
        'developmentEvidence'
      ]) {
        expect(nav, contains(route));
        expect(sidebar, contains(route));
      }
      expect(sidebar, contains("_SidebarSection(label: 'Development')"));
      expect(page, contains('Save Development Task'));
      expect(page, isNot(contains('Run Codex')));
      expect(page, contains('SelectableText(content)'));
    });
  });

  group('Development control migration', () {
    late final String sql;
    setUpAll(() {
      final file = File(
          'supabase/migrations/20260830213000_development_control_plane_phase_1.sql');
      expect(file.existsSync(), isTrue);
      sql = file.readAsStringSync();
    });

    test('creates the required workflow records and task-key sequence', () {
      for (final table in [
        'admin_development_tasks',
        'admin_development_task_events',
        'admin_development_prompt_templates',
        'admin_development_reviews',
        'admin_development_checks',
        'admin_releases'
      ]) {
        expect(sql, contains('public.$table'));
        expect(
            sql, contains("'alter table public.%I enable row level security'"));
      }
      expect(
          sql,
          contains(
              "'CVDEV-' || lpad(nextval('public.admin_development_task_key_seq')"));
      expect(sql, contains('task_key text not null unique'));
    });

    test('fails closed for anon and protects approval/audit paths', () {
      expect(sql, contains('revoke all on table public.%I from anon'));
      expect(sql, contains("public.current_admin_role() <> 'owner'"));
      expect(sql, contains('owner approval required'));
      expect(sql, contains('admin_development_task_approval_state_check'));
      expect(
          sql,
          contains(
              "status <> 'approved' or (human_approval_status = 'approved'"));
      expect(sql, contains("status not in ('approved', 'completed')"));
      expect(sql, contains('approval attribution is server controlled'));
      expect(sql, contains('recorded approval attribution is immutable'));
      expect(sql, contains('admin_audit_development_mutation'));
      expect(
          sql,
          isNot(contains(
              'grant select on table public.admin_development_tasks to anon')));
    });

    test('has an evidence-only store query without task request fields', () {
      final store = File('lib/admin/state/development_control_store.dart')
          .readAsStringSync();
      final evidenceMethod =
          store.substring(store.indexOf('Future<void> loadEvidence()'));
      expect(store, contains('Future<void> loadEvidence()'));
      expect(evidenceMethod, contains('admin_development_task_events'));
      expect(evidenceMethod, contains('admin_development_reviews'));
      expect(evidenceMethod, isNot(contains('original_product_request')));
      expect(evidenceMethod, isNot(contains('execution_prompt')));
    });

    test('does not add execution, credential, or patient-data fields', () {
      for (final forbidden in [
        'service_role',
        'github_token',
        'openai_key',
        'patient_name',
        'medical_document',
        'shell_command'
      ]) {
        expect(sql.toLowerCase(), isNot(contains(forbidden)));
      }
    });

    test('keeps the CI workflow read-only and disposable', () {
      final workflow =
          File('.github/workflows/flutter-ci.yml').readAsStringSync();
      final migrationValidator =
          File('tool/validate_development_control_migration.sh')
              .readAsStringSync();

      expect(workflow, contains('contents: read'));
      expect(workflow, contains('postgres:16-alpine'));
      expect(workflow, contains('check_analyzer_regression.sh'));
      expect(workflow, isNot(contains('pull-requests: write')));
      expect(workflow, isNot(contains('deployments: write')));
      expect(workflow, isNot(contains('packages: write')));
      expect(migrationValidator,
          contains('20260830213000_development_control_plane_phase_1.sql'));
      expect(migrationValidator, isNot(contains('supabase db push')));
    });
  });
}

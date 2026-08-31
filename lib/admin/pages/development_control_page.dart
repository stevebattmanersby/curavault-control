import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/models/development_control_models.dart';
import 'package:curavault_admin/admin/state/development_control_store.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/nav.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

enum DevelopmentSection { overview, tasks, prompts, reviews, releases }

class DevelopmentControlPage extends StatefulWidget {
  const DevelopmentControlPage({super.key, required this.section});
  final DevelopmentSection section;

  @override
  State<DevelopmentControlPage> createState() => _DevelopmentControlPageState();
}

class _DevelopmentControlPageState extends State<DevelopmentControlPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context
        .read<DevelopmentControlStore>()
        .load(includePrompts: widget.section == DevelopmentSection.prompts));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DevelopmentControlStore>();
    final role = context.watch<AdminAuthStore>().role;
    final canCreate = AdminRbac.canCreateDevelopmentTasks(role);
    final title = switch (widget.section) {
      DevelopmentSection.overview => 'Development Overview',
      DevelopmentSection.tasks => 'Development Tasks',
      DevelopmentSection.prompts => 'Prompt Library',
      DevelopmentSection.reviews => 'Reviews',
      DevelopmentSection.releases => 'Releases',
    };
    return AdminPageScaffold(
      title: title,
      subtitle:
          'Administrative workflow metadata and mock-only evidence. No secrets or external execution.',
      actions: [
        if (widget.section == DevelopmentSection.tasks && canCreate)
          FilledButton.icon(
              onPressed: () => _showTaskForm(context),
              icon: const Icon(Icons.add),
              label: const Text('New task')),
        if (widget.section == DevelopmentSection.prompts &&
            AdminRbac.canManagePromptTemplates(role))
          FilledButton.icon(
              onPressed: () => _showPromptForm(context),
              icon: const Icon(Icons.add),
              label: const Text('New template')),
        IconButton(
            onPressed: () => context.read<DevelopmentControlStore>().load(
                includePrompts: widget.section == DevelopmentSection.prompts),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh)),
      ],
      child: store.loading
          ? const Center(child: CircularProgressIndicator())
          : store.error != null
              ? _EmptyState(message: store.error!)
              : switch (widget.section) {
                  DevelopmentSection.overview => _Overview(tasks: store.tasks),
                  DevelopmentSection.tasks => _Tasks(tasks: store.tasks),
                  DevelopmentSection.prompts =>
                    _Prompts(prompts: store.prompts),
                  DevelopmentSection.reviews => _Reviews(tasks: store.tasks),
                  DevelopmentSection.releases => const _EmptyState(
                      message: 'No release records have been added yet.'),
                },
    );
  }
}

class DevelopmentTaskDetailPage extends StatelessWidget {
  const DevelopmentTaskDetailPage({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AdminAuthStore>().role;
    final task = context
        .watch<DevelopmentControlStore>()
        .tasks
        .where((item) => item.id == taskId)
        .firstOrNull;
    if (task == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.read<DevelopmentControlStore>().load());
      return const AdminPageScaffold(
          title: 'Development Task',
          child: Center(child: CircularProgressIndicator()));
    }
    return AdminPageScaffold(
      title: '${task.taskKey}  ${task.title}',
      subtitle: '${task.repository} · ${task.status.label}',
      actions: [
        if (AdminRbac.canRequestMockDevelopmentExecution(role) &&
            task.executionPrompt?.isNotEmpty == true)
          FilledButton.icon(
            onPressed: () => _confirmMockExecution(context, task),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Request mock run'),
          ),
        if (AdminRbac.canRequestMockDevelopmentExecution(role) &&
            task.executionPrompt?.isNotEmpty == true)
          _CodexExecutionAction(task: task),
      ],
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            _RiskBadge(risk: task.riskLevel),
            _StatusBadge(status: task.status),
            _Meta(label: 'Priority', value: '${task.priority}'),
            _Meta(label: 'Branch', value: task.workingBranch ?? task.baseBranch)
          ]),
          const SizedBox(height: AppSpacing.lg),
          _ContentCard(title: 'Request', content: task.originalProductRequest),
          if (task.executionPrompt?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.md),
            _ContentCard(
                title: 'Execution prompt', content: task.executionPrompt!)
          ],
          const SizedBox(height: AppSpacing.md),
          _ContentCard(
              title: 'GitHub references',
              content: [
                if (task.githubPrUrl != null)
                  'Pull request: ${task.githubPrUrl}',
                if (task.githubCommitSha != null)
                  'Commit: ${task.githubCommitSha}',
                if (task.githubPrUrl == null && task.githubCommitSha == null)
                  'No references recorded.'
              ].join('\n')),
          const SizedBox(height: AppSpacing.md),
          _ContentCard(
              title: 'Checks, reviews and activity',
              content:
                  'Evidence and reviews are reference records. Phase 1 does not run CI, GitHub actions, agents, or deployments.'),
        ]),
      ),
    );
  }
}

class DevelopmentRunsPage extends StatefulWidget {
  const DevelopmentRunsPage({super.key});

  @override
  State<DevelopmentRunsPage> createState() => _DevelopmentRunsPageState();
}

class _DevelopmentRunsPageState extends State<DevelopmentRunsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<DevelopmentControlStore>().loadRuns());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DevelopmentControlStore>();
    return AdminPageScaffold(
      title: 'Execution Runs',
      subtitle:
          'Policy-governed execution evidence. Codex remains disabled until trusted worker hosting is separately enabled.',
      actions: [
        IconButton(
            onPressed: () => context.read<DevelopmentControlStore>().loadRuns(),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh))
      ],
      child: store.loading
          ? const Center(child: CircularProgressIndicator())
          : store.error != null
              ? _EmptyState(message: store.error!)
              : store.runs.isEmpty
                  ? const _EmptyState(
                      message: 'No execution runs recorded yet.')
                  : ListView.separated(
                      itemCount: store.runs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final run = store.runs[index];
                        return AdminCard(
                            child: InkWell(
                          onTap: () =>
                              context.go('/development/runs/${run.id}'),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Row(children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(run.jobKey,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${run.provider} · ${run.repository} · ${run.baseBranch} · attempt ${run.attemptNumber}'),
                                  ])),
                              _ExecutionStatusBadge(status: run.status),
                            ]),
                          ),
                        ));
                      }),
    );
  }
}

class DevelopmentRunDetailPage extends StatefulWidget {
  const DevelopmentRunDetailPage({super.key, required this.runId});
  final String runId;

  @override
  State<DevelopmentRunDetailPage> createState() =>
      _DevelopmentRunDetailPageState();
}

class _DevelopmentRunDetailPageState extends State<DevelopmentRunDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<DevelopmentControlStore>().loadRunDetail(widget.runId));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DevelopmentControlStore>();
    final run = store.runs.where((item) => item.id == widget.runId).firstOrNull;
    if (run == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.read<DevelopmentControlStore>().loadRuns());
      return const AdminPageScaffold(
          title: 'Execution Run',
          child: Center(child: CircularProgressIndicator()));
    }
    final role = context.watch<AdminAuthStore>().role;
    final cancellable = {
      DevelopmentExecutionStatus.requested,
      DevelopmentExecutionStatus.policyCheck,
      DevelopmentExecutionStatus.queued,
      DevelopmentExecutionStatus.starting,
      DevelopmentExecutionStatus.running,
    }.contains(run.status);
    return AdminPageScaffold(
      title: run.jobKey,
      subtitle: '${run.provider} execution evidence',
      actions: [
        if (cancellable && AdminRbac.canRequestMockDevelopmentExecution(role))
          OutlinedButton.icon(
              onPressed: () => _cancelMockExecution(context, run.id),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel mock run')),
      ],
      child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          _ExecutionStatusBadge(status: run.status),
          _Meta(label: 'Provider', value: run.provider),
          _Meta(label: 'Mode', value: run.executorMode),
          _Meta(label: 'Attempt', value: '${run.attemptNumber}'),
        ]),
        const SizedBox(height: AppSpacing.lg),
        _ContentCard(
            title: 'Repository context',
            content: '${run.repository}\nBase branch: ${run.baseBranch}'
                '${run.resolvedBaseSha == null ? '' : '\nPinned SHA: ${run.resolvedBaseSha}'}'),
        if (run.changedPaths.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _ContentCard(
              title: 'Workspace change summary',
              content: '${run.changedPaths.length} changed path(s)\n'
                  '${run.changedPaths.join('\n')}'
                  '${run.protectedPathChanged ? '\nProtected path warning recorded.' : ''}'),
        ],
        if (run.testsSummary?.isNotEmpty == true ||
            run.analyzerSummary?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.md),
          _ContentCard(
              title: 'Validation summary',
              content: [run.testsSummary, run.analyzerSummary]
                  .whereType<String>()
                  .where((item) => item.isNotEmpty)
                  .join('\n')),
        ],
        if (store.selectedRunPolicy != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ContentCard(
              title: 'Policy decision',
              content:
                  '${store.selectedRunPolicy!.decision.label}\n${store.selectedRunPolicy!.reasons.join(', ')}'),
        ],
        if (run.failureSummary?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.md),
          _ContentCard(
              title: 'Safe failure summary', content: run.failureSummary!),
        ],
        if (run.resultSummary?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.md),
          _ContentCard(title: 'Result summary', content: run.resultSummary!),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Lifecycle', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (store.selectedRunEvents.isEmpty)
          const Text('No lifecycle evidence is available yet.')
        else
          ...store.selectedRunEvents.map((event) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_outlined),
                title: Text(event.eventType),
                subtitle: Text(event.summary),
                trailing: Text(event.createdAt.toIso8601String(),
                    style: Theme.of(context).textTheme.labelSmall),
              )),
      ])),
    );
  }
}

class DevelopmentEvidencePage extends StatefulWidget {
  const DevelopmentEvidencePage({super.key});
  @override
  State<DevelopmentEvidencePage> createState() =>
      _DevelopmentEvidencePageState();
}

class _DevelopmentEvidencePageState extends State<DevelopmentEvidencePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<DevelopmentControlStore>().loadEvidence());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DevelopmentControlStore>();
    return AdminPageScaffold(
      title: 'Development Evidence',
      subtitle:
          'Reviews, checks, releases, and event metadata only. Task requests and prompts are excluded.',
      actions: [
        IconButton(
            onPressed: () =>
                context.read<DevelopmentControlStore>().loadEvidence(),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh))
      ],
      child: store.loading
          ? const Center(child: CircularProgressIndicator())
          : store.error != null
              ? _EmptyState(message: store.error!)
              : store.evidence.isEmpty
                  ? const _EmptyState(
                      message: 'No development evidence has been recorded yet.')
                  : ListView.separated(
                      itemCount: store.evidence.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final item = store.evidence[index];
                        return AdminCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.kind,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                              Text(item.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              if (item.summary?.isNotEmpty ?? false)
                                Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(item.summary!)),
                              Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(item.recordedAt.toIso8601String(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)))
                            ]));
                      }),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.tasks});
  final List<DevelopmentTask> tasks;
  int _count(bool Function(DevelopmentTask) match) => tasks.where(match).length;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
          MetricTile(
              label: 'Active tasks',
              value: _count((t) => !{
                    DevelopmentTaskStatus.completed,
                    DevelopmentTaskStatus.cancelled
                  }.contains(t.status)).toString(),
              icon: Icons.pending_actions_outlined),
          MetricTile(
              label: 'Awaiting review',
              value: _count(
                      (t) => t.status == DevelopmentTaskStatus.awaitingReview)
                  .toString(),
              icon: Icons.rate_review_outlined),
          MetricTile(
              label: 'Awaiting approval',
              value: _count(
                      (t) => t.status == DevelopmentTaskStatus.awaitingApproval)
                  .toString(),
              icon: Icons.verified_user_outlined),
          MetricTile(
              label: 'Blocked',
              value: _count((t) => t.status == DevelopmentTaskStatus.blocked)
                  .toString(),
              icon: Icons.block_outlined),
          MetricTile(
              label: 'High risk',
              value: _count((t) =>
                  t.riskLevel == DevelopmentRiskLevel.high ||
                  t.riskLevel == DevelopmentRiskLevel.critical).toString(),
              icon: Icons.warning_amber_outlined),
        ]),
        const SizedBox(height: AppSpacing.xl),
        Text('Recent activity',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        _Tasks(tasks: tasks.take(8).toList(), compact: true),
      ]));
}

class _Tasks extends StatefulWidget {
  const _Tasks({required this.tasks, this.compact = false});
  final List<DevelopmentTask> tasks;
  final bool compact;
  @override
  State<_Tasks> createState() => _TasksState();
}

class _TasksState extends State<_Tasks> {
  String _query = '';
  DevelopmentTaskStatus? _status;
  DevelopmentRiskLevel? _risk;
  @override
  Widget build(BuildContext context) {
    final filtered = widget.tasks
        .where((task) =>
            (_status == null || task.status == _status) &&
            (_risk == null || task.riskLevel == _risk) &&
            ('${task.taskKey} ${task.title} ${task.repository}'
                .toLowerCase()
                .contains(_query.toLowerCase())))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!widget.compact) ...[
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          SizedBox(
              width: 280,
              child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search tasks'))),
          DropdownButton<DevelopmentTaskStatus?>(
              value: _status,
              hint: const Text('All statuses'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All statuses')),
                ...DevelopmentTaskStatus.values.map((value) =>
                    DropdownMenuItem(value: value, child: Text(value.label)))
              ],
              onChanged: (value) => setState(() => _status = value)),
          DropdownButton<DevelopmentRiskLevel?>(
              value: _risk,
              hint: const Text('All risks'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All risks')),
                ...DevelopmentRiskLevel.values.map((value) =>
                    DropdownMenuItem(value: value, child: Text(value.label)))
              ],
              onChanged: (value) => setState(() => _risk = value)),
        ]),
        const SizedBox(height: AppSpacing.md),
      ],
      if (filtered.isEmpty)
        const _EmptyState(message: 'No development tasks match this view.')
      else
        ...filtered.map((task) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _TaskRow(task: task))),
    ]);
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});
  final DevelopmentTask task;
  @override
  Widget build(BuildContext context) => AdminCard(
          child: InkWell(
        onTap: () => context.go('/development/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(task.taskKey,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 3),
                    Text(task.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(task.repository,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant))
                  ])),
              const SizedBox(width: AppSpacing.md),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _RiskBadge(risk: task.riskLevel),
                const SizedBox(height: 6),
                _StatusBadge(status: task.status)
              ]),
            ])),
      ));
}

class _Prompts extends StatelessWidget {
  const _Prompts({required this.prompts});
  final List<DevelopmentPromptTemplate> prompts;
  @override
  Widget build(BuildContext context) => prompts.isEmpty
      ? const _EmptyState(message: 'No prompt templates have been added yet.')
      : ListView.separated(
          itemCount: prompts.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final prompt = prompts[index];
            return AdminCard(
                child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(prompt.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (prompt.description?.isNotEmpty ?? false)
                      Text(prompt.description!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 5),
                    Text(
                        '${prompt.category} · v${prompt.version} · ${prompt.riskLevel.label}',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant))
                  ])),
              if (!prompt.isActive) const Chip(label: Text('Archived'))
            ]));
          });
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.tasks});
  final List<DevelopmentTask> tasks;
  @override
  Widget build(BuildContext context) => tasks.isEmpty
      ? const _EmptyState(
          message: 'No review records are available until tasks are created.')
      : ListView(
          children: tasks
              .map((task) => AdminCard(
                      child: Row(children: [
                    Expanded(child: Text('${task.taskKey} · ${task.title}')),
                    _StatusBadge(status: task.status)
                  ])))
              .toList());
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.title, required this.content});
  final String title;
  final String content;
  @override
  Widget build(BuildContext context) => AdminCard(
      header: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      child: SelectableText(content));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
      child: Text(message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)));
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.risk});
  final DevelopmentRiskLevel risk;
  @override
  Widget build(BuildContext context) {
    final color = switch (risk) {
      DevelopmentRiskLevel.low => Colors.green,
      DevelopmentRiskLevel.medium => Colors.blue,
      DevelopmentRiskLevel.high => Colors.orange,
      DevelopmentRiskLevel.critical => Colors.red
    };
    return Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(Icons.shield_outlined, size: 16, color: color),
        label: Text(risk.label));
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final DevelopmentTaskStatus status;
  @override
  Widget build(BuildContext context) =>
      Chip(visualDensity: VisualDensity.compact, label: Text(status.label));
}

class _ExecutionStatusBadge extends StatelessWidget {
  const _ExecutionStatusBadge({required this.status});
  final DevelopmentExecutionStatus status;

  @override
  Widget build(BuildContext context) =>
      Chip(visualDensity: VisualDensity.compact, label: Text(status.label));
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'));
}

class _CodexExecutionAction extends StatelessWidget {
  const _CodexExecutionAction({required this.task});
  final DevelopmentTask task;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
        future: context
            .read<DevelopmentControlStore>()
            .canRequestCodexExecution(task.id),
        builder: (context, snapshot) {
          if (snapshot.data != true) return const SizedBox.shrink();
          return FilledButton.icon(
              onPressed: () => _confirmCodexExecution(context, task),
              icon: const Icon(Icons.security_outlined),
              label: const Text('Request Codex run'));
        });
  }
}

Future<void> _showTaskForm(BuildContext context) async {
  final store = context.read<DevelopmentControlStore>();
  await showDialog<void>(
      context: context, builder: (_) => _TaskForm(store: store));
}

Future<void> _confirmMockExecution(
    BuildContext context, DevelopmentTask task) async {
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
              title: const Text('Request mock run?'),
              content: Text(
                  '${task.taskKey} will be checked against the server-side execution policy. This creates lifecycle evidence only: it does not run code, contact Codex/OpenAI, write to GitHub, or deploy anything.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Request mock run')),
              ]));
  if (confirmed != true || !context.mounted) return;
  try {
    await context.read<DevelopmentControlStore>().requestMockExecution(task.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Mock execution request recorded. Review Runs for policy evidence.')));
      context.go(AppRoutes.developmentRuns);
    }
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _confirmCodexExecution(
    BuildContext context, DevelopmentTask task) async {
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
              title: const Text('Request Codex run?'),
              content: Text(
                  '${task.taskKey} will be evaluated against server-side repository, SHA, approval, and path policy. Any approved run uses an isolated workspace. Nothing will be pushed, merged, published as a pull request, or deployed.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Request Codex run')),
              ]));
  if (confirmed != true || !context.mounted) return;
  try {
    await context
        .read<DevelopmentControlStore>()
        .requestCodexExecution(task.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Codex execution request recorded. Review Runs for policy evidence.')));
      context.go(AppRoutes.developmentRuns);
    }
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _cancelMockExecution(BuildContext context, String runId) async {
  try {
    await context.read<DevelopmentControlStore>().cancelMockExecution(runId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mock execution cancellation recorded.')));
    }
  } on StateError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _showPromptForm(BuildContext context) async {
  final store = context.read<DevelopmentControlStore>();
  await showDialog<void>(
      context: context, builder: (_) => _PromptForm(store: store));
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({required this.store});
  final DevelopmentControlStore store;
  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _request = TextEditingController();
  final _prompt = TextEditingController();
  final _repository =
      TextEditingController(text: 'stevebattmanersby/curavult-app');
  final _branch = TextEditingController(text: 'main');
  DevelopmentRiskLevel _risk = DevelopmentRiskLevel.medium;
  String _taskType = 'feature';
  int _priority = 3;
  bool _manualTesting = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _request.dispose();
    _prompt.dispose();
    _repository.dispose();
    _branch.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.store.createTask(
          title: _title.text,
          request: _request.text,
          prompt: _prompt.text,
          taskType: _taskType,
          repository: _repository.text,
          baseBranch: _branch.text,
          risk: _risk,
          priority: _priority,
          manualTesting: _manualTesting);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task could not be saved.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New development task'),
        content: SizedBox(
            width: 560,
            child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Enter a task title.'
                          : null),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _request,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                          labelText: 'Original product request'),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the approved request.'
                          : null),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _prompt,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                          labelText: 'Execution prompt (optional)')),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _repository,
                      decoration:
                          const InputDecoration(labelText: 'Repository')),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _branch,
                      decoration:
                          const InputDecoration(labelText: 'Base branch')),
                  const SizedBox(height: 10),
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    DropdownButton<DevelopmentRiskLevel>(
                        value: _risk,
                        items: DevelopmentRiskLevel.values
                            .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('${value.label} risk')))
                            .toList(),
                        onChanged: (value) => setState(() => _risk = value!)),
                    DropdownButton<String>(
                        value: _taskType,
                        items: const [
                          'feature',
                          'bug_fix',
                          'ui_ux',
                          'security',
                          'migration',
                          'release',
                          'test',
                          'documentation',
                          'other'
                        ]
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _taskType = value!)),
                    DropdownButton<int>(
                        value: _priority,
                        items: [1, 2, 3, 4, 5]
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text('Priority $value')))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _priority = value!)),
                  ]),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _manualTesting,
                      onChanged: (value) =>
                          setState(() => _manualTesting = value ?? true),
                      title: const Text('Manual testing required')),
                ])))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save Development Task'))
        ],
      );
}

class _PromptForm extends StatefulWidget {
  const _PromptForm({required this.store});
  final DevelopmentControlStore store;
  @override
  State<_PromptForm> createState() => _PromptFormState();
}

class _PromptFormState extends State<_PromptForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController(text: 'general');
  final _prompt = TextEditingController();
  DevelopmentRiskLevel _risk = DevelopmentRiskLevel.medium;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.store.savePrompt(
          name: _name.text,
          description: _description.text,
          category: _category.text,
          prompt: _prompt.text,
          risk: _risk);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template could not be saved.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('New prompt template'),
          content: SizedBox(
              width: 560,
              child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value?.trim().length ?? 0) < 3
                            ? 'Enter a template name.'
                            : null),
                    TextFormField(
                        controller: _description,
                        decoration:
                            const InputDecoration(labelText: 'Description')),
                    TextFormField(
                        controller: _category,
                        decoration:
                            const InputDecoration(labelText: 'Category')),
                    TextFormField(
                        controller: _prompt,
                        minLines: 5,
                        maxLines: 9,
                        decoration:
                            const InputDecoration(labelText: 'Prompt template'),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Enter prompt content.'
                            : null),
                    DropdownButton<DevelopmentRiskLevel>(
                        value: _risk,
                        items: DevelopmentRiskLevel.values
                            .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text('${value.label} risk')))
                            .toList(),
                        onChanged: (value) => setState(() => _risk = value!))
                  ])))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save template'))
          ]);
}

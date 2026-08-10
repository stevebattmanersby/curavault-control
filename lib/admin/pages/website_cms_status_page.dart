import 'package:curavault_admin/admin/auth/admin_auth_store.dart';
import 'package:curavault_admin/admin/auth/admin_rbac.dart';
import 'package:curavault_admin/admin/data/data_source_status.dart';
import 'package:curavault_admin/admin/data/models/admin_models.dart';
import 'package:curavault_admin/admin/data/models/cms_models.dart';
import 'package:curavault_admin/admin/pages/widgets/admin_owner_data_source_panel.dart';
import 'package:curavault_admin/admin/state/admin_store.dart';
import 'package:curavault_admin/admin/utils/formatters.dart';
import 'package:curavault_admin/admin/widgets/admin_layout.dart';
import 'package:curavault_admin/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WebsiteCmsStatusPage extends StatelessWidget {
  const WebsiteCmsStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final role = context.watch<AdminAuthStore>().role;
    final snap = store.websiteCms;
    final cms = store.marketingCms;
    final isLoading = store.isLoading || store.isWebsiteCmsLoading;
    final canManage = AdminRbac.canManageMarketingCms(role);

    return AdminPageScaffold(
      title: 'Website CMS',
      subtitle:
          'Manage marketing pages and blog drafts. Public website access is limited to published content only.',
      actions: [
        AdminDataSourceBadge(
            status: store.dataSource(AdminDataSourceKey.websiteCms)),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: () => context.read<AdminStore>().refreshWebsiteCmsStatus(),
          icon: Icon(Icons.refresh,
              color: Theme.of(context).colorScheme.onSurface),
          splashColor: Colors.transparent,
          highlightColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          hoverColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          tooltip: 'Refresh',
        ),
      ],
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : store.dataSource(AdminDataSourceKey.websiteCms).kind ==
                  AdminDataSourceKind.notInstrumented
              ? const AdminNotInstrumentedPanel()
              : store.dataSource(AdminDataSourceKey.websiteCms).kind ==
                      AdminDataSourceKind.error
                  ? Center(
                      child: Text(
                        store
                                .dataSource(AdminDataSourceKey.websiteCms)
                                .safeErrorMessage ??
                            'Failed to load Website CMS.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  : cms == null || snap == null
                      ? const _EmptyWebsiteCmsState()
                      : _WebsiteCmsWorkspace(
                          snapshot: snap, cms: cms, canManage: canManage),
    );
  }
}

class _WebsiteCmsWorkspace extends StatefulWidget {
  const _WebsiteCmsWorkspace({
    required this.snapshot,
    required this.cms,
    required this.canManage,
  });

  final WebsiteCmsStatusSnapshot snapshot;
  final MarketingCmsSnapshot cms;
  final bool canManage;

  @override
  State<_WebsiteCmsWorkspace> createState() => _WebsiteCmsWorkspaceState();
}

class _WebsiteCmsWorkspaceState extends State<_WebsiteCmsWorkspace> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final cms = widget.cms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminOwnerDataSourcePanel(
          store: context.watch<AdminStore>(),
          dataSourceKey: AdminDataSourceKey.websiteCms,
          title: 'Website CMS',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricPill(
                label: 'Pages',
                value: cms.pages.length.toString(),
                icon: Icons.description_outlined),
            _MetricPill(
                label: 'Published pages',
                value: cms.publishedPages.toString(),
                icon: Icons.public_outlined),
            _MetricPill(
                label: 'Blog posts',
                value: cms.blogPosts.length.toString(),
                icon: Icons.article_outlined),
            _MetricPill(
                label: 'Review queue',
                value: cms.reviewItems.toString(),
                icon: Icons.rate_review_outlined),
            _MetricPill(
                label: 'Scheduled',
                value: cms.scheduledItems.toString(),
                icon: Icons.schedule_outlined),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
                value: 0, icon: Icon(Icons.web_outlined), label: Text('Pages')),
            ButtonSegment(
                value: 1,
                icon: Icon(Icons.article_outlined),
                label: Text('Blog')),
            ButtonSegment(
                value: 2,
                icon: Icon(Icons.table_chart_outlined),
                label: Text('Schema')),
          ],
          selected: {_tab},
          onSelectionChanged: (value) => setState(() => _tab = value.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _PagesTab(cms: cms, canManage: widget.canManage),
              _BlogTab(cms: cms, canManage: widget.canManage),
              _StatusTab(snapshot: widget.snapshot),
            ],
          ),
        ),
      ],
    );
  }
}

class _PagesTab extends StatelessWidget {
  const _PagesTab({required this.cms, required this.canManage});

  final MarketingCmsSnapshot cms;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabHeader(
          title: 'Pages',
          body: canManage
              ? 'Create draft pages, manage page sections, and publish only when reviewed.'
              : 'Read-only CMS inspection.',
          action: canManage
              ? FilledButton.icon(
                  onPressed: () => _openPageEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New page'),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: cms.pages.isEmpty
              ? _EmptyPanel(
                  icon: Icons.description_outlined,
                  title: 'No pages yet',
                  body: canManage
                      ? 'Create the first draft page for the public website.'
                      : 'No CMS pages have been created.',
                )
              : ListView.separated(
                  itemCount: cms.pages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final page = cms.pages[index];
                    return _PageCard(
                      page: page,
                      sections: cms.sectionsForPage(page.id),
                      canManage: canManage,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BlogTab extends StatelessWidget {
  const _BlogTab({required this.cms, required this.canManage});

  final MarketingCmsSnapshot cms;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabHeader(
          title: 'Blog',
          body: canManage
              ? 'Prepare launch posts, SEO summaries, and publication status.'
              : 'Read-only blog inspection.',
          action: canManage
              ? FilledButton.icon(
                  onPressed: () =>
                      _openBlogEditor(context, categories: cms.categories),
                  icon: const Icon(Icons.add),
                  label: const Text('New post'),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: cms.blogPosts.isEmpty
              ? _EmptyPanel(
                  icon: Icons.article_outlined,
                  title: 'No blog posts yet',
                  body: canManage
                      ? 'Create the first draft post for review.'
                      : 'No CMS blog posts have been created.',
                )
              : ListView.separated(
                  itemCount: cms.blogPosts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => _BlogPostCard(
                    post: cms.blogPosts[index],
                    categories: cms.categories,
                    canManage: canManage,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.page,
    required this.sections,
    required this.canManage,
  });

  final MarketingPageRow page;
  final List<MarketingPageSectionRow> sections;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      header: _ContentHeader(
        title: page.title,
        slug: '/${page.slug}',
        status: page.status,
        updatedAt: page.updatedAt,
        canManage: canManage,
        onEdit: () => _openPageEditor(context, page: page),
        onPublish: () => _changeStatus(
            context, 'page', page.id, MarketingContentStatus.published),
        onUnpublish: () => _changeStatus(
            context, 'page', page.id, MarketingContentStatus.draft),
        onArchive: () => _changeStatus(
            context, 'page', page.id, MarketingContentStatus.archived),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((page.excerpt ?? '').isNotEmpty)
            Text(page.excerpt!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MiniChip(
                  icon: Icons.search_outlined,
                  label: page.seoTitle?.isNotEmpty == true
                      ? 'SEO title set'
                      : 'SEO title missing'),
              _MiniChip(
                  icon: Icons.notes_outlined,
                  label: page.seoDescription?.isNotEmpty == true
                      ? 'Meta description set'
                      : 'Meta description missing'),
              _MiniChip(
                  icon: Icons.view_agenda_outlined,
                  label: '${sections.length} sections'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionList(page: page, sections: sections, canManage: canManage),
        ],
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.page,
    required this.sections,
    required this.canManage,
  });

  final MarketingPageRow page;
  final List<MarketingPageSectionRow> sections;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Text('Sections',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                if (canManage)
                  TextButton.icon(
                    onPressed: () => _openSectionEditor(context,
                        page: page, nextSortOrder: sections.length),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add section'),
                  ),
              ],
            ),
          ),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No sections yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
            )
          else
            ...sections.map(
              (section) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primaryContainer,
                  child: Text(section.sortOrder.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: cs.onPrimaryContainer)),
                ),
                title: Text(section.title?.isNotEmpty == true
                    ? section.title!
                    : section.sectionKey),
                subtitle:
                    Text('${section.sectionType} · ${section.status.label}'),
                trailing: canManage
                    ? IconButton(
                        onPressed: () => _openSectionEditor(context,
                            page: page,
                            section: section,
                            nextSortOrder: section.sortOrder),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit section',
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _BlogPostCard extends StatelessWidget {
  const _BlogPostCard({
    required this.post,
    required this.categories,
    required this.canManage,
  });

  final MarketingBlogPostRow post;
  final List<MarketingBlogCategoryRow> categories;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final category =
        categories.where((c) => c.id == post.categoryId).firstOrNull;
    return AdminCard(
      header: _ContentHeader(
        title: post.title,
        slug: '/blog/${post.slug}',
        status: post.status,
        updatedAt: post.updatedAt,
        canManage: canManage,
        onEdit: () =>
            _openBlogEditor(context, post: post, categories: categories),
        onPublish: () => _changeStatus(
            context, 'blog_post', post.id, MarketingContentStatus.published),
        onUnpublish: () => _changeStatus(
            context, 'blog_post', post.id, MarketingContentStatus.draft),
        onArchive: () => _changeStatus(
            context, 'blog_post', post.id, MarketingContentStatus.archived),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((post.excerpt ?? '').isNotEmpty)
            Text(post.excerpt!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MiniChip(
                  icon: Icons.folder_outlined,
                  label: category?.name ?? 'No category'),
              _MiniChip(
                  icon: Icons.search_outlined,
                  label: post.seoTitle?.isNotEmpty == true
                      ? 'SEO title set'
                      : 'SEO title missing'),
              _MiniChip(
                  icon: Icons.notes_outlined,
                  label: post.seoDescription?.isNotEmpty == true
                      ? 'Meta description set'
                      : 'Meta description missing'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({
    required this.title,
    required this.slug,
    required this.status,
    required this.updatedAt,
    required this.canManage,
    required this.onEdit,
    required this.onPublish,
    required this.onUnpublish,
    required this.onArchive,
  });

  final String title;
  final String slug;
  final MarketingContentStatus status;
  final DateTime updatedAt;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('$slug · Updated ${AdminFormatters.dateTime(updatedAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        _StatusChip(status: status),
        if (canManage) ...[
          OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit')),
          if (status != MarketingContentStatus.published)
            FilledButton.icon(
                onPressed: onPublish,
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publish')),
          if (status == MarketingContentStatus.published)
            OutlinedButton.icon(
                onPressed: onUnpublish,
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Unpublish')),
          OutlinedButton.icon(
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive')),
        ],
      ],
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.snapshot});

  final WebsiteCmsStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _WebsiteCmsStatusTable(snapshot: snapshot);
  }
}

class _WebsiteCmsStatusTable extends StatelessWidget {
  const _WebsiteCmsStatusTable({required this.snapshot});

  final WebsiteCmsStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = snapshot.rows;

    return AdminCard(
      header: Row(
        children: [
          Text('Marketing tables',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('Generated ${AdminFormatters.dateTime(snapshot.generatedAt)}',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 980),
                child: Column(
                  children: [
                    const _WebsiteCmsStatusHeaderRow(),
                    for (final row in rows) ...[
                      Divider(
                          height: 1, color: cs.outline.withValues(alpha: 0.18)),
                      _WebsiteCmsStatusDataRow(row: row),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebsiteCmsStatusHeaderRow extends StatelessWidget {
  const _WebsiteCmsStatusHeaderRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Row(
        children: [
          _Cell(width: 240, child: Text('Table', style: style)),
          _Cell(width: 90, child: Text('Exists', style: style)),
          _Cell(width: 110, child: Text('Row count', style: style)),
          _Cell(width: 210, child: Text('Latest updated_at', style: style)),
          _Cell(width: 120, child: Text('RLS enabled', style: style)),
          _Cell(width: 160, child: Text('UI connected', style: style)),
          _Cell(width: 140, child: Text('Status', style: style)),
        ],
      ),
    );
  }
}

class _WebsiteCmsStatusDataRow extends StatelessWidget {
  const _WebsiteCmsStatusDataRow({required this.row});

  final WebsiteCmsTableStatusRow row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final err = (row.safeErrorMessage ?? '').trim();
    final rowWidget = Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      child: Row(
        children: [
          _Cell(
              width: 240,
              child: Text(row.tableName,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
          _Cell(
              width: 90,
              child: Text(row.exists ? 'Yes' : 'No',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: row.exists ? cs.onSurface : cs.error))),
          _Cell(
              width: 110,
              child: Text(
                  row.rowCount == null
                      ? '-'
                      : AdminFormatters.compactInt(row.rowCount!),
                  style: textTheme.bodyMedium)),
          _Cell(
              width: 210,
              child: Text(
                  row.latestUpdatedAt == null
                      ? '-'
                      : AdminFormatters.dateTime(row.latestUpdatedAt),
                  style: textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant))),
          _Cell(
              width: 120,
              child: Text(
                  row.rlsEnabled == null
                      ? '-'
                      : (row.rlsEnabled! ? 'Yes' : 'No'),
                  style: textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant))),
          _Cell(
              width: 160,
              child: Text(row.uiConnected ? 'Yes' : 'No',
                  style: textTheme.bodyMedium?.copyWith(
                      color: row.uiConnected
                          ? cs.onSurface
                          : cs.onSurfaceVariant))),
          _Cell(
              width: 140,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _TableStatusChip(status: row.status))),
        ],
      ),
    );
    return err.isEmpty ? rowWidget : Tooltip(message: err, child: rowWidget);
  }
}

class _PageEditorSheet extends StatefulWidget {
  const _PageEditorSheet({this.page});

  final MarketingPageRow? page;

  @override
  State<_PageEditorSheet> createState() => _PageEditorSheetState();
}

class _PageEditorSheetState extends State<_PageEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _excerpt;
  late final TextEditingController _seoTitle;
  late final TextEditingController _seoDescription;
  late MarketingContentStatus _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final page = widget.page;
    _title = TextEditingController(text: page?.title ?? '');
    _slug = TextEditingController(text: page?.slug ?? '');
    _excerpt = TextEditingController(text: page?.excerpt ?? '');
    _seoTitle = TextEditingController(text: page?.seoTitle ?? '');
    _seoDescription = TextEditingController(text: page?.seoDescription ?? '');
    _status = page?.status ?? MarketingContentStatus.draft;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _excerpt.dispose();
    _seoTitle.dispose();
    _seoDescription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorShell(
      title: widget.page == null ? 'New page' : 'Edit page',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextField(
                controller: _title,
                label: 'Title',
                required: true,
                onChanged: _maybeUpdateSlug),
            _TextField(controller: _slug, label: 'Slug', required: true),
            _StatusField(
                value: _status,
                onChanged: (value) => setState(() => _status = value)),
            _TextField(controller: _excerpt, label: 'Summary'),
            _TextField(controller: _seoTitle, label: 'SEO title'),
            _TextField(
                controller: _seoDescription,
                label: 'SEO description',
                maxLines: 3),
          ],
        ),
      ),
    );
  }

  void _maybeUpdateSlug(String value) {
    if (widget.page != null || _slug.text.trim().isNotEmpty) return;
    _slug.text = cmsSlugFromTitle(value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await context.read<AdminStore>().saveMarketingPage(
            MarketingPageDraft(
              id: widget.page?.id,
              title: _title.text.trim(),
              slug: cmsSlugFromTitle(_slug.text),
              status: _status,
              excerpt: _excerpt.text,
              seoTitle: _seoTitle.text,
              seoDescription: _seoDescription.text,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack(context, 'Page saved.');
    } catch (e) {
      if (mounted) _showSnack(context, formatAdminSafeError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _SectionEditorSheet extends StatefulWidget {
  const _SectionEditorSheet({
    required this.page,
    this.section,
    required this.nextSortOrder,
  });

  final MarketingPageRow page;
  final MarketingPageSectionRow? section;
  final int nextSortOrder;

  @override
  State<_SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<_SectionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sectionKey;
  late final TextEditingController _sectionType;
  late final TextEditingController _sortOrder;
  late final TextEditingController _eyebrow;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late MarketingContentStatus _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final section = widget.section;
    _sectionKey = TextEditingController(text: section?.sectionKey ?? '');
    _sectionType =
        TextEditingController(text: section?.sectionType ?? 'content');
    _sortOrder = TextEditingController(
        text: (section?.sortOrder ?? widget.nextSortOrder).toString());
    _eyebrow = TextEditingController(text: section?.eyebrow ?? '');
    _title = TextEditingController(text: section?.title ?? '');
    _body = TextEditingController(text: section?.body ?? '');
    _status = section?.status ?? MarketingContentStatus.draft;
  }

  @override
  void dispose() {
    _sectionKey.dispose();
    _sectionType.dispose();
    _sortOrder.dispose();
    _eyebrow.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorShell(
      title: widget.section == null ? 'Add section' : 'Edit section',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextField(
                controller: _sectionKey, label: 'Section key', required: true),
            _TextField(
                controller: _sectionType,
                label: 'Section type',
                required: true),
            _TextField(
                controller: _sortOrder, label: 'Sort order', required: true),
            _StatusField(
                value: _status,
                onChanged: (value) => setState(() => _status = value)),
            _TextField(controller: _eyebrow, label: 'Eyebrow'),
            _TextField(controller: _title, label: 'Title'),
            _TextField(controller: _body, label: 'Body', maxLines: 5),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await context.read<AdminStore>().saveMarketingSection(
            MarketingSectionDraft(
              id: widget.section?.id,
              pageId: widget.page.id,
              sectionKey: cmsSlugFromTitle(_sectionKey.text),
              sectionType: _sectionType.text.trim(),
              sortOrder:
                  int.tryParse(_sortOrder.text.trim()) ?? widget.nextSortOrder,
              status: _status,
              eyebrow: _eyebrow.text,
              title: _title.text,
              body: _body.text,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack(context, 'Section saved.');
    } catch (e) {
      if (mounted) _showSnack(context, formatAdminSafeError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _BlogEditorSheet extends StatefulWidget {
  const _BlogEditorSheet({this.post, required this.categories});

  final MarketingBlogPostRow? post;
  final List<MarketingBlogCategoryRow> categories;

  @override
  State<_BlogEditorSheet> createState() => _BlogEditorSheetState();
}

class _BlogEditorSheetState extends State<_BlogEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _excerpt;
  late final TextEditingController _body;
  late final TextEditingController _seoTitle;
  late final TextEditingController _seoDescription;
  late MarketingContentStatus _status;
  String? _categoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _title = TextEditingController(text: post?.title ?? '');
    _slug = TextEditingController(text: post?.slug ?? '');
    _excerpt = TextEditingController(text: post?.excerpt ?? '');
    _body = TextEditingController();
    _seoTitle = TextEditingController(text: post?.seoTitle ?? '');
    _seoDescription = TextEditingController(text: post?.seoDescription ?? '');
    _status = post?.status ?? MarketingContentStatus.draft;
    _categoryId = post?.categoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _excerpt.dispose();
    _body.dispose();
    _seoTitle.dispose();
    _seoDescription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorShell(
      title: widget.post == null ? 'New blog post' : 'Edit blog post',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextField(
                controller: _title,
                label: 'Title',
                required: true,
                onChanged: _maybeUpdateSlug),
            _TextField(controller: _slug, label: 'Slug', required: true),
            _StatusField(
                value: _status,
                onChanged: (value) => setState(() => _status = value)),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('No category')),
                for (final category in widget.categories)
                  DropdownMenuItem<String?>(
                      value: category.id, child: Text(category.name)),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            _TextField(controller: _excerpt, label: 'Excerpt'),
            _TextField(controller: _body, label: 'Body draft', maxLines: 6),
            _TextField(controller: _seoTitle, label: 'SEO title'),
            _TextField(
                controller: _seoDescription,
                label: 'SEO description',
                maxLines: 3),
          ],
        ),
      ),
    );
  }

  void _maybeUpdateSlug(String value) {
    if (widget.post != null || _slug.text.trim().isNotEmpty) return;
    _slug.text = cmsSlugFromTitle(value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await context.read<AdminStore>().saveMarketingBlogPost(
            MarketingBlogPostDraft(
              id: widget.post?.id,
              title: _title.text.trim(),
              slug: cmsSlugFromTitle(_slug.text),
              status: _status,
              excerpt: _excerpt.text,
              bodyMarkdown: _body.text,
              categoryId: _categoryId,
              seoTitle: _seoTitle.text,
              seoDescription: _seoDescription.text,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack(context, 'Blog post saved.');
    } catch (e) {
      if (mounted) _showSnack(context, formatAdminSafeError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _EditorShell extends StatelessWidget {
  const _EditorShell({
    required this.title,
    required this.child,
    required this.isSaving,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          maxChildSize: 0.94,
          minChildSize: 0.48,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800))),
                    IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                child,
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.required = false,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
        validator: required
            ? (value) {
                if ((value ?? '').trim().isEmpty) return '$label is required.';
                return null;
              }
            : null,
      ),
    );
  }
}

class _StatusField extends StatelessWidget {
  const _StatusField({required this.value, required this.onChanged});

  final MarketingContentStatus value;
  final ValueChanged<MarketingContentStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<MarketingContentStatus>(
        value: value,
        decoration: const InputDecoration(labelText: 'Status'),
        items: [
          for (final status in MarketingContentStatus.values)
            DropdownMenuItem(value: status, child: Text(status.label)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.title, required this.body, this.action});

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _EmptyWebsiteCmsState extends StatelessWidget {
  const _EmptyWebsiteCmsState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyPanel(
      icon: Icons.web_outlined,
      title: 'No CMS data yet',
      body: 'Refresh to probe the live marketing tables.',
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 44,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.tokens.surfaceElevated,
        border: Border.all(color: context.tokens.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MarketingContentStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (status) {
      MarketingContentStatus.published => (
          context.tokens.success.withValues(alpha: 0.16),
          context.tokens.success,
          Icons.check_circle_outline
        ),
      MarketingContentStatus.scheduled => (
          context.tokens.info.withValues(alpha: 0.14),
          context.tokens.info,
          Icons.schedule_outlined
        ),
      MarketingContentStatus.review => (
          context.tokens.warning.withValues(alpha: 0.16),
          context.tokens.warning,
          Icons.rate_review_outlined
        ),
      MarketingContentStatus.archived => (
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
          Icons.archive_outlined
        ),
      MarketingContentStatus.draft => (
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
          Icons.edit_note_outlined
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.18))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(status.label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TableStatusChip extends StatelessWidget {
  const _TableStatusChip({required this.status});

  final WebsiteCmsTableOverallStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    switch (status) {
      case WebsiteCmsTableOverallStatus.live:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        icon = Icons.check_circle_outline;
        break;
      case WebsiteCmsTableOverallStatus.empty:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        icon = Icons.inbox_outlined;
        break;
      case WebsiteCmsTableOverallStatus.missingUi:
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        icon = Icons.web_asset_off_outlined;
        break;
      case WebsiteCmsTableOverallStatus.missingTable:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        icon = Icons.table_chart_outlined;
        break;
      case WebsiteCmsTableOverallStatus.error:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.14))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(status.label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

Future<void> _openPageEditor(BuildContext context, {MarketingPageRow? page}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AdminStore>(),
      child: _PageEditorSheet(page: page),
    ),
  );
}

Future<void> _openSectionEditor(
  BuildContext context, {
  required MarketingPageRow page,
  MarketingPageSectionRow? section,
  required int nextSortOrder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AdminStore>(),
      child: _SectionEditorSheet(
          page: page, section: section, nextSortOrder: nextSortOrder),
    ),
  );
}

Future<void> _openBlogEditor(
  BuildContext context, {
  MarketingBlogPostRow? post,
  required List<MarketingBlogCategoryRow> categories,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AdminStore>(),
      child: _BlogEditorSheet(post: post, categories: categories),
    ),
  );
}

Future<void> _changeStatus(
  BuildContext context,
  String resourceType,
  String resourceId,
  MarketingContentStatus status,
) async {
  try {
    await context.read<AdminStore>().updateMarketingContentStatus(
          resourceType: resourceType,
          resourceId: resourceId,
          status: status,
        );
    if (context.mounted) _showSnack(context, 'CMS status updated.');
  } catch (e) {
    if (context.mounted) _showSnack(context, formatAdminSafeError(e));
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

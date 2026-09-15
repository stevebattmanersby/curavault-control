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

enum WebsiteCmsSection {
  status,
  pages,
  blog,
  seo,
  pricing,
  faqs,
  testimonials,
  campaigns,
  assets;

  String get title => switch (this) {
        WebsiteCmsSection.status => 'Website CMS',
        WebsiteCmsSection.pages => 'Website • Pages',
        WebsiteCmsSection.blog => 'Website • Blog',
        WebsiteCmsSection.seo => 'Website • SEO',
        WebsiteCmsSection.pricing => 'Website • Pricing',
        WebsiteCmsSection.faqs => 'Website • FAQs',
        WebsiteCmsSection.testimonials => 'Website • Testimonials',
        WebsiteCmsSection.campaigns => 'Website • Campaigns',
        WebsiteCmsSection.assets => 'Website • Assets',
      };

  String get subtitle => switch (this) {
        WebsiteCmsSection.status =>
          'Manage public website content. Public access is limited to published content only.',
        WebsiteCmsSection.pages =>
          'Manage marketing pages. Unpublished drafts are never exposed publicly.',
        WebsiteCmsSection.blog =>
          'Create and publish blog posts. Avoid unverified medical or compliance claims.',
        WebsiteCmsSection.seo =>
          'Global SEO defaults, sitemap toggles, and schema settings.',
        WebsiteCmsSection.pricing =>
          'Manage pricing plans shown on the public marketing website.',
        WebsiteCmsSection.faqs =>
          'FAQ categories and entries for the marketing site.',
        WebsiteCmsSection.testimonials => 'Customer testimonials library.',
        WebsiteCmsSection.campaigns =>
          'Create campaign landing overlays without code changes.',
        WebsiteCmsSection.assets =>
          'Asset library backend status and implementation handoff.',
      };

  String get tableName => switch (this) {
        WebsiteCmsSection.status => 'marketing_tables',
        WebsiteCmsSection.pages => 'marketing_pages',
        WebsiteCmsSection.blog => 'marketing_blog_posts',
        WebsiteCmsSection.seo => 'marketing_seo_settings',
        WebsiteCmsSection.pricing => 'marketing_pricing_plans',
        WebsiteCmsSection.faqs => 'marketing_faqs',
        WebsiteCmsSection.testimonials => 'marketing_testimonials',
        WebsiteCmsSection.campaigns => 'marketing_campaigns',
        WebsiteCmsSection.assets => 'asset_library_backend',
      };
}

class WebsiteCmsStatusPage extends StatelessWidget {
  const WebsiteCmsStatusPage(
      {super.key, this.section = WebsiteCmsSection.status});

  final WebsiteCmsSection section;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final role = context.watch<AdminAuthStore>().role;
    final snap = store.websiteCms;
    final cms = store.marketingCms;
    final isLoading = store.isLoading || store.isWebsiteCmsLoading;
    final canManage = AdminRbac.canManageMarketingCms(role);

    return AdminPageScaffold(
      title: section.title,
      subtitle: section.subtitle,
      actions: [
        AdminDataSourceBadge(
            status: store.dataSource(AdminDataSourceKey.websiteCms)),
        const SizedBox(width: AppSpacing.sm),
        if (section == WebsiteCmsSection.pages && canManage) ...[
          FilledButton.icon(
            onPressed: () => _openPageEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (section == WebsiteCmsSection.blog && canManage) ...[
          FilledButton.icon(
            onPressed: () => _openBlogEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (_canCreateInSection(section) && canManage) ...[
          FilledButton.icon(
            onPressed: () => _openCmsSectionEditor(context, section),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
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
                          snapshot: snap,
                          cms: cms,
                          canManage: canManage,
                          section: section),
    );
  }
}

class _WebsiteCmsWorkspace extends StatefulWidget {
  const _WebsiteCmsWorkspace({
    required this.snapshot,
    required this.cms,
    required this.canManage,
    required this.section,
  });

  final WebsiteCmsStatusSnapshot snapshot;
  final MarketingCmsSnapshot cms;
  final bool canManage;
  final WebsiteCmsSection section;

  @override
  State<_WebsiteCmsWorkspace> createState() => _WebsiteCmsWorkspaceState();
}

class _WebsiteCmsWorkspaceState extends State<_WebsiteCmsWorkspace> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final cms = widget.cms;
    final section = widget.section;

    if (section == WebsiteCmsSection.pages) {
      return _WebsiteSectionShell(
        section: section,
        snapshot: widget.snapshot,
        child: _PagesTab(cms: cms, canManage: widget.canManage, compact: true),
      );
    }

    if (section == WebsiteCmsSection.blog) {
      return _WebsiteSectionShell(
        section: section,
        snapshot: widget.snapshot,
        child: _BlogTab(cms: cms, canManage: widget.canManage, compact: true),
      );
    }

    if (section != WebsiteCmsSection.status) {
      return _WebsiteSectionShell(
        section: section,
        snapshot: widget.snapshot,
        child: _WebsiteTableWorkspace(
          section: section,
          snapshot: widget.snapshot,
          cms: cms,
          canManage: widget.canManage,
        ),
      );
    }

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

class _WebsiteSectionShell extends StatelessWidget {
  const _WebsiteSectionShell(
      {required this.section, required this.snapshot, required this.child});

  final WebsiteCmsSection section;
  final WebsiteCmsStatusSnapshot snapshot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final row = _statusRowForSection(snapshot, section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WebsiteSectionStatusCard(section: section, row: row),
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: child),
      ],
    );
  }
}

class _WebsiteSectionStatusCard extends StatelessWidget {
  const _WebsiteSectionStatusCard({required this.section, required this.row});

  final WebsiteCmsSection section;
  final WebsiteCmsTableStatusRow? row;

  @override
  Widget build(BuildContext context) {
    final err = (row?.safeErrorMessage ?? '').trim();
    final rowCount = row?.rowCount;
    final refreshed = row?.latestUpdatedAt;
    final status = row?.status ?? WebsiteCmsTableOverallStatus.missingTable;
    return AdminCard(
      header: Row(
        children: [
          Expanded(
              child: Text(
                  '${_marketingLabelForSection(section)} • Data source status',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800))),
          _TableStatusChip(status: status),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(
              label: 'data source',
              value: row?.exists == true ? 'live' : 'error'),
          _StatusLine(
              label: 'table / query name',
              value: row?.tableName ?? section.tableName),
          _StatusLine(
              label: 'row count',
              value: rowCount == null
                  ? '-'
                  : AdminFormatters.compactInt(rowCount)),
          _StatusLine(
              label: 'last refreshed',
              value: refreshed == null
                  ? '-'
                  : AdminFormatters.dateTime(refreshed)),
          if (err.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(err,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
              width: 160,
              child: Text(label,
                  style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700))),
          Expanded(
              child: Text(value,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _CmsChecklist extends StatelessWidget {
  const _CmsChecklist({required this.items});

  final List<(String, bool)> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 8),
            decoration: BoxDecoration(
              color: item.$2
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: item.$2
                    ? cs.primary.withValues(alpha: 0.22)
                    : cs.error.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.$2 ? Icons.check_circle_outline : Icons.error_outline,
                  size: 16,
                  color: item.$2 ? cs.onPrimaryContainer : cs.onErrorContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  item.$1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: item.$2
                            ? cs.onPrimaryContainer
                            : cs.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WebsiteTableWorkspace extends StatelessWidget {
  const _WebsiteTableWorkspace({
    required this.section,
    required this.snapshot,
    required this.cms,
    required this.canManage,
  });

  final WebsiteCmsSection section;
  final WebsiteCmsStatusSnapshot snapshot;
  final MarketingCmsSnapshot cms;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final row = _statusRowForSection(snapshot, section);
    final cs = Theme.of(context).colorScheme;
    final content = _sectionControlCopy(section);
    final exists = row?.exists == true;
    final ready = exists && row?.status != WebsiteCmsTableOverallStatus.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminCard(
            header: Row(
              children: [
                Icon(_iconForSection(section), color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(content.$1,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                _TableStatusChip(
                    status: row?.status ??
                        WebsiteCmsTableOverallStatus.missingTable),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content.$2,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _MiniChip(
                        icon: Icons.table_chart_outlined,
                        label: section.tableName),
                    _MiniChip(
                        icon: Icons.fact_check_outlined,
                        label: exists ? 'Live table' : 'Table missing'),
                    _MiniChip(
                        icon: Icons.admin_panel_settings_outlined,
                        label:
                            canManage ? 'Admin writes allowed' : 'Read-only'),
                    _MiniChip(
                        icon: Icons.format_list_numbered_outlined,
                        label:
                            '${AdminFormatters.compactInt(row?.rowCount ?? 0)} rows'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _CmsChecklist(
                  items: [
                    ('Supabase table reachable', exists),
                    ('RLS metadata visible', row?.rlsEnabled != null),
                    ('Control route connected', row?.uiConnected == true),
                    ('No table probe error', ready),
                  ],
                ),
              ],
            )),
        const SizedBox(height: AppSpacing.md),
        Expanded(
            child: _ManagementList(
                section: section, cms: cms, canManage: canManage)),
      ],
    );
  }
}

bool _canCreateInSection(WebsiteCmsSection section) => switch (section) {
      WebsiteCmsSection.pricing ||
      WebsiteCmsSection.faqs ||
      WebsiteCmsSection.testimonials ||
      WebsiteCmsSection.campaigns =>
        true,
      _ => false,
    };

WebsiteCmsTableStatusRow? _statusRowForSection(
    WebsiteCmsStatusSnapshot snapshot, WebsiteCmsSection section) {
  for (final row in snapshot.rows) {
    if (row.tableName == section.tableName) return row;
  }
  return null;
}

String _marketingLabelForSection(WebsiteCmsSection section) =>
    switch (section) {
      WebsiteCmsSection.pages => 'Marketing pages',
      WebsiteCmsSection.blog => 'Marketing blog posts',
      WebsiteCmsSection.seo => 'Global SEO settings',
      WebsiteCmsSection.pricing => 'Pricing plans',
      WebsiteCmsSection.faqs => 'Marketing FAQs',
      WebsiteCmsSection.testimonials => 'Marketing testimonials',
      WebsiteCmsSection.campaigns => 'Marketing campaigns',
      WebsiteCmsSection.assets => 'Marketing assets',
      WebsiteCmsSection.status => 'Marketing CMS',
    };

IconData _iconForSection(WebsiteCmsSection section) => switch (section) {
      WebsiteCmsSection.pages => Icons.web_asset_outlined,
      WebsiteCmsSection.blog => Icons.article_outlined,
      WebsiteCmsSection.seo => Icons.manage_search_outlined,
      WebsiteCmsSection.pricing => Icons.sell_outlined,
      WebsiteCmsSection.faqs => Icons.quiz_outlined,
      WebsiteCmsSection.testimonials => Icons.reviews_outlined,
      WebsiteCmsSection.campaigns => Icons.campaign_outlined,
      WebsiteCmsSection.assets => Icons.photo_library_outlined,
      WebsiteCmsSection.status => Icons.web_outlined,
    };

(String, String) _sectionControlCopy(WebsiteCmsSection section) =>
    switch (section) {
      WebsiteCmsSection.seo => (
          'SEO controls',
          'Review live SEO table readiness and keep public metadata changes behind the existing admin CMS authorization path.'
        ),
      WebsiteCmsSection.pricing => (
          'Pricing controls',
          'Inspect whether pricing copy can be managed from the Control Site before the public website consumes it.'
        ),
      WebsiteCmsSection.faqs => (
          'FAQ controls',
          'Inspect FAQ readiness, publication status, and admin-write availability without exposing user or health data.'
        ),
      WebsiteCmsSection.testimonials => (
          'Testimonial controls',
          'Track testimonial CMS readiness and ensure publication stays on the reviewed marketing path.'
        ),
      WebsiteCmsSection.campaigns => (
          'Campaign controls',
          'Inspect campaign table readiness for future landing content, scheduling, and attribution work.'
        ),
      WebsiteCmsSection.assets => (
          'Assets backend handoff',
          'Asset uploads and media metadata require a separately reviewed backend/storage implementation.'
        ),
      WebsiteCmsSection.pages ||
      WebsiteCmsSection.blog ||
      WebsiteCmsSection.status =>
        (
          'No content yet',
          'Create content from the page action when you are ready.'
        ),
    };

class _ManagementList extends StatelessWidget {
  const _ManagementList({
    required this.section,
    required this.cms,
    required this.canManage,
  });

  final WebsiteCmsSection section;
  final MarketingCmsSnapshot cms;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final items = switch (section) {
      WebsiteCmsSection.seo => <Widget>[
          _GlobalSeoCard(settings: cms.seoSettings, canManage: canManage),
          ...cms.pages
              .map((page) => _SeoCard(page: page, canManage: canManage)),
          ...cms.blogPosts
              .map((post) => _BlogSeoCard(post: post, canManage: canManage)),
        ],
      WebsiteCmsSection.pricing => cms.pricingPlans
          .map((row) => _PricingCard(row: row, canManage: canManage))
          .toList(),
      WebsiteCmsSection.faqs => cms.faqs
          .map((row) => _FaqCard(row: row, canManage: canManage))
          .toList(),
      WebsiteCmsSection.testimonials => cms.testimonials
          .map((row) => _TestimonialCard(row: row, canManage: canManage))
          .toList(),
      WebsiteCmsSection.campaigns => cms.campaigns
          .map((row) => _CampaignCard(row: row, canManage: canManage))
          .toList(),
      WebsiteCmsSection.assets => const <Widget>[
          _AssetsBackendHandoffCard(),
        ],
      _ => const <Widget>[],
    };

    if (items.isEmpty) {
      return _EmptyPanel(
        icon: _iconForSection(section),
        title: section == WebsiteCmsSection.assets
            ? 'No media assets yet'
            : 'No CMS records yet',
        body: section == WebsiteCmsSection.assets
            ? 'Asset uploads require storage/upload infrastructure. Existing asset metadata will appear here when available.'
            : 'Create the first record from the page action when content is ready.',
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _SeoCard extends StatelessWidget {
  const _SeoCard({required this.page, required this.canManage});

  final MarketingPageRow page;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return _RecordCard(
      title: page.title,
      subtitle: '/${page.slug}',
      chips: [
        _MiniChip(icon: Icons.web_outlined, label: 'Page'),
        _MiniChip(
            icon: Icons.title_outlined,
            label: page.seoTitle?.isNotEmpty == true
                ? 'SEO title set'
                : 'SEO title missing'),
        _MiniChip(
            icon: Icons.notes_outlined,
            label: page.seoDescription?.isNotEmpty == true
                ? 'Description set'
                : 'Description missing'),
      ],
      action: canManage
          ? OutlinedButton.icon(
              onPressed: () => _openPageEditor(context, page: page),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit SEO'),
            )
          : null,
    );
  }
}

class _GlobalSeoCard extends StatelessWidget {
  const _GlobalSeoCard({required this.settings, required this.canManage});

  final MarketingSeoSettingsRow? settings;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final row = settings;
    return _RecordCard(
      title: 'Global SEO',
      subtitle: row == null
          ? 'No global SEO settings row is visible.'
          : [
              row.siteName,
              row.defaultTitle,
              row.canonicalBaseUrl,
            ].where((value) => value?.isNotEmpty == true).join(' · '),
      chips: [
        const _MiniChip(icon: Icons.public_outlined, label: 'Global defaults'),
        _MiniChip(
            icon: Icons.title_outlined,
            label: row?.defaultTitle?.isNotEmpty == true
                ? 'Default title set'
                : 'Default title missing'),
        _MiniChip(
            icon: Icons.map_outlined,
            label: row?.sitemapIncludePages == true
                ? 'Pages in sitemap'
                : 'Pages sitemap off'),
      ],
      action: canManage && row != null
          ? OutlinedButton.icon(
              onPressed: () => _openSeoSettingsEditor(context, settings: row),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit global SEO'),
            )
          : null,
    );
  }
}

class _BlogSeoCard extends StatelessWidget {
  const _BlogSeoCard({required this.post, required this.canManage});

  final MarketingBlogPostRow post;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return _RecordCard(
      title: post.title,
      subtitle: '/blog/${post.slug}',
      chips: [
        _MiniChip(icon: Icons.article_outlined, label: 'Blog post'),
        _MiniChip(
            icon: Icons.title_outlined,
            label: post.seoTitle?.isNotEmpty == true
                ? 'SEO title set'
                : 'SEO title missing'),
        _MiniChip(
            icon: Icons.notes_outlined,
            label: post.seoDescription?.isNotEmpty == true
                ? 'Description set'
                : 'Description missing'),
      ],
      action: canManage
          ? OutlinedButton.icon(
              onPressed: () => _openBlogEditor(context, post: post),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit SEO'),
            )
          : null,
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.row, required this.canManage});
  final MarketingPricingPlanRow row;
  final bool canManage;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: row.name,
        subtitle: row.description ?? row.planKey,
        chips: [
          _MiniChip(icon: Icons.key_outlined, label: row.planKey),
          _MiniChip(icon: Icons.euro_outlined, label: _priceLabel(row)),
          _MiniChip(
              icon: Icons.toggle_on_outlined,
              label: row.isActive ? 'Active' : 'Inactive'),
          if (row.isFeatured)
            const _MiniChip(icon: Icons.star_outline, label: 'Featured'),
        ],
        action: canManage
            ? OutlinedButton.icon(
                onPressed: () => _openPricingEditor(context, row: row),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              )
            : null,
      );
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.row, required this.canManage});
  final MarketingFaqRow row;
  final bool canManage;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: row.question,
        subtitle: row.answer,
        chips: [
          _MiniChip(
              icon: Icons.category_outlined,
              label: row.category ?? 'No category'),
          _MiniChip(
              icon: Icons.public_outlined,
              label: row.isPublished ? 'Published' : 'Draft'),
          _MiniChip(icon: Icons.sort_outlined, label: 'Order ${row.sortOrder}'),
        ],
        action: canManage
            ? OutlinedButton.icon(
                onPressed: () => _openFaqEditor(context, row: row),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              )
            : null,
      );
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.row, required this.canManage});
  final MarketingTestimonialRow row;
  final bool canManage;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: row.name?.isNotEmpty == true ? row.name! : 'Unnamed testimonial',
        subtitle: row.quote,
        chips: [
          _MiniChip(icon: Icons.badge_outlined, label: row.role ?? 'No role'),
          _MiniChip(
              icon: Icons.business_outlined,
              label: row.organisation ?? 'No organisation'),
          _MiniChip(
              icon: Icons.public_outlined,
              label: row.isPublished ? 'Published' : 'Draft'),
        ],
        action: canManage
            ? OutlinedButton.icon(
                onPressed: () => _openTestimonialEditor(context, row: row),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              )
            : null,
      );
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.row, required this.canManage});
  final MarketingCampaignRow row;
  final bool canManage;

  @override
  Widget build(BuildContext context) => _RecordCard(
        title: row.name,
        subtitle: row.headline ?? row.campaignKey,
        chips: [
          _MiniChip(icon: Icons.key_outlined, label: row.campaignKey),
          _StatusChip(status: row.status),
          _MiniChip(
              icon: Icons.link_outlined,
              label: row.landingPageSlug ?? 'No landing page'),
          _MiniChip(
              icon: Icons.campaign_outlined,
              label: row.utmCampaign ?? 'No UTM campaign'),
        ],
        action: canManage
            ? OutlinedButton.icon(
                onPressed: () => _openCampaignEditor(context, row: row),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              )
            : null,
      );
}

class _AssetsBackendHandoffCard extends StatelessWidget {
  const _AssetsBackendHandoffCard();

  @override
  Widget build(BuildContext context) => const _RecordCard(
        title: 'Asset library backend not yet provisioned',
        subtitle:
            'Upload and media metadata management needs a separately reviewed backend/storage implementation before Control can manage assets.',
        chips: [
          _MiniChip(
              icon: Icons.storage_outlined, label: 'Backend handoff required'),
          _MiniChip(icon: Icons.lock_outline, label: 'No upload UI exposed'),
          _MiniChip(icon: Icons.fact_check_outlined, label: 'CMS still loads'),
        ],
      );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.title,
    required this.subtitle,
    required this.chips,
    this.action,
  });

  final String title;
  final String subtitle;
  final List<Widget> chips;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      header: Row(
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (action != null) action!,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: chips),
        ],
      ),
    );
  }
}

String _priceLabel(MarketingPricingPlanRow row) {
  final monthly = row.monthlyPrice == null ? '-' : row.monthlyPrice.toString();
  final annual = row.annualPrice == null ? '-' : row.annualPrice.toString();
  return '$monthly / mo, $annual / yr ${row.currency}';
}

class _PagesTab extends StatelessWidget {
  const _PagesTab(
      {required this.cms, required this.canManage, this.compact = false});

  final MarketingCmsSnapshot cms;
  final bool canManage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!compact) ...[
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
        ],
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
  const _BlogTab(
      {required this.cms, required this.canManage, this.compact = false});

  final MarketingCmsSnapshot cms;
  final bool canManage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!compact) ...[
          _TabHeader(
            title: 'Blog',
            body: canManage
                ? 'Prepare launch posts, SEO summaries, and publication status.'
                : 'Read-only blog inspection.',
            action: canManage
                ? FilledButton.icon(
                    onPressed: () => _openBlogEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('New post'),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
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
                subtitle: Text(
                    '${section.sectionType} · ${section.isEnabled ? 'Enabled' : 'Disabled'}'),
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
    required this.canManage,
  });

  final MarketingBlogPostRow post;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      header: _ContentHeader(
        title: post.title,
        slug: '/blog/${post.slug}',
        status: post.status,
        updatedAt: post.updatedAt,
        canManage: canManage,
        onEdit: () => _openBlogEditor(context, post: post),
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
                  label: post.category?.isNotEmpty == true
                      ? post.category!
                      : 'No category'),
              _MiniChip(
                  icon: Icons.sell_outlined,
                  label: post.tags.isEmpty
                      ? 'No tags'
                      : '${post.tags.length} tags'),
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
  late final TextEditingController _seoTitle;
  late final TextEditingController _seoDescription;
  late final TextEditingController _ogTitle;
  late final TextEditingController _ogDescription;
  late final TextEditingController _ogImageUrl;
  late final TextEditingController _canonicalUrl;
  late MarketingContentStatus _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final page = widget.page;
    _title = TextEditingController(text: page?.title ?? '');
    _slug = TextEditingController(text: page?.slug ?? '');
    _seoTitle = TextEditingController(text: page?.seoTitle ?? '');
    _seoDescription = TextEditingController(text: page?.seoDescription ?? '');
    _ogTitle = TextEditingController(text: page?.ogTitle ?? '');
    _ogDescription = TextEditingController(text: page?.ogDescription ?? '');
    _ogImageUrl = TextEditingController(text: page?.ogImageUrl ?? '');
    _canonicalUrl = TextEditingController(text: page?.canonicalUrl ?? '');
    _status = page?.status ?? MarketingContentStatus.draft;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _seoTitle.dispose();
    _seoDescription.dispose();
    _ogTitle.dispose();
    _ogDescription.dispose();
    _ogImageUrl.dispose();
    _canonicalUrl.dispose();
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
            _TextField(controller: _seoTitle, label: 'SEO title'),
            _TextField(
                controller: _seoDescription,
                label: 'SEO description',
                maxLines: 3),
            _TextField(controller: _ogTitle, label: 'Open Graph title'),
            _TextField(
                controller: _ogDescription,
                label: 'Open Graph description',
                maxLines: 3),
            _TextField(controller: _ogImageUrl, label: 'Open Graph image URL'),
            _TextField(controller: _canonicalUrl, label: 'Canonical URL'),
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
              seoTitle: _seoTitle.text,
              seoDescription: _seoDescription.text,
              ogTitle: _ogTitle.text,
              ogDescription: _ogDescription.text,
              ogImageUrl: _ogImageUrl.text,
              canonicalUrl: _canonicalUrl.text,
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
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _body;
  late final TextEditingController _ctaLabel;
  late final TextEditingController _ctaUrl;
  late final TextEditingController _mediaUrl;
  late bool _isEnabled;
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
    _title = TextEditingController(text: section?.title ?? '');
    _subtitle = TextEditingController(text: section?.subtitle ?? '');
    _body = TextEditingController(text: section?.body ?? '');
    _ctaLabel = TextEditingController(text: section?.ctaLabel ?? '');
    _ctaUrl = TextEditingController(text: section?.ctaUrl ?? '');
    _mediaUrl = TextEditingController(text: section?.mediaUrl ?? '');
    _isEnabled = section?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _sectionKey.dispose();
    _sectionType.dispose();
    _sortOrder.dispose();
    _title.dispose();
    _subtitle.dispose();
    _body.dispose();
    _ctaLabel.dispose();
    _ctaUrl.dispose();
    _mediaUrl.dispose();
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
            _BoolField(
                label: 'Enabled',
                value: _isEnabled,
                onChanged: (value) => setState(() => _isEnabled = value)),
            _TextField(controller: _title, label: 'Title'),
            _TextField(controller: _subtitle, label: 'Subtitle'),
            _TextField(controller: _body, label: 'Body', maxLines: 5),
            _TextField(controller: _ctaLabel, label: 'CTA label'),
            _TextField(controller: _ctaUrl, label: 'CTA URL'),
            _TextField(controller: _mediaUrl, label: 'Media URL'),
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
              isEnabled: _isEnabled,
              title: _title.text,
              subtitle: _subtitle.text,
              body: _body.text,
              ctaLabel: _ctaLabel.text,
              ctaUrl: _ctaUrl.text,
              mediaUrl: _mediaUrl.text,
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
  const _BlogEditorSheet({this.post});

  final MarketingBlogPostRow? post;

  @override
  State<_BlogEditorSheet> createState() => _BlogEditorSheetState();
}

class _BlogEditorSheetState extends State<_BlogEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _excerpt;
  late final TextEditingController _body;
  late final TextEditingController _category;
  late final TextEditingController _tags;
  late final TextEditingController _seoTitle;
  late final TextEditingController _seoDescription;
  late final TextEditingController _ogImageUrl;
  late MarketingContentStatus _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _title = TextEditingController(text: post?.title ?? '');
    _slug = TextEditingController(text: post?.slug ?? '');
    _excerpt = TextEditingController(text: post?.excerpt ?? '');
    _body = TextEditingController();
    _category = TextEditingController(text: post?.category ?? '');
    _tags = TextEditingController(text: post?.tags.join(', ') ?? '');
    _seoTitle = TextEditingController(text: post?.seoTitle ?? '');
    _seoDescription = TextEditingController(text: post?.seoDescription ?? '');
    _ogImageUrl = TextEditingController(text: post?.ogImageUrl ?? '');
    _status = post?.status ?? MarketingContentStatus.draft;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _excerpt.dispose();
    _body.dispose();
    _category.dispose();
    _tags.dispose();
    _seoTitle.dispose();
    _seoDescription.dispose();
    _ogImageUrl.dispose();
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
            _TextField(controller: _category, label: 'Category'),
            _TextField(controller: _tags, label: 'Tags (comma-separated)'),
            _TextField(controller: _excerpt, label: 'Excerpt'),
            _TextField(controller: _body, label: 'Body draft', maxLines: 6),
            _TextField(controller: _seoTitle, label: 'SEO title'),
            _TextField(
                controller: _seoDescription,
                label: 'SEO description',
                maxLines: 3),
            _TextField(controller: _ogImageUrl, label: 'Open Graph image URL'),
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
              category: _category.text,
              tags: _tags.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(),
              seoTitle: _seoTitle.text,
              seoDescription: _seoDescription.text,
              ogImageUrl: _ogImageUrl.text,
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

class _SeoSettingsEditorSheet extends StatefulWidget {
  const _SeoSettingsEditorSheet({required this.settings});

  final MarketingSeoSettingsRow settings;

  @override
  State<_SeoSettingsEditorSheet> createState() =>
      _SeoSettingsEditorSheetState();
}

class _SeoSettingsEditorSheetState extends State<_SeoSettingsEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _siteName;
  late final TextEditingController _defaultTitle;
  late final TextEditingController _defaultDescription;
  late final TextEditingController _defaultOgImage;
  late final TextEditingController _twitterHandle;
  late final TextEditingController _canonicalBaseUrl;
  late final TextEditingController _robotsPolicy;
  late final TextEditingController _schemaOrganisationName;
  late final TextEditingController _schemaWebsiteUrl;
  late final TextEditingController _schemaLogoUrl;
  late final TextEditingController _schemaSupportEmail;
  late bool _sitemapIncludePages;
  late bool _sitemapIncludeBlog;
  late bool _sitemapIncludeCampaigns;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final row = widget.settings;
    _siteName = TextEditingController(text: row.siteName ?? '');
    _defaultTitle = TextEditingController(text: row.defaultTitle ?? '');
    _defaultDescription =
        TextEditingController(text: row.defaultDescription ?? '');
    _defaultOgImage = TextEditingController(text: row.defaultOgImage ?? '');
    _twitterHandle = TextEditingController(text: row.twitterHandle ?? '');
    _canonicalBaseUrl = TextEditingController(text: row.canonicalBaseUrl ?? '');
    _robotsPolicy = TextEditingController(text: row.robotsPolicy ?? '');
    _schemaOrganisationName =
        TextEditingController(text: row.schemaOrganisationName ?? '');
    _schemaWebsiteUrl = TextEditingController(text: row.schemaWebsiteUrl ?? '');
    _schemaLogoUrl = TextEditingController(text: row.schemaLogoUrl ?? '');
    _schemaSupportEmail =
        TextEditingController(text: row.schemaSupportEmail ?? '');
    _sitemapIncludePages = row.sitemapIncludePages;
    _sitemapIncludeBlog = row.sitemapIncludeBlog;
    _sitemapIncludeCampaigns = row.sitemapIncludeCampaigns;
  }

  @override
  void dispose() {
    _siteName.dispose();
    _defaultTitle.dispose();
    _defaultDescription.dispose();
    _defaultOgImage.dispose();
    _twitterHandle.dispose();
    _canonicalBaseUrl.dispose();
    _robotsPolicy.dispose();
    _schemaOrganisationName.dispose();
    _schemaWebsiteUrl.dispose();
    _schemaLogoUrl.dispose();
    _schemaSupportEmail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorShell(
      title: 'Edit global SEO',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextField(controller: _siteName, label: 'Site name'),
            _TextField(controller: _defaultTitle, label: 'Default title'),
            _TextField(
                controller: _defaultDescription,
                label: 'Default description',
                maxLines: 3),
            _TextField(
                controller: _defaultOgImage, label: 'Default OG image URL'),
            _TextField(controller: _twitterHandle, label: 'Twitter handle'),
            _TextField(
                controller: _canonicalBaseUrl, label: 'Canonical base URL'),
            _TextField(controller: _robotsPolicy, label: 'Robots policy'),
            _BoolField(
                label: 'Include pages in sitemap',
                value: _sitemapIncludePages,
                onChanged: (value) =>
                    setState(() => _sitemapIncludePages = value)),
            _BoolField(
                label: 'Include blog in sitemap',
                value: _sitemapIncludeBlog,
                onChanged: (value) =>
                    setState(() => _sitemapIncludeBlog = value)),
            _BoolField(
                label: 'Include campaigns in sitemap',
                value: _sitemapIncludeCampaigns,
                onChanged: (value) =>
                    setState(() => _sitemapIncludeCampaigns = value)),
            _TextField(
                controller: _schemaOrganisationName,
                label: 'Schema organisation name'),
            _TextField(
                controller: _schemaWebsiteUrl, label: 'Schema website URL'),
            _TextField(controller: _schemaLogoUrl, label: 'Schema logo URL'),
            _TextField(
                controller: _schemaSupportEmail, label: 'Schema support email'),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await context.read<AdminStore>().saveMarketingSeoSettings(
            MarketingSeoSettingsDraft(
              id: widget.settings.id,
              siteName: _siteName.text,
              defaultTitle: _defaultTitle.text,
              defaultDescription: _defaultDescription.text,
              defaultOgImage: _defaultOgImage.text,
              twitterHandle: _twitterHandle.text,
              canonicalBaseUrl: _canonicalBaseUrl.text,
              robotsPolicy: _robotsPolicy.text,
              sitemapIncludePages: _sitemapIncludePages,
              sitemapIncludeBlog: _sitemapIncludeBlog,
              sitemapIncludeCampaigns: _sitemapIncludeCampaigns,
              schemaOrganisationName: _schemaOrganisationName.text,
              schemaWebsiteUrl: _schemaWebsiteUrl.text,
              schemaLogoUrl: _schemaLogoUrl.text,
              schemaSupportEmail: _schemaSupportEmail.text,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack(context, 'Global SEO saved.');
    } catch (e) {
      if (mounted) _showSnack(context, formatAdminSafeError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _SimpleCmsEditorSheet extends StatefulWidget {
  const _SimpleCmsEditorSheet({required this.section, this.row});

  final WebsiteCmsSection section;
  final Object? row;

  @override
  State<_SimpleCmsEditorSheet> createState() => _SimpleCmsEditorSheetState();
}

class _SimpleCmsEditorSheetState extends State<_SimpleCmsEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  bool _publishedOrActive = false;
  bool _featured = false;
  MarketingContentStatus _status = MarketingContentStatus.draft;

  TextEditingController _controller(String key, [String initial = '']) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    switch (row) {
      case MarketingPricingPlanRow r:
        _controller('planKey', r.planKey);
        _controller('name', r.name);
        _controller('description', r.description ?? '');
        _controller('monthlyPrice', r.monthlyPrice?.toString() ?? '');
        _controller('annualPrice', r.annualPrice?.toString() ?? '');
        _controller('currency', r.currency);
        _controller('features', r.features.join('\n'));
        _controller('sortOrder', r.sortOrder.toString());
        _publishedOrActive = r.isActive;
        _featured = r.isFeatured;
      case MarketingFaqRow r:
        _controller('question', r.question);
        _controller('answer', r.answer);
        _controller('category', r.category ?? '');
        _controller('sortOrder', r.sortOrder.toString());
        _publishedOrActive = r.isPublished;
      case MarketingTestimonialRow r:
        _controller('quote', r.quote);
        _controller('name', r.name ?? '');
        _controller('role', r.role ?? '');
        _controller('organisation', r.organisation ?? '');
        _controller('avatarUrl', r.avatarUrl ?? '');
        _controller('sortOrder', r.sortOrder.toString());
        _publishedOrActive = r.isPublished;
      case MarketingCampaignRow r:
        _controller('campaignKey', r.campaignKey);
        _controller('name', r.name);
        _controller('landingPageSlug', r.landingPageSlug ?? '');
        _controller('headline', r.headline ?? '');
        _controller('subheadline', r.subheadline ?? '');
        _controller('ctaLabel', r.ctaLabel ?? '');
        _controller('ctaUrl', r.ctaUrl ?? '');
        _controller('utmSource', r.utmSource ?? '');
        _controller('utmMedium', r.utmMedium ?? '');
        _controller('utmCampaign', r.utmCampaign ?? '');
        _controller('startsAt', r.startsAt?.toIso8601String() ?? '');
        _controller('endsAt', r.endsAt?.toIso8601String() ?? '');
        _status = r.status;
      default:
        _controller('sortOrder', '0');
        _controller('currency', 'EUR');
        _publishedOrActive =
            widget.section == WebsiteCmsSection.pricing ? true : false;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditorShell(
      title:
          widget.row == null ? 'Create ${widget.section.title}' : 'Edit record',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(children: _fieldsForSection()),
      ),
    );
  }

  List<Widget> _fieldsForSection() => switch (widget.section) {
        WebsiteCmsSection.pricing => [
            _TextField(
                controller: _controller('planKey'),
                label: 'Plan key',
                required: true),
            _TextField(
                controller: _controller('name'), label: 'Name', required: true),
            _TextField(
                controller: _controller('description'), label: 'Description'),
            _TextField(
                controller: _controller('monthlyPrice'),
                label: 'Monthly price'),
            _TextField(
                controller: _controller('annualPrice'), label: 'Annual price'),
            _TextField(controller: _controller('currency'), label: 'Currency'),
            _TextField(
                controller: _controller('features'),
                label: 'Features (one per line)',
                maxLines: 5),
            _TextField(
                controller: _controller('sortOrder'), label: 'Sort order'),
            _BoolField(
                label: 'Active',
                value: _publishedOrActive,
                onChanged: (value) =>
                    setState(() => _publishedOrActive = value)),
            _BoolField(
                label: 'Featured',
                value: _featured,
                onChanged: (value) => setState(() => _featured = value)),
          ],
        WebsiteCmsSection.faqs => [
            _TextField(
                controller: _controller('question'),
                label: 'Question',
                required: true),
            _TextField(
                controller: _controller('answer'),
                label: 'Answer',
                required: true,
                maxLines: 5),
            _TextField(controller: _controller('category'), label: 'Category'),
            _TextField(
                controller: _controller('sortOrder'), label: 'Sort order'),
            _BoolField(
                label: 'Published',
                value: _publishedOrActive,
                onChanged: (value) =>
                    setState(() => _publishedOrActive = value)),
          ],
        WebsiteCmsSection.testimonials => [
            _TextField(
                controller: _controller('quote'),
                label: 'Quote',
                required: true,
                maxLines: 5),
            _TextField(controller: _controller('name'), label: 'Name'),
            _TextField(controller: _controller('role'), label: 'Role'),
            _TextField(
                controller: _controller('organisation'), label: 'Organisation'),
            _TextField(
                controller: _controller('avatarUrl'), label: 'Avatar URL'),
            _TextField(
                controller: _controller('sortOrder'), label: 'Sort order'),
            _BoolField(
                label: 'Published',
                value: _publishedOrActive,
                onChanged: (value) =>
                    setState(() => _publishedOrActive = value)),
          ],
        WebsiteCmsSection.campaigns => [
            _TextField(
                controller: _controller('campaignKey'),
                label: 'Campaign key',
                required: true),
            _TextField(
                controller: _controller('name'), label: 'Name', required: true),
            _StatusField(
                value: _status,
                onChanged: (value) => setState(() => _status = value)),
            _TextField(
                controller: _controller('landingPageSlug'),
                label: 'Landing page slug'),
            _TextField(controller: _controller('headline'), label: 'Headline'),
            _TextField(
                controller: _controller('subheadline'), label: 'Subheadline'),
            _TextField(controller: _controller('ctaLabel'), label: 'CTA label'),
            _TextField(controller: _controller('ctaUrl'), label: 'CTA URL'),
            _TextField(
                controller: _controller('utmSource'), label: 'UTM source'),
            _TextField(
                controller: _controller('utmMedium'), label: 'UTM medium'),
            _TextField(
                controller: _controller('utmCampaign'), label: 'UTM campaign'),
            _TextField(
                controller: _controller('startsAt'),
                label: 'Starts at (ISO, optional)'),
            _TextField(
                controller: _controller('endsAt'),
                label: 'Ends at (ISO, optional)'),
          ],
        _ => const <Widget>[],
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final store = context.read<AdminStore>();
      switch (widget.section) {
        case WebsiteCmsSection.pricing:
          final row = widget.row as MarketingPricingPlanRow?;
          await store.saveMarketingPricingPlan(MarketingPricingPlanDraft(
            id: row?.id,
            planKey: _text('planKey'),
            name: _text('name'),
            description: _text('description'),
            monthlyPrice: num.tryParse(_text('monthlyPrice')),
            annualPrice: num.tryParse(_text('annualPrice')),
            currency: _text('currency').isEmpty ? 'EUR' : _text('currency'),
            features: _text('features')
                .split('\n')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(),
            isFeatured: _featured,
            isActive: _publishedOrActive,
            sortOrder: int.tryParse(_text('sortOrder')) ?? 0,
          ));
        case WebsiteCmsSection.faqs:
          final row = widget.row as MarketingFaqRow?;
          await store.saveMarketingFaq(MarketingFaqDraft(
            id: row?.id,
            question: _text('question'),
            answer: _text('answer'),
            category: _text('category'),
            sortOrder: int.tryParse(_text('sortOrder')) ?? 0,
            isPublished: _publishedOrActive,
          ));
        case WebsiteCmsSection.testimonials:
          final row = widget.row as MarketingTestimonialRow?;
          await store.saveMarketingTestimonial(MarketingTestimonialDraft(
            id: row?.id,
            quote: _text('quote'),
            name: _text('name'),
            role: _text('role'),
            organisation: _text('organisation'),
            avatarUrl: _text('avatarUrl'),
            sortOrder: int.tryParse(_text('sortOrder')) ?? 0,
            isPublished: _publishedOrActive,
          ));
        case WebsiteCmsSection.campaigns:
          final row = widget.row as MarketingCampaignRow?;
          await store.saveMarketingCampaign(MarketingCampaignDraft(
            id: row?.id,
            campaignKey: _text('campaignKey'),
            name: _text('name'),
            status: _status,
            landingPageSlug: _text('landingPageSlug'),
            headline: _text('headline'),
            subheadline: _text('subheadline'),
            ctaLabel: _text('ctaLabel'),
            ctaUrl: _text('ctaUrl'),
            utmSource: _text('utmSource'),
            utmMedium: _text('utmMedium'),
            utmCampaign: _text('utmCampaign'),
            startsAt: DateTime.tryParse(_text('startsAt')),
            endsAt: DateTime.tryParse(_text('endsAt')),
          ));
        default:
          break;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack(context, 'CMS record saved.');
    } catch (e) {
      if (mounted) _showSnack(context, formatAdminSafeError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _text(String key) => _controller(key).text.trim();
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
        initialValue: value,
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

class _BoolField extends StatelessWidget {
  const _BoolField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
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
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AdminStore>(),
      child: _BlogEditorSheet(post: post),
    ),
  );
}

Future<void> _openSeoSettingsEditor(
  BuildContext context, {
  required MarketingSeoSettingsRow settings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AdminStore>(),
      child: _SeoSettingsEditorSheet(settings: settings),
    ),
  );
}

Future<void> _openCmsSectionEditor(
  BuildContext context,
  WebsiteCmsSection section, {
  Object? row,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AdminStore>(),
      child: _SimpleCmsEditorSheet(section: section, row: row),
    ),
  );
}

Future<void> _openPricingEditor(BuildContext context,
        {MarketingPricingPlanRow? row}) =>
    _openCmsSectionEditor(context, WebsiteCmsSection.pricing, row: row);

Future<void> _openFaqEditor(BuildContext context, {MarketingFaqRow? row}) =>
    _openCmsSectionEditor(context, WebsiteCmsSection.faqs, row: row);

Future<void> _openTestimonialEditor(BuildContext context,
        {MarketingTestimonialRow? row}) =>
    _openCmsSectionEditor(context, WebsiteCmsSection.testimonials, row: row);

Future<void> _openCampaignEditor(BuildContext context,
        {MarketingCampaignRow? row}) =>
    _openCmsSectionEditor(context, WebsiteCmsSection.campaigns, row: row);

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

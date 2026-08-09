import 'package:flutter/foundation.dart';

enum MarketingContentStatus {
  draft,
  review,
  scheduled,
  published,
  archived;

  String get value => switch (this) {
        MarketingContentStatus.draft => 'draft',
        MarketingContentStatus.review => 'review',
        MarketingContentStatus.scheduled => 'scheduled',
        MarketingContentStatus.published => 'published',
        MarketingContentStatus.archived => 'archived',
      };

  String get label => switch (this) {
        MarketingContentStatus.draft => 'Draft',
        MarketingContentStatus.review => 'In review',
        MarketingContentStatus.scheduled => 'Scheduled',
        MarketingContentStatus.published => 'Published',
        MarketingContentStatus.archived => 'Archived',
      };

  static MarketingContentStatus parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'review':
      case 'in_review':
        return MarketingContentStatus.review;
      case 'scheduled':
        return MarketingContentStatus.scheduled;
      case 'published':
        return MarketingContentStatus.published;
      case 'archived':
        return MarketingContentStatus.archived;
      case 'draft':
      default:
        return MarketingContentStatus.draft;
    }
  }
}

bool isPublishedAndArrived({
  required MarketingContentStatus status,
  required DateTime? publishedAt,
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now().toUtc();
  return status == MarketingContentStatus.published &&
      publishedAt != null &&
      !publishedAt.toUtc().isAfter(effectiveNow);
}

String cmsSlugFromTitle(String input) {
  final lower = input.trim().toLowerCase();
  final slug = lower
      .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'untitled' : slug;
}

@immutable
class MarketingCmsSnapshot {
  const MarketingCmsSnapshot({
    required this.pages,
    required this.sections,
    required this.blogPosts,
    required this.categories,
    required this.generatedAt,
  });

  final List<MarketingPageRow> pages;
  final List<MarketingPageSectionRow> sections;
  final List<MarketingBlogPostRow> blogPosts;
  final List<MarketingBlogCategoryRow> categories;
  final DateTime generatedAt;

  int get publishedPages => pages
      .where((page) => isPublishedAndArrived(
          status: page.status, publishedAt: page.publishedAt))
      .length;

  int get scheduledItems =>
      pages
          .where((page) => page.status == MarketingContentStatus.scheduled)
          .length +
      blogPosts
          .where((post) => post.status == MarketingContentStatus.scheduled)
          .length;

  int get reviewItems =>
      pages
          .where((page) => page.status == MarketingContentStatus.review)
          .length +
      blogPosts
          .where((post) => post.status == MarketingContentStatus.review)
          .length;

  List<MarketingPageSectionRow> sectionsForPage(String pageId) =>
      sections.where((section) => section.pageId == pageId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

@immutable
class MarketingPageRow {
  const MarketingPageRow({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    this.template,
    this.excerpt,
    this.seoTitle,
    this.seoDescription,
    this.publishedAt,
    this.scheduledFor,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String title;
  final MarketingContentStatus status;
  final String? template;
  final String? excerpt;
  final String? seoTitle;
  final String? seoDescription;
  final DateTime? publishedAt;
  final DateTime? scheduledFor;
  final DateTime updatedAt;
  final DateTime createdAt;
}

@immutable
class MarketingPageSectionRow {
  const MarketingPageSectionRow({
    required this.id,
    required this.pageId,
    required this.sectionKey,
    required this.sectionType,
    required this.sortOrder,
    required this.status,
    this.eyebrow,
    this.title,
    this.body,
    required this.updatedAt,
  });

  final String id;
  final String pageId;
  final String sectionKey;
  final String sectionType;
  final int sortOrder;
  final MarketingContentStatus status;
  final String? eyebrow;
  final String? title;
  final String? body;
  final DateTime updatedAt;
}

@immutable
class MarketingBlogCategoryRow {
  const MarketingBlogCategoryRow({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.isActive,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final bool isActive;
}

@immutable
class MarketingBlogPostRow {
  const MarketingBlogPostRow({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    this.excerpt,
    this.categoryId,
    this.seoTitle,
    this.seoDescription,
    this.publishedAt,
    this.scheduledFor,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String title;
  final MarketingContentStatus status;
  final String? excerpt;
  final String? categoryId;
  final String? seoTitle;
  final String? seoDescription;
  final DateTime? publishedAt;
  final DateTime? scheduledFor;
  final DateTime updatedAt;
  final DateTime createdAt;
}

@immutable
class MarketingPageDraft {
  const MarketingPageDraft({
    this.id,
    required this.slug,
    required this.title,
    required this.status,
    this.template = 'marketing_page',
    this.excerpt,
    this.seoTitle,
    this.seoDescription,
    this.scheduledFor,
  });

  final String? id;
  final String slug;
  final String title;
  final MarketingContentStatus status;
  final String template;
  final String? excerpt;
  final String? seoTitle;
  final String? seoDescription;
  final DateTime? scheduledFor;
}

@immutable
class MarketingSectionDraft {
  const MarketingSectionDraft({
    this.id,
    required this.pageId,
    required this.sectionKey,
    required this.sectionType,
    required this.sortOrder,
    required this.status,
    this.eyebrow,
    this.title,
    this.body,
  });

  final String? id;
  final String pageId;
  final String sectionKey;
  final String sectionType;
  final int sortOrder;
  final MarketingContentStatus status;
  final String? eyebrow;
  final String? title;
  final String? body;
}

@immutable
class MarketingBlogPostDraft {
  const MarketingBlogPostDraft({
    this.id,
    required this.slug,
    required this.title,
    required this.status,
    this.excerpt,
    this.bodyMarkdown,
    this.categoryId,
    this.seoTitle,
    this.seoDescription,
    this.scheduledFor,
  });

  final String? id;
  final String slug;
  final String title;
  final MarketingContentStatus status;
  final String? excerpt;
  final String? bodyMarkdown;
  final String? categoryId;
  final String? seoTitle;
  final String? seoDescription;
  final DateTime? scheduledFor;
}

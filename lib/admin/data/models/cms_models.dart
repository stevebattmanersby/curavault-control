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
    required this.seoSettings,
    required this.generatedAt,
    this.pricingPlans = const [],
    this.faqs = const [],
    this.testimonials = const [],
    this.campaigns = const [],
  });

  final List<MarketingPageRow> pages;
  final List<MarketingPageSectionRow> sections;
  final List<MarketingBlogPostRow> blogPosts;
  final MarketingSeoSettingsRow? seoSettings;
  final List<MarketingPricingPlanRow> pricingPlans;
  final List<MarketingFaqRow> faqs;
  final List<MarketingTestimonialRow> testimonials;
  final List<MarketingCampaignRow> campaigns;
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
    this.seoTitle,
    this.seoDescription,
    this.ogTitle,
    this.ogDescription,
    this.ogImageUrl,
    this.canonicalUrl,
    this.publishedAt,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String title;
  final MarketingContentStatus status;
  final String? seoTitle;
  final String? seoDescription;
  final String? ogTitle;
  final String? ogDescription;
  final String? ogImageUrl;
  final String? canonicalUrl;
  final DateTime? publishedAt;
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
    required this.isEnabled,
    this.title,
    this.subtitle,
    this.body,
    this.ctaLabel,
    this.ctaUrl,
    this.mediaUrl,
    required this.updatedAt,
  });

  final String id;
  final String pageId;
  final String sectionKey;
  final String sectionType;
  final int sortOrder;
  final bool isEnabled;
  final String? title;
  final String? subtitle;
  final String? body;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? mediaUrl;
  final DateTime updatedAt;
}

@immutable
class MarketingBlogPostRow {
  const MarketingBlogPostRow({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    this.excerpt,
    this.category,
    this.tags = const [],
    this.seoTitle,
    this.seoDescription,
    this.ogImageUrl,
    this.publishedAt,
    required this.updatedAt,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String title;
  final MarketingContentStatus status;
  final String? excerpt;
  final String? category;
  final List<String> tags;
  final String? seoTitle;
  final String? seoDescription;
  final String? ogImageUrl;
  final DateTime? publishedAt;
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
    this.seoTitle,
    this.seoDescription,
    this.ogTitle,
    this.ogDescription,
    this.ogImageUrl,
    this.canonicalUrl,
  });

  final String? id;
  final String slug;
  final String title;
  final MarketingContentStatus status;
  final String? seoTitle;
  final String? seoDescription;
  final String? ogTitle;
  final String? ogDescription;
  final String? ogImageUrl;
  final String? canonicalUrl;
}

@immutable
class MarketingSectionDraft {
  const MarketingSectionDraft({
    this.id,
    required this.pageId,
    required this.sectionKey,
    required this.sectionType,
    required this.sortOrder,
    required this.isEnabled,
    this.title,
    this.subtitle,
    this.body,
    this.ctaLabel,
    this.ctaUrl,
    this.mediaUrl,
  });

  final String? id;
  final String pageId;
  final String sectionKey;
  final String sectionType;
  final int sortOrder;
  final bool isEnabled;
  final String? title;
  final String? subtitle;
  final String? body;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? mediaUrl;
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
    this.category,
    this.tags = const [],
    this.seoTitle,
    this.seoDescription,
    this.ogImageUrl,
  });

  final String? id;
  final String slug;
  final String title;
  final MarketingContentStatus status;
  final String? excerpt;
  final String? bodyMarkdown;
  final String? category;
  final List<String> tags;
  final String? seoTitle;
  final String? seoDescription;
  final String? ogImageUrl;
}

@immutable
class MarketingSeoSettingsRow {
  const MarketingSeoSettingsRow({
    required this.id,
    this.siteName,
    this.defaultTitle,
    this.defaultDescription,
    this.defaultOgImage,
    this.twitterHandle,
    this.canonicalBaseUrl,
    this.robotsPolicy,
    required this.sitemapIncludePages,
    required this.sitemapIncludeBlog,
    required this.sitemapIncludeCampaigns,
    this.schemaOrganisationName,
    this.schemaWebsiteUrl,
    this.schemaLogoUrl,
    this.schemaSupportEmail,
    required this.updatedAt,
  });

  final String id;
  final String? siteName;
  final String? defaultTitle;
  final String? defaultDescription;
  final String? defaultOgImage;
  final String? twitterHandle;
  final String? canonicalBaseUrl;
  final String? robotsPolicy;
  final bool sitemapIncludePages;
  final bool sitemapIncludeBlog;
  final bool sitemapIncludeCampaigns;
  final String? schemaOrganisationName;
  final String? schemaWebsiteUrl;
  final String? schemaLogoUrl;
  final String? schemaSupportEmail;
  final DateTime updatedAt;
}

@immutable
class MarketingSeoSettingsDraft {
  const MarketingSeoSettingsDraft({
    required this.id,
    this.siteName,
    this.defaultTitle,
    this.defaultDescription,
    this.defaultOgImage,
    this.twitterHandle,
    this.canonicalBaseUrl,
    this.robotsPolicy,
    required this.sitemapIncludePages,
    required this.sitemapIncludeBlog,
    required this.sitemapIncludeCampaigns,
    this.schemaOrganisationName,
    this.schemaWebsiteUrl,
    this.schemaLogoUrl,
    this.schemaSupportEmail,
  });

  final String id;
  final String? siteName;
  final String? defaultTitle;
  final String? defaultDescription;
  final String? defaultOgImage;
  final String? twitterHandle;
  final String? canonicalBaseUrl;
  final String? robotsPolicy;
  final bool sitemapIncludePages;
  final bool sitemapIncludeBlog;
  final bool sitemapIncludeCampaigns;
  final String? schemaOrganisationName;
  final String? schemaWebsiteUrl;
  final String? schemaLogoUrl;
  final String? schemaSupportEmail;
}

@immutable
class MarketingPricingPlanRow {
  const MarketingPricingPlanRow({
    required this.id,
    required this.planKey,
    required this.name,
    this.description,
    this.monthlyPrice,
    this.annualPrice,
    required this.currency,
    this.features = const [],
    required this.isFeatured,
    required this.isActive,
    required this.sortOrder,
    required this.updatedAt,
  });

  final String id;
  final String planKey;
  final String name;
  final String? description;
  final num? monthlyPrice;
  final num? annualPrice;
  final String currency;
  final List<String> features;
  final bool isFeatured;
  final bool isActive;
  final int sortOrder;
  final DateTime updatedAt;
}

@immutable
class MarketingFaqRow {
  const MarketingFaqRow({
    required this.id,
    required this.question,
    required this.answer,
    this.category,
    required this.sortOrder,
    required this.isPublished,
    required this.updatedAt,
  });

  final String id;
  final String question;
  final String answer;
  final String? category;
  final int sortOrder;
  final bool isPublished;
  final DateTime updatedAt;
}

@immutable
class MarketingTestimonialRow {
  const MarketingTestimonialRow({
    required this.id,
    required this.quote,
    this.name,
    this.role,
    this.organisation,
    this.avatarUrl,
    required this.isPublished,
    required this.sortOrder,
    required this.updatedAt,
  });

  final String id;
  final String quote;
  final String? name;
  final String? role;
  final String? organisation;
  final String? avatarUrl;
  final bool isPublished;
  final int sortOrder;
  final DateTime updatedAt;
}

@immutable
class MarketingCampaignRow {
  const MarketingCampaignRow({
    required this.id,
    required this.campaignKey,
    required this.name,
    required this.status,
    this.landingPageSlug,
    this.headline,
    this.subheadline,
    this.ctaLabel,
    this.ctaUrl,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.startsAt,
    this.endsAt,
    required this.updatedAt,
  });

  final String id;
  final String campaignKey;
  final String name;
  final MarketingContentStatus status;
  final String? landingPageSlug;
  final String? headline;
  final String? subheadline;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime updatedAt;
}

@immutable
class MarketingPricingPlanDraft {
  const MarketingPricingPlanDraft({
    this.id,
    required this.planKey,
    required this.name,
    this.description,
    this.monthlyPrice,
    this.annualPrice,
    this.currency = 'EUR',
    this.features = const [],
    this.isFeatured = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String? id;
  final String planKey;
  final String name;
  final String? description;
  final num? monthlyPrice;
  final num? annualPrice;
  final String currency;
  final List<String> features;
  final bool isFeatured;
  final bool isActive;
  final int sortOrder;
}

@immutable
class MarketingFaqDraft {
  const MarketingFaqDraft({
    this.id,
    required this.question,
    required this.answer,
    this.category,
    this.sortOrder = 0,
    this.isPublished = false,
  });

  final String? id;
  final String question;
  final String answer;
  final String? category;
  final int sortOrder;
  final bool isPublished;
}

@immutable
class MarketingTestimonialDraft {
  const MarketingTestimonialDraft({
    this.id,
    required this.quote,
    this.name,
    this.role,
    this.organisation,
    this.avatarUrl,
    this.isPublished = false,
    this.sortOrder = 0,
  });

  final String? id;
  final String quote;
  final String? name;
  final String? role;
  final String? organisation;
  final String? avatarUrl;
  final bool isPublished;
  final int sortOrder;
}

@immutable
class MarketingCampaignDraft {
  const MarketingCampaignDraft({
    this.id,
    required this.campaignKey,
    required this.name,
    required this.status,
    this.landingPageSlug,
    this.headline,
    this.subheadline,
    this.ctaLabel,
    this.ctaUrl,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.startsAt,
    this.endsAt,
  });

  final String? id;
  final String campaignKey;
  final String name;
  final MarketingContentStatus status;
  final String? landingPageSlug;
  final String? headline;
  final String? subheadline;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final DateTime? startsAt;
  final DateTime? endsAt;
}

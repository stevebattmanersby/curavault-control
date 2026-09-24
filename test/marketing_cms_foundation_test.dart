import 'dart:io';

import 'package:curavault_admin/admin/data/models/cms_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Marketing CMS models', () {
    test('normalizes page slugs', () {
      expect(cmsSlugFromTitle(' Health Records, Calmly Organised! '),
          'health-records-calmly-organised');
      expect(cmsSlugFromTitle(''), 'untitled');
    });

    test(
        'public eligibility requires published status and arrived publish time',
        () {
      final now = DateTime.utc(2026, 8, 9, 12);

      expect(
        isPublishedAndArrived(
          status: MarketingContentStatus.published,
          publishedAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
      expect(
        isPublishedAndArrived(
          status: MarketingContentStatus.published,
          publishedAt: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
      expect(
        isPublishedAndArrived(
          status: MarketingContentStatus.draft,
          publishedAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('matches the production CMS status constraint', () {
      expect(
        MarketingContentStatus.values.map((status) => status.value),
        ['draft', 'published', 'archived'],
      );
    });
  });

  group('Marketing CMS control-site wiring', () {
    late final String nav;
    late final String sidebar;
    late final String page;
    late final String repository;

    setUpAll(() {
      nav = File('lib/nav.dart').readAsStringSync();
      sidebar =
          File('lib/admin/pages/widgets/admin_sidebar.dart').readAsStringSync();
      page = File('lib/admin/pages/website_cms_status_page.dart')
          .readAsStringSync();
      repository = File(
        'lib/admin/data/supabase/supabase_admin_repository.dart',
      ).readAsStringSync();
    });

    test('exposes restored Website admin sections as first-class routes', () {
      for (final route in [
        'websitePages',
        'websiteBlog',
        'websiteSeo',
        'websitePricing',
        'websiteFaqs',
        'websiteTestimonials',
        'websiteCampaigns',
        'websiteAssets',
      ]) {
        expect(nav, contains(route));
        expect(sidebar, contains(route));
      }
      expect(sidebar, contains("'Website'"));
    });

    test('keeps Stripe Prep archived from the control-site sidebar', () {
      expect(sidebar, isNot(contains('Stripe Prep')));
      expect(sidebar, isNot(contains('stripePrep')));
    });

    test('does not require optional production-missing CMS tables', () {
      for (final source in [page, repository]) {
        expect(source, isNot(contains('marketing_blog_categories')));
        expect(source, isNot(contains('marketing_media_assets')));
        expect(source, isNot(contains('category_id')));
        expect(source, isNot(contains('scheduled_for')));
        expect(source, isNot(contains('og_image_asset_id')));
      }
      expect(page, contains('asset_library_backend'));
      expect(page, contains('Asset library backend not yet provisioned'));
    });

    test('uses only production page, section, and blog columns', () {
      expect(repository, contains('og_title'));
      expect(repository, contains('og_description'));
      expect(repository, contains('canonical_url'));
      expect(repository, contains('is_enabled'));
      expect(repository, contains('subtitle'));
      expect(repository, contains('cta_label'));
      expect(repository, contains('media_url'));
      expect(repository, contains('category'));
      expect(repository, contains('tags'));

      expect(repository, isNot(contains("'template'")));
      expect(repository, isNot(contains("'eyebrow'")));
      final sectionSave = repository.substring(
        repository.indexOf('Future<void> saveMarketingSection'),
        repository.indexOf('Future<void> saveMarketingBlogPost'),
      );
      expect(sectionSave, isNot(contains("'created_by'")));
      expect(sectionSave, isNot(contains("'updated_by'")));
    });

    test('implements global SEO settings support', () {
      expect(repository, contains("'marketing_seo_settings'"));
      expect(repository, contains('saveMarketingSeoSettings'));
      for (final field in [
        'site_name',
        'default_title',
        'default_description',
        'default_og_image',
        'twitter_handle',
        'canonical_base_url',
        'robots_policy',
        'sitemap_include_pages',
        'sitemap_include_blog',
        'sitemap_include_campaigns',
        'schema_organisation_name',
        'schema_website_url',
        'schema_logo_url',
        'schema_support_email',
      ]) {
        expect(repository, contains(field));
      }
      expect(page, contains('class _SeoSettingsEditorSheet'));
      expect(page, contains('Global SEO'));
    });

    test('implements management for supported marketing tables', () {
      for (final symbol in [
        'saveMarketingSeoSettings',
        'saveMarketingPricingPlan',
        'saveMarketingFaq',
        'saveMarketingTestimonial',
        'saveMarketingCampaign',
      ]) {
        expect(repository, contains(symbol));
        expect(page, contains(symbol));
      }
      expect(page, contains('class _SimpleCmsEditorSheet'));
      expect(repository, isNot(contains('saveMarketingMediaAsset')));
    });
  });
}

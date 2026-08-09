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
          status: MarketingContentStatus.review,
          publishedAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('Marketing CMS migration', () {
    late final String sql;

    setUpAll(() {
      sql = File(
              'supabase/migrations/20260809120000_cms_marketing_content_foundation.sql')
          .readAsStringSync();
    });

    test('creates the core marketing content tables', () {
      for (final table in [
        'marketing_pages',
        'marketing_sections',
        'marketing_blog_posts',
        'marketing_blog_categories',
        'marketing_blog_tags',
        'marketing_media_assets',
        'marketing_content_revisions',
        'marketing_social_queue',
      ]) {
        expect(sql, contains('create table if not exists public.$table'));
        expect(sql,
            contains('alter table public.$table enable row level security'));
      }
    });

    test('keeps public reads limited to published or public assets', () {
      expect(sql, contains('marketing_pages_public_published_read'));
      expect(sql, contains("status = 'published'"));
      expect(sql, contains('published_at <= now()'));
      expect(sql, contains('marketing_sections_public_published_read'));
      expect(sql, contains('marketing_blog_posts_public_published_read'));
      expect(sql, contains("visibility = 'public'"));
    });

    test('allows read-only admins to inspect but not write', () {
      expect(sql, contains("'owner', 'admin', 'read_only'"));
      expect(sql, contains("'owner', 'admin'"));
      expect(
          sql,
          isNot(contains(
              "current_admin_role() in ('owner', 'admin', 'read_only')\n) with check")));
    });
  });
}

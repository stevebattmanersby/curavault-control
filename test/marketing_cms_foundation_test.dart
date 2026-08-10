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
    late final String migrationPath;

    setUpAll(() {
      final migrations = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) =>
              file.path.endsWith('_reconcile_existing_marketing_cms.sql'))
          .toList();
      expect(migrations, hasLength(1));
      migrationPath = migrations.single.path;
      sql = migrations.single.readAsStringSync();
    });

    test('replaces the unapplied foundation migration with a live delta', () {
      expect(
        File(
          'supabase/migrations/20260809120000_cms_marketing_content_foundation.sql',
        ).existsSync(),
        isFalse,
      );
      expect(migrationPath, contains('reconcile_existing_marketing_cms'));
      expect(
        sql,
        contains(
          'Reconcile the Control Site marketing CMS with the existing live CMS backend.',
        ),
      );
    });

    test('creates or extends the core marketing content tables', () {
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
      expect(sql, contains('alter table public.marketing_pages'));
      expect(sql, contains('add column if not exists template'));
      expect(sql, contains('add column if not exists scheduled_for'));
      expect(sql, contains('alter table public.marketing_sections'));
      expect(sql, contains('add column if not exists eyebrow'));
      expect(sql, contains('alter table public.marketing_blog_posts'));
      expect(sql, contains('add column if not exists category_id'));
    });

    test('keeps public reads limited to published or public assets', () {
      expect(sql, contains('marketing_pages_public_published_read'));
      expect(sql, contains("status = 'published'"));
      expect(sql, contains('published_at <= now()'));
      expect(sql, contains('archived_at is null'));
      expect(sql, contains('marketing_sections_public_published_read'));
      expect(sql, contains('marketing_blog_posts_public_published_read'));
      expect(sql, contains("visibility = 'public'"));
      expect(sql, contains('p.og_image_asset_id = marketing_media_assets.id'));
      expect(
          sql, contains('where p.category_id = marketing_blog_categories.id'));
      expect(sql, contains('where pt.tag_id = marketing_blog_tags.id'));
    });

    test('allows read-only admins to inspect but not write', () {
      expect(sql, contains("'owner', 'admin', 'read_only'"));
      expect(sql, contains("'owner', 'admin'"));
      expect(
          sql,
          contains(
              'drop policy if exists "marketing_pages_write_active_admin"'));
      expect(
          sql,
          contains(
              'drop policy if exists "marketing_sections_write_active_admin"'));
      expect(
          sql,
          contains(
              'drop policy if exists "marketing_blog_posts_write_active_admin"'));
      expect(
          sql,
          isNot(contains(
              "current_admin_role() in ('owner', 'admin', 'read_only')\n) with check")));
    });

    test('reviews Data API grants separately from RLS', () {
      expect(
          sql,
          contains(
              'revoke all on public.marketing_pages from anon, authenticated'));
      expect(
          sql,
          contains(
              'grant select on public.marketing_pages to anon, authenticated'));
      expect(
          sql,
          contains(
              'grant insert, update, delete on public.marketing_pages to authenticated'));
      expect(sql, isNot(contains('auth.role()')));
    });
  });
}

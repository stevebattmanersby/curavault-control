-- CuraVault Control Site CMS foundation.
--
-- The Control Site manages draft/review/scheduled/published marketing content.
-- The public website must only read published content whose publish time has
-- arrived. It must never require service-role credentials.

create extension if not exists pgcrypto;

create table if not exists public.marketing_media_assets (
  id uuid primary key default gen_random_uuid(),
  storage_bucket text not null,
  storage_path text not null,
  alt_text text,
  caption text,
  mime_type text,
  width integer,
  height integer,
  size_bytes bigint,
  visibility text not null default 'private'
    check (visibility in ('private', 'public')),
  focal_point jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  updated_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

create table if not exists public.marketing_pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  status text not null default 'draft'
    check (status in ('draft', 'review', 'scheduled', 'published', 'archived')),
  template text not null default 'marketing_page',
  excerpt text,
  seo_title text,
  seo_description text,
  canonical_url text,
  og_image_asset_id uuid references public.marketing_media_assets (id) on delete set null,
  published_at timestamptz,
  scheduled_for timestamptz,
  archived_at timestamptz,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  updated_by uuid references public.admin_users (admin_user_id) on delete set null,
  published_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (slug = lower(slug)),
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.marketing_sections (
  id uuid primary key default gen_random_uuid(),
  page_id uuid not null references public.marketing_pages (id) on delete cascade,
  section_key text not null,
  section_type text not null default 'content',
  sort_order integer not null default 0,
  status text not null default 'draft'
    check (status in ('draft', 'review', 'scheduled', 'published', 'archived')),
  eyebrow text,
  title text,
  body text,
  content_json jsonb not null default '{}'::jsonb,
  media_asset_id uuid references public.marketing_media_assets (id) on delete set null,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  updated_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (page_id, section_key),
  unique (page_id, sort_order),
  check (section_key = lower(section_key)),
  check (section_key ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.marketing_blog_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  updated_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (slug = lower(slug)),
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.marketing_blog_tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  updated_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (slug = lower(slug)),
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.marketing_blog_posts (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  status text not null default 'draft'
    check (status in ('draft', 'review', 'scheduled', 'published', 'archived')),
  excerpt text,
  body_markdown text,
  content_json jsonb not null default '{}'::jsonb,
  category_id uuid references public.marketing_blog_categories (id) on delete set null,
  seo_title text,
  seo_description text,
  canonical_url text,
  og_image_asset_id uuid references public.marketing_media_assets (id) on delete set null,
  published_at timestamptz,
  scheduled_for timestamptz,
  archived_at timestamptz,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  updated_by uuid references public.admin_users (admin_user_id) on delete set null,
  published_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (slug = lower(slug)),
  check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table if not exists public.marketing_blog_post_tags (
  post_id uuid not null references public.marketing_blog_posts (id) on delete cascade,
  tag_id uuid not null references public.marketing_blog_tags (id) on delete cascade,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (post_id, tag_id)
);

create table if not exists public.marketing_content_revisions (
  id uuid primary key default gen_random_uuid(),
  resource_type text not null
    check (resource_type in ('page', 'section', 'blog_post', 'blog_category', 'blog_tag', 'media_asset')),
  resource_id uuid not null,
  revision_number integer not null,
  snapshot jsonb not null,
  reason text,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  unique (resource_type, resource_id, revision_number)
);

create table if not exists public.marketing_social_queue (
  id uuid primary key default gen_random_uuid(),
  resource_type text not null check (resource_type in ('page', 'blog_post')),
  resource_id uuid not null,
  channel text not null,
  status text not null default 'draft'
    check (status in ('draft', 'queued', 'sent', 'cancelled', 'failed')),
  scheduled_for timestamptz,
  payload_json jsonb not null default '{}'::jsonb,
  created_by uuid references public.admin_users (admin_user_id) on delete set null,
  updated_by uuid references public.admin_users (admin_user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_updated_at_marketing_media_assets on public.marketing_media_assets;
create trigger set_updated_at_marketing_media_assets
before update on public.marketing_media_assets
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_marketing_pages on public.marketing_pages;
create trigger set_updated_at_marketing_pages
before update on public.marketing_pages
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_marketing_sections on public.marketing_sections;
create trigger set_updated_at_marketing_sections
before update on public.marketing_sections
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_marketing_blog_categories on public.marketing_blog_categories;
create trigger set_updated_at_marketing_blog_categories
before update on public.marketing_blog_categories
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_marketing_blog_tags on public.marketing_blog_tags;
create trigger set_updated_at_marketing_blog_tags
before update on public.marketing_blog_tags
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_marketing_blog_posts on public.marketing_blog_posts;
create trigger set_updated_at_marketing_blog_posts
before update on public.marketing_blog_posts
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at_marketing_social_queue on public.marketing_social_queue;
create trigger set_updated_at_marketing_social_queue
before update on public.marketing_social_queue
for each row execute function public.set_updated_at();

create index if not exists marketing_pages_status_published_at_idx
  on public.marketing_pages (status, published_at desc);
create index if not exists marketing_pages_scheduled_for_idx
  on public.marketing_pages (scheduled_for)
  where status = 'scheduled';
create index if not exists marketing_sections_page_sort_idx
  on public.marketing_sections (page_id, sort_order);
create index if not exists marketing_sections_status_idx
  on public.marketing_sections (status);
create index if not exists marketing_blog_posts_status_published_at_idx
  on public.marketing_blog_posts (status, published_at desc);
create index if not exists marketing_blog_posts_category_idx
  on public.marketing_blog_posts (category_id);
create index if not exists marketing_blog_post_tags_tag_idx
  on public.marketing_blog_post_tags (tag_id);
create index if not exists marketing_content_revisions_resource_idx
  on public.marketing_content_revisions (resource_type, resource_id, revision_number desc);
create index if not exists marketing_social_queue_status_scheduled_idx
  on public.marketing_social_queue (status, scheduled_for);

alter table public.marketing_media_assets enable row level security;
alter table public.marketing_pages enable row level security;
alter table public.marketing_sections enable row level security;
alter table public.marketing_blog_categories enable row level security;
alter table public.marketing_blog_tags enable row level security;
alter table public.marketing_blog_posts enable row level security;
alter table public.marketing_blog_post_tags enable row level security;
alter table public.marketing_content_revisions enable row level security;
alter table public.marketing_social_queue enable row level security;

grant select on public.marketing_media_assets to anon, authenticated;
grant select on public.marketing_pages to anon, authenticated;
grant select on public.marketing_sections to anon, authenticated;
grant select on public.marketing_blog_categories to anon, authenticated;
grant select on public.marketing_blog_tags to anon, authenticated;
grant select on public.marketing_blog_posts to anon, authenticated;
grant select on public.marketing_blog_post_tags to anon, authenticated;
grant select on public.marketing_content_revisions to authenticated;
grant select on public.marketing_social_queue to authenticated;

grant insert, update on public.marketing_media_assets to authenticated;
grant insert, update on public.marketing_pages to authenticated;
grant insert, update on public.marketing_sections to authenticated;
grant insert, update on public.marketing_blog_categories to authenticated;
grant insert, update on public.marketing_blog_tags to authenticated;
grant insert, update on public.marketing_blog_posts to authenticated;
grant insert, update on public.marketing_blog_post_tags to authenticated;
grant insert, update on public.marketing_content_revisions to authenticated;
grant insert, update on public.marketing_social_queue to authenticated;

drop policy if exists "marketing_media_public_published_read" on public.marketing_media_assets;
create policy "marketing_media_public_published_read"
on public.marketing_media_assets
for select
to anon, authenticated
using (
  visibility = 'public'
  and (
    exists (
      select 1
      from public.marketing_pages p
      where p.og_image_asset_id = marketing_media_assets.id
        and p.status = 'published'
        and p.archived_at is null
        and p.published_at is not null
        and p.published_at <= now()
    )
    or exists (
      select 1
      from public.marketing_sections s
      join public.marketing_pages p on p.id = s.page_id
      where s.media_asset_id = marketing_media_assets.id
        and s.status = 'published'
        and p.status = 'published'
        and p.archived_at is null
        and p.published_at is not null
        and p.published_at <= now()
    )
    or exists (
      select 1
      from public.marketing_blog_posts p
      where p.og_image_asset_id = marketing_media_assets.id
        and p.status = 'published'
        and p.archived_at is null
        and p.published_at is not null
        and p.published_at <= now()
    )
  )
);

drop policy if exists "marketing_pages_public_published_read" on public.marketing_pages;
create policy "marketing_pages_public_published_read"
on public.marketing_pages
for select
to anon, authenticated
using (
  status = 'published'
  and archived_at is null
  and published_at is not null
  and published_at <= now()
);

drop policy if exists "marketing_sections_public_published_read" on public.marketing_sections;
create policy "marketing_sections_public_published_read"
on public.marketing_sections
for select
to anon, authenticated
using (
  status = 'published'
  and exists (
    select 1
    from public.marketing_pages p
    where p.id = page_id
      and p.status = 'published'
      and p.archived_at is null
      and p.published_at is not null
      and p.published_at <= now()
  )
);

drop policy if exists "marketing_blog_posts_public_published_read" on public.marketing_blog_posts;
create policy "marketing_blog_posts_public_published_read"
on public.marketing_blog_posts
for select
to anon, authenticated
using (
  status = 'published'
  and archived_at is null
  and published_at is not null
  and published_at <= now()
);

drop policy if exists "marketing_blog_categories_public_active_read" on public.marketing_blog_categories;
create policy "marketing_blog_categories_public_active_read"
on public.marketing_blog_categories
for select
to anon, authenticated
using (
  is_active = true
  and exists (
    select 1
    from public.marketing_blog_posts p
    where p.category_id = marketing_blog_categories.id
      and p.status = 'published'
      and p.archived_at is null
      and p.published_at is not null
      and p.published_at <= now()
  )
);

drop policy if exists "marketing_blog_tags_public_read" on public.marketing_blog_tags;
create policy "marketing_blog_tags_public_read"
on public.marketing_blog_tags
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.marketing_blog_post_tags pt
    join public.marketing_blog_posts p on p.id = pt.post_id
    where pt.tag_id = marketing_blog_tags.id
      and p.status = 'published'
      and p.archived_at is null
      and p.published_at is not null
      and p.published_at <= now()
  )
);

drop policy if exists "marketing_blog_post_tags_public_read" on public.marketing_blog_post_tags;
create policy "marketing_blog_post_tags_public_read"
on public.marketing_blog_post_tags
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.marketing_blog_posts p
    where p.id = post_id
      and p.status = 'published'
      and p.archived_at is null
      and p.published_at is not null
      and p.published_at <= now()
  )
);

drop policy if exists "marketing_cms_admin_read_assets" on public.marketing_media_assets;
create policy "marketing_cms_admin_read_assets"
on public.marketing_media_assets
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_assets" on public.marketing_media_assets;
create policy "marketing_cms_admin_write_assets"
on public.marketing_media_assets
for all
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
)
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

drop policy if exists "marketing_cms_admin_read_pages" on public.marketing_pages;
create policy "marketing_cms_admin_read_pages"
on public.marketing_pages
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_pages" on public.marketing_pages;
create policy "marketing_cms_admin_write_pages"
on public.marketing_pages
for all
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
)
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

drop policy if exists "marketing_cms_admin_read_sections" on public.marketing_sections;
create policy "marketing_cms_admin_read_sections"
on public.marketing_sections
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_sections" on public.marketing_sections;
create policy "marketing_cms_admin_write_sections"
on public.marketing_sections
for all
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
)
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

drop policy if exists "marketing_cms_admin_read_blog_categories" on public.marketing_blog_categories;
create policy "marketing_cms_admin_read_blog_categories"
on public.marketing_blog_categories
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_blog_categories" on public.marketing_blog_categories;
create policy "marketing_cms_admin_write_blog_categories"
on public.marketing_blog_categories
for all
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
)
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

drop policy if exists "marketing_cms_admin_read_blog_tags" on public.marketing_blog_tags;
create policy "marketing_cms_admin_read_blog_tags"
on public.marketing_blog_tags
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_blog_tags" on public.marketing_blog_tags;
create policy "marketing_cms_admin_write_blog_tags"
on public.marketing_blog_tags
for all
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
)
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

drop policy if exists "marketing_cms_admin_read_blog_posts" on public.marketing_blog_posts;
create policy "marketing_cms_admin_read_blog_posts"
on public.marketing_blog_posts
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_blog_posts" on public.marketing_blog_posts;
create policy "marketing_cms_admin_write_blog_posts"
on public.marketing_blog_posts
for all
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
)
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

drop policy if exists "marketing_cms_admin_read_blog_post_tags" on public.marketing_blog_post_tags;
create policy "marketing_cms_admin_read_blog_post_tags"
on public.marketing_blog_post_tags
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_blog_post_tags" on public.marketing_blog_post_tags;
create policy "marketing_cms_admin_write_blog_post_tags"
on public.marketing_blog_post_tags
for all
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
)
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

drop policy if exists "marketing_cms_admin_read_revisions" on public.marketing_content_revisions;
create policy "marketing_cms_admin_read_revisions"
on public.marketing_content_revisions
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_revisions" on public.marketing_content_revisions;
create policy "marketing_cms_admin_write_revisions"
on public.marketing_content_revisions
for insert
to authenticated
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

drop policy if exists "marketing_cms_admin_read_social_queue" on public.marketing_social_queue;
create policy "marketing_cms_admin_read_social_queue"
on public.marketing_social_queue
for select
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin', 'read_only')
);

drop policy if exists "marketing_cms_admin_write_social_queue" on public.marketing_social_queue;
create policy "marketing_cms_admin_write_social_queue"
on public.marketing_social_queue
for all
to authenticated
using (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
)
with check (
  public.is_active_admin()
  and public.current_admin_role() in ('owner', 'admin')
);

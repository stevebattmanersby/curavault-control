-- CuraVault Control Site - Marketing CMS backend tables
--
-- Security model:
--   - RLS enabled on all tables
--   - Only authenticated active admins (public.is_active_admin()) can read/write
--   - Public website access is NOT granted here (will be via safe API later)
--
-- Audit model:
--   - Any INSERT/UPDATE/DELETE on these tables writes an entry to public.admin_audit_log
--   - Audit diffs are redacted to avoid storing large/free-text payloads

begin;

create extension if not exists pgcrypto;

create or replace function public.admin_audit_marketing_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_email text;
  v_resource_id text;
  v_prev jsonb;
  v_next jsonb;
  v_action text;
begin
  if not public.is_active_admin() then
    raise exception 'not authorized';
  end if;

  select au.email into v_admin_email
  from public.admin_users au
  where au.admin_user_id = auth.uid()
  limit 1;

  v_action := 'marketing.' || tg_table_name || '.' || lower(tg_op);

  if (tg_op = 'INSERT') then
    v_resource_id := coalesce((to_jsonb(new)->>'id'), null);
    v_prev := null;
    v_next := to_jsonb(new)
      - 'content_json' - 'settings_json' - 'body_json'
      - 'body_markdown' - 'body' - 'answer';
  elsif (tg_op = 'UPDATE') then
    v_resource_id := coalesce((to_jsonb(new)->>'id'), (to_jsonb(old)->>'id'), null);
    v_prev := to_jsonb(old)
      - 'content_json' - 'settings_json' - 'body_json'
      - 'body_markdown' - 'body' - 'answer';
    v_next := to_jsonb(new)
      - 'content_json' - 'settings_json' - 'body_json'
      - 'body_markdown' - 'body' - 'answer';
  else
    v_resource_id := coalesce((to_jsonb(old)->>'id'), null);
    v_prev := to_jsonb(old)
      - 'content_json' - 'settings_json' - 'body_json'
      - 'body_markdown' - 'body' - 'answer';
    v_next := null;
  end if;

  insert into public.admin_audit_log (
    admin_user_id,
    admin_email,
    target_resource_type,
    target_resource_id,
    action_type,
    result,
    prev,
    next
  ) values (
    auth.uid(),
    v_admin_email,
    tg_table_name,
    v_resource_id,
    v_action,
    'success',
    v_prev,
    v_next
  );

  if (tg_op = 'DELETE') then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.set_marketing_actor_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_active_admin() then
    raise exception 'not authorized';
  end if;

  if (tg_op = 'INSERT') then
    if new.created_by is null then
      new.created_by := auth.uid();
    end if;
    new.updated_by := auth.uid();
  elsif (tg_op = 'UPDATE') then
    new.updated_by := auth.uid();
  end if;

  return new;
end;
$$;

create table if not exists public.marketing_pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  title text not null,
  status text not null default 'draft',
  seo_title text,
  seo_description text,
  og_title text,
  og_description text,
  og_image_url text,
  canonical_url text,
  content_json jsonb not null default '{}'::jsonb,
  published_at timestamptz,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketing_pages_slug_unique unique (slug),
  constraint marketing_pages_status_check check (status in ('draft','published','archived'))
);

create index if not exists marketing_pages_slug_idx on public.marketing_pages (slug);
create index if not exists marketing_pages_status_idx on public.marketing_pages (status);
create index if not exists marketing_pages_published_at_idx on public.marketing_pages (published_at desc);

drop trigger if exists set_updated_at_marketing_pages on public.marketing_pages;
create trigger set_updated_at_marketing_pages
before update on public.marketing_pages
for each row execute function public.set_updated_at();

drop trigger if exists set_actor_marketing_pages on public.marketing_pages;
create trigger set_actor_marketing_pages
before insert or update on public.marketing_pages
for each row execute function public.set_marketing_actor_fields();

drop trigger if exists audit_marketing_pages on public.marketing_pages;
create trigger audit_marketing_pages
after insert or update or delete on public.marketing_pages
for each row execute function public.admin_audit_marketing_mutation();

create table if not exists public.marketing_sections (
  id uuid primary key default gen_random_uuid(),
  page_id uuid not null references public.marketing_pages (id) on delete cascade,
  section_key text not null,
  section_type text not null,
  title text,
  subtitle text,
  body text,
  media_url text,
  cta_label text,
  cta_url text,
  sort_order int not null default 0,
  is_enabled boolean not null default true,
  settings_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists marketing_sections_page_id_idx on public.marketing_sections (page_id);
create index if not exists marketing_sections_section_key_idx on public.marketing_sections (section_key);
create index if not exists marketing_sections_sort_order_idx on public.marketing_sections (sort_order);
create index if not exists marketing_sections_is_enabled_idx on public.marketing_sections (is_enabled);

drop trigger if exists set_updated_at_marketing_sections on public.marketing_sections;
create trigger set_updated_at_marketing_sections
before update on public.marketing_sections
for each row execute function public.set_updated_at();

drop trigger if exists audit_marketing_sections on public.marketing_sections;
create trigger audit_marketing_sections
after insert or update or delete on public.marketing_sections
for each row execute function public.admin_audit_marketing_mutation();

create table if not exists public.marketing_blog_posts (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  title text not null,
  excerpt text,
  body_markdown text,
  body_json jsonb not null default '{}'::jsonb,
  status text not null default 'draft',
  author_name text,
  category text,
  tags text[],
  seo_title text,
  seo_description text,
  og_image_url text,
  published_at timestamptz,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketing_blog_posts_slug_unique unique (slug),
  constraint marketing_blog_posts_status_check check (status in ('draft','published','archived'))
);

create index if not exists marketing_blog_posts_slug_idx on public.marketing_blog_posts (slug);
create index if not exists marketing_blog_posts_status_idx on public.marketing_blog_posts (status);
create index if not exists marketing_blog_posts_published_at_idx on public.marketing_blog_posts (published_at desc);
create index if not exists marketing_blog_posts_category_idx on public.marketing_blog_posts (category);

drop trigger if exists set_updated_at_marketing_blog_posts on public.marketing_blog_posts;
create trigger set_updated_at_marketing_blog_posts
before update on public.marketing_blog_posts
for each row execute function public.set_updated_at();

drop trigger if exists set_actor_marketing_blog_posts on public.marketing_blog_posts;
create trigger set_actor_marketing_blog_posts
before insert or update on public.marketing_blog_posts
for each row execute function public.set_marketing_actor_fields();

drop trigger if exists audit_marketing_blog_posts on public.marketing_blog_posts;
create trigger audit_marketing_blog_posts
after insert or update or delete on public.marketing_blog_posts
for each row execute function public.admin_audit_marketing_mutation();

create table if not exists public.marketing_faqs (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  answer text not null,
  category text,
  sort_order int not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists marketing_faqs_category_idx on public.marketing_faqs (category);
create index if not exists marketing_faqs_sort_order_idx on public.marketing_faqs (sort_order);
create index if not exists marketing_faqs_is_published_idx on public.marketing_faqs (is_published);

drop trigger if exists set_updated_at_marketing_faqs on public.marketing_faqs;
create trigger set_updated_at_marketing_faqs
before update on public.marketing_faqs
for each row execute function public.set_updated_at();

drop trigger if exists audit_marketing_faqs on public.marketing_faqs;
create trigger audit_marketing_faqs
after insert or update or delete on public.marketing_faqs
for each row execute function public.admin_audit_marketing_mutation();

create table if not exists public.marketing_pricing_plans (
  id uuid primary key default gen_random_uuid(),
  plan_key text not null,
  name text not null,
  description text,
  monthly_price numeric,
  annual_price numeric,
  currency text not null default 'EUR',
  stripe_price_id_monthly text,
  stripe_price_id_annual text,
  features text[],
  limits_json jsonb not null default '{}'::jsonb,
  is_featured boolean not null default false,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketing_pricing_plans_plan_key_unique unique (plan_key)
);

create index if not exists marketing_pricing_plans_plan_key_idx on public.marketing_pricing_plans (plan_key);
create index if not exists marketing_pricing_plans_is_active_idx on public.marketing_pricing_plans (is_active);
create index if not exists marketing_pricing_plans_sort_order_idx on public.marketing_pricing_plans (sort_order);

drop trigger if exists set_updated_at_marketing_pricing_plans on public.marketing_pricing_plans;
create trigger set_updated_at_marketing_pricing_plans
before update on public.marketing_pricing_plans
for each row execute function public.set_updated_at();

drop trigger if exists audit_marketing_pricing_plans on public.marketing_pricing_plans;
create trigger audit_marketing_pricing_plans
after insert or update or delete on public.marketing_pricing_plans
for each row execute function public.admin_audit_marketing_mutation();

create table if not exists public.marketing_testimonials (
  id uuid primary key default gen_random_uuid(),
  quote text not null,
  name text,
  role text,
  organisation text,
  avatar_url text,
  is_published boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists marketing_testimonials_is_published_idx on public.marketing_testimonials (is_published);
create index if not exists marketing_testimonials_sort_order_idx on public.marketing_testimonials (sort_order);

drop trigger if exists set_updated_at_marketing_testimonials on public.marketing_testimonials;
create trigger set_updated_at_marketing_testimonials
before update on public.marketing_testimonials
for each row execute function public.set_updated_at();

drop trigger if exists audit_marketing_testimonials on public.marketing_testimonials;
create trigger audit_marketing_testimonials
after insert or update or delete on public.marketing_testimonials
for each row execute function public.admin_audit_marketing_mutation();

create table if not exists public.marketing_campaigns (
  id uuid primary key default gen_random_uuid(),
  campaign_key text not null,
  name text not null,
  status text not null default 'draft',
  landing_page_slug text,
  headline text,
  subheadline text,
  cta_label text,
  cta_url text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  settings_json jsonb not null default '{}'::jsonb,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketing_campaigns_campaign_key_unique unique (campaign_key),
  constraint marketing_campaigns_status_check check (status in ('draft','published','archived'))
);

create index if not exists marketing_campaigns_campaign_key_idx on public.marketing_campaigns (campaign_key);
create index if not exists marketing_campaigns_status_idx on public.marketing_campaigns (status);
create index if not exists marketing_campaigns_starts_at_idx on public.marketing_campaigns (starts_at);
create index if not exists marketing_campaigns_ends_at_idx on public.marketing_campaigns (ends_at);

drop trigger if exists set_updated_at_marketing_campaigns on public.marketing_campaigns;
create trigger set_updated_at_marketing_campaigns
before update on public.marketing_campaigns
for each row execute function public.set_updated_at();

drop trigger if exists audit_marketing_campaigns on public.marketing_campaigns;
create trigger audit_marketing_campaigns
after insert or update or delete on public.marketing_campaigns
for each row execute function public.admin_audit_marketing_mutation();

alter table public.marketing_pages enable row level security;
alter table public.marketing_sections enable row level security;
alter table public.marketing_blog_posts enable row level security;
alter table public.marketing_faqs enable row level security;
alter table public.marketing_pricing_plans enable row level security;
alter table public.marketing_testimonials enable row level security;
alter table public.marketing_campaigns enable row level security;

-- marketing_pages
drop policy if exists "marketing_pages_select_active_admin" on public.marketing_pages;
create policy "marketing_pages_select_active_admin" on public.marketing_pages
for select to authenticated
using (public.is_active_admin());

drop policy if exists "marketing_pages_write_active_admin" on public.marketing_pages;
create policy "marketing_pages_write_active_admin" on public.marketing_pages
for all to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- marketing_sections
drop policy if exists "marketing_sections_select_active_admin" on public.marketing_sections;
create policy "marketing_sections_select_active_admin" on public.marketing_sections
for select to authenticated
using (public.is_active_admin());

drop policy if exists "marketing_sections_write_active_admin" on public.marketing_sections;
create policy "marketing_sections_write_active_admin" on public.marketing_sections
for all to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- marketing_blog_posts
drop policy if exists "marketing_blog_posts_select_active_admin" on public.marketing_blog_posts;
create policy "marketing_blog_posts_select_active_admin" on public.marketing_blog_posts
for select to authenticated
using (public.is_active_admin());

drop policy if exists "marketing_blog_posts_write_active_admin" on public.marketing_blog_posts;
create policy "marketing_blog_posts_write_active_admin" on public.marketing_blog_posts
for all to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- marketing_faqs
drop policy if exists "marketing_faqs_select_active_admin" on public.marketing_faqs;
create policy "marketing_faqs_select_active_admin" on public.marketing_faqs
for select to authenticated
using (public.is_active_admin());

drop policy if exists "marketing_faqs_write_active_admin" on public.marketing_faqs;
create policy "marketing_faqs_write_active_admin" on public.marketing_faqs
for all to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- marketing_pricing_plans
drop policy if exists "marketing_pricing_plans_select_active_admin" on public.marketing_pricing_plans;
create policy "marketing_pricing_plans_select_active_admin" on public.marketing_pricing_plans
for select to authenticated
using (public.is_active_admin());

drop policy if exists "marketing_pricing_plans_write_active_admin" on public.marketing_pricing_plans;
create policy "marketing_pricing_plans_write_active_admin" on public.marketing_pricing_plans
for all to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- marketing_testimonials
drop policy if exists "marketing_testimonials_select_active_admin" on public.marketing_testimonials;
create policy "marketing_testimonials_select_active_admin" on public.marketing_testimonials
for select to authenticated
using (public.is_active_admin());

drop policy if exists "marketing_testimonials_write_active_admin" on public.marketing_testimonials;
create policy "marketing_testimonials_write_active_admin" on public.marketing_testimonials
for all to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

-- marketing_campaigns
drop policy if exists "marketing_campaigns_select_active_admin" on public.marketing_campaigns;
create policy "marketing_campaigns_select_active_admin" on public.marketing_campaigns
for select to authenticated
using (public.is_active_admin());

drop policy if exists "marketing_campaigns_write_active_admin" on public.marketing_campaigns;
create policy "marketing_campaigns_write_active_admin" on public.marketing_campaigns
for all to authenticated
using (public.is_active_admin())
with check (public.is_active_admin());

commit;
;

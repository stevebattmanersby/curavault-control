# Marketing/CMS Restore Audit (CuraVault Control Site)

Date: 2026-07-17

Scope:
- Audit the **current Flutter repo** for Marketing/CMS ("Website") UI, routes, repositories, and migrations.
- Audit the **connected Supabase project** for the presence of Marketing/CMS tables and applied migrations (schema-only).
- **No auth changes**, **no RLS weakening**, **no raw health data access**, and **no modifications** to the currently working admin/ops console.

## Executive findings

### Repo status (Flutter)
Marketing/CMS UI appears **absent** from the current repo state:
- No `Website` navigation group in the sidebar.
- No `Website`/CMS routes in `go_router` (`lib/nav.dart`).
- No CMS/marketing pages (e.g., `website_pages_page.dart`, `marketing_pages_page.dart`, editor pages) exist under `lib/`.
- No repository/query code for `marketing_pages` (or related CMS tables) exists under `lib/`.

The repo currently contains only the **admin/operations console** feature set (Dashboard, Users, Support, Billing, Compliance, etc.).

### Supabase status (schema)
Marketing/CMS schema still exists in Supabase.

Confirmed present tables (public schema; RLS enabled) include:
- `marketing_pages`
- `marketing_sections`
- `marketing_blog_posts`
- `marketing_faqs`
- `marketing_pricing_plans`
- `marketing_testimonials`
- `marketing_campaigns`
- `marketing_seo_settings`

This strongly suggests the Marketing/CMS backend was created/applied successfully, but the **frontend/admin CMS module and repo migration file(s) are missing** from the current repo.

## 1) Repo inspection results

### Keyword/code search
Searched in `lib/` and `supabase/` for:
- `marketing`, `marketing_pages`, `marketing_sections`, `marketing_assets`, `marketing_navigation`, `marketing_redirects`
- `website`, `CMS`, `content_json`, `seo_title`, `og_title`, `canonical_url`, `page editor`

Result: **no matches** in the current repo.

### File presence (what exists today)
The current repo structure is primarily:
- `lib/admin/...` (admin console)
- `lib/nav.dart` (router)
- `supabase/migrations/...` (admin-safe reporting + control site migrations)

Notably absent:
- Any `lib/website/...`, `lib/marketing/...`, `lib/cms/...`
- Any admin pages/widgets for CMS management
- Any `Website` section in `AdminSidebar`

### Router and sidebar

`lib/nav.dart`:
- Contains routes for admin console pages only.
- No `/website/*` routes or any placeholders for: Pages, Blog, SEO, Pricing, FAQs, Testimonials, Campaigns.

`lib/admin/pages/widgets/admin_sidebar.dart`:
- Contains navigation items for: Dashboard, Users, Support, Plans & Permissions, Usage Analytics, Storage, AI Usage, Billing, Compliance, System Health, Audit Logs, Security Checklist, Settings.
- No "Website" group.

## 2) Migrations present in repo

Repo migrations currently present in `supabase/migrations/`:
- `20260612_create_control_site_admin_tables.sql`
- `20260613_control_site_noop_schema_already_applied.sql`
- `20260614_add_privacy_safe_storage_metadata.sql`
- `20260614_admin_safe_reporting_rpcs.sql`
- `20260614_create_admin_safe_reporting_functions.sql`
- `20260615_complete_control_site_live_data_rpcs.sql`
- `20260616_add_privacy_safe_ai_usage_events.sql`
- `20260706_complete_control_site_detail_action_rpcs.sql`
- `20260706_fix_admin_data_test_reporting_rpcs.sql`
- `20260706_fix_ai_usage_summary_ambiguous_columns.sql`

There are **no marketing/CMS migrations** present in the repo.

## 3) Migrations applied in Supabase

Supabase migration history (from `list_migrations`) includes:
- `20260626_create_marketing_cms_backend` ✅ (applied)
- plus admin/control-site migrations (admin tables, reporting RPCs, theme_preference, etc.)

**Mismatch:**
- Supabase shows `20260626_create_marketing_cms_backend` was applied.
- The corresponding SQL file is **not present** in `supabase/migrations/` in the repo.

This indicates at least one marketing/CMS migration file was likely **deleted from the repo** (or never committed into this repo snapshot).

## 4) Supabase schema-only checks (no data reads)

Verified via Supabase table listing:
- `marketing_pages` exists and includes columns:
  - `title`, `slug`, `status`, `updated_at`, `published_at`
  - SEO fields: `seo_title`, `seo_description`, `og_title`, `og_description`, `og_image_url`, `canonical_url`
  - `content_json` (jsonb)
- Related supporting tables exist (see Executive findings).

## 5) Git history inspection (limitations in Dreamflow)

You requested:
- `git log --name-status ...`
- `git log --diff-filter=D ...`
- `git diff HEAD~10..HEAD`
- `git reflog`

In the current Dreamflow environment, I don’t have a tool that can directly execute `git` commands or inspect reflog output.

**Best way to complete this step:**
1) Dreamflow → Menu (top-left) → **Download Code**
2) Run the suggested git commands locally to identify:
   - which marketing/CMS files were deleted
   - which commit last contained the Website/CMS module

If you paste the output of either of these, I can pinpoint exact restore targets:
- `git log --name-status --all -- "*marketing*" "*website*" "*cms*"`
- `git log --diff-filter=D --summary --all | head -200`

## 6) Was marketing/CMS code deleted?

Based on repo scanning results:
- **Yes, it appears removed** from the Flutter repo:
  - no routes
  - no sidebar section
  - no CMS pages
  - no CMS repository/query layer
  - no marketing migration SQL files

Based on Supabase:
- **No, the schema was not removed** from the database.

## 7) Is the repo behind the deployed preview?

I can’t conclusively compare against the deployed build artifact from within the repo alone.

However, given:
- Supabase has applied `20260626_create_marketing_cms_backend`
- Repo has zero marketing/CMS code and zero migration files

It’s likely the repo snapshot you have now is missing the previously implemented Website/CMS module.

## 8) Safest restore approach (preserve working admin console)

Priority is to **avoid touching** the stable admin/ops functionality and all the recent fixes you listed.

### Recommended path (lowest risk)
1) **Restore from git** (preferred):
   - Identify the last commit where Website/CMS existed.
   - Cherry-pick or restore only:
     - CMS UI pages/components
     - CMS repository/query files
     - CMS route entries in `lib/nav.dart`
     - CMS sidebar section in `admin_sidebar.dart`
     - the missing migration file(s) under `supabase/migrations/`
2) Integrate it as an **additive module**:
   - New routes should be purely additive (`/website/...`)
   - Keep RBAC gating consistent with existing patterns
   - Do not alter existing admin routes, redirect logic, or auth flows
3) If git restore is not possible, **recreate minimal UI only**:
   - Implement “Website” group + placeholders + Pages table + editor
   - Use the existing Supabase schema (already present)
   - Recreate the missing migration file in repo only as a "schema already applied" noop (or a documented backfill) to keep repo history coherent

### Why this is safe
- Uses existing route/table namespaces without changing auth.
- Doesn’t require RLS weakening.
- Doesn’t touch admin-safe RPCs you’ve already stabilized.

## 9) Risks

- **RBAC coverage mismatch:** Marketing routes must be added to `AdminRbac.routeAccess` (or equivalent) without inadvertently granting broader access.
- **Schema drift:** Since the DB already has marketing tables, recreated migrations must be handled carefully (prefer noop or conditional checks) to avoid "relation already exists" errors.
- **Navigation complexity:** Adding a new nav group must not break sidebar selection state or overflow fixes.

## 10) Exact files I propose to restore or recreate (report-only; no changes made yet)

Based on your prior spec, we should expect a set of files similar to:
- `lib/admin/pages/website_pages_page.dart` (or `marketing_pages_page.dart`)
- `lib/admin/pages/website_page_editor_page.dart`
- `lib/admin/pages/website_section_placeholder.dart` (for Blog/SEO/Pricing/FAQs/Testimonials/Campaigns placeholders)
- `lib/admin/data/supabase/marketing_cms_queries.dart`
- `lib/admin/data/supabase/marketing_cms_repository.dart`
- `supabase/migrations/20260626_create_marketing_cms_backend.sql` (missing in repo)
- Updates to:
  - `lib/nav.dart` (add routes)
  - `lib/admin/pages/widgets/admin_sidebar.dart` (add "Website" section)
  - `lib/admin/auth/admin_rbac.dart` (add route access mapping)

At this moment, **none of these files exist** in the repo, and **no changes have been applied**.

---

## Next requested input (to complete the git portion)

If you want me to identify *exact* deleted filenames/commits (instead of inferred absence), please paste one of:
1) Output of `git log --diff-filter=D --summary --all | head -200`
2) Output of `git log --name-status --all -- "*marketing*" "*website*" "*cms*" | head -200`

Then I can produce a precise “restore list” with the exact paths and commit SHAs.

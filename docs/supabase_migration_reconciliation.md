# Supabase Migration Reconciliation

This document records the local-only reconciliation work for the CuraVault Control Site Supabase migrations. It is intentionally not a deployment log.

## Scope

- Repository: `curavault-control`
- Branch: `codex/cms-schema-reconciliation`
- Linked project inspected read-only: `curavault-clean`
- Project ref: `rzq...ykq`

No remote migrations, schema, data, migration history, Edge Functions, or deployments were changed during this reconciliation.

## Current Problem

The Control Site repository and the shared Supabase project do not share the same migration history.

The repository contains older shortened migration versions, including duplicate local versions:

- `20260614`
- `20260706`

The remote Supabase migration history uses unique 14-digit versions. The local migration `20260809120000_cms_marketing_content_foundation.sql` was never applied remotely.

The live database already contains an older marketing CMS created by remote migration `20260626120552` / `20260626_create_marketing_cms_backend`, so the unapplied local CMS foundation migration is not safe to apply as-is.

## Remote Migration History Observed

Read-only migration inspection found these remote versions:

| Remote version | Remote name | Local source found |
| --- | --- | --- |
| `20260612230013` | `20260612_create_control_site_admin_tables` | Semantically maps to `20260612_create_control_site_admin_tables.sql`; exact timestamped file not found locally |
| `20260614011527` | `20260614_admin_safe_reporting_rpcs` | Semantically maps to `20260614_admin_safe_reporting_rpcs.sql`; exact timestamped file not found locally |
| `20260614013625` | `20260614_create_admin_safe_reporting_functions` | Semantically maps to `20260614_create_admin_safe_reporting_functions.sql`; exact timestamped file not found locally |
| `20260614114331` | `20260614_create_admin_safe_reporting_functions` | No exact local timestamped file found |
| `20260614125140` | `20260616_add_privacy_safe_ai_usage_events` | Semantically maps to `20260616_add_privacy_safe_ai_usage_events.sql`; exact timestamped file not found locally |
| `20260614125203` | `20260616_add_privacy_safe_ai_usage_events` | No exact local timestamped file found |
| `20260626120552` | `20260626_create_marketing_cms_backend` | Authoritative local file not found in available repos |
| `20260701162541` | `20260616_fix_admin_safe_count_overload` | Authoritative local file not found in available repos |
| `20260701185250` | `20260617_add_admin_theme_preference` | Authoritative local file not found in available repos |
| `20260702133740` | `dreamflow_generated` | Authoritative local file not found in available repos |
| `20260716144804` | `dreamflow_generated` | Authoritative local file not found in available repos |
| `20260802111327` | `20260802_create_wellbeing_check_ins` | Authoritative local file not found in Control Site; consumer app has related wellbeing migrations but not this exact version |
| `20260803124554` | `preprod_security_entitlements_admin_helpers` | Authoritative file found in consumer app history, not Control Site |
| `20260803125019` | `preprod_security_entitlement_rpc_grant_fix` | Authoritative file found in consumer app history, not Control Site |
| `20260804163012` | `revenuecat_test_store_readiness` | Authoritative file found in consumer app history with a different timestamp |
| `20260804165019` | `subscription_events_server_only` | Authoritative file found in consumer app history with a different timestamp |
| `20260809211915` | `extend_family_members_profile_context` | Authoritative local file not found in Control Site |
| `20260809211923` | `extend_family_members_profile_context` | Authoritative local file not found in Control Site |
| `20260809221818` | `20260809_add_profile_photo_path_to_family_members` | Authoritative local file not found in Control Site |
| `20260809233202` | `20260809120000_medical_records_add_injury` | Authoritative file found in consumer app history with a different timestamp |
| `20260809233305` | `202606150007_lab_panels_and_results` | Authoritative file found in consumer app history with a different timestamp |

## Repositories Inspected

- `curavault-control`: contains Control Site shortened migrations and the replaced CMS migration.
- `curavult-app`: contains consumer app migrations, including RevenueCat, subscription events, lab panels/results, medical-record injury, and other shared-project migrations.
- `curavault-website2`: no Supabase SQL migration source was found during this pass.

The shared Supabase project appears to have received migrations from more than one tooling path. The Control Site repository alone is not currently a complete authoritative migration source for the shared database.

## Live CMS Schema Evidence

Read-only live metadata showed these existing marketing CMS tables:

- `marketing_pages`
- `marketing_sections`
- `marketing_blog_posts`
- `marketing_faqs`
- `marketing_pricing_plans`
- `marketing_testimonials`
- `marketing_campaigns`
- `marketing_seo_settings`

The live CMS did not have the newer Control Site workspace tables:

- `marketing_media_assets`
- `marketing_blog_categories`
- `marketing_blog_tags`
- `marketing_blog_post_tags`
- `marketing_content_revisions`
- `marketing_social_queue`

The live versions of `marketing_pages`, `marketing_sections`, and `marketing_blog_posts` also have older column shapes. The reconciliation migration must extend these tables, not recreate or replace them.

## Migration Correction

The unapplied incompatible migration was removed from this branch:

- `supabase/migrations/20260809120000_cms_marketing_content_foundation.sql`

It was replaced by a fresh migration created with the Supabase CLI:

- `supabase/migrations/20260810003557_reconcile_existing_marketing_cms.sql`

The new migration is a forward-only delta. It:

- Creates missing CMS tables when absent.
- Extends existing live CMS tables with nullable/default-backed columns required by the current Control Site.
- Preserves older live CMS tables and columns.
- Replaces the old active-admin-only policies on the three overlapping CMS tables.
- Adds public read policies only for published, publication-time-arrived, non-archived rows.
- Separates Data API grants from RLS.
- Allows `owner` and `admin` writes.
- Allows `read_only` inspection only.
- Avoids `auth.role()`.

## Files To Retain, Replace, Or Review Later

Retain now:

- Existing shortened historical migrations, until a larger cross-repository canonicalization plan is approved.
- `20260810003557_reconcile_existing_marketing_cms.sql`

Replace now:

- `20260809120000_cms_marketing_content_foundation.sql`, because it was never applied remotely and is incompatible with the live schema.

Review later:

- Whether Control Site should vendor/copy the remote authoritative timestamped migrations from consumer/shared migration ownership.
- Whether the shared Supabase project should move to a single migrations repository.
- Whether historical local shortened migration files should be canonicalized on a separate branch.

## Why Normal `db push` Is Still Not Safe

Normal `db push` is not safe yet because the remote migration history still does not match this repository's historical migration files. Supabase will continue to see shortened local versions as different from the remote 14-digit versions.

The corrected CMS migration is reviewable, but normal migration operations should remain blocked until historical migration mapping is resolved.

## Recommended Future Plan

1. Keep this branch as a reviewable reconciliation package.
2. Review the new CMS delta migration against a local disposable database seeded with a representation of the current live CMS schema.
3. In a separate migration-history branch, decide whether to:
   - canonicalize the Control Site migrations to match remote versions, or
   - move shared-project migrations to a single authoritative repository.
4. Do not mutate `supabase_migrations.schema_migrations` until every remote version has an evidence-backed local source or an explicitly approved reconciliation record.
5. Only after history is canonicalized should normal `supabase migration list` and `supabase db push` be considered safe.

## Deployment Readiness

The CMS delta migration is designed for review. It is not approved for production application until:

- The migration has been tested against a local copy of the current live CMS shape.
- Remote migration-history reconciliation is approved.
- A dry-run shows only the intended migration would apply.
- Post-apply public/RLS checks are scripted and approved.

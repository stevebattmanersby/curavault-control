# Supabase Migration Reconciliation

This document records the local-only reconciliation work for the CuraVault Control Site Supabase migrations. It is intentionally not a deployment log.

## Scope

- Repository: `curavault-control`
- Branch: `codex/cms-schema-reconciliation`
- Linked project inspected read-only: `curavault-clean`
- Project ref: `rzq...ykq`
- Canonical recovered source: `C:\Users\User\AppData\Local\Temp\curavault-migration-fetch-20260810-015012-2287\supabase\migrations`

No remote migrations, schema, data, migration history, Edge Functions, or deployments were changed during this reconciliation.

## Current Problem

The Control Site repository previously contained shortened historical migration versions, including duplicate local versions:

- `20260614`
- `20260706`

The linked Supabase project uses unique 14-digit migration versions. The previous local migration `20260809120000_cms_marketing_content_foundation.sql` was never applied remotely and assumed a newer CMS foundation than production actually has.

The live database already contains an older marketing CMS created by remote migration `20260626120552` / `20260626_create_marketing_cms_backend`, so the unapplied local CMS foundation migration was not safe to apply as-is.

## Canonical History Recovery

The canonical remote migration SQL was recovered read-only using:

```powershell
npx.cmd --yes supabase migration fetch --linked
```

The recovered SQL was left in the disposable workspace listed above. The repository migration directory was then restored to contain exact byte-for-byte copies of those 21 canonical files plus the newer local-only CMS reconciliation delta.

The recovered source scan found no connection strings, project ref, Supabase URLs, JWTs, passwords, API keys, generated local credentials, or link metadata in the SQL. One recovered canonical migration contains synthetic sample/test rows; those are part of the canonical migration SQL and are not copied production data.

## Canonical Migration Inventory

| Version | Migration | SHA-256 |
| --- | --- | --- |
| `20260612230013` | `20260612_create_control_site_admin_tables` | `1b2e2029d351ca8de219aea01e84b99b209c341c7080efed8e0c42ab6472622e` |
| `20260614011527` | `20260614_admin_safe_reporting_rpcs` | `6a5bb855ef867319db2177ebf81c84e99ab156b5a5e8e5b83f255148092d8aa1` |
| `20260614013625` | `20260614_create_admin_safe_reporting_functions` | `f1a5ae7cdb10d12031ac6073f1d23b5856767b768fea94063c6cf342fdb791f1` |
| `20260614114331` | `20260614_create_admin_safe_reporting_functions` | `ce7ae6c9a43fbe42fe0798de0ca4e4a6c361fd4ad5b3675c0fc05ae405179671` |
| `20260614125140` | `20260616_add_privacy_safe_ai_usage_events` | `7ff910dce1e301e5dc0e279f9dac284cef7b44c8c1805e10fc1fe47e85871e1a` |
| `20260614125203` | `20260616_add_privacy_safe_ai_usage_events` | `5fc85d9152129b450b14b6427c10d7ca3ec303a78d979610ed281b1750f66058` |
| `20260626120552` | `20260626_create_marketing_cms_backend` | `99070964ddbeeac7d599126f6cef267726f2b7b8efbae943442bbe406a3e2ba5` |
| `20260701162541` | `20260616_fix_admin_safe_count_overload` | `eccbc28fccec8ce6265073c288552622c9b7f4709718097c5fa7c6b57de131eb` |
| `20260701185250` | `20260617_add_admin_theme_preference` | `09e7e2ec2580a1ba27d3f9f294639e2d28429742fe073060a448f8f949755005` |
| `20260702133740` | `dreamflow_generated` | `a8b39d9cde8bdf186343f56053fe74f568b9c5a0ee8dc5ab0e2cb85f74d6a3be` |
| `20260716144804` | `dreamflow_generated` | `e47c1780bdd7b22841d0cf0da412a852430a8896f6e4e0e06a37cd3408204b26` |
| `20260802111327` | `20260802_create_wellbeing_check_ins` | `d25aebcf7989ff7e24c1c34e135bcc8e33753daeba6c326f9cc4acafea467460` |
| `20260803124554` | `preprod_security_entitlements_admin_helpers` | `2da2a5352a7554e07a27d63e1477656db77376593293238346382812b35851cb` |
| `20260803125019` | `preprod_security_entitlement_rpc_grant_fix` | `1c9dffc41eb4bb18b9b69d27509cdb00eb3e41ee9bc623072c8909c2e58ccd98` |
| `20260804163012` | `revenuecat_test_store_readiness` | `6ab7e67c05917c7897643e20c15e892b9c05e37316e1e5bb3734822320c79814` |
| `20260804165019` | `subscription_events_server_only` | `50b8c4005fcc8090fafd5c7cd80f9d03013d16f73d60e1856bdaedeb36489271` |
| `20260809211915` | `extend_family_members_profile_context` | `945ed74e58b9acd5a11fac418bba9aac58a4ad89c56676f41c1c175d027c9f29` |
| `20260809211923` | `extend_family_members_profile_context` | `d5ef7c9641e9cf6586106f70a5daba70768e7f2f665e681c2f4f6292a33c3640` |
| `20260809221818` | `20260809_add_profile_photo_path_to_family_members` | `f3fbdf26347975104478c192f232788b58bc462eb20c11561ce8ba175616d7ca` |
| `20260809233202` | `20260809120000_medical_records_add_injury` | `d8c4174ead40ada653094bbccb218a123eaae179d3f2459777f640cf2a0fd1f5` |
| `20260809233305` | `202606150007_lab_panels_and_results` | `e6493d01cff96026d1ec887c08d8351c4fa395f63ac722b6eaa4e988dff28714` |

## Obsolete Local Files Replaced

These shortened or non-canonical historical files were removed from `supabase/migrations` and replaced by the canonical timestamped files above:

- `20260612_create_control_site_admin_tables.sql`
- `20260613_control_site_noop_schema_already_applied.sql`
- `20260614_add_privacy_safe_storage_metadata.sql`
- `20260614_admin_safe_reporting_rpcs.sql`
- `20260614_create_admin_safe_reporting_functions.sql`
- `20260615_complete_control_site_live_data_rpcs.sql`
- `20260616_add_privacy_safe_ai_usage_events.sql`
- `20260619_ai_usage_provider_service_tracking.sql`
- `20260706_complete_control_site_detail_action_rpcs.sql`
- `20260706_fix_admin_data_test_reporting_rpcs.sql`
- `20260706_fix_ai_usage_summary_ambiguous_columns.sql`
- `20260718_revenuecat_entitlement_sync.sql`

The incompatible unapplied CMS foundation migration remains removed:

- `20260809120000_cms_marketing_content_foundation.sql`

## Recovered CMS Base

The recovered `20260626120552_20260626_create_marketing_cms_backend.sql` creates the older live CMS base:

- `marketing_pages`
- `marketing_sections`
- `marketing_blog_posts`
- `marketing_faqs`
- `marketing_pricing_plans`
- `marketing_testimonials`
- `marketing_campaigns`

It also creates CMS audit and actor trigger functions, indexes, update/audit triggers, RLS, and active-admin-only policies.

It does not create the newer Control Site CMS tables:

- `marketing_media_assets`
- `marketing_blog_categories`
- `marketing_blog_tags`
- `marketing_blog_post_tags`
- `marketing_content_revisions`
- `marketing_social_queue`

## CMS Delta Correction

The retained local-only delta is:

- `supabase/migrations/20260810003557_reconcile_existing_marketing_cms.sql`

It remains a forward-only additive migration that extends the recovered base schema. The delta now deliberately replaces the known live constraint names:

- `marketing_pages_status_check`
- `marketing_sections_status_check`
- `marketing_blog_posts_status_check`

The broadened CMS workflow states are:

- `draft`
- `review`
- `scheduled`
- `published`
- `archived`

The constraints are recreated as `not valid` so existing rows are preserved while new or updated rows are checked against the broadened workflow set. Public visibility remains based on `status = 'published'`, `published_at <= now()`, and `archived_at is null`.

## Validation Findings

- Canonical source contains exactly 21 recovered remote migrations from `20260612230013` through `20260809233305`.
- Repository copies of all 21 canonical migrations matched the recovered source SHA-256 checksums after copying.
- The migration directory contains the 21 canonical files plus only `20260810003557_reconcile_existing_marketing_cms.sql` as the newer local-only delta.
- The previous shortened duplicate historical migrations are no longer present.
- `supabase/.temp/` remains intentionally ignored and must not be staged.

## Deployment Readiness

Production remains unchanged. Before any production operation is considered, validate that:

- `supabase migration list --linked` shows the 21 canonical versions aligned between local and remote.
- Only `20260810003557` appears as local-only.
- A disposable local reset either completes successfully or records any missing baseline dependencies without modifying canonical migrations.
- Focused CMS status, RLS, grants, and privileged-code checks pass locally.
- Flutter tests and analysis pass.

Normal `db push` should not be used until the linked migration-list comparison confirms that the restored canonical history aligns and only the CMS delta remains pending.

## Shared Consumer Baseline Recovery

The Control Site migration chain depends on shared consumer schema that existed
in the linked Supabase project before the canonical Control Site migration
history begins. A clean local replay failed because `20260702133740` updates
`public.user_entitlements` unconditionally after guarded `alter table if exists`
statements.

The following genuine consumer migrations were recovered into this repository
byte-for-byte so a clean local replay has the same shared baseline dependencies
as the linked project:

| Version | Source | Provenance | SHA-256 |
| --- | --- | --- | --- |
| `20260317` | `curavult-app/lib/supabase/migrations/20260317_0001_user_entitlements.sql` | Commit `cb5bc318ec7c6724584a8ddbab5a70558653bd95` (`V3 . Phase 4`) | `1f3489c0a1ec0942055a5929b6589ba114a1fa93fc56600d221db54bbad20606` |
| `20260329` | `curavult-app/lib/supabase/migrations/20260329_0002_core_health_tables.sql` | Current consumer repository baseline | `905c6cd8ba3e4be9ffe009754617f57f9b9eddf5199cf283b06f01fa0ed8a371` |
| `20260504110000` | Historical `curavult-app/supabase/migrations/20260504110000_billing_foundation.sql` | Git blob `ec3e81983a15cf84e9651bb9cf891cf75629aebc` from commit `de49d102c8792e0ab968e59a8b61053654f72a0b` | `ac3ff3c4f5dc4634ee4ac3a54cdd1b10c4dcf13740381c2a625faec681297bec` |

The baseline files are intentionally not rewritten, combined, or normalized.
They preserve their original filenames so the missing shared history is visible.

Read-only production metadata inspection showed the baseline-created shared
tables exist in the linked project or have been deliberately superseded by later
migrations:

- `public.user_entitlements` exists and is evolved to the current
  `starter | plus | family` plan vocabulary.
- `public.user_profiles`, `public.family_members`, `public.medical_records`,
  `public.medications`, `public.insurance_cards`, `public.vaccinations`,
  `public.appointments`, `public.blood_pressure_readings`, and
  `public.medical_documents` exist with RLS enabled.
- `public.subscription_events` exists and is now server-only after the later
  `subscription_events_server_only` hardening.
- The historical `stripe_customers` table from the billing foundation is no
  longer present in the linked project and is treated as superseded by the
  current Stripe/RevenueCat entitlement path rather than as an active runtime
  dependency.

Production migration history has not been repaired. The following baseline
versions remain local-only until an explicit production history repair is
approved:

- `20260317`
- `20260329`
- `20260504110000`

## Entitlement Parity Delta

The disposable replay proved two `public.user_entitlements` objects existed in
production but were not recreated by the recovered local chain:

- `user_entitlements_updated_at_idx`
- `user_entitlements_limits_check`

The live definitions inspected read-only from `curavault-clean` are:

```sql
CREATE INDEX user_entitlements_updated_at_idx
ON public.user_entitlements USING btree (updated_at);
```

```sql
CHECK (((max_storage_mb >= 0) AND (max_family_members >= 0)))
```

The check constraint is validated in production. The index is valid, ready, and
has no predicate.

The local-only parity migration
`20260810180047_entitlement_parity_baseline_objects.sql` recreates only these
two objects. It is forward-only and safe for production replay because it:

- creates the index only when missing;
- creates the constraint only when missing;
- validates an existing matching constraint when needed;
- raises instead of silently accepting an object with the same name but a
  different definition;
- does not insert, update, delete, or backfill entitlement rows.

After this reconciliation, a normal `db push` is still not appropriate until the
linked migration history is repaired or otherwise explicitly reconciled. The
expected local-only versions before that repair are:

- `20260317`
- `20260329`
- `20260504110000`
- `20260810003557`
- `20260810180047`

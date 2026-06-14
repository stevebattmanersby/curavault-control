# CuraVault Control Site — Admin-Safe Data Layer Plan

This document tracks the **admin-only, aggregate-only** reporting layer used by the CuraVault Control Site.

## Hard privacy rule (non-negotiable)

The control site must show **business/support/usage metadata only**.

It must never expose:
- Raw health content (medical record fields, appointment notes, medication instructions, readings, etc.)
- Document names, file paths, file URLs, or document contents
- AI prompts, AI responses, summaries, user-entered text, or search queries
- Support notes free-text or compliance free-text notes (beyond redacted/metadata-only workflows)

Accordingly, all reporting endpoints are **SECURITY DEFINER RPCs** that:
1) Check `public.is_active_admin()` (via `public._admin_safe_assert_active_admin()`).
2) Return **aggregates only** (counts/totals/statuses/timestamps/limits).
3) Are resilient to missing tables/columns (return 0/NULL instead of failing).
4) Are executable by `authenticated` only (revoked from `anon`/`public`).

## Live admin-safe RPCs (source of truth)

### Base dashboard / usage / billing

Migration: `supabase/migrations/20260614_create_admin_safe_reporting_functions.sql`

- `public.admin_get_dashboard_metrics()`
  - Returns one row of totals across key tables (counts only).

- `public.admin_get_user_usage_summary()`
  - Returns one row per auth user: identifiers + timestamps + per-table counts.

- `public.admin_get_usage_events_summary()`
  - Returns grouped usage analytics based on a **controlled subset** of keys.

- `public.admin_get_billing_summary()`
  - Aggregates `user_entitlements` into plan/status/provider counts.

- `public.admin_get_country_usage_summary()`
  - Aggregates usage by country; applies a k-anonymity threshold (small cohorts grouped into “Other”).

- `public.admin_get_system_health_summary()`
  - Basic operational counts over the last 24h.

### “Complete live data” layer (replacing remaining mock fallbacks)

Migration: `supabase/migrations/20260615_complete_control_site_live_data_rpcs.sql`

- `public.admin_get_storage_summary()`
  - Aggregates storage *without* returning document/file details.
  - Output:
    - `total_document_count`
    - `total_storage_used_mb` *(only if a file size column exists)*
    - `average_storage_per_user_mb`
    - `users_over_storage_limit` *(only if storage limits exist)*
    - `users_near_storage_limit` *(only if storage limits exist)*
    - `failed_upload_events_24h` *(only if usage event failure signals exist)*

- `public.admin_get_ai_usage_summary()`
  - AI operational analytics derived from `usage_events` only.
  - Output:
    - `ai_request_count`
    - `input_tokens`
    - `output_tokens`
    - `total_tokens`
    - `estimated_cost` *(only if `usage_events.estimated_cost` exists)*
    - `failed_ai_requests` *(only if failure signals exist)*
    - `users_near_ai_limit` *(only if entitlement limits + per-user attribution exist)*
    - `users_over_ai_limit` *(only if entitlement limits + per-user attribution exist)*

- `public.admin_get_compliance_summary()`
  - Compliance workflow metadata (counts by status/type + latest timestamp).
  - Output:
    - `total_requests`, `open_requests`, `in_progress_requests`, `completed_requests`, `failed_requests`
    - `deletion_requests`, `export_requests`
    - `latest_request_at`

- `public.admin_get_support_summary()`
  - Support workflow metadata (counts by status + latest timestamp).
  - Output:
    - `total_sessions`, `open_sessions`, `active_sessions`, `closed_sessions`, `expired_sessions`
    - `latest_session_at`

- `public.admin_get_plan_permission_summary()`
  - Plan breakdown from `user_entitlements`.
  - Output:
    - `plan`, `user_count`, `active_count`
    - `storage_limit_mb` *(if present)*
    - `ai_token_limit` *(if present)*
    - `profile_limit` *(if present)*

- `public.admin_get_audit_summary()`
  - Audit log operational metadata.
  - Output:
    - `total_audit_events`, `audit_events_24h`, `failed_admin_actions_24h`, `latest_audit_event_at`
  - Explicitly **does not** return `prev`/`next` JSON.

- `public.admin_get_system_health_summary_v2()`
  - Expanded operational health, still aggregate-only.
  - Output:
    - `recent_usage_events_24h`, `recent_errors_24h`, `failed_upload_events_24h`, `failed_sync_events_24h`
    - `latest_usage_event_at`, `latest_audit_event_at`, `latest_support_session_at`, `latest_compliance_request_at`

## Known / likely missing instrumentation (best-effort fallbacks)

These RPCs are designed to be **schema-resilient**. If a dependency is missing, they return safe defaults (0/NULL). That means the UI will remain honest ("not instrumented") while still loading.

### Storage reporting

`admin_get_storage_summary()` is most accurate when:
- `public.medical_documents` has **both**:
  - `owner_user_id` (for per-user aggregation)
  - one of: `file_size`, `file_size_bytes`, or `size_bytes` (for storage bytes)

Storage limit enforcement requires:
- `public.user_entitlements.user_id`
- and one of:
  - `storage_limit_mb` (preferred)
  - `storage_limit_bytes`

Upload failure reporting (24h) requires:
- `public.usage_events.created_at`
- and one of `event_key` / `event_name`
- and either `success` or `failure_code`

### AI usage reporting

`admin_get_ai_usage_summary()` is most accurate when `public.usage_events` includes:
- `event_key` or `event_name` (to classify “AI” events)
- `estimated_tokens_input` + `estimated_tokens_output` (for token totals)
- `estimated_cost` (optional)
- `success` and/or `failure_code` (for failure counts)

AI-limit computations require:
- `usage_events.user_id` (per-user attribution)
- `user_entitlements.user_id`
- and `user_entitlements.ai_token_limit` (or `ai_tokens_limit`)

### Audit failure reporting

`admin_get_audit_summary()` uses `admin_audit_log.result` as the failure signal.
If your operational tooling writes different values than `success|failure|denied`, update instrumentation to match.

## Next steps (when you’re ready)

1) Update Flutter query parsing + repository methods to call these new RPCs (and remove remaining mock fallbacks in release mode).
2) Add a control-site “Instrumentation status” panel that surfaces which metrics are 0 because tables/columns are missing.

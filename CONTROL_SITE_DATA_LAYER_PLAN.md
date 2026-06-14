# CuraVault Control Site — Admin-Safe Reporting Layer

This document describes the **admin-safe** (aggregate-only) reporting RPCs used by the CuraVault Control Site.

## Non-negotiable privacy rules

These RPCs must never expose raw health content.

**Never return (directly or indirectly):**
- medical record titles/content
- appointment details
- medication names
- vaccination names
- blood pressure values
- family member names
- document names / file paths
- AI prompts / AI responses
- search query text

**Allowed:** counts, totals, statuses, timestamps, country/platform/plan aggregates, and other business/support metadata.

## Migration that implements these RPCs

**File:** `supabase/migrations/20260614_create_admin_safe_reporting_functions.sql`

### Security model

- All reporting RPCs are **`SECURITY DEFINER`**.
- Each function calls `public.is_active_admin()` via an internal guard and **raises a safe access denied** error if false.
- Each function sets a **safe `search_path`** (at minimum `public`; and `auth` only where needed).
- Execution privileges are:
  - **granted to** `authenticated`
  - **revoked from** `anon` and `public`
- No RLS policies are changed and **no health tables are modified**.

### Schema-robust behavior (tables/columns may be missing)

To avoid failures when tables/columns are absent:

- The migration defines helpers:
  - `public._admin_safe_table_exists(qualified_table)`
  - `public._admin_safe_column_exists(schema, table, column)`
  - `public._admin_safe_count(qualified_table, where_sql)`
  - `public._admin_safe_count_uuid(qualified_table, where_sql, user_id)`
- RPCs use **dynamic SQL** and existence checks, so:
  - dashboard metrics return **0** for missing tables
  - other RPCs return **empty sets** or safe defaults when inputs are missing

## RPCs created

### 1) `public.admin_get_dashboard_metrics()`

Returns **one row** containing safe total counts:

- `total_auth_users`
- `total_admin_users`, `active_admin_users`
- `total_user_profiles`
- `total_family_members`
- `total_medical_records`
- `total_appointments`
- `total_medications`
- `total_vaccinations`
- `total_blood_pressure_entries`
- `total_medical_documents`
- `total_insurance_cards`
- `total_usage_events`
- `total_subscription_events`
- `total_user_entitlements`
- `total_audit_events`
- `total_support_sessions`, `open_support_sessions`
- `total_compliance_requests`, `open_compliance_requests`

**Missing table handling:** if any referenced public table doesn’t exist, the metric returns **0**.

### 2) `public.admin_get_user_usage_summary()`

Returns **one row per Auth user** (from `auth.users`) with:

- `user_id`
- `email` (from `auth.users.email`, when present)
- `created_at`, `last_sign_in_at`
- per-user counts only (profiles/family members/records/etc.)

**No raw health content is ever returned**—only counts.

**Missing table handling:** any missing counted table yields a **0** count for that field.

### 3) `public.admin_get_usage_events_summary()`

Aggregates `usage_events` into:

- `event_name`
- `feature_area`
- `platform`
- `app_version`
- `country`
- `event_count`
- `unique_user_count`
- `first_seen_at`, `last_seen_at`

**Missing column handling:**
- If `event_name` doesn’t exist, falls back to `event_key`; otherwise `'unknown'`.
- If `properties` doesn’t exist, platform/app_version/country default to `'unknown'`.
- If `created_at` doesn’t exist, `first_seen_at/last_seen_at` are `NULL`.

### 4) `public.admin_get_billing_summary()`

Aggregates `user_entitlements` (and optionally `subscription_events`) into:

- `plan`
- `billing_status`
- `subscription_provider`
- `user_count`
- `active_count`
- `cancelled_count`
- `failed_payment_count` (best-effort, conservative signal)

**Missing table/column handling:**
- If `user_entitlements` is missing, returns **no rows**.
- If expected columns are missing, returns `'unknown'` labels and **0** for derived counts.

### 5) `public.admin_get_country_usage_summary()`

Aggregates usage by country:

- `country`
- `user_count`
- `active_user_count`
- `usage_event_count`
- `storage_used_mb` (only if doc size columns exist)
- `ai_tokens_used` (only if token columns exist)

**Privacy rule:** if a country has **fewer than 10 users**, it is grouped under **`Other`**.

**Missing column handling:**
- If token columns are missing, `ai_tokens_used = 0`.
- If medical document size columns are missing, `storage_used_mb = 0`.

### 6) `public.admin_get_system_health_summary()`

Returns one row with operational aggregates:

- `recent_usage_events_24h`
- `recent_errors_24h` (based on `success` and/or `failure_code` columns when present)
- `failed_upload_events_24h` (best-effort)
- `failed_sync_events_24h` (best-effort)
- `latest_usage_event_at`
- `latest_audit_event_at`
- `latest_support_session_at`

**No raw error payloads** are returned.

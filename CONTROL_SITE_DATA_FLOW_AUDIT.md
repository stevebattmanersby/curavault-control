# CuraVault Control Site – Data Flow Audit

Date: 2026-06-14

This document is a **privacy + wiring audit** of each main CuraVault Control Site admin page.

Hard rules (must hold for every page):

* Frontend must **not** query raw health tables directly.
* Frontend calls are limited to:
  * **admin-safe RPCs** (SECURITY DEFINER, gated by `public.is_active_admin()`)
  * **admin/control tables** (e.g., `admin_users`, `admin_audit_log`, `admin_support_sessions`, `admin_compliance_requests`)
* Do **not** expose: medical record contents/titles, document/file names, file paths, appointments, medications/vaccinations names, BP values, family member names, AI prompts/responses, search query text.

## Page-by-page wiring

Legend:

* **Live**: Supabase RPC/view is called and parsed.
* **Mock (debug-only)**: mock fallback may be used **only** in debug; UI must label it.
* **Not instrumented**: backend source missing; UI must show explicit empty/not-instrumented state.
* **Empty**: live call works but returns 0 rows/0 totals.

### Dashboard

* **Current data source:** Live
* **RPC used:** `public.admin_get_dashboard_metrics()`
* **Aggregates behind RPC:** `auth.users`, `public.admin_users`, and best-effort counts from (if present):
  * `public.user_profiles`, `public.family_members`, `public.medical_records`, `public.appointments`, `public.medications`, `public.vaccinations`, `public.blood_pressure_readings`, `public.medical_documents`, `public.insurance_cards`, `public.usage_events`, `public.subscription_events`, `public.user_entitlements`, `public.admin_audit_log`, `public.admin_support_sessions`, `public.admin_compliance_requests`
* **Status:** Live / Empty (if totals are all 0)
* **If blank:** Usually either (a) no underlying tables exist yet, or (b) RPC not deployed / not authorized.
* **Fix required:** Deploy the migration(s) containing the RPCs; ensure the signed-in admin is active.
* **Privacy risk level:** Low (counts only)

### Users

* **Current data source:** Live
* **RPC used:** `public.admin_get_user_usage_summary()`
* **Aggregates behind RPC:** `auth.users` + per-user counts from the same set of domain tables as Dashboard (best-effort, returns 0 when missing).
* **Status:** Live / Empty
* **If blank:** Either no users exist in `auth.users`, or the RPC is not deployed/authorized.
* **Fix required:** Deploy RPC; confirm admin allow-list + `public.is_active_admin()`.
* **Privacy risk level:** Medium (returns email for allowed roles; still no medical content)

### Usage Analytics

* **Current data source:** Live
* **RPC used:** `public.admin_get_usage_events_summary()`
* **Additional RPC used:** `public.admin_get_country_usage_summary()`
* **Aggregates behind RPC:** `public.usage_events` (only controlled metadata keys) + optional storage bytes derived from documents (aggregate only).
* **Status:** Live / Empty
* **If blank:** No `usage_events` collected yet, or the table does not exist.
* **Fix required:** Instrument the main CuraVault app to write privacy-safe `usage_events`.
* **Privacy risk level:** Low

### Storage

* **Current data source:** Live
* **RPC used (preferred):** `public.admin_get_storage_summary_v2()`
* **RPC used (fallback):** `public.admin_get_storage_summary()`
* **Aggregates behind RPC:**
  * Preferred: `public.document_storage_metadata` (privacy-safe bytes/status only)
  * Fallback: `public.medical_documents` (aggregate byte totals only; never names/paths)
  * Limits: `public.user_entitlements` (storage limit fields)
  * Errors: optionally `public.usage_events` for recent failures (aggregate only)
* **Status:** Live / Empty
* **If blank:** Metadata table not instrumented, or documents table lacks size columns.
* **Fix required:** Instrument main app uploads to maintain `document_storage_metadata`.
* **Privacy risk level:** Low

### AI Usage

* **Current data source:** Live
* **RPC used:** `public.admin_get_ai_usage_summary()`
* **Aggregates behind RPC:** `public.ai_usage_events` (metadata-only; no prompts/outputs).
* **Status:** Live / Empty
* **If blank:** No AI events collected yet.
* **Fix required:** Instrument main app to insert `ai_usage_events` (metadata only).
* **Privacy risk level:** Low

### Billing

* **Current data source:** Live
* **RPC used:** `public.admin_get_billing_summary()`
* **Aggregates behind RPC:** `public.user_entitlements` (plan/status/provider fields) + optional `public.subscription_events` for failure signals.
* **Status:** Live / Empty
* **If blank:** No entitlements collected yet or entitlements table not deployed.
* **Fix required:** Ensure entitlement writing is instrumented in main app.
* **Privacy risk level:** Low

### Support

* **Current data source:** Live
* **RPC used (summary):** `public.admin_get_support_summary()`
* **Table used (queue list):** `public.admin_support_sessions`
* **Status:** Live / Empty
* **If blank:** No support sessions recorded yet.
* **Fix required:** Instrument support-session creation in the admin backend (or main app, depending on design).
* **Privacy risk level:** Medium (includes operational support metadata; no health content)

### Compliance

* **Current data source:** Live
* **RPC used (summary):** `public.admin_get_compliance_summary()`
* **Table used (details/list):** `public.admin_compliance_requests` (metadata-only)
* **Status:** Live / Empty
* **If blank:** No compliance requests recorded yet.
* **Fix required:** Instrument compliance workflow table writes.
* **Privacy risk level:** Medium (sensitive workflows; still no medical content)

### System Health

* **Current data source:** Live
* **RPC used:** `public.admin_get_system_health_summary()` or `public.admin_get_system_health_summary_v2()`
* **Aggregates behind RPC:** best-effort operational aggregates over `public.usage_events`, `public.admin_audit_log`, `public.admin_support_sessions`, and optionally `public.admin_compliance_requests`.
* **Status:** Live / Empty
* **If blank:** No usage/audit/support activity exists yet.
* **Fix required:** Ensure the relevant operational tables exist and are being written.
* **Privacy risk level:** Low

### Audit Logs

* **Current data source:** Live
* **RPC used (summary):** `public.admin_get_audit_summary()`
* **Table used (list):** `public.admin_audit_log` (redacted payloads)
* **Status:** Live / Empty
* **If blank:** No audited actions have been recorded yet.
* **Fix required:** Ensure every privileged admin action writes an audit row.
* **Privacy risk level:** Medium (audit metadata; payloads must stay redacted)

### Plans & Permissions

* **Current data source:** Live (summary only)
* **RPC used:** `public.admin_get_plan_permission_summary()`
* **Aggregates behind RPC:** `public.user_entitlements` (plan/status/limit fields)
* **Status:** Live / Empty
* **If blank:** No entitlements collected yet.
* **Fix required:** Instrument entitlements.
* **Privacy risk level:** Low

## Known reasons pages can appear “blank”

1. **RPC not deployed** (migration not applied) → page should show **Not instrumented**.
2. **RPC deployed but returns zero rows / all-zero aggregates** because the main app isn’t sending events yet → page should show **No data has been collected yet.**
3. **RPC call fails due to auth/RBAC** (inactive admin, allow-list missing, etc.) → page should show a **safe error** and the owner-only diagnostics panel should show the RPC name.

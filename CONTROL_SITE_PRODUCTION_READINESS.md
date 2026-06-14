# CuraVault Control Site — Production Readiness Review

Date: 2026-06-14

Scope: Flutter **CuraVault Control Site** (this repo) + Supabase-backed admin-safe reporting RPCs.

This review focuses on **production safety**: auth gating, role routing, data-layer wiring, privacy (no PHI), and security hardening. It also calls out remaining areas that are **mocked / not instrumented** so the UI cannot appear “working” in production when it isn’t.

---

## 1) Authentication

### Login
- **Implemented:** `AdminAuthStore.signInWithPassword()` + `LoginPage`.
- **Behavior:**
  - Authenticates via Supabase Auth (anon key).
  - Then performs allow-list + active check via `public.admin_users` lookup in `SupabaseAdminQueries.getCurrentAdminUser()`.
  - If not allow-listed / inactive / unknown role ⇒ the router redirects to `/unauthorized`.
- **Dev-only diagnostics:** `DevLoginStagePanel` is shown **only in `kDebugMode`**.

### Logout
- **Implemented:** `AdminAuthStore` maintains session via `onAuthStateChange`; sign-out should invalidate session and trigger redirects.
- **Status:** Not re-verified in this pass (ensure a visible sign-out action exists in the shell/settings).

### Password reset
- **Implemented:** `ResetPasswordPage` + `AdminAuthStore.sendPasswordResetEmail()` (invoked from `LoginPage` “Forgot password”).
- **Redirect correctness:** Redirect target is derived from `CONTROL_SITE_BASE_URL` via `SupabaseConfig.setPasswordRedirectUrl` (`.../#/set-password`).
- **Security:** UI uses a neutral success message regardless of email existence; dev-only error details are hidden outside debug.

### Invite / set-password
- **Implemented:** `SetPasswordPage` route (`/#/set-password`) and `LoginPage` fragment-forwarding when an invite/recovery link incorrectly lands on `/#/login`.
- **Risk:** Invite/recovery flows are sensitive to Supabase Auth Site URL + redirect URL configuration; must be validated in the production Supabase project.

### Allow-list
- **Implemented:** allow-list is enforced by requiring a row in `public.admin_users` with `admin_user_id = auth.uid()`.
- **Status:** **Live** (depends on `admin_users` table + correct RLS).

### Inactive admin block
- **Implemented:** `getCurrentAdminUser()` filters `is_active = true` and denies if missing.
- **Status:** **Live**.

### Role routing / RBAC
- **Implemented:** `AppRouter.redirect` uses `AdminRbac.canAccessRoute(role, location)`.
- **Status:** **Live** client-side; must be paired with server-side enforcement via RPC gating/RLS.

### Dev routes exposure
- `/supabase-connectivity-test`, `/admin-test`, `/admin-data-test` exist but are **debug-only**:
  - In `nav.dart`, `enableDevRoutes = kDebugMode`.
  - In non-debug builds the route builders resolve to `UnauthorizedPage` and redirect blocks access.

**Auth conclusion:** Functionally strong and fail-closed by default. Remaining risk is primarily **Supabase Auth configuration correctness** (site URL + redirects) and ensuring **RLS** matches the intended allow-list and active-admin rules.

---

## 2) Data layer (RPC coverage)

Primary implementation:
- Repository: `lib/admin/data/supabase/supabase_admin_repository.dart`
- Queries: `lib/admin/data/supabase/supabase_admin_queries.dart`

Key production-safety behavior:
- If an RPC/view/table is missing:
  - **Release:** repository throws `AdminNotInstrumentedException` (fail-closed; **no mock**).
  - **Debug:** may fall back to `MockFallbackData` and marks the data source as **mock (debug only)**.

### Required admin-safe RPCs and wiring status

| Area | RPC / source expected | App wiring status |
|---|---|---|
| Dashboard | `admin_get_dashboard_metrics()` | **Live** (RPC called, parsed as TABLE → list row) |
| Users summary | `admin_get_user_usage_summary()` | **Partially live** (counts + created/last sign-in; many fields placeholders) |
| Usage analytics | `admin_get_usage_events_summary()`, `admin_get_country_usage_summary()` | **Expected live** (wired previously; re-verify page output) |
| Storage | `admin_get_storage_summary()` | **Expected live** (wired previously; re-verify) |
| AI usage | `admin_get_ai_usage_summary()` | **Expected live** (wired previously; re-verify) |
| Billing | `admin_get_billing_summary()` | **Expected live** (wired previously; re-verify) |
| Support | `admin_get_support_summary()` + queue list source | **Partially live** (summary/list live; **detail mocked/not instrumented**) |
| Compliance | `admin_get_compliance_summary()` | **Expected live** (wired previously; re-verify) |
| System health | `admin_get_system_health_summary()` | **Expected live** (wired previously; re-verify) |
| Audit logs | audit list + `admin_get_audit_summary()` (or summary view) | **Partially live** (list + summary attempt live; verify schema/RPC exists) |

Notes:
- The query layer uses `rpc('admin_get_...')` and only falls back to legacy `control_*` RPCs where present.
- Any page that relies on `getUserDetail()` or admin actions is explicitly **not instrumented in release**.

---

## 3) Data completeness by dashboard section

This section is about what the UI can truthfully represent in production.

### Executive dashboard (`/dashboard`)
- **Status:** **Live** via `admin_get_dashboard_metrics()`.
- **Completeness:** **Mostly live** (aggregate counts). Any sub-metrics not returned by the RPC will show as `0` or omitted.

### Users (`/users` + `/users/:userId`)
- Users list summary:
  - **Status:** **Partially live** via `admin_get_user_usage_summary()`.
  - **Gaps:** plan/country/platform/app version/storage/AI tokens appear as placeholders in the mapping today.
- User detail:
  - **Status:** **Not instrumented in release** (repository throws) / **mock in debug**.

### Usage analytics (`/usage-analytics`)
- **Status:** **Expected live** (admin-safe RPC summaries). Needs confirmation against production DB.
- **Instrumented inputs:** `public.usage_events` is written by `lib/services/usage_event_service.dart` (privacy-safe metadata only).

### Storage (`/storage`)
- **Status:** **Expected live**.
- **Instrumented inputs:** `public.document_storage_metadata` is written by `lib/services/document_storage_metadata_service.dart` (bytes/status only).

### AI usage (`/ai-usage`)
- **Status:** **Expected live**.
- **Instrumented inputs:** `public.ai_usage_events` exists via migration; ensure the main app writes these events (privacy-safe).

### Billing (`/billing`)
- **Status:** **Expected live** via billing summary RPC.
- **Risk:** Billing sources often come from Stripe/webhooks; confirm the summary is actually fed by real data.

### Support (`/support` + detail)
- Queue/list + summary:
  - **Status:** **Live/partially live** (depends on backing table/RPC).
- Support session detail:
  - **Status:** **Not instrumented in release** / **mock in debug**.

### Compliance (`/compliance`)
- **Status:** **Expected live**.

### System health (`/system-health`)
- **Status:** **Expected live**.

### Audit logs (`/audit-logs`)
- **Status:** **Live/partially live** (list + summary). Must confirm production RLS allows active admins to read the safe audit log table/view.

### Security checklist (`/security-checklist`)
- **Status:** **Likely live** (depends on implementation source; intended to be aggregate-only).

---

## 4) Privacy review (no raw health content)

Intended posture: the control site must not expose any of:
- medical record contents
- document text
- document names/paths/URLs
- AI prompts/responses
- user-entered notes
- search queries

Findings:
- Query layer documentation and patterns in `SupabaseAdminQueries` strongly emphasize aggregate-only access.
- Instrumentation services added to the main app are metadata-only:
  - `UsageEventService` writes event metadata (feature area, platform, duration, error_code, etc.)
  - `DocumentStorageMetadataService` writes byte counts + coarse mime group + status
  - `ai_usage_events` migration explicitly forbids content storage by design

**Privacy conclusion:** No direct evidence of PHI exposure in the admin query layer from reviewed files. The remaining privacy risk is **server-side**: ensure the RPCs/views referenced are aggregate-only and do not accidentally select text columns.

---

## 5) Security review

### No service role key in frontend
- `SupabaseConfig` and `AdminAuthStore.initializeSupabase()` explicitly **fail closed** if `SUPABASE_SERVICE_ROLE_KEY` is detected.
- `lib/admin/data/supabase/supabase_client.dart` documents anon-only usage.

### No public diagnostic pages
- Dev-only routes exist but are gated by `kDebugMode` at both redirect and route builder levels (`nav.dart`).
- Login diagnostic panel is shown only in debug (`kDebugMode`).

### No bootstrap function enabled
- `lib/supabase/config.toml` sets `functions.bootstrap_admin_auth_user.enabled = false`.
- Edge function source still exists at `lib/supabase/functions/bootstrap_admin_auth_user/index.ts`.

### No mock data in production
- `SupabaseAdminRepository` uses `kReleaseMode` to throw `AdminNotInstrumentedException` instead of returning `MockFallbackData`.
- Several flows are intentionally **not instrumented** (e.g., user detail, admin actions, support detail). This is correct fail-closed behavior.

### No hardcoded preview URLs
- Supabase config uses `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CONTROL_SITE_BASE_URL`.

### RLS/RPC permissions
- Client assumes:
  - `public.admin_users` is readable for the current admin row under RLS.
  - `admin_get_*` RPCs are executable only for authenticated **active admins**.
- **Not validated in this pass in code** (must be validated in Supabase via SQL/policies).

---

## 6) Production blockers

### P0 (blocking)
1. **User detail + admin actions not instrumented**
   - `getUserDetail()` and `performUserAdminAction()` are mock in debug and **throw in release**.
   - Result: `/users/:userId` and any admin actions cannot ship as working features.
2. **Support session detail not instrumented**
   - `getSupportSessionDetail()` throws in release.
3. **RLS/RPC enforcement not proven in this repo**
   - Must verify in the production Supabase project:
     - `admin_get_*` RPCs all gate via `public.is_active_admin()` (or `_admin_safe_assert_active_admin()`).
     - `EXECUTE` privileges granted appropriately (typically `authenticated`) without opening data to non-admin users.
4. **CONTROL_SITE_BASE_URL must be set in production builds**
   - Password reset and invite flows depend on it.

### P1 (important)
1. **Users list is partially live**
   - Mapping currently fills plan/country/platform/appVersion/storage/AI token fields with placeholders even if RPC could return them.
2. **Audit logs: confirm live data source + retention**
   - Ensure `admin_audit_log` schema matches what UI expects and is not overly permissive.
3. **Remove edge-function source or add stronger owner-only guardrails**
   - Even though disabled, shipping the function source increases accidental-enable risk.

### P2 (later)
1. Add automated “instrumentation health” page/endpoint (admin-only) to detect missing RPCs before release.
2. Add e2e tests for auth redirects + RBAC route access.

---

## 7) Go-live decision

**Decision: internal beta only**

Rationale:
- Core auth + allow-list gating looks production-oriented.
- However, several key pages/actions are still **not instrumented** and will fail closed in release.
- Before public production, server-side permissions and the remaining live-data gaps must be closed.

---

## 8) Required fixes before production (prioritized)

### P0 — must fix before public production
1. Implement admin-safe **user detail** RPC/view and wire `getUserDetail()`.
2. Implement server-side **admin actions** RPC(s) with mandatory audit logging + RBAC.
3. Implement privacy-safe **support session detail** RPC/view and wire `getSupportSessionDetail()`.
4. Verify **RLS + EXECUTE privileges** for:
   - `public.admin_users`
   - all `admin_get_*` RPCs
   - `admin_audit_log` read policies (and write policies for audit inserts)
5. Confirm `CONTROL_SITE_BASE_URL` is correctly set and matches Supabase Auth Site URL.

### P1 — important for a polished production launch
1. Expand `admin_get_user_usage_summary()` to include plan/country/platform/app_version/storage/AI tokens if available; update parsing/mapping accordingly.
2. Confirm billing and compliance summaries are backed by real event sources (Stripe/webhooks, compliance workflow tables).
3. Remove or fully owner-lock any remaining dev-only tooling beyond the current `kDebugMode` gating (optional defense-in-depth).

### P2 — follow-ups
1. Add runtime self-check that lists missing RPCs/relations for owners (admin-only) and records an audit event.
2. Add CI checks to prevent reintroducing hardcoded URLs/keys and prevent enabling bootstrap functions.

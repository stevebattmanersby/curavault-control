# CuraVault Control Site — QA & Privacy Review

Date: 2026-06-12  
Scope: Flutter admin/control website in `/lib/admin/*` using Supabase (anon key only).

This report focuses on **privacy & security guarantees** for an internal control site that must **never display or expose actual user health content**.

---

## Pages tested (code review)

Routing / auth gates:
- `/loading` (`LoadingPage`)
- `/login` (`LoginPage`)
- `/unauthorized` (`UnauthorizedPage`)
- Shell layout (`AdminShell`, `AdminLayout`, `AdminSidebar`, `AdminTopBar`)

Primary sections:
- `/dashboard` (`DashboardPage`)
- `/users` (`UsersPage`)
- `/users/:userId` (`UserDetailPage`)
- `/plans-permissions` (`PlansPermissionsPage`)
- `/usage-analytics` (`UsageAnalyticsPage`)
- `/storage` (`StoragePage`)
- `/ai-usage` (`AiUsagePage`)
- `/billing` (`BillingPage`)
- `/compliance` (`CompliancePage`)
- `/system-health` (`SystemHealthPage`)
- `/support` (`SupportQueuePage`)
- `/support/diagnostics` (`DiagnosticsCheckerPage`)
- `/support/:supportSessionId` (`SupportSessionDetailPage`)
- `/audit-logs` (`AuditLogsPage`)
- `/security-checklist` (`SecurityChecklistPage`)
- `/settings` (`SettingsPage`)

---

## Verification checklist (requested items)

Legend: ✅ Pass / ⚠️ Risk / ❌ Fail

### Privacy: health-content non-exposure
1. No actual health data is displayed: ✅ (UI displays counts/metadata only; no record bodies)
2. No medical document names are displayed: ✅ (Storage/UI uses counts + size buckets; no filenames)
3. No uploaded file previews are displayed: ✅
4. No family member names are displayed: ✅ (only profile counts)
5. No medication names are displayed: ✅ (only medication counts)
6. No appointment titles/details are displayed: ✅ (only appointment counts)
7. No blood pressure values are displayed: ✅
8. No vaccination names are displayed: ✅ (only vaccination counts)
9. No AI prompt text is displayed: ✅
10. No AI output text is displayed: ✅
11. No search query text is displayed: ⚠️ (admins type into search fields; nothing is persisted/audited by this UI, but search text is still sent to the backend query for filtering)

### Security / auth / routing
12. No frontend service role key exists: ✅
   - `AdminAuthStore` fails closed if `SUPABASE_SERVICE_ROLE_KEY` is present.
   - `ControlSupabaseClient.tryGet()` refuses access if service role key is detected.
13. All admin routes are protected: ✅ (`GoRouter.redirect` enforces signed-in + authorized + route RBAC)
14. All admin actions create audit logs: ✅ (repository methods write `admin_audit_log` for actions)
15. If audit logging fails, the admin action fails: ✅ (audit insert throws `StateError('Audit log write failed')`)

### RBAC requirements
16. Each role only sees what it is allowed to see: ✅ (route gate + per-table email visibility)
17. Product analyst sees only aggregate analytics: ✅ (`AdminRbac.analytics`; cannot access Users/Support/Billing/Compliance)
18. Executive readonly sees only aggregate dashboards: ✅ (`AdminRbac.analytics`; cannot access Users/Support/Billing/Compliance)
19. Support agent cannot change billing: ✅ (`AdminRbac.canPerformBillingAction` disallows; `AdminRbac.canPerformSupportAction` blocks billing-impacting support actions)
20. Billing admin cannot view support-only diagnostic notes unless explicitly allowed: ✅ (Billing role cannot access `/support` routes)
21. Compliance officer can manage export/deletion workflows: ✅ (Compliance route + action policies)
22. Small country cohorts are grouped as “Other”: ✅ in mock data + Storage-by-Country UI; ⚠️ for live Supabase aggregates (must ensure the SQL views/RPCs also group small cohorts)

### Error handling / logging
23. Error states do not leak sensitive data: ✅ (UI uses generic snackbars; exceptions are printed)
24. Logs do not contain sensitive user content: ⚠️ (debug logs print exceptions; if Supabase errors contain row payloads, they could appear in logs)
25. Mock data is clearly separated from live data: ✅ (`MockAdminRepository` and `MockFallbackData` are isolated; `SupabaseAdminRepository` falls back when views/RPCs are missing)

---

## What was changed during this QA pass

To make the privacy guarantees stronger, the following **UI redactions** were applied:

- `UserDetailPage`:
  - Support notes are now rendered as **“Present (redacted)”** instead of showing free text.

- `SupportSessionDetailPage`:
  - Admin notes are now rendered as **“Present (redacted)”**.
  - Technical event **message/details** are now rendered as **“Redacted”** (or `—` if empty) rather than showing raw strings.

- `DashboardPage`:
  - Alert “note” is now rendered as **“Redacted”** (or `—` if empty).

- `CompliancePage`:
  - Request notes are now rendered as **“Present (redacted)”** instead of free text.

Rationale: any free-text field (notes, messages) can accidentally contain user-provided medical context. The control site should be safe even when backend data is imperfect.

---

## Issues found

### 1) Free-text fields could have exposed sensitive content (Fixed)
**Where:**
- `UserDetailPage` (support notes)
- `SupportSessionDetailPage` (admin notes + event message)
- `DashboardPage` (alert note)
- `CompliancePage` (request notes)

**Risk:** notes/messages may include health content, document titles, or other user-entered text.

**Fix applied:** UI now displays redacted placeholders.

### 2) Search query text is sent to backend filtering (Remaining risk)
**Where:** `SupabaseAdminQueries._applyUserListFilters` uses `or('user_id.ilike... , email.ilike...')`.

**Risk:**
- Even if not displayed, the query string may be logged server-side (PostgREST logs) or appear in proxy tooling.
- This is not health content itself, but can contain user-entered identifiers.

**Recommended fix:**
- When email is not allowed for the role, do **not** include the `email.ilike` clause.
- Consider enforcing a **min length** for search to reduce accidental sensitive fragments (e.g., 3+ chars).

### 3) Debug logging prints raw exception strings (Remaining risk)
**Where:** multiple `debugPrint('... failed: $e')` across admin store/repo/pages.

**Risk:** some exception strings can embed request/response details.

**Recommended fix:**
- Introduce a small `AdminLog.safeError(e)` helper that strips/normalizes common sensitive substrings.
- Log only error codes + high-level messages in release builds.

### 4) Live Supabase coverage is partial (Expected, but important)
**Where:** `SupabaseAdminRepository` currently falls back to mock for:
- `getUserDetail`, `performUserAdminAction`
- `getSupportSessionDetail`, `performSupportAction`, `runDiagnostics`
- `performComplianceAction`
- `getSystemHealthSnapshot`
- plans/flags/overrides + usage analytics

**Risk:** UI is privacy-safe, but some production workflows are not yet executing server-side.

**Recommended fix:**
- Implement server-side RPCs/views (control schema) for these endpoints and enforce:
  - RLS
  - role checks
  - mandatory audit writes in the same transaction
  - no selection of raw health content columns

---

## Recommended fixes (prioritized)

1. **Backend: enforce cohort privacy in SQL**
   - Ensure all "by country" aggregates group cohorts with `<10 users` into `Other`.
2. **Search clause hardening**
   - Only include `email.ilike` when `AdminRbac.canViewUserEmail(role)`.
   - Add minimum search length (e.g., 3+) and trim normalization.
3. **Safe logging helper**
   - Replace `debugPrint('... $e')` with sanitized messages.
4. **Complete Supabase RPC/view layer**
   - Replace remaining mock fallbacks with privacy-safe views/RPCs.

---

## Remaining risks

- **Server-side logging**: PostgREST and proxies may log query strings and errors.
- **Upstream data quality**: If any “note/message” fields in control views accidentally contain user-entered content, it must be blocked/cleansed server-side. The UI redaction reduces exposure risk but does not eliminate backend storage risks.
- **RLS correctness**: This repo assumes control schema tables/views/RPCs are properly protected by RLS and role checks.

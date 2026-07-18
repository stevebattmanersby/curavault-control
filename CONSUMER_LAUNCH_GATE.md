# CuraVault — Consumer Launch Gate Checklist

This checklist is the **final gate** for a consumer paid launch. It is designed to be **front-end verifiable** where possible, and to prevent “looks-live” dashboards from masking missing instrumentation.

**Rule:** Do **not** mark launch-ready unless **all P0 items are PASS**.

---

## How to use this document

For each section:

- Set **Status**: `PASS` / `FAIL` / `PARTIAL`
- Provide **Evidence**: links, screenshots, Control Site pages, logs, function URLs, store console references, test receipts, etc.
- Assign **Blocker Level**: `P0` (launch blocking), `P1` (should fix pre-launch), `P2` (post-launch acceptable)
- Assign **Owner** and **Target Fix Date**

Use the **Launch Decision** table at the end as the final sign-off.

---

## 1) Auth / Account

**Status:** ☐ PASS ☐ FAIL ☐ PARTIAL  \
**Evidence:**  \
**Blockers:** (P0/P1/P2)  \
**Owner:**  \
**Target fix date:**

### Pass/Fail checks

| Check | Pass criteria | Blocker | Result | Evidence |
|---|---|---:|:---:|---|
| Sign up | New user can create account reliably (mobile + web if supported) | P0 | ☐ | |
| Login | Existing user can log in; session persists; refresh works | P0 | ☐ | |
| Logout | Logout clears local session and server session where applicable | P0 | ☐ | |
| Password reset | Reset email/flow works end-to-end; rate limiting in place | P0 | ☐ | |
| Delete account UI/URL/action | User-accessible delete flow exists (in-app and/or web URL) | P0 | ☐ | |
| Backend account deletion | Backend deletes/disables account and revokes access immediately | P0 | ☐ | |
| Profile data cleanup | Deletion cleans profile + derived data per policy (or hard-disables) | P0 | ☐ | |
| Re-auth requirements | Sensitive actions require recent auth (where appropriate) | P1 | ☐ | |
| Abuse controls | Brute force + enumeration mitigations validated | P1 | ☐ | |

Notes:
- If using Supabase Auth: confirm provider configs, redirect URLs, and email template domains are correct.
- If account deletion is “soft delete,” ensure access is revoked and retention policy is documented.

---

## 2) Billing / RevenueCat

**Status:** ☐ PASS ☐ FAIL ☐ PARTIAL  \
**Evidence:**  \
**Blockers:** (P0/P1/P2)  \
**Owner:**  \
**Target fix date:**

### Pass/Fail checks

| Check | Pass criteria | Blocker | Result | Evidence |
|---|---|---:|:---:|---|
| RevenueCat SDK installed (mobile) | iOS + Android app includes RevenueCat SDK and initialization | P0 | ☐ | |
| iOS public key configured | Correct RC iOS API key for environment; no secrets in logs | P0 | ☐ | |
| Android public key configured | Correct RC Android API key for environment; no secrets in logs | P0 | ☐ | |
| Offerings load | App can fetch offerings reliably on cold start + retry | P0 | ☐ | |
| Products available | Correct products appear (monthly/annual/etc.) | P0 | ☐ | |
| Purchase works (sandbox) | Purchase completes in sandbox/test and unlocks entitlement | P0 | ☐ | |
| Restore works | Restore purchases re-grants entitlement on new install | P0 | ☐ | |
| CustomerInfo → unlock | Feature gating is driven by active entitlement(s) | P0 | ☐ | |
| Supabase user_entitlements sync | RC state syncs into Supabase `user_entitlements` reliably | P0 | ☐ | |
| Webhook deployed | RevenueCat webhook endpoint deployed + reachable | P0 | ☐ | |
| Webhook idempotency | Duplicate events don’t double-apply entitlements; safe retries | P0 | ☐ | |
| Cancellation handled | Cancel events update access appropriately | P0 | ☐ | |
| Expiration handled | Expired subscriptions remove access promptly | P0 | ☐ | |
| Billing issue handled | Billing issue/past_due shows correct degraded state | P0 | ☐ | |
| Trial end handled | Trial end transitions are accurate and timely | P0 | ☐ | |
| app_user_id = Supabase auth.uid | RC App User ID matches Supabase `auth.uid()` for joins | P0 | ☐ | |
| Control Site Billing status | Billing page shows **live** RC-backed status, not mocked | P0 | ☐ | |
| Free plan limits enforced | Non-paying users limited as designed (server-authoritative) | P0 | ☐ | |
| Paid/Pro limits enforced | Paying users granted correct limits/features (server + client) | P0 | ☐ | |

Notes:
- RevenueCat is the **source of purchase truth**. Supabase should reflect it for app access + admin visibility.
- Do not store payment card data anywhere in CuraVault.

---

## 3) Storage / AI limits

**Status:** ☐ PASS ☐ FAIL ☐ PARTIAL  \
**Evidence:**  \
**Blockers:** (P0/P1/P2)  \
**Owner:**  \
**Target fix date:**

### Pass/Fail checks

| Check | Pass criteria | Blocker | Result | Evidence |
|---|---|---:|:---:|---|
| Storage quota enforced | Uploads blocked or degraded past quota; server-authoritative | P0 | ☐ | |
| Document byte tracking | Bytes stored per user are tracked consistently | P0 | ☐ | |
| AI token usage tracked | LLM usage recorded with provider/service separation | P0 | ☐ | |
| Google Document AI/OCR usage tracked | OCR usage tracked as pages/files/time (not tokens) | P0 | ☐ | |
| OpenAI token usage tracked | OpenAI usage tracked via input/output tokens + cost | P0 | ☐ | |
| Limits degrade gracefully | UI shows clear messaging; no crashes/loops when limited | P0 | ☐ | |
| No PHI in telemetry | Usage events contain no raw doc text / health fields | P0 | ☐ | |
| Rate limiting | AI endpoints protected from abuse + runaway costs | P1 | ☐ | |

---

## 4) Documents / OCR / Intake

**Status:** ☐ PASS ☐ FAIL ☐ PARTIAL  \
**Evidence:**  \
**Blockers:** (P0/P1/P2)  \
**Owner:**  \
**Target fix date:**

### Pass/Fail checks

| Check | Pass criteria | Blocker | Result | Evidence |
|---|---|---:|:---:|---|
| Manual upload works | User can upload documents and view them reliably | P0 | ☐ | |
| AI upload works | AI-assisted upload/intake completes end-to-end | P0 | ☐ | |
| OCR status visible | OCR state visible (queued/processing/done/error) | P0 | ☐ | |
| Extracted suggestions visible | Suggestions displayed with source doc reference | P0 | ☐ | |
| Suggestions require approval | No auto-commit without explicit user approval | P0 | ☐ | |
| No auto-create appointments | Appointment suggestions do not create appointments automatically | P0 | ☐ | |
| No auto-create medications | Medication suggestions do not create records automatically | P0 | ☐ | |
| No auto-create contacts | Contact suggestions do not create contacts automatically | P0 | ☐ | |
| No auto-create locations | Location suggestions do not create locations automatically | P0 | ☐ | |
| Error recovery | Failed OCR/intake can be retried safely | P1 | ☐ | |

---

## 5) Privacy / Security

**Status:** ☐ PASS ☐ FAIL ☐ PARTIAL  \
**Evidence:**  \
**Blockers:** (P0/P1/P2)  \
**Owner:**  \
**Target fix date:**

### Pass/Fail checks

| Check | Pass criteria | Blocker | Result | Evidence |
|---|---|---:|:---:|---|
| RLS reviewed | RLS policies reviewed for all user/PHI tables | P0 | ☐ | |
| No service role key in frontend | No service-role key in Flutter/web builds | P0 | ☐ | |
| No raw health data in Control Site | Admin UI never displays raw PHI/health fields | P0 | ☐ | |
| Audit logs safe | Audit logs are redacted + PHI-safe | P0 | ☐ | |
| Support tools gated | Support tooling is RBAC-gated; owner-only where needed | P0 | ☐ | |
| PHI-safe logging | No PHI in client logs, analytics, crash reports, edge logs | P0 | ☐ | |
| Privacy policy live | Public URL reachable; versioned | P0 | ☐ | |
| Terms live | Public URL reachable; versioned | P0 | ☐ | |
| Delete-account page live | Public URL reachable with instructions + flow | P0 | ☐ | |
| Data request page live | DSAR/data export request page live | P1 | ☐ | |
| Key management | Secrets stored in platform vault; rotated plan exists | P1 | ☐ | |
| Incident response | On-call + incident process documented | P2 | ☐ | |

---

## 6) App Store / Google Play

**Status:** ☐ PASS ☐ FAIL ☐ PARTIAL  \
**Evidence:**  \
**Blockers:** (P0/P1/P2)  \
**Owner:**  \
**Target fix date:**

### Pass/Fail checks

| Check | Pass criteria | Blocker | Result | Evidence |
|---|---|---:|:---:|---|
| Package IDs correct | Bundle ID / package name finalized and consistent | P0 | ☐ | |
| Icons/screenshots ready | Store assets meet specs; consistent branding | P0 | ☐ | |
| Permissions explanations | iOS purpose strings + Play permissions rationale complete | P0 | ☐ | |
| Privacy labels / Data safety | Apple Privacy Nutrition + Google Data Safety complete | P0 | ☐ | |
| Subscriptions approved | IAP/subscription products approved and testable | P0 | ☐ | |
| RevenueCat connected | RC project connected to App Store + Play products | P0 | ☐ | |
| Test users/licenses configured | Sandbox testers + license testers configured | P0 | ☐ | |
| Env separation understood | Clear sandbox vs prod behavior; no mixed keys | P0 | ☐ | |
| Review notes | Reviewer instructions for paywall/login prepared | P1 | ☐ | |
| Versioning | Build numbers, release tracks, phased rollout planned | P1 | ☐ | |

---

## 7) Control Site / Admin Console

**Status:** ☐ PASS ☐ FAIL ☐ PARTIAL  \
**Evidence:**  \
**Blockers:** (P0/P1/P2)  \
**Owner:**  \
**Target fix date:**

### Pass/Fail checks

| Check | Pass criteria | Blocker | Result | Evidence |
|---|---|---:|:---:|---|
| Login works | Admin login works reliably; session persists | P0 | ☐ | |
| Dashboard live | Dashboard shows live/empty/partial truthfully | P0 | ☐ | |
| Users live | Users list + detail loads; RBAC enforced | P0 | ☐ | |
| Usage analytics honest | Usage shows live/empty with explicit status | P0 | ☐ | |
| AI usage provider/service | AI Usage distinguishes providers/services (OCR vs LLM) | P0 | ☐ | |
| Billing shows RC status | Billing clearly marks RC-backed vs not-instrumented | P0 | ☐ | |
| Production readiness green | Owner-only readiness page indicates live connectivity | P0 | ☐ | |
| No mock data in production | Production builds never show mock fallback as “live” | P0 | ☐ | |
| No overflow warnings | No RenderFlex overflow/yellow-black stripes in prod flows | P1 | ☐ | |
| Website/CMS status (if needed) | `/website/status` accurately reports table + UI connection | P2 | ☐ | |

---

## 8) Launch decision

### Section-level decision table (required)

| Section | Status (PASS/FAIL/PARTIAL) | Evidence | Blocker level (P0/P1/P2) | Owner | Target fix date |
|---|---|---|---|---|---|
| 1) Auth/account |  |  |  |  |  |
| 2) Billing/RevenueCat |  |  |  |  |  |
| 3) Storage/AI limits |  |  |  |  |  |
| 4) Documents/OCR/intake |  |  |  |  |  |
| 5) Privacy/security |  |  |  |  |  |
| 6) App Store / Google Play |  |  |  |  |  |
| 7) Control Site |  |  |  |  |  |

### P0 blocker rollup (required)

- **List every P0 FAIL/PARTIAL item here** with an owner + target fix date.

| P0 item | Current status | Owner | Target fix date | Evidence/notes |
|---|---|---|---|---|
|  |  |  |  |  |

### Final decision

- ☐ **NO-GO** (any P0 not PASS)
- ☐ **GO** (all P0 PASS; residual P1/P2 explicitly accepted)

**Approvers / Sign-off**

| Role | Name | Date | Notes |
|---|---|---|---|
| Product owner |  |  |  |
| Engineering lead |  |  |  |
| Security/privacy |  |  |  |
| Operations/support |  |  |  |

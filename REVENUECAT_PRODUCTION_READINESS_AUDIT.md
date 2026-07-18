# RevenueCat Production Readiness Audit (CuraVault Control Site)

Date: 2026-07-18  
Scope: **Current Flutter repo (Control Site / Admin console)** + **connected Supabase schema (metadata-only)**

## Executive conclusion

1) **No RevenueCat SDK integration exists in this repo** (no `purchases_flutter`, no `Purchases.*`, no offerings/purchase/restore code).

2) The connected Supabase project **does not contain RevenueCat-specific tables** (e.g. `revenuecat_events`, `revenuecat_webhook_events`) and **does not contain store-transaction ledger tables** (e.g. `app_store_transactions`, `play_billing_transactions`).

3) Billing in this system currently appears to be driven by **generic** tables:
   - `public.user_entitlements` (source of truth for plan/limits flags)
   - `public.subscription_events` (optional lifecycle/event log; currently empty)

4) This repo is an **admin/control-site app**, not the consumer mobile app. Therefore:

> **RevenueCat cannot be verified from this Control Site repo alone.**

To verify RevenueCat readiness for paid consumer launch, we must inspect the **consumer mobile app repo** (Flutter iOS/Android app) and the **backend webhook ingestion** (Supabase Edge Functions and/or separate backend) that updates `user_entitlements` from RevenueCat.

---

## 1) Repo search: RevenueCat integration

Search terms requested:

- `revenuecat`, `RevenueCat`
- `purchases_flutter`
- `Purchases.configure`, `Purchases.logIn`
- `getCustomerInfo`, `Offerings`, `EntitlementInfo`, `CustomerInfo`
- `restorePurchases`
- `appUserID`
- `webhook`
- `subscription_events`
- `user_entitlements`

### Results (Flutter repo)

**RevenueCat SDK / client purchase flow:**
- ✅/❌ `purchases_flutter`: **NOT FOUND**
- ✅/❌ `RevenueCat` / `revenuecat`: **NOT FOUND**
- ✅/❌ `Purchases.configure`: **NOT FOUND**
- ✅/❌ `Purchases.logIn`: **NOT FOUND**
- ✅/❌ `Offerings`: **NOT FOUND**
- ✅/❌ `CustomerInfo` / `EntitlementInfo`: **NOT FOUND**
- ✅/❌ `restorePurchases`: **NOT FOUND**
- ✅/❌ `appUserID`: **NOT FOUND**

**Webhook handlers (repo-side):**
- Keyword `webhook`: **only appears in documentation text** (not an implementation).

**Generic billing tables referenced:**
- `subscription_events`: referenced by **Supabase migrations and docs** (admin-safe reporting functions), not by any RevenueCat code.
- `user_entitlements`: referenced by **Supabase migrations and docs** (admin-safe reporting functions), not by any RevenueCat code.

### Dependency confirmation (pubspec)

`pubspec.yaml` does **not** include RevenueCat packages (`purchases_flutter`).

---

## 2) Is this repo only the Control Site/admin console?

Based on `lib/main.dart`, `lib/nav.dart`, and the page set (Dashboard/Users/Support/Billing/AI Usage/etc), this application is the **CuraVault Admin/Control Site**.

There are no consumer-facing screens, no store purchase flows, and no mobile IAP/RevenueCat SDK code.

**Therefore:**

> **RevenueCat cannot be verified from this Control Site repo alone.**

---

## 3) Supabase schema inspection (billing + RevenueCat related)

Method: metadata-only query against `information_schema.columns`, `pg_indexes`, `pg_policies`, and `pg_class.relrowsecurity`.

### Table: `public.user_entitlements`

- Exists: **YES**
- Row count: **7**
- RLS enabled: **YES**
- Indexes (2):
  - `user_entitlements_pkey` (unique, `user_id`)
  - `user_entitlements_updated_at_idx` (`updated_at`)
- Policies (4):
  - `user_entitlements_select_own` (SELECT, `user_id = auth.uid()`)
  - `user_entitlements_update_own` (UPDATE, own row)
  - `user_entitlements_insert_own` (INSERT, own row)
  - `user_entitlements_insert_free_defaults` (INSERT w/ strict defaults enforced)

Columns (high-level):
- Identity/time: `user_id (PK)`, `created_at`, `updated_at`
- Plan/status: `plan`, `plan_key`, `status`, `subscription_status`, `source_platform`, `billing_period`, `expires_at`, `current_period_end`
- Feature/limits: `ai_enabled/ai_access`, `export_enabled/export_access`, `ocr_enabled/ocr_access`, `max_storage_mb`, `max_family_members`, `mass_upload_enabled`
- Caps/overrides: `ai_monthly_cap`, `ocr_monthly_cap`, plus various `*_override` and override audit fields

**Observation:** `source_platform` exists and currently defaults to `'internal'`. This is the natural place to mark `revenuecat` vs `stripe` vs `internal` etc, but **no RevenueCat ingestion exists yet**.

### Table: `public.subscription_events`

- Exists: **YES**
- Row count: **0**
- RLS enabled: **YES**
- Indexes (2):
  - `subscription_events_pkey` (unique, `id`)
  - `subscription_events_user_id_created_at_idx` (`user_id, created_at desc`)
- Policies (1):
  - `subscription_events_select_own` (SELECT, `user_id = auth.uid()`)

Columns (high-level):
- `id`, `user_id`, `event_key`, `provider` (defaults to `unknown`), `payload jsonb`, `created_at`

**Observation:** This table can store RevenueCat lifecycle/webhook events safely, but it is currently empty and does not appear to be fed by an ingestion pipeline.

### Missing tables (RevenueCat / store ledgers / billing catalog)

These were checked and are **NOT present**:

- `public.revenuecat_events` → **MISSING**
- `public.revenuecat_webhook_events` → **MISSING**
- `public.app_store_transactions` → **MISSING**
- `public.play_billing_transactions` → **MISSING**
- `public.billing_customers` → **MISSING**
- `public.billing_products` → **MISSING**
- `public.billing_entitlements` → **MISSING**

---

## 4) Edge Functions: RevenueCat webhook handlers

### Repo-side edge functions present

The repo includes only one edge function directory:

- `lib/supabase/functions/bootstrap_admin_auth_user/index.ts`

This function bootstraps the initial admin user using a server-side secret and **does not** implement any billing or webhook logic.

### Connected Supabase edge functions

Attempted to list edge functions from the connected Supabase project, but the tool call repeatedly timed out in this environment. Because of that:

- I **cannot** conclusively confirm whether the connected project has additional deployed edge functions for RevenueCat webhooks.
- However, based on **(a)** the repo not containing such functions, and **(b)** the schema lacking any RevenueCat webhook event tables, it is **very likely** that RevenueCat webhook ingestion is not yet implemented.

What we still need to check (once the tool responds or via Supabase dashboard/CLI):
- Any function named like `revenuecat_webhook`, `revenuecat`, `webhook_*`.
- Handlers that validate signature/authorization headers.
- Idempotency handling (event IDs / `event.created_at` + unique constraints).

---

## 5) Required readiness checklist (what must exist before paid consumer launch)

### A) Client (mobile app) RevenueCat SDK

Not verifiable in this repo.

Required items to confirm in the **consumer mobile app repo**:

- `Purchases.configure(...)` is called at startup.
- iOS RevenueCat **public SDK key** configured.
- Android RevenueCat **public SDK key** configured.
- `appUserID` strategy:
  - Preferred: **set RevenueCat app user id = Supabase `auth.uid()`** (or a stable deterministic mapping).
  - Confirm behavior for anonymous users / pre-auth.
- Offering retrieval:
  - `Offerings` fetched and shown.
- Purchase flow:
  - purchase package/product
  - error handling and cancellation cases
- Restore purchases:
  - `restorePurchases`
- CustomerInfo mapping:
  - `getCustomerInfo()` read
  - entitlements mapped to app feature gates

### B) Backend: webhook ingestion + entitlements source-of-truth

Currently missing (based on schema + repo).

What must be built:

1) **RevenueCat webhook endpoint** (Supabase Edge Function or other backend)
   - Validates webhook authorization/signature
   - Parses event types (initial purchase, renewal, cancellation, billing issues, etc.)

2) **Idempotent processing**
   - Store processed webhook event IDs with a unique constraint, or use `subscription_events` with a unique key strategy.
   - Ensure retries from RevenueCat don’t double-apply state.

3) **Write model**
   - Update `public.user_entitlements` based on RevenueCat entitlements
   - Append lifecycle entries to `public.subscription_events` (provider=`revenuecat`, `event_key`, minimal safe `payload`)

4) **RLS-safe design**
   - Webhook handler must use **server-side credentials** (edge function env) and never expose service role keys to frontend.
   - Do not weaken RLS.

### C) Admin/control-site reporting

Current state:
- `BillingPage` exists and is designed to report subscriptions/trials/failures/revenue, but it is powered by admin-safe aggregates that currently appear to be based on `user_entitlements` + `subscription_events`.

Needed for RevenueCat-backed correctness:
- `user_entitlements.source_platform` and `subscription_events.provider` should reflect RevenueCat.
- `subscription_events` must actually be populated by webhook ingestion.

---

## 6) Launch blockers (based on this audit)

**Blocker 1 — No client SDK integration in this repo**
- This repo cannot execute purchases.

**Blocker 2 — No RevenueCat webhook ingestion confirmed**
- Missing RevenueCat event tables and no webhook handler found in repo.
- `subscription_events` is empty.

**Blocker 3 — No verifiable link between RevenueCat appUserID and Supabase users**
- Must be verified in the consumer app repo.

**Blocker 4 — Billing dashboard likely not RevenueCat-backed yet**
- Without ingestion, admin billing metrics will be partial/empty.

---

## 7) What to inspect next (exact repos/files)

Because this is a Control Site repo, the next required audit targets are:

1) **Consumer mobile app repo (Flutter iOS/Android)**
   - `pubspec.yaml`: look for `purchases_flutter`
   - App bootstrap / DI file(s): search for `Purchases.configure`
   - Auth bridge: where user logs in (`Purchases.logIn`) and logs out (`Purchases.logOut`)
   - Paywall UI: where `Offerings` are fetched and rendered
   - Restore: where `restorePurchases` is called
   - Entitlement gating: where `CustomerInfo.entitlements` is mapped to local feature flags and/or written to backend

2) **Supabase Edge Functions (deployed project)**
   - Any function named `*revenuecat*` or `*webhook*`
   - Signature verification logic
   - Idempotency store
   - Updates to `user_entitlements` and `subscription_events`

If you tell me:
- the **consumer app repo name/path**, and/or
- whether RevenueCat webhooks are intended to be processed in **Supabase Edge Functions** vs another backend,

I can produce the same level of audit for those components next.

# RevenueCat Consumer App Purchase Readiness Audit (CuraVault)

Date: 2026-07-18

## Scope + critical note

You asked for an audit of the **main consumer Flutter mobile app repo** (iOS/Android) to confirm it can:

- Sell subscriptions
- Restore purchases
- Unlock access based on entitlements
- Interoperate correctly with **Supabase auth** and **Supabase entitlement sync**

**However:** the currently-open Dreamflow workspace appears to be the **Control Site/admin console repo**, not the consumer app.

### Evidence (this workspace)

Repo-wide keyword scan found **no** consumer RevenueCat SDK integration:

- `purchases_flutter` in `pubspec.yaml`: **NOT FOUND**
- `Purchases.configure`, `Purchases.logIn`, `purchasePackage`, `restorePurchases`, `CustomerInfo`: **NOT FOUND**

Files present here are admin/control-site oriented (e.g. `lib/admin/pages/...`, admin billing/usage pages).

This means we **cannot honestly verify** consumer in-app purchase readiness from this repo alone.

### What *is* present (backend/admin side)

This repo *does* contain:

- A Supabase migration that adds RevenueCat entitlement-sync support (non-destructive):
  - `supabase/migrations/20260718_revenuecat_entitlement_sync.sql`
- A Supabase Edge Function webhook receiver (deploy path present):
  - `supabase/functions/revenuecat_webhook/index.ts`
- Control Site verifiability surfaces (privacy-safe aggregates):
  - `lib/admin/pages/billing_page.dart` (RevenueCat sync health card)
  - `lib/admin/pages/production_readiness_page.dart` (RevenueCat checks)

Those are necessary for **server-side truth**, but they do not prove the **mobile app can sell/restore/unlock**.

---

## Pass/Fail table (consumer mobile app)

Legend: ✅ Pass, ❌ Fail, ⚠️ Partial, ❓ Unknown (repo not available)

> Because the consumer app repo is not loaded here, all consumer-app items are **❓ Unknown** by evidence, and should be treated as **P0 blockers** for paid launch until verified.

| Area | Check | Status | Evidence / exact code path (expected) | Notes |
|---|---|---:|---|---|
| 1. SDK/package | `purchases_flutter` installed | ❓ | `pubspec.yaml` in consumer repo | Not verifiable in this workspace |
| 1. SDK/package | iOS public SDK key configured | ❓ | `Purchases.configure(PurchasesConfiguration(iosKey))` | Must be **public SDK key**, not secret |
| 1. SDK/package | Android public SDK key configured | ❓ | `PurchasesConfiguration(androidKey)` | Same requirement |
| 1. SDK/package | No secret keys in client | ❓ | Search consumer repo for `secret`, `service_role`, RC secret keys | Client must never ship secrets |
| 2. Identity | RevenueCat `appUserID` = Supabase `auth.uid()` | ❓ | `Purchases.logIn(supabaseUser.id)` | Avoid anonymous attribution |
| 2. Identity | RC identify occurs after Supabase login | ❓ | Auth success handler / session restore flow | Must handle session refresh |
| 2. Identity | RC logout/reset on app logout | ❓ | `Purchases.logOut()` | Prevent cross-account leakage |
| 3. Offerings/paywall | Offerings load reliably | ❓ | `Purchases.getOfferings()` | Retry/backoff + UX errors |
| 3. Offerings/paywall | Empty offerings handled safely | ❓ | Paywall UI shows “not available” + support CTA | Sandbox misconfig common |
| 3. Offerings/paywall | Prices/packages display correctly | ❓ | `Package.storeProduct.priceString` | Ensure localization |
| 4. Purchase flow | iOS sandbox purchase works | ❓ | Integration test evidence + code path | Requires App Store product setup |
| 4. Purchase flow | Android license testing works | ❓ | Integration test evidence + code path | Requires Play Console setup |
| 4. Purchase flow | Purchase reads `CustomerInfo` | ❓ | `final info = await Purchases.purchasePackage(...)` | Must use returned info or refresh |
| 4. Purchase flow | Active entitlement unlocks access | ❓ | Entitlement gate: `info.entitlements.active.containsKey(...)` | Must be strict |
| 4. Purchase flow | Cancel/fail does not unlock | ❓ | Error handling for `PurchasesErrorCode.purchaseCancelledError` etc | Must not optimistically unlock |
| 5. Restore flow | Restore action exists | ❓ | Settings/Account screen: `Purchases.restorePurchases()` | Required for iOS |
| 5. Restore flow | Restore updates `CustomerInfo` | ❓ | Use restore response + update local state | |
| 5. Restore flow | Restored entitlement unlocks access | ❓ | Same gate path as purchase | |
| 5. Restore flow | Expired/cancelled does not unlock | ❓ | Check entitlement active vs all | |
| 6. Supabase sync | Immediate access uses `CustomerInfo` OR refreshes backend | ❓ | Either local gate or RPC refresh call | Recommended: both |
| 6. Supabase sync | Webhook updates `user_entitlements` (server truth) | ✅* | `supabase/functions/revenuecat_webhook/index.ts` | *Backend side exists here; must confirm deployed |
| 6. Supabase sync | App handles stale entitlement safely | ❓ | Cache with TTL; “last verified” timestamp | Offline needs careful UX |
| 7. Limits | Free limits enforced | ❓ | Storage/AI/profile limit enforcement points | Must not rely solely on UI |
| 7. Limits | Paid limits enforced | ❓ | Same | |
| 7. Limits | Expired users downgraded gracefully | ❓ | Gate checks on app resume + after webhook sync | |
| 7. Limits | Offline handled carefully | ❓ | “Limited offline grace” policy + clear indicators | Avoid granting paid indefinitely |
| 8. Store setup | App Store products exist | ❓ | RevenueCat dashboard + App Store Connect | Needs screenshots |
| 8. Store setup | Play products exist | ❓ | RevenueCat dashboard + Play Console | |
| 8. Store setup | Products attached to RevenueCat | ❓ | RevenueCat Products page | |
| 8. Store setup | Offerings configured + current offering set | ❓ | RevenueCat Offerings page | |
| 8. Store setup | Entitlements configured | ❓ | RevenueCat Entitlements page | |
| 8. Store setup | Product IDs consistent | ❓ | Consumer code constants vs RC product IDs | |
| 8. Store setup | Sandbox/test users ready | ❓ | iOS sandbox testers + Play license testers | |

---

## P0 launch blockers (paid launch)

1) **Consumer app repo not audited / not present in workspace**
   - We cannot confirm `purchases_flutter`, paywall, purchase, restore, or entitlement gating.

2) **No verifiable identity bridge** (consumer)
   - Must prove `Purchases.logIn(supabaseUser.id)` is used and `Purchases.logOut()` on logout.

3) **No verified offerings/products configuration**
   - Most paid launches fail due to “empty offerings” or product ID mismatch.

4) **No verified entitlement gating + limits enforcement in the consumer app**
   - Paid features must be unlocked strictly by active entitlements (not optimistic flags).

---

## What can ship as a free beta (without paid launch)

You can safely ship a **free beta** if:

- The app does not expose paid purchase UI, or the paywall is clearly marked “coming soon”.
- Access control does not rely on RevenueCat yet.
- You keep the backend webhook + entitlement tables in place (they can run idle).

What you should *not* claim in a free beta:

- “Subscriptions available”
- “Restore purchases supported”
- “Paid tier unlocking implemented”

---

## What blocks paid launch

- Any unknowns in sections **1–5** (SDK + identity + offerings + purchase + restore).
- Lack of strict entitlement gating and downgrade logic.
- Missing store configuration evidence (product IDs, offerings, entitlements).

---

## Exact next step to complete this audit

To complete the audit honestly, I need the **consumer mobile Flutter repo** loaded into Dreamflow (or provided as a separate workspace/path). Once available, I will:

1. Re-run the keyword scans you listed against that repo.
2. Inspect `pubspec.yaml`, app bootstrap, auth flows, and paywall/purchase/restore screens.
3. Verify entitlement gating and limits enforcement points.
4. Produce a second section in this same file with **exact file paths + code excerpts** for all PASS/FAIL calls.

If you tell me how to access the consumer repo (e.g., open a new Dreamflow project/workspace, or share the path if it exists in this environment), I’ll finish the audit immediately.

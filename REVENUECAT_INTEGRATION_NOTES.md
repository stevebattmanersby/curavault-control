# RevenueCat entitlement sync layer (CuraVault)

This repo is the **Control Site (admin)**. It now contains:

- Supabase migration to add RevenueCat webhook event storage + entitlement sync fields
- A Supabase Edge Function `revenuecat_webhook` to receive RevenueCat webhooks and upsert `user_entitlements`
- Control Site UI surfaces (Billing + Production Readiness) that show **aggregate-only** RevenueCat sync health

The **consumer app** still needs the RevenueCat SDK integration (see below).

## 1) Supabase setup (required)

### A) Apply migration

Migration added:

- `supabase/migrations/20260718_revenuecat_entitlement_sync.sql`

This is **idempotent** and does **not** drop or overwrite existing data.

### B) Deploy Edge Function

Edge function added:

- `supabase/functions/revenuecat_webhook/index.ts`

Set secret (Supabase Functions secrets):

- `REVENUECAT_WEBHOOK_SECRET`

Notes:

- `GET /functions/v1/revenuecat_webhook` returns a privacy-safe `{ ok: true }` payload for deployment probing.
- `POST` requires `Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>`.

## 2) RevenueCat dashboard configuration (required)

Before launch, verify in RevenueCat:

1. Products exist in **App Store Connect** and **Google Play Console**
2. Products are added to RevenueCat with consistent product IDs
3. Offerings are configured and set as **Current Offering**
4. Entitlements are configured and mapped to the right products
5. Trials/free/paid plans are mapped correctly (period type is used in webhook processing)
6. Webhook configured to point to your Supabase Edge Function:
   - `https://<PROJECT_REF>.supabase.co/functions/v1/revenuecat_webhook`
   - Authorization header set to the shared secret above

## 3) Consumer app SDK integration (still needed)

This Control Site repo does **not** include the consumer app code.

In the consumer app Flutter repo you should:

### A) Add dependency

```yaml
dependencies:
  purchases_flutter: ^6.30.1
```

### B) Configure on startup

- Initialize RevenueCat with platform public SDK keys
- After Supabase login, identify using `Supabase.instance.client.auth.currentUser!.id`

Pseudocode:

```dart
await Purchases.configure(PurchasesConfiguration(rcPublicKey)
  ..appUserID = supabaseUserId);

await Purchases.logIn(supabaseUserId);
final info = await Purchases.getCustomerInfo();
```

On logout:

```dart
await Purchases.logOut();
```

### C) Required flows

- Fetch offerings: `Purchases.getOfferings()`
- Show packages/prices
- Purchase: `Purchases.purchasePackage(package)`
- Restore: `Purchases.restorePurchases()`
- Read entitlements: `customerInfo.entitlements.active`
- Map entitlement IDs to app features locally
- Cache last-known `CustomerInfo` for offline support
- Expose “Manage subscription” URL when available (platform-specific)

## 4) Sandbox test checklist

### iOS (sandbox)

- Purchase subscription
- Restore purchases
- Cancel subscription
- Let subscription expire / renew

### Android (license tester)

- Test purchase
- Restore purchases
- Cancel

### Webhook + sync

- Webhook test event arrives
- Duplicate webhook event id is idempotent (second call returns `duplicate: true`)
- App user id mismatch produces `warning:unmapped_app_user_id` and does **not** break processing
- Entitlement expires/renews updates `user_entitlements`

## 5) Remaining blockers

- Consumer app repo must implement RevenueCat SDK purchase flows + entitlement gating.
- (Optional) Add admin-safe rollups for RevenueCat billing analytics (MRR/ARR) if you want non-zero revenue charts.

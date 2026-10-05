# DEV-AUTOMATION-03 — Control client contract reconciliation

Control main: `9910331bbcb59361a492b49c56ac46b5f86f3ad8`.
App main: `2b4e7a02d90034364957908b69f2e1f085794648`.
Integration baseline: approved harness `49d999bb00fb715f621b27c556b1a35e8ec42c60`.
Separate branch `codex/dev-automation-03-contracts`; PR #10 remains draft and
unchanged. This PR is stacked on its approved harness branch, so its diff contains
only remediation. No merge, deployment, infrastructure or live-CI activation.

Risk: HIGH cross-repository/read-only billing reporting and disposable validation.
The explicit task authorizes client reconciliation and synthetic fixture lifecycle.
No billing authority, Auth/AAL/RBAC/RLS/grants, schema, production or app source
changes. Human architecture/security acceptance remains a separate gate.

## Authoritative inventory and corrections

Metadata inspected on production and disposable, without reading customer rows.
App source compared at current main. Runtime callers are Control AdminStore
bootstrap, repository diagnostics, summary queries and UsageEventService.

| Call / source | Reality and boundary | Correction |
| --- | --- | --- |
| UsageEventService `_writeEventImpl`, usage_events INSERT | `event_key`, `event_type`, user/owner UUIDs, success/failure_code, properties; INSERT requires writable own account | Canonical keys; authenticated account owns both UUIDs; platform/version/duration in sanitized properties; retain best-effort behavior |
| Queries `_tryGetRevenueCatSyncHealth`, repository `_probeBillingDataSources`, user_entitlements | No provider/store columns; SELECT exposes own account only; app access resolver uses billing_source and effective fields | Remove obsolete global raw scans. Global RevenueCat entitlement/store detail is NOT INSTRUMENTED, with nullable counts, never a false zero. Preserve existing admin_get_billing_summary aggregate; no billing-authority reinterpretation |
| Repository subscription_events count | Authenticated SELECT intentionally unavailable; existing AAL2 admin billing summary aggregates events server-side | Remove browser detail query, show NOT INSTRUMENTED; no grant or new RPC |
| Queries AI/storage V2 | No deployed V2 contract on either target; V1 exists and succeeds | Request supported V1 directly, preserve source name and AI partial-capability note; remove obsolete V2 parser/probe |
| Repository stripe_webhook_events | Absent on both; defensive future instrumentation probe (D future capability), not a typo for restricted subscription_events | Explicit unavailable diagnostic with null count; no REST probe/table fabrication |
| Repository asset_library_backend | Explicit future/unprovisioned CMS feature (D), no executable current backend | Keep future asset status/page, null count and missing-table status; omit REST probe |

Existing legacy billing summary semantics are not upgraded to canonical billing
authority by this task. Effective entitlement/source resolver, revenue authority
and new provider/store aggregates would require separate architecture work.
No data from account-scoped reads is presented as a global population.

The associated `revenuecat_sync_health_v1` view is also absent on both targets.
Its stale fallback query is removed; sync health stays unavailable, while existing
authorized webhook row diagnostics remain. Regression uses a nonempty billing
aggregate to cover the path hidden by empty synthetic billing populations.

Telemetry has no medical document/profile association; it describes the signed-in
Control account only. Existing property sanitization/PHI rejection is preserved.
RevenueCat webhook metadata remains under existing admin SELECT policy.

## Transport diagnosis and evidence

DEV-AUTOMATION-02 saved only `local-resource`, so its precise original URL/type
cannot be recovered from that artifact. New diagnostics preserve only an allowlisted
loopback pathname, request type, bounded error-code enum and test phase; no query,
headers, bodies, tokens, TOTP or arbitrary error strings. Every transport failure
remains unexpected and blocks PASS; no blanket ignore or automatic scenario retry.
Current exact-head artifacts record any reproduction and clean repeat results.

## Validation and rollback

Before edits: analyzer zero issues, 69 Flutter tests, 16 Node harness tests and
release build PASS. Regression coverage exercises real Supabase request builders
through an offline HTTP transport, checks V1 parsed/source values, prohibits raw
entitlement/subscription/Stripe/asset calls and verifies canonical telemetry shape.
No app/backend source affected; no database migration or Deno behavior changed.
Final evidence lives under ignored `build/control-e2e`, with exact head and target,
three independent fixture runs and cleanup proof. Live CI stays disabled.

Rollback: revert this remediation commit; approved harness remains. No database,
billing state or production rollback is needed. Any future deployment needs separate
approval and must retain unavailable-state semantics and authorization boundaries.

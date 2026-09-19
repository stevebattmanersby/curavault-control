# CuraVault Control Change Risk and Validation Matrix

Use this matrix before implementing, reviewing, merging, or releasing Control repository changes.

## Risk levels

### LOW

Examples:

- copy changes
- non-sensitive layout polish
- visual presentation that does not alter shared state, authorization, routing, data access, production configuration, or release behavior

Minimum validation:

- focused affected test or static check
- formatting for changed files
- `git diff --check`

### MEDIUM

Examples:

- dashboards
- read-only reporting
- navigation
- shared UI state
- admin-facing presentation of already-authorized data
- documentation/tooling that may affect future engineering workflow

Minimum validation:

- LOW validation
- focused widget/unit tests for changed behavior
- relevant existing tests
- analyzer regression when Dart code changes
- route/state regression checks when navigation is affected

### HIGH

Examples:

- Auth, MFA, AAL, RBAC
- RLS, RPCs, grants, policies
- migrations
- audit logging or audit authorization
- support sessions
- billing or plan/entitlement changes
- compliance/privacy workflows
- account mutation
- production Control reporting that claims authoritative live state
- admin mutations or buttons that require backend execution
- cross-repository contracts with `curavult-app` production state
- production actions
- trusted worker, Codex provider, release/deployment path
- service-role or backend identity semantics

Minimum validation:

- MEDIUM validation
- security-specific tests
- disposable runtime proof when database/backend authorization is involved
- adversarial review
- exact-head CI
- explicit human authorization for merge/release/production actions

## Production-equivalent disposable runtime rule

Static SQL or Dart inspection alone is insufficient for any change involving:

- `auth.uid()`
- `auth.jwt()`
- AAL
- RBAC
- RLS
- `service_role`
- audit authorization
- RPC authorization
- `SECURITY INVOKER` or `SECURITY DEFINER`
- grants or policies
- support-session mutations
- billing or compliance mutations

The proof must model realistic Supabase/PostgREST claim semantics, including authenticated and anonymous roles, AAL claims, active and inactive admins, ordinary users, malformed or missing claims, and the relevant positive and negative role cases.

## Required review dimensions

Every non-trivial change must state how it affects:

- entry points
- authorization
- state transitions
- legacy state
- concurrency
- interruption/retry behavior
- idempotency
- auditability
- deployment dependencies
- rollback/recovery
- human validation

Production Control features must additionally prove operational truth:

- production data source exists
- schema matches the client contract
- displayed values have documented source and semantics
- visible filters alter authoritative backend predicates
- server authorization matches UI authorization
- mutations have executable production RPC or Edge Function contracts
- mutation outcomes are auditable and create the intended downstream state
- missing instrumentation displays `NOT INSTRUMENTED`, `UNKNOWN`, or `ERROR`
- synthetic/sample/dev data is not created in production for demonstration, audit, UI, or test purposes

When Control reads or manages consumer-app state, review must compare current `curavult-app` main, production Supabase schema/functions, and the current Control implementation. Legacy compatibility fields are not authoritative when canonical/effective fields or resolvers exist.

## Validation tier mapping

- LOW normally uses Tier 1.
- MEDIUM normally uses Tier 1 plus the relevant Tier 2 checks before PR review.
- HIGH requires Tier 2 and a planned Tier 3 release gate before production impact.

Tier definitions live in [VALIDATION_TIERS.md](VALIDATION_TIERS.md).

## Release and rollback expectations

Any release-affecting change must name:

- the exact commit or PR head validated
- whether migrations are pending
- whether deploy configuration changes are pending
- the rollback target or recovery path
- what read-only verification proves after production action

Do not call a release ready when rollback is unknown.

# CuraVault Control Adversarial Review Contract

Independent review for Control changes must attempt to break the system, not merely confirm the happy path.

## Required verdicts

- `PASS TO MERGE`: evidence supports merge, no blocking defects remain, and production action remains separately gated.
- `WAIT`: evidence is incomplete, CI/runtime proof is pending, or a human/external gate is unresolved.
- `FAIL`: a defect weakens authorization, privacy, audit integrity, release safety, production safety, or validated behavior.

## Attack checklist

Reviewers must actively test or reason about:

- AAL bypass
- role escalation
- inactive-admin access
- ordinary-user access
- anonymous access
- `support` privilege leakage
- `read_only` privilege leakage
- billing privilege leakage
- compliance privilege leakage
- audit forgery
- audit omission
- ownership bypass
- `service_role` exposure
- malformed or missing claims
- stale auth/session state
- stale release or validation evidence
- concurrent admin actions
- duplicate dispatch, retry, or idempotency failure
- privacy leakage
- raw PHI/customer/secrets exposure
- fabricated production metrics or sample-data substitution
- missing instrumentation presented as healthy, zero, successful, or empty
- visible filters that do not alter the authoritative backend query
- placeholder or mock-only admin mutations
- legacy compatibility fields used instead of canonical/effective fields
- production-action safety
- migration ordering
- rollback and recovery

## Evidence standards

For HIGH changes, independent review should include disposable runtime evidence wherever authorization is affected. Repository tests are necessary but not sufficient when database authorization, Supabase claims, RLS, grants, or RPC behavior is in scope.

For production Control reporting or administrative actions, review must prove operational truth, not merely UI rendering. The reviewer should verify the production data source, client/server schema match, metric semantics, backend predicates for visible filters, server-side authorization, audit behavior, downstream state changes, and honest unavailable states.

## Review boundaries

The reviewer must not merge, deploy, apply production migrations, mutate production, or change the reviewed branch unless explicitly asked to implement corrections. A review that finds a blocker should leave the PR open and mark the verdict `FAIL` or `WAIT`.

## Required output

An adversarial review should report:

- exact PR/head SHA reviewed
- test and runtime evidence
- authorization matrix covered
- defects found
- residual risks
- merge recommendation
- production-action recommendation, if any, as a separate gate

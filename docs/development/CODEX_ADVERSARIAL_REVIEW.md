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
- production-action safety
- migration ordering
- rollback and recovery

## Evidence standards

For HIGH changes, independent review should include disposable runtime evidence wherever authorization is affected. Repository tests are necessary but not sufficient when database authorization, Supabase claims, RLS, grants, or RPC behavior is in scope.

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

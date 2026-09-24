# CuraVault Control Validation Tiers

Validation tiers are cumulative, but higher tiers are not invoked automatically. Tier 3 is a release gate and requires explicit human authorization.

## Tier 1 - Development

Purpose: fast feedback while implementing.

Typical checks:

- focused affected tests
- static contract tests for docs/tooling changes
- changed-file formatting
- `git diff --check`

Tier 1 does not authorize merge or production action.

## Tier 2 - PR Gate

Purpose: prove a PR is reviewable.

Typical checks:

- Tier 1 checks
- relevant focused tests
- full deterministic repository tests where practical
- security tests for auth/RBAC/audit/support/billing/compliance scope
- analyzer regression gate
- release web build when Flutter UI/build surfaces changed
- disposable runtime proof when risk requires it
- secret scan
- clean git status review

Tier 2 supports PR review. It does not authorize production deployment, migrations, or merge unless the user separately grants merge authorization.

## Tier 3 - Release

Purpose: prove a specific exact head is ready for production action.

Typical checks:

- exact-head CI
- full relevant suite once
- full Control security suite
- production-equivalent disposable runtime proof for HIGH security/database changes
- migration dry-run when migrations are pending
- release build/preflight
- rollback target
- read-only post-action verification plan

Tier 3 must be explicitly requested. A Tier 1 or Tier 2 command must not silently run Tier 3 or imply production readiness.

## Human and production gate sequence

Use this sequence for production-impacting work:

1. Automated validation
2. Human authorization
3. Production action
4. Read-only verification

Separate authorization is required for:

- source change approval
- merge approval
- migration approval
- deployment approval
- production mutation approval
- store/publication approval

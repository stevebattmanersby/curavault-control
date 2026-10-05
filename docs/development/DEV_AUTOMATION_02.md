# DEV-AUTOMATION-02: disposable Control browser validation

Approved baseline: `main`, `9910331bbcb59361a492b49c56ac46b5f86f3ad8`.
Branch: `codex/dev-automation-02-control-e2e`.
Human authority: the DEV-AUTOMATION-02 task authorizes source preparation,
synthetic fixture lifecycle and validation on retained disposable ref
`evvksortjegefsldamwb`. No merge, deployment, production mutation, billing
change, RLS/grant change, paid infrastructure or VM is authorized.

Risk: **HIGH tooling boundary** (server-only fixture credential, disposable Auth
lifecycle and CI preparation). Runtime authorization is unchanged. Tier 2 source
and disposable validation; human security/architecture acceptance remains a gate.
Read the execution contract, risk matrix, validation tiers and adversarial review.

## Contract inventory (read-only catalog inspection, 2026-10-05)

| Call / observed failure | Disposable and production metadata | Classification | Smallest next action |
| --- | --- | --- | --- |
| `usage_events` INSERT 400 | Canonical columns are `event_key`, `event_type`, `owner_user_id`, `properties`; client sends `event_name`, `feature_area`, etc. | D optional telemetry with underlying A client defect | Separate client mapping review; do not reshape canonical medical usage schema |
| `user_entitlements` GET 400 | Neither target has `provider`/`store`; Control filters `provider=revenuecat` | A genuine mismatch / E stale call | Separately approved billing contract remediation; no billing change in this task |
| AI/storage v2 RPC 404 | v2 absent on both; V1 present on both | E unsupported capability probe | Require V1 HTTP 200 and truthful partial/fallback status; separately remove dead probes or design v2 |
| read_only audit INSERT 403 | Policy permits owner/admin/billing/compliance via AAL2 role gate | C expected authorization | Assert denial, preserve policy; optional audit client behavior follow-up |
| Console HTTP resource failures | Browser reports failed HTTP calls above | Same classification as exact network responses | Preserve counts, no blanket ignore |

No B reconstruction omission was established for these calls. The retained branch
still records `MIGRATIONS_FAILED` despite prior explicit reconstruction; this task
does not reset/rebase it or infer production parity from that status.

Additional tested dependencies: Auth token/logout/refresh, MFA enroll/challenge/
verify, active allowlist self lookup, dashboard V1 aggregate, settings route/RBAC,
read_only self role UPDATE denial, fixture-only Auth Admin create/delete, audit
cleanup and absence checks. No real users or medical rows are test inputs.

## Validation and acceptance

Baseline: analyzer zero issues; 67 Flutter tests pass; release web build passes.
Exact-head browser artifacts are generated under ignored `build/control-e2e/runs`.
Known A/D failures remain unexpected and prevent a clean full-suite PASS. Do not
present successful auth/RBAC scenarios as a clean reporting contract proof.
Live CI is disabled; credential-free lifecycle/target guard tests run on PRs.
See [the harness contract](../../tool/e2e/README.md) for lifecycle, local commands,
recovery, activation gates, evidence and rollback.

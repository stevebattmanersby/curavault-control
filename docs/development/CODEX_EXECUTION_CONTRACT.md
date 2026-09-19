# CuraVault Control Codex Execution Contract

This contract governs Codex-assisted work in the CuraVault Control repository. It adapts the CuraVault app development framework to the Control Site, where admin authorization, AAL2, audit integrity, support sessions, billing, compliance, and production evidence are part of the product boundary.

## Non-negotiable repository rules

- Start from an explicitly named commit SHA. Recheck the base SHA immediately before any branch, merge, release, or production action.
- Work on an isolated branch or worktree. Never develop directly on `main`.
- Keep the working tree clean before starting and before handoff. If unrelated changes exist, preserve them and report them.
- Never overwrite, reset, rebase, or commit to another active PR branch unless the user explicitly requests that exact branch.
- Merge authorization is separate from deployment authorization.
- Production migration authorization is separate from source-change, merge, and deployment authorization.
- Production data, infrastructure, Netlify, Supabase, Auth, DNS, Stripe, GitHub settings, and store/publication changes require explicit production-action authorization.
- Do not print, log, copy, or commit secrets, keys, tokens, PHI, customer data, raw support content, or raw CI logs.
- Browser code must never receive service-role keys, OpenAI/Codex credentials, GitHub write credentials, signing material, deployment credentials, or worker credentials.
- Evidence must be gathered before recommendation. Do not convert assumptions into release facts.
- Rollback or recovery notes are required for release-affecting changes.

## Required start checklist

1. Confirm repository and branch.
2. Confirm expected base SHA and compare it with `origin/main` or the user-approved base.
3. Confirm whether any active PR branch must be protected from modification.
4. Classify risk using [CHANGE_RISK_AND_VALIDATION_MATRIX.md](CHANGE_RISK_AND_VALIDATION_MATRIX.md).
5. Identify protected files and systems.
6. Select the minimum validation tier from [VALIDATION_TIERS.md](VALIDATION_TIERS.md).
7. State whether any human checkpoint, disposable runtime, production dry-run, or release gate is required.

## Control-specific security model

The Control Site has six administrative roles:

- `owner`
- `admin`
- `billing`
- `compliance`
- `support`
- `read_only`

Unknown roles fail closed.

Access is governed by Supabase Auth, `admin_users`, route-level RBAC, database RLS, RPC authorization, and AAL2 step-up where required. UI checks are not sufficient; server/database authorization is authoritative for protected data and mutations.

## AAL1 and AAL2

- AAL1 may identify an authenticated user, but it is not sufficient for protected Control access.
- Active allow-listed admins at AAL1 must be sent through the MFA step-up path.
- AAL2 is required before protected admin routes and protected admin RPC/data paths are considered authorized.
- TOTP enrollment and verification must use Supabase MFA APIs.
- A successful `admin_login` audit entry must be recorded only after AAL2 authorization succeeds.

## Allow-list and denial behavior

- Active `admin_users` rows are required for Control authorization.
- Inactive admins are denied.
- Ordinary authenticated users are denied.
- Anonymous users are denied.
- Missing role, unknown role, malformed claims, stale session state, and unavailable MFA state fail closed.

## Production operational truth

A production Control feature is not implemented or production-ready merely because UI, models, repository methods, or tests exist. Production-readiness evidence must establish:

- the production data source exists;
- the schema matches the client contract;
- the displayed value has documented source and semantics;
- visible filters alter the authoritative backend query;
- server-side authorization matches UI authorization;
- mutations have an existing executable backend contract;
- mutations are auditable and produce the intended downstream state;
- unavailable instrumentation is displayed as `NOT INSTRUMENTED`, `UNKNOWN`, or `ERROR`, never as zero, healthy, successful, or empty.

Synthetic, sample, seed, mock, or development data must never be created in production to satisfy a Control UI, audit, demonstration, or test. Missing instrumentation must fail honestly and must never silently degrade to fabricated, placeholder, hard-coded, or compatibility-only production data.

## Cross-repository contract verification

When Control reads or manages consumer-app state, review must validate the contract against all of:

- current `curavult-app` main;
- current production Supabase schema/functions;
- current Control implementation.

Legacy compatibility fields must not be selected as authoritative where a newer canonical/effective field or resolver exists.

## Administrative action completeness

An admin action is incomplete unless evidence proves all of:

- UI authorization;
- server authorization;
- AAL requirement;
- production RPC or Edge Function exists;
- input validation;
- state transition;
- concurrency/idempotency where relevant;
- audit event;
- error/failure behaviour;
- downstream user effect.

A button wired to a missing, placeholder, mock-only, or non-executable backend contract is a production blocker, not a partial implementation.

## Metric integrity

Every Control metric must define exact source, aggregation, date/window semantics, freshness, and whether it is authoritative, derived, estimated, or unavailable. Every visible filter must be traceable to the backend predicate it changes.

Hard-coded health states, current timestamps, zeros, empty lists, or placeholder values may not be presented as production evidence.

## PHI minimisation

Normal Control operations manage account and service metadata, not clinical record content. Support and admin reporting should prefer counts, states, identifiers, timestamps, error codes, processing status, entitlement metadata, and usage metadata.

Access to raw health content requires a separate explicit architecture, consent model, time-bounded authorization, and audit design.

## Backend and service-role separation

`service_role` and trusted backend/worker identities are server-side boundaries only. They must not be simulated by the browser, embedded in Flutter, exposed through build configuration, or used to bypass user-scoped RLS. Any backend or trusted-worker path must have its own proof, audit trail, and least-privilege contract.

## Role boundaries

- `owner`: highest Control authority. Required for high-risk approvals, production readiness ownership, owner-only settings, critical user/account actions, and final human GO/NO-GO decisions.
- `admin`: operational administration. May manage allowed operational areas but cannot grant owner-only approvals or bypass high-risk gates.
- `billing`: billing and plan/entitlement workflows only. Must not gain development-control, support-session, audit-forgery, or compliance mutation authority through convenience paths.
- `compliance`: privacy/compliance review and evidence access. May inspect audit/compliance evidence and perform approved compliance workflows, but must not gain general operational write power.
- `support`: support triage and support-session workflow only. Must not receive billing, compliance, development-control, audit-write, or privileged release authority unless a dedicated reviewed permission is introduced.
- `read_only`: evidence and reporting visibility only. Must not mutate user, billing, support, compliance, audit, development, release, or production state.

## Audit integrity

- Audit records are append-only administrative metadata.
- Audit entries must not include raw PHI, raw customer content, credentials, prompts, attachment contents, or raw CI logs.
- Browser-originated audit writes require explicit authorization and must not use broad `is_active_admin()` checks where role-specific restriction is required.
- Manual status changes must record actor, previous value, new value, reason, timestamp, and related SHA/build/deployment where applicable.

## Protected files and systems

Treat changes touching the following as at least HIGH unless proven otherwise:

- `supabase/migrations/**`
- `supabase/functions/**`
- `lib/admin/auth/**`
- `lib/admin/data/supabase/**`
- `lib/admin/state/**` when it changes authorization, persistence, or mutations
- `lib/nav.dart`
- `lib/supabase/**`
- `.github/workflows/**`
- `worker/**`
- release/deployment scripts or Netlify configuration
- any file that changes Auth, AAL, RBAC, RLS, RPC, audit, support, billing, compliance, privacy, account mutation, production actions, or trusted-worker behavior

## Human checkpoints

Human authorization is required before:

- merging
- deploying
- applying migrations
- changing production Supabase/Auth/Netlify/DNS/Stripe
- publishing store builds
- enabling live execution providers/workers
- modifying production release gates
- accepting HIGH or CRITICAL work as complete

The standard production sequence is:

`AUTOMATED VALIDATION -> HUMAN AUTHORIZATION -> PRODUCTION ACTION -> READ-ONLY VERIFICATION`

Never infer production authorization from earlier development approval.

## Known baseline handling

Known baseline debt may be documented only when it is reproducible in this repository. It cannot hide a new regression. Analyzer, test, security, or migration drift must compare against the approved base and fail if the change introduces new diagnostics or weakens existing guardrails.

## PR #8 protection

PR #8 (`fix/control-production-site-audit`) owns active Control security/audit/CMS hardening. Framework work must not modify, reset, rebase, or reinterpret that branch. Release Control implementation should begin only after PR #8 is resolved or deliberately rebased against its final merged state.

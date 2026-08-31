# Development Control Plane

## Purpose

The Development Control Plane records CuraVault engineering work as administrative metadata. It is a planning, review, evidence, and release-tracking surface; it is not an agent runner, CI runner, GitHub client, or deployment console.

## Data model

`admin_development_tasks` is the canonical task record and receives a database-generated `CVDEV-######` key. Append-only task events, reusable prompt templates, structured reviews, concise check evidence, and release records reference the task without storing logs, patient content, credentials, or attachment data.

## Permissions and RLS

The existing `admin_users` allow-list remains authoritative. Owner and Admin can read or manage task prompts; only Owner can grant formal approval. Compliance can submit a security review and inspect the evidence-only view: reviews, checks, releases, and event metadata. Read-only can inspect that evidence only. Support and Billing have no Development section access. Every table has RLS, anon has no access, and the browser receives no service-role capability.

## Audit and lifecycle

Database audit triggers write actor, entity, action, and constrained state metadata to `admin_audit_log`; free-text requests and prompts are deliberately excluded. Task status is a workflow record only. `approved` always requires a recorded Owner approval; high/critical work also cannot become `completed` without that approval. Approval attribution is written by the database and becomes immutable.

## Phase 2 mock dispatcher

Phase 2 adds a durable, policy-governed **mock-only** execution ledger. The browser submits a task ID only; PostgreSQL loads the task, hashes the stored execution prompt, evaluates recorded approval/review state, creates an idempotent `CVRUN-######` job, and records policy and lifecycle evidence. A server-managed database configuration row defaults to disabled. Authenticated roles have no read/write policy or direct grant for that switch; a future privileged deployment path must be separately designed and reviewed. Configuration changes are safely audited. No browser control exists.

The only provider and executor mode defined or accepted by the database are `mock`. The deterministic mock processor never invokes Codex/OpenAI, executes shell commands, calls GitHub, accesses a repository, starts CI, stores credentials, merges code, or deploys. The Runs view exposes safe metadata, policy outcomes, and concise lifecycle summaries. It never exposes stored task requests or prompts to Compliance/Read-only roles.

Low-risk tasks may be mock-eligible in `ready`, `awaiting_review`, or `approved`. Medium tasks require `approved` plus Architecture review. High tasks require recorded Owner approval plus Architecture and Security review. Critical work returns `manual_review_required` and is not dispatched. Rejection, retry limit, cancellation, snapshot-change, and controlled mock-failure outcomes are all durable and auditable. Retries are explicit and bounded to three attempts; duplicate active requests return the same job.

## Phase 3 Codex provider architecture

Phase 3 adds a separate, disabled-by-default `codex` provider policy. A real
request is server-derived from a task ID and is pinned to the sole allowed
repository (`stevebattmanersby/curavult-app`) and a trusted base SHA. Mock and
Codex configuration are independent; neither Owner nor Admin has browser/API
table access to enable Codex. Codex jobs retain safe policy, pin, path, and
validation evidence only. High-risk requests additionally require an explicit
Owner-issued Codex authorization bound to the current task snapshot, repository,
base branch, and provider policy version; stale authorizations are rejected.
The private provider configuration contains the audited, allow-listed model ID;
neither browser users nor tasks can select it. Critical requests remain unsupported.

The provider transport is a trusted-worker contract, not a browser or Edge
Function runner. Production enablement requires a separately hosted isolated
workspace worker with provider/repository secrets, egress controls, cleanup,
and monitoring. See [CODEX_PROVIDER_ARCHITECTURE.md](CODEX_PROVIDER_ARCHITECTURE.md).

## Limits

No browser-to-Codex call, GitHub write operation, CI rerun, raw shell endpoint,
webhook runner, deployment, merge, or secret storage exists. GitHub fields are
manually entered references only. Codex remains disabled until the documented
trusted-worker enablement checklist is complete.

## Validation

Pull requests run a read-only changed-Dart format gate, a baseline-aware analyzer regression gate, deterministic Flutter tests, and a disposable PostgreSQL validation of the Development Control migration. Existing analyzer debt is reported but does not fail unrelated work; newly introduced diagnostics fail the gate. The database job uses only synthetic records and is destroyed with the CI job; it does not contact Supabase. Production migration application remains separately authorized.

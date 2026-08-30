# Development Control Plane

## Purpose

The Development Control Plane records CuraVault engineering work as administrative metadata. It is a planning, review, evidence, and release-tracking surface; it is not an agent runner, CI runner, GitHub client, or deployment console.

## Data model

`admin_development_tasks` is the canonical task record and receives a database-generated `CVDEV-######` key. Append-only task events, reusable prompt templates, structured reviews, concise check evidence, and release records reference the task without storing logs, patient content, credentials, or attachment data.

## Permissions and RLS

The existing `admin_users` allow-list remains authoritative. Owner and Admin can read or manage task prompts; only Owner can grant formal approval. Compliance can submit a security review and inspect the evidence-only view: reviews, checks, releases, and event metadata. Read-only can inspect that evidence only. Support and Billing have no Development section access. Every table has RLS, anon has no access, and the browser receives no service-role capability.

## Audit and lifecycle

Database audit triggers write actor, entity, action, and constrained state metadata to `admin_audit_log`; free-text requests and prompts are deliberately excluded. Task status is a workflow record only. `approved` always requires a recorded Owner approval; high/critical work also cannot become `completed` without that approval. Approval attribution is written by the database and becomes immutable.

## Phase 1 limits

No Codex/OpenAI execution, GitHub write operation, CI rerun, shell execution, webhook, deployment, merge, or secret storage exists in this phase. GitHub fields are manually entered references only.

## Validation

Pull requests run a read-only changed-Dart format gate, a baseline-aware analyzer regression gate, deterministic Flutter tests, and a disposable PostgreSQL validation of the Development Control migration. Existing analyzer debt is reported but does not fail unrelated work; newly introduced diagnostics fail the gate. The database job uses only synthetic records and is destroyed with the CI job; it does not contact Supabase. Production migration application remains separately authorized.

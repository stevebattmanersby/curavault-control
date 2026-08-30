# Development Control Plane

## Purpose

The Development Control Plane records CuraVault engineering work as administrative metadata. It is a planning, review, evidence, and release-tracking surface; it is not an agent runner, CI runner, GitHub client, or deployment console.

## Data model

`admin_development_tasks` is the canonical task record and receives a database-generated `CVDEV-######` key. Append-only task events, reusable prompt templates, structured reviews, concise check evidence, and release records reference the task without storing logs, patient content, credentials, or attachment data.

## Permissions and RLS

The existing `admin_users` allow-list remains authoritative. Owner and Admin can read or manage task prompts; only Owner can approve high-risk work. Compliance can submit a security review and inspect review/release evidence. Read-only can inspect that evidence only. Support and Billing have no Development section access. Every table has RLS, anon has no access, and the browser receives no service-role capability.

## Audit and lifecycle

Database audit triggers write actor, entity, action, and constrained state metadata to `admin_audit_log`; free-text requests and prompts are deliberately excluded. Task status is a workflow record only. High and critical risk work cannot self-approve: Owner approval is recorded separately from task status.

## Phase 1 limits

No Codex/OpenAI execution, GitHub write operation, CI rerun, shell execution, webhook, deployment, merge, or secret storage exists in this phase. GitHub fields are manually entered references only.

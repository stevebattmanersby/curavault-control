# Trusted Codex Worker Operations

## Status and host choice

Phase 4 supplies a deployable worker image and a database control-plane; no worker host is deployed and live Codex remains disabled. The production target is a dedicated Kubernetes or VM-grade isolated execution host: a small control worker claims database jobs and creates a separate, short-lived sandbox for each workspace. This is selected over Cloud Run Jobs, ECS/Fargate, Fly.io, Railway, and Render because a simple shared container cannot independently demonstrate no-egress workspace execution, filesystem isolation, or process termination without an additional sandbox boundary.

The host must give the control worker an outbound allow-list for PostgreSQL/Supabase, GitHub read APIs, and OpenAI Responses. The per-job sandbox must have no general egress, no Docker socket, no host home, no SSH mount, no signing/deployment credentials, and a bounded writable filesystem. Until those policies are independently verified, `live_execution_enabled` remains false.

## Identity and secrets

The worker authenticates as the dedicated `LOGIN NOINHERIT` database identity `curavault_codex_worker`. The migration never sets a password: privileged host infrastructure provisions and rotates that external credential. The worker can invoke only the `worker_*_codex_execution` RPCs. It is not an authenticated browser Admin, cannot assume Admin/Owner roles, and has no table write grants. Host secret injection supplies separate worker database, OpenAI, and GitHub read-only credentials. They are never stored in PostgreSQL, Flutter, Docker layers, workspaces, CI, or logs.

Use a GitHub App or fine-grained credential scoped only to `contents:read` on `stevebattmanersby/curavult-app`. No `contents:write`, pull-request, workflow, administration, push, branch, merge, or deployment privilege is allowed. Clone at the server-derived SHA, verify detached `HEAD`, remove/neutralize `origin`, and reject any remote change before accepting evidence.

## Lifecycle and incident response

The database atomically claims `queued` Codex work with `FOR UPDATE SKIP LOCKED`, issues a one-minute hashed lease token, records heartbeat, and accepts only lease-owned state transitions. A crash never authorizes an overlapping run; an expired lease is a failure requiring separately reviewed recovery. The worker enforces a 30-minute maximum and at most one active Codex job. Cancellation stops the sandbox, records bounded evidence, cleans up, then reports cancellation.

Two independent kill switches exist: the private Codex provider row and the private worker live gate. For an incident: disable provider, stop workers, revoke OpenAI and GitHub-read credentials, let leases expire, and retain only safe durable evidence. Do not enable live mode until worker health, monitoring, repository credential, provider credential, workspace isolation, network policy, cleanup, timeout, cancellation, crash recovery, and a synthetic E2E have been independently verified.

## Logs, evidence, and cost

Log only job ID, worker ID, status, duration, safe failure code, repository, and SHA prefix. Never log prompts, raw model output, credentials, full environment, or terminal dumps. Retain bounded path lists, diff hash, validation summaries, cleanup outcome, model ID, and provider reference. Token/cost telemetry may be added only as bounded provider metadata. No automatic retry loop or provider spend escalation is permitted.

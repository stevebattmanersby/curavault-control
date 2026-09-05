# Controlled Codex Provider Architecture

## Status

Phase 4 establishes the Codex worker control-plane boundary. Codex is disabled
by default, no worker host is deployed, and no live provider call is made by
CI or by the Flutter browser client.

## Trust boundary

The browser submits only a Development Task identifier to
`admin_request_codex_development_execution(uuid)`. PostgreSQL loads the stored
task, checks the authenticated Owner/Admin role, derives the repository and
base branch, requires a trusted revision pin, evaluates server-side policy, and
records a durable job. The browser cannot supply a prompt, provider, path
allow-list, base SHA, command, credential, or timeout.

Provider configuration, repository revisions, and per-task high-risk Codex
authorizations are RLS-protected and have no browser table grants. Enabling the
Codex provider requires a separately provisioned privileged deployment/worker
path; normal Owner/Admin users cannot change it. Configuration starts disabled,
is auditable, and is independent of the Phase 2 mock switch. The configuration
also contains an allow-listed model ID and policy version. A model or policy
change is privileged, auditable, and invalidates existing High-risk Owner
authorizations until they are renewed against the current task snapshot.

## Worker and credentials

A dedicated worker identity owns the provider API credential, read-only repository
credential, and database worker credential. None are stored in PostgreSQL,
Flutter, generated assets, the editable workspace, or CI. The worker constructs
a trusted envelope and sends untrusted task content in a distinct delimited
section. `worker/codex_execution_provider.ts` contains the typed transport and
policy contract; the OpenAI transport uses the server-side Responses API only
when the worker injects its own secret at runtime. The worker loads and
validates the model ID from the private provider configuration; no task or
browser request can select a model.

The current Supabase Edge Function environment is not used as a writable
worktree host. It cannot provide the required durable job claim, isolated
filesystem, egress restriction, or secret-free child-process environment. A
production worker must be deployed separately before Codex can be enabled.

## Workspace and network isolation

Each eligible job must receive a fresh, bounded temporary workspace cloned at
the persisted `resolved_base_sha`. The worker must mount no user home directory,
no unrelated repository, no deployment credentials, and no GitHub write token.
It may make only provider API and scoped repository-read connections. Arbitrary
outbound network access from the workspace must be denied by the worker host.
If that isolation cannot be demonstrated, Codex remains disabled.

The worker must inspect the workspace after execution, require the expected
repository and SHA, verify that remotes did not change, capture bounded changed
paths/diff metadata, terminate on cancellation or timeout, and clean the
workspace. Cleanup failure or a policy failure rejects the output.

## Path policy

Phase 3 accepts normal changes only in `lib/**`, `test/**`, and non-sensitive
documentation. It rejects protected changes in migrations, Edge Functions,
Android/iOS configuration, workflow files, billing/entitlement/auth security
areas, and all forbidden secret/credential/environment paths. Future protected
area support requires a separate reviewed policy and stronger authorization.

## Execution policy

* Low: Owner/Admin request only; the stored task must otherwise be eligible.
* Medium: approved task plus Architecture approval.
* High: recorded Owner approval, Architecture and Security approvals, and a
  separate Owner-issued Codex execution authorization bound to the current
  canonical task snapshot, repository, base branch, and provider policy
  version. A mismatch denies with `codex_execution_authorization_stale` until
  the Owner reauthorizes the current state.
* Critical: denied with `critical_execution_not_supported`.

All jobs are bound to a task snapshot, approved repository allow-list, pinned
SHA, provider policy version, 30-minute maximum runtime, at most three attempts,
and a single Codex job concurrency limit. A task cannot alter these limits.

## Output and audit

Only safe structured evidence is retained: provider reference, status,
duration, pinned SHA, changed path count/list, protected-path indicator,
diff hash, concise validation summaries, policy result, and cleanup result.
Raw model reasoning, raw worker logs, prompts, credentials, and uncontrolled
terminal output are excluded from the evidence UI.

## Phase 4 worker control plane

Worker-only RPCs atomically claim a pinned queued job, issue a hashed lease,
renew heartbeats, load the server-derived envelope, and accept only
lease-owned start, success, or bounded-failure transitions. Browser roles have
no execute grant for those RPCs or table access to worker readiness/configuration.
The private readiness endpoint reports only safe booleans to Owner/Admin.

The included Deno runtime defaults both live and fake execution off. Its fake
provider uses the real lifecycle with no network or credentials. The Docker
image is non-root, contains no secrets, has no Docker socket, and exposes only
a controlled `/workspaces` path. See [TRUSTED_WORKER_OPERATIONS.md](TRUSTED_WORKER_OPERATIONS.md).

## Enablement checklist

- [ ] architecture review
- [ ] security review
- [x] worker container reviewed
- [x] synthetic fake-provider lifecycle implemented
- [ ] worker host selected and deployed
- [ ] provider secret provisioned
- [ ] repository read credential provisioned
- [ ] repository allow-list confirmed
- [ ] network isolation verified
- [ ] workspace isolation verified
- [ ] provider concurrency configured
- [ ] runtime/token limits configured
- [ ] monitoring available
- [ ] audit verified
- [ ] cancellation verified
- [ ] no GitHub write credential present
- [ ] no deployment credential present
- [ ] dry-run/fake integration tests passed
- [ ] explicit Owner authorization to enable

Until every item is independently verified, the Codex configuration row remains
disabled. Phase 3 has no GitHub push, branch creation, pull request creation,
merge, CI trigger, or deployment capability.

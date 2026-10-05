# Disposable Control E2E

Node 22+, Flutter, Playwright 1.62.1 and Chrome/Chromium. No VM. Only retained
`automation-proof-reconstructed` (`evvksortjegefsldamwb`) is permitted. This is
Tier 2 validation, not release authorization.

## Local run

Supply these through an authorized secret store into the **server process**:
`CONTROL_E2E_SUPABASE_URL`, `CONTROL_E2E_ANON_KEY`, `CONTROL_E2E_ADMIN_KEY`.
The URL must exactly equal `https://evvksortjegefsldamwb.supabase.co`; JWT keys
must have that ref and respectively `anon` / `service_role` roles. Opaque keys
are deliberately unsupported until a reviewed project-binding mechanism exists.
Never paste keys into command lines, logs, Git or browser configuration.

```sh
node --test tool/e2e/test/*.test.cjs
npm ci --ignore-scripts --prefix tool/e2e
node tool/e2e/build.cjs
node tool/e2e/run.cjs
```

Commit source before proof. Each build is stamped with HEAD and hashes; the run
rejects dirty source, altered output, stale SHA, production configuration or an
unresolved earlier fixture journal. Use `CHROME_EXECUTABLE` for installed Chrome,
or install pinned Playwright Chromium locally/ephemerally. An existing trusted
runtime may supply `PLAYWRIGHT_MODULE_PATH` pointing to its Playwright package.

The isolated build includes all three public compile defines and replaces only
the copied runtime config. Source production assets remain untouched. Build
output is scanned for the production ref. The fixture key is removed from the
Flutter child environment and never written to a build define/file.
Browser contexts block service workers; CSP, request allowlist, redirect rejection
and WebSocket rejection constrain backend traffic to loopback and the pinned disposable
host. Flutter fallback fonts have one browser-only exception: HTTPS static
`fonts.gstatic.com/s/` font files, GET only, no query, credentials or redirects.
This fixes harness-induced CSP font errors without permitting other backend hosts.
Server API requests enforce the disposable host and reject redirects. No retries
can accidentally send fixture credentials to another project.

## Fixtures and failure recovery

Seven unique accounts/run: owner UI, admin UI, read_only UI, inactive admin UI,
ordinary UI, AAL1 API, AAL2 API. Random run UUID plus explicit scenario names in
`@example.invalid` identities; random per-account passwords. Email confirmation
is server-side without delivery. Each browser scenario uses a fresh context;
API scenarios use different accounts. No shared sessions, parallel scenario
execution, permanent test passwords or production fixtures.

An atomic secret-free journal records creation intent before Auth calls and
captures only run/role-scenario/email/id/cleanup status. Teardown closes browsers,
deletes only synthetic actor audit rows, removes allowlist rows, deletes Auth
users, verifies Auth absence and zero allowlist/audit/usage rows, then verifies
email absence. Auth deletion removes its MFA/identity/session descendants.
Cleanup verifies the synthetic run metadata before deleting any discovered user.

On setup/browser failure, SIGINT/SIGTERM or the suite's ten-minute limit, teardown
still runs. API requests time out after 15 seconds, selectors after 25 seconds.
Process termination, host failure or backend outage cannot guarantee immediate
cleanup; the intent journal permits deterministic recovery. A failed cleanup is
fatal and blocks subsequent runs. Retain the journal until verified recovery:

```sh
node tool/e2e/cleanup.cjs build/control-e2e/runs/RUN-ID/fixtures.json
```

Recovery uses the same pinned disposable server credential. It scans paginated
Auth metadata only in server memory to recover a lost create response. Never
delete the retained branch as a cleanup shortcut. No schema/grants/RLS are changed.

## Scenarios and evidence

Active owner/admin login, synthetic TOTP/AAL2, aggregate HTTP200 + count shape,
settings permissions, read_only UI redirect + self role UPDATE denial/unchanged
role, ordinary/inactive denial, direct protected reporting AAL1 HTTP403,
independent AAL2 API success, logout and refresh replay400, logged-out route denial.
Stable Flutter semantics identifiers/roles are used, never pixel coordinates.

Each `evidence.json` records SHA/ref, named scenario PASS/FAIL and elapsed times,
created/cleaned counts, isolation/cleanup booleans, console categories/counts,
page errors, exact sanitized endpoint/status/code classifications, expected and
unexpected network failures, blocked/prod request counts, artifact paths/time.
Unknown errors block PASS. Known entitlement400 and telemetry400 defects also
block PASS. v2 RPC404 is expected only with successful V1 fallback; read_only
audit403 must match exact endpoint/method/code/role. See the task record inventory.
The command returns nonzero for an incomplete/dirty/unsafe/failing suite.

Raw console text, bodies, query strings, headers, passwords, tokens, TOTP keys,
HARs and traces are never persisted. Screenshots are intentionally disabled:
MFA screens and traces contain credentials. Failure evidence reports scenario
and safe error kind without Playwright's potentially secret-bearing call log.
Ignored evidence is local; do not upload fixture journals or complete build output.

## CI activation gate (live execution disabled)

The PR workflow executes only credential-free Node safety/lifecycle tests.
No live job, retained-branch secret, scheduled execution or paid service is added.
A separate reviewed activation must first establish:

1. Dedicated protected GitHub environment; manual dispatch from reviewed exact
   head only, never untrusted PR/fork code with fixture credentials.
2. Encrypted disposable URL/anon/admin secrets with this exact ref; no production
   credential, no fixture key in build environment, logs or artifacts.
3. Run concurrency lock for this retained branch; pinned tooling, bounded runtime,
   local isolated build and fail-closed checks before fixture creation.
4. Always-run teardown and recovery job that retains secret-free intent journals
   privately through cancellation/runner failure, with a human recovery owner.
5. Upload only reviewed sanitized evidence, no traces/HAR/build/journal. Resolve
   genuine A contract defects before claiming clean full E2E CI.

Rollback: remove the harness/workflow and optional semantics identifiers from
source; no migration, deployment, production data or billing rollback required.

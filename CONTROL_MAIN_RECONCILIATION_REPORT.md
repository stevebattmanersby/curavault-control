# CuraVault Control Main Reconciliation Report

## A. Branch SHAs

- PR branch: `reconcile/phase4-main-baseline`
- PR branch HEAD before reconciliation edits: `f246c38f7012d54eb84a19ba21b32a53fde56992`
- Approved Phase 4 baseline: `origin/codex/control-published-ui-restore` at `f246c38f7012d54eb84a19ba21b32a53fde56992`
- Target base: `origin/main` at `5c96f1cea87bc539ccc2beace6b5e6a6622d24a2`
- Phase 5 branch: `origin/feature/development-control-plane-phase-5-worker-host` at `5e8c87716a29241d58c4a679448300af82406502`

## B. Graph And Divergence

`origin/main` is an ancestor of the Phase 4 baseline and of this reconciliation branch.

`origin/main...origin/codex/control-published-ui-restore` reported `0 25`, meaning the Phase 4 baseline is 25 commits ahead of `main` and `main` has no unique commits outside that line.

Relevant graph:

```text
f246c38 Merge pull request #5 from feature/development-control-plane-phase-4-trusted-worker
f290724 fix: harden trusted worker identity and readiness
6fbebb6 architecture: add trusted isolated Codex worker
d4917e3 Merge pull request #4 from feature/development-control-plane-phase-3-codex-provider
fb6fdfc test: format Codex provider assertions
e94cd44 fix: bind Codex authorization to task snapshot
e3ea7bc architecture: add controlled Codex provider integration
d49ec5d Merge pull request #3 from feature/development-control-plane-phase-2-dispatcher
453a9a7 feat: add secure mock execution dispatcher foundation
54a84ce Merge pull request #2 from feature/development-control-plane-phase-1
7c1650e ci: validate development control migrations
d217ce7 fix: enforce development approval and evidence access
5361111 feat: add development control plane foundation
39e7e9a feat(admin): restore website CMS navigation
...
5c96f1c origin/main
```

## C. Content Entering Main After Cleanup

The branch brings in the approved Control Plane work through Phase 4:

- Development Control UI, state, models, navigation, and admin RBAC updates.
- Development Control Plane Phase 1 migrations and tests.
- Mock dispatcher Phase 2 migrations and tests.
- Controlled Codex provider Phase 3 migrations, policy checks, and worker contract tests.
- Trusted isolated worker architecture Phase 4 migrations, Deno runtime, fake provider, Dockerfile, and docs.
- Supabase migration reconciliation docs/tests and canonical shared baseline migrations.
- Flutter CI workflow for format/test/analyzer regression, Deno provider tests, worker container build, and disposable migration validation.

Cleanup in this branch:

- Removed `supabase/migrations/20260716144804_dreamflow_generated.sql` from the active migration path.
- Archived it at `docs/archive/dreamflow/20260716144804_dreamflow_generated.sql`.
- Added `docs/archive/dreamflow/README.md`.
- Updated `docs/supabase_migration_reconciliation.md` so it no longer claims that sample-data SQL is active.
- Ran `dart format lib test`, which normalized existing Dart formatting.
- Restored `.dreamflow` so Dreamflow environment metadata is not part of the PR diff.
- Restored `pubspec.lock`; its changes were local Flutter/Dart resolver drift and not required by this branch.

## D. Phase 5 Exclusion Proof

Phase 5 remains excluded. The only commits ahead of Phase 4 on the Phase 5 branch are:

```text
38e6b86 infrastructure: harden trusted Codex worker host
5e8c877 fix: remove trusted worker Docker socket exposure
```

`git branch --contains 38e6b86` and `git branch --contains 5e8c877` list only `feature/development-control-plane-phase-5-worker-host`, not `reconcile/phase4-main-baseline`.

## E. Test Results

- `dart format lib test`: passed; normalized Dart formatting and later formatted 2 analyzer-fix files.
- `dart format --output=none --set-exit-if-changed lib test`: passed; 0 changed.
- `deno fmt --check worker`: passed; checked 7 files.
- `flutter pub get`: passed during validation, but its `pubspec.lock` resolver drift was reverted because `pubspec.yaml` did not change.
- `flutter test`: passed; 46 tests passed, 0 failed.
- `deno test --allow-net --allow-env --allow-read --allow-write worker/codex_execution_provider_test.ts worker/runtime/worker_runtime_test.ts`: passed; 7 tests passed, 0 failed.
- `git diff --check`: passed; Git reported CRLF normalization warnings on four Dart files, but no whitespace errors.
- `flutter analyze`: passed; no issues found.
- `bash tool/check_analyzer_regression.sh origin/main`: not run successfully because Windows `bash.exe` is present only as the WSL relay and fails with `/bin/bash` unavailable.
- `tool/validate_development_control_migration.sh`: not run because `psql` is not installed on PATH and Docker is unavailable for a disposable container fallback.
- Docker build: not run because Docker Desktop Linux engine is unavailable.

## E1. Analyzer Categorisation And Fixes

Baseline comparison:

- `origin/main` analyzer result after dependency resolution: 57 issues.
- Reconciliation branch analyzer result before fixes: 137 issues.
- Net new analyzer findings from the Phase 1-4/reconciliation line: 80 issues.

Categories:

- Phase 1-4 introduced and fixed: 80 findings, mostly `curly_braces_in_flow_control_structures` in changed/admin files plus deprecation fallout after Flutter 3.44.2 formatting.
- Pre-existing baseline from `main`: 57 findings in existing admin Supabase query/repository, AI usage, billing, plans/permissions, and usage-event code.
- Generated/Dreamflow artifact: 0 active analyzer issues. The sample-data migration is quarantined outside `supabase/migrations`.
- Safe-to-defer info/warning: the six disconnected legacy AI usage tab declarations were pre-existing baseline debt and are now explicitly marked with targeted `unused_element` ignores rather than removed in this reconciliation branch.

Fixes applied:

- Applied analyzer mechanical fixes for missing braces, local variable names, and deprecated dropdown `value` arguments.
- Removed one unused local helper `sumBy` from `supabase_admin_queries.dart`.
- Added targeted `// ignore: unused_element` comments to six unused legacy AI usage tab classes instead of deleting a large unused UI/charts block.

Remaining analyzer issues: none.

## E2. Pubspec.lock Decision

`flutter pub get` changed only transitive packages tied to the local Flutter 3.44.2 / Dart 3.12.2 resolver:

- `characters`
- `leak_tracker`
- `leak_tracker_flutter_testing`
- `leak_tracker_testing`
- `matcher`
- `material_color_utilities`
- `meta`
- `test_api`
- `vector_math`
- Dart SDK lower bound in the lockfile

`pubspec.yaml` did not change, and no branch work required dependency changes. The `pubspec.lock` diff was restored as local tool drift.

## F. Security Validation

Static validation found the intended fail-closed controls:

- Mock execution configuration defaults disabled: `values ('mock', false)`.
- Codex provider configuration defaults disabled: `values ('codex', false)`.
- Worker `live_execution_enabled` and `fake_execution_enabled` default false.
- Worker role is `curavault_codex_worker login noinherit`.
- Worker RPCs are revoked from `public`, `anon`, and `authenticated`.
- Worker RPCs are granted only to `curavault_codex_worker`.
- Browser code submits task IDs only; provider configuration, repository revision pins, credentials, worker leases, and readiness internals stay server-side.
- Secret-pattern diff scan found guardrail/documentation/test placeholder references, not real credentials.
- `.dreamflow` is restored and no longer appears in the reconciliation diff.

No production Supabase changes were made. No migrations were applied. Live Codex execution was not enabled. No credentials were provisioned.

## G. Schema / Migration Consistency

Static inspection shows the Flutter control client references tables and RPCs created by the active migrations:

- `admin_development_tasks`
- `admin_development_prompt_templates`
- `admin_development_task_events`
- `admin_development_reviews`
- `admin_development_checks`
- `admin_releases`
- `admin_development_execution_jobs`
- `admin_development_execution_events`
- `admin_development_execution_policy_decisions`
- `admin_request_mock_development_execution`
- `admin_cancel_development_execution`
- `admin_codex_execution_available`
- `admin_request_codex_development_execution`
- `admin_codex_live_execution_readiness`

The active migration directory no longer contains the Dreamflow sample-data migration. The archived file is still searchable under `docs/archive/dreamflow` and clearly marked as historical reference only.

Disposable SQL/RLS execution remains unverified locally because the required Postgres execution path was unavailable.

## H. Removed / Quarantined Artifacts

Quarantined:

- From: `supabase/migrations/20260716144804_dreamflow_generated.sql`
- To: `docs/archive/dreamflow/20260716144804_dreamflow_generated.sql`

Reason: the file loops over `auth.users` and inserts demo/sample user, entitlement, family, medical, appointment, medication, vaccination, insurance, vital, and document metadata rows. It is not safe as an automatic canonical production migration.

Still active and requires human awareness:

- `supabase/migrations/20260702133740_dreamflow_generated.sql` remains active because it is part of the recovered canonical migration history documented in `docs/supabase_migration_reconciliation.md`; it changes entitlement schema/defaults rather than seeding demo/sample user data.

## I. Blockers Remaining

- Disposable SQL/RLS validation could not run locally due missing `psql` and unavailable Docker engine.
- Docker worker image validation could not run locally due unavailable Docker Desktop Linux engine.
- Analyzer regression shell script could not run locally due missing usable Bash, but full `flutter analyze` now passes locally.

## J. Recommended PR Strategy

This branch is ready to push as a PR head for review and CI. Do not merge until GitHub CI confirms the disposable SQL/RLS migration validation and Docker worker image validation in the Ubuntu environment.

Recommended path:

1. Keep `reconcile/phase4-main-baseline` as the PR head.
2. Base the PR on `main`.
3. Do not merge or cherry-pick Phase 5.
4. Run CI on GitHub, where Ubuntu Bash, Postgres service, and Docker should be available.
5. Treat any SQL/RLS or Docker CI failure as blocking.
6. Do not apply production migrations until a separate human-approved migration plan exists.

## K. Final Conclusion

SAFE TO OPEN PR

The high-risk sample-data migration has been removed from the active migration path, Phase 5 is excluded, `pubspec.lock` tool drift has been restored, `.dreamflow` environment metadata is no longer in the diff, analyzer is clean, and local Flutter/Deno/format/diff checks pass. SQL/RLS and Docker validation remain CI-gated because the local machine does not currently have `psql` or a running Docker Desktop Linux engine.

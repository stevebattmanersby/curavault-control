# CONTROL-RELEASE-01 Future Contract

This document reserves the architecture contract for the future Release Control Dashboard. It does not implement the feature.

## Purpose

Release Control will provide one visual source of truth for CuraVault release state across:

- Android
- iOS
- Web
- Backend
- Control
- current development cycles and concurrent workstreams

## V1 constraints

V1 must be observability-first. It must not include buttons or background jobs that:

- merge PRs
- deploy
- apply migrations
- publish store builds
- mutate production Supabase/Auth/Netlify/DNS/Stripe
- enable live Codex or trusted-worker execution

Future actions, if ever introduced, require their own AAL2, role, confirmation, exact-SHA, audit, and human authorization model.

## Evidence model

Release state should be hybrid:

- automated technical evidence from GitHub, Netlify, Supabase, and repository metadata
- manual human/external gates for Apple review, Google Play status, physical smoke, GO/NO-GO, and rollback decisions
- derived rollups that show stale or unknown when evidence is old or unavailable

## Gate states

- `NOT_STARTED`
- `IN_PROGRESS`
- `WAITING_EXTERNAL`
- `WAITING_HUMAN`
- `PASS`
- `FAIL`
- `BLOCKED`
- `SUPERSEDED`

Each gate should store evidence, timestamp, actor/source, related SHA/build/deployment, notes, and next action.

## Auditability

Manual changes must record actor, previous value, new value, reason, timestamp, and related artifact. Release Control must never store secrets, raw customer content, PHI, or raw CI logs.

## PR #8 dependency

Release Control implementation should begin only after PR #8 is resolved or deliberately rebased against its final merged state, because PR #8 owns active Control security/audit/CMS hardening.

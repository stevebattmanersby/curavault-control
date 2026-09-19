#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash tool/control_validation_tier.sh tier1
  bash tool/control_validation_tier.sh tier2 [base_sha]
  bash tool/control_validation_tier.sh tier3 --confirm-release-gate [base_sha]

Tier 3 is explicit by design. It is a release gate checklist runner and must not
be invoked as part of ordinary development or PR validation.
USAGE
}

tier="${1:-}"
if [[ -z "$tier" || "$tier" == "-h" || "$tier" == "--help" ]]; then
  usage
  exit 0
fi
shift || true

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

base_sha="${1:-origin/main}"
if [[ "$tier" == "tier3" && "${1:-}" == "--confirm-release-gate" ]]; then
  shift
  base_sha="${1:-origin/main}"
fi

run_common_static_checks() {
  dart format --output=none --set-exit-if-changed test/control_framework_contract_test.dart
  git diff --check
  if git grep -n -I -E '(-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----|supabase_[a-zA-Z0-9_-]{80,}|sb_secret_[a-zA-Z0-9_-]{20,}|sk-[a-zA-Z0-9_-]{20,}|gh[pousr]_[a-zA-Z0-9_]{20,})' -- . \
    ':(exclude)tool/control_validation_tier.sh' \
    ':(exclude)test/control_framework_contract_test.dart'; then
    echo 'Potential secret-like string found. Review before continuing.' >&2
    exit 1
  fi
}

case "$tier" in
  tier1)
    run_common_static_checks
    flutter test test/control_framework_contract_test.dart
    ;;
  tier2)
    run_common_static_checks
    flutter test
    bash tool/check_analyzer_regression.sh "$base_sha"
    ;;
  tier3)
    if [[ "${1:-}" != "--confirm-release-gate" && "${tier_confirmed:-}" != "true" ]]; then
      echo 'Tier 3 requires: bash tool/control_validation_tier.sh tier3 --confirm-release-gate [base_sha]' >&2
      exit 1
    fi
    run_common_static_checks
    flutter test
    bash tool/check_analyzer_regression.sh "$base_sha"
    flutter build web --release
    cat <<'TIER3'
Tier 3 release gate reminder:
- Recheck exact PR/head SHA.
- Confirm exact-head CI.
- Run disposable runtime proof for HIGH database/security changes.
- Run migration dry-run when migrations are pending.
- Record rollback target.
- Obtain separate human authorization before merge, deploy, migration, or production mutation.
- Perform read-only verification after any authorized production action.
TIER3
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

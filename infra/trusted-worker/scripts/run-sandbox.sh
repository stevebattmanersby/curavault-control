#!/usr/bin/env bash
set -euo pipefail

# The control worker invokes this fixed policy only; task content is never a
# command. The caller supplies a pre-created workspace and a fixed image.
workspace="$1"
shift
timeout_seconds="${CURAVAULT_SANDBOX_TIMEOUT_SECONDS:-1800}"
if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || (( timeout_seconds == 0 || timeout_seconds > 1800 )); then
  echo 'Sandbox timeout must be between 1 and 1800 seconds.' >&2
  exit 64
fi
mount_source="$workspace"
if [[ "$(uname -s)" =~ ^MINGW|^MSYS ]]; then
  # Docker Desktop needs a Windows source path, while Docker target paths must
  # stay Linux paths. This branch is only a local-contract-test adapter.
  mount_source="$(cygpath -m "$workspace")"
  export MSYS_NO_PATHCONV=1
fi

run_sandbox=(docker run --rm
  --network none \
  --cpus 1.0 \
  --memory 2g \
  --pids-limit 256 \
  --ulimit fsize=1073741824:1073741824 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  --user 65532:65532 \
  --workdir /workspace \
  --mount "type=bind,src=${mount_source},dst=/workspace" \
  "$@")

# Ubuntu hosts enforce the 30-minute hard deadline. The Git-for-Windows
# contract test uses Docker Desktop and intentionally exercises the same
# container isolation without requiring GNU timeout on the workstation.
if [[ "$(uname -s)" == "Linux" ]] && command -v timeout >/dev/null 2>&1; then
  exec timeout --signal=TERM --kill-after=30s "${timeout_seconds}s" "${run_sandbox[@]}"
fi
exec "${run_sandbox[@]}"

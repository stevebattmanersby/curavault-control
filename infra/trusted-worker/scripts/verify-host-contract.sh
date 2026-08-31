#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
runner="$root/infra/trusted-worker/scripts/run-sandbox.sh"
image="${SANDBOX_IMAGE:-curavault-trusted-worker:reviewed}"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

grep -q -- '--network none' "$runner"
grep -q -- '--pids-limit 256' "$runner"
grep -q -- '--cap-drop ALL' "$runner"
grep -q -- 'no-new-privileges:true' "$runner"
! grep -q '/var/run/docker.sock' "$runner"

# No external request succeeds: the sandbox receives Docker's none network.
"$runner" "$workspace" "$image" deno eval '
  try { await fetch("https://example.invalid"); Deno.exit(1); }
  catch (_) { Deno.exit(0); }
'
echo 'Trusted worker host sandbox contract passed.'

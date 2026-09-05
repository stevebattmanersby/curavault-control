#!/usr/bin/env bash
set -euo pipefail

base_sha="${1:?base commit SHA is required}"
repo_root="$(git rev-parse --show-toplevel)"
baseline_dir="$(mktemp -d)"
head_output="$baseline_dir/analyzer-head.machine"
trap 'git -C "$repo_root" worktree remove --force "$baseline_dir" >/dev/null 2>&1 || true; rm -rf "$baseline_dir"' EXIT

normalize_diagnostics() {
  awk -F'|' '
    $1 ~ /^(ERROR|WARNING|INFO)$/ && NF >= 4 {
      path = $4
      if (match(path, /(^|[\\/])(lib|test)[\\/]/)) {
        path = substr(path, RSTART + 1)
      }
      gsub(/\\/, "/", path)
      gsub(/\/+/, "/", path)
      print $1 "|" $2 "|" $3 "|" path
    }
  ' "$1" | sort
}

git worktree add --detach "$baseline_dir" "$base_sha" >/dev/null
(
  cd "$baseline_dir"
  flutter pub get >/dev/null
  dart analyze --format machine > "$baseline_dir/analyzer.machine" 2>&1 || true
)
dart analyze --format machine > "$head_output" 2>&1 || true

normalize_diagnostics "$baseline_dir/analyzer.machine" > "$baseline_dir/analyzer.normalized"
normalize_diagnostics "$head_output" > "$baseline_dir/analyzer-head.normalized"

baseline_count="$(wc -l < "$baseline_dir/analyzer.normalized" | tr -d ' ')"
head_count="$(wc -l < "$baseline_dir/analyzer-head.normalized" | tr -d ' ')"
new_diagnostics="$(comm -13 "$baseline_dir/analyzer.normalized" "$baseline_dir/analyzer-head.normalized")"

echo "Baseline analyzer diagnostics: $baseline_count"
echo "PR analyzer diagnostics: $head_count"
if [[ -n "$new_diagnostics" ]]; then
  echo 'New analyzer diagnostics:' >&2
  echo "$new_diagnostics" >&2
  exit 1
fi

echo 'Analyzer regression gate passed: no new diagnostics.'

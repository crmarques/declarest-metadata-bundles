#!/usr/bin/env bash
# Emits the set of bundle names changed vs a base ref (one per line).
# Also prints the literal string `__ALL__` if a shared-infra path changed
# (schemas/, tools/, workflows, requirements.txt) — the caller should then
# validate every bundle.
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
IFS=$'\n\t'
. "$(dirname "$0")/common.sh"

base=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="$2"; shift 2;;
    -h|--help)
      cat <<EOF
Usage: $0 [--base <ref>]
Defaults --base to \$GITHUB_BASE_REF then origin/main then HEAD^.
EOF
      exit 0
      ;;
    *) die "unknown arg: $1";;
  esac
done

if [[ -z "${base}" ]]; then
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    base="origin/${GITHUB_BASE_REF}"
  elif git -C "${REPO_ROOT}" rev-parse --verify origin/main >/dev/null 2>&1; then
    base="origin/main"
  else
    base="HEAD^"
  fi
fi

changed_paths="$(git -C "${REPO_ROOT}" diff --name-only "${base}...HEAD" -- . || true)"

shared_infra=0
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  case "$p" in
    schemas/*|tools/*|.github/workflows/*|requirements.txt)
      shared_infra=1
      ;;
  esac
done <<< "${changed_paths}"

if [[ "${shared_infra}" -eq 1 ]]; then
  echo "__ALL__"
  exit 0
fi

printf '%s\n' "${changed_paths}" \
  | awk -F/ '$1 == "bundles" && NF >= 2 { print $2 }' \
  | sort -u

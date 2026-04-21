#!/usr/bin/env bash
# Shared helpers for tools/ scripts. Source this from every script.
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
IFS=$'\n\t'

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TOOLS_DIR}/.." && pwd)"
BUNDLES_DIR="${REPO_ROOT}/bundles"
SCHEMA_PATH="${REPO_ROOT}/schemas/bundle.schema.json"
INDEX_PATH="${REPO_ROOT}/index/index.json"

log() { printf '%s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# parse_bundle_tag <tag>
# Emits `NAME=<name>\nVERSION=<x.y.z...>` to stdout on success.
parse_bundle_tag() {
  local tag="$1"
  if [[ "${tag}" =~ ^bundle/([a-z0-9][a-z0-9-]*)/v([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?)$ ]]; then
    printf 'NAME=%s\nVERSION=%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  die "tag ${tag@Q} does not match 'bundle/<name>/v<X.Y.Z>[-pre][+build]'"
}

# require_bundle_dir <name>
# Exits if bundles/<name>/bundle.yaml does not exist.
require_bundle_dir() {
  local name="$1"
  local dir="${BUNDLES_DIR}/${name}"
  [[ -d "${dir}" ]] || die "bundle directory not found: ${dir}"
  [[ -f "${dir}/bundle.yaml" ]] || die "bundle manifest not found: ${dir}/bundle.yaml"
}

# read_manifest_field <manifest_path> <dotted.path>
# Reads a scalar field from bundle.yaml via Python.
read_manifest_field() {
  local path="$1" field="$2"
  python3 - "$path" "$field" <<'PY'
import sys, yaml
path, field = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as fh:
    manifest = yaml.safe_load(fh) or {}
cur = manifest
for segment in field.split("."):
    if not isinstance(cur, dict) or segment not in cur:
        sys.exit(0)
    cur = cur[segment]
if cur is None:
    sys.exit(0)
print(cur)
PY
}

# list_bundles
# Emits each bundle directory name (one per line).
list_bundles() {
  local d
  for d in "${BUNDLES_DIR}"/*/; do
    [[ -d "$d" ]] || continue
    basename "$d"
  done | sort
}

export TOOLS_DIR REPO_ROOT BUNDLES_DIR SCHEMA_PATH INDEX_PATH

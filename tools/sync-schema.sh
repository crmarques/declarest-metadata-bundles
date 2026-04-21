#!/usr/bin/env bash
# Re-vendor schemas/bundle.schema.json from declarest and rewrite
# schemas/SCHEMA_SOURCE with provenance.
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
IFS=$'\n\t'
. "$(dirname "$0")/common.sh"

SRC_PATH=""
SRC_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-path) SRC_PATH="$2"; shift 2;;
    --from-url)  SRC_URL="$2";  shift 2;;
    -h|--help)
      cat <<EOF
Usage: $0 [--from-path <path-to-declarest-checkout>] [--from-url <url>]
Default: ../declarest/schemas/bundle.schema.json relative to this repo.
EOF
      exit 0
      ;;
    *) die "unknown arg: $1";;
  esac
done

TARGET="${SCHEMA_PATH}"
TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

UPSTREAM_REV="unknown"

if [[ -n "${SRC_URL}" ]]; then
  log "fetching ${SRC_URL}"
  curl -sSL "${SRC_URL}" -o "${TMP}"
else
  PATH_ROOT="${SRC_PATH:-${REPO_ROOT}/../declarest}"
  UPSTREAM="${PATH_ROOT%/}/schemas/bundle.schema.json"
  [[ -f "${UPSTREAM}" ]] || die "upstream schema not found: ${UPSTREAM}"
  cp "${UPSTREAM}" "${TMP}"
  if git -C "${PATH_ROOT}" rev-parse HEAD >/dev/null 2>&1; then
    UPSTREAM_REV="$(git -C "${PATH_ROOT}" rev-parse HEAD)"
  fi
fi

cp "${TMP}" "${TARGET}"
SHA256="$(sha256sum "${TARGET}" | awk '{print $1}')"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "${REPO_ROOT}/schemas/SCHEMA_SOURCE" <<EOF
upstream=declarest
upstreamPath=schemas/bundle.schema.json
declarestRev=${UPSTREAM_REV}
sha256=${SHA256}
vendoredAt=${NOW}
EOF

log "vendored schema → ${TARGET}"
log "declarestRev=${UPSTREAM_REV}"
log "sha256=${SHA256}"

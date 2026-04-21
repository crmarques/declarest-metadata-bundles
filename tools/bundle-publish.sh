#!/usr/bin/env bash
# Push a built tarball to GHCR as an OCI artifact via oras, then update
# moving tags (latest/stable/major/major.minor) for stable releases.
#
# Requires: oras (setup-oras action), gh/oras already logged in.
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
IFS=$'\n\t'
. "$(dirname "$0")/common.sh"

NAME=""
VERSION=""
REGISTRY=""
INPUT_DIR="${REPO_ROOT}/out"
SIGN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2;;
    --registry) REGISTRY="$2"; shift 2;;
    --input-dir) INPUT_DIR="$2"; shift 2;;
    --sign) SIGN=1; shift;;
    -h|--help)
      cat <<EOF
Usage: $0 <bundle-name> --version X.Y.Z --registry ghcr.io/OWNER [--input-dir DIR] [--sign]
EOF
      exit 0
      ;;
    -*) die "unknown flag: $1";;
    *)
      if [[ -z "${NAME}" ]]; then NAME="$1"; shift
      else die "extra arg: $1"; fi
      ;;
  esac
done

[[ -n "${NAME}" ]]     || die "missing <bundle-name>"
[[ -n "${VERSION}" ]]  || die "missing --version"
[[ -n "${REGISTRY}" ]] || die "missing --registry (e.g. ghcr.io/crmarques)"

VERSION="${VERSION#v}"
ARCHIVE="${INPUT_DIR}/${NAME}-${VERSION}.tar.gz"
[[ -f "${ARCHIVE}" ]] || die "archive not found: ${ARCHIVE}"

REPO="${REGISTRY}/declarest-metadata-bundles/${NAME}"
REF="${REPO}:${VERSION}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Minimal config blob describing the artifact.
CONFIG="${WORK}/config.json"
COMPAT_DECLAREST="$(read_manifest_field "${BUNDLES_DIR}/${NAME}/bundle.yaml" declarest.compatibleDeclarest || true)"
NAME="${NAME}" VERSION="${VERSION}" COMPAT="${COMPAT_DECLAREST}" \
python3 -c '
import json, os
data = {
  "name": os.environ["NAME"],
  "version": os.environ["VERSION"],
  "schemaVersion": 1,
  "compatibleDeclarest": os.environ.get("COMPAT") or None,
}
print(json.dumps(data, sort_keys=True))
' > "${CONFIG}"

# Annotations
ANNOTATIONS="${WORK}/annotations.json"
python3 - "${NAME}" "${VERSION}" > "${ANNOTATIONS}" <<'PY'
import datetime
import json
import os
import sys

name, version = sys.argv[1], sys.argv[2]
source = os.environ.get("SOURCE_URL")
if not source and os.environ.get("GITHUB_REPOSITORY"):
    source = f"https://github.com/{os.environ['GITHUB_REPOSITORY']}"

manifest_annotations = {
    "org.opencontainers.image.title": f"declarest-metadata-bundle/{name}",
    "org.opencontainers.image.version": version,
    "org.opencontainers.image.created": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
if source:
    manifest_annotations["org.opencontainers.image.source"] = source
if os.environ.get("GITHUB_SHA"):
    manifest_annotations["org.opencontainers.image.revision"] = os.environ["GITHUB_SHA"]

payload = {
  "$manifest": manifest_annotations
}
print(json.dumps(payload))
PY

log "pushing ${REF}"
ORAS_PUSH_OUTPUT=""
if ! ORAS_PUSH_OUTPUT="$(oras push "${REF}" \
  --config "${CONFIG}:application/vnd.declarest.bundle.config.v1+json" \
  --annotation-file "${ANNOTATIONS}" \
  "${ARCHIVE}:application/vnd.declarest.bundle.v1.tar+gzip" 2>&1)"; then
  printf '%s\n' "${ORAS_PUSH_OUTPUT}" >&2
  if grep -q 'permission_denied: write_package' <<<"${ORAS_PUSH_OUTPUT}"; then
    if [[ "${GHCR_TOKEN_SOURCE:-}" == "GITHUB_TOKEN" ]]; then
      log "GHCR denied write_package while using GITHUB_TOKEN."
      log "GITHUB_TOKEN can write only packages linked to ${GITHUB_REPOSITORY:-this repository}"
      log "or packages that grant this repository Actions access."
      log "Fix package permissions in GitHub Packages, delete and recreate the package"
      log "from this workflow, or configure GHCR_TOKEN with write:packages plus"
      log "GHCR_USERNAME when the token owner differs from the workflow actor."
    else
      log "GHCR denied write_package while publishing ${REPO}."
      log "Ensure the token used for oras login has write:packages access to this owner/package namespace."
    fi
  fi
  exit 1
fi
if [[ -n "${ORAS_PUSH_OUTPUT}" ]]; then
  printf '%s\n' "${ORAS_PUSH_OUTPUT}"
fi

DIGEST="$(oras manifest fetch --descriptor "${REF}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["digest"])')"
log "published digest: ${DIGEST}"

# Moving tags, skipped for prereleases (anything with a '-' before '+').
if ! [[ "${VERSION}" == *-* ]]; then
  MAJOR="${VERSION%%.*}"
  REST="${VERSION#*.}"
  MINOR="${REST%%.*}"
  for tag in "${MAJOR}" "${MAJOR}.${MINOR}" stable latest; do
    log "tagging ${REPO}@${DIGEST} → :${tag}"
    oras tag "${REPO}@${DIGEST}" "${tag}"
  done
fi

# Optional keyless sign via cosign + SBOM attach via syft.
if [[ "${SIGN}" -eq 1 ]]; then
  if command -v cosign >/dev/null 2>&1; then
    log "cosign sign --yes"
    cosign sign --yes "${REPO}@${DIGEST}"
  else
    log "cosign not installed, skipping sign"
  fi
  if command -v syft >/dev/null 2>&1; then
    log "syft SBOM + oras attach"
    SBOM="${WORK}/sbom.spdx.json"
    syft packages "${ARCHIVE}" -o spdx-json > "${SBOM}"
    oras attach "${REPO}@${DIGEST}" \
      --artifact-type application/vnd.declarest.bundle.sbom.v1+json \
      "${SBOM}:application/spdx+json"
  else
    log "syft not installed, skipping SBOM"
  fi
fi

printf 'DIGEST=%s\n' "${DIGEST}"

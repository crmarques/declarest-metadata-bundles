#!/usr/bin/env bash
# Build a deterministic bundle tarball under --output-dir (default ./out).
# Stamps the manifest version, copies bundle.yaml + README + metadata tree +
# openapi file into a staging dir, then tars with reproducibility flags.
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
IFS=$'\n\t'
. "$(dirname "$0")/common.sh"

NAME=""
VERSION=""
DRY_RUN=0
OUTPUT_DIR="${REPO_ROOT}/out"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --output-dir) OUTPUT_DIR="$2"; shift 2;;
    -h|--help)
      cat <<EOF
Usage: $0 <bundle-name> [--version X.Y.Z] [--dry-run] [--output-dir DIR]
If --version is omitted, the value stamped is read from bundle.yaml.
EOF
      exit 0
      ;;
    -*)
      die "unknown flag: $1"
      ;;
    *)
      if [[ -z "${NAME}" ]]; then NAME="$1"; shift
      else die "extra arg: $1"; fi
      ;;
  esac
done

[[ -n "${NAME}" ]] || die "usage: $0 <bundle-name> [--version X.Y.Z] [--dry-run] [--output-dir DIR]"
require_bundle_dir "${NAME}"

BUNDLE_DIR="${BUNDLES_DIR}/${NAME}"
MANIFEST="${BUNDLE_DIR}/bundle.yaml"

if [[ -z "${VERSION}" ]]; then
  VERSION="$(read_manifest_field "${MANIFEST}" version)"
fi
# Strip a leading v if provided
VERSION="${VERSION#v}"
if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  die "version ${VERSION@Q} is not semver-like"
fi

mkdir -p "${OUTPUT_DIR}"

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

# Stamp version into a rendered bundle.yaml under stage/
BUNDLE_DIR="${BUNDLE_DIR}" VERSION="${VERSION}" STAGE="${STAGE}" \
python3 - <<'PY'
import os
import pathlib
import yaml

stage = pathlib.Path(os.environ["STAGE"])
bundle_dir = pathlib.Path(os.environ["BUNDLE_DIR"])
version = os.environ["VERSION"]
manifest = yaml.safe_load((bundle_dir / "bundle.yaml").read_text(encoding="utf-8")) or {}
manifest["version"] = version
(stage / "bundle.yaml").write_text(
    yaml.safe_dump(manifest, sort_keys=False),
    encoding="utf-8",
)
PY

# Copy metadata tree, openapi file, README (README is optional but always
# present in this monorepo).
METADATA_ROOT="$(read_manifest_field "${MANIFEST}" declarest.metadataRoot)"
OPENAPI_REF="$(read_manifest_field "${MANIFEST}" declarest.openapi)"
[[ -n "${METADATA_ROOT}" ]] || die "declarest.metadataRoot missing from ${MANIFEST}"
[[ -n "${OPENAPI_REF}" ]] || die "declarest.openapi missing from ${MANIFEST}"

mkdir -p "${STAGE}/$(dirname "${METADATA_ROOT}")"
cp -R "${BUNDLE_DIR}/${METADATA_ROOT}" "${STAGE}/${METADATA_ROOT}"
mkdir -p "${STAGE}/$(dirname "${OPENAPI_REF}")"
cp "${BUNDLE_DIR}/${OPENAPI_REF}" "${STAGE}/${OPENAPI_REF}"
[[ -f "${BUNDLE_DIR}/README.md" ]] && cp "${BUNDLE_DIR}/README.md" "${STAGE}/README.md"

# Normalize mtimes inside the stage (redundant with tar --mtime but defensive).
find "${STAGE}" -exec touch -h -d @0 {} + 2>/dev/null || true

ARCHIVE="${NAME}-${VERSION}.tar.gz"
ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE}"

# List contents in deterministic order and pipe to gzip -n (no filename/mtime
# in the gzip header).
(
  cd "${STAGE}" && tar \
    --sort=name \
    --mtime='@0' \
    --owner=0 --group=0 --numeric-owner \
    --format=pax --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
    -cf - -- *
) | gzip -n -9 > "${ARCHIVE_PATH}"

(cd "${OUTPUT_DIR}" && sha256sum "${ARCHIVE}" > "${ARCHIVE}.sha256")

log "built: ${ARCHIVE_PATH}"
cat "${ARCHIVE_PATH}.sha256" >&2

if [[ "${DRY_RUN}" -eq 1 ]]; then
  log "dry-run: archive kept at ${ARCHIVE_PATH}"
fi

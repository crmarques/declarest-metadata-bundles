#!/usr/bin/env bash
# Validate a bundle's manifest against the vendored schema plus structural
# constraints (metadata root exists, openapi file exists, name/artifact
# template consistency, strict-decode).
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
IFS=$'\n\t'
. "$(dirname "$0")/common.sh"

[[ $# -ge 1 ]] || die "usage: $0 <bundle-name>"
NAME="$1"
require_bundle_dir "${NAME}"

BUNDLE_DIR="${BUNDLES_DIR}/${NAME}"
MANIFEST="${BUNDLE_DIR}/bundle.yaml"

log "validating bundle: ${NAME}"

BUNDLE_DIR="${BUNDLE_DIR}" NAME="${NAME}" SCHEMA_PATH="${SCHEMA_PATH}" MANIFEST="${MANIFEST}" \
python3 - <<'PY'
import json
import os
import pathlib
import sys
import urllib.parse

import yaml
import jsonschema

bundle_dir = pathlib.Path(os.environ["BUNDLE_DIR"]).resolve()
name = os.environ["NAME"]
schema_path = pathlib.Path(os.environ["SCHEMA_PATH"])
manifest_path = pathlib.Path(os.environ["MANIFEST"])

manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8")) or {}
schema = json.loads(schema_path.read_text(encoding="utf-8"))

validator = jsonschema.Draft202012Validator(schema)
errors = sorted(validator.iter_errors(manifest), key=lambda e: list(e.absolute_path))
if errors:
    for err in errors:
        loc = "/".join(str(p) for p in err.absolute_path) or "<root>"
        sys.stderr.write(f"schema: {loc}: {err.message}\n")
    sys.exit(1)

m_name = str(manifest.get("name", "")).strip()
if m_name != name:
    sys.exit(f"manifest.name {m_name!r} must equal bundle directory name {name!r}")

declarest = manifest.get("declarest") or {}
metadata_root = str(declarest.get("metadataRoot", "")).strip()
if not metadata_root:
    sys.exit("declarest.metadataRoot is required")

metadata_dir = (bundle_dir / metadata_root).resolve()
try:
    metadata_dir.relative_to(bundle_dir)
except ValueError:
    sys.exit("declarest.metadataRoot must stay within the bundle directory")
if not metadata_dir.is_dir():
    sys.exit(f"metadata root {metadata_root!r} does not exist or is not a directory")

metadata_file_candidates = ("metadata.yaml", "metadata.yml", "metadata.json")
found_metadata_file = any(
    path.name in metadata_file_candidates
    for path in metadata_dir.rglob("*")
    if path.is_file()
)
if not found_metadata_file:
    sys.exit(
        f"metadata root {metadata_root!r} does not contain any of {metadata_file_candidates!r}"
    )

openapi_ref = str(declarest.get("openapi", "")).strip()
if not openapi_ref:
    sys.exit("declarest.openapi is required and must reference a bundled file")
parsed = urllib.parse.urlparse(openapi_ref)
if parsed.scheme:
    sys.exit("declarest.openapi must be a relative file path inside the bundle")
openapi_path = (bundle_dir / openapi_ref).resolve()
try:
    openapi_path.relative_to(bundle_dir)
except ValueError:
    sys.exit("declarest.openapi must stay within the bundle directory")
if not openapi_path.is_file():
    sys.exit(f"declarest.openapi file {openapi_ref!r} does not exist or is not a file")

distribution = manifest.get("distribution") or {}
artifact_template = str(distribution.get("artifactTemplate", "")).strip()
if artifact_template:
    expected = f"{m_name}-{{version}}.tar.gz"
    if artifact_template != expected:
        sys.exit(
            f"distribution.artifactTemplate {artifact_template!r} must equal {expected!r}"
        )

sys.stderr.write(f"ok: bundle {name!r} manifest+structure valid\n")
PY

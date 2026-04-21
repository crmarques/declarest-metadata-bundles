#!/usr/bin/env bash
# Regenerate index/index.json by merging:
#   - the current bundles/*/bundle.yaml manifests (as the "unreleased/next"
#     descriptors), and
#   - an optional append of a just-released descriptor passed via
#     --append-release name,version,ociRef,digest,tarballSha256
#
# Simple and self-contained: reads the prior index if present and merges
# per-bundle versions, then sorts by semver per bundle.
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
IFS=$'\n\t'
. "$(dirname "$0")/common.sh"

APPEND=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --append-release) APPEND="$2"; shift 2;;
    -h|--help)
      cat <<EOF
Usage: $0 [--append-release name,version,ociRef,digest,tarballSha256]
EOF
      exit 0
      ;;
    *) die "unknown arg: $1";;
  esac
done

mkdir -p "$(dirname "${INDEX_PATH}")"

BUNDLES_DIR="${BUNDLES_DIR}" INDEX_PATH="${INDEX_PATH}" APPEND="${APPEND}" \
python3 - <<'PY'
import datetime
import json
import os
import pathlib

import yaml

bundles_dir = pathlib.Path(os.environ["BUNDLES_DIR"])
index_path = pathlib.Path(os.environ["INDEX_PATH"])
append = os.environ.get("APPEND", "")

def load_prior():
    if not index_path.exists():
        return {"schemaVersion": 1, "generatedAt": "", "bundles": []}
    try:
        return json.loads(index_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {"schemaVersion": 1, "generatedAt": "", "bundles": []}

def semver_key(v):
    core, _, _ = v.partition("+")
    base, _, pre = core.partition("-")
    parts = [int(x) for x in base.split(".")[:3]]
    while len(parts) < 3:
        parts.append(0)
    return (parts, pre == "", pre)

def read_manifest(path):
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}

prior = load_prior()
bundles = {b["name"]: b for b in prior.get("bundles", [])}

for bundle_dir in sorted(bundles_dir.iterdir()):
    if not bundle_dir.is_dir():
        continue
    manifest_path = bundle_dir / "bundle.yaml"
    if not manifest_path.exists():
        continue
    m = read_manifest(manifest_path)
    name = m.get("name", bundle_dir.name)
    entry = bundles.setdefault(name, {"name": name, "latest": None, "versions": []})
    entry["description"] = m.get("description", "")
    declarest = m.get("declarest") or {}
    entry["compatibleDeclarest"] = declarest.get("compatibleDeclarest")
    entry["compatibleManagedService"] = declarest.get("compatibleManagedService")
    entry["deprecated"] = bool(m.get("deprecated", False))

if append:
    parts = append.split(",")
    if len(parts) != 5:
        raise SystemExit("--append-release expects name,version,ociRef,digest,tarballSha256")
    name, version, oci_ref, digest, tarball_sha = parts
    entry = bundles.setdefault(
        name, {"name": name, "latest": None, "versions": []}
    )
    versions = entry.setdefault("versions", [])
    existing = next((v for v in versions if v["version"] == version), None)
    record = {
        "version": version,
        "ociRef": oci_ref,
        "digest": digest,
        "tarballSha256": tarball_sha,
        "releasedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    if existing:
        existing.update(record)
    else:
        versions.append(record)

# Recompute `latest` per bundle (highest stable version wins; falls back to
# highest overall if no stable).
for entry in bundles.values():
    versions = entry.get("versions") or []
    stable = [v for v in versions if "-" not in v["version"]]
    pool = stable or versions
    if pool:
        latest = sorted(pool, key=lambda v: semver_key(v["version"]))[-1]
        entry["latest"] = latest["version"]
        entry["versions"] = sorted(versions, key=lambda v: semver_key(v["version"]))
    else:
        entry["latest"] = None

out = {
    "schemaVersion": 1,
    "generatedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "bundles": [bundles[n] for n in sorted(bundles)],
}
index_path.write_text(
    json.dumps(out, indent=2, sort_keys=False) + "\n",
    encoding="utf-8",
)
print(f"wrote {index_path}")
PY

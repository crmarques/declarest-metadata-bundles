# Bundle Format

The bundle manifest schema is owned by the `declarest` repo. The
authoritative reference is:

- `declarest/agents/reference/metadata-bundle.md` — contract, strict-decode
  rules, compatibility gates.
- `declarest/schemas/bundle.schema.json` — machine-readable schema (vendored
  at `schemas/bundle.schema.json` here).

This document only lists the **monorepo-specific additions** layered on top
of the upstream contract.

## Directory layout (required)

```
bundles/<name>/
  bundle.yaml
  README.md
  openapi.yaml        # declarest.openapi must point at a local file
  metadata/           # declarest.metadataRoot
```

## Additional constraints enforced by this repo's CI

The upstream schema and the validator in `tools/validate-bundle.sh`
together enforce:

1. `bundles/<name>/bundle.yaml` `name` **equals the directory name**.
2. `declarest.metadataRoot` is a relative path inside the bundle directory
   (no parent traversal).
3. The metadata root exists and contains at least one
   `metadata.yaml`/`.yml`/`.json`.
4. `declarest.openapi` is a relative file path inside the bundle directory
   and the file exists.
5. `distribution.artifactTemplate`, if set, equals
   `<name>-{version}.tar.gz`.
6. Manifest decodes strictly (`additionalProperties: false` throughout the
   schema — unknown keys fail the release).

## In-repo version placeholder

`bundles/<name>/bundle.yaml` keeps a placeholder `version` (e.g. `0.1.0`)
between releases. The release workflow **stamps the actual tag version**
into `.release/bundle.yaml` before building the tarball; the committed
manifest is not modified by the release.

## Adding a new bundle

1. `mkdir bundles/<name>/` and populate `bundle.yaml`, `README.md`,
   `openapi.yaml`, `metadata/`.
2. Set `name: <name>`, `version: 0.1.0`,
   `distribution.artifactTemplate: <name>-{version}.tar.gz`.
3. `tools/validate-bundle.sh <name>` until clean.
4. Open a PR. `pr-validate.yml` will pick up the new bundle
   automatically.

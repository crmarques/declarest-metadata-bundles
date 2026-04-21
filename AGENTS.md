# AGENTS

## Purpose
Guide coding agents that maintain `declarest-metadata-bundles`, including
updates to existing bundles and creation of new bundles.

This repository is the canonical home for bundle content under
`bundles/<name>/`. The `declarest` repository remains canonical for runtime
contracts, metadata semantics, and the `bundle.yaml` schema.

## Startup Protocol
1. Read this file first.
2. Identify the request type and affected bundle names.
3. Load `README.md` and `docs/bundle-format.md` for all bundle-content work.
4. Load the minimal extra local docs from the matrix below.
5. When `../declarest` is available, load the upstream references named in
   the matrix before changing manifest or metadata semantics.
6. Inspect the current git status before editing and preserve user changes.
7. Before handoff, run the verification required by this file and review the
   prepared diff for correctness, secrets, and unexpected large or binary
   files.

## Repository Layout
| Path | Purpose |
|---|---|
| `bundles/<name>/bundle.yaml` | Bundle manifest validated by `schemas/bundle.schema.json` |
| `bundles/<name>/metadata/` | DeclaREST metadata tree rooted by `declarest.metadataRoot` |
| `bundles/<name>/openapi.yaml` | Managed-service OpenAPI or Swagger document referenced by the manifest |
| `bundles/<name>/README.md` | Bundle-specific user documentation |
| `schemas/bundle.schema.json` | Vendored snapshot from `declarest/schemas/bundle.schema.json` |
| `schemas/SCHEMA_SOURCE` | Provenance for the vendored schema |
| `tools/` | Validation, build, publish, index, and schema-sync helpers |
| `index/index.json` | Generated release index |
| `docs/` | Repository architecture, bundle format, release model, and ADRs |

## Request Routing
| Request Type | Required Local Files | Upstream Files When `../declarest` Exists |
|---|---|---|
| Existing bundle metadata or OpenAPI change | `README.md`, `docs/bundle-format.md`, affected `bundles/<name>/bundle.yaml`, affected metadata/OpenAPI files | `agents/reference/interfaces.md`, `agents/reference/metadata.md`, `agents/reference/metadata-bundle.md`, `agents/reference/quality.md` |
| New bundle | `README.md`, `docs/bundle-format.md`, `docs/architecture.md`, one similar existing bundle | `agents/reference/interfaces.md`, `agents/reference/metadata.md`, `agents/reference/metadata-bundle.md`, `agents/reference/quality.md` |
| Manifest-only change | `README.md`, `docs/bundle-format.md`, affected `bundle.yaml`, `schemas/bundle.schema.json` | `agents/reference/interfaces.md`, `agents/reference/metadata-bundle.md`, `agents/reference/quality.md` |
| Tooling or workflow change | `README.md`, `docs/architecture.md`, `docs/release-model.md`, affected `tools/*` or `.github/workflows/*` | `agents/reference/code.md`, `agents/reference/quality.md` |
| Schema sync or schema drift | `docs/architecture.md`, `docs/adr/0003-schema-vendoring-strategy.md`, `schemas/bundle.schema.json`, `schemas/SCHEMA_SOURCE`, `tools/sync-schema.sh` | `schemas/bundle.schema.json`, `agents/reference/metadata-bundle.md` |
| Documentation-only change | Targeted docs and any referenced files | Only load upstream docs when the text describes upstream-owned contracts |

## Bundle Authoring Rules
1. A bundle directory MUST be named `bundles/<name>` where `<name>` is a
   lowercase hyphenated identifier matching the manifest `name`.
2. Each bundle MUST contain `bundle.yaml`, `README.md`, `openapi.yaml`, and a
   `metadata/` tree.
3. `bundle.yaml` MUST conform to `schemas/bundle.schema.json` and the upstream
   `declarest` bundle manifest contract.
4. `declarest.metadataRoot` MUST be a repository-relative path inside the
   bundle directory, normally `metadata`.
5. `declarest.openapi` MUST be a relative file path inside the bundle
   directory in this repository, normally `openapi.yaml`.
6. `distribution.artifactTemplate`, when present, MUST equal
   `<name>-{version}.tar.gz`.
7. The committed `version` is a placeholder for local validation. Release
   tooling stamps the tag version into the packaged `bundle.yaml`.
8. Do not add decorative manifest keys. Unknown keys are rejected by strict
   schema validation.
9. Do not edit `schemas/bundle.schema.json` to make a bundle change pass.
   Schema-relevant changes land in `../declarest` first, then are vendored here
   through `tools/sync-schema.sh`.

## Metadata Rules
1. Metadata MUST use the canonical nested DeclaREST metadata structure.
2. Prefer `metadata.yaml` sidecars unless an existing bundle deliberately uses
   JSON for the same selector.
3. Collection selectors use the `_/metadata.yaml` convention. Preserve
   existing selector shape unless the request intentionally changes logical
   paths.
4. JSON Pointer fields MUST use RFC 6901 paths such as `/id`; template fields
   SHOULD prefer canonical placeholders such as `{{/id}}`.
5. Identity templates SHOULD define the managed service's stable remote ID and
   user-facing alias explicitly when they differ.
6. Secret material MUST NOT be committed in manifests, metadata, OpenAPI files,
   examples, generated contexts, logs, or docs.
7. `resource.secretAttributes` and `resource.secret` describe secret handling;
   they are not a place for secret values.
8. Include placeholders such as `{{include defaults.yaml}}` MUST point to
   selector-local files that are intended to ship in the bundle.
9. Metadata changes that alter behavior SHOULD include or update a bundle README
   example that covers at least one non-happy-path or edge-case resource.

## OpenAPI Rules
1. `openapi.yaml` MUST describe the managed-service version range declared in
   `declarest.compatibleManagedService` as closely as practical.
2. Keep OpenAPI documents local to the bundle and referenced by
   `declarest.openapi`.
3. Do not include live credentials, bearer tokens, private endpoints, or
   environment-specific server URLs.
4. When metadata relies on paths, schemas, request bodies, or media types from
   OpenAPI, keep the metadata and OpenAPI changes in the same bundle change.

## New Bundle Checklist
1. Create `bundles/<name>/bundle.yaml`, `README.md`, `openapi.yaml`, and
   `metadata/`.
2. Set manifest `apiVersion: declarest.io/v1alpha1` and
   `kind: MetadataBundle`.
3. Set `name: <name>`, a semver placeholder `version`, and a useful
   `description`.
4. Set `declarest.metadataRoot: metadata` and
   `declarest.openapi: openapi.yaml`.
5. Set `declarest.compatibleDeclarest` to the minimum declarest version that
   supports the metadata features used by the bundle.
6. Set both `declarest.compatibleManagedService.product` and
   `declarest.compatibleManagedService.versions`, or omit both only when the
   bundle is intentionally product-agnostic.
7. Set `distribution.artifactTemplate: "<name>-{version}.tar.gz"`.
8. Author the smallest metadata tree that covers the supported resources.
9. Document supported managed-service versions, important logical paths, and
   known limitations in `bundles/<name>/README.md`.
10. Run the bundle validation and reproducible-build checks before handoff.

## Verification
Install Python dependencies only when needed and allowed by the environment:

```bash
python3 -m pip install --requirement requirements.txt
```

For one changed bundle:

```bash
tools/validate-bundle.sh <name>
tools/bundle-build.sh <name> --output-dir /tmp/declarest-bundle-run1
tools/bundle-build.sh <name> --output-dir /tmp/declarest-bundle-run2
diff /tmp/declarest-bundle-run1/*.sha256 /tmp/declarest-bundle-run2/*.sha256
```

For multiple changed bundles, run the same checks for each affected bundle.
When shared infrastructure changes (`schemas/`, `tools/`,
`.github/workflows/`, or `requirements.txt`), validate and build every bundle
under `bundles/`.

For shell tooling changes:

```bash
bash -n tools/*.sh
```

For schema changes:

```bash
python3 -m json.tool schemas/bundle.schema.json >/dev/null
```

Documentation-only changes MAY skip bundle builds when they do not alter
manifest, metadata, OpenAPI, schema, tooling, workflow, or release behavior.

## Common Failure Modes
1. `bundle.yaml` `name` differs from the bundle directory name.
2. `declarest.metadataRoot` or `declarest.openapi` points outside the bundle
   directory or to a missing path.
3. The metadata root exists but contains no `metadata.yaml`, `metadata.yml`, or
   `metadata.json` sidecar.
4. A manifest includes an upstream-unsupported key that strict schema decoding
   rejects.
5. A schema change is made directly in this repository instead of being synced
   from `../declarest`.
6. OpenAPI and metadata drift so generated operation paths, media types, or
   validation schema references no longer describe the same managed-service
   behavior.

## Corner Cases
1. A bundle MAY use a non-`metadata` root only when `declarest.metadataRoot`
   points to that relative directory and validation passes.
2. A product-agnostic bundle MAY omit `declarest.compatibleManagedService`, but
   a product-specific bundle MUST set both `product` and `versions`.
3. A prerelease tag such as `bundle/<name>/v1.2.3-rc1` produces an immutable
   versioned artifact but does not update moving tags.
4. A committed manifest version may remain a placeholder; release builds stamp
   the tag version into the packaged manifest.

## Delivery Rules
1. Keep edits scoped to the requested bundle or repository area.
2. Do not stage, commit, tag, push, publish, or create releases unless the user
   explicitly asks for that operation.
3. Do not modify generated artifacts such as `index/index.json` unless the
   request or release/index workflow specifically requires it.
4. If required verification cannot run, report the blocker and the skipped
   command instead of presenting the change as complete.
5. Before handoff, inspect `git diff` for accidental unrelated changes,
   secrets, generated files, archives, or large binaries.

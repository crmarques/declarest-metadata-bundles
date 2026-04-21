# declarest-metadata-bundles

Repository of [DeclaREST](https://github.com/crmarques/declarest) metadata
bundles. Each bundle under `bundles/<name>/` releases independently on a
per-bundle tag. Artifacts publish to GHCR as OCI artifacts and, through
v0.x, also as GitHub Release assets so existing `spec.source.url`
consumers keep working.

## Layout

```
bundles/<name>/         one bundle per directory (haproxy, keycloak, rundeck, …)
  bundle.yaml           manifest (see schemas/bundle.schema.json)
  README.md
  openapi.yaml          OpenAPI / Swagger document the bundle targets
  metadata/             metadata tree (DeclaREST metadata resolution root)
schemas/                vendored bundle.schema.json + SCHEMA_SOURCE provenance
tools/                  shell helpers: validate, build, publish, index, …
index/index.json        machine-readable catalog of releases
docs/                   architecture, release model, ADRs
.github/workflows/      pr-validate.yml, release-bundle.yml, schema-drift.yml
```

## Release flow (short)

1. Bump `bundles/<name>/bundle.yaml` `version` (placeholder — release stamps
   the real value from the tag).
2. Open PR; `pr-validate.yml` validates only the changed bundle and does a
   reproducible dry-run build.
3. Merge, then push tag `bundle/<name>/v<X.Y.Z>`.
4. `release-bundle.yml`:
   - parses the tag, stamps the manifest, builds a deterministic tarball,
   - uploads it to a GitHub Release (`bundle/<name>/v<X.Y.Z>`),
   - pushes an OCI artifact to
     `ghcr.io/<owner>/declarest-metadata-bundles/<name>:<version>` via
     `oras`, updates moving tags (`:latest`, `:stable`, `:<major>`,
     `:<major>.<minor>`) unless prerelease,
   - regenerates `index/index.json`.

Tag format: `bundle/<name>/v<X.Y.Z>[-prerelease][+build]`.

## GHCR package permissions

`release-bundle.yml` logs in to GHCR with `GITHUB_TOKEN` by default. If GHCR
returns `permission_denied: write_package` for an existing package that is not
linked to this repository, grant this repository Actions access to the package,
delete and recreate the package from this workflow, or configure a `GHCR_TOKEN`
secret with `write:packages` access and, when the token owner differs from the
workflow actor, a matching `GHCR_USERNAME` secret.

## Quickstart — local

```bash
# Validate every bundle against the vendored schema
for b in bundles/*/; do tools/validate-bundle.sh "$(basename "$b")"; done

# Build a deterministic tarball (no publish)
tools/bundle-build.sh haproxy --version 0.1.0 --output-dir out

# Verify reproducibility
tools/bundle-build.sh haproxy --version 0.1.0 --output-dir out2
diff out/haproxy-0.1.0.tar.gz.sha256 out2/haproxy-0.1.0.tar.gz.sha256
```

## Adding a new bundle

1. `mkdir bundles/<name>` with `bundle.yaml`, `README.md`, `openapi.yaml`,
   `metadata/`.
2. Set `name: <name>`, `version: 0.1.0`,
   `distribution.artifactTemplate: <name>-{version}.tar.gz`.
3. Open a PR. CI validates the manifest against
   `schemas/bundle.schema.json` and does a dry-run build.

## Consumption

- `spec.source.url:
  https://github.com/<owner>/declarest-metadata-bundles/releases/download/bundle/<name>/v<ver>/<name>-<ver>.tar.gz`
- OCI: `ghcr.io/<owner>/declarest-metadata-bundles/<name>:<version>`
  (prefer pinning by digest for production).

## Relationship to declarest

The bundle manifest schema is owned by the declarest repo at
`schemas/bundle.schema.json`. This monorepo vendors a snapshot; a weekly
workflow opens a PR when declarest diverges. See
[docs/adr/0003-schema-vendoring-strategy.md](docs/adr/0003-schema-vendoring-strategy.md).
If the repository disables pull-request creation by `GITHUB_TOKEN`, configure
a `SCHEMA_DRIFT_PR_TOKEN` secret with contents and pull-request write access,
or use the workflow summary link to open the pushed drift branch manually.

# Architecture

`declarest-metadata-bundles` is a monorepo of independently versioned
DeclaREST metadata bundles. Each bundle under `bundles/<name>/` is a
standalone product with its own release lifecycle. This document captures
the rationale and constraints that shape the repository.

## Design goals

- **One repo, N lifecycles.** Tags are per-bundle, not repo-wide. A push
  to `bundle/haproxy/v0.1.0` releases only `haproxy`.
- **Deterministic artifacts.** Back-to-back builds of the same tree
  produce byte-identical tarballs so digests can be pinned by consumers.
- **Canonical schema from `declarest`.** The bundle manifest contract is
  owned by `declarest/schemas/bundle.schema.json`. This repo only vendors
  and validates.
- **GHCR as the primary distribution.** OCI artifacts via `oras` with
  pinnable digests; GitHub Releases stay in parallel through v0.x for
  `curl`-friendly consumers.
- **Future-friendly.** A single bundle can graduate to its own repo with
  a `git subtree split` if it ever outgrows the monorepo model.

## Layout

```
bundles/<name>/    one bundle per directory (bundle.yaml, README.md, openapi.yaml, metadata/)
schemas/           vendored bundle.schema.json + SCHEMA_SOURCE provenance
tools/             shell helpers: validate, build, publish, index, sync-schema
index/             machine-readable release catalog (index.json)
docs/              architecture, release model, bundle format, ADRs
.github/workflows/ pr-validate.yml, release-bundle.yml, schema-drift.yml, dependency-review.yml
```

## Packaging contract (what's shipped)

At the tarball root:

- `bundle.yaml` (with the version stamped from the release tag)
- `README.md`
- `metadata/**`
- `openapi.yaml` (the file pointed to by `declarest.openapi`)

Explicitly excluded: `.github/`, `tools/`, `schemas/`, `docs/`, dotfiles,
anything outside the bundle directory.

Reproducibility flags applied in `tools/bundle-build.sh`:

- `tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner
  --format=pax --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime`
- `gzip -n -9` (no filename/mtime in the gzip header)

PR CI runs the build twice and fails if `.sha256` differs.

## Schema vendoring

- `schemas/bundle.schema.json` is a read-only snapshot of
  `crmarques/declarest/schemas/bundle.schema.json`.
- `schemas/SCHEMA_SOURCE` records `declarestRev`, `sha256`, and
  `vendoredAt` so a human can tell at a glance which upstream commit
  the monorepo validates against.
- `tools/sync-schema.sh` re-vendors the snapshot from either a local
  `declarest` checkout (default: `../declarest`) or a URL
  (`--from-url`).
- `.github/workflows/schema-drift.yml` runs weekly and on any change to
  `tools/sync-schema.sh` or `schemas/**`. It checks out `declarest` so
  `schemas/SCHEMA_SOURCE` records the exact upstream commit. When the
  upstream diverges, it opens a PR if token permissions allow it; otherwise
  it leaves a pushed drift branch and a workflow-summary link for manually
  opening the PR.
- Rule: **this repo never adds schema fields.** Any schema-relevant
  change lands upstream in `declarest` first, then flows back via
  `sync-schema.sh`. See
  [adr/0003-schema-vendoring-strategy.md](adr/0003-schema-vendoring-strategy.md).

## Relationship to `declarest`

- `declarest` is the canonical decoder and runtime consumer (CLI +
  operator). It owns the manifest schema.
- `declarest-metadata-bundles` is read-only with respect to `declarest`.
  No file in `declarest` is modified by tooling here.
- Consumers install bundles either via `spec.source.url` pointing at a
  GitHub Release asset, or (future) via a native OCI source in the CRD.

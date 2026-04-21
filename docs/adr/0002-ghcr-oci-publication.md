# 0002 — GHCR OCI as primary distribution

- Status: Accepted
- Date: 2026-04-20

## Context

Bundles need a distribution surface that supports version pinning by
immutable digest, discovery via container tooling, and supply-chain
primitives (signing, SBOM). GitHub Releases work for basic `curl`
delivery but lack pull-by-digest, standard registry auth, and OCI
tooling integration.

## Decision

Publish every bundle as an OCI artifact to GHCR using `oras`:

- Ref: `ghcr.io/<owner>/declarest-metadata-bundles/<name>:<version>`
- Layer media type: `application/vnd.declarest.bundle.v1.tar+gzip`
- Config media type: `application/vnd.declarest.bundle.config.v1+json`
- Moving tags for stable releases only: `:latest`, `:stable`,
  `:<major>`, `:<major>.<minor>`.

Optional, enabled from day one:

- Keyless `cosign sign --yes` (GitHub OIDC) on the manifest digest.
- `syft` SBOM attached via `oras attach` with media type
  `application/spdx+json`.

GitHub Releases stay in parallel through v0.x so existing
`spec.source.url` consumers keep working without CRD changes. Deprecate
Releases at v1.0 in a follow-up ADR.

## Consequences

- Consumers can pin by digest:
  `ghcr.io/<owner>/declarest-metadata-bundles/<name>@sha256:…`
- `index/index.json` itself is published as
  `ghcr.io/<owner>/declarest-metadata-bundles/index:latest` so tooling
  can discover available bundles without cloning the repo.
- `declarest` gains a clean path to add a native `spec.source.oci`
  variant later; not a blocker for this repo's launch.

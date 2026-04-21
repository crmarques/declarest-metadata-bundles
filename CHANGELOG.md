# Changelog

Per-bundle release notes live on the corresponding GitHub Release and as
OCI artifact annotations. This file tracks monorepo-wide changes: tooling,
schemas, release-model conventions, and newly added or removed bundles.

## [Unreleased]

### Added
- Initial monorepo scaffold for declarest metadata bundles.
- Bundles migrated from peer single-bundle repos: `haproxy`, `keycloak`,
  `rundeck` (renamed from `haproxy-bundle`, `keycloak-bundle`,
  `rundeck-bundle`).
- Per-bundle tag-driven release workflow
  (`bundle/<name>/v<X.Y.Z>`) publishing to GHCR OCI and GitHub Releases.
- Vendored `schemas/bundle.schema.json` from declarest with weekly
  drift-detection workflow.
- `index/index.json` generator and OCI publication.

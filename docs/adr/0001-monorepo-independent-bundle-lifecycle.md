# 0001 — Monorepo with independent per-bundle lifecycles

- Status: Accepted
- Date: 2026-04-20

## Context

Until this ADR, each DeclaREST metadata bundle lived in its own peer repo
(`declarest-bundle-haproxy`, `-keycloak`, `-rundeck`). Every repo
duplicated the same CI (release-bundle.yml, dependency-review.yml,
dependabot.yml), the same `requirements.txt`, and the same release
contract. The duplication was cheap at three bundles and would grow
expensive as the catalog expands; drift between copies was already a
visible risk.

## Decision

Consolidate every bundle into a single monorepo,
`declarest-metadata-bundles`. Each bundle remains independently
releasable via per-bundle tags of the form `bundle/<name>/v<X.Y.Z>`. The
monorepo shares schema, tooling, and CI; the bundles share nothing about
their release cadence.

## Consequences

Positive:

- One place to update CI and schema validation.
- One vendored `bundle.schema.json`, one drift-detection workflow.
- Cross-bundle changes (e.g. metadata convention evolution) are visible
  in a single PR.

Negative:

- `CODEOWNERS` and review assignment must be set per `bundles/<name>/`
  to keep reviewer scope narrow.
- A renamed or deleted bundle affects monorepo-wide tooling. Mitigated
  by the matrix-driven PR workflow and explicit validation of the
  directory ↔ manifest name alignment.

## Considered alternatives

- **Keep one-repo-per-bundle.** Rejected — duplication cost dominates
  as the catalog grows.
- **Git submodules.** Rejected — extra operational burden for
  contributors, no upside for bundles with independent lifecycles.

## Escape hatch

A bundle can graduate to its own repo with
`git subtree split --prefix=bundles/<name> -b split-<name>` followed by
a push to a fresh repo. The tag format and release workflow carry over
with minimal edits.

# 0003 — Schema vendoring strategy

- Status: Accepted
- Date: 2026-04-20

## Context

`bundle.yaml`'s schema is authoritative in `declarest`
(`declarest/schemas/bundle.schema.json`). The monorepo needs that schema
to validate manifests in CI and in `tools/validate-bundle.sh`. Three
options were considered: git submodule, git subtree, or vendored
snapshot.

## Decision

Vendor a snapshot at `schemas/bundle.schema.json` and track provenance
in `schemas/SCHEMA_SOURCE` (`declarestRev`, `sha256`, `vendoredAt`).
Drift is detected by a weekly workflow
(`.github/workflows/schema-drift.yml`) that checks out `declarest`, re-runs
`tools/sync-schema.sh --from-path <checkout>` and opens a PR on
divergence.

## Consequences

- A contributor can open and read the schema directly; no submodule
  tooling required.
- Drift is visible in PRs, not hidden in a submodule pointer.
- The monorepo must **never add schema fields**. Any schema-relevant
  change lands upstream in `declarest` first, then flows back via
  `sync-schema.sh`. This ADR codifies that rule.

## Considered alternatives

- **Submodule.** Rejected — requires `--recurse-submodules` discipline,
  and the schema is a single JSON file; the tooling overhead is
  disproportionate.
- **Fetch at CI time.** Rejected — PR reviewers lose the ability to see
  the schema used by a given PR in the diff itself, and offline
  reproduction is harder.

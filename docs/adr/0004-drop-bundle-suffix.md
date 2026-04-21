# 0004 — Drop the `-bundle` suffix from bundle names

- Status: Accepted
- Date: 2026-04-20

## Context

The pre-monorepo peer repos shipped manifests with names
`haproxy-bundle`, `keycloak-bundle`, `rundeck-bundle`. Because every
consumer identifier (directory, manifest `name`, tarball filename, OCI
path, `spec.source.shorthand`) already says "bundle" by context — the
monorepo itself is called `declarest-metadata-bundles`, the dir is
`bundles/…`, the tag prefix is `bundle/…` — the `-bundle` suffix in the
manifest name is redundant.

Crucially, none of the pre-monorepo bundles ever released
(`version: 0.0.0`), so there are no live consumers pinning
`haproxy-bundle:X.Y.Z`.

## Decision

Drop the `-bundle` suffix everywhere. Directory name, manifest `name`,
tarball filename, OCI path, moving tags all use the short form.

| Before (peer repo)        | After (monorepo)                                        |
|---------------------------|---------------------------------------------------------|
| `haproxy-bundle`          | `haproxy`                                               |
| `haproxy-bundle-1.0.0.tgz`| `haproxy-1.0.0.tar.gz`                                  |
| shorthand `haproxy-bundle:v` | shorthand `haproxy:v`                                |

## Consequences

- Bundles feel like product names rather than package-manager style
  identifiers.
- `CODEOWNERS`, CI matrix entries, and documentation all use the same
  short name in every context.
- The pre-monorepo repos (`declarest-bundle-haproxy`, `-keycloak`,
  `-rundeck`) remain untouched per the migration plan; their READMEs
  should eventually point at this monorepo.

# rundeck

Rundeck metadata bundle for DeclaREST, including descendant-aware key
storage mappings.

## Bundle manifest

`bundle.yaml` is the canonical bundle manifest. The full manifest shape,
strict-decode rules, and compatibility-gate semantics are owned by
[DeclaREST Bundle Manifest reference](https://crmarques.github.io/declarest/reference/bundle-manifest/)
(`docs/reference/bundle-manifest.md` in `crmarques/declarest`).

This bundle declares:

- `declarest.openapi: openapi.yaml` (bundled spec is the source of truth;
  renamed from `openapi.yml` during monorepo migration)
- `declarest.compatibleDeclarest: ">=0.1.0"` (gate enforced at bundle
  resolution against the running CLI/operator binary)
- `declarest.compatibleManagedService.product: rundeck` plus
  `versions: ">=5.0.0 <6.0.0"` (declared today; runtime evaluation against
  a live Rundeck server is deferred until the
  `managedservice.ProductVersionProvider` capability lands)

## Included metadata scope

- `/projects/_` — Rundeck Project APIs
- `/projects/_/jobs/_` — Rundeck Job APIs
- `/projects/_/nodes/_` — Rundeck resource model source APIs
- `/projects/_/secrets/_` — Rundeck key storage APIs, including nested
  descendant paths
- `/projects/_/infra-secrets/_` — Rundeck infrastructure key storage APIs

## Feature highlights

- `selector.descendants` plus `{% raw %}{{/descendantCollectionPath}}{% endraw %}`
  model nested key storage folders under `/projects/_/secrets/_`.
- Relative operation paths keep the key storage metadata concise by
  resolving against the effective remote collection path.
- `resource.externalizedAttributes` in the jobs scope stores command
  scripts in deterministic sidecar files.

## Release

Release is driven by pushing a tag from the monorepo root:

```
bundle/rundeck/v<X.Y.Z>
```

The published tarball is named `rundeck-<X.Y.Z>.tar.gz`. See
[../../docs/release-model.md](../../docs/release-model.md) for the full
flow.

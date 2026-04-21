# keycloak

Keycloak Admin REST API metadata bundle for DeclaREST.

## Bundle manifest

`bundle.yaml` is the canonical bundle manifest. The full manifest shape,
strict-decode rules, and compatibility-gate semantics are owned by
[DeclaREST Bundle Manifest reference](https://crmarques.github.io/declarest/reference/bundle-manifest/)
(`docs/reference/bundle-manifest.md` in `crmarques/declarest`).

This bundle declares:

- `declarest.openapi: openapi.yaml` (bundled spec is the source of truth)
- `declarest.compatibleDeclarest: ">=0.1.0"` (gate enforced at bundle
  resolution against the running CLI/operator binary)
- `declarest.compatibleManagedService.product: keycloak` plus
  `versions: ">=26.0.0 <27.0.0"` (declared today; runtime evaluation
  against a live Keycloak server is deferred until the
  `managedservice.ProductVersionProvider` capability lands)

## Release

Release is driven by pushing a tag from the monorepo root:

```
bundle/keycloak/v<X.Y.Z>
```

The published tarball is named `keycloak-<X.Y.Z>.tar.gz`. See
[../../docs/release-model.md](../../docs/release-model.md) for the full
flow.

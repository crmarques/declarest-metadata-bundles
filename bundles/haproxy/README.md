# haproxy

HAProxy Data Plane API metadata bundle for DeclaREST.

This bundle is shaped for GitOps ownership of HAProxy routing state: sites,
frontends, listener binds, ACLs, backend switching rules, backend pools,
backend servers, and HTTP request rewrite/routing rules.

## Bundle manifest

`bundle.yaml` is the canonical bundle manifest. The full manifest shape,
strict-decode rules, and compatibility-gate semantics are owned by
[DeclaREST Bundle Manifest reference](https://crmarques.github.io/declarest/reference/bundle-manifest/)
(`docs/reference/bundle-manifest.md` in `crmarques/declarest`).

This bundle declares:

- `declarest.openapi: openapi.yaml` (bundled HAProxy Data Plane API Swagger
  2.0 document)
- `declarest.compatibleDeclarest: ">=0.1.0"` (gate enforced at bundle
  resolution against the running CLI/operator binary)
- `declarest.compatibleManagedService.product: haproxy` plus
  `versions: ">=3.0.0 <4.0.0"` (declared today; runtime evaluation against a
  live HAProxy Data Plane API is deferred until the
  `managedservice.ProductVersionProvider` capability lands)

The HAProxy Data Plane API spec uses `basePath: /v3`; configure the
DeclaREST managed service base URL with the `/v3` prefix, for example
`https://haproxy-api.example.com/v3`.

## Included metadata scope

- `/sites/_` — HAProxy simple site resources
- `/frontends/_` — frontend sections
- `/frontends/_/binds/_` — listener binds
- `/frontends/_/acls/_` — frontend ACL lines
- `/frontends/_/backend-switching-rules/_` — `use_backend` routing rules
- `/frontends/_/http-request-rules/_` — frontend `http-request` rules
- `/backends/_` — backend pools
- `/backends/_/servers/_` — upstream servers
- `/backends/_/acls/_` — backend ACL lines
- `/backends/_/http-request-rules/_` — backend `http-request` rules

## Repository shape

```text
sites/www/resource.yaml
frontends/public/resource.yaml
frontends/public/binds/http/resource.yaml
frontends/public/acls/0/resource.yaml
frontends/public/backend-switching-rules/0/resource.yaml
frontends/public/http-request-rules/0/resource.yaml
backends/api/resource.yaml
backends/api/servers/app1/resource.yaml
```

Index-addressed HAProxy child APIs use an `index` field in local resources.
The metadata uses that field for DeclaREST identity and API path rendering,
then removes it from request bodies before HAProxy schema validation and
writes.

Example frontend ACL:

```yaml
index: "0"
acl_name: host_api
criterion: hdr(host)
value: -i api.example.com
```

Example frontend backend switching rule:

```yaml
index: "0"
name: api
cond: if
cond_test: host_api
```

Example backend upstream:

```yaml
name: app1
address: 10.0.0.10
port: 8080
check: enabled
```

## Release

Release is driven by pushing a tag from the monorepo root:

```
bundle/haproxy/v<X.Y.Z>
```

The published tarball is named `haproxy-<X.Y.Z>.tar.gz`. See
[../../docs/release-model.md](../../docs/release-model.md) for the full
flow.

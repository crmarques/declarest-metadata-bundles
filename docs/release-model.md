# Release Model

## Tag format

```
bundle/<name>/v<X.Y.Z>[-prerelease][+build]
```

Examples:

- `bundle/haproxy/v0.1.0`
- `bundle/keycloak/v1.2.3-rc1`
- `bundle/rundeck/v2.0.0+build.42`

Regex (enforced by `tools/common.sh::parse_bundle_tag`):

```
^bundle/([a-z0-9][a-z0-9-]*)/v([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?)$
```

## What the release workflow does

Triggered by `push` of a matching tag (or by `workflow_dispatch` with
explicit `bundle` and `version` inputs).

1. **Parse the tag** → `(name, version)`.
2. **Validate alignment** — `bundles/<name>/bundle.yaml` must exist;
   `manifest.name` must equal `<name>`; `distribution.artifactTemplate`
   (if set) must equal `<name>-{version}.tar.gz`.
3. **Build deterministic tarball** — `tools/bundle-build.sh` stamps the
   version into `bundle.yaml`, copies `README.md`, `metadata/**`, and
   `openapi.yaml` into a stage, then produces
   `<name>-<version>.tar.gz` + `.sha256`.
4. **Upload GitHub Release asset** — tagged `bundle/<name>/v<version>`.
5. **Push OCI artifact** to
   `ghcr.io/<owner>/declarest-metadata-bundles/<name>:<version>` via
   `oras`, with media types:
   - Layer: `application/vnd.declarest.bundle.v1.tar+gzip`
   - Config: `application/vnd.declarest.bundle.config.v1+json`
6. **Moving tags** (only for stable, non-prerelease versions):
   `:latest`, `:stable`, `:<major>`, `:<major>.<minor>`.
7. **Regenerate `index/index.json`** with the new release descriptor,
   publish as `ghcr.io/<owner>/declarest-metadata-bundles/index:latest`,
   and commit back to `main`.

## Moving tags policy

- Stable release (`0.1.0`): updates `:latest`, `:stable`, `:0`, `:0.1`.
- Prerelease (`0.1.0-rc1`): pushes the immutable `:0.1.0-rc1` tag only.
  Moving tags are **not** updated.
- Rollback: `oras tag <repo>@<old-digest> latest` — no rebuild needed.

## Digest pinning (recommended for production)

```yaml
spec:
  source:
    url: https://github.com/<owner>/declarest-metadata-bundles/releases/download/bundle/haproxy/v0.1.0/haproxy-0.1.0.tar.gz
    # or, once CRD supports it:
    # oci:
    #   ref: ghcr.io/<owner>/declarest-metadata-bundles/haproxy
    #   digest: sha256:…
```

## Local dry run

```bash
# 1. validate
tools/validate-bundle.sh haproxy

# 2. build tarball (no publish)
tools/bundle-build.sh haproxy --version 0.1.0 --output-dir out

# 3. verify reproducibility
tools/bundle-build.sh haproxy --version 0.1.0 --output-dir out2
diff out/haproxy-0.1.0.tar.gz.sha256 out2/haproxy-0.1.0.tar.gz.sha256

# 4. push a real release
git tag bundle/haproxy/v0.1.0
git push origin bundle/haproxy/v0.1.0
```

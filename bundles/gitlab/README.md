# gitlab

GitLab REST Admin API metadata bundle for DeclaREST. Targets the
GitLab v4 API (`/api/v4`) for the `18.x` version line (tested against
`18.10`). Configure the context `managedService.http.url` to
`https://<gitlab-host>/api/v4`. Administrative operations (creating
users, setting admin flags, the root-level `/users` list with all
accounts) require a personal access token owned by an administrator;
group- and project-scoped operations need a token with at least the
`Maintainer` role on the owning resource.

## Bundle manifest

`bundle.yaml` is the canonical manifest. The shape, strict-decode
rules, and compatibility-gate semantics are owned by DeclaREST; see
`declarest/agents/reference/metadata-bundle.md`.

This bundle declares:

- `declarest.openapi: openapi.yaml` (the official, intentionally
  partial GitLab OpenAPI 3.0.1 document from
  `gitlab-org/gitlab:v18.10.3-ee:doc/api/openapi/openapi.yaml`).
- `declarest.compatibleDeclarest: ">=0.1.0"`.
- `declarest.compatibleManagedService.product: gitlab` plus
  `versions: ">=18.10.0 <19.0.0"`. Runtime evaluation against a live
  GitLab server is deferred until the
  `managedservice.ProductVersionProvider` capability lands.

## Logical paths

| Logical path | GitLab API | Notes |
|---|---|---|
| `/users/{id}` | `POST /users`, `GET /users/{id}`, `PUT /users/{id}`, `DELETE /users/{id}`, `GET /users` | Admin token required. Writes accept numeric user id. `password` and `reset_password` are secret-masked. |
| `/groups/{id}` | `POST /groups`, `GET /groups/{id}`, `PUT /groups/{id}`, `DELETE /groups/{id}`, `GET /groups` | `id` is the numeric group id. Subgroups are addressable under the same collection via their own id and `parent_id` in the payload. |
| `/groups/{group_id}/members/{user_id}` | `POST /groups/{id}/members`, `GET /groups/{id}/members/{user_id}`, `PUT /groups/{id}/members/{user_id}`, `DELETE /groups/{id}/members/{user_id}`, `GET /groups/{id}/members` | Assigns a user to a group with an `access_level`. |
| `/projects/{id}` | `POST /projects`, `GET /projects/{id}`, `PUT /projects/{id}`, `DELETE /projects/{id}`, `GET /projects` | Numeric project id. Create under a group by setting `namespace_id` in the payload. |
| `/projects/{project_id}/members/{user_id}` | `POST /projects/{id}/members`, `GET /projects/{id}/members/{user_id}`, `PUT /projects/{id}/members/{user_id}`, `DELETE /projects/{id}/members/{user_id}`, `GET /projects/{id}/members` | Assigns a user to a project with an `access_level`. |

## Known limitations

- GitLab addresses groups, projects, users, and members by numeric id.
  The logical-path segment is therefore that numeric id (`/groups/42`,
  `/projects/101/members/7`); a future iteration may add a
  path-with-namespace view once declarest supports URL-encoded path
  segments natively.
- GitLab subgroups are modelled flat under `/groups/_`; set
  `parent_id` in the group payload to express the hierarchy. Listing
  subgroups through `GET /groups/{id}/subgroups` is not modelled
  separately because the subgroup object is returned at
  `/groups/{sub_id}` with full fidelity.
- User-owned projects are not modelled explicitly; the `/projects/_`
  path covers them through `namespace_id`.
- Application/instance settings (`/application/settings`,
  `/application/appearance`) are not modelled because they are
  singletons without a collection endpoint; declare them via a
  dedicated overlay if needed.
- The bundled OpenAPI document is the official GitLab spec, which is
  intentionally partial. Declarative operations above fall back to
  metadata defaults where the OpenAPI lacks the endpoint; request
  validation is best-effort for endpoints not present in the spec.

## Release

Release is driven by pushing a tag from the monorepo root:

```
bundle/gitlab/v<X.Y.Z>
```

The published tarball is named `gitlab-<X.Y.Z>.tar.gz`. See
[../../docs/release-model.md](../../docs/release-model.md) for the
full flow.

# gitea

Gitea Admin REST API metadata bundle for DeclaREST. Targets the Gitea
`v1` API (`/api/v1`) for version line `1.26.x`. Configure the context
`managedService.http.url` to `https://<gitea-host>/api/v1` and use an
API token with `admin` scope for the admin-only endpoints (users and
system hooks) and an org owner token for the org-scoped resources.

## Bundle manifest

`bundle.yaml` is the canonical manifest. The shape, strict-decode
rules, and compatibility-gate semantics are owned by DeclaREST; see
`declarest/agents/reference/metadata-bundle.md`.

This bundle declares:

- `declarest.openapi: openapi.yaml` (the bundled Swagger 2.0 spec
  stamped to Gitea `1.26.0`; regenerated from
  `templates/swagger/v1_json.tmpl` on the `release/v1.26` branch).
- `declarest.compatibleDeclarest: ">=0.1.0"`.
- `declarest.compatibleManagedService.product: gitea` plus
  `versions: ">=1.26.0 <1.27.0"`. Runtime evaluation against a live
  Gitea server is deferred until the
  `managedservice.ProductVersionProvider` capability lands.

## Logical paths

| Logical path | Gitea API | Notes |
|---|---|---|
| `/users/{login}` | `POST /admin/users`, `GET /users/{login}`, `PATCH /admin/users/{login}`, `DELETE /admin/users/{login}`, `GET /admin/users` | Requires an admin token. `password` is secret-masked. |
| `/orgs/{org}` | `POST /orgs`, `GET /orgs/{org}`, `PATCH /orgs/{org}`, `DELETE /orgs/{org}`, `GET /orgs` | `org` is the Gitea organization `username`. |
| `/orgs/{org}/teams/{team_id}` | `POST /orgs/{org}/teams`, `GET /teams/{id}`, `PATCH /teams/{id}`, `DELETE /teams/{id}`, `GET /orgs/{org}/teams` | Gitea addresses teams by numeric id; the logical-path segment is the team `id`. |
| `/orgs/{org}/teams/{team_id}/members/{login}` | `PUT /teams/{id}/members/{username}`, `GET /teams/{id}/members`, `DELETE /teams/{id}/members/{username}` | Assigns a user to a team. |
| `/orgs/{org}/teams/{team_id}/repos/{repo}` | `PUT /teams/{id}/repos/{org}/{repo}`, `GET /teams/{id}/repos`, `DELETE /teams/{id}/repos/{org}/{repo}` | Grants a team access to a repository in the same org. |
| `/orgs/{org}/repos/{repo}` | `POST /orgs/{org}/repos`, `GET /repos/{org}/{repo}`, `PATCH /repos/{org}/{repo}`, `DELETE /repos/{org}/{repo}`, `GET /orgs/{org}/repos` | Creates and manages repositories owned by the org. |
| `/orgs/{org}/repos/{repo}/collaborators/{login}` | `PUT /repos/{org}/{repo}/collaborators/{login}`, `GET /repos/{org}/{repo}/collaborators`, `DELETE /repos/{org}/{repo}/collaborators/{login}` | Grants direct per-user access on a repo. |
| `/admin/hooks/{id}` | `POST /admin/hooks`, `GET /admin/hooks/{id}`, `PATCH /admin/hooks/{id}`, `DELETE /admin/hooks/{id}`, `GET /admin/hooks` | Instance-wide (system) webhooks. |

## Known limitations

- Gitea uses the team numeric `id` in `/teams/{id}` endpoints and has
  no path variant that accepts the team slug, so the team logical-path
  segment is the numeric id (e.g. `orgs/acme/teams/42`). Create the
  team first, read the assigned id, then rename the local directory to
  match if you want stable local paths.
- User-owned repositories (`POST /user/repos`) are not modelled; the
  bundle focuses on the org-owned path which is the common
  declarative-management case.
- Team-member and collaborator add/update both use `PUT` and overwrite
  the previous permission; the same Gitea endpoint backs `create` and
  `update`.

## Release

Release is driven by pushing a tag from the monorepo root:

```
bundle/gitea/v<X.Y.Z>
```

The published tarball is named `gitea-<X.Y.Z>.tar.gz`. See
[../../docs/release-model.md](../../docs/release-model.md) for the
full flow.

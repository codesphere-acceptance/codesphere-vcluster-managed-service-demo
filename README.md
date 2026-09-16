# Codesphere vCluster + Managed Service Demo

A deliberately small demonstration of deploying a **Helm-chart-based, Kubernetes-native
application into a vCluster booked as a Codesphere managed service**, reachable
under a **custom domain over TLS**.

Everything is declared in one place and deployed reproducibly: sync the
landscape, run it, and the app answers on your custom domain.

## What's here

| Path | Purpose |
| --- | --- |
| `ci.yml` | The whole landscape: the vCluster managed service, the Helm deploy step, and the headless route to the custom domain. |
| `chart/` | The Helm chart — a Kubernetes-native app (`nginx-unprivileged` serving one page). Editable straight from the browser IDE. |
| `deploy/deploy.sh` | One reproducible `helm upgrade --install` into the vCluster. |
| `tools/` | `doctor.sh` (toolchain + API check) and `providers.sh` (query the managed-service catalog). |
| `.mise.toml`, `.envrc` | Pinned local toolchain (`helm`, `kubectl`, `jq`, `yq`, `gh`, `direnv`) and auto-loading of `.env.local`. |

## How it works

```
prepare:  helm upgrade --install  ->  Deployment + Service in the vCluster
run:      demo-vcluster (managed service)  +  demo-app (headless route)

Browser ──HTTPS──▶ Codesphere edge (TLS) ──▶ headless route (ci.yml)
        ──▶ demo-app Service in the vCluster ──▶ nginx pod
```

- The **vCluster** is a team-level managed service (`provider: virtual-k8s`).
  Booking it auto-mounts its kubeconfig into the landscape pods, so `helm` and
  `kubectl` (both in the base image) deploy into it with no extra tooling.
- The **Helm chart** is deployed by `deploy/deploy.sh` — the app is imported
  from its manifests and rolled out reproducibly, not hand-assembled.
- The **headless route** in `ci.yml` forwards the custom domain to the app's
  in-vCluster Service. Codesphere syncs that Service to the host cluster at a
  predictable DNS name and terminates TLS at the edge:

  ```
  http://demo-app-x-demo-x-k8s.rg-${{ team.id }}.svc.cluster.local:80
  ```

  The service name (`demo-app`) and namespace (`demo`) come from
  `RELEASE`/`NAMESPACE` in `deploy/deploy.sh`; keep the three in sync.

## Local setup

The toolchain is pinned with [mise](https://mise.jdx.dev/) and auto-activated by
[direnv](https://direnv.net/):

```bash
cp .env.example .env.local   # add your CS_TOKEN (Account Settings > API Keys)
direnv allow                 # trust .envrc: activates mise + loads .env.local
mise install                 # fetch helm, kubectl, jq, yq, gh at pinned versions
mise run doctor              # verify the toolchain + Codesphere API access
```

`.env.local` (gitignored) holds the Public API credentials used by the `cs` CLI
and `tools/*.sh`. Defaults target the demo instance (`csa.codesphere-demo.com`,
Team A1); only `CS_TOKEN` is required.

- `mise run lint` — `helm lint` + render the chart.
- `mise run providers [name]` — inspect the managed-service catalog. This is how
  the `virtual-k8s` plan in `ci.yml` was resolved; re-run it to refresh the
  values for your instance.
- `cs list workspaces` / `cs create workspace` — the `cs` CLI reads `CS_API` /
  `CS_TEAM_ID` from `.env.local` to manage the team's workspaces.

## Deploy it

1. **Book the vCluster** as a managed service at team level. It is declared in
   `ci.yml` (`demo-vcluster`) with the verified `virtual-k8s` "Custom" plan
   (resolve/refresh the quota parameters any time with `mise run providers
   virtual-k8s`).
2. **Add your custom domain** in the workspace UI and point it at the landscape.
3. **Open the workspace** — the Helm chart under `chart/` is visible and
   editable in the browser IDE.
4. **Sync the landscape and run all.** `prepare` deploys the chart into the
   vCluster; `run` brings up the managed service and the headless route.
5. **Open the custom domain** in a browser — the Helm-imported app responds over
   TLS.

## Change the app

Edit `chart/values.yaml` (`page:` block) for the page text, or the templates in
`chart/templates/` for anything structural, then re-sync. To use a different
container image, change `image.repository` / `image.tag` — if it listens on a
port other than `8080`, update `service.targetPort` and the deployment
`containerPort` to match.

## Validate locally

```bash
mise run lint    # helm lint + render the chart (or: helm lint chart)
```

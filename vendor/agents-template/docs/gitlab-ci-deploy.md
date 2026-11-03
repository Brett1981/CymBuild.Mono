# CI and deployment conventions

The shape SOCOTEC UK apps under `<gitlab-group>/*` use to build and deploy to the
Kubernetes clusters. Mirror this when adding CI to a new project.

## Runners

Pin every job to the internal runners — **shared runners are disabled** on these projects:

```yaml
tags: [internal]
```

A job with no tags will sit pending forever with no obvious error.

## Build

- `docker:24` with the `docker:24-dind` service.
- Push to `$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA` **and** `:latest`.
- Smoke-test the built image before pushing it.
- Build and check on merge requests; **deploy only on push to `main`**.

## Deploy

Use the GitLab Kubernetes Agent contexts — one per cluster:

```
<gitlab-group>/infra/k8s-cluster-config:dev
<gitlab-group>/infra/k8s-cluster-config:uat
<gitlab-group>/infra/k8s-cluster-config:prod
```

The agent lives in the `k8s-cluster-config` project and its `ci_access` is
group-wide, so any project in the group can use these contexts without its own agent.

The deploy job installs `kubectl`, then:

```bash
kubectl config use-context "$KUBE_CONTEXT"
envsubst < k8.yaml | kubectl apply -f -
kubectl rollout status deployment/<name> -n "$NAMESPACE"
```

## Manifests

- The file is **`k8.yaml`** — no `s`. Matching the existing name matters for the
  `envsubst` step above and for anyone grepping the group.
- Templated with `${NAMESPACE}`, `${REPLICAS}`, `${INGRESS_HOSTNAME}`, `${K8S_IMAGE_TO_DEPLOY}`.
- `nodeSelector: {node-role.kubernetes.io/worker: worker}`
- Ingress class `nginx`, host `<app>-dev.socotec.co.uk`.

## Registry pull secret — the one that bites

Namespaces hold a `gitlab-registry` docker-registry secret built from a
**`read_registry` deploy token** (e.g. `gitlab+deploy-token-1234`), *not* the CI
job token. Reference it with `imagePullSecrets: [gitlab-registry]`.

> **Deploy tokens are scoped to the issuing project.** A namespace seeded with
> another project's token fails as `ImagePullBackOff` with
> `insufficient_scope: authorization failed` — which reads like a missing image
> rather than a wrong credential, and sends people hunting in the wrong place.

**Prefer having the deploy job build the secret itself** from a project deploy
token named exactly `gitlab-deploy-token` with scope `read_registry`. That exact
name is what makes GitLab expose `$CI_DEPLOY_USER` / `$CI_DEPLOY_PASSWORD` to CI,
and it means a rebuilt namespace self-heals instead of needing a manual reseed.

Creating one via the API works from CI:

```bash
glab api --method POST -H "Content-Type: application/json" \
  "projects/<url-encoded-path>/deploy_tokens" --input -
```

Setting **masked CI variables** still has to be done by a human in the UI.

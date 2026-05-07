# A03 - Helm Chart

> Namespace: `g<n>-helm` (per rotation table)

## Goal

Take a working set of plain Kubernetes manifests and **package them into a Helm chart** with values, then practice the upgrade/rollback lifecycle.

## Architecture

```
   Internet ──► Ingress ──► /g<n>      ──► svc-frontend ──► Deployment frontend (nginx:1.25)
                        └─► /g<n>/api ──► svc-backend  ──► Deployment backend  (podinfo)
```

`k8s/` contains the raw manifests **as a starter** — do NOT `kubectl apply` them. Your job is to convert them into a Helm chart and install via `helm install`.

Images (public): `nginx:1.25` (frontend), `stefanprodan/podinfo:6.5.0` (backend, returns JSON with hostname + version).

## Step 1 — pack the manifests into a Helm chart

Convert the 5 raw YAMLs in `k8s/` into a chart:

```
fullstack-app/
├── Chart.yaml
├── values.yaml                 # parameterize what changes per environment
├── values-prod.yaml            # override for prod (replicas, image tag)
└── templates/
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── backend-deployment.yaml
    ├── backend-service.yaml
    └── ingress.yaml
```

**What to parameterize via `values.yaml`** (at minimum):
- `pathPrefix` — `/g0` in the raw ingress, must become `/g<n>` per group
- `frontend.replicas`, `backend.replicas`
- `backend.tag` — `6.5.0` should be configurable so we can upgrade later
- `frontend.image`, `backend.image`

Hint: `helm create fullstack-app` gives you a scaffold; replace the auto-generated templates with your converted ones.

Validate:
```bash
helm lint ./fullstack-app
helm template fs ./fullstack-app --set pathPrefix=/g<n> | head -40   # preview rendered YAML
helm install fs ./fullstack-app --set pathPrefix=/g<n> -n <ns>
kubectl rollout status deploy/fs-frontend deploy/fs-backend -n <ns>

HOST=$(kubectl get ing -n <ns> -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
curl http://$HOST/g<n>            # → nginx welcome
curl http://$HOST/g<n>/api        # → JSON with "version": "6.5.0"
```

## Step 2 — challenge: upgrade then rollback

Use `values-prod.yaml` to bump podinfo from **6.5.0 → 6.7.0** and increase replicas, then roll back.

```bash
# UPGRADE — should see version change in JSON
helm upgrade fs ./fullstack-app -f ./fullstack-app/values-prod.yaml --set pathPrefix=/g<n> -n <ns>
kubectl rollout status deploy/fs-backend -n <ns>
curl http://$HOST/g<n>/api/version    # → "version": "6.7.0"

# HISTORY — should show 2 revisions
helm history fs -n <ns>

# ROLLBACK to revision 1
helm rollback fs 1 -n <ns>
curl http://$HOST/g<n>/api/version    # → "version": "6.5.0" again

helm history fs -n <ns>               # → 3 revisions, latest one is "Rollback to 1"
```

In your demo, answer:
- What does Helm store between revisions to make rollback possible?
- What's the difference between `helm upgrade -f values-prod.yaml` and `helm upgrade --set ...`?
- If you delete the release with `helm uninstall`, do the PVCs (if any) go with it?

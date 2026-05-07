# A01 - Web App with Ingress

> Namespace: `g<n>-web` (where `<n>` is your group number per the rotation table)

## Goal

Deploy an Nginx web app and expose it via **Ingress** at a group-prefixed path. Then add a second backend behind the same Ingress.

## Architecture

```
   Internet ──► AWS NLB ──► Nginx Ingress
                                 │
                                 ├─► /g<n>      ──► svc-web   ──► Deployment web   (nginx, 2 pods)
                                 └─► /g<n>/user ──► svc-user  ──► Deployment user  (nginx, 2 pods)
```

All 3 groups share the same NLB hostname. Each group's Ingress is isolated by path prefix `/g<n>`. Hint: use `nginx.ingress.kubernetes.io/rewrite-target: /$2` with a capture group so backend pods see `/` instead of the group/sub-path prefix.

`k8s/deployment.yaml` is provided as a starter for Step 1 — you write the rest.

## Step 1 — main page

Deploy `web` and route `/g<n>` to it.

```
k8s/
├── deployment.yaml      # PROVIDED — nginx, 2 replicas, mounts configmap as /usr/share/nginx/html
├── configmap.yaml       # custom index.html — e.g. "Hello from group <n>"
├── service.yaml         # ClusterIP, port 80, selector app=web
└── ingress.yaml         # path /g<n> → svc-web
```

Validate:
```bash
kubectl apply -f k8s/ -n <ns>
HOST=$(kubectl get ing web-ingress -n <ns> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$HOST/g<n>           # → "Hello from group <n>"
```

## Step 2 — challenge: add a `/user` route

Add a second backend served at `/g<n>/user`. Reuse the same Ingress object — just add another rule.

```
k8s/
├── deployment-user.yaml    # nginx, 2 replicas, mounts configmap-user
├── configmap-user.yaml     # different HTML — e.g. "User page — group <n>"
├── service-user.yaml       # ClusterIP, port 80, selector app=user
└── ingress.yaml            # UPDATED — adds /g<n>/user → svc-user
```

Validate:
```bash
curl http://$HOST/g<n>           # still → "Hello from group <n>"
curl http://$HOST/g<n>/user      # → "User page — group <n>"
```

**Hint on path matching:** when both paths share a prefix, list the more specific one first. With Nginx Ingress + `rewrite-target: /$2`, use path patterns like `/g<n>/user(/|$)(.*)` and `/g<n>(/|$)(.*)`, both with `pathType: ImplementationSpecific`.

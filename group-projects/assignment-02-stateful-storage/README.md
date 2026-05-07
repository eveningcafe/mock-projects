# A02 - Stateful App with Storage

> Namespace: `g<n>-storage` (per rotation table)

## Goal

Deploy a **Redis StatefulSet** with persistent EBS storage and prove data survives a pod kill.

## Architecture

```
   StatefulSet: redis (3 replicas)
   ┌──────────┐  ┌──────────┐  ┌──────────┐
   │ redis-0  │  │ redis-1  │  │ redis-2  │
   └────┬─────┘  └────┬─────┘  └────┬─────┘
        ▼             ▼             ▼
       PVC-0         PVC-1         PVC-2     (each 2Gi via StorageClass ebs-gp3)

   Headless Service: redis (clusterIP: None, port 6379)
   ConfigMap (redis.conf) + Secret (password) mounted into pods
```

Image: `redis:7-alpine` (public). StorageClass `ebs-gp3` already exists.

`k8s/statefulset.yaml` is provided as a starter — you write the rest.

## Deliverables

```
k8s/
├── statefulset.yaml        # PROVIDED — 3 replicas, volumeClaimTemplates → ebs-gp3, mounts configmap + secret
├── configmap.yaml          # redis.conf (e.g. maxmemory 100mb, appendonly yes)
├── secret.yaml             # Redis password (stringData.password = ...)
└── service-headless.yaml   # name=redis, clusterIP: None, port 6379, selector app=redis
```

## Validation

```bash
kubectl apply -f k8s/ -n <ns>
kubectl rollout status sts/redis -n <ns>
kubectl get sts,pod,svc,pvc -n <ns>

# Headless DNS — each pod gets its own DNS name
kubectl exec redis-0 -n <ns> -- nslookup redis-1.redis.<ns>.svc.cluster.local

# Persistence test — must return "world" after pod kill
PWD=$(kubectl get secret redis-secret -n <ns> -o jsonpath='{.data.password}' | base64 -d)
kubectl exec redis-0 -n <ns> -- redis-cli -a "$PWD" --no-auth-warning SET hello world
kubectl delete pod redis-0 -n <ns>
kubectl wait --for=condition=Ready pod/redis-0 -n <ns> --timeout=120s
kubectl exec redis-0 -n <ns> -- redis-cli -a "$PWD" --no-auth-warning GET hello   # → "world"
```

In your demo, explain in 3 bullets each: **Deployment vs StatefulSet** (when to use which).

## Step 2 — challenge: online PVC expansion

You need more space. Grow each Redis volume from **2Gi to 5Gi** *without restarting the pods*. No new manifests — just patches.

1. First, try the obvious: edit the StatefulSet's `volumeClaimTemplates` to `5Gi`. Observe the error and note **why** it fails.
2. Patch each PVC directly:
   ```bash
   for i in 0 1 2; do
     kubectl patch pvc data-redis-$i -n <ns> --type=merge \
       -p='{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
   done
   ```
3. Wait ~30–60s for EBS to resize and the filesystem to grow online.
4. Verify:
   ```bash
   kubectl get pvc -n <ns>                                # CAPACITY 5Gi
   kubectl exec redis-0 -n <ns> -- df -h /data | tail -1  # filesystem ~4.9G
   ```

In your demo, answer:
- Why did editing the StatefulSet fail?
- Which property of the StorageClass `ebs-gp3` made the PVC-level expansion possible?
- Why didn't the pods need to restart?

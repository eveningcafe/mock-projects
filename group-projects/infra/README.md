# Infra - Shared EKS Cluster

Terraform that provisions the EKS cluster used by all 3 group assignments.

## What it creates

- EKS cluster `group-projects-eks` in `ap-southeast-1`
- Managed nodegroup, **3x `t3.medium`** (Spot), Kubernetes 1.35
- IAM roles for cluster + nodes
- OIDC provider (for IRSA)
- **EBS CSI driver addon** (used by A02 storage)

Nginx Ingress Controller is **not** in Terraform — install via Helm after cluster is up (see `bootstrap.sh` below).

## Before applying

Edit `variables.tf` (or pass via `terraform.tfvars`):

- `vpc_id` — your VPC ID (current default is from another account, **must change**)
- `subnet_ids` — 2+ subnets in different AZs in that VPC
- `cluster_name` — optionally rename per class (e.g. `do2601-group-projects-eks`)

```bash
cp terraform.tfvars.example terraform.tfvars   # if you create one
# edit terraform.tfvars
```

## Apply

```bash
terraform init
terraform plan
terraform apply

# After ~10-15 min, configure kubectl
aws eks update-kubeconfig --region ap-southeast-1 --name group-projects-eks
kubectl get nodes
```

## Bootstrap (after cluster is ready)

```bash
# 1. Nginx Ingress Controller (used by A01, A03)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace

# 2. StorageClass ebs-gp3 (used by A02) — apply the manifest from A02
kubectl apply -f ../assignment-02-stateful-storage/k8s/storageclass.yaml

# 3. Pre-create 9 namespaces (3 groups × 3 assignments)
for g in g1 g2 g3; do
  for a in web storage helm; do
    kubectl create ns $g-$a
  done
done
```

## Destroy (after final session)

```bash
# Clean k8s resources first so AWS LBs/EBS volumes are released
kubectl delete ns g1-web g1-storage g1-helm g2-web g2-storage g2-helm g3-web g3-storage g3-helm
kubectl delete ns ingress-nginx

terraform destroy
```

## Estimated cost

~$84/month if left running 24/7 with Spot nodes. For class-only usage (a few hours), keep nodegroup at desired=0 between sessions or run `terraform destroy`.

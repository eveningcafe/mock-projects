# Group Projects - Kubernetes on EKS

## Overview

3 group projects covering Kubernetes topics from week 13-16. **Single 2-hour session**, 3 groups rotate through all 3 assignments (20 min each, AI-assisted).

## Groups & Assignments

- **A01** - [Web App + Ingress](./assignment-01-web-ingress/)
- **A02** - [Stateful App + Storage](./assignment-02-stateful-storage/)
- **A03** - [Helm Chart](./assignment-03-helm-fullstack/)


Each group has n students. Within each round, students may split sub-tasks or work together with AI.

## Master Rotation Table

| Round | Time | Group 1 | Group 2 | Group 3 |
|-------|------|---------|---------|---------|
| Brief | 0:00 – 0:10 | Mentor briefs assignments | | |
| **R1** | 0:10 – 0:30 | A01 → ns `g1-web` | A02 → ns `g2-storage` | A03 → ns `g3-helm` |
| **R2** | 0:30 – 0:50 | A02 → ns `g1-storage` | A03 → ns `g2-helm` | A01 → ns `g3-web` |
| **R3** | 0:50 – 1:10 | A03 → ns `g1-helm` | A01 → ns `g2-web` | A02 → ns `g3-storage` |
| Demos | 1:10 – 1:50 | G1 demos (13 min) | G2 demos (13 min) | G3 demos (13 min) |
| Cleanup | 1:50 – 2:00 | Mentor deletes all namespaces | | |

After R3, each group has 3 namespaces, one per assignment.

## Mentor pre-class setup

Cluster is provisioned via Terraform — see [`infra/`](./infra/) for the full setup (EKS + nodegroup + EBS CSI driver). After `terraform apply`, run the bootstrap commands documented in `infra/README.md` to install Nginx Ingress, the StorageClass, and the 9 group namespaces.

## Cluster access

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name group-projects-eks
kubectl get nodes   # should show 3 nodes
```

**Shared NLB hostname** (for A01 / A03 ingress tests):

```
a82dd0afe962841cca55b2ba8534a30b-2090911537.ap-southeast-1.elb.amazonaws.com
```

All 3 groups' Ingress objects resolve to this same NLB — that's why each group must use a unique path prefix (`/g1`, `/g2`, `/g3`).

## Shared rules

- Region: `ap-southeast-1`
- All public/pre-built images (no Docker build during class)
- AI tools (Claude / Copilot / ChatGPT) **encouraged** — focus is on understanding, not memorizing YAML

## Deliverables (per group)

1. Manifests committed to group folder (`group-projects/group-<n>/`)
2. Each member commits at least one resource type
3. Demo: each group shows all 3 namespaces working

## Grading (100pts per group)

| Item | Points |
|------|--------|
| All 3 assignments completed in 3 rounds | 60 |
| Demo quality + ability to explain (not just AI copy-paste) | 25 |
| Cleanup (no leftover resources) | 15 |

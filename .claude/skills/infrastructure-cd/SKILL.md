# Infrastructure CD Workflow

## Overview

This repository uses **automated CD for both Terraform infrastructure and Helm/ArgoCD runner configurations**. Changes merged to `main` are automatically applied - no manual intervention required.

## Deployment Pipelines

### 1. Terraform Infrastructure (Rackspace Spot)

**Workflow:** `.github/workflows/terraform.yaml`

**Triggers:**
- Push to `main` with changes in `terraform/**`
- Pull requests (plan only, no apply)
- Manual dispatch via workflow_dispatch

**What it deploys:**
- Rackspace Spot Cloudspace (managed Kubernetes)
- Node pool configuration (bid price, scaling)
- ArgoCD installation

**Key files:**
| File | Purpose |
|------|---------|
| `terraform/prod.tfvars` | Production configuration (bid_price, min_nodes, max_nodes) |
| `terraform/variables.tf` | Variable definitions and defaults |
| `terraform/modules/nodepool/` | Node pool resource definition |

**Auto-apply behavior:**
```
PR opened → terraform plan (comment on PR)
PR merged to main → terraform apply (automatic)
```

### 2. Runner Configuration (ArgoCD/Helm)

**Managed by:** ArgoCD (deployed via Terraform)

**Triggers:**
- Push to `main` with changes in `values/**` or `charts/**`
- ArgoCD syncs automatically (polling or webhook)

**What it deploys:**
- GitHub Actions Runner Scale Sets
- Runner configurations per repository

**Key files:**
| File | Purpose |
|------|---------|
| `values/repositories.yaml` | Per-repo runner config (minRunners, maxRunners, labels) |
| `values/base-config.yaml` | Default runner settings |
| `charts/github-actions-runners/` | Helm chart for runners |

**Auto-sync behavior:**
```
PR merged to main → ArgoCD detects change → Helm upgrade (automatic)
```

## Configuration Reference

### Bid Price (Spot Instance Priority)

Location: `terraform/prod.tfvars`

```hcl
bid_price = 0.28  # USD per hour
```

**Guidelines:**
- Higher bid = lower preemption risk
- You only pay market price (not your bid)
- Current Cloud Run equivalent: ~$0.48/hr
- Recommended: 50-70% of on-demand for balance

### Runner Scaling

Location: `values/repositories.yaml`

```yaml
repositories:
  - name: project-beta-api
    scaling:
      minRunners: 1  # Keep warm (0 = scale-to-zero)
      maxRunners: 20
```

**Guidelines:**
- `minRunners: 0` = cold start delays (2-5 min)
- `minRunners: 1+` = pre-warmed runners (5-10 sec start)
- Active repos should have `minRunners: 1` minimum

### Node Pool Scaling

Location: `terraform/prod.tfvars`

```hcl
min_nodes = 1   # Rackspace Spot minimum (cannot be 0)
max_nodes = 10  # Scale ceiling
```

## Common Operations

### Increase Bid Price

1. Edit `terraform/prod.tfvars`:
   ```hcl
   bid_price = 0.30  # New price
   ```
2. Create PR, get approval
3. Merge to main → **auto-applied by CD**

### Increase minRunners

1. Edit `values/repositories.yaml`:
   ```yaml
   scaling:
     minRunners: 2  # New value
   ```
2. Create PR, get approval
3. Merge to main → **auto-synced by ArgoCD**

### Manual Terraform Apply (Emergency Only)

```bash
# Get kubeconfig
export TF_HTTP_PASSWORD="<github-token>"
cd terraform
terraform init
terraform apply -var-file=prod.tfvars \
  -var="rackspace_spot_token=$RACKSPACE_SPOT_TOKEN" \
  -var="github_token=$GITHUB_TOKEN"
```

## Monitoring Deployments

### Check Terraform Workflow

```bash
gh run list --workflow=terraform.yaml --limit 5
gh run view <run-id> --log
```

### Check ArgoCD Sync Status

```bash
# Get kubeconfig first
kubectl get applications -n argocd
kubectl describe application arc-runners -n argocd
```

## Troubleshooting

### Terraform Apply Failed

1. Check workflow logs: `gh run view <run-id> --log`
2. Common issues:
   - Missing secrets (RACKSPACE_SPOT_API_TOKEN, INFRA_GH_TOKEN)
   - State lock (another apply in progress)
   - Invalid configuration

### ArgoCD Not Syncing

1. Check ArgoCD application status
2. Verify webhook or polling is working
3. Check for Helm chart errors in ArgoCD UI

### Runners Not Scaling

1. Verify `values/repositories.yaml` changes merged
2. Check ArgoCD sync status
3. Verify runner scale set in Kubernetes:
   ```bash
   kubectl get autoscalingrunnerset -A
   ```

---
name: arc-runner-troubleshooting
description: Troubleshoot ARC (Actions Runner Controller) runners on Rackspace Spot Kubernetes. Diagnose stuck jobs, scaling issues, and cluster access. Activates on "runner", "ARC", "stuck job", "queued", "GitHub Actions", or "CI stuck".
allowed-tools: Read, Grep, Glob, Bash
---

# ARC Runner Troubleshooting Guide

## Overview

project-beta uses self-hosted GitHub Actions runners deployed via ARC (Actions Runner Controller) on Rackspace Spot Kubernetes. This guide covers common issues and troubleshooting procedures.

## Architecture

### Runner Infrastructure

```
GitHub Actions
      ↓
ARC (Actions Runner Controller)    ← Watches for queued jobs
      ↓
AutoscalingRunnerSet              ← Scales runner pods 0→N
      ↓
Runner Pods                        ← Execute GitHub Actions jobs
      ↓
Rackspace Spot Kubernetes         ← Underlying infrastructure
```

### Runner Pools

| Pool | Target | Namespace | Repository |
|------|--------|-----------|------------|
| `arc-beta-runners` | Org-level | `arc-beta-runners-new` | project-beta, project-beta-api |
| `arc-frontend-runners` | Frontend | `arc-frontend-runners` | project-beta-frontend |
| `arc-api-runners-v2` | API-specific | `arc-api-runners` | project-beta-api |

### Key Configuration Files

```
matchpoint-github-runners-helm/
├── examples/
│   ├── beta-runners-values.yaml      ← DEPLOYED Helm values (org-level)
│   └── frontend-runners-values.yaml  ← DEPLOYED Helm values (frontend)
├── values/
│   └── repositories.yaml             ← Documentation (NOT deployed)
├── charts/
│   └── github-actions-runners/       ← Helm chart
└── terraform/
    └── modules/                      ← Infrastructure as Code
```

## Common Issues

### 1. Runners with Empty Labels (CRITICAL - P0)

**Primary Root Cause:** ArgoCD release name ≠ runnerScaleSetName (mismatch causes tracking failure)

**Secondary Root Cause:** `ACTIONS_RUNNER_LABELS` environment variable **does not work with ARC**

**CRITICAL: ArgoCD/Helm Alignment Issue (Dec 12, 2025 Discovery)**

If the ArgoCD helm release name doesn't match `runnerScaleSetName`:
1. ArgoCD tracks resources under the old release name
2. New AutoscalingRunnerSet created with different name
3. Old ARS may not be pruned, resulting in stale runners
4. Stale runners have broken registration → empty labels

**Fix:**
```yaml
# argocd/apps-live/arc-runners.yaml
helm:
  releaseName: arc-beta-runners  # MUST match runnerScaleSetName!

# examples/runners-values.yaml
gha-runner-scale-set:
  runnerScaleSetName: "arc-beta-runners"  # MUST match releaseName!
```

**Diagnosis tip:** Check runner pod names:
- `arc-runners-*-runner-*` → OLD ARS still active (problem!)
- `arc-beta-runners-*-runner-*` → NEW ARS deployed (correct!)

**Symptoms:**
- Runners show empty labels `[]` in GitHub
- Runners show `os: "unknown"` in GitHub API
- ALL jobs stuck in "queued" state indefinitely
- Runners appear online but never pick up jobs

**Diagnosis:**
```bash
# Check runner labels via GitHub API
gh api /orgs/Matchpoint-AI/actions/runners --jq '.runners[] | {name, status, labels: [.labels[].name], os}'

# Bad output (empty labels):
{
  "name": "arc-runners-w74pg-runner-2xppt",
  "status": "online",
  "labels": [],
  "os": "unknown"
}

# Good output (proper labels):
{
  "name": "arc-beta-runners-xxxxx-runner-yyyyy",
  "status": "online",
  "labels": ["arc-beta-runners", "self-hosted", "Linux", "X64"],
  "os": "Linux"
}
```

**Root Cause Explanation:**

Per [GitHub's official documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/using-actions-runner-controller-runners-in-a-workflow):

> "You cannot use additional labels to target runners created by ARC. You can only use the installation name of the runner scale set that you specified during the installation or by defining the value of the `runnerScaleSetName` field in your values.yaml file."

**How ARC Labels Work:**
1. ARC uses ONLY the `runnerScaleSetName` as the GitHub label
2. Cannot add custom labels via `ACTIONS_RUNNER_LABELS` environment variable
3. ARC automatically adds `self-hosted`, OS, and architecture labels
4. Cannot have multiple custom labels on a single scale set

**Fix:**
```yaml
# examples/runners-values.yaml or frontend-runners-values.yaml
gha-runner-scale-set:
  runnerScaleSetName: "arc-beta-runners"  # This becomes the GitHub label

  template:
    spec:
      containers:
      - name: runner
        env:
        # DO NOT SET ACTIONS_RUNNER_LABELS - it's ignored by ARC!
        # Only runnerScaleSetName matters
        - name: RUNNER_NAME_PREFIX
          value: "arc-beta"
```

**Deployment Steps:**
1. Ensure `runnerScaleSetName` matches workflow `runs-on:` labels
2. Remove any `ACTIONS_RUNNER_LABELS` env vars
3. Merge configuration changes
4. Wait for ArgoCD auto-sync (3-5 minutes)
5. Force runner re-registration:
   ```bash
   kubectl delete pods -n arc-runners -l app.kubernetes.io/component=runner
   ```
6. Verify fix after 1-2 minutes

**References:**
- [Troubleshooting Guide](https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/blob/main/docs/TROUBLESHOOTING_EMPTY_LABELS.md)
- Issue #89 in matchpoint-github-runners-helm

### 2. Jobs Stuck in Queued State (2-5+ minutes)

**Root Cause:** `minRunners: 0` causes cold-start delays

**Symptoms:**
- Jobs stuck in "queued" status for 2-5+ minutes
- First job of the day takes significantly longer
- Parallel PRs cause cascading delays

**Diagnosis:**
```bash
# Check current Helm values
cat /home/pselamy/repositories/matchpoint-github-runners-helm/examples/beta-runners-values.yaml | grep minRunners

# Check if issue is minRunners: 0
# If minRunners: 0 → cold start on every job
```

**Fix:**
```yaml
# examples/beta-runners-values.yaml
minRunners: 2      # Changed from 0 - keep 2 runners pre-warmed
maxRunners: 20
```

**Why This Happens:**
```
With minRunners: 0:
Job Queued → ARC detects → Schedule pod → Pull image →
Start container → Register runner → Job starts
Total: 120-300 seconds

With minRunners: 2:
Job Queued → Assign to pre-warmed runner → Job starts
Total: 5-10 seconds
```

### 2. Cluster Access Issues

**Problem:** Cannot connect to Rackspace Spot cluster

**Common Errors:**
```
error: You must be logged in to the server (the server has asked for the client to provide credentials)
error: unknown command "oidc-login" for "kubectl"
dial tcp: lookup hcp-xxx.spot.rackspace.com: no such host
```

**Solutions:**

**Option A: Get kubeconfig from Terraform (RECOMMENDED)**

This is the preferred method - it gets a fresh kubeconfig from the active cloudspace without modifying infrastructure.

```bash
# 1. Set up terraform backend authentication
# Requires GitHub token with repo scope for TFstate.dev backend
export TF_HTTP_PASSWORD="<github-token-with-repo-scope>"

# 2. Navigate to terraform directory
cd /home/pselamy/repositories/matchpoint-github-runners-helm/terraform

# 3. Initialize terraform (reads state only, no changes)
terraform init

# 4. Get kubeconfig from terraform output (read-only operation)
terraform output -raw kubeconfig_raw > /tmp/runners-kubeconfig.yaml

# 5. Use the kubeconfig
export KUBECONFIG=/tmp/runners-kubeconfig.yaml
kubectl get pods -A
```

**Why this works:**
- `terraform output` only reads from state, doesn't plan or apply
- Uses `data.spot_kubeconfig` which fetches fresh credentials from Rackspace Spot API
- The cloudspace module automatically retrieves kubeconfig via the `spot` provider

**Option B: Use token-based auth (ngpc-user)**
```bash
# Check if token expired
kubectl config view --minify -o jsonpath='{.users[0].user.token}' | cut -d. -f2 | base64 -d | jq .exp
# Compare with current timestamp

# Get new kubeconfig from Rackspace Spot console
# 1. Login to https://spot.rackspace.com
# 2. Select cloudspace
# 3. Download kubeconfig
```

**Option C: Install oidc-login plugin**
```bash
# Install krew (kubectl plugin manager)
brew install krew  # or appropriate package manager

# Install oidc-login
kubectl krew install oidc-login

# Use OIDC context
kubectl config use-context tradestreamhq-tradestream-cluster-oidc
```

**Option D: Use ngpc CLI**
```bash
# Install ngpc CLI from Rackspace
pip install ngpc-cli

# Login and refresh credentials
ngpc login
ngpc kubeconfig get <cloudspace-name>
```

### 3. DNS Resolution Failures

**Problem:** Cluster hostname not resolving

```
dial tcp: lookup hcp-xxx.spot.rackspace.com: no such host
```

**Causes:**
1. Cluster was deleted/migrated (most common)
2. Using stale kubeconfig file that points to old cluster
3. DNS propagation delay
4. Wrong cluster endpoint

**Solution:**
Use terraform to get kubeconfig for the CURRENT active cluster:

```bash
# Get fresh kubeconfig from terraform (see Option A above)
export TF_HTTP_PASSWORD="<github-token>"
cd /home/pselamy/repositories/matchpoint-github-runners-helm/terraform
terraform init
terraform output -raw kubeconfig_raw > /tmp/runners-kubeconfig.yaml
```

**Note:** The `kubeconfig-matchpoint-runners-prod.yaml` file in the repo root may be stale if the cluster was recreated. Always use `terraform output` to get the current kubeconfig.

**Diagnosis:**
```bash
# Check terraform state for current cloudspace
cd /home/pselamy/repositories/matchpoint-github-runners-helm/terraform
export TF_HTTP_PASSWORD="<github-token>"
terraform init
terraform state list | grep cloudspace

# View cloudspace details
terraform state show module.cloudspace.spot_cloudspace.main
```

### 4. Configuration Mismatch

**Problem:** Documentation says one thing, deployed config is different

**Key Insight:** The `examples/*.yaml` files are what actually gets deployed. The `values/repositories.yaml` is documentation/reference only.

**Audit Configuration:**
```bash
# Check what's ACTUALLY deployed
cat examples/beta-runners-values.yaml | grep -E "(minRunners|maxRunners)"

# vs what documentation says
cat values/repositories.yaml | grep -E "(minRunners|maxRunners)"
```

## Monitoring Commands

### Check Workflow Status

```bash
# List queued workflows
gh run list --repo Matchpoint-AI/project-beta-api --status queued

# List in-progress workflows
gh run list --repo Matchpoint-AI/project-beta-api --status in_progress

# View specific run
gh run view <RUN_ID> --repo Matchpoint-AI/project-beta-api
```

### Check Runner Status (when cluster accessible)

```bash
# Set kubeconfig
export KUBECONFIG=/path/to/kubeconfig.yaml

# Check runner scale set
kubectl get autoscalingrunnerset -n arc-beta-runners-new

# Check runner pods
kubectl get pods -n arc-beta-runners-new -l app.kubernetes.io/component=runner

# Check ARC controller logs
kubectl logs -n arc-systems deployment/arc-gha-rs-controller --tail=50

# Check for scaling events
kubectl get events -n arc-beta-runners-new --sort-by='.lastTimestamp' | tail -20
```

### Check GitHub Registration

```bash
# List registered runners
gh api /orgs/Matchpoint-AI/actions/runners --jq '.runners[] | {name, status, busy}'

# Check runner groups
gh api /orgs/Matchpoint-AI/actions/runner-groups --jq '.runner_groups[].name'
```

## Troubleshooting Checklist

### For Stuck Jobs

1. [ ] Check `minRunners` in deployed Helm values
2. [ ] Verify ArgoCD sync status
3. [ ] Check if pods are scheduling (kubectl get pods)
4. [ ] Verify GitHub runner registration
5. [ ] Check node capacity and resources
6. [ ] Review ARC controller logs for errors

### For Cluster Access

1. [ ] Check kubeconfig context (kubectl config current-context)
2. [ ] Verify token expiration
3. [ ] Try different auth method (token vs OIDC)
4. [ ] Check if cluster hostname resolves (nslookup)
5. [ ] Verify cluster still exists in Rackspace console

### For Configuration Issues

1. [ ] Compare examples/*.yaml with values/repositories.yaml
2. [ ] Check ArgoCD for deployed values
3. [ ] Verify Helm release values

## Related Issues

| Issue | Repository | Description |
|-------|------------|-------------|
| #72 | matchpoint-github-runners-helm | Root cause analysis for queuing |
| #77 | matchpoint-github-runners-helm | Fix PR (minRunners: 0 → 2) - MERGED |
| #76 | matchpoint-github-runners-helm | Investigation state file |
| #1624 | project-beta | ARC runners stuck (closed) |
| #1577 | project-beta | P0: ARC unavailable (closed) |
| #1521 | project-beta | Runners stuck (closed) |

## Cost Considerations

| Setting | Cost Impact | Recommendation |
|---------|-------------|----------------|
| `minRunners: 0` | Lowest ($0 idle) | Development/low-traffic |
| `minRunners: 2` | ~$150-300/mo | Production/high-traffic |
| `minRunners: 5` | ~$400-700/mo | Enterprise/critical CI |

**ROI Calculation:**
- 2 pre-warmed runners save ~2-5 min per job
- 50+ PRs/week × 3 min saved = 150+ min/week
- Developer time saved >> runner cost

## Emergency Procedures

### Runners Completely Down

1. **Check ArgoCD sync status** via Argo UI or CLI
2. **Force sync** if needed: `argocd app sync arc-beta-runners`
3. **Check node availability** in Rackspace console
4. **Manual pod restart**: `kubectl rollout restart deployment -n arc-beta-runners-new`

### Fallback to GitHub-hosted runners

```yaml
# Temporarily switch workflow to GitHub-hosted
jobs:
  build:
    runs-on: ubuntu-latest  # Instead of self-hosted
```

## References

- Helm Chart: `matchpoint-github-runners-helm/charts/github-actions-runners/`
- Terraform: `matchpoint-github-runners-helm/terraform/`
- ArgoCD: https://argocd.matchpointai.com (internal)
- Rackspace Spot: https://spot.rackspace.com
- ARC Documentation: https://github.com/actions/actions-runner-controller

# Deployment Guide

This guide explains how to deploy GitHub Actions Runner Scale Sets on Rackspace Spot infrastructure using Helm charts and ArgoCD.

## Prerequisites

1. **Rackspace Spot Infrastructure** (provisioned via Terraform - see terraform/)
2. **Helm 3.x** installed locally
3. **kubectl** configured to access the cluster
4. **GitHub Personal Access Token** with these permissions:
   - `repo` (Full control of private repositories)
   - `admin:org` > `manage_runners:org` (Manage organization runners)
5. **ArgoCD CLI** (optional, for manual sync operations)

## Infrastructure Overview

The infrastructure uses a standardized naming convention to support multi-purpose deployments.

### Naming Convention

All cloudspaces follow the pattern: `matchpoint-{purpose}-{region}-{env}`

- **Purpose**: Identifies the infrastructure use case (e.g., `github-runners`, `app-hosting`)
- **Region**: Abbreviated region code (e.g., `dfw`, `iad`, `ord`)
- **Environment**: Terraform workspace name (e.g., `prod`, `staging`, `dev`)

**Example**: `matchpoint-github-runners-dfw-prod`

This convention ensures:
- Clear identification of cloudspace purpose at a glance
- Easy filtering and management of multi-purpose infrastructure
- Consistent labeling across resources

## Deployment Methods

We support two deployment methods:

1. **GitOps (Recommended)**: ArgoCD automatically deploys runners from Git
2. **Manual Helm**: Direct installation via Helm commands

### Method 1: GitOps with ArgoCD (Recommended)

This is our production deployment method. All configuration lives in Git, and ArgoCD keeps the cluster in sync.

#### Step 1: Provision Infrastructure

```bash
cd terraform

# Create environment-specific workspace
terraform workspace new prod

# Deploy with defaults (creates matchpoint-github-runners-dfw-prod)
terraform apply -var-file=prod.tfvars

# Or customize the purpose for different use cases
terraform apply -var-file=prod.tfvars -var="purpose=app-hosting"
# Creates: matchpoint-app-hosting-dfw-prod
```

The Terraform deployment automatically:
1. Creates a Kubernetes cluster (cloudspace) with proper naming
2. Provisions autoscaling worker nodes with purpose labels
3. Installs ArgoCD for GitOps-based application management
4. Configures node labels for workload targeting

#### Step 2: Configure GitHub Token

Store your GitHub token in ArgoCD:

```bash
kubectl create secret generic github-token \
  -n argocd \
  --from-literal=token=YOUR_GITHUB_TOKEN
```

#### Step 3: Deploy via ArgoCD

The Terraform setup automatically deploys bootstrap applications. Verify:

```bash
argocd app list

# Expected output:
# NAME                           STATUS
# arc-controller                 Synced
# github-runners                 Synced
```

#### Step 4: Add New Repositories

To add runners for a new repository, edit `values/repositories.yaml`:

```yaml
repositories:
  - name: my-new-repo
    org: Matchpoint-AI
    category: frontend
    profile: medium
    scaling:
      minRunners: 1
      maxRunners: 10
    labels:
      - my-new-repo-runners
```

Commit and push:

```bash
git add values/repositories.yaml
git commit -m "feat: add runners for my-new-repo"
git push
```

ArgoCD will automatically sync the changes within 3 minutes (or trigger manually):

```bash
argocd app sync github-runners
```

### Method 2: Manual Helm Installation

For testing or non-production environments:

#### Step 1: Add Helm Repository

```bash
helm repo add matchpoint-runners https://matchpoint-ai.github.io/matchpoint-github-runners-helm
helm repo update
```

#### Step 2: Install ARC Controller

```bash
helm install arc matchpoint-runners/github-actions-controller \
  -n arc-systems \
  --create-namespace
```

#### Step 3: Deploy Runners

Choose the configuration for your repository type:

**Frontend Repository (Node.js/Docker)**
```bash
helm install arc-frontend-runners matchpoint-runners/github-actions-runners \
  -f examples/frontend-runners-values.yaml \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-frontend-runners \
  --create-namespace
```

**API Repository (Python/Docker)**
```bash
helm install arc-api-runners matchpoint-runners/github-actions-runners \
  -f examples/api-runners-values.yaml \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-api-runners \
  --create-namespace
```

**Organization Runners (with Persistent Storage)**
```bash
helm install arc-runners matchpoint-runners/github-actions-runners \
  -f examples/runners-values.yaml \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-runners \
  --create-namespace
```

## Development/Testing Deployment

For local development or testing from this repository source:

### 1. Update Chart Dependencies

```bash
# Update controller dependencies
cd charts/github-actions-controller
helm dependency update

# Update runner dependencies
cd ../github-actions-runners
helm dependency update
cd ../..
```

### 2. Install Controller from Source

```bash
helm install arc ./charts/github-actions-controller \
  -n arc-systems \
  --create-namespace
```

### 3. Install Runners from Source

```bash
helm install test-runners ./charts/github-actions-runners \
  -f examples/frontend-runners-values.yaml \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-test-runners \
  --create-namespace
```

### 4. Test Changes

```bash
# Dry-run to see rendered templates
helm template test-runners ./charts/github-actions-runners \
  -f examples/frontend-runners-values.yaml \
  --namespace arc-test

# Upgrade after making changes
helm upgrade test-runners ./charts/github-actions-runners \
  -f examples/frontend-runners-values.yaml \
  -n arc-test-runners
```

## Configuration

### GitHub Token Management

**GitOps Method:**
Token stored in Kubernetes secret and referenced by ArgoCD:
```bash
kubectl create secret generic github-token \
  -n argocd \
  --from-literal=token=ghp_xxxxxxxxxxxxx
```

**Manual Method:**
Token passed directly via Helm:
```bash
--set gha-runner-scale-set.githubConfigSecret.github_token=ghp_xxxxxxxxxxxxx
```

### Runner Labels (IMPORTANT)

ARC only supports **one label**: the `runnerScaleSetName`. Do NOT use `ACTIONS_RUNNER_LABELS` environment variable.

**Correct Configuration:**
```yaml
gha-runner-scale-set:
  runnerScaleSetName: "arc-frontend-runners"  # This becomes the GitHub label
```

**Usage in Workflow:**
```yaml
jobs:
  build:
    runs-on: arc-frontend-runners  # Matches runnerScaleSetName
```

See [docs/TROUBLESHOOTING_EMPTY_LABELS.md](docs/TROUBLESHOOTING_EMPTY_LABELS.md) for details.

### Storage Configuration

Organization runners (beta) use persistent storage for build caching:

```yaml
gha-runner-scale-set:
  template:
    spec:
      volumes:
      - name: work
        ephemeral:
          volumeClaimTemplate:
            spec:
              storageClassName: standard-rwo  # Rackspace default
              resources:
                requests:
                  storage: 35Gi
```

Ensure your cluster has the `standard-rwo` storage class (created automatically by Rackspace Spot).

### Resource Profiles

Defined in `values/base-config.yaml`:

| Profile | CPU Request | CPU Limit | Memory Request | Memory Limit | Use Case |
|---------|-------------|-----------|----------------|--------------|----------|
| small   | 500m        | 1         | 1Gi            | 2Gi          | Lightweight tasks |
| medium  | 2           | 3         | 4Gi            | 6Gi          | Standard builds |
| large   | 4           | 6         | 8Gi            | 12Gi         | Heavy compilation |
| xlarge  | 8           | 12        | 16Gi           | 24Gi         | ML/Data processing |

Assign profiles in `values/repositories.yaml`:
```yaml
- name: project-beta-frontend
  profile: medium
```

## Monitoring and Verification

### Check Runner Registration

Verify runners are registered in GitHub:

```bash
# Via GitHub CLI
gh api /orgs/Matchpoint-AI/actions/runners --jq '.runners[] | {name, status, labels: [.labels[].name]}'

# Via GitHub UI
# Navigate to: Organization Settings > Actions > Runners
```

### Check Kubernetes Resources

```bash
# View all runner scale sets
kubectl get autoscalingrunnerset -A

# Check specific namespace
kubectl get pods -n arc-frontend-runners

# View runner pod logs
kubectl logs -n arc-frontend-runners <pod-name>

# Check ARC controller status
kubectl get pods -n arc-systems
kubectl logs -n arc-systems -l app.kubernetes.io/component=controller-manager
```

### Check ArgoCD Sync Status

```bash
# List all applications
argocd app list

# Get detailed status
argocd app get arc-controller
argocd app get github-runners

# View sync history
argocd app history github-runners
```

## GitOps Workflow (Production)

Our production workflow uses Git as the single source of truth:

1. **Developer makes change:**
   ```bash
   vim values/repositories.yaml
   git add values/repositories.yaml
   git commit -m "feat: add runners for new-repo"
   git push
   ```

2. **ArgoCD detects change:**
   - Polls Git repository every 3 minutes
   - Detects diff between Git and cluster state
   - Shows "OutOfSync" status

3. **ArgoCD syncs:**
   - Auto-sync enabled by default
   - Applies Helm chart changes to cluster
   - Creates/updates AutoScalingRunnerSet resources

4. **ARC Controller responds:**
   - Detects new/updated AutoScalingRunnerSet
   - Registers runner scale set with GitHub
   - Provisions runner pods

5. **Self-healing:**
   - If manual changes made in cluster
   - ArgoCD detects drift and reverts to Git state

## Troubleshooting

### Runners Not Showing in GitHub

**Symptoms:** Runners don't appear in GitHub UI, or show empty labels `[]`

**Diagnosis:**
```bash
# Check if runners registered
gh api /orgs/Matchpoint-AI/actions/runners --jq '.runners[] | {name, labels: [.labels[].name]}'

# Check AutoScalingRunnerSet
kubectl get autoscalingrunnerset -A

# Check ARC controller logs
kubectl logs -n arc-systems -l app.kubernetes.io/component=controller-manager | tail -50
```

**Common Causes:**
1. **GitHub token invalid or expired** - Regenerate token with correct permissions
2. **runnerScaleSetName mismatch** - See [docs/TROUBLESHOOTING_EMPTY_LABELS.md](docs/TROUBLESHOOTING_EMPTY_LABELS.md)
3. **Network issues** - Check controller can reach api.github.com

**Fix:**
```bash
# Update GitHub token
kubectl delete secret github-token -n argocd
kubectl create secret generic github-token -n argocd --from-literal=token=NEW_TOKEN

# Force runner re-registration
kubectl delete pods -n arc-frontend-runners -l app.kubernetes.io/component=runner
```

### Runners Not Picking Up Jobs

**Symptoms:** Jobs stuck in "Queued" state despite runners online

**Diagnosis:**
```bash
# Check runner labels match workflow
gh api /orgs/Matchpoint-AI/actions/runners --jq '.runners[] | {name, labels: [.labels[].name]}'

# Your workflow must use matching label:
# runs-on: arc-frontend-runners
```

**Fix:** Ensure workflow `runs-on:` matches `runnerScaleSetName` exactly.

### ArgoCD Out of Sync

**Symptoms:** ArgoCD shows "OutOfSync" but doesn't sync automatically

**Diagnosis:**
```bash
argocd app get github-runners

# Check sync policy
argocd app get github-runners -o json | jq '.spec.syncPolicy'
```

**Fix:**
```bash
# Manual sync
argocd app sync github-runners --force

# Enable auto-sync if disabled
argocd app set github-runners --sync-policy automated --auto-prune --self-heal
```

### Storage Issues (Beta Runners)

**Symptoms:** Runner pods stuck in "Pending", PVC not bound

**Diagnosis:**
```bash
# Check storage class exists
kubectl get storageclass

# Check PVC status
kubectl get pvc -n arc-runners

# Describe PVC for errors
kubectl describe pvc -n arc-runners
```

**Fix:**
```bash
# Rackspace Spot provides standard-rwo by default
# If missing, check node pool provisioning:
kubectl get nodes -L topology.kubernetes.io/zone
```

### Pods Stuck in ImagePullBackOff

**Symptoms:** Runner pods can't pull container image

**Diagnosis:**
```bash
kubectl describe pod -n arc-frontend-runners <pod-name>
```

**Common Causes:**
1. Rate limiting from ghcr.io
2. Network connectivity issues

**Fix:**
```bash
# Check node connectivity
kubectl run test-curl --image=curlimages/curl --rm -it -- curl -I ghcr.io

# Wait and retry (rate limits reset)
kubectl delete pods -n arc-frontend-runners -l app.kubernetes.io/component=runner
```

### High Resource Usage

**Symptoms:** Runners slow, builds timing out

**Diagnosis:**
```bash
# Check resource usage
kubectl top pods -n arc-frontend-runners

# Check resource requests/limits
kubectl describe autoscalingrunnerset -n arc-frontend-runners
```

**Fix:**
Edit `values/repositories.yaml` to use larger profile:
```yaml
- name: project-beta-frontend
  profile: large  # Upgrade from medium
```

## Scaling Runners

### GitOps Method

Edit `values/repositories.yaml`:

```yaml
- name: project-beta-frontend
  scaling:
    minRunners: 2   # Always-on runners
    maxRunners: 20  # Maximum concurrent runners
```

Commit, push, and let ArgoCD sync:

```bash
git add values/repositories.yaml
git commit -m "feat: scale frontend runners for peak load"
git push
```

### Manual Method

```bash
helm upgrade arc-frontend-runners matchpoint-runners/github-actions-runners \
  --reuse-values \
  --set gha-runner-scale-set.minRunners=2 \
  --set gha-runner-scale-set.maxRunners=20 \
  -n arc-frontend-runners
```

### Quick Scaling Script

Use the helper script:

```bash
./scripts/scale-runners.sh project-beta-frontend 2 20
```

See [SCALING.md](SCALING.md) for advanced scaling strategies.

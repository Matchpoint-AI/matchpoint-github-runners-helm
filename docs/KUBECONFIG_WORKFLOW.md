# Kubeconfig Workflow for Cluster Interaction

This guide explains how to obtain and use kubeconfig to interact with the ARC runner Kubernetes clusters deployed on Rackspace Spot.

## Overview

The ARC (Actions Runner Controller) runners are deployed on a Rackspace Spot managed Kubernetes cluster (cloudspace). To interact with the cluster using `kubectl`, you need a valid kubeconfig file with authentication credentials.

## Architecture

```
Terraform → Rackspace Spot API → Cloudspace (K8s Cluster)
                ↓
         data.spot_kubeconfig
                ↓
         kubeconfig_raw output
                ↓
         kubectl commands
```

## Methods to Obtain Kubeconfig

### Method 1: Terraform Output (RECOMMENDED)

This is the **preferred method** as it always retrieves the current kubeconfig from the active cloudspace without modifying infrastructure.

**Prerequisites:**
- GitHub token with `repo` scope (for TFstate.dev backend authentication)
- Terraform installed locally

**Steps:**

```bash
# 1. Set up terraform backend authentication
export TF_HTTP_PASSWORD="<github-token-with-repo-scope>"

# 2. Navigate to terraform directory
cd /path/to/matchpoint-github-runners-helm/terraform

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
- Always gets current credentials even if cluster was recreated

**Security Note:** The kubeconfig file contains sensitive credentials. Always store it in `/tmp` or another secure location and never commit it to git.

### Method 2: spotctl CLI

`spotctl` is the official Rackspace Spot CLI tool that can retrieve kubeconfig directly from the API.

**Prerequisites:**
- `spotctl` installed (`go install github.com/rackspace-spot/spotctl@latest`)
- Rackspace Spot API token configured in `~/.spot_config`

**Steps:**

```bash
# Get kubeconfig for a specific cloudspace
spotctl cloudspaces get-config \
  --name matchpoint-runners-prod \
  --org matchpoint-ai \
  > /tmp/runners-kubeconfig.yaml

# Use the kubeconfig
export KUBECONFIG=/tmp/runners-kubeconfig.yaml
kubectl get pods -A
```

**Configuration file** (`~/.spot_config`):
```yaml
org: "matchpoint-ai"
refreshToken: "<rackspace-spot-api-token>"
accessToken: "<rackspace-spot-api-token>"
region: "us-central-dfw-1"
```

**Finding your cloudspace name:**
```bash
# List all cloudspaces
spotctl cloudspaces list --org matchpoint-ai -o table
```

### Method 3: Terraform-Generated File (Development Only)

During development, Terraform can optionally write kubeconfig to a local file.

**Enable in terraform:**
```hcl
# terraform/prod.tfvars
write_kubeconfig = true
```

**After terraform apply:**
```bash
# File will be at:
ls terraform/kubeconfig-matchpoint-runners-prod.yaml

# Use it:
export KUBECONFIG=terraform/kubeconfig-matchpoint-runners-prod.yaml
kubectl get pods -A
```

**Warning:** This file can become stale if the cluster is recreated. Always prefer Method 1 (terraform output) for reliable access.

### Method 4: Rackspace Spot Console (Manual)

**Steps:**
1. Login to <https://spot.rackspace.com>
2. Navigate to your cloudspace
3. Click "Download Kubeconfig"
4. Save to local file
5. Use with kubectl

**Use case:** Quick access when you don't have CLI tools set up.

## Common kubectl Operations

Once you have a valid kubeconfig, here are common operations for managing ARC runners:

### Viewing Runner Resources

```bash
# Set kubeconfig
export KUBECONFIG=/tmp/runners-kubeconfig.yaml

# View all namespaces
kubectl get namespaces

# Check ARC controller status
kubectl get pods -n arc-systems

# View AutoscalingRunnerSet resources
kubectl get autoscalingrunnerset -A

# Check runner pods (replace namespace as needed)
kubectl get pods -n arc-runners
kubectl get pods -n arc-frontend-runners
kubectl get pods -n arc-api-runners
```

### Checking Runner Logs

```bash
# Get logs from a specific runner pod
kubectl logs -n arc-runners <pod-name>

# Follow logs in real-time
kubectl logs -n arc-runners <pod-name> -f

# Get logs from ARC controller
kubectl logs -n arc-systems deployment/arc-gha-rs-controller --tail=100
```

### Debugging Runner Issues

```bash
# Check pod events
kubectl describe pod -n arc-runners <pod-name>

# View recent events in namespace
kubectl get events -n arc-runners --sort-by='.lastTimestamp' | tail -20

# Check resource usage
kubectl top pods -n arc-runners

# View node status
kubectl get nodes
kubectl describe node <node-name>
```

### Scaling Operations

```bash
# View current scale set configuration
kubectl get autoscalingrunnerset -n arc-runners -o yaml

# Force restart of runner pods (to pick up new configuration)
kubectl delete pods -n arc-runners -l app.kubernetes.io/component=runner

# Check Persistent Volume Claims (for runners with storage)
kubectl get pvc -n arc-runners
```

### ArgoCD Operations

```bash
# View ArgoCD applications
kubectl get applications -n argocd

# Check sync status of runner application
kubectl describe application arc-runners -n argocd

# View ArgoCD ApplicationSets
kubectl get applicationset -n argocd
```

## Troubleshooting

### Error: "You must be logged in to the server"

**Cause:** Token expired or invalid kubeconfig

**Solution:** Get fresh kubeconfig using Method 1 (terraform output)

```bash
export TF_HTTP_PASSWORD="<github-token>"
cd terraform
terraform init
terraform output -raw kubeconfig_raw > /tmp/runners-kubeconfig.yaml
export KUBECONFIG=/tmp/runners-kubeconfig.yaml
```

### Error: "dial tcp: lookup hcp-xxx.spot.rackspace.com: no such host"

**Cause:** Kubeconfig points to old cluster that was deleted/recreated

**Solution:** Get current kubeconfig from terraform state (not from file)

```bash
# Always use terraform output, not old kubeconfig files
cd terraform
export TF_HTTP_PASSWORD="<github-token>"
terraform init
terraform output -raw kubeconfig_raw > /tmp/runners-kubeconfig.yaml
```

### Error: "unknown command 'oidc-login' for kubectl"

**Cause:** Missing kubectl oidc-login plugin

**Solution:** Either:
- Use Method 1 (terraform output) which provides token-based auth
- Or install the plugin: `kubectl krew install oidc-login`

### Verifying Current Cluster

```bash
# Check which cloudspace is active in terraform state
cd terraform
export TF_HTTP_PASSWORD="<github-token>"
terraform init
terraform state list | grep cloudspace

# View cloudspace details
terraform state show module.cloudspace.spot_cloudspace.main

# Compare with actual cloudspaces via API
spotctl cloudspaces list --org matchpoint-ai -o table
```

## Authentication Details

### How Kubeconfig Works

The kubeconfig file contains:
- **Cluster endpoint:** API server URL (e.g., `hcp-xxx.spot.rackspace.com`)
- **CA certificate:** For TLS verification
- **Authentication:** Either token-based or OIDC-based

**Token-based authentication (from terraform):**
```yaml
users:
- name: ngpc-user
  user:
    token: <service-account-token>
```

**OIDC-based authentication (from console):**
```yaml
users:
- name: oidc-user
  user:
    exec:
      command: kubectl
      args:
      - oidc-login
```

### Token Expiration

Tokens retrieved via `terraform output` are service account tokens that have long expiration times. If you encounter auth errors, simply re-run `terraform output` to get a fresh token.

## Best Practices

1. **Always use terraform output** for reliable kubeconfig access
2. **Store kubeconfig in /tmp** to avoid committing credentials
3. **Use namespaces** to scope your operations (e.g., `-n arc-runners`)
4. **Check cluster state** in terraform before assuming cluster exists
5. **Never commit** kubeconfig files to git (already in `.gitignore`)

## CI/CD Integration

The GitHub Actions workflows use terraform to automatically retrieve kubeconfig:

```yaml
# .github/workflows/terraform.yaml
- name: Get kubeconfig
  run: |
    cd terraform
    terraform output -raw kubeconfig_raw > /tmp/kubeconfig.yaml
  env:
    TF_HTTP_PASSWORD: ${{ secrets.GITHUB_TOKEN }}

- name: Deploy with kubectl
  run: kubectl apply -f manifest.yaml
  env:
    KUBECONFIG: /tmp/kubeconfig.yaml
```

## Related Documentation

- [Deployment Guide](../DEPLOYMENT.md) - How to deploy runners
- [Troubleshooting Guide](../docs/TROUBLESHOOTING_EMPTY_LABELS.md) - Common runner issues
- [spotctl Documentation](../.ai/tools/spotctl.md) - Rackspace Spot CLI reference
- [Infrastructure CD Workflow](../.claude/skills/infrastructure-cd/SKILL.md) - Automated deployments
- [ARC Runner Troubleshooting](../.claude/skills/arc-runner-troubleshooting/SKILL.md) - Comprehensive troubleshooting

## Quick Reference

```bash
# Get fresh kubeconfig (recommended method)
export TF_HTTP_PASSWORD="<github-token>"
cd terraform
terraform init
terraform output -raw kubeconfig_raw > /tmp/kubeconfig.yaml
export KUBECONFIG=/tmp/kubeconfig.yaml

# Common commands
kubectl get pods -A                              # All pods
kubectl get autoscalingrunnerset -A              # Runner scale sets
kubectl logs -n arc-systems deployment/arc-gha-rs-controller  # Controller logs
kubectl get events -n arc-runners --sort-by='.lastTimestamp'  # Recent events
kubectl describe application arc-runners -n argocd           # ArgoCD sync status
```

## Support

For issues or questions:
- Check [ARC Runner Troubleshooting](../.claude/skills/arc-runner-troubleshooting/SKILL.md)
- Review [GitHub Issues](https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/issues)
- Contact: Infrastructure team

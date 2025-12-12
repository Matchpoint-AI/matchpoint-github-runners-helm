# ArgoCD Management for GitHub Runners

This directory contains ArgoCD manifests for managing GitHub Actions Runner infrastructure using GitOps.

## Architecture

```
ArgoCD (GitOps Controller)
    ├── arc-controller (ARC Controller)
    └── github-runners (ApplicationSet)
        ├── arc-frontend-runners
        ├── arc-api-runners-v2
        └── arc-runners
```

## Setup

### Prerequisites
- ArgoCD installed in the cluster
- GitHub Personal Access Token with appropriate permissions
- Access to the Kubernetes cluster

### Quick Setup

Run the setup script with your GitHub token:

```bash
./argocd/setup-argocd.sh YOUR_GITHUB_TOKEN
```

This will:
1. Configure ArgoCD with the GitHub repository
2. Store the GitHub token securely
3. Create ArgoCD applications for all runners
4. Enable auto-sync and self-healing

## Manual Setup

### 1. Login to ArgoCD

```bash
# Get server IP
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Login
argocd login $ARGOCD_SERVER --username admin --password "$ARGOCD_PASSWORD" --insecure
```

### 2. Add Repository

```bash
argocd repo add https://github.com/Matchpoint-AI/matchpoint-github-runners-helm
```

### 3. Create GitHub Token Secret

```bash
kubectl create secret generic github-token \
  -n argocd \
  --from-literal=token=YOUR_GITHUB_TOKEN
```

### 4. Apply Applications

```bash
# Apply controller
kubectl apply -f argocd/applications/arc-controller.yaml

# Apply ApplicationSet for runners
kubectl apply -f argocd/applicationset.yaml
```

## Managing Applications

### View All Applications

```bash
argocd app list
```

### Sync Applications

```bash
# Sync all runner applications
argocd app sync -l argocd.argoproj.io/instance=github-runners

# Sync specific application
argocd app sync arc-frontend-runners
```

### Check Application Health

```bash
argocd app get arc-frontend-runners --health
```

### Scale Runners

Edit the values files in the repository and commit:
- `examples/frontend-runners-values.yaml`
- `examples/api-runners-values.yaml`
- `examples/runners-values.yaml`

ArgoCD will automatically detect changes and sync.

## Monitoring

### ArgoCD UI

Access the web interface:
- URL: `https://<ARGOCD_SERVER_IP>`
- Username: `admin`
- Password: Get from secret (see setup)

### CLI Status

```bash
# Overall status
argocd app list

# Detailed application info
argocd app get arc-frontend-runners

# View resources
argocd app resources arc-frontend-runners
```

## Troubleshooting

### Application Out of Sync

```bash
# Force sync
argocd app sync arc-frontend-runners --force

# Prune resources not in Git
argocd app sync arc-frontend-runners --prune
```

### Check Logs

```bash
# ArgoCD controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Repo server logs
kubectl logs -n argocd deployment/argocd-repo-server

# Runner controller logs
kubectl logs -n arc-systems deployment/arc-gha-rs-controller
```

### Refresh Application

```bash
# Hard refresh from Git
argocd app get arc-frontend-runners --hard-refresh
```

## GitOps Workflow

1. **Make changes**: Edit Helm values in the Git repository
2. **Commit & Push**: Push changes to the main branch
3. **Auto-sync**: ArgoCD detects changes and syncs automatically
4. **Self-heal**: Any manual changes in the cluster are reverted

## Security

- GitHub token stored as Kubernetes secret
- Token injected as environment variable to ArgoCD repo-server
- Applications use `$ARGOCD_ENV_GITHUB_TOKEN` variable
- Secrets never stored in Git

## Benefits

✅ **GitOps**: All configuration in Git
✅ **Auto-sync**: Automatic deployment of changes
✅ **Self-healing**: Drift detection and correction
✅ **Rollback**: Easy rollback through Git history
✅ **Visibility**: Single pane of glass for all runners
✅ **Declarative**: Infrastructure as Code
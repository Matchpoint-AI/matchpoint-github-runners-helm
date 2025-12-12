# App of Apps Pattern - ArgoCD Self-Management

This directory implements the **App of Apps pattern**, where ArgoCD manages itself and all child applications through a single root application.

## Architecture

```
root (App of Apps)
├── argocd (ArgoCD manages itself)
├── arc-controller (GitHub Actions Runner Controller)
└── github-runners (ApplicationSet)
    └── arc-runners (Org-level runners)
```

## Benefits

1. **Single Source of Truth**: One root application to manage everything
2. **Self-Management**: ArgoCD manages its own installation and updates
3. **Declarative GitOps**: Everything defined in Git, including ArgoCD itself
4. **Sync Wave Control**: Ordered deployment (ArgoCD → Controller → Runners)
5. **Easy Bootstrap**: Apply one manifest to deploy the entire stack
6. **Version Control**: Track all infrastructure changes through Git

## Directory Structure

```
argocd/
├── root-app.yaml                   # Root Application (entry point)
├── apps/                           # Child applications managed by root
│   ├── argocd.yaml                # ArgoCD self-management
│   ├── arc-controller.yaml        # ARC controller application
│   └── github-runners-appset.yaml # Runners ApplicationSet
├── applications/                   # Legacy individual apps (kept for reference)
├── applicationset.yaml            # Legacy ApplicationSet (kept for reference)
└── APP_OF_APPS.md                 # This documentation
```

## Sync Waves

Applications deploy in order using `argocd.argoproj.io/sync-wave` annotations:

- **Wave -1**: ArgoCD itself (must exist first)
- **Wave 0**: Root application (default)
- **Wave 1**: ARC Controller (needs cluster ready)
- **Wave 2**: GitHub Runners (needs ARC controller)

## Initial Bootstrap

### Prerequisites

1. Kubernetes cluster running
2. ArgoCD installed (initial installation)
3. GitHub Personal Access Token with `repo` and `admin:org` permissions

### Quick Bootstrap

Apply the root application to bootstrap everything:

```bash
# 1. Install ArgoCD initially (one-time manual step)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Create GitHub token secret
kubectl create secret generic github-token \
  -n argocd \
  --from-literal=token=YOUR_GITHUB_TOKEN

# 3. Create the org-level GitHub secret for runners
kubectl create namespace arc-runners
kubectl create secret generic arc-org-github-secret \
  -n arc-runners \
  --from-literal=github_token=YOUR_GITHUB_TOKEN

# 4. Apply the root application (bootstraps everything)
kubectl apply -f argocd/root-app.yaml
```

### What Happens Next

Once the root application is applied:

1. **ArgoCD Self-Management**: ArgoCD creates an Application to manage itself
2. **Controller Deployment**: ARC controller is deployed (wave 1)
3. **Runners Deployment**: GitHub runners are deployed via ApplicationSet (wave 2)
4. **Continuous Sync**: All applications auto-sync on Git changes

## Self-Management Details

### How ArgoCD Manages Itself

The `argocd.yaml` application uses the official ArgoCD Helm chart to manage the ArgoCD installation:

```yaml
source:
  repoURL: https://github.com/argoproj/argo-helm
  chart: argo-cd
  targetRevision: 7.7.12  # Pinned version
```

**Benefits:**
- ArgoCD configuration is version-controlled
- Updates managed through GitOps
- Drift detection on ArgoCD itself
- Self-healing if manually modified

**Important**: The initial ArgoCD installation must be done manually. After that, ArgoCD takes over its own management.

### Upgrading ArgoCD

To upgrade ArgoCD:

1. Edit `argocd/apps/argocd.yaml`
2. Update `targetRevision` to new chart version
3. Commit and push to Git
4. ArgoCD will sync and upgrade itself

## Managing Applications

### View All Applications

```bash
# Using ArgoCD CLI
argocd app list

# Using kubectl
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
```

### Sync Root Application

```bash
# Sync everything from root
argocd app sync root

# Sync with cascade (syncs children too)
argocd app sync root --cascade
```

### Add New Applications

To add a new application to the App of Apps:

1. Create a new YAML file in `argocd/apps/`
2. Define the Application or ApplicationSet
3. Set appropriate sync wave annotation
4. Commit and push
5. Root application will detect and deploy it

Example:

```yaml
# argocd/apps/my-new-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-new-app
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/my-repo
    targetRevision: main
    path: charts/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Monitoring

### ArgoCD UI

Access the ArgoCD web interface:

```bash
# Port forward to access UI locally
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Navigate to: https://localhost:8080

### CLI Monitoring

```bash
# Overall health
argocd app get root

# Detailed app tree
argocd app get root --show-operation

# Watch sync status
argocd app wait root --sync
```

## Troubleshooting

### Root Application Out of Sync

```bash
# Force sync from Git
argocd app sync root --force

# Hard refresh
argocd app get root --hard-refresh
```

### Child Application Not Deploying

```bash
# Check if root app sees it
argocd app get root --show-params

# Sync specific child
argocd app sync arc-controller

# Check for sync waves
kubectl get app -n argocd -o json | jq '.items[] | {name: .metadata.name, wave: .metadata.annotations["argocd.argoproj.io/sync-wave"]}'
```

### ArgoCD Self-Management Issues

If ArgoCD self-management causes issues:

```bash
# Disable automated sync temporarily
kubectl patch app argocd -n argocd --type json \
  -p='[{"op": "replace", "path": "/spec/syncPolicy/automated", "value": null}]'

# Make manual fixes
kubectl edit <resource>

# Re-enable automated sync
kubectl patch app argocd -n argocd --type json \
  -p='[{"op": "add", "path": "/spec/syncPolicy/automated", "value": {"prune": true, "selfHeal": true}}]'
```

## Migration from Legacy Setup

If migrating from the old individual applications:

1. **Backup current state**:
   ```bash
   kubectl get applications -n argocd -o yaml > backup-apps.yaml
   ```

2. **Apply root application**:
   ```bash
   kubectl apply -f argocd/root-app.yaml
   ```

3. **Delete old applications** (after verifying new ones work):
   ```bash
   kubectl delete -f argocd/applications/arc-controller.yaml
   kubectl delete -f argocd/applicationset.yaml
   ```

4. **Keep legacy files** for reference in `argocd/applications/` and `argocd/applicationset.yaml`

## Best Practices

1. **Always use sync waves** for ordered deployment
2. **Pin versions** (e.g., ArgoCD chart version) for stability
3. **Test changes** in a dev cluster before production
4. **Monitor root application health** regularly
5. **Use Git branches** for testing new applications
6. **Document custom values** in application YAMLs
7. **Keep secrets external** (never in Git)

## Security Considerations

- GitHub token stored as Kubernetes secret
- Secret injected into ArgoCD repo-server via environment variable
- Applications reference secret, never contain token directly
- All manifests in Git are token-free
- Use RBAC to control who can modify root application

## References

- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Sync Waves and Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)

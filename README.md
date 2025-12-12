# Matchpoint GitHub Runners Helm Charts

This repository manages self-hosted GitHub Actions runners for the Matchpoint-AI organization, deployed on **Rackspace Spot** infrastructure using GitOps principles.

## Overview

**Infrastructure:** Rackspace Spot (Managed Kubernetes on spot instances)
**Orchestration:** ArgoCD for GitOps deployments
**Runner Controller:** GitHub Actions Runner Scale Set (ARC) v0.12.1
**Management:** Fully declarative configuration via Helm charts

### Architecture

```
GitHub Workflows
    ↓
GitHub Actions Runner Scale Set (ARC)
    ↓
Kubernetes Cluster (Rackspace Spot)
    ├── ARC Controller (arc-systems namespace)
    └── Runner Scale Sets (per-repository namespaces)
        ├── project-beta-frontend
        ├── project-beta-api
        └── project-beta (beta runners)
```

**Key Components:**
- **ARC Controller**: Manages runner lifecycle and scaling
- **Runner Scale Sets**: Auto-scaling runner pools per repository
- **ArgoCD**: Deploys and syncs runner configurations from Git
- **Rackspace Spot**: Provides cost-effective Kubernetes infrastructure

## Repository Structure

```
.
├── charts/                        # Helm charts
│   ├── github-actions-controller/ # ARC Controller chart
│   └── github-actions-runners/    # Runner scale set chart
├── argocd/                        # ArgoCD manifests
│   ├── applications/              # Individual app manifests
│   ├── apps-live/                 # Active deployments
│   └── applicationset*.yaml       # Dynamic app generation
├── terraform/                     # Rackspace Spot infrastructure
│   └── modules/
│       ├── cloudspace/            # Kubernetes cluster
│       ├── nodepool/              # Worker nodes
│       └── argocd/                # ArgoCD installation
├── values/                        # Parameterized configurations
│   ├── repositories.yaml          # Repository-to-runner mappings
│   ├── base-config.yaml           # Resource profiles & scaling
│   └── performance-*.yaml         # Performance overlays
├── examples/                      # Example values files
├── docs/                          # Troubleshooting guides
└── scripts/                       # Utility scripts
```

## Infrastructure Naming Convention

This repository follows a standardized naming convention for multi-purpose infrastructure.

### Cloudspace Naming Pattern

```
matchpoint-{purpose}-{region}-{env}
```

**Components:**
- `matchpoint`: Organization prefix
- `purpose`: Infrastructure purpose (e.g., `github-runners`, `app-hosting`, `services`)
- `region`: Region abbreviation (e.g., `dfw`, `iad`, `ord`)
- `env`: Environment (e.g., `prod`, `staging`, `dev`)

**Examples:**
- `matchpoint-github-runners-dfw-prod` - Production GitHub Actions runners in Dallas
- `matchpoint-github-runners-dfw-dev` - Development GitHub Actions runners in Dallas
- `matchpoint-app-hosting-iad-prod` - Production application hosting in Ashburn

### Node Labels

Worker nodes are automatically labeled with purpose identifiers:

```yaml
matchpoint.ai/purpose: github-runners
matchpoint.ai/environment: prod
matchpoint.ai/runner-pool: github-actions
```

## Quick Start

### For End Users (Deploy Runners)

1. **Add the Helm repository:**
```bash
helm repo add matchpoint-runners https://matchpoint-ai.github.io/matchpoint-github-runners-helm
helm repo update
```

1. **Install the ARC Controller:**
```bash
helm install arc matchpoint-runners/github-actions-controller \
  -n arc-systems --create-namespace
```

1. **Deploy runners for your repository:**
```bash
helm install my-runners matchpoint-runners/github-actions-runners \
  --set gha-runner-scale-set.githubConfigUrl=https://github.com/Matchpoint-AI/my-repo \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-my-repo-runners --create-namespace
```

### For Maintainers (GitOps Workflow)

We use ArgoCD for automated deployments. Changes to runner configurations are made via Git:

1. **Update runner configuration:**
```bash
# Edit repository definitions
vim values/repositories.yaml
```

1. **Commit and push:**
```bash
git add values/repositories.yaml
git commit -m "feat: scale frontend runners to handle peak load"
git push
```

1. **ArgoCD auto-syncs** (or trigger manually):
```bash
argocd app sync github-runners
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed setup instructions.
See [SCALING.md](SCALING.md) for scaling strategies and resource profiles.

## Key Features

- **Auto-scaling**: Runners scale based on job queue depth (0 to N)
- **Cost Optimization**: Runs on Rackspace Spot instances with automatic bidding
- **GitOps**: All configuration managed via Git (ArgoCD)
- **Multi-Repository**: Supports separate runner pools per repository
- **Resource Profiles**: Pre-configured sizing (small, medium, large, xlarge)
- **Persistent Storage**: Optional persistent volumes for build caching (beta runners)
- **Self-Healing**: ArgoCD detects and corrects configuration drift

## Usage in Workflows

Specify the runner scale set name in your workflow:

```yaml
jobs:
  build:
    runs-on: arc-frontend-runners  # Matches runnerScaleSetName
    steps:
      - uses: actions/checkout@v4
      - run: npm install && npm test
```

**Important**: ARC only supports the `runnerScaleSetName` as a label. See [docs/TROUBLESHOOTING_EMPTY_LABELS.md](docs/TROUBLESHOOTING_EMPTY_LABELS.md) for details.

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Comprehensive deployment guide
- [SCALING.md](SCALING.md) - Scaling strategies and resource management
- [argocd/README.md](argocd/README.md) - ArgoCD management and GitOps workflow
- [docs/DOCKER_IN_DOCKER.md](docs/DOCKER_IN_DOCKER.md) - Docker-in-Docker configuration and testcontainers guide
- [docs/TROUBLESHOOTING_EMPTY_LABELS.md](docs/TROUBLESHOOTING_EMPTY_LABELS.md) - Runner label troubleshooting
- [docs/KUBECONFIG_WORKFLOW.md](docs/KUBECONFIG_WORKFLOW.md) - Cluster access guide
- [AGENTS.md](AGENTS.md) - AI agent instructions for infrastructure work

## Cluster Access

To interact with the deployed runners, you need cluster access. See the [Kubeconfig Workflow Guide](docs/KUBECONFIG_WORKFLOW.md) for detailed instructions.

**Quick start:**
```bash
# Get kubeconfig from terraform (recommended)
export TF_HTTP_PASSWORD="<github-token>"
cd terraform
terraform init
terraform output -raw kubeconfig_raw > /tmp/kubeconfig.yaml
export KUBECONFIG=/tmp/kubeconfig.yaml
kubectl get pods -A
```

## Infrastructure Deployment

The underlying Rackspace Spot infrastructure is managed via Terraform:

```bash
cd terraform
terraform workspace select prod
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

This provisions:
1. Rackspace Spot Cloudspace (managed Kubernetes)
2. Auto-scaling worker node pool
3. ArgoCD installation with bootstrap applications

See [terraform/](terraform/) for infrastructure details.

## Chart Development

### Testing Charts Locally

```bash
# Update dependencies
cd charts/github-actions-runners
helm dependency update

# Template the chart
helm template test-runners . \
  -f ../../examples/frontend-runners-values.yaml \
  --namespace arc-test

# Install locally
helm install test-runners . \
  -f ../../examples/frontend-runners-values.yaml \
  -n arc-test --create-namespace
```

### Release Process

Charts are automatically packaged and published when merged to `main`:
1. Update chart version in `Chart.yaml`
2. Submit PR with changes
3. CI validates Helm templates and lints
4. On merge: chart packaged and published to GitHub Pages
5. `index.yaml` updated automatically

## Contributing

1. Create feature branch: `git checkout -b feat/description`
2. Make changes to charts in `charts/` directory
3. Update chart versions following [semver](https://semver.org/)
4. Test locally using examples
5. Submit PR with clear description
6. Ensure CI passes before merging

## Monitoring

```bash
# View all runner scale sets
kubectl get autoscalingrunnerset -A

# Check runner pods
kubectl get pods -n arc-frontend-runners

# View ARC controller logs
kubectl logs -n arc-systems -l app.kubernetes.io/component=controller-manager

# Check ArgoCD sync status
argocd app list | grep runners
```

## Support

- **Issues**: [GitHub Issues](https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/issues)
- **Documentation**: Check the [docs/](docs/) directory for troubleshooting guides
- **Infrastructure**: See main infrastructure repo for Rackspace Spot details

## License

Maintained by Matchpoint-AI Engineering Team.

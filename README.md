# Matchpoint GitHub Runners Helm Charts

This repository contains Helm charts and Terraform infrastructure for deploying GitHub Actions Runner Scale Set (ARC) in the Matchpoint-AI organization.

## Charts

- **github-actions-controller**: Helm chart for the GitHub Actions Runner Scale Set Controller
- **github-actions-runners**: Helm chart for deploying GitHub Actions runners for specific repositories

## Repository Structure

```
charts/
├── github-actions-controller/     # ARC Controller chart
└── github-actions-runners/        # Runner scale set chart
terraform/                         # Rackspace Spot infrastructure
├── modules/
│   ├── cloudspace/               # Kubernetes cluster module
│   ├── nodepool/                 # Worker node pool module
│   └── argocd/                   # ArgoCD installation module
docs/                              # Generated chart documentation
index.yaml                         # Helm repository index
```

## Infrastructure Naming Convention

This repository follows a standardized naming convention for multi-purpose infrastructure:

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

### Configuration

The naming convention is configured via Terraform variables:

```hcl
# terraform/variables.tf
variable "purpose" {
  default = "github-runners"  # Override for different purposes
}

variable "region" {
  default = "us-central-dfw-1"  # Extracted to "dfw"
}

# Environment is set via terraform workspace (prod, staging, dev)
```

### Node Labels

Worker nodes are automatically labeled with purpose identifiers:

```yaml
matchpoint.ai/purpose: github-runners
matchpoint.ai/environment: prod
matchpoint.ai/runner-pool: github-actions
```

## Usage

### Add the Helm Repository

```bash
helm repo add matchpoint-runners https://matchpoint-ai.github.io/matchpoint-github-runners-helm
helm repo update
```

### Install the Controller

```bash
helm install arc matchpoint-runners/github-actions-controller -n arc-systems --create-namespace
```

### Deploy Runners for a Repository

```bash
helm install my-runners matchpoint-runners/github-actions-runners \
  --set githubConfigUrl=https://github.com/Matchpoint-AI/my-repo \
  --set githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-runners --create-namespace
```

## Documentation

- [Deployment Guide](DEPLOYMENT.md) - Detailed deployment instructions
- [Kubeconfig Workflow](docs/KUBECONFIG_WORKFLOW.md) - How to access and interact with the cluster
- [Troubleshooting](docs/TROUBLESHOOTING_EMPTY_LABELS.md) - Common issues and solutions
- [Scaling Guide](SCALING.md) - Runner scaling strategies

## Cluster Access

To interact with the deployed runners, you need cluster access. See the [Kubeconfig Workflow Guide](docs/KUBECONFIG_WORKFLOW.md) for detailed instructions on obtaining and using kubeconfig.

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

## Chart Development

This repository follows Helm best practices:
- Charts are stored in the `charts/` directory
- Chart documentation is auto-generated in `docs/`
- GitHub Pages serves the repository index
- Semantic versioning for chart releases

## Contributing

1. Make changes to charts in the `charts/` directory
2. Update chart versions following semantic versioning
3. Test charts locally before submitting PR
4. Charts are automatically packaged and published on merge to main
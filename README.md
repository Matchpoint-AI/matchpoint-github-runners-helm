# Matchpoint GitHub Runners Helm Charts

This repository contains Helm charts for deploying GitHub Actions Runner Scale Set (ARC) in the Matchpoint-AI organization.

## Charts

- **github-actions-controller**: Helm chart for the GitHub Actions Runner Scale Set Controller
- **github-actions-runners**: Helm chart for deploying GitHub Actions runners for specific repositories

## Repository Structure

```
charts/
├── github-actions-controller/     # ARC Controller chart
└── github-actions-runners/        # Runner scale set chart
docs/                              # Generated chart documentation
index.yaml                         # Helm repository index
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
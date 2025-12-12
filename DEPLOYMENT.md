# Deployment Guide

This guide explains how to deploy GitHub Actions Runner Scale Sets using these Helm charts.

## Prerequisites

1. Kubernetes cluster with sufficient resources
2. Helm 3.x installed
3. GitHub Personal Access Token with `repo` and `admin:org` permissions

## Quick Start

### 1. Install the Controller

First, install the GitHub Actions Runner Scale Set Controller:

```bash
# Add the repository (once released)
helm repo add matchpoint-runners https://matchpoint-ai.github.io/matchpoint-github-runners-helm
helm repo update

# Install the controller
helm install arc matchpoint-runners/github-actions-controller \
  -n arc-systems \
  --create-namespace
```

### 2. Deploy Runners for Your Repository

Choose the appropriate configuration based on your repository type:

#### Frontend Repository (Node.js/Docker)

```bash
helm install arc-frontend-runners matchpoint-runners/github-actions-runners \
  -f examples/frontend-runners-values.yaml \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-frontend-runners \
  --create-namespace
```

#### API Repository (Python/Docker)

```bash
helm install arc-api-runners matchpoint-runners/github-actions-runners \
  -f examples/api-runners-values.yaml \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-api-runners \
  --create-namespace
```

#### Organization-level Runners (Python with Persistent Storage)

```bash
helm install arc-runners matchpoint-runners/github-actions-runners \
  -f examples/runners-values.yaml \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-runners \
  --create-namespace
```

## Development Deployment

For local development or testing from this repository:

### 1. Install Controller

```bash
cd charts/github-actions-controller
helm dependency update
helm install arc . -n arc-systems --create-namespace
```

### 2. Install Runners

```bash
cd charts/github-actions-runners
helm dependency update
helm install my-runners . \
  -f ../../examples/frontend-runners-values.yaml \
  --set gha-runner-scale-set.githubConfigSecret.github_token=YOUR_TOKEN \
  -n arc-runners \
  --create-namespace
```

## Configuration

### GitHub Token Requirements

Your GitHub token needs these permissions:
- `repo` (Full control of private repositories)
- `admin:org` > `manage_runners:org` (Manage organization runners)

### Storage Classes

The beta runners use persistent storage. Ensure your cluster has a `standard-rwo` storage class, or modify the `storageClassName` in the values file.

### Resource Requirements

Default resource requests per runner:
- **Frontend/API**: 2 CPU, 4Gi memory
- **Beta**: 2 CPU, 4Gi memory (with persistent 35Gi storage)

## Monitoring

Check runner status:

```bash
# View AutoScalingRunnerSet resources
kubectl get autoscalingrunnerset -A

# Check runner pods
kubectl get pods -n arc-frontend-runners
kubectl get pods -n arc-api-runners
kubectl get pods -n arc-runners

# View controller logs
kubectl logs -n arc-systems deployment/arc-gha-rs-controller
```

## Troubleshooting

### Runners not picking up jobs

1. Check if runners are registered in GitHub:
   - Go to repository Settings > Actions > Runners
   - Verify runners appear in the list

2. Check runner pod logs:
   ```bash
   kubectl logs -n <namespace> <runner-pod-name>
   ```

3. Verify GitHub token permissions

### Storage issues (Organization runners)

1. Check if storage class exists:
   ```bash
   kubectl get storageclass
   ```

2. View PVC status:
   ```bash
   kubectl get pvc -n arc-runners
   ```

## Scaling

Adjust runner counts by updating the values:

```bash
helm upgrade my-runners matchpoint-runners/github-actions-runners \
  --set gha-runner-scale-set.minRunners=2 \
  --set gha-runner-scale-set.maxRunners=20 \
  -n arc-runners
```
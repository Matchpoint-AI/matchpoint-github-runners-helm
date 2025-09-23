# Scaling GitHub Actions Runners

This document explains how to scale GitHub Actions runners horizontally and vertically using the parameterized configuration.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     repositories.yaml                        │
│  (Repository definitions with scaling parameters)            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  ArgoCD ApplicationSet                       │
│  (Dynamically generates runner deployments)                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Deployments                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Frontend   │  │    API     │  │    Beta    │  ...        │
│  │  Runners   │  │  Runners   │  │  Runners   │            │
│  └────────────┘  └────────────┘  └────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Key Configuration Files

### 1. `values/base-config.yaml`
Central configuration for scaling parameters:
- **Resource profiles** (small, medium, large, xlarge)
- **Autoscaling policies**
- **Storage configurations**
- **Category-specific settings**

### 2. `values/repositories.yaml`
Repository-to-runner mappings:
- **Repository definitions**
- **Min/max runner counts**
- **Resource profile assignments**
- **Custom labels and environment variables**

## Scaling Methods

### 1. Horizontal Scaling (Adding More Runners)

#### Quick Scale Command
```bash
# Scale frontend runners to handle more concurrent jobs
./scripts/scale-runners.sh project-beta-frontend 5 30

# Scale API runners down during quiet periods
./scripts/scale-runners.sh project-beta-api 0 5
```

#### Manual Configuration
Edit `values/repositories.yaml`:
```yaml
- name: project-beta-frontend
  scaling:
    minRunners: 5    # Increased from 1
    maxRunners: 30   # Increased from 15
```

Then commit and push:
```bash
git add values/repositories.yaml
git commit -m "Scale frontend runners for peak load"
git push
```

### 2. Vertical Scaling (Changing Resource Allocations)

#### Change Resource Profile
Edit `values/repositories.yaml`:
```yaml
- name: project-beta-api
  profile: large  # Changed from medium
```

#### Custom Resource Override
```yaml
- name: project-beta
  profile: large
  # Override specific resources
  resources:
    cpu:
      request: "6"
      limit: "10"
    memory:
      request: "12Gi"
      limit: "20Gi"
```

### 3. Adding New Repositories

Add to `values/repositories.yaml`:
```yaml
- name: new-repository
  org: Matchpoint-AI
  category: backend
  scaling:
    minRunners: 1
    maxRunners: 10
  profile: medium
  labels:
    - new-repo-runners
    - self-hosted
    - linux
```

## Resource Profiles

| Profile | CPU Request | CPU Limit | Memory Request | Memory Limit | Use Case |
|---------|------------|-----------|----------------|--------------|----------|
| small   | 500m       | 1         | 1Gi           | 2Gi         | Lightweight CI tasks |
| medium  | 2          | 3         | 4Gi           | 6Gi         | Standard builds |
| large   | 4          | 6         | 8Gi           | 12Gi        | Heavy compilation |
| xlarge  | 8          | 12        | 16Gi          | 24Gi        | ML/Data processing |

## Environment-Specific Scaling

### Development Environment
```bash
# Use 50% of production capacity
export ENVIRONMENT=development
# Runners will use smaller profiles and reduced max counts
```

### Production Environment
```bash
# Full capacity with HA settings
export ENVIRONMENT=production
# Includes pod anti-affinity and zone spreading
```

## Autoscaling Behavior

### Scale-Up Policy
- **Trigger**: When pending jobs detected
- **Response**: Scale up by 100% or add 5 pods (whichever is greater)
- **Stabilization**: 60 seconds

### Scale-Down Policy
- **Trigger**: When runners idle for 10+ minutes
- **Response**: Scale down by 50% or remove 2 pods (whichever is smaller)
- **Stabilization**: 300 seconds (5 minutes)

## Monitoring Scaling

### Check Current Scale
```bash
# View all runner counts
kubectl get autoscalingrunnerset -A

# Check specific repository
kubectl get autoscalingrunnerset -n arc-project-beta-frontend-runners
```

### View Scaling Events
```bash
# Check ArgoCD sync status
argocd app list | grep runners

# View scaling events
kubectl get events -n arc-systems | grep scale
```

## Cost Optimization

### 1. Time-Based Scaling
```bash
# Scale up during business hours (via cron job)
0 8 * * 1-5 ./scripts/scale-runners.sh project-beta-frontend 5 20

# Scale down after hours
0 18 * * 1-5 ./scripts/scale-runners.sh project-beta-frontend 1 5
```

### 2. Repository-Based Optimization
- **Active repos**: Higher min runners for faster response
- **Inactive repos**: Set minRunners to 0
- **Batch processing**: Use xlarge profile but fewer runners

### 3. Spot Instances
Configure in `values/base-config.yaml`:
```yaml
nodeSelector:
  node.kubernetes.io/instance-type: spot
tolerations:
- key: "spot"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

## Troubleshooting

### Runners Not Scaling
1. Check ArgoCD sync status:
   ```bash
   argocd app get <repo-name>-runners
   ```

2. Verify GitHub token:
   ```bash
   kubectl get secret -n arc-<repo>-runners
   ```

3. Check controller logs:
   ```bash
   kubectl logs -n arc-systems deployment/arc-gha-rs-controller
   ```

### Performance Issues
1. Check resource usage:
   ```bash
   kubectl top pods -n arc-<repo>-runners
   ```

2. Increase profile size in `repositories.yaml`

3. Enable monitoring to identify bottlenecks

## Best Practices

1. **Start Conservative**: Begin with smaller profiles and scale up as needed
2. **Monitor Actively**: Watch job queue times and runner utilization
3. **Use Categories**: Group similar repositories for consistent configuration
4. **Regular Reviews**: Audit scaling parameters monthly
5. **Cost Tracking**: Tag resources and monitor cloud spend
6. **Gradual Changes**: Scale incrementally rather than dramatic jumps

## Example Scenarios

### High-Traffic Repository
```yaml
- name: main-application
  scaling:
    minRunners: 3      # Always ready
    maxRunners: 50     # Handle spikes
  profile: large       # Sufficient resources
  priorityClass: high  # Kubernetes priority
```

### Batch Processing Repository
```yaml
- name: data-pipeline
  scaling:
    minRunners: 0      # Scale to zero
    maxRunners: 5      # Limited concurrency
  profile: xlarge     # High resources per runner
```

### Development Repository
```yaml
- name: experimental-features
  scaling:
    minRunners: 0      # On-demand only
    maxRunners: 3      # Limited resources
  profile: small      # Minimal resources
```
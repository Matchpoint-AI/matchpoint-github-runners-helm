# Troubleshooting GitHub Actions Runners

This document covers common issues with ARC (Actions Runner Controller) runners and their solutions.

## Issue #72: Jobs Stuck in Queued State

### Problem
Jobs remain in queued state for 2-5+ minutes before execution, particularly affecting:
- `project-beta-api` (Backend)
- `project-beta` (Terraform)
- Any repository using the `arc-beta-runners` pool

### Root Cause
**minRunners was set to 0** in `examples/beta-runners-values.yaml`, causing cold-start delays:

1. No pre-warmed runners available
2. Every job triggers new pod creation
3. Pod lifecycle adds 2-5 minutes:
   - Kubernetes scheduling
   - Image pull (`ghcr.io/actions/actions-runner:latest`)
   - Runner registration with GitHub
   - Job assignment

### Solution (Implemented)
**Changed minRunners from 0 to 2** in:
- `examples/beta-runners-values.yaml`
- `values/repositories.yaml` (aligned all beta pool repos)

**Impact:**
- Queue time: **2-5 minutes → <10 seconds**
- Cost increase: **~$150-300/month** (2 always-on small pods)
- Developer velocity: **Immediate CI feedback**

### Why minRunners > 0 Matters

#### With minRunners = 0 (BEFORE)
```
Job Queued → Wait for ARC controller → Schedule pod → Pull image →
Start container → Register runner → Job starts
Total: 120-300 seconds
```

#### With minRunners = 2 (AFTER)
```
Job Queued → Assign to pre-warmed runner → Job starts
Total: 5-10 seconds
```

### Configuration Details

| Runner Pool | Repos Served | minRunners | maxRunners | Purpose |
|-------------|--------------|------------|------------|---------|
| arc-beta-runners | project-beta<br>project-beta-api<br>(org-level) | 2 | 20 | Always-ready for common CI |
| arc-frontend-runners | project-beta-frontend | 2 | 15 | Pre-warmed for frontend builds |

## Monitoring Runner Health

### Check Current Scale
```bash
# View all runner scale sets
kubectl get autoscalingrunnerset -A

# Check specific runner pool
kubectl get autoscalingrunnerset -n arc-beta-runners-new

# Get detailed pod status
kubectl get pods -n arc-beta-runners-new
```

### View Scaling Events
```bash
# Check recent scaling activity
kubectl get events -n arc-systems --sort-by='.lastTimestamp' | grep -i scale

# Check ArgoCD sync status
argocd app get arc-beta-runners-new
argocd app get arc-frontend-runners
```

### Monitor Queue Times
```bash
# Check runner logs
kubectl logs -n arc-systems deployment/arc-gha-rs-controller --tail=100

# Watch pod creation in real-time
kubectl get pods -n arc-beta-runners-new -w
```

### Verify Runner Registration
```bash
# Check if runners are registered with GitHub
# Go to: https://github.com/organizations/Matchpoint-AI/settings/actions/runners

# Or use GitHub CLI
gh api /orgs/Matchpoint-AI/actions/runners --jq '.runners[] | {name, status, busy}'
```

## Common Issues and Fixes

### Issue: Runners not scaling up

**Symptoms:**
- Jobs queue even when below maxRunners
- `kubectl get autoscalingrunnerset` shows 0/0 runners

**Diagnosis:**
```bash
# Check controller logs
kubectl logs -n arc-systems deployment/arc-gha-rs-controller

# Check for GitHub token issues
kubectl get secret -n arc-beta-runners-new arc-org-github-secret -o yaml
```

**Solutions:**
1. Verify GitHub token is valid and has `repo` permissions
2. Check controller has proper RBAC permissions
3. Verify ArgoCD application is synced

### Issue: Pods stuck in Pending

**Symptoms:**
- Pods created but never start
- `kubectl get pods` shows Pending status

**Diagnosis:**
```bash
# Check why pod is pending
kubectl describe pod <pod-name> -n arc-beta-runners-new

# Check node capacity
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Solutions:**
1. Insufficient node resources - scale up cluster
2. Storage class not available - verify `standard-rwo` exists
3. Node selector/affinity not matching - check pod spec

### Issue: Runners start but jobs timeout

**Symptoms:**
- Runner picks up job but execution takes too long
- Tests timeout after 20+ minutes

**Diagnosis:**
```bash
# Check runner pod resources
kubectl top pods -n arc-beta-runners-new

# Check if pod is being OOM killed
kubectl get events -n arc-beta-runners-new | grep -i oom
```

**Solutions:**
1. Increase resource limits in values file
2. Optimize test suite (use test splitting, caching)
3. Check for memory leaks in application

### Issue: Image pull errors

**Symptoms:**
- Pods stuck in ImagePullBackOff
- Long delays during pod startup

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n arc-beta-runners-new | grep -i image

# Verify image exists
docker pull ghcr.io/actions/actions-runner:latest
```

**Solutions:**
1. Add image pull secrets if using private registry
2. Use node image cache
3. Consider using `imagePullPolicy: IfNotPresent`

## Performance Optimization

### Quick Wins

1. **Pre-warm runners** (implemented in #72)
   - Set `minRunners >= 2` for active repositories
   - Reduces queue time from minutes to seconds

2. **Use persistent caching**
   - npm cache: Configured in frontend runners
   - pip cache: Configured in beta runners
   - Docker layer cache: Uses overlay2 storage driver

3. **Right-size resources**
   - Small: Lightweight tasks (linting, formatting)
   - Medium: Standard builds
   - Large: Heavy compilation, frontend builds
   - XLarge: Terraform, complex integration tests

4. **Optimize image pull**
   - Use `imagePullPolicy: IfNotPresent`
   - Pre-cache images on nodes
   - Use smaller base images

### Advanced Optimizations

See `values/performance-optimized.yaml` for:
- Aggressive autoscaling policies
- BuildKit for faster Docker builds
- Parallel initialization
- Network and storage optimizations

## Cost Management

### Current Configuration Costs

**Beta Runners (minRunners=2):**
- 2 pods × 4 CPU × 12Gi RAM each
- ~$150-300/month for always-on capacity
- Scales to 20 pods during peak load

**Frontend Runners (minRunners=2):**
- 2 pods × 4 CPU × 8Gi RAM (runner) + 2 CPU × 4Gi (dind)
- ~$200-400/month for always-on capacity
- Scales to 15 pods during peak load

### Cost Optimization Strategies

1. **Time-based scaling** (see `values/global-scaling.yaml`):
   ```yaml
   # Scale down during off-hours
   - schedule: "0 18 * * 1-5"   # 6 PM weekdays
     preset: economy
   ```

2. **Repository prioritization**:
   - Critical repos: Higher minRunners
   - Inactive repos: minRunners = 0

3. **Spot instances**:
   - Use preemptible nodes for non-critical runners
   - Save 60-80% on compute costs

4. **Right-sizing**:
   - Monitor actual resource usage
   - Downgrade over-provisioned profiles

## Alerting Recommendations

### Key Metrics to Monitor

1. **Queue Time** - Alert if > 2 minutes
2. **Runner Utilization** - Alert if < 20% (over-provisioned) or > 90% (under-provisioned)
3. **Pod Failures** - Alert on OOM kills, crashes
4. **Scale-up Latency** - Alert if pod creation > 60s

### Sample Prometheus Alerts

```yaml
groups:
  - name: arc-runners
    rules:
      - alert: HighRunnerQueueTime
        expr: github_runner_queue_time_seconds > 120
        for: 5m
        annotations:
          summary: "Jobs queuing for too long"

      - alert: NoRunnersAvailable
        expr: github_runner_available_count == 0
        for: 2m
        annotations:
          summary: "No runners available for jobs"

      - alert: RunnerPodPending
        expr: kube_pod_status_phase{namespace=~"arc-.*",phase="Pending"} > 0
        for: 5m
        annotations:
          summary: "Runner pod stuck in Pending"
```

## Emergency Procedures

### Immediate Scale-up

If you need immediate capacity:

```bash
# Temporarily increase minRunners
kubectl patch autoscalingrunnerset arc-beta-runners \
  -n arc-beta-runners-new \
  --type merge \
  -p '{"spec":{"minRunners":5}}'

# Or edit directly
kubectl edit autoscalingrunnerset arc-beta-runners -n arc-beta-runners-new
```

### Force Runner Restart

If runners are misbehaving:

```bash
# Delete all runner pods (they'll recreate)
kubectl delete pods -n arc-beta-runners-new -l app.kubernetes.io/name=gha-runner-scale-set

# Or restart specific pod
kubectl delete pod <pod-name> -n arc-beta-runners-new
```

### Disable Auto-scaling

If you need to debug:

```bash
# Set min=max to prevent scaling
kubectl patch autoscalingrunnerset arc-beta-runners \
  -n arc-beta-runners-new \
  --type merge \
  -p '{"spec":{"minRunners":3,"maxRunners":3}}'
```

## Related Documentation

- [SCALING.md](./SCALING.md) - Detailed scaling guide
- [values/performance-optimized.yaml](./values/performance-optimized.yaml) - Performance tuning
- [values/global-scaling.yaml](./values/global-scaling.yaml) - Global scaling controls
- [Issue #72](https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/issues/72) - Original queue time investigation
- [Issue #67](https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/issues/67) - Initial symptom report

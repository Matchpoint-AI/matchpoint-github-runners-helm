# Troubleshooting: ARC Runners with Empty Labels

## Problem

Runners registered with GitHub showing empty labels `[]` and `os: "unknown"`, causing all CI jobs to queue indefinitely.

## Root Cause

**ACTIONS_RUNNER_LABELS environment variable does not work with ARC (Actions Runner Controller).**

### Why This Happens

According to [GitHub's official documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/using-actions-runner-controller-runners-in-a-workflow):

> "You cannot use additional labels to target runners created by ARC. You can only use the installation name of the runner scale set that you specified during the installation or by defining the value of the `runnerScaleSetName` field in your values.yaml file."

### How ARC Labels Work

1. **Single Label**: ARC only supports ONE label - the `runnerScaleSetName`
2. **Automatic Labels**: ARC adds `self-hosted`, OS, and architecture labels automatically (as of certain versions)
3. **No Custom Labels**: The `ACTIONS_RUNNER_LABELS` env var is completely ignored

## Diagnosis

### Check Current Runner Status

```bash
gh api /orgs/Matchpoint-AI/actions/runners --jq '.runners[] | {name, status, labels: [.labels[].name], os}'
```

**Symptoms of the issue:**
```json
{
  "name": "arc-runners-w74pg-runner-2xppt",
  "status": "online",
  "labels": [],
  "os": "unknown"
}
```

### Check Deployed Configuration

1. **Check the AutoscalingRunnerSet name:**
```bash
kubectl get autoscalingrunnerset -A
```

1. **Check runner pods:**
```bash
kubectl get pods -n arc-runners -l app.kubernetes.io/component=runner
```

1. **Check ARC controller logs:**
```bash
kubectl logs -n arc-systems -l app.kubernetes.io/component=controller-manager --tail=100
```

## Solution

### Step 1: Fix Values Files

Remove `ACTIONS_RUNNER_LABELS` environment variable from:
- `examples/runners-values.yaml`
- `examples/frontend-runners-values.yaml`

The only label that matters is `runnerScaleSetName`:

```yaml
gha-runner-scale-set:
  runnerScaleSetName: "arc-beta-runners"  # This becomes the GitHub label
```

### Step 2: Ensure Consistency

Make sure:
1. `runnerScaleSetName` matches what workflows expect
2. All workflows use the same `runs-on:` label
3. ArgoCD has synced the latest configuration

### Step 3: Verify Helm Template

```bash
helm template arc-runners ./charts/github-actions-runners \
  -f examples/runners-values.yaml \
  --namespace arc-runners \
  | grep -A 5 "kind: AutoscalingRunnerSet"
```

Should show:
```yaml
kind: AutoscalingRunnerSet
metadata:
  name: arc-beta-runners  # Must match runnerScaleSetName
```

### Step 4: Sync ArgoCD

If using ArgoCD:
```bash
argocd app sync arc-runners --force
```

Or via kubectl:
```bash
kubectl patch application arc-runners -n argocd -p '{"operation":{"initiatedBy":{"automated":true}}}' --type=merge
```

### Step 5: Force Runner Re-registration

Delete existing runner pods to force re-registration:
```bash
kubectl delete pods -n arc-runners -l app.kubernetes.io/component=runner
```

### Step 6: Verify Fix

```bash
# Wait 1-2 minutes for runners to re-register
gh api /orgs/Matchpoint-AI/actions/runners --jq '.runners[] | {name, labels: [.labels[].name], os}'
```

Should now show:
```json
{
  "name": "arc-beta-runners-xxxxx-runner-yyyyy",
  "labels": ["arc-beta-runners", "self-hosted", "Linux", "X64"],
  "os": "Linux"
}
```

## Common Pitfalls

### Pitfall 1: Release Name vs runnerScaleSetName

- **Helm release name** determines the Kubernetes resource name
- **runnerScaleSetName** determines the GitHub label
- These can be different, but runnerScaleSetName must match your workflows

### Pitfall 2: Multiple Label Requirements

If you need runners to support multiple labels (e.g., both `arc-runners` AND `arc-beta-runners`):

**Solution**: Create two separate runner scale sets:
```yaml
# Set 1: arc-runners
runnerScaleSetName: "arc-runners"

# Set 2: arc-beta-runners
runnerScaleSetName: "arc-beta-runners"
```

**Alternative**: Update all workflows to use the same label.

### Pitfall 3: ArgoCD Not Syncing

ArgoCD may not auto-sync if:
- Changes are in values files only
- Sync is disabled
- There are sync errors

Force sync with:
```bash
argocd app sync arc-runners --force --prune
```

## Prevention

1. **Use only `runnerScaleSetName`** - Never rely on `ACTIONS_RUNNER_LABELS` with ARC
2. **Verify before merge** - Template the chart and check the AutoscalingRunnerSet name
3. **Monitor runners** - Set up alerts for runners with empty labels
4. **Document expectations** - Add comments in values files about label behavior

## References

- [Using ARC Runners in Workflows](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/using-actions-runner-controller-runners-in-a-workflow)
- [Deploying Runner Scale Sets](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/deploy-runner-scale-sets)
- [ARC Issue #3330: Missing self-hosted label](https://github.com/actions/actions-runner-controller/issues/3330)
- [ARC Issue #2802: AutoscalingRunnerSet naming](https://github.com/actions/actions-runner-controller/issues/2802)

## See Also

- [docs/SCALING.md](../SCALING.md) - Runner scaling configuration
- [argocd/README.md](../argocd/README.md) - ArgoCD management guide

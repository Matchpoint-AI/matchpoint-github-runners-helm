# spotctl - Rackspace Spot CLI

CLI tool for inspecting and managing Rackspace Spot resources outside of Terraform.

**Repository**: https://pkg.go.dev/github.com/rackspace-spot/spotctl

## Why Use spotctl?

| Use Case | Benefit |
|----------|---------|
| **Real-time visibility** | Queries actual API, not potentially stale Terraform state |
| **Faster feedback** | Sub-second execution vs full `terraform plan` |
| **Debugging** | Verify resources exist, check bid status, find orphans |
| **Recovery** | Handle corrupted Terraform state, out-of-band cleanup |
| **Verification** | Cross-check Terraform's view with actual API state |

## Installation

```bash
go install github.com/rackspace-spot/spotctl@latest
```

## Configuration

Config file: `~/.spot_config` (YAML format)

```yaml
org: "matchpoint-ai"
refreshToken: "your-api-token"
accessToken: "your-api-token"
region: "us-central-dfw-1"
```

**Getting the token**: Use `RACKSPACE_SPOT_API_TOKEN` from GitHub org secrets.

### IMPORTANT: Org Name vs Org ID

The `--org` flag requires the **org name**, NOT the org ID:

```bash
# WRONG - uses org ID (returns "organization not found")
spotctl cloudspaces list --org org_au2pnWWpLOp2vssn

# CORRECT - uses org name
spotctl cloudspaces list --org matchpoint-ai
```

To find your org name:
```bash
spotctl organizations list -o json
# Returns: [{"name": "matchpoint-ai", "id": "org_au2pnWWpLOp2vssn"}]
# Use the "name" field, not "id"
```

## Key Commands

### Organizations
```bash
# List organizations (to get org name)
spotctl organizations list -o table
```

### Cloudspaces (Kubernetes Clusters)
```bash
# List all cloudspaces
spotctl cloudspaces list --org matchpoint-ai -o table

# Get details of a specific cloudspace
spotctl cloudspaces get --name matchpoint-runners-prod --org matchpoint-ai -o json

# Get kubeconfig for kubectl access
spotctl cloudspaces get-config --name matchpoint-runners-prod --org matchpoint-ai > kubeconfig.yaml

# Delete a cloudspace (use for orphan cleanup)
spotctl cloudspaces delete --name <cloudspace-name> --org matchpoint-ai
```

### Node Pools
```bash
# List node pools
spotctl nodepools list --org matchpoint-ai -o table
```

### Infrastructure Info
```bash
# List available regions
spotctl regions list -o table

# List available server classes
spotctl serverclasses list --org matchpoint-ai -o table

# View pricing
spotctl pricing --org matchpoint-ai
```

## Common Workflows

### 1. Verify Terraform Changes Took Effect
```bash
# After terraform apply, confirm resources exist
spotctl cloudspaces list --org matchpoint-ai -o table
```

### 2. Debug "Resource Not Found" Errors
```bash
# Check if resource actually exists in the API
spotctl cloudspaces get --name matchpoint-runners-prod --org matchpoint-ai -o json
```

### 3. Check Node Pool Status and Bid Results
```bash
# View won count, bid status, and node details
spotctl cloudspaces list --org matchpoint-ai -o json | jq '.cloudspaces[].spotNodepools[]'
```

### 4. Get Kubeconfig for Debugging
```bash
# Fetch kubeconfig and use with kubectl
spotctl cloudspaces get-config --name matchpoint-runners-prod --org matchpoint-ai > /tmp/kubeconfig.yaml
kubectl --kubeconfig=/tmp/kubeconfig.yaml get nodes
kubectl --kubeconfig=/tmp/kubeconfig.yaml get pods -A
```

### 5. Clean Up Orphaned Resources
When Terraform state is corrupted or resources exist outside of Terraform:
```bash
# List to find orphans
spotctl cloudspaces list --org matchpoint-ai -o table

# Delete orphaned cloudspace
spotctl cloudspaces delete --name orphaned-cloudspace --org matchpoint-ai
```

### 6. Compare Terraform State vs Reality
```bash
# Terraform's view
terraform state list | grep cloudspace

# API's view (ground truth)
spotctl cloudspaces list --org matchpoint-ai -o json | jq '.cloudspaces[].name'
```

## Output Formats

All commands support `-o` / `--output` flag:
- `json` - JSON output (default, good for scripting)
- `table` - Human-readable table
- `yaml` - YAML output

## Troubleshooting

### "organization not found" Error
You're using the org ID instead of org name. Use `matchpoint-ai`, not `org_au2pnWWpLOp2vssn`.

### "spot config not found" Error
Create `~/.spot_config` with your credentials (see Configuration section above).

### "refresh token is required" Error
Your config file is missing the `refreshToken` field or has incorrect YAML syntax.

## Integration with Terraform Workflow

1. **Before `terraform apply`**: Use spotctl to check current state
2. **After `terraform apply`**: Verify changes with spotctl
3. **On errors**: Use spotctl to debug actual resource state
4. **State drift**: Compare `terraform state list` with `spotctl cloudspaces list`
5. **Recovery**: Use spotctl to clean up before `terraform import`

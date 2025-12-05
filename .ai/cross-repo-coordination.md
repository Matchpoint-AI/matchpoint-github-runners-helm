# Cross-Repository Coordination

## Overview

This repository (`matchpoint-github-runners-helm`) provides GitHub Actions self-hosted runners for the entire Matchpoint organization. Changes here affect all repositories that use self-hosted runners.

## Prerequisites (MANDATORY)

**NEVER start work without a GitHub issue.**

Before making ANY changes, verify a GitHub issue exists for the work.

## GitHub Issue Commenting Protocol (CRITICAL)

**Comment every 3-5 minutes during active work.**

For cross-repo changes, always document the impact:

```markdown
[PLANNING] Updating runner resource limits.

**Impact Assessment:**
- project-beta: Will affect Terraform CI builds
- project-beta-api: Will affect API test suite
- project-beta-frontend: Will affect E2E tests

**Coordination Required:** None (backwards compatible)
```

## Repository Relationship Map

```
┌─────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                          │
│                                                                   │
│  matchpoint-github-runners-helm                                   │
│  ├── terraform/    → Rackspace Spot Kubernetes cluster           │
│  ├── charts/       → ARC controller + runner Helm charts         │
│  └── argocd/       → ArgoCD application manifests                │
│                                                                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ Provides self-hosted runners
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CONSUMER REPOSITORIES                          │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐   │
│  │   project-beta   │  │ project-beta-api│  │project-beta-    │   │
│  │   (Terraform)   │  │    (Backend)    │  │   frontend      │   │
│  │                 │  │                 │  │   (Frontend)    │   │
│  │ uses: runners   │  │ uses: runners   │  │ uses: runners   │   │
│  │ for: infra CI   │  │ for: API tests  │  │ for: E2E tests  │   │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Dependency Direction

**This repo is upstream** - Changes here flow downstream to consumers.

| Direction | From | To | Type |
|-----------|------|-----|------|
| Downstream | runners-helm | project-beta | Runner availability |
| Downstream | runners-helm | project-beta-api | Runner availability |
| Downstream | runners-helm | project-beta-frontend | Runner availability |
| Upstream | project-beta | runners-helm | Infrastructure (Terraform patterns) |

## Change Impact Matrix

### High Impact Changes

| Change Type | Affected Repos | Coordination Required |
|-------------|----------------|----------------------|
| Runner labels change | All consumers | Update workflow `runs-on` |
| Resource limits decrease | All consumers | Verify builds still pass |
| ARC version upgrade | All consumers | Test runner behavior |
| Kubernetes version change | All consumers | Verify workload compatibility |
| Runner image change | All consumers | Test all workflow types |

### Low Impact Changes

| Change Type | Affected Repos | Coordination Required |
|-------------|----------------|----------------------|
| Scale up runners | None | No coordination |
| Increase resource limits | None | No coordination |
| Documentation updates | None | No coordination |
| Monitoring improvements | None | No coordination |

## Deployment Order

### Adding New Runners

```
1. matchpoint-github-runners-helm
   └── Terraform: Create node pool capacity
   └── Helm: Deploy runner scale set
   └── ArgoCD: Sync application

2. Consumer repos (no changes needed)
   └── Workflows automatically pick up new runners
```

### Breaking Changes (Label Updates)

```
1. Consumer repos (project-beta, api, frontend)
   └── Update workflow files with new labels
   └── Merge PRs (workflows will queue)

2. matchpoint-github-runners-helm
   └── Update runner labels
   └── Deploy new configuration
   └── Queued workflows start running
```

## Version Compatibility

### ARC Versions

| ARC Version | Kubernetes | Status |
|-------------|------------|--------|
| 0.9.x | 1.25+ | Current |
| 0.8.x | 1.24+ | Deprecated |

### Runner Image Versions

| Image | Compatibility |
|-------|---------------|
| `ghcr.io/actions/actions-runner:latest` | GitHub-hosted parity |
| Custom images | Must include runner binary |

## Testing Runner Changes

### Before Deploying to Production

1. **Test in isolation:**
   ```bash
   # Create test runner scale set
   helm template test charts/github-actions-runners \
     --set runnerScaleSetName=test-runners \
     --set minRunners=1 \
     --set maxRunners=1
   ```

2. **Run test workflow:**
   ```yaml
   # In any consumer repo
   jobs:
     test:
       runs-on: [self-hosted, test-runners]
       steps:
         - run: echo "Testing runner"
   ```

3. **Verify against consumer workloads:**
   - Run project-beta Terraform plan
   - Run project-beta-api test suite
   - Run project-beta-frontend E2E tests

### Test Workflow Template

```yaml
name: Test Self-Hosted Runners
on: workflow_dispatch

jobs:
  basic:
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - run: |
          echo "Runner: $RUNNER_NAME"
          echo "OS: $(uname -a)"
          echo "Memory: $(free -h)"
          echo "Disk: $(df -h)"
```

## Communication Protocol

### For Breaking Changes

1. **Create coordination issue:**
   ```bash
   gh issue create --repo Matchpoint-AI/matchpoint-github-runners-helm \
     --title "breaking: [Description of change]" \
     --body "## Breaking Change

   **Change:** [Description]
   **Affected Repos:** project-beta, project-beta-api, project-beta-frontend
   **Required Updates:** [What consumers need to do]
   **Timeline:** [When change will be deployed]

   ## Consumer Checklist
   - [ ] project-beta updated
   - [ ] project-beta-api updated
   - [ ] project-beta-frontend updated
   - [ ] All consumers merged
   - [ ] Ready to deploy runners change"
   ```

2. **Cross-link issues:**
   ```bash
   # In each consumer repo
   gh issue create --repo Matchpoint-AI/project-beta \
     --title "Update runner labels for Matchpoint-AI/matchpoint-github-runners-helm#XX" \
     --body "Tracking issue for runner changes."
   ```

3. **Coordinate deployment:**
   - Wait for all consumer PRs to merge
   - Deploy runner changes
   - Verify all CI pipelines pass

### For Non-Breaking Changes

Post in runner repo issue:

```markdown
[DEPLOYED] Runner resource limits increased.

**Change:** Memory limit increased from 4Gi to 8Gi
**Impact:** Faster builds, no workflow changes required
**Verification:** Monitored 10 builds across all consumer repos
```

## Recursive Issue Creation

**Rule:** Never fix issues in other repos as part of this ticket.

When you discover issues in consumer repos:
1. **Create a NEW ISSUE** in the appropriate repo
2. Comment in current thread: `[DISCOVERY] Found issue in project-beta. Created Matchpoint-AI/project-beta#XYZ to track.`
3. Stay focused on your current task in this repo

## Emergency Procedures

### Runner Outage

1. Check runner pod status
2. Check controller health
3. Post in #engineering Slack channel
4. Create incident issue

### Rollback Procedure

```bash
# Revert to previous chart version
git revert HEAD
git push

# ArgoCD will auto-sync to previous state
```

## Cross-References

- @.ai/agents/meta-orchestrator.md - Task coordination
- @.ai/agents/arc-troubleshooting.md - Runner debugging
- @.ai/ci-file-groupings.md - CI impact mapping
- @.ai/GITHUB_COMMENTING.md - Full commenting protocol

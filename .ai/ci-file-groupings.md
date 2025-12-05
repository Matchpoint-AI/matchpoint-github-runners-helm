# CI File Groupings

## Overview

This document maps file paths to CI jobs, helping agents understand which CI checks run based on file changes.

## Prerequisites (MANDATORY)

**NEVER start work without a GitHub issue.**

Before making ANY changes, verify a GitHub issue exists for the work.

## GitHub Issue Commenting Protocol (CRITICAL)

**Comment every 3-5 minutes during active work.**

When editing files, note which CI jobs will run:

```markdown
[EDITING] Modifying charts/github-actions-runners/values.yaml

**CI Impact:** This will trigger:
- `lint-test` job (Helm lint and chart-testing)
- `release` job (if merged to main)

**Estimated CI Time:** ~5 minutes for full validation
```

## File Groups

### Terraform Files

| Path Pattern | CI Job | Trigger |
|--------------|--------|---------|
| `terraform/**` | `Terraform` | PR, Push to main |
| `.github/workflows/terraform.yaml` | `Terraform` | PR, Push to main |

**Jobs Triggered:**
- `changes` - Detects if terraform files changed
- `terraform` - Runs fmt, init, validate, plan (apply on main)

**Estimated Time:** 3-5 minutes

### Helm Charts

| Path Pattern | CI Job | Trigger |
|--------------|--------|---------|
| `charts/**` | `Release Charts` | PR, Push to main |
| `.github/workflows/release.yml` | `Release Charts` | PR, Push to main |

**Jobs Triggered:**
- `lint-test` - Helm lint, chart-testing (install on PR)
- `release` - Publish to GitHub Pages (main only)

**Estimated Time:**
- PR: ~8-10 minutes (includes kind cluster + install)
- Push to main: ~3 minutes (lint only + release)

### Documentation

| Path Pattern | CI Job | Trigger |
|--------------|--------|---------|
| `.ai/**` | `Documentation` | PR, Push to main |
| `*.md` (root) | `Documentation` | PR, Push to main |
| `docs/**` | `Documentation` | PR, Push to main |
| `.markdownlint.json` | `Documentation` | PR, Push to main |
| `.github/workflows/docs.yaml` | `Documentation` | PR, Push to main |

**Jobs Triggered:**
- `lint` - Markdown linting

**Estimated Time:** ~1 minute

### Pages (Static Site)

| Path Pattern | CI Job | Trigger |
|--------------|--------|---------|
| (manual) | `pages` | Workflow dispatch |

**Estimated Time:** ~2 minutes

## Skip Conditions

### When CI Can Be Safely Skipped

CI is configured with path filters. These changes don't trigger unnecessary jobs:

| Change Type | Skipped Jobs |
|-------------|--------------|
| Terraform-only changes | Helm, Docs |
| Helm-only changes | Terraform |
| Docs-only changes | Terraform, Helm |
| ArgoCD manifest changes | All (no CI workflow) |
| Values file changes | Terraform (triggers Helm only) |

### Forced Runs

The Terraform workflow always runs on PRs (for required status checks) but exits early via the `changes` job if no terraform files changed.

## CI Job Details

### Terraform Workflow

```yaml
name: Terraform
on:
  push:
    branches: [main]
    paths: ['terraform/**', '.github/workflows/terraform.yaml']
  pull_request:
    branches: [main]
    # No path filter - always runs for status check
```

**Steps:**
1. `changes` - Check if terraform files changed
2. `terraform` (if changes detected):
   - Checkout
   - GCP Auth (Workload Identity Federation)
   - Terraform fmt check
   - Terraform init
   - Terraform validate
   - Terraform plan (PR) / apply (main)

**Required Secrets:**
- `RACKSPACE_SPOT_API_TOKEN`
- `INFRA_GH_TOKEN`
- `SLACK_PREEMPTION_WEBHOOK` (optional)

**Required Variables:**
- `WIF_PROVIDER`
- `WIF_SERVICE_ACCOUNT`

### Helm Release Workflow

```yaml
name: Release Charts
on:
  push:
    branches: [main]
    paths: ['charts/**', '.github/workflows/release.yml']
  pull_request:
    branches: [main]
    paths: ['charts/**', '.github/workflows/release.yml']
```

**Steps:**
1. `lint-test`:
   - Setup Helm v3.14.0
   - Chart-testing lint
   - Create kind cluster (PR only)
   - Chart-testing install (PR only)
2. `release` (main only):
   - Chart-releaser action

### Documentation Workflow

```yaml
name: Documentation
on:
  push:
    branches: [main]
    paths: ['.ai/**', '*.md', 'docs/**', '.markdownlint.json']
  pull_request:
    branches: [main]
    paths: ['.ai/**', '*.md', 'docs/**', '.markdownlint.json']
```

**Steps:**
1. `lint`:
   - markdownlint-cli2-action

## Cross-File Dependencies

Understanding which file changes might require changes in other areas:

| Primary Change | Often Requires |
|----------------|----------------|
| Chart values schema | ArgoCD application updates |
| Terraform outputs | Helm value references |
| New node pool | Runner resource limits |
| ARC version bump | Chart appVersion update |
| New secrets | Terraform + Helm updates |

## Comment Templates

### Before Editing

```markdown
[PLANNING] Updating runner configuration.

**Files to Modify:**
- `charts/github-actions-runners/values.yaml`
- `values/prod.yaml`

**CI Jobs Affected:**
- Release Charts (lint-test, ~8 min)

**Downstream Impact:**
- ArgoCD will auto-sync after merge
```

### After Editing

```markdown
[TESTING] Changes pushed. Monitoring CI.

**Active Jobs:**
- Release Charts: lint-test running
- Documentation: lint running

**Expected Completion:** ~10 minutes

**Monitoring:** https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/actions
```

## Recursive Issue Creation

**Rule:** Never fix CI issues that aren't in your ticket.

When you discover CI problems unrelated to your task:
1. **Create a NEW ISSUE**: `gh issue create --title "ci: description" --body "..."`
2. Comment in current thread: `[DISCOVERY] Found CI issue. Created #XYZ to track.`
3. Stay focused on your current task

## Cross-References

- @.ai/agents/helm-chart-specialist.md - Helm CI details
- @.ai/agents/terraform-specialist.md - Terraform CI details
- @.ai/GITHUB_COMMENTING.md - Full commenting protocol

# Anti-Patterns Reference

## Core Directive

This document catalogs common mistakes to avoid when working with Helm charts, ARC, ArgoCD, and Terraform in this repository.

## Prerequisites (MANDATORY)

**NEVER start work without a GitHub issue.**

Before making ANY changes, verify a GitHub issue exists for the work.

## GitHub Issue Commenting Protocol (CRITICAL)

**Comment every 3-5 minutes during active work.**

When you catch yourself about to use an anti-pattern:

```markdown
[UPDATE] Caught potential anti-pattern.

**Almost Did:** Hardcoded image tag in template
**Correct Approach:** Using .Values.image.tag with default
**Reference:** .ai/agents/anti-patterns.md#helm-anti-patterns
```

## Recursive Issue Creation

**Rule:** Never fix anti-patterns that aren't in your ticket.

When you discover existing anti-patterns:
1. **Create a NEW ISSUE**: `gh issue create --title "refactor: fix anti-pattern - description" --body "..."`
2. Comment in current thread: `[DISCOVERY] Found anti-pattern in existing code. Created #XYZ to track.`
3. Stay focused on your current task

---

## Helm Anti-Patterns

### 1. Hardcoded Values in Templates

**Anti-Pattern:**

```yaml
# templates/runner.yaml
spec:
  containers:
    - name: runner
      image: ghcr.io/actions/actions-runner:2.311.0  # Hardcoded!
      resources:
        limits:
          memory: 4Gi  # Hardcoded!
```

**Correct Pattern:**

```yaml
# templates/runner.yaml
spec:
  containers:
    - name: runner
      image: {{ .Values.runner.image }}:{{ .Values.runner.tag | default .Chart.AppVersion }}
      resources:
        limits:
          memory: {{ .Values.runner.resources.limits.memory }}
```

### 2. Missing Resource Limits

**Anti-Pattern:**

```yaml
# values.yaml
runner:
  image: ghcr.io/actions/actions-runner
  # No resources defined - pods can consume unlimited resources
```

**Correct Pattern:**

```yaml
# values.yaml
runner:
  image: ghcr.io/actions/actions-runner
  resources:
    limits:
      cpu: "2"
      memory: 4Gi
    requests:
      cpu: "1"
      memory: 2Gi
```

> "Without enough memory resources, the controller will be killed. Without enough CPU resources, it will be throttled." - Ken Muse

### 3. No Default Values

**Anti-Pattern:**

```yaml
# templates/runner.yaml
replicas: {{ .Values.replicas }}  # Fails if not set
```

**Correct Pattern:**

```yaml
# templates/runner.yaml
replicas: {{ .Values.replicas | default 1 }}
```

### 4. Undocumented Values

**Anti-Pattern:**

```yaml
# values.yaml
runner:
  min: 1
  max: 10
  img: ghcr.io/actions/actions-runner
```

**Correct Pattern:**

```yaml
# values.yaml
runner:
  # -- Minimum number of idle runners to maintain
  minRunners: 1
  # -- Maximum number of runners to scale up to
  maxRunners: 10
  # -- Container image for the runner
  image: ghcr.io/actions/actions-runner
```

### 5. Missing Conditionals

**Anti-Pattern:**

```yaml
# templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-token
data:
  token: {{ .Values.github.token | b64enc }}  # Fails if token not provided
```

**Correct Pattern:**

```yaml
# templates/secret.yaml
{{- if .Values.github.token }}
apiVersion: v1
kind: Secret
metadata:
  name: github-token
data:
  token: {{ .Values.github.token | b64enc }}
{{- end }}
```

---

## ARC Anti-Patterns

### 1. Persistent Runners for Autoscaling

**Anti-Pattern:**

```yaml
# Using persistent runners with autoscaling
spec:
  template:
    spec:
      containers:
        - name: runner
          # Runner persists between jobs
          lifecycle:
            # No ephemeral cleanup
```

**Correct Pattern:**

```yaml
# Using ephemeral runners (recommended by GitHub)
spec:
  template:
    spec:
      restartPolicy: Never  # Pod terminates after job
      containers:
        - name: runner
          env:
            - name: RUNNER_EPHEMERAL
              value: "true"
```

> "GitHub recommends implementing autoscaling with ephemeral self-hosted runners; autoscaling with persistent self-hosted runners is not recommended." - GitHub Documentation

### 2. Insufficient Controller Resources

**Anti-Pattern:**

```yaml
# Controller with no resource limits
controller:
  resources: {}  # Will be OOMKilled under load
```

**Correct Pattern:**

```yaml
controller:
  resources:
    limits:
      cpu: "500m"
      memory: 512Mi
    requests:
      cpu: "100m"
      memory: 128Mi
```

### 3. No Runner Limits

**Anti-Pattern:**

```yaml
# No maximum runners - can exhaust cluster
runner:
  minRunners: 1
  # maxRunners not set - unlimited scaling
```

**Correct Pattern:**

```yaml
runner:
  minRunners: 1
  maxRunners: 20  # Prevents resource exhaustion
```

### 4. Using PAT Instead of GitHub App

**Anti-Pattern:**

```yaml
# Personal Access Token (expires, broad permissions)
githubConfigSecret:
  github_token: ghp_xxxx
```

**Correct Pattern:**

```yaml
# GitHub App (fine-grained, auto-rotating)
githubConfigSecret:
  github_app_id: "12345"
  github_app_installation_id: "67890"
  github_app_private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----
```

---

## ArgoCD Anti-Patterns

### 1. Branch-Based Environments

**Anti-Pattern:**

```
repo/
├── main       → production
├── staging    → staging
└── develop    → development
```

**Correct Pattern:**

```
repo/
├── environments/
│   ├── prod/values.yaml
│   ├── staging/values.yaml
│   └── dev/values.yaml
└── charts/
    └── app/
```

> "You should NOT have permanent branches for your clusters or environments." - ArgoCD Best Practices

### 2. Secrets in Git

**Anti-Pattern:**

```yaml
# values.yaml (committed to Git)
database:
  password: "super-secret-password"
```

**Correct Pattern:**

```yaml
# Use External Secrets Operator or Sealed Secrets
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  secretStoreRef:
    name: gcp-secret-store
  target:
    name: database-credentials
  data:
    - secretKey: password
      remoteRef:
        key: database-password
```

### 3. Manual Sync Without Auto-Heal

**Anti-Pattern:**

```yaml
spec:
  syncPolicy:
    # No auto-sync - drift goes undetected
```

**Correct Pattern:**

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true  # Corrects drift automatically
```

### 4. Missing Resource Tracking

**Anti-Pattern:**

```yaml
# Application doesn't track all resources
spec:
  source:
    helm:
      skipCrds: true  # CRDs not managed
```

**Correct Pattern:**

```yaml
spec:
  source:
    helm:
      skipCrds: false
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
```

---

## Terraform Anti-Patterns

### 1. Manual State Manipulation

**Anti-Pattern:**

```bash
# Directly editing state file
terraform state rm module.dangerous
terraform import module.dangerous.resource id
```

**Correct Pattern:**

```bash
# Use targeted operations with proper planning
terraform plan -target=module.dangerous
terraform apply -target=module.dangerous
```

### 2. Missing State Locking

**Anti-Pattern:**

```hcl
# backend.tf - no locking configured
terraform {
  backend "gcs" {
    bucket = "tf-state"
    prefix = "runners"
    # No lock table
  }
}
```

**Correct Pattern:**

```hcl
# GCS has built-in locking, but ensure it's not disabled
terraform {
  backend "gcs" {
    bucket = "tf-state"
    prefix = "runners"
  }
}
```

### 3. Hardcoded Provider Versions

**Anti-Pattern:**

```hcl
# No version constraints - breaks on updates
provider "google" {}
```

**Correct Pattern:**

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

### 4. No Output Values

**Anti-Pattern:**

```hcl
# No outputs - downstream consumers can't reference values
resource "google_container_cluster" "runners" {
  name = "runners-cluster"
}
# End of file - no outputs
```

**Correct Pattern:**

```hcl
resource "google_container_cluster" "runners" {
  name = "runners-cluster"
}

output "cluster_endpoint" {
  value       = google_container_cluster.runners.endpoint
  description = "Kubernetes API endpoint"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.runners.master_auth[0].cluster_ca_certificate
  sensitive   = true
  description = "Cluster CA certificate"
}
```

---

## Documentation Anti-Patterns

### 1. Ephemeral Status Files

**Anti-Pattern:**

```
repo/
├── CURRENT_STATUS.md    # Outdated in hours
├── WORK_IN_PROGRESS.md  # Never updated
└── TODO.md              # Stale list
```

**Correct Pattern:**

Use GitHub Issues for tracking:
- Status → Issue comments
- Work in progress → Issue with `in-progress` label
- TODO → Issues with `enhancement` label

### 2. Duplicating GitHub Info in Markdown

**Anti-Pattern:**

```markdown
# Recent Changes
- 2024-01-15: Updated runner limits (PR #45)
- 2024-01-10: Fixed scaling issue (PR #42)
```

**Correct Pattern:**

```markdown
# Changes
See [GitHub Releases](https://github.com/org/repo/releases) for changelog.
```

---

## Quick Reference Checklist

Before committing, verify:

- [ ] No hardcoded values in templates
- [ ] All resources have limits defined
- [ ] Values are documented with `# --` comments
- [ ] Using ephemeral runners for autoscaling
- [ ] No secrets committed to Git
- [ ] Terraform has version constraints
- [ ] No status/tracking markdown files created

## Cross-References

- @.ai/agents/helm-chart-specialist.md - Helm best practices
- @.ai/agents/arc-troubleshooting.md - ARC configuration
- @.ai/agents/terraform-specialist.md - Terraform patterns
- @.ai/GITHUB_COMMENTING.md - Documentation patterns

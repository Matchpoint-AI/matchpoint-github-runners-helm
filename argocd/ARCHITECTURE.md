# App of Apps Architecture

This document provides a visual representation of the App of Apps architecture for the GitHub Runners Helm repository.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                       │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    ArgoCD Namespace                        │ │
│  │                                                            │ │
│  │  ┌──────────────────────────────────────────────────┐    │ │
│  │  │         Root Application (App of Apps)           │    │ │
│  │  │                                                  │    │ │
│  │  │  Source: argocd/apps/                           │    │ │
│  │  │  Auto-sync: Enabled                             │    │ │
│  │  │  Self-heal: Enabled                             │    │ │
│  │  └─────────────┬────────────────────────────────────┘    │ │
│  │                │                                          │ │
│  │                │ Manages                                  │ │
│  │                ▼                                          │ │
│  │  ┌──────────────────────────────────────────────────┐    │ │
│  │  │  Child Applications (managed by root)            │    │ │
│  │  │                                                  │    │ │
│  │  │  1. argocd.yaml (wave: -1)                      │    │ │
│  │  │     └─> ArgoCD manages itself                   │    │ │
│  │  │                                                  │    │ │
│  │  │  2. arc-controller.yaml (wave: 1)               │    │ │
│  │  │     └─> GitHub Actions Runner Controller        │    │ │
│  │  │                                                  │    │ │
│  │  │  3. github-runners-appset.yaml (wave: 2)        │    │ │
│  │  │     └─> ApplicationSet for runners              │    │ │
│  │  └──────────────────────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Deployed Resources                            │ │
│  │                                                            │ │
│  │  Namespace: argocd                                         │ │
│  │  ├─ ArgoCD Server                                          │ │
│  │  ├─ ArgoCD Application Controller                          │ │
│  │  ├─ ArgoCD Repo Server                                     │ │
│  │  └─ ArgoCD ApplicationSet Controller                       │ │
│  │                                                            │ │
│  │  Namespace: arc-systems                                    │ │
│  │  └─ ARC Controller Deployment                              │ │
│  │                                                            │ │
│  │  Namespace: arc-runners                                    │ │
│  │  └─ GitHub Runners AutoScalingRunnerSet                    │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Sync Wave Flow

The deployment follows a specific order using sync waves:

```
Time ─────────────────────────────────────────────────────────>

Wave -1: ArgoCD Self-Management
         │
         ├─> ArgoCD Helm Chart deployed
         └─> ArgoCD components updated/configured
              │
              ▼
Wave 0:  Root Application (default, already exists)
              │
              ▼
Wave 1:  ARC Controller
         │
         ├─> arc-systems namespace created
         ├─> ARC Controller deployed
         └─> CRDs installed (AutoScalingRunnerSet, etc.)
              │
              ▼
Wave 2:  GitHub Runners ApplicationSet
         │
         ├─> arc-runners namespace created
         ├─> Runner sets deployed
         └─> Runners register with GitHub
```

## GitOps Flow

```
┌──────────────┐
│   Developer  │
└──────┬───────┘
       │ 1. Edit YAML
       │ 2. Git commit
       │ 3. Git push
       ▼
┌──────────────────────┐
│   GitHub Repository  │
│  (main branch)       │
└──────┬───────────────┘
       │
       │ 4. ArgoCD polls every 3 min
       │    or webhook triggers
       ▼
┌──────────────────────┐
│   ArgoCD Controller  │
│   - Detects changes  │
│   - Computes diff    │
└──────┬───────────────┘
       │
       │ 5. Auto-sync enabled
       ▼
┌──────────────────────┐
│  Kubernetes Cluster  │
│  - Apply manifests   │
│  - Update resources  │
└──────┬───────────────┘
       │
       │ 6. Self-heal enabled
       ▼
┌──────────────────────┐
│   Desired State      │
│   (from Git)         │
└──────────────────────┘
```

## Self-Management Loop

ArgoCD managing itself creates a recursive loop:

```
┌─────────────────────────────────────────────┐
│         ArgoCD Running in Cluster           │
│                                             │
│  1. Monitors Git repository                 │
│  2. Finds argocd/apps/argocd.yaml          │
│  3. Reads ArgoCD Helm chart config          │
│  4. Compares with current ArgoCD state      │
│  5. Detects drift                           │
│  6. Updates itself (if changes exist)       │
│  7. Goes back to step 1                     │
│                                             │
│     ┌───────────────────────┐              │
│     │  "I manage myself!"   │              │
│     └───────────────────────┘              │
└─────────────────────────────────────────────┘
```

**Note**: The initial ArgoCD installation must be done manually. After that, ArgoCD manages its own updates through the `argocd.yaml` application.

## Directory Structure

```
argocd/
├── root-app.yaml                     # Root Application manifest
│                                     # (Apply this to bootstrap)
│
├── apps/                             # Child applications directory
│   ├── argocd.yaml                  # ArgoCD self-management
│   ├── arc-controller.yaml          # ARC controller
│   └── github-runners-appset.yaml   # Runners ApplicationSet
│
├── applications/                     # Legacy (for reference)
│   ├── arc-controller.yaml
│   ├── arc-runners.yaml
│   └── arc-frontend-runners.yaml
│
├── applicationset.yaml              # Legacy (for reference)
├── applicationset-dynamic.yaml      # Legacy (for reference)
│
├── setup-argocd.sh                  # Setup script (legacy)
├── README.md                        # Main documentation
├── APP_OF_APPS.md                   # App of Apps guide
└── ARCHITECTURE.md                  # This file
```

## Application Dependencies

```
root
├── argocd (no dependencies - wave -1)
├── arc-controller (depends on: argocd - wave 1)
└── github-runners (depends on: arc-controller - wave 2)
    └── arc-runners (depends on: arc-controller CRDs)
```

## Secret Management Flow

```
┌────────────────────────┐
│  Developer/Admin       │
│  Creates secrets:      │
│  - github-token        │
│  - arc-org-github-     │
│    secret              │
└───────┬────────────────┘
        │
        │ kubectl create secret
        ▼
┌────────────────────────┐
│  Kubernetes Secrets    │
│  - Not in Git          │
│  - Cluster only        │
└───────┬────────────────┘
        │
        │ Referenced by
        ▼
┌────────────────────────┐
│  ArgoCD Applications   │
│  - argocd.yaml refs    │
│    github-token        │
│  - runners ref         │
│    arc-org-github-     │
│    secret              │
└───────┬────────────────┘
        │
        │ Injected as env var
        ▼
┌────────────────────────┐
│  Running Pods          │
│  - ArgoCD repo-server  │
│  - GitHub Runners      │
└────────────────────────┘
```

## Benefits of This Architecture

1. **Single Source of Truth**: Git is the source of truth for everything
2. **Declarative**: All infrastructure defined in YAML
3. **Self-Healing**: Automatic drift detection and correction
4. **Ordered Deployment**: Sync waves ensure correct startup order
5. **Self-Management**: ArgoCD manages its own configuration
6. **Scalability**: Easy to add new applications
7. **Rollback**: Git history enables easy rollbacks
8. **Visibility**: Single pane of glass in ArgoCD UI
9. **Automation**: No manual intervention needed after bootstrap

## Failure Recovery

If any component fails:

```
Component Failure → ArgoCD Detects → Auto-Sync/Self-Heal → Recovery
```

Example scenarios:

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| Manual pod deletion | ArgoCD health check | Self-heal recreates pod |
| Manual config change | Drift detection | Self-heal reverts to Git |
| Git commit with change | Repo poll/webhook | Auto-sync applies change |
| ArgoCD config drift | Self-management app | ArgoCD updates itself |
| Upgrade needed | Developer edits YAML | Auto-sync upgrades |

## Monitoring Points

Watch these for system health:

1. **Root Application**: `kubectl get app root -n argocd`
2. **Child Applications**: `kubectl get applications -n argocd`
3. **ApplicationSets**: `kubectl get applicationsets -n argocd`
4. **Sync Status**: ArgoCD UI or `argocd app list`
5. **Resource Health**: `argocd app get <app-name>`

## Security Model

```
GitHub Repository (Public)
├── Application manifests (safe to be public)
├── Helm values (safe to be public)
└── No secrets (never committed)

Kubernetes Cluster (Private)
├── Secrets created manually
├── ArgoCD references secrets
└── Secrets injected at runtime
```

**Key principle**: Manifests in Git are secret-free. Secrets are cluster-only and referenced by name.

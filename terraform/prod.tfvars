# Production Environment Configuration
# Usage: terraform apply -var-file=prod.tfvars

# Cloudspace configuration
# ATTEMPT 11: Fresh cloudspace name to avoid stale SubscriptionSuspended from v3
cloudspace_name    = "mp-runners-v4"  # Fresh name — v3 carried stale suspension
region             = "us-east-iad-1"  # Back to IAD with new provider
kubernetes_version = "1.30.10"  # Stable K8s version
ha_control_plane   = false  # Try without HA (simpler control plane)

# Environment
environment = "prod"

# Node pool configuration
# gp.vs1.large-iad: 4 vCPU, 15GB RAM
server_class = "gp.vs1.large-iad"
bid_price    = 0.30  # Higher bid

# Autoscaling — 1 runner pod per node (3 CPU request vs 3.5 allocatable)
min_nodes = 2
max_nodes = 25

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

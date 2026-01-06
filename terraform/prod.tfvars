# Production Environment Configuration
# Usage: terraform apply -var-file=prod.tfvars

# Cloudspace configuration
# ATTEMPT 10: Retry IAD with pinned provider v0.1.4 and non-HA (simpler config)
cloudspace_name    = "mp-runners-v3"  # Fresh cloudspace name
region             = "us-east-iad-1"  # Back to IAD with new provider
kubernetes_version = "1.30.10"  # Stable K8s version
ha_control_plane   = false  # Try without HA (simpler control plane)

# Environment
environment = "prod"

# Node pool configuration
# gp.vs1.large-iad: 4 vCPU, 15GB RAM
server_class = "gp.vs1.large-iad"
bid_price    = 0.30  # Higher bid

# Autoscaling - increase min_nodes to compensate for smaller instances
min_nodes = 2
max_nodes = 15

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

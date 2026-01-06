# Production Environment Configuration
# Usage: terraform apply -var-file=prod.tfvars

# Cloudspace configuration
# ATTEMPT 7: Try ORD (Chicago) region - DFW region has persistent control plane failures (Issue #159)
cloudspace_name    = "mp-runners-ord"  # New cloudspace in ORD region
region             = "us-central-ord-1"  # Switching from DFW to ORD (Chicago) due to DFW control plane failures (Issue #159)
kubernetes_version = "1.30.10"  # Stable K8s version
ha_control_plane   = true  # HA for control plane stability

# Environment
environment = "prod"

# Node pool configuration
# gp.vs1.large-ord: 4 vCPU, 15GB RAM (ORD region equivalent)
# Server classes are region-specific (dfw -> ord suffix)
server_class = "gp.vs1.large-ord"
bid_price    = 0.25  # Slightly higher bid for new region availability

# Autoscaling - increase min_nodes to compensate for smaller instances
min_nodes = 2
max_nodes = 15

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

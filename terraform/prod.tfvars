# Production Environment Configuration
# Usage: terraform apply -var-file=prod.tfvars

# Cloudspace configuration
# ATTEMPT 8: Try IAD (US East / Northern Virginia) - DFW and ORD both failed (Issue #159)
cloudspace_name    = "mp-runners-iad"  # New cloudspace in IAD region
region             = "us-east-iad-1"  # Switching to US East (Northern Virginia)
kubernetes_version = "1.30.10"  # Stable K8s version
ha_control_plane   = true  # HA for control plane stability

# Environment
environment = "prod"

# Node pool configuration
# gp.vs1.large-iad: 4 vCPU, 15GB RAM (IAD region equivalent)
# Server classes are region-specific
server_class = "gp.vs1.large-iad"
bid_price    = 0.25  # Bid for region availability

# Autoscaling - increase min_nodes to compensate for smaller instances
min_nodes = 2
max_nodes = 15

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

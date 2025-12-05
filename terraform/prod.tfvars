# Production Environment Configuration
# Usage: terraform apply -var-file=prod.tfvars

# Cloudspace configuration
cloudspace_name    = "matchpoint-runners"
region             = "us-central-dfw-1"
kubernetes_version = "1.31.1"
ha_control_plane   = false

# Environment
environment = "prod"

# Node pool configuration
# gp.vs1.large-dfw: 4 vCPU, 15GB RAM
# 80th percentile: $0.031/hr, Market: $0.003/hr
# Cloud Run equivalent: ~$0.48/hr
# Bid $0.08/hr = ~83% savings vs Cloud Run with higher priority
server_class = "gp.vs1.large-dfw"
bid_price    = 0.08

# Autoscaling
min_nodes = 1
max_nodes = 10

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

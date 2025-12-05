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
server_class = "gp.vs1.medium-dfw"
bid_price    = 0.03

# Autoscaling
min_nodes = 1
max_nodes = 10

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

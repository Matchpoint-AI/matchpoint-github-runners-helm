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
# gp.vs1.xlarge-dfw: 8 vCPU, 30GB RAM
# Each node fits 2 runner pods (3 CPU each: 2 runner + 1 dind sidecar)
# Market price: $0.013/hr, On-demand: $0.162/hr
# Bid $0.10/hr = 62% of on-demand, 8x market (safe buffer for CI stability)
server_class = "gp.vs1.xlarge-dfw"
bid_price    = 0.10

# Autoscaling
# min_nodes=2 supports minRunners=3 in ARC config (2 runners/node)
min_nodes = 2
max_nodes = 10

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

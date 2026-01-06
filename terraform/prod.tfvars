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
# Trying smaller instance type to avoid spot market contention (Issue #159)
# xlarge instances were being immediately outbid in volatile market
# On-demand price: ~$0.081/hr (per Rackspace Spot pricing)
# Bid $0.50/hr = high priority bid for smaller instance
server_class = "gp.vs1.large-dfw"
bid_price    = 0.50

# Autoscaling - increase min_nodes to compensate for smaller instances
min_nodes = 2
max_nodes = 15

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

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
# gp.vs1.xlarge-dfw: 8 vCPU, 30GB RAM (matches Cloud Run runner specs)
# Larger nodes required to fit runner pods (6 CPU request)
# Cloud Run equivalent: ~$0.48/hr
# On-demand price: ~$0.162/hr (per Rackspace Spot pricing)
# Bid $0.40/hr = ~17% savings vs Cloud Run, high priority to avoid preemption
# Increased from $0.10 due to spot market price surge causing bid loss (Issue #159)
server_class = "gp.vs1.xlarge-dfw"
bid_price    = 0.40

# Autoscaling
min_nodes = 1
max_nodes = 10

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

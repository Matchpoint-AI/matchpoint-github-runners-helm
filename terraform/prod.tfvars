# Production Environment Configuration
# Usage: terraform apply -var-file=prod.tfvars

# Cloudspace configuration
cloudspace_name    = "mp-runners-v2"  # Renamed from matchpoint-runners due to stuck deletion (Issue #159)
region             = "us-central-dfw-2"  # Changed from dfw-1 due to control plane provisioning issues (Issue #159)
kubernetes_version = "1.30.10"  # Downgraded from 1.31.1 due to ControlPlaneUnresponsive in both dfw-1 and dfw-2 (Issue #159)
ha_control_plane   = true  # Enabled to test if HA mode avoids ControlPlaneUnresponsive issue (Issue #159)

# Environment
environment = "prod"

# Node pool configuration
# gp.vs1.large-dfw: 4 vCPU, 15GB RAM
# Using smaller instance type after spot market volatility (Issue #159)
# On-demand price: ~$0.081/hr (per Rackspace Spot pricing)
# Bid $0.20/hr = ~2.5x on-demand, balancing cost vs availability
# Previous $0.50/hr was 6x on-demand (too expensive)
server_class = "gp.vs1.large-dfw"
bid_price    = 0.20

# Autoscaling - increase min_nodes to compensate for smaller instances
min_nodes = 2
max_nodes = 15

# Git configuration
git_repo_url        = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
git_target_revision = "main"

# Debug (disable in production after initial setup)
write_kubeconfig = true

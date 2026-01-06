################################################################################
# Cloudspace Module - Rackspace Spot Managed Kubernetes
################################################################################
# Creates a managed Kubernetes cluster (cloudspace) on Rackspace Spot.
#
# Features:
# - Automatic kubeconfig retrieval
# - Optional HA control plane
# - Preemption webhook support
#
# Docs: https://registry.terraform.io/providers/rackerlabs/spot/latest/docs/resources/cloudspace
################################################################################

resource "spot_cloudspace" "main" {
  cloudspace_name    = var.name
  region             = var.region
  kubernetes_version = var.kubernetes_version
  hacontrol_plane    = var.ha_control_plane
  wait_until_ready   = false  # Issue #159: Disable blocking wait - cloudspace creates faster without waiting

  # Optional: Slack/webhook notification for preemption events
  # Only set if non-empty (provider requires valid URL or null)
  preemption_webhook = var.preemption_webhook != "" ? var.preemption_webhook : null
}

# Wait for control plane to become ready before fetching kubeconfig
# Issue #159: Control plane takes 15-20+ minutes to provision after cloudspace creation
# Attempt 14 showed 10m wasn't enough - cloudspace was still in "Provisioning" phase
resource "time_sleep" "wait_for_control_plane" {
  depends_on = [spot_cloudspace.main]

  create_duration = "20m"  # Wait 20 minutes for control plane to provision
}

# Retrieve kubeconfig for the created cloudspace
data "spot_kubeconfig" "main" {
  cloudspace_name = spot_cloudspace.main.cloudspace_name

  depends_on = [time_sleep.wait_for_control_plane]
}

# Store kubeconfig as a local file (optional, for debugging)
resource "local_sensitive_file" "kubeconfig" {
  count = var.write_kubeconfig_file ? 1 : 0

  content  = data.spot_kubeconfig.main.raw
  filename = "${path.root}/kubeconfig-${var.name}.yaml"

  file_permission = "0600"
}

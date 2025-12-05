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
  wait_until_ready   = true

  # Optional: Slack/webhook notification for preemption events
  # Only set if non-empty (provider requires valid URL or null)
  preemption_webhook = var.preemption_webhook != "" ? var.preemption_webhook : null
}

# Retrieve kubeconfig for the created cloudspace
data "spot_kubeconfig" "main" {
  cloudspace_name = spot_cloudspace.main.cloudspace_name

  depends_on = [spot_cloudspace.main]
}

# Store kubeconfig as a local file (optional, for debugging)
resource "local_sensitive_file" "kubeconfig" {
  count = var.write_kubeconfig_file ? 1 : 0

  content  = data.spot_kubeconfig.main.raw
  filename = "${path.root}/kubeconfig-${var.name}.yaml"

  file_permission = "0600"
}

################################################################################
# Node Pool Module - Rackspace Spot Worker Nodes
################################################################################
# Creates a worker node pool within a cloudspace for running GitHub Actions
# runners.
#
# Features:
# - Autoscaling (min/max nodes)
# - Bid pricing for cost optimization
# - Kubernetes labels and taints for scheduling
#
# Docs: https://registry.terraform.io/providers/rackerlabs/spot/latest/docs/resources/spotnodepool
################################################################################

resource "spot_spotnodepool" "main" {
  cloudspace_name = var.cloudspace_name
  server_class    = var.server_class
  bid_price       = var.bid_price

  # Autoscaling configuration
  autoscaling = var.enable_autoscaling ? {
    min_nodes = var.min_nodes
    max_nodes = var.max_nodes
  } : null

  # Fixed node count (mutually exclusive with autoscaling)
  desired_server_count = var.enable_autoscaling ? null : var.desired_server_count

  # Kubernetes labels for node selection
  labels = merge(
    {
      "matchpoint.ai/runner-pool" = "github-actions"
      "matchpoint.ai/environment" = var.environment
      "matchpoint.ai/purpose"     = var.purpose
    },
    var.labels
  )

  # Only set annotations if non-empty (provider bug: empty map becomes null)
  annotations = length(var.annotations) > 0 ? var.annotations : null
}

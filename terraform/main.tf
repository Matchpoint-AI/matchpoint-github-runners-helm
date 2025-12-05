################################################################################
# Rackspace Spot GitHub Runners Infrastructure
################################################################################
# Deploys self-hosted GitHub Actions runners on Rackspace Spot infrastructure.
#
# This configuration deploys:
# 1. Rackspace Spot Cloudspace (managed Kubernetes)
# 2. Worker node pool with autoscaling
# 3. ArgoCD for GitOps-based runner deployment
#
# Usage:
#   terraform workspace new prod    # Create workspace (first time only)
#   terraform workspace select prod # Select workspace
#   terraform plan -var-file=prod.tfvars
#   terraform apply -var-file=prod.tfvars
#
# Prerequisites:
# 1. RACKSPACE_SPOT_API_TOKEN set as org secret
# 2. GitHub token with repo access
################################################################################

locals {
  # Append workspace name to cloudspace for environment isolation
  cloudspace_name = "${var.cloudspace_name}-${terraform.workspace}"
}

#------------------------------------------------------------------------------
# Phase 1: Rackspace Spot Cloudspace (Managed Kubernetes)
#------------------------------------------------------------------------------

module "cloudspace" {
  source = "./modules/cloudspace"

  name               = local.cloudspace_name
  region             = var.region
  kubernetes_version = var.kubernetes_version
  ha_control_plane   = var.ha_control_plane
  preemption_webhook = var.preemption_webhook

  # Write kubeconfig for debugging
  write_kubeconfig_file = var.write_kubeconfig
}

#------------------------------------------------------------------------------
# Phase 2: Worker Node Pool
#------------------------------------------------------------------------------

module "nodepool" {
  source = "./modules/nodepool"

  cloudspace_name = module.cloudspace.name
  server_class    = var.server_class
  bid_price       = var.bid_price
  environment     = var.environment

  # Autoscaling configuration
  enable_autoscaling = true
  min_nodes          = var.min_nodes
  max_nodes          = var.max_nodes

  # Labels for runner targeting
  labels = {
    "github-runner" = "true"
    "workload"      = "ci-cd"
  }

  depends_on = [module.cloudspace]
}

#------------------------------------------------------------------------------
# Phase 3: ArgoCD Installation
#------------------------------------------------------------------------------

module "argocd" {
  source = "./modules/argocd"

  namespace           = "argocd"
  github_token        = var.github_token
  git_repo_url        = var.git_repo_url
  git_target_revision = var.git_target_revision
  # Disabled: kubernetes_manifest requires CRDs which may not be ready immediately
  # TODO: Enable after initial ArgoCD deploy, or use kubectl apply manually
  enable_bootstrap_app = false

  depends_on = [module.nodepool]
}

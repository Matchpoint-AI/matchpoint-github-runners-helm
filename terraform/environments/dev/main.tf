################################################################################
# Development Environment - Rackspace Spot GitHub Runners
################################################################################
# This environment deploys the complete GitHub Actions runner infrastructure:
#
# 1. Rackspace Spot Cloudspace (managed Kubernetes)
# 2. Worker node pool with autoscaling
# 3. ArgoCD for GitOps-based runner deployment
#
# Prerequisites:
# 1. RACKSPACE_SPOT_API_TOKEN set as org secret (already done)
# 2. GitHub token with repo access
#
# Issue: https://github.com/Matchpoint-AI/matchpoint-github-runners-helm/issues/1
################################################################################

terraform {
  required_version = ">= 1.5.0"

  # Remote state in GCS (same bucket as project-beta-runners)
  backend "gcs" {
    bucket = "project-beta-runners-tf-state"
    prefix = "rackspace-spot/dev"
  }

  required_providers {
    spot = {
      source  = "rackerlabs/spot"
      version = "~> 0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

#------------------------------------------------------------------------------
# Providers
#------------------------------------------------------------------------------

provider "spot" {
  token = var.rackspace_spot_token
}

# Kubernetes and Helm providers configured after cloudspace creation
provider "kubernetes" {
  host     = module.cloudspace.api_server_host
  token    = module.cloudspace.api_server_token
  insecure = module.cloudspace.insecure
}

provider "helm" {
  kubernetes {
    host     = module.cloudspace.api_server_host
    token    = module.cloudspace.api_server_token
    insecure = module.cloudspace.insecure
  }
}

#------------------------------------------------------------------------------
# Phase 1: Rackspace Spot Cloudspace (Managed Kubernetes)
#------------------------------------------------------------------------------

module "cloudspace" {
  source = "../../modules/cloudspace"

  name               = var.cloudspace_name
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
  source = "../../modules/nodepool"

  cloudspace_name = module.cloudspace.name
  server_class    = var.server_class
  bid_price       = var.bid_price
  environment     = "dev"

  # Autoscaling: 0-10 nodes (scale-to-zero when idle)
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
  source = "../../modules/argocd"

  namespace            = "argocd"
  github_token         = var.github_token
  git_repo_url         = var.git_repo_url
  git_target_revision  = var.git_target_revision
  enable_bootstrap_app = true

  depends_on = [module.nodepool]
}

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

variable "rackspace_spot_token" {
  description = "Rackspace Spot API token (from GitHub org secret RACKSPACE_SPOT_API_TOKEN)"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub token for ArgoCD repository access"
  type        = string
  sensitive   = true
}

variable "cloudspace_name" {
  description = "Name of the Rackspace Spot cloudspace"
  type        = string
  default     = "matchpoint-runners-dev"
}

variable "region" {
  description = "Rackspace Spot region"
  type        = string
  default     = "us-central-dfw-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31.1"
}

variable "ha_control_plane" {
  description = "Enable HA control plane"
  type        = bool
  default     = false
}

variable "preemption_webhook" {
  description = "Webhook URL for preemption alerts"
  type        = string
  default     = ""
}

variable "write_kubeconfig" {
  description = "Write kubeconfig to file"
  type        = bool
  default     = true
}

# Node pool configuration
variable "server_class" {
  description = "Server class for runner nodes"
  type        = string
  default     = "gp.vs1.medium-dfw"
}

variable "bid_price" {
  description = "Bid price in USD per hour"
  type        = number
  default     = 0.03
}

variable "min_nodes" {
  description = "Minimum nodes (0 for scale-to-zero)"
  type        = number
  default     = 0
}

variable "max_nodes" {
  description = "Maximum nodes"
  type        = number
  default     = 10
}

# Git configuration
variable "git_repo_url" {
  description = "Git repository URL"
  type        = string
  default     = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
}

variable "git_target_revision" {
  description = "Git branch to track"
  type        = string
  default     = "main"
}

#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------

output "cloudspace_name" {
  description = "Name of the cloudspace"
  value       = module.cloudspace.name
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = module.cloudspace.kubernetes_version
}

output "api_server_host" {
  description = "Kubernetes API server URL"
  value       = module.cloudspace.api_server_host
  sensitive   = true
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig (use kubectl with this)"
  value       = module.cloudspace.kubeconfig_raw
  sensitive   = true
}

output "nodepool_name" {
  description = "Node pool name"
  value       = module.nodepool.name
}

output "nodepool_bid_status" {
  description = "Current bid status"
  value       = module.nodepool.bid_status
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = module.argocd.namespace
}

output "arc_systems_namespace" {
  description = "ARC controller namespace"
  value       = module.argocd.arc_systems_namespace
}

################################################################################
# Input Variables
################################################################################

#------------------------------------------------------------------------------
# Required Variables (no defaults - must be provided)
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

#------------------------------------------------------------------------------
# Cloudspace Configuration
#------------------------------------------------------------------------------

variable "cloudspace_name" {
  description = "Name of the Rackspace Spot cloudspace"
  type        = string
  default     = "matchpoint-runners"
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

#------------------------------------------------------------------------------
# Node Pool Configuration
#------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (used for workspace selection and labeling)"
  type        = string
  default     = "prod"
}

variable "server_class" {
  description = "Server class for runner nodes (gp.vs1.large-dfw: 4 vCPU, 15GB RAM)"
  type        = string
  default     = "gp.vs1.large-dfw"
}

variable "bid_price" {
  description = "Bid price in USD per hour (~83% savings vs Cloud Run with higher priority)"
  type        = number
  default     = 0.08
}

variable "min_nodes" {
  description = "Minimum nodes (provider minimum is 1)"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum nodes"
  type        = number
  default     = 10
}

#------------------------------------------------------------------------------
# Git/ArgoCD Configuration
#------------------------------------------------------------------------------

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

################################################################################
# Cloudspace Module - Variables
################################################################################

variable "name" {
  description = "Name of the cloudspace (Kubernetes cluster)"
  type        = string
}

variable "region" {
  description = "Rackspace Spot region for deployment"
  type        = string
  default     = "us-central-dfw-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version (supported: 1.29.6, 1.30.10, 1.31.1)"
  type        = string
  default     = "1.31.1"

  validation {
    condition     = contains(["1.29.6", "1.30.10", "1.31.1"], var.kubernetes_version)
    error_message = "Kubernetes version must be one of: 1.29.6, 1.30.10, 1.31.1"
  }
}

variable "ha_control_plane" {
  description = "Enable high-availability control plane (recommended for production)"
  type        = bool
  default     = false
}

variable "preemption_webhook" {
  description = "Webhook URL to receive preemption notifications (e.g., Slack)"
  type        = string
  default     = ""
}

variable "create_timeout" {
  description = "Timeout for cloudspace creation"
  type        = string
  default     = "30m"
}

variable "write_kubeconfig_file" {
  description = "Write kubeconfig to a local file (for debugging)"
  type        = bool
  default     = false
}

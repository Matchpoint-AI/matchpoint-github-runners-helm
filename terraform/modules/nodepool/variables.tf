################################################################################
# Node Pool Module - Variables
################################################################################

variable "cloudspace_name" {
  description = "Name of the parent cloudspace"
  type        = string
}

variable "server_class" {
  description = "Server class for worker nodes (e.g., gp.vs1.medium-dfw)"
  type        = string
  default     = "gp.vs1.medium-dfw"
}

variable "bid_price" {
  description = "Bid price in USD per hour (e.g., 0.02 for $0.02/hour)"
  type        = number
  default     = 0.02

  validation {
    condition     = var.bid_price > 0 && var.bid_price < 1
    error_message = "Bid price must be between 0 and 1 USD per hour"
  }
}

variable "environment" {
  description = "Environment name for labeling (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Autoscaling configuration
variable "enable_autoscaling" {
  description = "Enable autoscaling (mutually exclusive with desired_server_count)"
  type        = bool
  default     = true
}

variable "min_nodes" {
  description = "Minimum number of nodes (0 for scale-to-zero)"
  type        = number
  default     = 0
}

variable "max_nodes" {
  description = "Maximum number of nodes"
  type        = number
  default     = 10
}

variable "desired_server_count" {
  description = "Fixed number of nodes (only when autoscaling is disabled)"
  type        = number
  default     = 1
}

# Kubernetes scheduling configuration
variable "labels" {
  description = "Additional Kubernetes labels for nodes"
  type        = map(string)
  default     = {}
}

variable "taints" {
  description = "Kubernetes taints to apply to nodes"
  type = list(object({
    key    = string
    value  = optional(string)
    effect = string
  }))
  default = []
}

variable "annotations" {
  description = "Annotations to apply to nodes"
  type        = map(string)
  default     = {}
}

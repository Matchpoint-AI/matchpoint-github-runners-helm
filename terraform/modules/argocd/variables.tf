################################################################################
# ArgoCD Module - Variables
################################################################################

variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "github_token" {
  description = "GitHub token for ArgoCD repository access (needs Contents:read on the helm repo)"
  type        = string
  sensitive   = true
}

variable "arc_runners_github_token" {
  description = "GitHub token for ARC org-level runner registration (needs admin:org on classic PAT, or Self-hosted runners: read/write on fine-grained)"
  type        = string
  sensitive   = true
}

variable "git_repo_url" {
  description = "Git repository URL for runner configuration"
  type        = string
  default     = "https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
}

variable "git_target_revision" {
  description = "Git branch/tag/commit to track"
  type        = string
  default     = "main"
}

variable "enable_bootstrap_app" {
  description = "Create bootstrap Application that watches this repo"
  type        = bool
  default     = true
}

# Ingress configuration
variable "ingress_enabled" {
  description = "Enable ingress for ArgoCD web UI"
  type        = bool
  default     = false
}

variable "ingress_hosts" {
  description = "List of ingress hostnames"
  type        = list(string)
  default     = []
}

variable "admin_password_hash" {
  description = "Bcrypt hash of the admin password (generate with: htpasswd -nbBC 10 '' $PASSWORD | tr -d ':')"
  type        = string
  default     = ""
  sensitive   = true
}

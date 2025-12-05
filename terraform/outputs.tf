################################################################################
# Outputs
################################################################################

#------------------------------------------------------------------------------
# Cloudspace Outputs
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

#------------------------------------------------------------------------------
# Node Pool Outputs
#------------------------------------------------------------------------------

output "nodepool_name" {
  description = "Node pool name"
  value       = module.nodepool.name
}

output "nodepool_bid_status" {
  description = "Current bid status"
  value       = module.nodepool.bid_status
}

#------------------------------------------------------------------------------
# ArgoCD Outputs
#------------------------------------------------------------------------------

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = module.argocd.namespace
}

output "arc_systems_namespace" {
  description = "ARC controller namespace"
  value       = module.argocd.arc_systems_namespace
}

#------------------------------------------------------------------------------
# Workspace Info
#------------------------------------------------------------------------------

output "workspace" {
  description = "Current terraform workspace"
  value       = terraform.workspace
}

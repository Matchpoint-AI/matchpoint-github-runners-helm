################################################################################
# ArgoCD Module - Outputs
################################################################################

output "namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.namespace
}

output "argocd_version" {
  description = "Installed ArgoCD version"
  value       = var.argocd_version
}

output "server_service" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "arc_systems_namespace" {
  description = "Namespace for ARC controller"
  value       = kubernetes_namespace.arc_systems.metadata[0].name
}

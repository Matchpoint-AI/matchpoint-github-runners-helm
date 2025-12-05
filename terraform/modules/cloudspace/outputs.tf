################################################################################
# Cloudspace Module - Outputs
################################################################################

output "name" {
  description = "Name of the cloudspace"
  value       = spot_cloudspace.main.cloudspace_name
}

output "region" {
  description = "Region of the cloudspace"
  value       = spot_cloudspace.main.region
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = spot_cloudspace.main.kubernetes_version
}

# Kubeconfig outputs for downstream providers (Kubernetes, Helm)
output "kubeconfig_raw" {
  description = "Raw kubeconfig YAML (use for kubectl)"
  value       = data.spot_kubeconfig.main.raw
  sensitive   = true
}

output "api_server_host" {
  description = "Kubernetes API server URL"
  value       = data.spot_kubeconfig.main.kubeconfigs[0].host
}

output "api_server_token" {
  description = "Service account token for API authentication"
  value       = data.spot_kubeconfig.main.kubeconfigs[0].token
  sensitive   = true
}

output "insecure" {
  description = "Whether to skip TLS verification"
  value       = data.spot_kubeconfig.main.kubeconfigs[0].insecure
}

output "first_ready_timestamp" {
  description = "Timestamp when cloudspace became ready"
  value       = spot_cloudspace.main.first_ready_timestamp
}

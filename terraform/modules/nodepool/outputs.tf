################################################################################
# Node Pool Module - Outputs
################################################################################

output "name" {
  description = "Name of the node pool"
  value       = spot_spotnodepool.main.name
}

# Note: id attribute is deprecated in provider, use name instead

output "bid_status" {
  description = "Current bid status"
  value       = spot_spotnodepool.main.bid_status
}

output "won_count" {
  description = "Number of successful bids (active nodes)"
  value       = spot_spotnodepool.main.won_count
}

output "server_class" {
  description = "Server class used"
  value       = var.server_class
}


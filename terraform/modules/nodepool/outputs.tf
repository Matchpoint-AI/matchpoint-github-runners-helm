################################################################################
# Node Pool Module - Outputs
################################################################################

output "name" {
  description = "Name of the node pool"
  value       = spot_spotnodepool.main.name
}

output "id" {
  description = "ID of the node pool"
  value       = spot_spotnodepool.main.id
}

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

# Server class specifications (for reference)
output "server_specs" {
  description = "Specifications of the selected server class"
  value = {
    cpu          = data.spot_serverclass.selected.cpu
    memory       = data.spot_serverclass.selected.memory
    display_name = data.spot_serverclass.selected.display_name
    spot_price   = data.spot_serverclass.selected.spot_price_per_hour
    available    = data.spot_serverclass.selected.available_count
  }
}

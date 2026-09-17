output "subnet" {
  description = "The tenant's overlay subnet, issued with its index."
  value       = deevnet_tenant.this.subnet
}

output "app_address" {
  value = deevnet_workload.app.address
}

output "names" {
  description = "What this tenant publishes."
  value       = [deevnet_workload.app.fqdn, deevnet_dns_record.service.fqdn]
}

# The credentials the substrate issued. This state is their authoritative copy
# (ADR-0015 §4), which is why it belongs in the state store or somewhere with
# the same care.
output "state_backend" {
  description = "Values for the backend block, and the credentials it needs."
  sensitive   = true
  value = {
    endpoint   = deevnet_tenant.this.state_endpoint
    bucket     = deevnet_tenant.this.state_bucket
    key        = "${deevnet_tenant.this.state_key_prefix}terraform.tfstate"
    access_key = deevnet_tenant.this.state_access_key
    secret_key = deevnet_tenant.this.state_secret_key
  }
}

output "dns_publication" {
  description = "For publishing names directly over RFC 2136, which the tenant may still do (ADR-0004)."
  sensitive   = true
  value = {
    server        = deevnet_tenant.this.dns_update_server
    zone          = deevnet_tenant.this.dns_zone
    reverse_zone  = deevnet_tenant.this.dns_reverse_zone
    key_name      = deevnet_tenant.this.tsig_key_name
    key_algorithm = deevnet_tenant.this.tsig_algorithm
    key_secret    = deevnet_tenant.this.tsig_secret
  }
}

output "api_token" {
  description = "This tenant's own API token. Every apply after the first uses it."
  sensitive   = true
  value       = deevnet_tenant.this.api_token
}

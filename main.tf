# Demo tenant - proves the path end to end, then gets destroyed.
#
# Everything about this tenant derives from tenant_index. That is the whole
# point of the numbering scheme: one allocation, no per-tenant decisions, and
# no way to collide with another tenant once the fabric has more members.
#
# Reads the fabric stack's outputs rather than hardcoding the controller or
# node, so a tenant is portable across fabric members without edits.

terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.101"
    }
  }
}

provider "proxmox" {
  endpoint  = replace(var.proxmox_url, "/api2/json", "")
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true
}

# Publication credentials (ADR-0004). The key is scoped by the server to this
# tenant's zones, so this configuration cannot write into another tenant's
# namespace even by mistake - an update aimed elsewhere comes back REFUSED.
provider "dns" {
  update {
    server        = var.dns_update_server
    key_name      = "${var.tsig_key_name}."
    key_algorithm = "hmac-sha256"
    key_secret    = var.tsig_key_secret
  }
}

# The module is consumed by tag, not by path (ADR-0006). The tag is never moved,
# so this pins the module as precisely as the lock file pins the providers.
# Moving to a newer tag requires an explicit `terraform init -upgrade` - plan and
# apply will not pick one up, which is a feature and a trap in equal measure.
module "tenant" {
  source = "git::ssh://git@github.com/deevnet/deevnet-tenant-factory.git//modules/tenant?ref=tenant-module-v1.0.0"

  tenant_name  = "tdemo"
  tenant_index = 1

  # Issued by the substrate at onboarding, in fabric.auto.tfvars - see ADR-0006.
  # Previously read out of the fabric's Terraform state by relative path, which
  # only worked while this tenant lived inside the factory repository.
  controller_id = var.controller_id
  node          = var.node


  template_vm_id = var.template_vm_id
  vm_count       = 1
  ssh_keys       = var.ssh_keys

  # Workload A and PTR records derive from the addressing, so nothing is listed
  # here. dns_extra_records is where a tenant adds service names - the thing the
  # Proxmox IPAM hook could never have given us.
  dns_publish = true
}

output "subnet" {
  value = module.tenant.subnet
}

output "gateway" {
  value = module.tenant.gateway
}

output "vrf_vni" {
  value = module.tenant.vrf_vni
}

output "vnet_ids" {
  value = module.tenant.vnet_ids
}

output "vm_names" {
  value = module.tenant.vm_names
}

output "dns_zone" {
  value = module.tenant.dns_zone
}

output "dns_names" {
  value = module.tenant.dns_names
}

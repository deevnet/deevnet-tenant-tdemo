# tdemo - the reference tenant.
#
# Copy this repository to create a tenant: change the name here, and nothing
# else. Everything a tenant is - its index, network numbering, DNS zone and
# key, state-store credential and workload addressing - is issued by the
# Deevnet API (ADR-0015), so there is no number to allocate and no substrate
# credential to fetch.
#
# What the tenant holds is one token: the single-use enrollment token the
# substrate issues at admission, and then its own token, which lands in this
# state on the first apply.

terraform {
  required_version = ">= 1.5"

  required_providers {
    deevnet = {
      source  = "deevnet/deevnet"
      version = "~> 0.1"
    }
  }

  # The state store the substrate offers (ADR-0007). It is deliberately
  # commented out: its credentials are outputs of the tenant below, so the
  # first apply runs with local state and the backend is configured after it,
  # with `terraform init -migrate-state` and the values from
  # `make state-backend`.
  #
  # A tenant that would rather keep its own custody simply leaves this out;
  # the offer is not a requirement.
  #
  # backend "s3" {
  #   bucket       = "tf-state"
  #   key          = "tenants/tdemo/terraform.tfstate"
  #   region       = "us-east-1"
  #   endpoints    = { s3 = "http://tfstate.mobile.deevnet.net:9000" }
  #   use_lockfile = true
  #
  #   # MinIO, not AWS.
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  #   skip_requesting_account_id  = true
  #   skip_metadata_api_check     = true
  #   skip_s3_checksum            = true
  #   use_path_style              = true
  # }
}

# endpoint, token and ca_certificate come from DEEVNET_API_ENDPOINT,
# DEEVNET_API_TOKEN and DEEVNET_API_CACERT. The token is the enrollment token
# on the first apply, and this tenant's own token afterwards.
provider "deevnet" {}

resource "deevnet_tenant" "this" {
  name = var.tenant_name
}

# One workload. The API picks its VMID, MAC and address from the tenant's
# index; the tenant picks what it runs on.
resource "deevnet_workload" "app" {
  tenant    = deevnet_tenant.this.name
  name      = "app"
  cores     = var.vm_cores
  memory_mb = var.vm_memory_mb
  ssh_keys  = var.ssh_keys
}

# A name beside the workload's own, for the service rather than the machine.
resource "deevnet_dns_record" "service" {
  tenant  = deevnet_tenant.this.name
  name    = "service"
  address = deevnet_workload.app.address
}

# A Deevnet tenant: a Wi-Fi key and a device, a backend workload, and the
# broker accounts between them - the walkthrough in the tenant guide, as one
# configuration you can apply.
#
# To make your own tenant from this repository: `make new NAME=<your name>`,
# then README.md. Nothing below names this tenant; terraform.tfvars does.

terraform {
  required_version = ">= 1.5"

  required_providers {
    deevnet = {
      source  = "deevnet/deevnet"
      version = "~> 0.5"
    }
  }
  # No backend here. Your first apply keeps state on your computer; after it,
  # `make state-backend` writes backend.tf for the state store the substrate
  # offers (ADR-0007), from your own tenant's outputs.
}

# DEEVNET_API_ENDPOINT, DEEVNET_API_TOKEN and DEEVNET_API_CACERT; the Makefile
# sets the first and the last. The token is the enrollment token on the first
# apply, and this tenant's own token afterwards.
provider "deevnet" {}

resource "deevnet_tenant" "this" {
  name = var.tenant_name
}

# --- Devices ---------------------------------------------------------------------

# One Wi-Fi key for all of your devices.
resource "deevnet_iot_wifi_key" "devices" {
  tenant      = deevnet_tenant.this.name
  name        = "devices"
  trust_class = "iot"
}

# Each device: an entry in your registry, and a broker account of its own.
resource "deevnet_iot_device" "dev" {
  for_each    = toset(var.devices)
  tenant      = deevnet_tenant.this.name
  name        = each.key
  trust_class = "iot"
}

resource "deevnet_iot_broker_account" "dev" {
  for_each  = toset(var.devices)
  tenant    = deevnet_tenant.this.name
  name      = each.key
  device    = deevnet_iot_device.dev[each.key].name
  publish   = ["sensors/${each.key}/telemetry", "log/${each.key}"]
  subscribe = ["sensors/${each.key}/command"]
}

# --- The backend -------------------------------------------------------------------

# Its broker account is the app's login everywhere it runs: on the workload,
# on your computer, and later on a Pi of your own, with the same password.
resource "deevnet_iot_broker_account" "backend" {
  tenant    = deevnet_tenant.this.name
  name      = "backend"
  subscribe = ["sensors/+/telemetry"]
  publish   = ["sensors/+/command"]
}

# A VM to run it on. Optional: a backend on your computer needs none, and a VM
# nothing runs on only costs memory. You log in with the private half of a
# key in ssh_keys; the substrate never sees it.
resource "deevnet_workload" "backend" {
  count    = var.backend_workload ? 1 : 0
  tenant   = deevnet_tenant.this.name
  name     = "backend"
  ssh_keys = var.ssh_keys
}

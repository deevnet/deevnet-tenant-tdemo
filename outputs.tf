# Everything below that is sensitive is a credential the substrate issued, and
# this state is its authoritative copy (ADR-0015 §4). Read one with
# `terraform output -json <name>`.

output "api_token" {
  description = "This tenant's own API token. Every apply after the first uses it."
  sensitive   = true
  value       = deevnet_tenant.this.api_token
}

# What you flash onto a device.
output "flash" {
  sensitive = true
  value = {
    wifi = { ssid = deevnet_iot_wifi_key.devices.ssid, psk = deevnet_iot_wifi_key.devices.psk }
    mqtt = { for d, a in deevnet_iot_broker_account.dev :
    d => { user = a.username, pass = a.password, publish = a.granted_publish } }
  }
}

# How to reach the backend workload, when there is one.
output "backend" {
  value = var.backend_workload ? {
    address = deevnet_workload.backend[0].address
    login   = "ssh ${deevnet_workload.backend[0].login_user}@${deevnet_workload.backend[0].fqdn}"
  } : null
}

# The app's whole environment. `terraform output -raw kit_env > kit.env`, and
# the same app runs on Deevnet and - with a Pi's kit.env - on a Pi of your own.
output "kit_env" {
  sensitive = true
  value     = <<-EOT
    DEEVNET_TENANT=${deevnet_tenant.this.name}
    MQTT_HOST=mqtt.mobile.deevnet.net
    MQTT_PORT=8883
    MQTT_CA_FILE=site-ca.pem
    MQTT_USERNAME=${deevnet_iot_broker_account.backend.username}
    MQTT_PASSWORD=${deevnet_iot_broker_account.backend.password}
    LOG_ENDPOINT=${deevnet_tenant.this.log_endpoint}
    LOG_INGEST_TOKEN=${deevnet_tenant.this.log_ingest_token}
    LOG_READ_TOKEN=${deevnet_tenant.this.log_read_token}
    LOG_SELECT_HEADER=${deevnet_tenant.this.log_select_header}
    LOG_DEVICE_PARTITION=${deevnet_tenant.this.index}-2
    GRAFANA_URL=${deevnet_tenant.this.dashboard_url}
    GRAFANA_AUTH=${deevnet_tenant.this.dashboard_username}:${deevnet_tenant.this.dashboard_password}
    GRAFANA_ORG_ID=${deevnet_tenant.this.dashboard_org_id}
    TF_VAR_grafana_org_id=${deevnet_tenant.this.dashboard_org_id}
    GRAFANA_CA_CERT=site-ca.pem
  EOT
}

# What `make state-backend` writes backend.tf and .backend.env from.
output "state_backend" {
  sensitive = true
  value = {
    endpoint   = deevnet_tenant.this.state_endpoint
    bucket     = deevnet_tenant.this.state_bucket
    key        = "${deevnet_tenant.this.state_key_prefix}terraform.tfstate"
    access_key = deevnet_tenant.this.state_access_key
    secret_key = deevnet_tenant.this.state_secret_key
  }
}

# For publishing names yourself over RFC 2136 (ADR-0004). The workload's own
# name is published for you.
output "dns_publication" {
  sensitive = true
  value = {
    server        = deevnet_tenant.this.dns_update_server
    zone          = deevnet_tenant.this.dns_zone
    reverse_zone  = deevnet_tenant.this.dns_reverse_zone
    key_name      = deevnet_tenant.this.tsig_key_name
    key_algorithm = deevnet_tenant.this.tsig_algorithm
    key_secret    = deevnet_tenant.this.tsig_secret
  }
}

# Alerts, to your phone on site (ADR-0023 §5).
#
# Each group's rules run in your own vmalert on the site, reading with your log
# read token: a rule sees exactly what your tokens see. When a rule fires, and
# again when it clears, a notification goes to the ntfy topic
# "<tenant>-<topic>". On the phone: the ntfy app, server notify_endpoint, logged
# in with notify_username and notify_password, subscribed to alert_topics.

# Over your workloads' metrics: MetricsQL (PromQL works).
resource "deevnet_alert_rule_group" "backend" {
  tenant = deevnet_tenant.this.name
  name   = "backend"
  type   = "metrics"
  topic  = "backend"

  rule {
    alert       = "QueueBacklog"
    expr        = "backend_queue_depth > 100"
    for         = "5m"
    labels      = { severity = "page" }
    annotations = { summary = "The backend's queue is {{ $value }} deep" }
  }
}

# Over your devices' logs, as the MQTT log bridge stores them: LogsQL ending in
# a stats pipe, one alert for each row it returns. A logs rule searches only the
# last interval, so it suits "this happened" alerts.
resource "deevnet_alert_rule_group" "devices" {
  tenant    = deevnet_tenant.this.name
  name      = "devices"
  type      = "logs"
  partition = "devices"
  topic     = "devices"

  rule {
    alert       = "DeviceError"
    expr        = "error | stats by (device) count() as hits | filter hits:>0"
    annotations = { summary = "{{ $labels.device }} logged {{ $value }} errors" }
  }
}

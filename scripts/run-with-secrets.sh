#!/bin/sh
# Run your app with its secrets from OpenBao in its environment, never on disk.
#
#   scripts/run-with-secrets.sh kit.env ./backend [args...]
#
# Reads BAO_ADDR, BAO_NAMESPACE, BAO_CACERT, BAO_ROLE_ID and BAO_SECRET_ID from
# kit.env (secrets.tf.example's `secrets_env`), and runs OpenBao Agent in
# process-supervisor mode: it logs in by AppRole, renders each secret into an
# environment variable of the app, and restarts the app when a secret changes.
# Needs the `bao` binary on the workload.
set -eu
[ $# -ge 2 ] || { echo "usage: $0 kit.env command [args...]" >&2; exit 2; }
env_file=$1; shift
set -a; . "./$env_file"; set +a

# The AppRole's two halves go in a private directory in memory, which the
# agent re-reads to log in again when its token reaches its maximum lifetime.
run=$(mktemp -d "${XDG_RUNTIME_DIR:-/dev/shm}/bao-agent.XXXXXX")
trap 'rm -rf "$run"' EXIT INT TERM
umask 077
printf %s "$BAO_ROLE_ID" > "$run/role_id"
printf %s "$BAO_SECRET_ID" > "$run/secret_id"
unset BAO_ROLE_ID BAO_SECRET_ID
# The CA as an absolute path: the agent reads BAO_CACERT from the environment too.
case $BAO_CACERT in /*) ;; *) BAO_CACERT="$(pwd)/$BAO_CACERT" ;; esac
export BAO_CACERT

# The command, quoted for HCL.
cmd=""
for a in "$@"; do
  cmd="$cmd\"$(printf %s "$a" | sed 's/\\/\\\\/g; s/"/\\"/g')\", "
done

cat > "$run/agent.hcl" <<HCL
vault {
  address = "$BAO_ADDR"
  ca_cert = "$BAO_CACERT"
}

auto_auth {
  method {
    type      = "approle"
    namespace = "$BAO_NAMESPACE"
    config {
      role_id_file_path                   = "$run/role_id"
      secret_id_file_path                 = "$run/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }
}

template_config {
  static_secret_render_interval = "5m"
  exit_on_retry_failure         = true
}

# One env_template per value your app reads.
env_template "WEATHER_API_KEY" {
  contents             = "{{ with secret \"secrets/data/backend/weather\" }}{{ .Data.data.api_key }}{{ end }}"
  error_on_missing_key = true
}

exec {
  command                   = [${cmd%, }]
  restart_on_secret_changes = "always"
  restart_stop_signal       = "SIGTERM"
}
HCL

bao agent -config="$run/agent.hcl"

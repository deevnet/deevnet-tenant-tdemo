#!/bin/sh
# Push a metric to your tenant's metrics store, read it back, and check that
# each token does only its own job.
#
#   scripts/metrics-check.sh kit.env
#
# Reads METRICS_ENDPOINT, LOG_INGEST_TOKEN, LOG_READ_TOKEN and LOG_SELECT_HEADER
# from kit.env (the metrics store takes the log tokens). Runs the same on your
# computer and on the workload. Needs curl.
set -eu
[ $# -eq 1 ] || { echo "usage: $0 kit.env" >&2; exit 2; }
set -a; . "./$1"; set +a
: "${METRICS_ENDPOINT:?not in $1: provider 0.12 or later, then terraform output -raw kit_env again}"

ca=${MQTT_CA_FILE:-deevnet-root-ca.pem}
here=$(hostname 2>/dev/null || echo unknown)
fail=0

code() { curl -s -o /dev/null -w '%{http_code}' --cacert "$ca" "$@"; }
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok    $1 ($3)"; else echo "FAIL  $1: expected $2, got $3"; fail=1; fi
}
refused() { # name actual: anything but a 2xx
  case $2 in 2??) echo "FAIL  $1: answered $2"; fail=1 ;; *) echo "ok    $1 (refused, $2)" ;; esac
}

# Your index, from the select header's value (e.g. "X-Deevnet-Partition: 1-0").
index=${LOG_SELECT_HEADER##*: }; index=${index%%-*}
other=$((index + 1))

# One sample in the Prometheus text format; remote write works the same way.
check "push with the ingest token" 204 "$(code -H "Authorization: Bearer $LOG_INGEST_TOKEN" \
  --data-binary "tdemo_check{host=\"$here\"} $(date +%s)" "$METRICS_ENDPOINT/api/v1/import/prometheus")"

refused "push with the read token" "$(code -H "Authorization: Bearer $LOG_READ_TOKEN" \
  --data-binary 'tdemo_check 1' "$METRICS_ENDPOINT/api/v1/import/prometheus")"
refused "query with the ingest token" "$(code -H "Authorization: Bearer $LOG_INGEST_TOKEN" \
  "$METRICS_ENDPOINT/api/v1/query" --data-urlencode 'query=tdemo_check')"
refused "push naming tenant $other's partition" "$(code -H "Authorization: Bearer $LOG_INGEST_TOKEN" \
  --data-binary 'tdemo_check 1' "$METRICS_ENDPOINT/insert/$other:0/prometheus/api/v1/import/prometheus")"
refused "query across every tenant" "$(code -H "Authorization: Bearer $LOG_READ_TOKEN" \
  "$METRICS_ENDPOINT/select/multitenant/prometheus/api/v1/query" --data-urlencode 'query=up')"
check "query the platform's partition about you" 200 "$(code -H "Authorization: Bearer $LOG_READ_TOKEN" \
  -H "X-Deevnet-Partition: $index-1" "$METRICS_ENDPOINT/api/v1/query" --data-urlencode 'query=up')"

# The store hides the newest 30 seconds, so the sample shows after that.
echo "waiting 40s for the sample to be queryable..."
sleep 40
out=$(curl -sS --cacert "$ca" -H "Authorization: Bearer $LOG_READ_TOKEN" \
  "$METRICS_ENDPOINT/api/v1/query" --data-urlencode "query=tdemo_check{host=\"$here\"}")
case $out in
  *"\"host\":\"$here\""*) echo "ok    read back tdemo_check{host=\"$here\"}" ;;
  *) echo "FAIL  read back: $out"; fail=1 ;;
esac

# Naming another tenant's partition is not obeyed: the header only chooses
# among your own partitions, and anything else reads your own (index, 0).
out=$(curl -sS --cacert "$ca" -H "Authorization: Bearer $LOG_READ_TOKEN" -H "X-Deevnet-Partition: $other-0" \
  "$METRICS_ENDPOINT/api/v1/query" --data-urlencode "query=tdemo_check{host=\"$here\"}")
case $out in
  *"\"host\":\"$here\""*) echo "ok    naming tenant $other's partition reads your own" ;;
  *) echo "FAIL  naming tenant $other's partition: $out"; fail=1 ;;
esac

exit $fail

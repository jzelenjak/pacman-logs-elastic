#!/bin/bash
# Setup script for Elasticsearch.

set -euo pipefail
IFS=$'\n\t'

ES_HOST="${ES_HOST:-https://es:9200}"
ES_HOME_DIR="/usr/share/elasticsearch"
CA_CERT="${ES_HOME_DIR}/config/certs/ca/ca.crt"

# NOTE: This is a workaround as jq is not installed in the official Elasticsearch image
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

[ -z "${ELASTIC_PASSWORD:-}" ] && { echo "Set ELASTIC_PASSWORD to a non-empty value in the .env file"; exit 1; }
[ -z "${KIBANA_PASSWORD:-}" ] && { echo "Set KIBANA_PASSWORD to a non-empty value in the .env file"; exit 1; }

echo "Setting kibana_system password"
body="$(printf '{"password":"%s"}' "$(json_escape "$KIBANA_PASSWORD")")"
curl -sS --fail-with-body -X PUT --cacert "$CA_CERT" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" --data-binary "$body" \
  "${ES_HOST%/}/_security/user/kibana_system/_password"
echo

echo "Setting snapshot volume permissions"
chown 1000:0 /usr/share/elasticsearch/snapshots
chmod 775 /usr/share/elasticsearch/snapshots

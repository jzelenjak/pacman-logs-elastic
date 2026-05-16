#!/bin/bash
# Generates encryption keys for Kibana.
# See https://www.elastic.co/docs/reference/kibana/commands/kibana-encryption-keys

set -euo pipefail
IFS=$'\n\t'

[ -f .env ] && source .env || { echo "$0: cannot find .env file" >&2; exit 1; }

KIBANA_IMAGE=docker.elastic.co/kibana/kibana:${STACK_VERSION}

docker run --rm "$KIBANA_IMAGE" bin/kibana-encryption-keys generate

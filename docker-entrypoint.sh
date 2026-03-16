#!/bin/sh
set -eu

TEMPLATE_PATH="/etc/haproxy/templates/haproxy.cfg.template"
OUTPUT_PATH="/usr/local/etc/haproxy/haproxy.cfg"

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "Template not found: $TEMPLATE_PATH" >&2
  exit 1
fi

if [ -z "${DOMAIN_NAME:-}" ]; then
  echo "DOMAIN_NAME is required" >&2
  exit 1
fi

: "${HAPROXY_CERT_PATH:=/etc/haproxy/certs/${DOMAIN_NAME}.pem}"
export DOMAIN_NAME HAPROXY_CERT_PATH

envsubst '${DOMAIN_NAME} ${HAPROXY_CERT_PATH}' < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

exec "$@"

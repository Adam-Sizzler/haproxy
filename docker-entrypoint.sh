#!/bin/sh
set -eu

TEMPLATE_PATH="/etc/haproxy/templates/haproxy.cfg.template"
OUTPUT_PATH="/usr/local/etc/haproxy/haproxy.cfg"

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "Template not found: $TEMPLATE_PATH" >&2
  exit 1
fi

if [ -z "${HAPROXY_DOMAIN:-}" ]; then
  echo "HAPROXY_DOMAIN is required" >&2
  exit 1
fi

: "${HAPROXY_CERT_PATH:=/etc/haproxy/certs/${HAPROXY_DOMAIN}.pem}"
export HAPROXY_DOMAIN HAPROXY_CERT_PATH

envsubst '${HAPROXY_DOMAIN} ${HAPROXY_CERT_PATH}' < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

exec "$@"

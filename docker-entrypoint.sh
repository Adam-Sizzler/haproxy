#!/bin/sh
set -eu

TEMPLATE_CONF="/app/haproxy.cfg"
RUNTIME_CONF="/etc/haproxy/haproxy.cfg"
RUNTIME_DIR="$(dirname "$RUNTIME_CONF")"
SOCKET_DIR="/var/run/haproxy"
TMP_CONF="/tmp/haproxy.cfg"

mkdir -p "$RUNTIME_DIR" "$SOCKET_DIR"

if [ ! -f "$TEMPLATE_CONF" ]; then
    echo "ERROR: HAProxy template config not found: $TEMPLATE_CONF" >&2
    exit 1
fi

cp "$TEMPLATE_CONF" "$RUNTIME_CONF"

if grep -q '\${DOMAIN_NAME}' "$RUNTIME_CONF"; then
    DOMAIN_TO_USE="${DOMAIN_NAME:-example.com}"
    if [ -n "${DOMAIN_NAME:-}" ]; then
        echo "Using DOMAIN_NAME=$DOMAIN_NAME"
    else
        echo "WARNING: DOMAIN_NAME is empty. Using fallback example.com"
    fi

    ESCAPED_DOMAIN=$(printf '%s' "$DOMAIN_TO_USE" | sed 's/[\/&]/\\&/g')
    sed "s/\${DOMAIN_NAME}/$ESCAPED_DOMAIN/g" "$RUNTIME_CONF" > "$TMP_CONF"
    mv "$TMP_CONF" "$RUNTIME_CONF"
fi

# Fallback if certificate is placed directly at /etc/letsencrypt/haproxy.pem
if [ -f "/etc/letsencrypt/haproxy.pem" ]; then
    CERT_IN_CFG=$(grep -o '/etc/letsencrypt/[^ ]*\.pem' "$RUNTIME_CONF" | head -n 1 || true)
    if [ -n "$CERT_IN_CFG" ] && [ ! -f "$CERT_IN_CFG" ]; then
        echo "Certificate $CERT_IN_CFG not found, using existing /etc/letsencrypt/haproxy.pem"
        sed -i "s|$CERT_IN_CFG|/etc/letsencrypt/haproxy.pem|g" "$RUNTIME_CONF"
    fi
fi

echo "Checking HAProxy configuration..."
haproxy -c -f "$RUNTIME_CONF"

exec "$@"

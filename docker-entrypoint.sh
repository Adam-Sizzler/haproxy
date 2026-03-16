#!/bin/sh
set -e

SOURCE_CONF="/etc/haproxy/haproxy.cfg"
RENDERED_CONF="/tmp/haproxy.cfg"

cp "$SOURCE_CONF" "$RENDERED_CONF"

# 1. Обработка переменной DOMAIN_NAME только в рендер-копии.
if grep -q '\${DOMAIN_NAME}' "$RENDERED_CONF"; then
    DOMAIN_TO_USE="${DOMAIN_NAME:-example.com}"
    if [ -n "$DOMAIN_NAME" ]; then
        echo "Updating DOMAIN_NAME to: $DOMAIN_NAME"
    else
        echo "![WARNING]: DOMAIN_NAME not set, template found. Using example.com"
    fi

    # Escape replacement string for sed.
    ESCAPED_DOMAIN=$(printf '%s' "$DOMAIN_TO_USE" | sed 's/[\/&]/\\&/g')
    sed -i "s/\${DOMAIN_NAME}/$ESCAPED_DOMAIN/g" "$RENDERED_CONF"
fi

# 2. Проверка синтаксиса (чтобы контейнер не падал молча).
echo "Checking HAProxy configuration..."
haproxy -c -f "$RENDERED_CONF"

# 3. Запуск: если стартует haproxy, принудительно используем рендер-файл.
if [ "${1:-}" = "haproxy" ]; then
    exec haproxy -f "$RENDERED_CONF" -db
fi

exec "$@"

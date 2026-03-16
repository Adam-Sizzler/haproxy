#!/bin/sh
set -e

CONF="/etc/haproxy/haproxy.cfg"

# 1. Обработка переменной DOMAIN_NAME в /etc/haproxy/haproxy.cfg.
# Не используем sed -i, чтобы не создавать temp-файл в /etc/haproxy.
if grep -q '\${DOMAIN_NAME}' "$CONF"; then
    DOMAIN_TO_USE="${DOMAIN_NAME:-example.com}"
    if [ -n "$DOMAIN_NAME" ]; then
        echo "Updating DOMAIN_NAME to: $DOMAIN_NAME"
    else
        echo "![WARNING]: DOMAIN_NAME not set, template found. Using example.com"
    fi

    # Escape replacement string for sed и перезаписываем исходный файл.
    ESCAPED_DOMAIN=$(printf '%s' "$DOMAIN_TO_USE" | sed 's/[\/&]/\\&/g')
    sed "s/\${DOMAIN_NAME}/$ESCAPED_DOMAIN/g" "$CONF" > /tmp/haproxy.cfg
    cat /tmp/haproxy.cfg > "$CONF"
    rm -f /tmp/haproxy.cfg
fi

# 2. Проверка синтаксиса (чтобы контейнер не падал молча).
echo "Checking HAProxy configuration..."
haproxy -c -f "$CONF"

# 3. Стандартный запуск из CMD.
exec "$@"

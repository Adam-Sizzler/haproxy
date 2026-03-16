#!/bin/sh
set -e

CONF="/etc/haproxy/haproxy.cfg"

# 1. Обработка переменной
if [ -n "$DOMAIN_NAME" ]; then
    echo "Updating DOMAIN_NAME to: $DOMAIN_NAME"
    sed -i "s/\${DOMAIN_NAME}/$DOMAIN_NAME/g" "$CONF"
else
    # Если переменной нет, но в файле остался шаблон ${DOMAIN_NAME}, 
    # лучше заменить его на example.com, чтобы HAProxy не упал при старте.
    if grep -q '\${DOMAIN_NAME}' "$CONF"; then
        echo "![WARNING]: DOMAIN_NAME not set, but template found. Using example.com"
        sed -i "s/\${DOMAIN_NAME}/example.com/g" "$CONF"
    fi
fi

# 2. Проверка синтаксиса (чтобы контейнер не падал молча)
echo "Checking HAProxy configuration..."
haproxy -c -f "$CONF"

# 3. Запускаем то, что передано в CMD (стандартный механизм Docker)
exec "$@"
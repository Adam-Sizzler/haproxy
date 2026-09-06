# HAProxy

Высокопроизводительный шлюз HAProxy с автодеплоем по GitHub Release, поддержкой TLS-терминации, мультипротокольной идентификации (VLESS, Trojan, AnyTLS) и базовой L7 аутентификацией для NaiveProxy.

## Что снаружи

Наружу пробрасывается шаблон:

- `haproxy/haproxy.cfg`

`lua`-скрипты встроены в образ (`FROM haproxy:3.2-alpine`), а рабочий конфиг в контейнере генерируется при старте.

## Архитектура обработки трафика

1. **L4 TLS Frontend (`haproxy-tls`, порт 443)**:
   - Принимает TLS-соединения с ALPN `h2,http/1.1`.
   - Проверяет SNI (`DOMAIN_NAME`).
   - Идентифицирует протоколы Trojan, VLESS и AnyTLS через sample-fetch `lua.identify_protocol` и перенаправляет в соответствующие TCP-бэкенды.
   - HTTP/2 и веб-трафик передаются через loopback-прокси (`to-internal-http`) в L7 frontend.
2. **L7 HTTP Frontend (`internal-http`, 127.0.0.1:10080 accept-proxy)**:
   - Обрабатывает VLESS gRPC (`/google.internal.metrics.v1`).
   - Выполняет L7-аутентификацию NaiveProxy через sample-fetch `lua.auth_naive` (проверка заголовка `Proxy-Authorization: Basic <token>` по базе `users.csv`).
   - При успешной авторизации отправляет трафик в `backend naive` (sing-box H2 inbound).
   - При отсутствии или неверной авторизации трафик уходит в `default_backend nginx`.

## Формат `users.csv`

Файл учетных записей монтируется в `/etc/haproxy/data/users.csv`.
Формат строго двухколоночный:
```text
<username>,<credential>
```

Где `<credential>` может быть:
- **VLESS**: UUID (32 символа без дефисов или 36 символов со стандартными дефисами)
- **Trojan**: SHA224-хэш пароля (56 символов hex)
- **AnyTLS**: SHA256-хэш пароля (64 символа hex)
- **NaiveProxy**: `basic:<base64(username:password)>` или `Basic <token>`

Пример (`haproxy/data/users.csv.example`):
```csv
user-vless,11111111-1111-1111-1111-111111111111
trojan-user,0123456789abcdef0123456789abcdef0123456789abcdef01234567
anytls-user,0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd
naive-user,basic:dXNlcm5hbWU6cGFzc3dvcmQ=
```

## Runtime reload users.csv (без рестарта контейнера)

HAProxy публикует admin socket:

- `/var/run/haproxy/haproxy.sock`

В Lua-модуле доступны runtime-команды:

- `lua reload users` — перечитать `/etc/haproxy/data/users.csv` в Lua-кэш
- `lua show users cache [limit]` — показать текущее состояние кэша и пользователей

Пример вызова:

```bash
docker exec haproxy sh -lc "printf 'lua reload users\n' | socat - UNIX-CONNECT:/var/run/haproxy/haproxy.sock"
docker exec haproxy sh -lc "printf 'lua show users cache 20\n' | socat - UNIX-CONNECT:/var/run/haproxy/haproxy.sock"
```

Пример ответа:

```text
OK reload users: users=5 vless=2 trojan=1 anytls=1 naive=1 updated_at=2026-09-06T14:44:23Z reloads=2
users=5 vless=2 trojan=1 anytls=1 naive=1 reloads=2 updated_at=2026-09-06T14:44:23Z
user alice
user bob
...
```

Это позволяет обновлять авторизацию по `users.csv` мгновенно, без `docker restart`, без потери активных соединений и без сигнала HUP.

## Домен через env

В `haproxy.cfg` используется переменная:

- `${DOMAIN_NAME}`

При старте контейнера:

- шаблон читается из `/app/haproxy.cfg` (обычно bind-mount с хоста, `:ro`)
- создается runtime-конфиг `/etc/haproxy/haproxy.cfg`
- в runtime-конфиг подставляется `${DOMAIN_NAME}`

Исходный файл шаблона на хосте не изменяется.

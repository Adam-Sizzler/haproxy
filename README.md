# HAProxy

Минимальный репозиторий HAProxy с автодеплоем по GitHub Release.

## Что снаружи

Наружу пробрасывается шаблон:

- `haproxy/haproxy.cfg`

`lua`-скрипты встроены в образ (`FROM haproxy:3.2-alpine`), а рабочий конфиг
в контейнере генерируется при старте.

## Локальный запуск

1. Указать домен в .env:
   - `DOMAIN_NAME=your.domain.com`
2. Запустить:
   - `docker compose up -d`

`users.csv` по умолчанию ожидается в volume `haproxy-data` по пути
`/app/haproxy/data/users.csv`. Его может заполнять внешний сервис (например, node).
Пример формата хранится в репозитории: `haproxy/data/users.csv.example`.

## Runtime reload users.csv (без рестарта контейнера)

HAProxy публикует admin socket:

- `/var/run/haproxy/haproxy.sock`

В Lua-модуле доступны runtime-команды:

- `lua reload users` — перечитать `/etc/haproxy/data/users.csv` в Lua-кэш
- `lua show users cache [limit]` — показать текущее состояние кэша

Пример вызова:

```bash
docker exec haproxy sh -lc "printf 'lua reload users\n' | socat - UNIX-CONNECT:/var/run/haproxy/haproxy.sock"
docker exec haproxy sh -lc "printf 'lua show users cache 20\n' | socat - UNIX-CONNECT:/var/run/haproxy/haproxy.sock"
```

Пример ответа:

```text
OK reload users: users=5 vless=2 trojan=3 updated_at=2026-04-04T06:15:39Z reloads=2
users=5 vless=2 trojan=3 reloads=2 updated_at=2026-04-04T06:15:39Z
user alice
user bob
...
```

Это позволяет обновлять авторизацию по `users.csv` с минимальной задержкой, без `docker restart` и без сигнала HUP контейнеру.

## Домен через env

В `haproxy.cfg` используются переменные:

- `${DOMAIN_NAME}`

При старте контейнера:

- шаблон читается из `/app/haproxy.cfg` (обычно bind-mount с хоста, `:ro`)
- создается runtime-конфиг `/etc/haproxy/haproxy.cfg`
- в runtime-конфиг подставляется `${DOMAIN_NAME}`

Исходный файл на хосте не изменяется.

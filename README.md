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

## Домен через env

В `haproxy.cfg` используются переменные:

- `${DOMAIN_NAME}`

При старте контейнера:

- шаблон читается из `/app/haproxy.cfg` (обычно bind-mount с хоста, `:ro`)
- создается runtime-конфиг `/etc/haproxy/haproxy.cfg`
- в runtime-конфиг подставляется `${DOMAIN_NAME}`

Исходный файл на хосте не изменяется.

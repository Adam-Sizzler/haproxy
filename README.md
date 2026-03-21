# HAProxy

Минимальный репозиторий HAProxy с автодеплоем по GitHub Release.

## Что снаружи

Наружу пробрасываются только:

- `haproxy.cfg` (шаблон)

`lua`-скрипты встроены в образ (`FROM haproxy:3.2-alpine`).

## Локальный запуск

1. Скопировать переменные:
   - `cp .env.example .env`
2. Указать домен:
   - `DOMAIN_NAME=your.domain.com`
3. Запустить:
   - `docker compose up -d --build`

`users.csv` по умолчанию ожидается в volume `haproxy-data` по пути
`/app/haproxy/data/users.csv`. Его может заполнять внешний сервис (например, node).
Пример формата хранится в репозитории: `haproxy/data/users.csv.example`.

## Домен через env

В `haproxy.cfg` используются переменные:

- `${DOMAIN_NAME}`

При старте контейнера (если в файле есть `${DOMAIN_NAME}`) шаблон подставляется прямо в
`/etc/haproxy/haproxy.cfg`, после чего HAProxy запускается с этим системным путем.

## Сборка образа по релизу

Workflow: `.github/workflows/deploy-on-release.yml`

Триггер: публикация релиза (`release.published`).

Что делает workflow:

- Собирает Docker-образ из `Dockerfile`
- Публикует образ в `ghcr.io/<owner>/haproxy`
- Ставит теги `latest` и тег релиза

Дополнительные SSH/серверные секреты не нужны.

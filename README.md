# HAProxy

Минимальный репозиторий HAProxy с автодеплоем по GitHub Release.

## Что снаружи

Наружу пробрасываются только:

- `haproxy.cfg` (шаблон)
- `data/users.csv`

`lua`-скрипты встроены в образ (`FROM haproxy:3.2-alpine`).

## Локальный запуск

1. Скопировать переменные:
   - `cp .env.example .env`
2. Указать домен:
   - `HAPROXY_DOMAIN=your.domain.com`
3. Создать пользователей:
   - `cp data/users.csv.example data/users.csv`
4. Запустить:
   - `docker compose up -d --build`

## Домен через env

В `haproxy.cfg` используются переменные:

- `${HAPROXY_DOMAIN}`
- `${HAPROXY_CERT_PATH}`

При старте контейнера шаблон рендерится в реальный `/usr/local/etc/haproxy/haproxy.cfg`.

## Автодеплой по релизу

Workflow: `.github/workflows/deploy-on-release.yml`

Триггер: публикация релиза (`release.published`).

Нужные GitHub Secrets:

- `DEPLOY_HOST`
- `DEPLOY_USER`
- `DEPLOY_SSH_KEY`
- `DEPLOY_PORT` (опционально)
- `DEPLOY_PATH` (путь до директории с `docker-compose.yml` на сервере)

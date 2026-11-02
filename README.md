# AiDreamsStudioDevops

Общий nginx для подпроектов AiDreamsStudio. Принимает трафик на 80/443 и по домену проксирует в контейнеры через docker-сеть `aidreams`:

| Домен (env)                         | Контейнер     | Проект                 |
|-------------------------------------|---------------|------------------------|
| `MAIN_DOMAIN`, `www.MAIN_DOMAIN`    | `front:80`    | AiDreamsStudioFront    |
| `PARTNERS_DOMAIN`                   | `partners:80` | AiDreamsStudioPartners |

`/api` и WebSocket проксируют на бэкенд (`backend:3000`) сами фронты, у каждого свой nginx внутри контейнера. Запросы к неизвестным хостам и по IP отбрасываются.

## Структура

```
docker-compose.yml          nginx + certbot (профиль certbot)
nginx/http/*.conf.template  режим без TLS
nginx/https/*.conf.template режим с TLS и редиректом http → https
nginx/snippets/             общие куски: прокси, ACME, TLS
certs/                      /etc/letsencrypt (в git не попадает)
certbot/www/                webroot для ACME-проверки
```

Шаблоны превращаются в `conf.d/*.conf` при старте контейнера: `${MAIN_DOMAIN}` и `${PARTNERS_DOMAIN}` подставляются из env.

## Запуск

```bash
cp .env.example .env        # домены и NGINX_MODE

# порядок важен: сеть aidreams создаёт бэкенд
(cd ../AiDreamsStudio         && docker compose --profile app up -d --build)
(cd ../AiDreamsStudioFront    && docker compose up -d --build)
(cd ../AiDreamsStudioPartners && docker compose up -d --build)
docker compose up -d
```

Перезапуск после правки конфигов или `.env`: `docker compose up -d --force-recreate nginx`.

## Сертификаты

### Let's Encrypt

DNS-записи доменов должны указывать на сервер, nginx запущен в режиме `http`: он уже отдаёт `/.well-known/acme-challenge/`.

Сертификатов два, по одному на домен: `nginx/https` ждёт их в `certs/live/<MAIN_DOMAIN>/` и `certs/live/<PARTNERS_DOMAIN>/`. Папка называется по первому `-d`. Подставьте свои домены и почту (на неё Let's Encrypt пишет об истекающих сертификатах):

```bash
# основной домен + www — один сертификат на оба имени
docker compose --profile certbot run --rm certbot \
  "certbot certonly --webroot -w /var/www/certbot --agree-tos --no-eff-email -m you@example.com -d aidreamsstudio.ru -d www.aidreamsstudio.ru"

# кабинет партнёров
docker compose --profile certbot run --rm certbot \
  "certbot certonly --webroot -w /var/www/certbot --agree-tos --no-eff-email -m you@example.com -d partners.aidreamsstudio.ru"
```

`run --rm` создаёт одноразовый контейнер certbot: он выпускает сертификат в `certs/` и удаляется. Для проверки без лимитов Let's Encrypt добавьте `--dry-run`.

Затем в `.env` поставить `NGINX_MODE=https` и выполнить:

```bash
docker compose --profile certbot up -d --force-recreate
```

Так поднимутся nginx и certbot. Certbot проверяет продление раз в 12 ч, nginx перечитывает сертификаты раз в 6 ч.

### Свои сертификаты

Положите файлы в `certs/live/<домен>/fullchain.pem` и `certs/live/<домен>/privkey.pem` для каждого домена (для `www` подходит сертификат основного домена, если в нём есть `www`). Затем поставьте `NGINX_MODE=https` и запустите `docker compose up -d --force-recreate`. Certbot в этом случае не нужен.

HSTS выключен, его можно включить в `nginx/snippets/ssl.conf`, когда HTTPS заработает на всех доменах.

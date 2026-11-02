#!/bin/sh
# Раз в 6 ч перечитывает конфиг — подхватывает продлённые certbot сертификаты.
# Скрипты /docker-entrypoint.d/ образ запускает перед стартом nginx; цикл уходит в фон и живёт рядом с ним.
(while :; do sleep 6h; nginx -s reload; done) &

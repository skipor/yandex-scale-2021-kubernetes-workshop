#!/usr/bin/env bash
set -eu

# Посылает запросы в clock сервис пока выполнение не прервут.
# На каждый запрос выводит 'ok' или 'FAIL <HTTP код>' и номер запроса.

i=0
while true; do
  i=$((i + 1))
  CODE=$(curl "http://scale-2021-k8s-workshop.yandex.cloud/clock" -w "%{http_code}" -s -o /dev/null)
  if [[ "$CODE" == 200 ]] ; then
    echo "ok $i"
  else
    echo "FAIL $CODE $i"
  fi
done

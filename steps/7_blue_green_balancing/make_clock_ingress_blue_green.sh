#!/usr/bin/env bash
set -eu

# NOTE: perl, т.к. inplace замена через sed немного разная на macOS и Linux
\cp -f steps/7_blue_green_balancing/clock_backend_group.yaml deploy
echo "- Добавлен файл ./deploy/clock_backend_group.yaml с ресурсом указывающим веса балансировки blue и green деплойментов"

\cp -f steps/7_blue_green_balancing/ingress.yaml deploy

# \cp снимает 'alias cp='cp -i', которые требует интерактивного подтверждения перезаписи файла.
\cp -f steps/7_blue_green_balancing/ingress.yaml deploy
ALB_IP=$(yc vpc address get alb-ingress --format json  | jq '.external_ipv4_address.address' -r)
SUBNET=$(yc k8s node-group get default --format json | jq '.allocation_policy.locations[0].subnet_id' -r)
perl -pe "s/ALB_IP/${ALB_IP}/g; s/SUBNET/${SUBNET}/g" -i ./deploy/ingress.yaml
echo "- В ./deploy/ingress.yaml clock маршрут перенаправлен на clock backend group"

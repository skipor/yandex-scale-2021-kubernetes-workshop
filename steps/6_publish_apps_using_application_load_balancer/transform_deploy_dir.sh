#!/usr/bin/env bash
set -eu

# NOTE: perl, т.к. inplace замена через sed немного разная на macOS и Linux

find ./deploy -name service.yaml | xargs perl -pe "s/ClusterIP/NodePort/g" -i
echo "- Тип сервисов изменён на NodePort"

# \cp снимает 'alias cp='cp -i', которые требует интерактивного подтверждения перезаписи файла.
\cp -f steps/6_publish_apps_using_application_load_balancer/ingress.yaml deploy
ALB_IP=$(yc vpc address get alb-ingress --format json  | jq '.external_ipv4_address.address' -r)
SUBNET=$(yc k8s node-group get default --format json | jq '.allocation_policy.locations[0].subnet_id' -r)
perl -pe "s/ALB_IP/${ALB_IP}/g" -i ./deploy/ingress.yaml
perl -pe "s/SUBNET/${SUBNET}/g" -i ./deploy/ingress.yaml
echo "- Добавлен ./ingress.yaml"

tree ./deploy

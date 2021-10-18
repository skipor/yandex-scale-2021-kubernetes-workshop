#!/usr/bin/env bash

# Добавляет отображение хоста scale-2021-k8s-workshop.yandex.cloud в IP адрес вашего ALB
# путём добавления (замены) записи в /etc/hosts
set -eu

if [ "$EUID" -ne 0 ]
  then echo "Please run as 'sudo $0'"
  exit 1
fi

ALB_IP=$(yc vpc address get alb-ingress --format json  | jq '.external_ipv4_address.address' -r)
# Удалим строку с записью если она уже была
sudo perl -pe "s/.* scale-2021-k8s-workshop.yandex.cloud//g" -i /etc/hosts
# Добавим новую запись
echo "${ALB_IP:?} scale-2021-k8s-workshop.yandex.cloud" | sudo tee -a /etc/hosts



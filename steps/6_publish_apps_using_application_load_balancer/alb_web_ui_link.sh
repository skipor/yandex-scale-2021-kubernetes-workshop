#!/usr/bin/env bash
set -eu

FOLDER_ID=$(yc config get folder-id)
ALB_ID=$(yc application-load-balancer load-balancer list --format json | jq '.[0].id' -r)
echo "https://console.cloud.yandex.ru/folders/${FOLDER_ID}/application-load-balancer/load-balancer/${ALB_ID}/map"

#!/usr/bin/env bash

set -ux

ALB_ID="$(yc application-load-balancer load-balancer list --format json | jq '.[0].id' -r)"
yc alb load-balancer delete --id "$ALB_ID"
yc vpc address --name alb-ingress delete

FOLDER_NAME="$(yc resource folder get "$(yc config get folder-id)" --format json | jq .name -r)"
yc iam service-account delete --name "${FOLDER_NAME:?}-k8s-alb-ingress-controller"

source set_tf_vars_from_yc_config.sh
terraform apply --destroy --auto-approve

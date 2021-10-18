#!/usr/bin/env bash

set -euxo pipefail

ALB_IP=$(yc vpc address get alb-ingress --format json  | jq '.external_ipv4_address.address' -r)
SUBNET=$(yc k8s node-group get default --format json | jq '.allocation_policy.locations[0].subnet_id' -r)

PREPROVISION_DIR="$(cd "$(dirname "$0")" && pwd)"
perl <"$PREPROVISION_DIR/alb_holder_dummy_ingress.tmpl.yaml" -pe "s/ALB_IP/${ALB_IP}/g; s/SUBNET/${SUBNET}/g"

#!/usr/bin/env bash

set -euxo pipefail

PREPROVISION_DIR="$(cd "$(dirname "$0")" && pwd)"
"$PREPROVISION_DIR"/alb_holder_dummy_ingress.sh | kubectl apply -f -

MAX=60
for i in {0...MAX}; do
  ALBs=$(yc application-load-balancer load-balancer list --format json)
  if [[ $(jq <<< "$ALBs" length) == 0 || $(jq <<< "$ALBs" '.[0].id' -r) == "null" ]] ; then
    echo "There is no creating ALB since ${i} seconds..."
    if [[ "$i" == "$MAX" ]]; then
      echo "ALB creation not started..."
      exit 1
    fi
    sleep 1
    echo "ALB creating!"
    break
  fi
done

ALBs=$(yc application-load-balancer load-balancer list --format json | tee /dev/stderr)
ALB_ID=$(jq <<< "$ALBs" '.[0].id' -r)
OPERATION_ID=$(yc application-load-balancer load-balancer list-operations --id "$ALB_ID" --format json | jq '.[0].id' -r)

echo "Waiting for ALB creation..."
yc operation wait "${OPERATION_ID}"
echo "ALB Created!"

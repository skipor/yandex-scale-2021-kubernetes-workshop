#!/usr/bin/env bash

set -euxo pipefail

PREPROVISION_DIR="$(cd "$(dirname "$0")" && pwd)"
ln -fs "$PREPROVISION_DIR"/*.tf .

source set_tf_vars_from_yc_config.sh

terraform init

# Починит state, если создание ресурса было прервано
# "$PREPROVISION_DIR"/import_all.sh || true

terraform apply --auto-approve

export KUBECONFIG="$PWD/kubeconfig.yaml"
yc k8s cluster --name workshop get-credentials --force --external --kubeconfig "$KUBECONFIG"

kubectl cluster-info
kubectl get namespace workshop || kubectl create namespace workshop

"$PREPROVISION_DIR"/install_yc_alb_ingress_controller.sh
"$PREPROVISION_DIR"/alb.sh

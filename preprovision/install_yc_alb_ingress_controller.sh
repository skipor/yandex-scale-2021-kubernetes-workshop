#!/usr/bin/env bash

set -euxo pipefail

# Скрипт устанавливает Yandex Cloud Application Load Balancer ingress controller
# Основано на https://cloud.yandex.ru/docs/managed-kubernetes/solutions/alb-ingress-controller

FOLDER_ID="$(yc config get folder-id)"
FOLDER_NAME="$(yc resource folder get "$FOLDER_ID" --format json | jq .name -r)"
ALB_INGRESS_SA_NAME=${FOLDER_NAME}-k8s-alb-ingress-controller

kubectl create namespace yc-alb-ingress || true

if ! kubectl get secret -n yc-alb-ingress yc-alb-ingress-controller-sa-key; then
  KEY_FILE=sa-key.json
  yc iam key create --service-account-name "${ALB_INGRESS_SA_NAME:?}" --output "$KEY_FILE"
  kubectl delete secret -n yc-alb-ingress yc-alb-ingress-controller-sa-key || true
  kubectl create secret generic -n yc-alb-ingress yc-alb-ingress-controller-sa-key \
    --from-file="${KEY_FILE}"
  rm -rf "${KEY_FILE}"
fi


if ! helm status -n yc-alb-ingress yc-alb-ingress-controller; then
  CHART_VERSION=v0.0.6
  export HELM_EXPERIMENTAL_OCI=1

  if [[ ! -f ./yc-alb-ingress-controller/ ]]; then
    helm chart pull "cr.yandex/crpsjg1coh47p81vh2lc/yc-alb-ingress-controller-chart:${CHART_VERSION}"
    helm chart export "cr.yandex/crpsjg1coh47p81vh2lc/yc-alb-ingress-controller-chart:${CHART_VERSION}"
  fi

  CLUSTER_ID=$(yc k8s cluster get workshop --format json | jq .id)
  helm install \
    --namespace yc-alb-ingress \
    --set "folderId=${FOLDER_ID:?}" \
    --set "clusterId=${CLUSTER_ID:?}" \
    yc-alb-ingress-controller ./yc-alb-ingress-controller/

  kubectl rollout status -n yc-alb-ingress deployment/yc-alb-ingress-controller
fi

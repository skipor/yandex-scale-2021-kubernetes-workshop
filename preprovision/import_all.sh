#!/usr/bin/env bash
set -x
set +o

# Сеть и подсети
terraform import 'yandex_vpc_network.default' "$(yc vpc network get default --format json | jq .id -r)"
terraform import 'yandex_vpc_subnet.default[0]' "$(yc vpc subnet get default-a --format json | jq .id -r)"
terraform import 'yandex_vpc_subnet.default[1]' "$(yc vpc subnet get default-b --format json | jq .id -r)"
terraform import 'yandex_vpc_subnet.default[2]' "$(yc vpc subnet get default-c --format json | jq .id -r)"

FOLDER_NAME="$(yc resource folder get "$(yc config get folder-id)" --format json | jq .name -r)"

# Сервисный аккаунт Kubernetes кластера и его биндинг роли
terraform import 'yandex_iam_service_account.k8s' "$(yc iam service-account get "${FOLDER_NAME:?}-k8s" --format json | jq .id -r)"
terraform import 'yandex_resourcemanager_folder_iam_binding.sa_k8s_editor' "$(yc config get folder-id) editor"

# Сервисный аккаунт Kubernetes узлов и его биндинг роли
terraform import 'yandex_iam_service_account.k8s_nodes' "$(yc iam service-account get "${FOLDER_NAME:?}-k8s-nodes" --format json | jq .id -r)"
terraform import 'yandex_resourcemanager_folder_iam_binding.sa_k8s_nodes_image_puller' "$(yc config get folder-id) container-registry.images.puller"

# KMS ключ шифрования секретов кластера Kubernetes
terraform import 'yandex_kms_symmetric_key.k8s_cluster_workshop' "$(yc kms symmetric-key --name k8s-cluster-workshop get --format json | jq .id -r)"

# Кластер Kubernetes
terraform import 'yandex_kubernetes_cluster.workshop' "$(yc k8s cluster get workshop --format json | jq .id -r)"

# Группа узлов Kubernetes
terraform import 'yandex_kubernetes_node_group.default' "$(yc k8s node-group get default --format json | jq .id -r)"


# Другие предсозданные ресурсы

terraform import yandex_iam_service_account.alb_ingress_controller "$(yc iam service-account get --name "${FOLDER_NAME:?}-k8s-alb-ingress-controller")"
terraform import yandex_vpc_address.alb_ingress "$(yc vpc address --name alb-ingress get --format json | jq -r .id)"

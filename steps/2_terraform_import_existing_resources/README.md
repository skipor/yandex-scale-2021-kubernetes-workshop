# Импортируем существующие ресурсы

Познакомимся с ресурсами в каталоге:
```bash
FOLDER_ID=$(yc config get folder-id)
(
set -x # Чтобы видеть команду перед её выводом
yc resource folder --id ${FOLDER_ID:?} get
yc vpc network list
yc vpc subnet list

yc iam service-account list
yc resource folder --id ${FOLDER_ID:?} list-access-bindings

yc kms symmetric-key list

yc k8s cluster list
yc k8s cluster --name workshop list-node-groups
yc k8s cluster --name workshop list-nodes
)
```

Иницилизируем `terraform` в каталоге
```bash
# Выставим для terraform переменные с OAUTH токеном и ID каталога взяв их из `yc config`.
source ./set_tf_vars_from_yc_config.sh 

terraform init
```

Посмотрим `terraform plan`
```bash
terraform plan
```

Т.к. state пустой, в плане создание всех ресурсов. Для перевода существующих ресурсов под управление terraform, их 
нужно добавить в state.

Для этого, для каждого ресурса нужно выполнить команду `terraform import` передав имя в terraform и идентификатор в 
облаке:
```bash
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
```

Запустим ещё раз `plan`, чтобы убедиться, что он пустой - актуальное состояние ресурсов соответствует целевому:
```bash
terraform plan
```


### [cледующий этап >>>](../3_terraform_remote_state/README.md)

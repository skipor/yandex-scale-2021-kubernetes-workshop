// Зональный кластер подойдёт для тестирования и значительно дешевле зонального.
// Для запуска производственной (production) нагрузки, рекомендуется использовать региональный отказоустойчивый мастер.
resource "yandex_kubernetes_cluster" "workshop" {
  name                    = "workshop"
  release_channel         = "RAPID"
  network_id              = yandex_vpc_network.default.id
  service_account_id      = yandex_iam_service_account.k8s.id
  node_service_account_id = yandex_iam_service_account.k8s_nodes.id

  master {
    zonal {
      zone = local.zone
    }
    public_ip = true
    version   = "1.20"
  }

  // Шифруем все секреты хранящиеся в кластере используя указанные KMS ключ.
  // Подробнее:
  // - https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/
  // - https://cloud.yandex.ru/docs/kms/concepts/envelope
  kms_provider {
    key_id = yandex_kms_symmetric_key.k8s_cluster_workshop.id
  }

  depends_on = [
    // Ресурс биндинга роли не используется в ресурсе кластера напрямую, поэтому необходимо объявить зависимость явно.
    // Иначе кластер может начать создаваться без него, или разрушаться (terraform destroy) после его разрушения.
    yandex_resourcemanager_folder_iam_binding.sa_k8s_editor,
    // Подсеть выберется автоматически на основании указанной зоны, но их создания нужно дождаться.
    yandex_vpc_subnet.default,
  ]
}


// Для тестирования достаточно пары "легких" и недорогих узлов в одной зоне с мастером.
// Для запуска производственной (production) нагрузки, рекомендуется распределить узлы по трём зонам.
resource "yandex_kubernetes_node_group" "default" {
  cluster_id = yandex_kubernetes_cluster.workshop.id
  name       = "default"
  version    = "1.20"

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    location {
      zone = local.zone
    }
  }

  instance_template {
    platform_id = "standard-v2"
    resources {
      cores         = 2
      core_fraction = 20
      memory        = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    network_interface {
      nat        = true
      subnet_ids = [local.zone_subnet_id]
    }
  }
}

// Ключ который будет использовать KMS provider кластера Managed Kubernetes.
resource "yandex_kms_symmetric_key" "k8s_cluster_workshop" {
  name              = "k8s-cluster-workshop"
  description       = "KMS key, for Managed Kubernetes cluster KMS provider"
  default_algorithm = "AES_128"
  rotation_period   = "${365 * 24}h"
}


resource "yandex_iam_service_account" "k8s" {
  name        = "${data.yandex_resourcemanager_folder.workshop.name}-k8s"
  description = "Service account for k8s cluster"
}

// Кластер будет управлять узлами и другими сущностями в нашем каталоге от имени указанного сервисного аккаунта,
// поэтому ему нужно выдать права необходимые для этого.
resource "yandex_resourcemanager_folder_iam_binding" "sa_k8s_editor" {
  folder_id = local.folder_id
  role      = "editor"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s.id}"]
}

resource "yandex_iam_service_account" "k8s_nodes" {
  name        = "${data.yandex_resourcemanager_folder.workshop.name}-k8s-nodes"
  description = "Service account for k8s nodes"
}

// Получение токенов сервисного аккаунта узлов будет доступна через сервис метаданных на узлах,
// который может быть доступен из подов, если это не было ограниченно через NetworkPolicies.
// Поэтому особенно важно выдать ему минимально необходимые права.
resource "yandex_resourcemanager_folder_iam_binding" "sa_k8s_nodes_image_puller" {
  folder_id = local.folder_id
  role      = "container-registry.images.puller"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_nodes.id}"]
}



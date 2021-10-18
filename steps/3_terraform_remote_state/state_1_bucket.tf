// Бакет в котором будет храниться файл со state.
resource "yandex_storage_bucket" "terraform_state" {
  bucket     = "${data.yandex_resourcemanager_folder.workshop.name}-terraform-state"
  access_key = yandex_iam_service_account_static_access_key.terraform_state.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform_state.secret_key

  // Версионирование бакета позволит вернуть последний рабочий state, если он был случайно испорчен.
  // https://cloud.yandex.ru/docs/storage/concepts/versioning
  versioning {
    enabled = true
  }

  // Данные надёжно зашифрованы во время передачи, благодаря использованию HTTPS,
  // но необходимо отдельно включить шифрование во время хранения.
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.terraform_state.id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  // Дополнительно можно подключить:
  // - Аудит: https://cloud.yandex.ru/docs/overview/security/domains/secure-config#audit
  // - Дополнить/детализировать роли используя bucket policy и ACL: https://cloud.yandex.ru/docs/overview/security/domains/secure-config#object-storage-access

  // Убираем защиту от удаления на время практикума, т.к это временное окружение для обучения.
  // В реальности её обязательно нужно оставить не указывая этой строки.
  force_destroy = true
}

// Этим ключом будут зашифрованы данные хранящиеся в бакете.
// Расшифровка будет происходить перед их отдачей клиенту по HTTPS.
resource "yandex_kms_symmetric_key" "terraform_state" {
  name              = "terraform-state"
  description       = "KMS key, for terraform state bucket"
  default_algorithm = "AES_128"
  rotation_period   = "${365 * 24}h"
}


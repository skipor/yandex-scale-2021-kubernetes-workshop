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


  // При необходимости удалить бакет раскомментируйте и сделайте apply:
  // force_destroy = true
}

// Этим ключом будут зашифрованы данные хранящиеся в бакете.
// Расшифровка будет происходить перед их отдачей клиенту по HTTPS.
resource "yandex_kms_symmetric_key" "terraform_state" {
  name              = "terraform-state"
  description       = "KMS key, for terraform state bucket"
  default_algorithm = "AES_128"
  rotation_period   = "${365 * 24}h"
}

// В бессерверной базе данных YDB terraform будет хранить локи, предохраняющие от параллельной работы со state
// и его повреждения из-за этого.
resource "yandex_ydb_database_serverless" "terraform_locks" {
  name      = "terraform-locks"
  folder_id = local.folder_id
  labels    = {}

  // К сожалению, на момент октября 2021 для таблицы YDB Serverless нет готового ресурса в yandex-cloud Terraform провайдере,
  // а ресурс из aws провайдера не совместим.
  // Поэтому воспользуемся local-exec provisioner, который вызывает aws CLI в докере.
  // Инструкции по установке aws CLI: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
  provisioner "local-exec" {
    command     = <<-EOF
    set -euo pipefail
    
    until [[ "$(yc ydb database --id ${self.id} get --format json | jq .status -r)" == "RUNNING" ]] ; do
      echo "Waiting Serverless DB to become RUNNING..."
      sleep 1
    done

    # Чтобы не требовать установки aws CLI, запустим его в докере.
    # При желании можно установить aws CLI и заменить вызов docker на `aws`.
    # Инструкция по установки aws CLI: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html

    docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY amazon/aws-cli \
      dynamodb --region "us-east-1" --endpoint-url ${yandex_ydb_database_serverless.terraform_locks.document_api_endpoint} \
      create-table \
      --table-name tf_lock \
      --attribute-definitions  AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH
      
    EOF
    environment = {
      AWS_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.terraform_state.access_key
      // nonsensitive указывает Terraform, что можно показать вывод команды, не смотря на чувствительность передаваемого параметра.
      // Это безопасно, в случае если этот параметр не поддает в вывод.
      // Иначе вывод команды содержащий секрет может случайно утечь, например, в логи CI/CD, что может быть использовано для взлома.
      AWS_SECRET_ACCESS_KEY = nonsensitive(yandex_iam_service_account_static_access_key.terraform_state.secret_key)
    }
  }
}

resource "yandex_iam_service_account" "terraform_state" {
  name        = "${data.yandex_resourcemanager_folder.workshop.name}-terraform-state"
  description = "Service account for managing S3 buckets"
}

resource "yandex_iam_service_account_static_access_key" "terraform_state" {
  service_account_id = yandex_iam_service_account.terraform_state.id
  description        = "Key to access S3 buckets"

  depends_on = [
    yandex_resourcemanager_folder_iam_binding.terraform_state_storage_editor,
    yandex_resourcemanager_folder_iam_binding.terraform_state_encrypter_decrypter,
    yandex_resourcemanager_folder_iam_binding.terraform_state_ydb_admin,
  ]
}

// Для того, чтобы надёжно и безопасно сохранить ключ доступа к бакету, и разделить его с коллегами
// положим его в менеджер секретов - Yandex Lockbox.
// Для создания Lockbox секрета воспользуемся local-exec provisioner вызывающим `yc` CLI, 
// поскольку на момент октября 2021 года Lockbox в Preview и пока не поддержан в Terraform провайдере.
resource "null_resource" "lockbox_secret_terraform_state_secret_key" {
  provisioner "local-exec" {
    command     = <<-CMD
    # Для обеспечения корректной работы `terraform taint`, попробуем удалить ключ, на случай если он уже есть.
    yc lockbox secret delete terraform-state-secret-key 2> /dev/null || true

    yc lockbox secret create --name terraform-state-secret-key \
      --kms-key-id ${yandex_kms_symmetric_key.terraform_state.id} \
      --payload - \
      --labels "key_id=${self.id}" \
      --labels "service_account_id=${self.id}" \
    <<PAYLOAD
    [
      {"key": "access_key", "text_value": ${yandex_iam_service_account_static_access_key.terraform_state.access_key}},
      {"key": "secret_key", "text_value": $${secret_key}}
    ]
    PAYLOAD
    CMD
    environment = {
      secret_key = nonsensitive(yandex_iam_service_account_static_access_key.terraform_state.secret_key)
    }
  }
  provisioner "local-exec" {
    when = destroy
    command = <<-CMD
    yc lockbox secret delete terraform-state-secret-key
    CMD
  }
}

resource "yandex_resourcemanager_folder_iam_binding" "terraform_state_storage_editor" {
  folder_id = local.folder_id
  role      = "storage.admin"
  members   = ["serviceAccount:${yandex_iam_service_account.terraform_state.id}"]
}

resource "yandex_resourcemanager_folder_iam_binding" "terraform_state_encrypter_decrypter" {
  folder_id = local.folder_id
  role      = "kms.keys.encrypterDecrypter"
  members   = ["serviceAccount:${yandex_iam_service_account.terraform_state.id}"]
}

resource "yandex_resourcemanager_folder_iam_binding" "terraform_state_ydb_admin" {
  folder_id = local.folder_id
  role      = "ydb.admin"
  members   = ["serviceAccount:${yandex_iam_service_account.terraform_state.id}"]
}

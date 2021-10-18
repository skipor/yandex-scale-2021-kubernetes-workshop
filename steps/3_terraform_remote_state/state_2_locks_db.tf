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
    interpreter = ["/bin/bash", "-c"]
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


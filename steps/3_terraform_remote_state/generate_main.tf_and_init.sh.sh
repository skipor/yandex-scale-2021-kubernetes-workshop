#!/usr/bin/env bash
set -euo pipefail

if [[ "${DEBUG:-}" != "" ]] ; then
  set -x
fi

# Для получения значений из state, воспользуемся 'terraform show -json'

# Удалим предыдущий main.tf сразу, прежде чем сделать его снова.
# Иначе 'terraform show' требует 'terraform init'.
rm -f main.tf

BUCKET_STATE=$(terraform show -json | jq -r '
  .values.root_module.resources[] |
  select(.address == "yandex_storage_bucket.terraform_state") |
  .values
')

if [[ "$BUCKET_STATE" == "" ]] ; then
  echo "Bucket is not created. Copy 'state.tf' file and 'terraform apply' to create it"
  exit 1
fi

BUCKET=$(jq <<< "${BUCKET_STATE:?}" .bucket -r)
ACCESS_KEY=$(jq <<< "${BUCKET_STATE:?}" .access_key -r)

SERVERLESS_DB_ENDPOINT=$(terraform show -json | jq -r '
  .values.root_module.resources[] |
  select(.address == "yandex_ydb_database_serverless.terraform_locks") |
  .values.document_api_endpoint
')

cat - <<EOF > main.tf
terraform {
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "${BUCKET:?}"
    key        = "yandex-scale-2021-kubernetes-workshop.tfstate"
    access_key = "${ACCESS_KEY:?}"
    // Параметр 'secret_key' необходим, но не должен быть выставлен в коде,
    // т.к. код попадает в VCS, куда не должны попадать незашифрованные секреты.
    // Его необходимо выставить во время 'terraform init' передав параметр '-backend-config="secret_key=<secret_value>"'

    dynamodb_endpoint = "${SERVERLESS_DB_ENDPOINT}"
    dynamodb_table    = "tf_lock"

    // Параметры, которые для Yandex Cloud не имеют смысла, но их необходимо задать.
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    region                      = "us-east-1"
  }
}
EOF


cat <<EOF > init.sh
#!/usr/bin/env bash
set -euo pipefail

SECRET_KEY=\$(yc lockbox payload get --name terraform-state-secret-key --key secret_key)

terraform init --backend-config "secret_key=\${SECRET_KEY:?}" "\$@"
EOF
chmod +x init.sh

echo './main.tf and ./init.sh generated!'

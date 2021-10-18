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
    when    = destroy
    command = <<-CMD
    yc lockbox secret delete terraform-state-secret-key
    CMD
  }
}


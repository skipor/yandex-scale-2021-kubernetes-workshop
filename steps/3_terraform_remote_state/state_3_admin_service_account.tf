resource "yandex_iam_service_account" "terraform_state" {
  name        = "${data.yandex_resourcemanager_folder.workshop.name}-terraform-state"
  description = "Service account for managing S3 buckets"
}

resource "yandex_iam_service_account_static_access_key" "terraform_state" {
  service_account_id = yandex_iam_service_account.terraform_state.id
  description        = "Key to access S3 buckets"

  // Укажем выдачу ролей зависимостью, чтобы ресурсы требующие этого ключа не начали создаться, пока ролей нет.
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.terraform_state_storage_editor,
    yandex_resourcemanager_folder_iam_binding.terraform_state_encrypter_decrypter,
    yandex_resourcemanager_folder_iam_binding.terraform_state_ydb_admin,
  ]
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

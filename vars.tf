variable "folder_id" {
  description = <<-EOT
  ID of folder for the Yandex Scale 2021 Kubernetes workshop participant.
  Run:
    source ./set_tf_vars_from_yc_config.sh
  to set it from `yc config`.
  EOT
  type        = string
}

variable "yc_token" {
  description = <<-EOT
  OAuth token for the Yandex Scale 2021 Kubernetes workshop participant user account.
  Run:
    source ./set_tf_vars_from_yc_config.sh
  to set it from `yc config`.
  EOT
  type        = string
}


// Использование locals скрывает то, откуда берутся эти параметры.
// На бонусном шаге мы покажем как terraform может эти параметры из yc config самостоятельно.
locals {
  folder_id = var.folder_id
  yc_token  = var.yc_token
}


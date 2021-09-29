terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  token = "" // FIXME: make required variable
  folder_id = var.folder_id
  zone = local.zone
}

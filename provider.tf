terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    null   = {}
  }
}

provider "yandex" {
  folder_id = local.folder_id
  token     = local.yc_token
}

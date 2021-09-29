variable folder_id {
  description = "Folder for the Yandex Scale 2021 Kubernetes workshop participant"
  type = string
}

locals {
  zone_letters = [
    "a",
    "b",
    "c",
  ]
  zones = [for letter in local.zone_letters : "ru-central1-${letter}"]
  // Availability zone for cloud resources determined by the hash of the folder ID.
  zone = local.zones[parseint(md5(var.folder_id), 16) % 3]
}

data "yandex_resourcemanager_folder" "workshop" {
  id = var.folder_id
}

resource "yandex_vpc_network" "default" {
  folder_id = var.folder_id
  name = "default"
}

resource "yandex_vpc_subnet" "default" {
  count =  3
  network_id = yandex_vpc_network.default.id
  name = "default-${local.zone_letters[count.index]}"
  zone = local.zones[count.index]
  v4_cidr_blocks = ["10.${count.index}.0.0/16"]
}


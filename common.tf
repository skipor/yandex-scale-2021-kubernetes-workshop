// Импорт данных используемого каталога позволит использовать его имя,
// например при определении имени сервисного аккаунта.
data "yandex_resourcemanager_folder" "workshop" {
  folder_id = local.folder_id
}

resource "yandex_vpc_network" "default" {
  name = "default"
}

// В реальности, часто удобно создать подсети сразу во всех зонах.
// Чтобы не копировать несколько блоков, удобно создать их через конструкцию 'count'.
// Например, так определить подсети:
//   default-a: 10.0.0.0/16
//   default-b: 10.1.0.0/16
//   default-c: 10.2.0.0/16
locals {
  zone_letters = ["a", "b", "c"]
  zones        = [for letter in local.zone_letters : "ru-central1-${letter}"]
}
resource "yandex_vpc_subnet" "default" {
  count          = 3
  network_id     = yandex_vpc_network.default.id
  name           = "default-${local.zone_letters[count.index]}"
  zone           = local.zones[count.index]
  v4_cidr_blocks = ["10.${count.index}.0.0/16"]
}

locals {
  // В рамках практикума, как и для сценария тестирования,
  // оптимально будет развернуть все ресурсы в одной зоне.
  // Выберем зону случайно используя хеш от ID каталога,
  // чтобы равномерно распределить участников практикума по всем зонам.
  zone           = local.zones[parseint(md5(local.folder_id), 16) % 3]
  // При создании подсетей через 'count`, определить ID подсети для фиксированной зоны, можно
  // поиском индекса по значению в массиве с зонами.
  // Условное выражение нужно для избежании ошибки в случае, когда state утерян, и в нём ещё не все сети.
  zone_subnet_id = length(yandex_vpc_subnet.default) == 3 ? yandex_vpc_subnet.default[index(local.zones, local.zone)].id : ""
}


resource "yandex_container_registry" "workshop" {
  name      = "workshop"
  folder_id = local.folder_id

  // Окружение для практикума временное, поэтому пропишем provisioner, который удалит все образа
  // перед уничтожением registry, что позволит терраформу его удалить
  provisioner "local-exec" {
    when    = destroy
    command = <<-CMD
    yc container image list --registry-id ${self.id} --format json | jq '.[].id' -r | xargs -P 16 yc container image delete --id
    CMD
  }
}

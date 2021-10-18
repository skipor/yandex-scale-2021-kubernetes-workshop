resource "yandex_iam_service_account" "translate" {
  name        = "${data.yandex_resourcemanager_folder.workshop.name}-translate"
  description = "Service account for translate app"
}

// Согласно документации сервиса Yandex Translate, сервисному аккаунту требуется роль
// editor на каталог в котором он создан.
// Т.к. мы в рамках практикума ограничены одним каталогом, то выдадим роль на тот же где
// и все остальные ресурсы, однако в реальности, для минимизации ущерба от компрометации ключа,
// рекомендуется  выдать эту роль на отдельный пустой каталог.
resource "yandex_resourcemanager_folder_iam_binding" "translate_editor" {
  folder_id = local.folder_id
  role      = "editor"
  members   = ["serviceAccount:${yandex_iam_service_account.translate.id}"]
}

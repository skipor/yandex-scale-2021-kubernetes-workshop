resource "yandex_vpc_address" "alb_ingress" {
  name = "alb-ingress"
  external_ipv4_address {
    zone_id = local.zone
  }
}

resource "yandex_iam_service_account" "alb_ingress_controller" {
  name        = "${data.yandex_resourcemanager_folder.workshop.name}-k8s-alb-ingress-controller"
  description = "Service account for ALB ingress controller running in Kubernetes cluster"
}

resource "yandex_resourcemanager_folder_iam_binding" "alb_ingress_controller_storage_editor" {
  folder_id = local.folder_id
  role      = "viewer"
  members   = ["serviceAccount:${yandex_iam_service_account.alb_ingress_controller.id}"]
}

resource "yandex_resourcemanager_folder_iam_binding" "alb_ingress_controller_encrypter_decrypter" {
  folder_id = local.folder_id
  role      = "alb.editor"
  members   = ["serviceAccount:${yandex_iam_service_account.alb_ingress_controller.id}"]
}

resource "yandex_resourcemanager_folder_iam_binding" "alb_ingress_controller_vpc_public_admin" {
  folder_id = local.folder_id
  role      = "vpc.publicAdmin"
  members   = ["serviceAccount:${yandex_iam_service_account.alb_ingress_controller.id}"]
}

resource "yandex_resourcemanager_folder_iam_binding" "alb_ingress_controller_ydb_admin" {
  folder_id = local.folder_id
  role      = "certificate-manager.certificates.downloader"
  members   = ["serviceAccount:${yandex_iam_service_account.alb_ingress_controller.id}"]
}

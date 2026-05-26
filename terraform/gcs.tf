resource "google_storage_bucket" "platform_cert_artifacts" {
  name                        = "platform-cert-artifacts-${data.google_project.current.number}"
  project                     = var.gcp_project_id
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

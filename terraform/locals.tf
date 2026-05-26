locals {
  workload_identity_pool_resource     = "projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.workload_identity_pool_id}"
  workload_identity_provider_resource = "${local.workload_identity_pool_resource}/providers/${var.workload_identity_provider_id}"
}

data "google_project" "current" {
  project_id = var.gcp_project_id
}

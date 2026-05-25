locals {
  service_account_email = "${var.service_account_id}@${var.gcp_project_id}.iam.gserviceaccount.com"

  # GitHub OIDC token subject format
  github_oidc_sub = "repo:${var.github_repo_owner}/${var.github_repo_name}:*"

  # For specific branch deployments (optional)
  # github_oidc_sub = "repo:${var.github_repo_owner}/${var.github_repo_name}:ref:refs/heads/main"

  workload_identity_pool_resource = "projects/${data.google_client_config.current.project_number}/locations/global/workloadIdentityPools/${var.workload_identity_pool_id}"

  workload_identity_provider_resource = "${local.workload_identity_pool_resource}/providers/${var.workload_identity_provider_id}"
}

data "google_client_config" "current" {}

output "workload_identity_provider" {
  value       = local.workload_identity_provider_resource
  description = "Workload Identity Provider resource name for GitHub Actions authentication"
}

output "service_account_email" {
  value       = google_service_account.github_actions.email
  description = "Service account email for GitHub Actions"
}

output "github_action_config" {
  value = {
    workload_identity_provider = local.workload_identity_provider_resource
    service_account_email      = google_service_account.github_actions.email
    github_repo_owner          = var.github_repo_owner
    github_repo_name           = var.github_repo_name
    gcp_project_id             = var.gcp_project_id
    gcp_region                 = var.gcp_region
  }
  description = "Configuration needed for GitHub Actions workflow"
  sensitive   = false
}

output "gcp_project_number" {
  value       = data.google_project.current.number
  description = "GCP Project Number"
}

output "workload_identity_pool_id" {
  value       = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  description = "Workload Identity Pool ID"
}

output "workload_identity_provider_id" {
  value       = google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id
  description = "Workload Identity Provider ID"
}

output "workload_identity_provider" {
  value       = local.workload_identity_provider_resource
  description = "Workload Identity Provider resource name (managed out-of-band by admin team)"
}

output "github_action_config" {
  value = {
    workload_identity_provider = local.workload_identity_provider_resource
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
  value       = var.workload_identity_pool_id
  description = "Workload Identity Pool ID (managed out-of-band by admin team)"
}

output "workload_identity_provider_id" {
  value       = var.workload_identity_provider_id
  description = "Workload Identity Provider ID (managed out-of-band by admin team)"
}

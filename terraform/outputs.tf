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

output "platform_cert_artifacts_bucket" {
  value       = google_storage_bucket.platform_cert_artifacts.name
  description = "GCS bucket name for cert artifacts (consumed by automi)"
}

output "pubsub_topic_cert_request" {
  value       = google_pubsub_topic.cert_request.name
  description = "Pub/Sub topic for inbound cert requests"
}

output "pubsub_topic_cert_dispatch" {
  value       = google_pubsub_topic.cert_dispatch.name
  description = "Pub/Sub topic for cert dispatch fan-out events"
}

output "pubsub_subscription_cert_request_event_trigger" {
  value       = google_pubsub_subscription.cert_request_event_trigger.name
  description = "Subscription consumed by EventTrigger"
}

output "pubsub_subscription_cert_dispatch_dispatch_agent" {
  value       = google_pubsub_subscription.cert_dispatch_dispatch_agent.name
  description = "Subscription consumed by DispatchAgent"
}

output "platform_secret_ids" {
  value       = [for s in google_secret_manager_secret.platform : s.secret_id]
  description = "Secret Manager secret IDs (containers only; versions must be added manually)"
}

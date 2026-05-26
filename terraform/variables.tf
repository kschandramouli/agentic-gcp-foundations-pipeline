variable "gcp_project_id" {
  type        = string
  description = "GCP Project ID where resources will be deployed"
}

variable "gcp_region" {
  type        = string
  default     = "australia-southeast1"
  description = "GCP region for shared platform resources (GCS, Pub/Sub message storage, GKE, Cloud SQL)"
}

variable "github_repo_owner" {
  type        = string
  description = "GitHub repository owner/organization"
}

variable "github_repo_name" {
  type        = string
  description = "GitHub repository name"
}

variable "workload_identity_pool_id" {
  type        = string
  default     = "github-action-landing"
  description = "Workload Identity Pool ID (created out-of-band by admin team; informational only)"
}

variable "workload_identity_provider_id" {
  type        = string
  default     = "github-oidc-provider"
  description = "Workload Identity Provider ID (created out-of-band by admin team; informational only)"
}

variable "enable_required_apis" {
  type = list(string)
  default = [
    # IAM / project plumbing
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "serviceusage.googleapis.com",
    # Workload-plane APIs consumed by downstream apps (automi etc.)
    "container.googleapis.com",
    "pubsub.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
  ]
  description = "List of GCP APIs to enable on the project"
}

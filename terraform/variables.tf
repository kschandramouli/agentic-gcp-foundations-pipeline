variable "gcp_project_id" {
  type        = string
  description = "GCP Project ID where resources will be deployed"
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
  description = "GCP region for resources"
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
  description = "Workload Identity Pool ID for GitHub Actions"
}

variable "workload_identity_provider_id" {
  type        = string
  default     = "github-oidc-provider"
  description = "Workload Identity Provider ID for GitHub OIDC"
}

variable "service_account_id" {
  type        = string
  default     = "github-action"
  description = "Service account ID for GitHub Actions"
}

variable "service_account_display_name" {
  type        = string
  default     = "GitHub Actions Service Account"
  description = "Display name for the service account"
}

variable "iam_roles" {
  type        = list(string)
  default     = []
  description = "IAM roles to grant directly to the service account (editor role is managed via admin_group_email)"
}

variable "admin_group_email" {
  type        = string
  description = "Google Group email that receives roles/editor on the project. The pipeline service account must be a member of this group."
}

variable "enable_required_apis" {
  type        = list(string)
  default     = [
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "serviceusage.googleapis.com"
  ]
  description = "List of APIs to enable for WIF"
}

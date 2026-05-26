# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset(var.enable_required_apis)

  service            = each.value
  disable_on_destroy = false
}

# Create Workload Identity Pool
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions OIDC"
  disabled                  = false

  depends_on = [google_project_service.required_apis]
}

# Create OIDC Provider for GitHub
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider_id
  display_name                       = "GitHub OIDC Provider"
  description                        = "OIDC provider for GitHub Actions"
  disabled                           = false
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  attribute_condition = "assertion.repository == '${var.github_repo_owner}/${var.github_repo_name}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Create Service Account for GitHub Actions
resource "google_service_account" "github_actions" {
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
  description  = "Service account for GitHub Actions deployments"

  depends_on = [google_project_service.required_apis]
}

# Grant editor role to the admin group (service account must be a member of this group)
resource "google_project_iam_member" "admin_group_editor" {
  project = var.gcp_project_id
  role    = "roles/editor"
  member  = "group:${var.admin_group_email}"
}

# Grant any additional IAM roles directly to the service account
resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset(var.iam_roles)

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"

  depends_on = [google_service_account.github_actions]
}

# Bind the Workload Identity Pool to the Service Account
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_resource}/attribute.repository/${var.github_repo_owner}/${var.github_repo_name}"

  depends_on = [google_iam_workload_identity_pool.github_pool]
}

# Additional: Grant Tokenize permissions if using WIF for token generation
resource "google_service_account_iam_member" "workload_identity_tokenize" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "principalSet://iam.googleapis.com/${local.workload_identity_pool_resource}/attribute.repository/${var.github_repo_owner}/${var.github_repo_name}"

  depends_on = [google_iam_workload_identity_pool.github_pool]
}

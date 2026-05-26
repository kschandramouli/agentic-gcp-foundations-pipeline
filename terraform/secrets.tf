locals {
  platform_secret_ids = toset([
    "platform-anthropic-api-key",
    "platform-langchain-api-key",
    "platform-db-password",
    "platform-vault-token",
    "platform-artifactory-token",
  ])
}

resource "google_secret_manager_secret" "platform" {
  for_each = local.platform_secret_ids

  project   = var.gcp_project_id
  secret_id = each.value

  replication {
    auto {}
  }
}

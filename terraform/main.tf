resource "google_project_service" "required_apis" {
  for_each = toset(var.enable_required_apis)

  service            = each.value
  disable_on_destroy = false
}

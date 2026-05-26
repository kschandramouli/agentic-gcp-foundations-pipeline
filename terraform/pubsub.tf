resource "google_pubsub_topic" "cert_request" {
  name    = "cert-request"
  project = var.gcp_project_id

  message_storage_policy {
    allowed_persistence_regions = [var.gcp_region]
  }
}

resource "google_pubsub_topic" "cert_dispatch" {
  name    = "cert-dispatch"
  project = var.gcp_project_id

  message_storage_policy {
    allowed_persistence_regions = [var.gcp_region]
  }
}

resource "google_pubsub_subscription" "cert_request_event_trigger" {
  name    = "cert-request-event-trigger"
  topic   = google_pubsub_topic.cert_request.id
  project = var.gcp_project_id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
}

resource "google_pubsub_subscription" "cert_dispatch_dispatch_agent" {
  name    = "cert-dispatch-dispatch-agent"
  topic   = google_pubsub_topic.cert_dispatch.id
  project = var.gcp_project_id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
}

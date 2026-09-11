# This was applied manually via `gcloud projects add-iam-policy-binding`
# during initial debugging (collectors were running and scraping, but had
# no permission to write to Cloud Monitoring — every write was silently
# failing). Codified here so a future cluster/project rebuild doesn't
# silently hit the same gap.

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_project_iam_member" "gke_node_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

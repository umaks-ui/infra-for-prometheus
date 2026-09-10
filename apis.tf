# Only the services this stack actually needs.
# Existing enabled APIs in the project (bigquery, firestore, pubsub, etc.)
# are left untouched — this list is additive, not exhaustive.

locals {
  required_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project = var.project_id
  service = each.value

  # Don't disable the API on `terraform destroy` — several of these
  # (monitoring, logging, iam) are almost certainly relied on by other
  # things in the project (e.g. db-poc-vpc's Private Service Access).
  disable_on_destroy = false
}

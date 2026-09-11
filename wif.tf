# Lets GitHub Actions authenticate to this project without a long-lived
# JSON key. Set var.github_repo to "owner/repo" (e.g. "umaks-ui/uma-yadav-infra")
# before applying.

variable "github_repo" {
  description = "GitHub repo allowed to assume the deploy service account, as owner/repo"
  type        = string
  # default = "umaks-ui/uma-yadav-infra"  # uncomment and set, or pass via -var
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions"
  description               = "Used by GitHub Actions to deploy to uma-yadav"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id         = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Restrict to just this repo, not any repo in the GitHub org.
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_deployer" {
  account_id   = "github-deployer"
  display_name = "GitHub Actions deployer (Terraform)"
}

# Only what this stack needs to create: networking, GKE, service enablement,
# and impersonation of itself.
resource "google_project_iam_member" "deployer_roles" {
  for_each = toset([
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountUser",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_deployer.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

output "wif_provider" {
  description = "Value for the WIF_PROVIDER GitHub secret"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "wif_service_account" {
  description = "Value for the WIF_SERVICE_ACCOUNT GitHub secret"
  value       = google_service_account.github_deployer.email
}

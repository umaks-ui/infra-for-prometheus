resource "google_container_cluster" "prod_gke" {
  name     = var.cluster_name
  location = var.region # regional cluster; Autopilot requires this

  enable_autopilot = true

  network    = google_compute_network.prod_gke.id
  subnetwork = google_compute_subnetwork.prod_gke.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "prod-gke-pods"
    services_secondary_range_name = "prod-gke-services"
  }

  # --- Managed Prometheus (GMP) ---
  # Enabled explicitly rather than relying on the Autopilot default so
  # it's version-controlled and shows up in `terraform plan` if ever
  # changed out-of-band.
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "STORAGE",
      "POD",
      "DEPLOYMENT",
      "STATEFULSET",
      "DAEMONSET",
      "HPA",
      "CADVISOR",
      "KUBELET",
    ]

    managed_prometheus {
      enabled = true
    }
  }

  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
    ]
  }

  release_channel {
    channel = "REGULAR"
  }

  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  # POC-friendly default. Flip to true once this is a real production
  # cluster you don't want an accidental `terraform destroy` to remove.
  deletion_protection = false

  depends_on = [
    google_project_service.required,
    google_compute_subnetwork.prod_gke,
  ]
}

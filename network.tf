# Dedicated VPC for prod-gke. Deliberately separate from db-poc-vpc —
# that network has 0.0.0.0/0 SSH/RDP firewall rules and a different
# apparent purpose, so it's left untouched.

resource "google_compute_network" "prod_gke" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "prod_gke" {
  name          = var.subnet_name
  region        = var.region
  network       = google_compute_network.prod_gke.id
  ip_cidr_range = var.subnet_cidr

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "prod-gke-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "prod-gke-services"
    ip_cidr_range = var.services_cidr
  }
}

# Minimal firewall: allow internal traffic within the subnet + secondary
# ranges only. No 0.0.0.0/0 SSH/RDP like db-poc-vpc — GKE Autopilot nodes
# are managed by Google and don't need inbound SSH from the internet.
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.prod_gke.id

  direction = "INGRESS"
  priority  = 65534

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.subnet_cidr,
    var.pods_cidr,
    var.services_cidr,
  ]
}

output "network_name" {
  value = google_compute_network.prod_gke.name
}

output "subnet_name" {
  value = google_compute_subnetwork.prod_gke.name
}

output "cluster_name" {
  value = google_container_cluster.prod_gke.name
}

output "cluster_endpoint" {
  value     = google_container_cluster.prod_gke.endpoint
  sensitive = true
}

output "get_credentials_command" {
  description = "Run this to configure kubectl against the new cluster"
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}

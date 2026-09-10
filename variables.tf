variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "uma-yadav"
}

variable "region" {
  description = "GCP region for the new VPC/subnet/cluster"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment label applied as a resource label"
  type        = string
  default     = "production"
}

variable "network_name" {
  description = "Name of the new VPC dedicated to this cluster"
  type        = string
  default     = "prod-gke-vpc"
}

variable "subnet_name" {
  description = "Name of the GKE subnet"
  type        = string
  default     = "prod-gke-subnet"
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE subnet (nodes)"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.40.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.50.0.0/20"
}

variable "cluster_name" {
  description = "Name of the GKE Autopilot cluster"
  type        = string
  default     = "prod-gke"
}

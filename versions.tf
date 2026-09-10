terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # Uncomment and configure once you have a GCS bucket for state.
  # Local state is fine to start, but move to a remote backend before
  # anyone else touches this repo.
  #
  # backend "gcs" {
  #   bucket = "uma-yadav-tfstate"
  #   prefix = "prod-gke"
  # }
}

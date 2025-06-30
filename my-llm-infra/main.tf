terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.35.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "5.35.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

resource "google_compute_network" "llm_vpc" {
  name                    = "llm-vpc"
  auto_create_subnetworks = false
  depends_on = [
    google_project_service.artifactregistry_api
  ]
}

resource "google_compute_subnetwork" "llm_subnet" {
  name          = "llm-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.gcp_region
  network       = google_compute_network.llm_vpc.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "llm-vpc-allow-ssh"
  network = google_compute_network.llm_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "llm-vpc-allow-http-https"
  network = google_compute_network.llm_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "llm-vpc-allow-internal"
  network = google_compute_network.llm_vpc.name
  allow {
    protocol = "all"
  }
  source_ranges = [google_compute_subnetwork.llm_subnet.ip_cidr_range]
}

# --------------------------------------------------------------------------------
# Cloud Run & Artifact Registry Resources
# --------------------------------------------------------------------------------

# Enable required APIs
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
}

resource "google_project_service" "artifactregistry_api" {
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "aiplatform_api" {
  service = "aiplatform.googleapis.com"
}

# Create a repository in Artifact Registry to store the container image
resource "google_artifact_registry_repository" "llm_app_repo" {
  location      = var.gcp_region
  repository_id = "llm-app-repo"
  description   = "Repository for the LLM application container"
  format        = "DOCKER"
  depends_on = [
    google_project_service.artifactregistry_api
  ]
}

# This null_resource uses a provisioner to build and push the Docker image
# after the Artifact Registry is created.
resource "null_resource" "docker_build_and_push" {
  depends_on = [google_artifact_registry_repository.llm_app_repo]

  triggers = {
    # This will re-run the provisioner if the python code changes.
    source_code_hash = filesha1("${path.module}/../llm-app/main.py")
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud auth configure-docker ${var.gcp_region}-docker.pkg.dev --quiet
      docker build -t ${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.llm_app_repo.repository_id}/llm-app:v1 ../llm-app
      docker push ${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.llm_app_repo.repository_id}/llm-app:v1
    EOT
  }
}

# Deploy the application to Cloud Run
resource "google_cloud_run_v2_service" "llm_service" {
  name     = "llm-inference-service"
  location = var.gcp_region
  project  = var.gcp_project_id

  template {
    labels = {
      # This label changes when the code changes, forcing a new revision.
      "source_code_hash" = null_resource.docker_build_and_push.triggers.source_code_hash
    }
    containers {
      image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.llm_app_repo.repository_id}/llm-app:v1"
      ports {
        container_port = 8080
      }
      env {
        name  = "GCP_PROJECT"
        value = var.gcp_project_id
      }
      env {
        name  = "GCP_REGION"
        value = var.gcp_region
      }
    }
  }

  depends_on = [
    null_resource.docker_build_and_push,
    google_project_service.run_api,
    google_project_service.aiplatform_api
  ]
}

# Allow unauthenticated access to the Cloud Run service
resource "google_cloud_run_v2_service_iam_binding" "allow_public" {
  project  = google_cloud_run_v2_service.llm_service.project
  location = google_cloud_run_v2_service.llm_service.location
  name     = google_cloud_run_v2_service.llm_service.name
  role     = "roles/run.invoker"
  members = [
    "allUsers",
  ]
}

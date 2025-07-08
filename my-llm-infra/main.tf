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

# Enable required APIs
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy = false  # Changed from true to false
}

resource "google_project_service" "artifactregistry_api" {
  service = "artifactregistry.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy = false  # Changed from true to false
}

resource "google_project_service" "aiplatform_api" {
  service = "aiplatform.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy = false  # Changed from true to false
}

# Enable Monitoring API
resource "google_project_service" "monitoring_api" {
  service = "monitoring.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy = false  # Changed from true to false
}

# Enable Logging API
resource "google_project_service" "logging_api" {
  service = "logging.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy = false  # Changed from true to false
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
  # Restrict SSH access to your IP address only
  # Replace with your actual IP address in CIDR notation
  source_ranges = [var.my_ip_cidr]
  description   = "Allow SSH only from specified IP for management purposes"
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "llm-vpc-allow-http-https"
  network = google_compute_network.llm_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  # These ports need to be accessible for Cloud Run service
  # But could be restricted to specific IP ranges if needed
  source_ranges = ["0.0.0.0/0"]
  description   = "Allow HTTP/HTTPS access for application traffic"
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

# --------------------------------------------------------------------------------
# Security Resources - IAM
# --------------------------------------------------------------------------------

# Create a custom IAM role with least privileges required for the LLM service
resource "google_project_iam_custom_role" "llm_service_role" {
  role_id     = "llmServiceMinimalRole"
  title       = "LLM Service Minimal Role"
  description = "Custom role with minimal permissions for LLM inference service"
  permissions = [
    "aiplatform.endpoints.predict",          # Required for Vertex AI model invocation
    "logging.logEntries.create",             # Required for writing logs
    "monitoring.timeSeries.create",          # Required for creating monitoring metrics
  ]
}

# Create a service account for the LLM service
resource "google_service_account" "llm_service_account" {
  account_id   = "llm-service-account"
  display_name = "LLM Service Account"
  description  = "Service account with minimal permissions for the LLM service"
}

# Assign the custom role to the service account
resource "google_project_iam_binding" "llm_service_role_binding" {
  project = var.gcp_project_id
  role    = google_project_iam_custom_role.llm_service_role.id
  members = [
    "serviceAccount:${google_service_account.llm_service_account.email}",
  ]
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
    service_account = google_service_account.llm_service_account.email
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
  
  # This ensures the service and its dependencies are destroyed in the right order
  lifecycle {
    create_before_destroy = true
  }
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
  
  # This prevents dependency issues during destroy
  lifecycle {
    create_before_destroy = true
    # This prevents errors when the service is deleted before the binding
    prevent_destroy = false
  }
}

# --------------------------------------------------------------------------------
# Monitoring Resources
# --------------------------------------------------------------------------------

# Log-based metric for counting inference requests
resource "google_logging_metric" "inference_requests" {
  name        = "inference-requests"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"llm-inference-service\" AND textPayload=~\"Received log for analysis:.*\""
  description = "Counts the number of inference requests received"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    display_name = "LLM Inference Requests"
  }
  depends_on = [google_project_service.logging_api]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Log-based metric for counting model errors
resource "google_logging_metric" "model_errors" {
  name        = "model-errors"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"llm-inference-service\" AND (textPayload:\"Error during model generation\" OR jsonPayload.message:\"Error\" OR severity=ERROR)"
  description = "Counts the number of model generation errors and request validation errors"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    display_name = "LLM Model Errors"
  }
  depends_on = [google_project_service.logging_api]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Log-based metric for counting HTTP errors
resource "google_logging_metric" "http_errors" {
  name        = "http-errors"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"llm-inference-service\" AND httpRequest.status >= 400"
  description = "Counts the number of HTTP errors (4xx and 5xx responses)"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    display_name = "LLM HTTP Errors"
  }
  depends_on = [google_project_service.logging_api]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Custom monitoring dashboard
resource "google_monitoring_dashboard" "llm_dashboard" {
  dashboard_json = <<EOF
{
  "displayName": "LLM Application Dashboard",
  "gridLayout": {
    "widgets": [
      {
        "title": "CPU Utilization",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"llm-inference-service\" AND metric.type=\"run.googleapis.com/container/cpu/utilizations\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_PERCENTILE_95"
                  }
                }
              },
              "plotType": "LINE"
            }
          ],
          "yAxis": {
            "scale": "LINEAR",
            "label": "CPU Utilization"
          }
        }
      },
      {
        "title": "Memory Utilization",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"llm-inference-service\" AND metric.type=\"run.googleapis.com/container/memory/utilizations\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_PERCENTILE_95"
                  }
                }
              },
              "plotType": "LINE"
            }
          ],
          "yAxis": {
            "scale": "LINEAR",
            "label": "Memory Utilization"
          }
        }
      },
      {
        "title": "Network Egress",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"llm-inference-service\" AND metric.type=\"run.googleapis.com/container/network/sent_bytes_count\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              },
              "plotType": "LINE"
            }
          ],
          "yAxis": {
            "scale": "LINEAR",
            "label": "Bytes per second"
          }
        }
      },
      {
        "title": "Inference Requests",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"logging.googleapis.com/user/inference-requests\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              },
              "plotType": "LINE"
            }
          ],
          "yAxis": {
            "scale": "LINEAR",
            "label": "Requests per second"
          }
        }
      },
      {
        "title": "Model Errors",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"logging.googleapis.com/user/model-errors\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              },
              "plotType": "LINE"
            }
          ],
          "yAxis": {
            "scale": "LINEAR",
            "label": "Errors per second"
          }
        }
      },
      {
        "title": "HTTP Errors",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"logging.googleapis.com/user/http-errors\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              },
              "plotType": "LINE"
            }
          ],
          "yAxis": {
            "scale": "LINEAR",
            "label": "Errors per second"
          }
        }
      },
      {
        "title": "Request Latency",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"llm-inference-service\" AND metric.type=\"run.googleapis.com/request_latencies\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_PERCENTILE_99"
                  }
                }
              },
              "plotType": "LINE"
            }
          ],
          "yAxis": {
            "scale": "LINEAR",
            "label": "Latency (ms)"
          }
        }
      }
    ]
  }
}
EOF
  depends_on = [
    google_cloud_run_v2_service.llm_service,
    google_logging_metric.inference_requests,
    google_logging_metric.model_errors,
    google_project_service.monitoring_api
  ]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Alert policy for high CPU usage
resource "google_monitoring_alert_policy" "high_cpu_alert" {
  display_name = "High CPU Usage Alert"
  combiner     = "OR"
  conditions {
    display_name = "CPU Utilization > 80%"
    condition_threshold {
      filter     = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"llm-inference-service\" AND metric.type=\"run.googleapis.com/container/cpu/utilizations\""
      duration   = "300s"
      comparison = "COMPARISON_GT"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_95"
      }
    }
  }

  notification_channels = []
  depends_on = [google_project_service.monitoring_api]
  
  lifecycle {
    create_before_destroy = true
  }
}

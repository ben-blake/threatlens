output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.llm_vpc.name
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.llm_subnet.name
}

output "cloud_run_service_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.llm_service.uri
}

output "dashboard_url" {
  description = "The URL to access the log analysis dashboard"
  value       = google_cloud_run_v2_service.llm_service.uri
}

output "custom_service_account" {
  description = "Email address of the custom service account"
  value       = google_service_account.llm_service_account.email
}

output "custom_iam_role" {
  description = "ID of the custom IAM role"
  value       = google_project_iam_custom_role.llm_service_role.id
}

output "logging_metric_inference_requests" {
  description = "Name of the inference requests logging metric"
  value       = google_logging_metric.inference_requests.name
}

output "logging_metric_model_errors" {
  description = "Name of the model errors logging metric"
  value       = google_logging_metric.model_errors.name
}

output "alert_policy_name" {
  description = "Name of the CPU utilization alert policy"
  value       = google_monitoring_alert_policy.high_cpu_alert.name
}

output "monitoring_dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = google_monitoring_dashboard.llm_dashboard.id
}

output "monitoring_dashboard_url" {
  description = "URL to access the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards"
}

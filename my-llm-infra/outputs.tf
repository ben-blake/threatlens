output "vpc_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.llm_vpc.name
}

output "subnet_name" {
  description = "The name of the subnet."
  value       = google_compute_subnetwork.llm_subnet.name
}

output "cloud_run_service_url" {
  description = "The URL of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.llm_service.uri
}

output "monitoring_dashboard_id" {
  description = "The ID of the monitoring dashboard"
  value       = google_monitoring_dashboard.llm_dashboard.id
}

output "monitoring_dashboard_url" {
  description = "The URL to access the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards"
}

output "custom_service_account" {
  description = "The email of the custom service account with least privilege"
  value       = google_service_account.llm_service_account.email
}

output "custom_iam_role" {
  description = "The ID of the custom IAM role"
  value       = google_project_iam_custom_role.llm_service_role.id
}

output "alert_policy_name" {
  description = "The name of the CPU alert policy"
  value       = google_monitoring_alert_policy.high_cpu_alert.name
}

output "logging_metric_inference_requests" {
  description = "The name of the log-based metric for inference requests"
  value       = google_logging_metric.inference_requests.name
}

output "logging_metric_model_errors" {
  description = "The name of the log-based metric for model errors"
  value       = google_logging_metric.model_errors.name
}

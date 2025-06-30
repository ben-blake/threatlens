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

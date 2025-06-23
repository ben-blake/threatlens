output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.llm_vpc.name
}

output "vpc_self_link" {
  description = "The self_link of the VPC network"
  value       = google_compute_network.llm_vpc.self_link
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.llm_subnet.name
}

output "subnet_self_link" {
  description = "The self_link of the subnet"
  value       = google_compute_subnetwork.llm_subnet.self_link
}

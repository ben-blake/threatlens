variable "gcp_project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "The GCP region to deploy resources in"
  type        = string
  default     = "us-central1"
}

variable "my_ip_cidr" {
  description = "Your IP address in CIDR notation (e.g., 123.45.67.89/32) for secure SSH access"
  type        = string
}

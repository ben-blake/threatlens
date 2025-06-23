terraform {
     required_providers {
       google = {
         source  = "hashicorp/google"
         version = ">= 5.0"
       }
     }
   }

   provider "google" {
     project = var.project_id
     region  = var.region
   }

   resource "google_compute_network" "llm_vpc" {
     name                    = "llm-vpc"
     auto_create_subnetworks = false
   }

   resource "google_compute_subnetwork" "llm_subnet" {
     name          = "llm-subnet"
     ip_cidr_range = "10.10.0.0/24"
     region        = var.region
     network       = google_compute_network.llm_vpc.id
   }

   resource "google_compute_firewall" "allow_ssh" {
     name    = "allow-ssh"
     network = google_compute_network.llm_vpc.name

     allow {
       protocol = "tcp"
       ports    = ["22"]
     }

     source_ranges = ["0.0.0.0/0"] # For dev only; restrict to your IP for production
   }

   resource "google_compute_firewall" "allow_http_https" {
     name    = "allow-http-https"
     network = google_compute_network.llm_vpc.name

     allow {
       protocol = "tcp"
       ports    = ["80", "443"]
     }

     source_ranges = ["0.0.0.0/0"]
   }

   resource "google_compute_firewall" "allow_internal" {
     name    = "allow-internal"
     network = google_compute_network.llm_vpc.name

     allow {
       protocol = "all"
     }

     source_ranges = ["10.10.0.0/16"]
   }
   
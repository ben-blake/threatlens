# LLM-Based Log Analysis Dashboard

A cloud-native application for analyzing system logs using Google's Gemini 2.0 Flash-Lite LLM. This project deploys a web dashboard and API for threat intelligence analysis to Google Cloud Run.

## Project Structure

```
ben-blake-llm-project-2025/
├── llm-app/              # Application code
│   ├── main.py           # Flask application
│   ├── requirements.txt  # Python dependencies
│   ├── Dockerfile        # Container definition
│   ├── static/           # Static assets (CSS, JS)
│   └── templates/        # HTML templates
├── my-llm-infra/         # Infrastructure code
│   ├── main.tf           # Terraform configuration
│   ├── variables.tf      # Input variables
│   └── outputs.tf        # Output variables
├── init.sh               # Initialization script
├── teardown.sh           # Teardown script
└── README.md             # This file
```

## Architecture

The application uses a cloud-native architecture with the following components:

- **Web UI**: Flask-based interface for submitting logs and viewing analysis
- **Cloud Run**: Hosts the containerized Flask application with auto-scaling
- **Vertex AI**: Provides Gemini 2.0 Flash-Lite model for security log analysis
- **VPC Network**: Isolated network environment for future integrations, e.g. VMs, databases, etc.
- **Artifact Registry**: Stores container images
- **Monitoring & Logging**: Custom metrics, dashboard, and alerts

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- A Google Cloud Platform account with billing enabled
- GCP Project ID: `ben-blake-llm-project-2025`

## Initial Setup

1. **Clone the repository**:

   ```bash
   git clone <repository-url>
   cd ben-blake-llm-project-2025
   ```

2. **Make scripts executable**:

   ```bash
   chmod +x init.sh teardown.sh
   ```

3. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

## Deployment

To deploy the application:

```bash
./init.sh
```

The script will:

1. Verify prerequisites
2. Configure Docker with gcloud credentials
3. Initialize Terraform
4. Deploy infrastructure to GCP (including building and pushing Docker images)
5. Output the dashboard URL

Terraform automatically handles all required infrastructure, including:

- Building and pushing Docker images
- Creating networking and security resources
- Configuring IAM permissions for the service account
- Deploying the Cloud Run service
- Setting up monitoring and logging

## Teardown

To tear down all resources:

```bash
./teardown.sh
```

This will:

1. Remove additional IAM bindings added during initialization
2. Destroy all Terraform-managed resources
3. Offer to force-remove any stuck resources (if the normal destroy fails)
4. Clean up local Terraform state files
5. Optionally remove Docker images

## Manual Deployment

If you prefer to deploy manually:

### Building Infrastructure with Terraform

```bash
cd my-llm-infra
terraform init
terraform apply \
  -var="gcp_project_id=ben-blake-llm-project-2025" \
  -var="gcp_region=us-central1" \
  -var="my_ip_cidr=YOUR_IP/32"
```

Terraform will handle:

- Building and pushing the Docker image
- Creating all necessary infrastructure
- Deploying the application to Cloud Run

## Usage

1. Access the dashboard at the URL provided after deployment
2. Enter a security log entry in the text area (or select from examples)
3. Click "Analyze" to process the log
4. View the analysis results with:
   - Threat Classification
   - Risk Score (1-10)
   - Summary explanation

## API Usage

You can also use the API programmatically:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"log_entry":"sshd[1234]: Failed password for invalid user admin from 123.45.67.89 port 22 ssh2"}' \
  https://YOUR_SERVICE_URL/api
```

## Cost Information

This project is designed to run within GCP's free tier with minimal costs:

- **Cloud Run**: Free tier includes 2 million requests, 360,000 GB-seconds of memory, and 180,000 vCPU-seconds
- **Vertex AI**: Free tier includes ~300,000 characters per month for Gemini 2.0 Flash-Lite
- **Cloud Logging**: Free tier includes 50 GiB of logs per month
- **Artifact Registry**: Free tier includes 0.5 GB storage

Actual costs for this project were approximately $0.12 total ($0.11 for Cloud Run, $0.01 for Vertex AI).

## Troubleshooting

- **Deployment issues**: Check Cloud Build logs and Cloud Run logs in GCP Console
- **Application errors**: Check Cloud Run logs with:
  ```bash
  gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=llm-inference-service"
  ```

## License

This project is for educational purposes as part of COMP-SCI 5525 - Cloud Computing at UMKC.

#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  LLM Dashboard Initialization Script   ${NC}"
echo -e "${BLUE}========================================${NC}"

# Check required tools
echo -e "${YELLOW}Checking required tools...${NC}"
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed. Please install Terraform and try again.${NC}"; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo -e "${RED}Google Cloud SDK is required but not installed. Please install gcloud and try again.${NC}"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed. Please install Docker and try again.${NC}"; exit 1; }

# Verify gcloud authentication
echo -e "${YELLOW}Verifying gcloud authentication...${NC}"
ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
if [ -z "$ACCOUNT" ]; then
  echo -e "${RED}Not logged in to gcloud. Please run 'gcloud auth login' first.${NC}"
  exit 1
else
  echo -e "${GREEN}Authenticated as: $ACCOUNT${NC}"
fi

# Verify project ID
PROJECT_ID="ben-blake-llm-project-2025"
echo -e "${YELLOW}Setting project to: $PROJECT_ID${NC}"
gcloud config set project $PROJECT_ID

# Check if the project exists
gcloud projects describe $PROJECT_ID >/dev/null 2>&1 || { 
  echo -e "${RED}Project $PROJECT_ID does not exist or you don't have access.${NC}"
  exit 1
}

# Configure Docker to use gcloud credentials
echo -e "${YELLOW}Configuring Docker to use gcloud credentials...${NC}"
gcloud auth configure-docker --quiet
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

# Get current IP for firewall configuration
echo -e "${YELLOW}Detecting your current public IP address...${NC}"
MY_IP=$(curl -s https://api.ipify.org)
if [ -z "$MY_IP" ]; then
  echo -e "${RED}Could not detect your IP address. Using 0.0.0.0/0 instead (not recommended for production).${NC}"
  MY_IP_CIDR="0.0.0.0/0"
else
  MY_IP_CIDR="$MY_IP/32"
  echo -e "${GREEN}Detected IP: $MY_IP_CIDR${NC}"
fi

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
cd my-llm-infra || { echo -e "${RED}Failed to find my-llm-infra directory${NC}"; exit 1; }
terraform init

# Apply Terraform configuration
echo -e "${YELLOW}Applying Terraform configuration...${NC}"
echo -e "${YELLOW}This may take several minutes...${NC}"
echo -e "${YELLOW}Terraform will handle building and pushing the Docker image...${NC}"
terraform apply -auto-approve \
  -var="gcp_project_id=$PROJECT_ID" \
  -var="gcp_region=us-central1" \
  -var="my_ip_cidr=$MY_IP_CIDR"

# Check if apply was successful
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Terraform apply completed successfully!${NC}"
  
  # Get the dashboard URL
  DASHBOARD_URL=$(terraform output -raw dashboard_url)
  
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}Deployment complete!${NC}"
  echo -e "${GREEN}Dashboard URL: $DASHBOARD_URL${NC}"
  echo -e "${GREEN}========================================${NC}"
  
  echo -e "${YELLOW}Note: It may take a few minutes for the service to fully initialize and for IAM permissions to propagate.${NC}"
else
  echo -e "${RED}Terraform apply failed. Please check the error messages above.${NC}"
  exit 1
fi 
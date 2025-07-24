#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting teardown process...${NC}"

# Set project ID
PROJECT_ID="ben-blake-llm-project-2025"

# Destroy infrastructure with Terraform
echo -e "${YELLOW}Destroying Terraform infrastructure...${NC}"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform command not found. Please install Terraform to proceed.${NC}"
    exit 1
fi

# Go to the infrastructure directory
cd my-llm-infra || { echo -e "${RED}Failed to find my-llm-infra directory${NC}"; exit 1; }

# Run terraform destroy
echo -e "${YELLOW}Running terraform destroy...${NC}"
terraform destroy -auto-approve \
  -var="gcp_project_id=$PROJECT_ID" \
  -var="gcp_region=us-central1" \
  -var="my_ip_cidr=0.0.0.0/0"

# Check if destroy was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Terraform resources destroyed successfully!${NC}"
else
    echo -e "${RED}Terraform destroy failed. Some resources may still exist in your GCP project.${NC}"
    echo -e "${YELLOW}Consider checking the GCP Console to manually remove any remaining resources.${NC}"
    
    # Ask if user wants to try forcing removal of Cloud Run and custom roles
    echo -e "${YELLOW}Would you like to try removing problematic resources with gcloud? (y/n)${NC}"
    read -r force_remove
    
    if [[ $force_remove =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Attempting to force-remove Cloud Run service...${NC}"
        gcloud run services delete llm-inference-service --region=us-central1 --quiet 2>/dev/null || true
        
        echo -e "${YELLOW}Attempting to delete custom IAM role...${NC}"
        gcloud iam roles delete llmServiceMinRole2025 --project=$PROJECT_ID --quiet 2>/dev/null || true
    fi
fi

# Return to project root
cd ..

# Clean up Terraform files
echo -e "${YELLOW}Cleaning up Terraform state files...${NC}"
find my-llm-infra -name "*.tfstate*" -type f -delete
find my-llm-infra -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
find my-llm-infra -name ".terraform.lock.hcl" -type f -delete

echo -e "${GREEN}Teardown complete! Your project is now ready for reinitialization.${NC}" 
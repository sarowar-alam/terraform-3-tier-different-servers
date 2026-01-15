#!/bin/bash
################################################################################
# Terraform Deployment Script
# 
# This script helps automate the Terraform deployment process with validation
# and error checking at each step.
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    print_success "Terraform $(terraform version | head -n1 | awk '{print $2}') found"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    print_success "AWS CLI found"
    
    # Check configuration files
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found"
        print_info "Copy terraform.tfvars.example and update with your values"
        exit 1
    fi
    print_success "terraform.tfvars found"
    
    if [ ! -f "backend-config.tfbackend" ]; then
        print_warning "backend-config.tfbackend not found"
        print_info "Copy backend-config.tfbackend.example and update with your values"
        exit 1
    fi
    print_success "backend-config.tfbackend found"
}

terraform_init() {
    print_info "Initializing Terraform..."
    terraform init -backend-config=backend-config.tfbackend
    print_success "Terraform initialized"
}

terraform_validate() {
    print_info "Validating Terraform configuration..."
    terraform validate
    print_success "Configuration is valid"
}

terraform_format() {
    print_info "Formatting Terraform files..."
    terraform fmt -recursive
    print_success "Files formatted"
}

terraform_plan() {
    print_info "Creating Terraform plan..."
    terraform plan -out=tfplan
    print_success "Plan created: tfplan"
    
    print_info "Review the plan above. Continue with apply? (yes/no)"
    read -r response
    if [[ ! "$response" =~ ^[Yy][Ee][Ss]$|^[Yy]$ ]]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
}

terraform_apply() {
    print_info "Applying Terraform configuration..."
    terraform apply tfplan
    print_success "Infrastructure deployed!"
}

show_outputs() {
    print_info "Deployment Outputs:"
    echo ""
    terraform output
    echo ""
}

post_deployment_info() {
    echo ""
    print_success "=================================="
    print_success "Deployment Completed!"
    print_success "=================================="
    echo ""
    print_info "Next Steps:"
    echo "  1. Wait 5-10 minutes for user data scripts to complete"
    echo "  2. Check health status: terraform output deployment_info"
    echo "  3. Access your application: terraform output application_url"
    echo ""
    print_info "Useful Commands:"
    echo "  - View all outputs: terraform output"
    echo "  - Check instance logs: aws ec2 get-console-output --instance-id <id>"
    echo "  - Destroy infrastructure: terraform destroy"
    echo ""
}

# Main execution
main() {
    echo ""
    print_info "=================================="
    print_info "BMI Health Tracker - Terraform Deployment"
    print_info "=================================="
    echo ""
    
    check_prerequisites
    echo ""
    
    terraform_init
    echo ""
    
    terraform_validate
    echo ""
    
    terraform_format
    echo ""
    
    terraform_plan
    echo ""
    
    terraform_apply
    echo ""
    
    show_outputs
    
    post_deployment_info
}

# Run main function
main

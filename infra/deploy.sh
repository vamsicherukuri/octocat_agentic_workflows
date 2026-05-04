#!/bin/bash

# OctoCAT Supply - Azure App Service Deployment Script
# This script automates the deployment process

set -e

# Parse flags
SKIP_INFRASTRUCTURE=false
SKIP_APP_DEPLOY=false
FORCE=false
DESTROY=false

for arg in "$@"; do
    case $arg in
        --skip-infrastructure) SKIP_INFRASTRUCTURE=true ;;
        --skip-app-deploy)     SKIP_APP_DEPLOY=true ;;
        --force)               FORCE=true ;;
        --destroy)             DESTROY=true ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install from: https://www.terraform.io/downloads"
        exit 1
    fi
    
    log_info "All prerequisites are installed ✓"
}

check_azure_login() {
    log_info "Checking Azure login status..."
    
    if ! az account show &> /dev/null; then
        log_warn "Not logged in to Azure. Please login..."
        az login
    fi
    
    SUBSCRIPTION=$(az account show --query name -o tsv)
    log_info "Using Azure subscription: $SUBSCRIPTION ✓"
}

setup_terraform() {
    log_info "Setting up Terraform configuration..."
    
    cd "$(dirname "$0")/terraform"
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        log_warn "terraform.tfvars not found. Creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        log_warn "Please edit terraform.tfvars with your custom values before proceeding."
        if [ "$FORCE" != "true" ]; then
            read -p "Press Enter after editing terraform.tfvars to continue..."
        fi
    fi
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    cd -
}

deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd "$(dirname "$0")/terraform"
    
    # Plan
    log_info "Creating Terraform plan..."
    terraform plan -out=tfplan
    
    # Apply
    if [ "$FORCE" != "true" ]; then
        read -p "Do you want to apply this plan? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            log_warn "Deployment cancelled by user."
            rm -f tfplan
            exit 0
        fi
    fi

    terraform apply tfplan
    rm -f tfplan
    log_info "Infrastructure deployed successfully ✓"
    
    cd -
}

deploy_application_code() {
    log_info "Packaging and deploying application source code..."

    cd "$(dirname "$0")/terraform"
    RESOURCE_GROUP=$(terraform output -raw resource_group_name)
    API_APP_NAME=$(terraform output -raw api_app_name)
    FRONTEND_APP_NAME=$(terraform output -raw frontend_app_name)
    API_URL=$(terraform output -raw api_url)
    cd -

    API_ARCHIVE="/tmp/octocat-api.zip"
    FRONTEND_ARCHIVE="/tmp/octocat-frontend.zip"

    log_info "Creating API archive..."
    cd "$(dirname "$0")/../api"
    zip -r "$API_ARCHIVE" . --exclude "node_modules/*" --exclude "dist/*" --exclude ".git/*"
    cd -

    log_info "Creating frontend archive..."
    cd "$(dirname "$0")/../frontend"
    zip -r "$FRONTEND_ARCHIVE" . --exclude "node_modules/*" --exclude "dist/*" --exclude ".git/*"
    cd -

    log_info "Deploying API... (this takes ~3-5 min while Oryx builds)"
    az webapp deploy --resource-group "$RESOURCE_GROUP" --name "$API_APP_NAME" \
      --src-path "$API_ARCHIVE" --type zip
    log_info "API deployed ✓"

    log_info "Deploying frontend... (this takes ~2-3 min while Oryx builds)"
    az webapp deploy --resource-group "$RESOURCE_GROUP" --name "$FRONTEND_APP_NAME" \
      --src-path "$FRONTEND_ARCHIVE" --type zip
    log_info "Frontend deployed ✓"

    rm -f "$API_ARCHIVE" "$FRONTEND_ARCHIVE"

    # Poll API health until it responds (Oryx restarts the app after build)
    log_info "Waiting for API to become healthy..."
    HEALTH_URL="${API_URL}/api/health"
    MAX_ATTEMPTS=24  # 2 minutes
    ATTEMPT=0
    HEALTHY=false

    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$HEALTH_URL" 2>/dev/null || true)
        if [ "$HTTP_STATUS" = "200" ]; then
            log_info "API is healthy ✓"
            HEALTHY=true
            break
        fi
        ATTEMPT=$((ATTEMPT + 1))
        echo "  Waiting for API... ($ATTEMPT/$MAX_ATTEMPTS)"
        sleep 5
    done

    if [ "$HEALTHY" != "true" ]; then
        log_warn "API health check timed out — it may still be starting. Check: $HEALTH_URL"
    fi

    log_info "Application code deployed successfully ✓"
}

destroy_infrastructure() {
    echo ""
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}  WARNING: This will DELETE all Azure resources${NC}"
    echo -e "${RED}================================================${NC}"
    echo ""

    if [ "$FORCE" != "true" ]; then
        read -p "Type 'destroy' to confirm deletion of all resources: " CONFIRM
        if [ "$CONFIRM" != "destroy" ]; then
            log_warn "Destroy cancelled."
            exit 0
        fi
    fi

    cd "$(dirname "$0")/terraform"
    log_info "Running terraform destroy..."
    terraform destroy -auto-approve
    log_info "All Azure resources destroyed ✓"
    cd -
}

show_deployment_info() {
    log_info "Deployment completed successfully! 🎉"
    echo ""
    
    cd "$(dirname "$0")/terraform"
    
    FRONTEND_URL=$(terraform output -raw frontend_url)
    API_URL=$(terraform output -raw api_url)
    API_APP_NAME=$(terraform output -raw api_app_name)
    RESOURCE_GROUP=$(terraform output -raw resource_group_name)
    
    echo "================================================"
    echo "  OctoCAT Supply - Deployment Information"
    echo "================================================"
    echo ""
    echo "Frontend URL: $FRONTEND_URL"
    echo "API URL: $API_URL"
    echo "API Swagger: ${API_URL}/api-docs"
    echo ""
    echo "To view logs:"
    echo "  az webapp log tail --name $API_APP_NAME --resource-group $RESOURCE_GROUP"
    echo ""
    echo "================================================"
    
    cd -
}

# Main deployment flow
main() {
    echo "================================================"
    echo "  OctoCAT Supply - Azure Deployment Script"
    echo "================================================"
    echo ""
    
    check_prerequisites
    check_azure_login
    setup_terraform

    if [ "$DESTROY" = "true" ]; then
        destroy_infrastructure
        return
    fi
    
    # Deployment steps
    echo ""
    echo "Deployment will perform the following steps:"
    if [ "$SKIP_INFRASTRUCTURE" = "true" ]; then
        echo "1. [skipped] Deploy Azure infrastructure"
    else
        echo "1. Deploy Azure infrastructure"
    fi
    if [ "$SKIP_APP_DEPLOY" = "true" ]; then
        echo "2. [skipped] Deploy API + frontend code"
    else
        echo "2. Deploy API + frontend code"
    fi
    echo ""
    
    if [ "$FORCE" != "true" ]; then
        read -p "Do you want to proceed? (yes/no): " PROCEED
        if [ "$PROCEED" != "yes" ]; then
            log_warn "Deployment cancelled by user."
            exit 0
        fi
    fi

    if [ "$SKIP_INFRASTRUCTURE" != "true" ]; then
        deploy_infrastructure
    fi

    if [ "$SKIP_APP_DEPLOY" != "true" ]; then
        deploy_application_code
    fi

    show_deployment_info
}

# Run main function
main

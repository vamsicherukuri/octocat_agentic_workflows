# Terraform Infrastructure Files - Index

This directory contains all Terraform configuration and deployment resources for deploying OctoCAT Supply to Azure App Services.

## 📁 File Structure

```
infra/
├── terraform/
│   ├── main.tf                          # Main Terraform configuration
│   ├── variables.tf                     # Input variables definition
│   ├── outputs.tf                       # Output values after deployment
│   ├── terraform.tfvars.example         # Example variables file (copy to terraform.tfvars)
│   ├── .gitignore                       # Git ignore for Terraform files
│   ├── README.md                        # Complete deployment guide
│   ├── QUICKSTART.md                    # Quick reference guide
│   ├── CICD.md                          # GitHub Actions CI/CD setup guide
│   ├── .github-workflows-example.yml    # Example GitHub Actions workflow
│   └── INDEX.md                         # This file
├── deploy.sh                            # Bash deployment script (Linux/Mac)
├── deploy.ps1                           # PowerShell deployment script (Windows)
└── container-apps.bicep                 # Original Bicep template (Container Apps)
```

## 📄 File Descriptions

### Core Terraform Files

#### `main.tf`
**Purpose**: Main infrastructure definition
**Contains**:
- Azure Resource Group
- Azure Container Registry (ACR)
- App Service Plan (Linux)
- API App Service (Node.js/Express)
- Frontend App Service (React/NGINX)
- CORS configuration
- Health checks
- Logging configuration

**Resources Created**:
- `azurerm_resource_group.main`
- `azurerm_container_registry.acr`
- `azurerm_service_plan.main`
- `azurerm_linux_web_app.api`
- `azurerm_linux_web_app.frontend`

#### `variables.tf`
**Purpose**: Define all configurable parameters
**Key Variables**:
- `resource_group_name` - Resource group name
- `location` - Azure region
- `environment` - Environment name (dev/staging/prod)
- `app_name` - Base application name
- `acr_name` - Container registry name (must be globally unique)
- `acr_sku` - ACR tier (Basic/Standard/Premium)
- `app_service_plan_sku` - App Service tier (B1/S1/P1v2/etc)
- `always_on` - Keep app always running
- `api_docker_image` - API Docker image name
- `frontend_docker_image` - Frontend Docker image name
- `*_docker_tag` - Image tags

#### `outputs.tf`
**Purpose**: Export useful information after deployment
**Outputs**:
- Resource group name
- ACR login server and credentials (sensitive)
- API and Frontend URLs
- App Service names
- Deployment instructions

### Configuration Files

#### `terraform.tfvars.example`
**Purpose**: Template for user configuration
**Usage**: 
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```
**Important**: `terraform.tfvars` is gitignored - never commit it!

#### `.gitignore`
**Purpose**: Prevent sensitive Terraform files from being committed
**Ignores**:
- `.terraform/` directory
- `*.tfstate` files
- `terraform.tfvars`
- Crash logs and backup files

### Documentation Files

#### `README.md`
**Purpose**: Complete deployment guide
**Sections**:
- Architecture overview
- Prerequisites
- Quick start guide
- Detailed deployment steps
- Configuration options
- Monitoring and logging
- Troubleshooting
- Cost optimization
- Security best practices

#### `QUICKSTART.md`
**Purpose**: Quick reference for common tasks
**Contents**:
- Prerequisites checklist
- Quick deploy commands
- Common tasks (logs, updates, destroy)
- Troubleshooting quick fixes
- Cost estimates

#### `CICD.md`
**Purpose**: GitHub Actions CI/CD setup
**Contents**:
- Service principal creation
- GitHub secrets configuration
- Workflow setup
- Environment-specific deployments
- Rollback procedures
- Monitoring deployments
- Best practices

### Deployment Scripts

#### `deploy.sh` (Bash)
**Purpose**: Automated deployment for Linux/Mac
**Features**:
- Prerequisites checking
- Azure login verification
- Terraform initialization and deployment
- Docker image building and pushing
- App Service restart
- Deployment summary

**Usage**:
```bash
cd infra
chmod +x deploy.sh
./deploy.sh
```

#### `deploy.ps1` (PowerShell)
**Purpose**: Automated deployment for Windows
**Features**: Same as deploy.sh but for Windows
**Additional Options**:
- `-SkipInfrastructure` - Update images only
- `-SkipImages` - Update infrastructure only
- `-Force` - Skip confirmation prompts

**Usage**:
```powershell
cd infra
.\deploy.ps1
```

### CI/CD Files

#### `.github-workflows-example.yml`
**Purpose**: GitHub Actions workflow template
**Features**:
- Automated builds on push to main/develop
- Manual workflow dispatch
- Docker image building and tagging
- Azure deployment
- Deployment summary

**Usage**:
```bash
mkdir -p .github/workflows
cp infra/terraform/.github-workflows-example.yml .github/workflows/azure-deploy.yml
```

## 🚀 Quick Start Paths

### Path 1: Automated Deployment (Easiest)
1. Configure `terraform.tfvars`
2. Run deployment script:
   - Windows: `.\deploy.ps1`
   - Linux/Mac: `./deploy.sh`

### Path 2: Manual Deployment (More Control)
1. Follow steps in `README.md`
2. Run Terraform commands manually
3. Build and push Docker images
4. Restart App Services

### Path 3: CI/CD Setup (Production)
1. Follow `CICD.md` guide
2. Set up GitHub secrets
3. Copy workflow file
4. Commit and push

## 📋 Deployment Checklist

- [ ] Azure CLI installed
- [ ] Terraform installed (>= 1.0)
- [ ] Docker installed
- [ ] Logged into Azure (`az login`)
- [ ] Copied `terraform.tfvars.example` to `terraform.tfvars`
- [ ] Edited `terraform.tfvars` with unique `acr_name`
- [ ] Reviewed `app_service_plan_sku` (B1 for dev, S1+ for prod)
- [ ] Chosen appropriate `location`
- [ ] Run deployment
- [ ] Verified URLs are accessible
- [ ] Checked logs for errors

## 🔧 Common Commands Reference

### Terraform Commands
```bash
# Initialize
terraform init

# Plan (preview changes)
terraform plan

# Apply (deploy)
terraform apply

# Destroy (delete all resources)
terraform destroy

# Show outputs
terraform output

# Show specific output
terraform output -raw api_url
```

### Docker Commands
```bash
# Login to ACR
az acr login --name <acr-name>

# Build image
docker build -t <image-name>:<tag> <path>

# Push image
docker push <image-name>:<tag>

# List images in ACR
az acr repository list --name <acr-name>
```

### Azure CLI Commands
```bash
# Restart App Service
az webapp restart --name <app-name> --resource-group <rg-name>

# Stream logs
az webapp log tail --name <app-name> --resource-group <rg-name>

# Show app configuration
az webapp config show --name <app-name> --resource-group <rg-name>

# List all resources in resource group
az resource list --resource-group <rg-name> --output table
```

## 🏗️ Infrastructure Components

### Resource Hierarchy
```
Resource Group
├── Container Registry (ACR)
│   ├── octocat-supply-api:latest
│   └── octocat-supply-frontend:latest
├── App Service Plan (Linux)
│   ├── API App Service
│   │   ├── Port: 3000
│   │   ├── Runtime: Node.js container
│   │   └── Health check: /api/health
│   └── Frontend App Service
│       ├── Port: 80
│       ├── Runtime: NGINX container
│       └── Connects to API via HTTPS
```

### Networking
- **API**: Exposed on HTTPS (443)
- **Frontend**: Exposed on HTTPS (443)
- **CORS**: Auto-configured between frontend and API
- **Internal**: Frontend connects to API using default hostname

### Data Persistence
- **SQLite Database**: Stored in container filesystem
- **Note**: Data is ephemeral - container restarts reset DB
- **Solution**: Consider Azure Database for persistent storage

## 💰 Cost Breakdown

| Resource | SKU/Tier | Monthly Cost (Est.) |
|----------|----------|---------------------|
| App Service Plan (B1) | Basic | ~$13 |
| Container Registry | Basic | ~$5 |
| Data Transfer | Minimal | ~$1-2 |
| **Total (Dev)** | | **~$18-20** |
| App Service Plan (S1) | Standard | ~$69 |
| **Total (Prod)** | | **~$75-80** |

**Savings Tips**:
- Use B1 for development
- Stop/delete when not in use
- Use reserved instances for production
- Monitor with Azure Cost Management

## 🔐 Security Checklist

- [ ] HTTPS enforced (✓ configured in Terraform)
- [ ] ACR admin credentials secured
- [ ] Service principal with minimal permissions (for CI/CD)
- [ ] Secrets in GitHub Secrets, not code
- [ ] CORS properly configured
- [ ] Health checks enabled
- [ ] Logging enabled for debugging
- [ ] Consider Azure Key Vault for secrets
- [ ] Consider VNet integration for production
- [ ] Enable Azure Defender for App Service (optional)

## 🐛 Troubleshooting Guide

### Issue: Terraform apply fails
**Check**:
- Azure CLI logged in: `az account show`
- Correct subscription: `az account set --subscription <id>`
- Unique `acr_name` in `terraform.tfvars`
- Valid `location` value

### Issue: Docker push fails
**Check**:
- Logged into ACR: `az acr login --name <acr-name>`
- Correct image tag format
- Network connectivity

### Issue: App doesn't start
**Check**:
- Container logs: `az webapp log tail --name <app-name> --resource-group <rg-name>`
- `WEBSITES_PORT` matches container port
- Image successfully pulled from ACR
- Environment variables set correctly

### Issue: Frontend can't reach API
**Check**:
- `API_HOST` environment variable
- CORS configuration
- Both apps using HTTPS
- API health check passing

## 📚 Additional Resources

- **Main README**: [../README.md](../README.md)
- **Project Documentation**: [../../docs/](../../docs/)
- **Azure App Service**: https://docs.microsoft.com/azure/app-service/
- **Terraform Azure Provider**: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- **Azure Container Registry**: https://docs.microsoft.com/azure/container-registry/

## 🎯 Next Steps After Deployment

1. **Verify Deployment**
   - Access frontend URL
   - Check API Swagger docs
   - Test core functionality

2. **Set Up Monitoring**
   - Enable Application Insights
   - Configure alerts
   - Review cost analytics

3. **Configure CI/CD**
   - Follow CICD.md
   - Set up GitHub Actions
   - Test automated deployments

4. **Optimize for Production**
   - Scale to Standard tier
   - Add custom domain
   - Configure SSL certificate
   - Set up backup/restore
   - Implement blue/green deployments

5. **Security Hardening**
   - Migrate to managed identity
   - Implement VNet integration
   - Add WAF (Application Gateway)
   - Enable Azure Defender

## 📞 Support

For issues related to:
- **Terraform**: Check [README.md](README.md) troubleshooting section
- **Azure**: Consult Azure documentation
- **Application**: Check project's main README and docs
- **CI/CD**: See [CICD.md](CICD.md)

---

**Last Updated**: 2026-04-17
**Terraform Version**: >= 1.0
**Azure Provider Version**: ~> 4.0

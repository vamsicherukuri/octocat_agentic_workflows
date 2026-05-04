# OctoCAT Supply - Azure App Service Terraform Deployment

This directory contains Terraform configuration to deploy the OctoCAT Supply application to Azure App Services using native Node.js runtime (no Docker required).

## Architecture

The Terraform configuration creates:

- **Resource Group**: Container for all Azure resources
- **App Service Plan**: Linux-based plan with Node.js 20 LTS runtime
- **API App Service**: Backend Node.js/Express application
- **Frontend App Service**: React/Vite application served via `vite preview`

## Prerequisites

1. **Azure CLI**: Install from https://docs.microsoft.com/cli/azure/install-azure-cli
2. **Terraform**: Install from https://www.terraform.io/downloads
3. **Azure Subscription**: Active Azure subscription with appropriate permissions

## Quick Start

### 1. Login to Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Configure Variables

Copy the example variables file and customize:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to set your values:
- **app_name**: Base name for resources (max 20 chars)
- **location**: Azure region (e.g., eastus, westus2)
- **environment**: Environment name (dev, staging, prod)

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 6. Deploy Application Code

After infrastructure is provisioned, deploy source code via zip:

```bash
# From repo root - package and deploy API
cd api && zip -r /tmp/api.zip . --exclude "node_modules/*" --exclude "dist/*"
az webapp deploy --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw api_app_name) --src-path /tmp/api.zip --type zip --async true

# Package and deploy frontend
cd ../frontend && zip -r /tmp/frontend.zip . --exclude "node_modules/*" --exclude "dist/*"
az webapp deploy --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw frontend_app_name) --src-path /tmp/frontend.zip --type zip --async true
```

Or use the provided deployment script from the `infra/` directory:

```bash
# Linux/Mac
./deploy.sh

# Windows
.\deploy.ps1
```

### 7. Access Your Application

```bash
terraform output frontend_url
terraform output api_url
```

## Configuration

### App Service Plan SKUs

Choose the right SKU based on your needs:

- **B1, B2, B3** (Basic): Good for dev/test, supports Always On
- **S1, S2, S3** (Standard): Production workloads, auto-scaling
- **P1v2, P2v2, P3v2** (Premium v2): High performance
- **P1v3, P2v3, P3v3** (Premium v3): Latest premium tier

Update in `terraform.tfvars`:
```hcl
app_service_plan_sku = "B1"  # or S1, P1v2, etc.
```

### Build Process

App Service uses Azure's [Oryx build system](https://github.com/microsoft/Oryx) to automatically:
1. Install Node.js 20 LTS
2. Run `npm install` (including devDependencies, controlled by `NPM_CONFIG_PRODUCTION=false`)
3. Run the build script defined in `package.json`
4. Start the app via the configured `app_command_line`

## Monitoring and Logs

```bash
# Stream API logs
az webapp log tail --name <api-app-name> --resource-group <resource-group>

# Download logs
az webapp log download --name <api-app-name> --resource-group <resource-group> --log-file api-logs.zip
```

terraform apply
```

Type `yes` when prompted to confirm the deployment.

### 6. Build and Push Docker Images

After infrastructure is deployed, build and push your Docker images:

```bash
# Get ACR login server from Terraform output
ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server)

# Login to ACR
az acr login --name $(terraform output -raw container_registry_login_server | cut -d'.' -f1)

# Build and push API image
cd ../../api
docker build -t ${ACR_LOGIN_SERVER}/octocat-supply-api:latest .
docker push ${ACR_LOGIN_SERVER}/octocat-supply-api:latest

# Build and push Frontend image
cd ../frontend
docker build -t ${ACR_LOGIN_SERVER}/octocat-supply-frontend:latest .
docker push ${ACR_LOGIN_SERVER}/octocat-supply-frontend:latest
```

### 7. Restart App Services

Restart the App Services to pull the new images:

```bash
cd ../infra/terraform

# Get resource details
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
API_APP_NAME=$(terraform output -raw api_app_name)
FRONTEND_APP_NAME=$(terraform output -raw frontend_app_name)

# Restart apps
az webapp restart --name $API_APP_NAME --resource-group $RESOURCE_GROUP
az webapp restart --name $FRONTEND_APP_NAME --resource-group $RESOURCE_GROUP
```

### 8. Access Your Application

Get the URLs from Terraform outputs:

```bash
terraform output frontend_url
terraform output api_url
```

Or view all deployment instructions:

```bash
terraform output deployment_instructions
```

## Configuration

### App Service Plan SKUs

Choose the right SKU based on your needs:

- **B1, B2, B3** (Basic): Good for dev/test, supports Always On
- **S1, S2, S3** (Standard): Production workloads, auto-scaling
- **P1v2, P2v2, P3v2** (Premium v2): High performance
- **P1v3, P2v3, P3v3** (Premium v3): Latest premium tier

Update in `terraform.tfvars`:
```hcl
app_service_plan_sku = "B1"  # or S1, P1v2, etc.
```

### Container Registry SKUs

- **Basic**: Small-scale scenarios
- **Standard**: Most production scenarios
- **Premium**: Geo-replication, advanced features

### Environment Variables

Both App Services are configured with appropriate environment variables:

**API App Service:**
- `NODE_ENV=production`
- `PORT=3000`
- `WEBSITES_PORT=3000`

**Frontend App Service:**
- `API_HOST=<api-hostname>`
- `API_PORT=443`
- `WEBSITES_PORT=80`

## Monitoring and Logs

### View Application Logs

```bash
# API logs
az webapp log tail --name $API_APP_NAME --resource-group $RESOURCE_GROUP

# Frontend logs
az webapp log tail --name $FRONTEND_APP_NAME --resource-group $RESOURCE_GROUP
```

### Stream Logs in Real-time

```bash
az webapp log tail --name $API_APP_NAME --resource-group $RESOURCE_GROUP
```

### Download Logs

```bash
az webapp log download --name $API_APP_NAME --resource-group $RESOURCE_GROUP --log-file api-logs.zip
```

## Continuous Deployment

For automated deployments, consider:

1. **GitHub Actions**: Use Azure credentials and deploy on push
2. **Azure DevOps**: Set up CI/CD pipelines
3. **Webhook**: Configure ACR webhook to trigger App Service deployment

Example GitHub Actions workflow snippet:

```yaml
- name: Build and push to ACR
  run: |
    az acr build --registry ${{ secrets.ACR_NAME }} \
      --image octocat-supply-api:${{ github.sha }} \
      --file ./api/Dockerfile ./api

- name: Deploy to App Service
  uses: azure/webapps-deploy@v2
  with:
    app-name: ${{ secrets.API_APP_NAME }}
    images: ${{ secrets.ACR_LOGIN_SERVER }}/octocat-supply-api:${{ github.sha }}
```

## Troubleshooting

### Container fails to start

Check logs:
```bash
az webapp log tail --name $API_APP_NAME --resource-group $RESOURCE_GROUP
```

Common issues:
- Incorrect `WEBSITES_PORT` setting
- Container registry authentication
- Missing environment variables

### Cannot pull images from ACR

Verify ACR credentials:
```bash
az acr credential show --name $(terraform output -raw container_registry_login_server | cut -d'.' -f1)
```

Ensure App Service has correct registry settings in app settings.

### Frontend cannot connect to API

1. Check CORS settings in API App Service
2. Verify `API_HOST` environment variable in Frontend
3. Ensure both apps are in the same region for optimal performance

## Updating the Application

1. Make code changes
2. Build and push new Docker images (use tags for versioning)
3. Update `terraform.tfvars` with new image tags (optional)
4. Restart App Services or redeploy with Terraform

```bash
# Quick update without Terraform
az webapp restart --name $API_APP_NAME --resource-group $RESOURCE_GROUP
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted to confirm deletion.

**Warning**: This will permanently delete all resources including the Container Registry and all images.

## Cost Optimization

- Use **Basic (B1)** tier for development
- Use **Standard (S1)** for production with auto-scaling disabled
- Enable auto-scaling only if needed
- Delete resources when not in use
- Consider Azure Reserved Instances for production

## Security Best Practices

1. **Use Managed Identity**: Consider migrating to managed identity for ACR access
2. **Enable HTTPS Only**: Already configured in Terraform
3. **Network Security**: Consider VNet integration for production
4. **Secrets Management**: Use Azure Key Vault for sensitive data
5. **Regular Updates**: Keep base Docker images updated

## Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Container Registry](https://docs.microsoft.com/azure/container-registry/)
- [Docker on App Service](https://docs.microsoft.com/azure/app-service/configure-custom-container)

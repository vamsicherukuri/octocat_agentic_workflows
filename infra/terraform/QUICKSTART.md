# Quick Deployment Guide - Azure App Services

## Prerequisites Checklist
- [ ] Azure CLI installed
- [ ] Terraform installed (>= 1.0)
- [ ] Docker installed
- [ ] Logged into Azure (`az login`)
- [ ] Active Azure subscription

## Quick Deploy (PowerShell - Windows)

```powershell
cd infra
.\deploy.ps1
```

## Quick Deploy (Bash - Linux/Mac)

```bash
cd infra
chmod +x deploy.sh
./deploy.sh
```

## Manual Step-by-Step

### 1. Setup Terraform Variables

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Important**: Change `acr_name` to something globally unique!

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Build & Push Images

```bash
# Get ACR name
ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server)

# Login to ACR
az acr login --name $(echo $ACR_LOGIN_SERVER | cut -d'.' -f1)

# Build and push (from project root)
cd ../..
docker build -t $ACR_LOGIN_SERVER/octocat-supply-api:latest ./api
docker push $ACR_LOGIN_SERVER/octocat-supply-api:latest

docker build -t $ACR_LOGIN_SERVER/octocat-supply-frontend:latest ./frontend
docker push $ACR_LOGIN_SERVER/octocat-supply-frontend:latest
```

### 4. Restart App Services

```bash
cd infra/terraform
az webapp restart --name $(terraform output -raw api_app_name) \
  --resource-group $(terraform output -raw resource_group_name)

az webapp restart --name $(terraform output -raw frontend_app_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

### 5. Access Application

```bash
# View URLs
terraform output frontend_url
terraform output api_url
```

## Common Tasks

### View Logs
```bash
cd infra/terraform
az webapp log tail --name $(terraform output -raw api_app_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

### Update Application (New Images Only)
```bash
cd infra
.\deploy.ps1 -SkipInfrastructure
```

### Destroy All Resources
```bash
cd infra/terraform
terraform destroy
```

## Troubleshooting

**Issue**: Container fails to start
- Check: `az webapp log tail --name <app-name> --resource-group <rg-name>`
- Verify: WEBSITES_PORT matches container's exposed port

**Issue**: Cannot pull images from ACR
- Verify ACR credentials in App Service app settings
- Check: `az acr credential show --name <acr-name>`

**Issue**: Frontend cannot reach API
- Check CORS settings in API
- Verify API_HOST environment variable in frontend
- Both apps should use HTTPS

## Cost Estimates (Monthly)

- **Basic Tier (B1)**: ~$13/month (good for dev/test)
- **Standard Tier (S1)**: ~$69/month (production)
- **ACR Basic**: ~$5/month
- **Total Dev Environment**: ~$18-25/month
- **Total Prod Environment**: ~$75-85/month

💡 **Tip**: Delete resources when not in use to save costs!

## Next Steps

1. Setup custom domain
2. Configure SSL certificates
3. Enable Application Insights
4. Setup CI/CD pipeline
5. Configure backup/restore
6. Enable auto-scaling (Standard tier+)

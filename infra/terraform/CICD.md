# GitHub Actions CI/CD Setup Guide

This guide explains how to set up automated deployments to Azure App Services using GitHub Actions.

## Prerequisites

1. Azure resources deployed via Terraform
2. GitHub repository for the project
3. Azure credentials configured

## Setup Steps

### 1. Create Azure Service Principal

Create a service principal with contributor access to your resource group:

```bash
# Get your subscription ID
az account show --query id -o tsv

# Create service principal (replace <subscription-id> and <resource-group-name>)
az ad sp create-for-rbac \
  --name "github-actions-octocat-supply" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/<resource-group-name> \
  --sdk-auth
```

Copy the JSON output - you'll need it for GitHub secrets.

### 2. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `AZURE_CREDENTIALS` | JSON from service principal creation | Step 1 output |
| `API_APP_NAME` | API App Service name | `terraform output api_app_name` |
| `FRONTEND_APP_NAME` | Frontend App Service name | `terraform output frontend_app_name` |
| `RESOURCE_GROUP` | Resource group name | `terraform output resource_group_name` |

### 3. Create GitHub Workflow File

Copy the example workflow to your repository:

```bash
mkdir -p .github/workflows
cp infra/terraform/.github-workflows-example.yml .github/workflows/azure-deploy.yml
```

### 4. Commit and Push

```bash
git add .github/workflows/azure-deploy.yml
git commit -m "Add Azure deployment workflow"
git push
```

## Workflow Features

### Automatic Triggers
- Pushes to `main` branch → Deploy to production
- Pushes to `develop` branch → Deploy to dev
- Manual workflow dispatch → Choose environment

### Build Process
1. Checkout code
2. Setup Node.js environment
3. Login to Azure
4. Package API and frontend source into zip archives
5. Deploy to App Service via `az webapp deploy --type zip`
6. Oryx build engine handles `npm install` and `npm run build` on Azure

6. Deploy to App Services
7. Display deployment summary

### Image Tagging Strategy
- Every build creates two tags:
  - `latest` - Always points to the most recent build
  - `<git-sha>` - Specific commit for rollback capability

## Rollback

To rollback to a previous version:

```bash
# List available images
az acr repository show-tags --name <acr-name> --repository octocat-supply-api

# Deploy specific version
az webapp config container set \
  --name <app-name> \
  --resource-group <resource-group> \
  --docker-custom-image-name <acr-login-server>/octocat-supply-api:<git-sha>

# Restart the app
az webapp restart --name <app-name> --resource-group <resource-group>
```

## Environment-Specific Deployments

To set up multiple environments (dev, staging, prod):

1. Create multiple resource groups via Terraform
2. Add environment-specific secrets in GitHub
3. Use GitHub Environments feature for approval gates
4. Modify workflow to use environment-specific variables

Example:
```yaml
environment: production
```

This enables:
- Required reviewers before deployment
- Environment-specific secrets
- Deployment protection rules

## Monitoring Deployments

### View Workflow Runs
- Go to Actions tab in your GitHub repository
- Click on a workflow run to see details
- View logs for each step

### View App Service Logs
```bash
# Stream logs in real-time
az webapp log tail --name <app-name> --resource-group <resource-group>

# Download logs
az webapp log download --name <app-name> --resource-group <resource-group>
```

### Deployment Status Badge

Add this to your README.md:

```markdown
![Deploy to Azure](https://github.com/<username>/<repo>/actions/workflows/azure-deploy.yml/badge.svg)
```

## Best Practices

1. **Use Environments**: Set up GitHub Environments for better control
2. **Enable Branch Protection**: Require PR reviews before merging to main
3. **Run Tests First**: Uncomment the test job in the workflow
4. **Tag Releases**: Use Git tags for production releases
5. **Monitor Costs**: Check Azure costs regularly via Azure Portal
6. **Rotate Secrets**: Periodically rotate service principal credentials

## Troubleshooting

### Deployment Fails with Authentication Error
- Verify `AZURE_CREDENTIALS` secret is correct
- Check service principal has contributor role
- Ensure service principal is not expired

### Cannot Push to Container Registry
- Verify ACR credentials in secrets
- Check ACR allows admin user access
- Ensure ACR name is correct

### App Service Doesn't Update
- Check if new image was pushed to ACR
- Verify App Service pulled the new image
- Restart App Service manually if needed
- Check App Service logs for errors

### Build Fails
- Check Node.js version compatibility
- Verify all dependencies are in package.json
- Check Dockerfile syntax
- Review build logs in GitHub Actions

## Advanced Configuration

### Multi-Environment Setup

Create different Terraform workspaces:

```bash
# Dev environment
terraform workspace new dev
terraform apply -var-file=dev.tfvars

# Production environment
terraform workspace new prod
terraform apply -var-file=prod.tfvars
```

### Custom Domain Setup

After deployment, add custom domain:

```bash
# Add custom domain
az webapp config hostname add \
  --webapp-name <app-name> \
  --resource-group <resource-group> \
  --hostname <custom-domain>

# Add SSL certificate
az webapp config ssl upload \
  --certificate-file <cert-file> \
  --certificate-password <password> \
  --name <app-name> \
  --resource-group <resource-group>
```

### Application Insights Integration

Add to your Terraform configuration:

```hcl
resource "azurerm_application_insights" "main" {
  name                = "${var.app_name}-insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}
```

## Security Recommendations

1. **Never commit secrets** to the repository
2. **Use managed identities** instead of passwords when possible
3. **Enable Azure Defender** for App Service
4. **Implement secret scanning** in GitHub
5. **Use Azure Key Vault** for sensitive configuration
6. **Enable HTTPS only** (already configured in Terraform)
7. **Implement proper RBAC** for service principals

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Azure App Service Deploy Action](https://github.com/Azure/webapps-deploy)
- [Azure Login Action](https://github.com/Azure/login)
- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)

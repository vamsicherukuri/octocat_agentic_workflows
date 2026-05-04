# OctoCAT Supply - Azure App Service Deployment Script (PowerShell)
# This script automates the deployment process for Windows

param(
    [switch]$SkipInfrastructure,
    [switch]$SkipAppDeploy,
    [switch]$Force,
    [switch]$Destroy
)

$ErrorActionPreference = "Stop"

# Colors for output
$ErrorColor = "Red"
$InfoColor = "Green"
$WarnColor = "Yellow"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $InfoColor
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor $WarnColor
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $ErrorColor
}

function Assert-LastExitCode {
    param([string]$Action)

    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed with exit code $LASTEXITCODE"
    }
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Err "Azure CLI is not installed. Please install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    }
    
    # Check Terraform
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Err "Terraform is not installed. Please install from: https://www.terraform.io/downloads"
        exit 1
    }
    
    Write-Info "All prerequisites are installed ✓"
}

function Test-AzureLogin {
    Write-Info "Checking Azure login status..."
    
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if (-not $account) {
            Write-Warn "Not logged in to Azure. Please login..."
            az login
            Assert-LastExitCode "Azure login"
        }

        $subscription = az account show --query name -o tsv
        Assert-LastExitCode "Reading Azure subscription"
        Write-Info "Using Azure subscription: $subscription ✓"
    }
    catch {
        Write-Warn "Not logged in to Azure. Please login..."
        az login
        Assert-LastExitCode "Azure login"
    }
}

function Initialize-Terraform {
    Write-Info "Setting up Terraform configuration..."
    
    Push-Location "$PSScriptRoot\terraform"
    
    # Check if terraform.tfvars exists
    if (-not (Test-Path "terraform.tfvars")) {
        Write-Warn "terraform.tfvars not found. Creating from example..."
        Copy-Item "terraform.tfvars.example" "terraform.tfvars"
        Write-Warn "Please edit terraform.tfvars with your custom values before proceeding."
        
        if (-not $Force) {
            Read-Host "Press Enter after editing terraform.tfvars to continue"
        }
    }
    
    # Initialize Terraform
    Write-Info "Initializing Terraform..."
    terraform init
    Assert-LastExitCode "Terraform init"
    
    Pop-Location
}

function Deploy-Infrastructure {
    Write-Info "Deploying infrastructure with Terraform..."
    
    Push-Location "$PSScriptRoot\terraform"
    
    # Plan
    Write-Info "Creating Terraform plan..."
    terraform plan -out=tfplan
    Assert-LastExitCode "Terraform plan"
    
    # Apply
    if (-not $Force) {
        $confirm = Read-Host "Do you want to apply this plan? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Warn "Deployment cancelled by user."
            Remove-Item tfplan -ErrorAction SilentlyContinue
            Pop-Location
            exit 0
        }
    }
    
    terraform apply tfplan
    Assert-LastExitCode "Terraform apply"
    Remove-Item tfplan -ErrorAction SilentlyContinue
    Write-Info "Infrastructure deployed successfully ✓"
    
    Pop-Location
}

function New-DeploymentArchive {
    param(
        [string]$SourcePath,
        [string]$ArchivePath
    )

    if (Test-Path $ArchivePath) {
        Remove-Item $ArchivePath -Force
    }

    # Change into the source directory so the zip contains files at the root,
    # not nested under the source folder name.
    Push-Location $SourcePath
    try {
        $items = Get-ChildItem -Force | Where-Object {
            $_.Name -notin @("node_modules", "dist", ".git", ".github", ".terraform")
        }

        if (-not $items) {
            throw "No files found to archive in $SourcePath"
        }

        Compress-Archive -Path $items.FullName -DestinationPath $ArchivePath -Force
    }
    finally {
        Pop-Location
    }
}

function Deploy-ApplicationCode {
    Write-Info "Packaging and deploying application source code..."

    Push-Location "$PSScriptRoot\terraform"
    $resourceGroup = terraform output -raw resource_group_name
    Assert-LastExitCode "Reading Terraform output resource_group_name"
    $apiAppName = terraform output -raw api_app_name
    Assert-LastExitCode "Reading Terraform output api_app_name"
    $frontendAppName = terraform output -raw frontend_app_name
    Assert-LastExitCode "Reading Terraform output frontend_app_name"
    $apiUrl = terraform output -raw api_url
    Assert-LastExitCode "Reading Terraform output api_url"
    Pop-Location

    $apiArchive = Join-Path $env:TEMP "octocat-api.zip"
    $frontendArchive = Join-Path $env:TEMP "octocat-frontend.zip"

    New-DeploymentArchive -SourcePath (Join-Path $PSScriptRoot "..\api") -ArchivePath $apiArchive
    New-DeploymentArchive -SourcePath (Join-Path $PSScriptRoot "..\frontend") -ArchivePath $frontendArchive

    Write-Info "Deploying API... (this takes ~3-5 min while Oryx builds)"
    az webapp deploy --resource-group $resourceGroup --name $apiAppName --src-path $apiArchive --type zip
    Assert-LastExitCode "API zip deployment"
    Write-Info "API deployed ✓"

    Write-Info "Deploying frontend... (this takes ~2-3 min while Oryx builds)"
    az webapp deploy --resource-group $resourceGroup --name $frontendAppName --src-path $frontendArchive --type zip
    Assert-LastExitCode "Frontend zip deployment"
    Write-Info "Frontend deployed ✓"

    Remove-Item $apiArchive -Force -ErrorAction SilentlyContinue
    Remove-Item $frontendArchive -Force -ErrorAction SilentlyContinue

    # Poll API health until it responds (Oryx restarts the app after build)
    Write-Info "Waiting for API to become healthy..."
    $healthUrl = "$apiUrl/api/health"
    $maxAttempts = 24  # 2 minutes
    $attempt = 0
    $healthy = $false
    while ($attempt -lt $maxAttempts) {
        try {
            $result = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5 -ErrorAction Stop
            if ($result.status -eq "ok") {
                Write-Info "API is healthy ✓"
                $healthy = $true
                break
            }
        } catch {}
        $attempt++
        Write-Host "  Waiting for API... ($attempt/$maxAttempts)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
    }
    if (-not $healthy) {
        Write-Warn "API health check timed out — it may still be starting. Check: $healthUrl"
    }
}

function Restart-AppServices {
    Write-Info "Restarting App Services..."
    
    Push-Location "$PSScriptRoot\terraform"
    
    $resourceGroup = terraform output -raw resource_group_name
    Assert-LastExitCode "Reading Terraform output resource_group_name"
    $apiAppName = terraform output -raw api_app_name
    Assert-LastExitCode "Reading Terraform output api_app_name"
    $frontendAppName = terraform output -raw frontend_app_name
    Assert-LastExitCode "Reading Terraform output frontend_app_name"
    
    Write-Info "Restarting API App Service: $apiAppName"
    az webapp restart --name $apiAppName --resource-group $resourceGroup
    Assert-LastExitCode "API app restart"
    
    Write-Info "Restarting Frontend App Service: $frontendAppName"
    az webapp restart --name $frontendAppName --resource-group $resourceGroup
    Assert-LastExitCode "Frontend app restart"
    
    Write-Info "App Services restarted successfully ✓"
    
    Pop-Location
}

function Destroy-Infrastructure {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Host "  WARNING: This will DELETE all Azure resources" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Red
    Write-Host ""

    if (-not $Force) {
        $confirm = Read-Host "Type 'destroy' to confirm deletion of all resources"
        if ($confirm -ne "destroy") {
            Write-Warn "Destroy cancelled."
            exit 0
        }
    }

    Push-Location "$PSScriptRoot\terraform"

    Write-Info "Running terraform destroy..."
    terraform destroy -auto-approve
    Assert-LastExitCode "Terraform destroy"

    Write-Info "All Azure resources destroyed ✓"

    Pop-Location
}

function Show-DeploymentInfo {
    Write-Info "Deployment completed successfully! 🎉"
    Write-Host ""
    
    Push-Location "$PSScriptRoot\terraform"
    
    $frontendUrl = terraform output -raw frontend_url
    Assert-LastExitCode "Reading Terraform output frontend_url"
    $apiUrl = terraform output -raw api_url
    Assert-LastExitCode "Reading Terraform output api_url"
    $resourceGroup = terraform output -raw resource_group_name
    Assert-LastExitCode "Reading Terraform output resource_group_name"
    $apiAppName = terraform output -raw api_app_name
    Assert-LastExitCode "Reading Terraform output api_app_name"
    
    Write-Host "================================================"
    Write-Host "  OctoCAT Supply - Deployment Information"
    Write-Host "================================================"
    Write-Host ""
    Write-Host "Frontend URL: $frontendUrl" -ForegroundColor Cyan
    Write-Host "API URL: $apiUrl" -ForegroundColor Cyan
    Write-Host "API Swagger: $apiUrl/api-docs" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To view logs:" -ForegroundColor Yellow
    Write-Host "  az webapp log tail --name $apiAppName --resource-group $resourceGroup"
    Write-Host ""
    Write-Host "================================================"
    
    Pop-Location
}

# Main deployment flow
function Main {
    Write-Host "================================================"
    Write-Host "  OctoCAT Supply - Azure Deployment Script"
    Write-Host "================================================"
    Write-Host ""

    Test-Prerequisites
    Test-AzureLogin
    Initialize-Terraform

    if ($Destroy) {
        Destroy-Infrastructure
        return
    }

    # Deployment steps
    Write-Host ""
    Write-Host "Deployment will perform the following steps:"
    Write-Host "1. Deploy Azure infrastructure" -ForegroundColor $(if ($SkipInfrastructure) { "DarkGray" } else { "White" })
    Write-Host "2. Deploy API + frontend code" -ForegroundColor $(if ($SkipAppDeploy) { "DarkGray" } else { "White" })
    Write-Host ""

    if (-not $Force) {
        $proceed = Read-Host "Do you want to proceed? (yes/no)"
        if ($proceed -ne "yes") {
            Write-Warn "Deployment cancelled by user."
            exit 0
        }
    }
    
    if (-not $SkipInfrastructure) {
        Deploy-Infrastructure
    }

    if (-not $SkipAppDeploy) {
        Deploy-ApplicationCode
    }

    Show-DeploymentInfo
}

# Run main function
try {
    Main
}
catch {
    Write-Err "Deployment failed: $_"
    exit 1
}

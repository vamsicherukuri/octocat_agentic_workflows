terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    environment = var.environment
    project     = "octocat-supply"
  }
}

# App Service Plan (Linux)
resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  
  tags = {
    environment = var.environment
    project     = "octocat-supply"
  }
}

# API App Service
resource "azurerm_linux_web_app" "api" {
  name                = "${var.app_name}-api"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  
  site_config {
    always_on = var.always_on

    application_stack {
      node_version = "20-lts"
    }

    app_command_line = "cd /home/site/wwwroot && npm start"

    health_check_path = "/api/health"
    health_check_eviction_time_in_min = 2
  }

  app_settings = {
    "NODE_ENV"                    = "production"
    "PORT"                        = "8080"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "ENABLE_ORYX_BUILD"           = "true"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~20"
    "NPM_CONFIG_PRODUCTION"       = "false"
    "API_CORS_ORIGINS"            = join(",", concat(
      ["https://${var.app_name}-frontend.azurewebsites.net"],
      var.environment == "dev" || var.environment == "development" ? ["http://localhost:5137"] : []
    ))
  }

  https_only = true

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    
    application_logs {
      file_system_level = "Information"
    }
  }
  
  tags = {
    environment = var.environment
    project     = "octocat-supply"
    component   = "api"
  }
}

# Frontend App Service
resource "azurerm_linux_web_app" "frontend" {
  name                = "${var.app_name}-frontend"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  
  site_config {
    always_on = var.always_on

    application_stack {
      node_version = "20-lts"
    }

    app_command_line = "cd /home/site/wwwroot && npm run preview -- --host 0.0.0.0 --port 8080"
  }

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "ENABLE_ORYX_BUILD"              = "true"
    "WEBSITE_NODE_DEFAULT_VERSION"   = "~20"
    "NPM_CONFIG_PRODUCTION"          = "false"
    "VITE_API_URL"                   = "https://${azurerm_linux_web_app.api.default_hostname}"
  }

  https_only = true

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    
    application_logs {
      file_system_level = "Information"
    }
  }
  
  tags = {
    environment = var.environment
    project     = "octocat-supply"
    component   = "frontend"
  }
  
  depends_on = [
    azurerm_linux_web_app.api
  ]
}

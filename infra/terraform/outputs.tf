output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "api_url" {
  description = "URL of the API App Service"
  value       = "https://${azurerm_linux_web_app.api.default_hostname}"
}

output "frontend_url" {
  description = "URL of the Frontend App Service"
  value       = "https://${azurerm_linux_web_app.frontend.default_hostname}"
}

output "api_app_name" {
  description = "Name of the API App Service"
  value       = azurerm_linux_web_app.api.name
}

output "frontend_app_name" {
  description = "Name of the Frontend App Service"
  value       = azurerm_linux_web_app.frontend.name
}

output "app_service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.main.name
}

output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value       = <<-EOT

    ## Deployment Instructions

   1. Deploy application source code:
       ```bash
     az webapp deploy --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_linux_web_app.api.name} --src-path api.zip --type zip
     az webapp deploy --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_linux_web_app.frontend.name} --src-path frontend.zip --type zip
       ```

   2. Access your application:
       - Frontend: https://${azurerm_linux_web_app.frontend.default_hostname}
       - API: https://${azurerm_linux_web_app.api.default_hostname}
       - API Swagger: https://${azurerm_linux_web_app.api.default_hostname}/api-docs

  EOT
}

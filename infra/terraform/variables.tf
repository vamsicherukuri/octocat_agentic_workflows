variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-octocat-supply"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Base name for the application resources"
  type        = string
  default     = "octocat-supply"
  
  validation {
    condition     = length(var.app_name) <= 20 && can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "App name must be 20 characters or less and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "app_service_plan_sku" {
  description = "SKU for App Service Plan (e.g., B1, S1, P1v2, P1v3)"
  type        = string
  default     = "B1"
}

variable "always_on" {
  description = "Keep the app always on (requires Basic tier or higher)"
  type        = bool
  default     = true
}

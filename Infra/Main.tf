locals {
  common_tags = {
    workload    = "cedarbridge-ticketing"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "cedarbridge" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = local.common_tags
}


resource "azurerm_log_analytics_workspace" "cedarbridge" {
  name                = "law-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.cedarbridge.location
  resource_group_name = azurerm_resource_group.cedarbridge.name

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = local.common_tags
}

resource "azurerm_container_app_environment" "cedarbridge" {
  name                = "cae-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.cedarbridge.location
  resource_group_name = azurerm_resource_group.cedarbridge.name

  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.cedarbridge.id

  tags = local.common_tags
}

resource "azurerm_container_app" "cedarbridge" {
  name                         = "ca-${var.project_name}-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.cedarbridge.id
  resource_group_name          = azurerm_resource_group.cedarbridge.name
  revision_mode                = "Single"

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "cedarbridge-web"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled           = true
    target_port                = 80
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags
}
# Get current Azure subscription information
data "azurerm_client_config" "current" {}

# SQL Logical Server
resource "azurerm_mssql_server" "cedarbridge" {
  name = "sql-${var.project_name}-${var.environment}-${substr(sha256(data.azurerm_client_config.current.subscription_id), 0, 8)}"

  location            = azurerm_resource_group.cedarbridge.location
  resource_group_name = azurerm_resource_group.cedarbridge.name

  version = "12.0"

  administrator_login                     = "cedarbridgeadmin"
  administrator_login_password_wo         = var.sql_admin_password
  administrator_login_password_wo_version = 1

  minimum_tls_version           = "1.2"
  public_network_access_enabled = true

  tags = local.common_tags
}

# Azure SQL Development Database - Free Offer
resource "azapi_resource" "cedarbridge_database" {
  type      = "Microsoft.Sql/servers/databases@2023-08-01"
  name      = "sqldb-${var.project_name}-${var.environment}"
  parent_id = azurerm_mssql_server.cedarbridge.id
  location  = azurerm_mssql_server.cedarbridge.location

  body = {
    sku = {
      name     = "GP_S_Gen5"
      tier     = "GeneralPurpose"
      family   = "Gen5"
      capacity = 2
    }

    properties = {
      useFreeLimit                     = true
      freeLimitExhaustionBehavior      = "AutoPause"
      autoPauseDelay                   = 15
      minCapacity                      = 0.5
      maxSizeBytes                     = 34359738368
      requestedBackupStorageRedundancy = "Local"
    }
  }

  tags = local.common_tags
}
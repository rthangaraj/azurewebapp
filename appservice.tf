terraform {    
  required_providers {    
    azurerm = {    
      source = "hashicorp/azurerm"    
    }    
  }    
} 
   
provider "azurerm" {    
  features {}    
}


/*
# Configure the Microsoft Azure Active Directory Provider
provider "azuread" {
  version = "~> 0.3"
}

# Create an application
resource "azuread_application" "example" {
  name = "newday-app-service"
  homepage                   = "https://newday-app-service.azurewebsites.net"
  identifier_uris            = ["https://newday-app-service.azurewebsites.net"]
  reply_urls                 = ["https://newday-app-service.azurewebsites.net/.auth/login/aad/callback"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true

}
*/
resource "azurerm_resource_group" "rg" {
  name     = "app-service-rg"
  location = "North Europe"
}

resource "azurerm_storage_account" "storageacc" {
  name                     = "newdaystg01"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_kind              = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  enable_https_traffic_only = true


  tags = {
    environment = "newdaytest"
  }
}

## Create storage account container
resource "azurerm_storage_container" "storage_container" {
  name                  = "my-container"
  storage_account_name  = azurerm_storage_account.storageacc.name
  container_access_type = "private"
}

data "azurerm_storage_account_sas" "example" {
  connection_string = azurerm_storage_account.storageacc.primary_connection_string
  https_only        = true
  signed_version    = "2017-07-29"

  resource_types {
    service   = true
    container = false
    object    = false
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = "2022-03-07T00:00:00Z"
  expiry = "2024-03-21T00:00:00Z"

  permissions {
    read    = true
    write   = true
    delete  = false
    list    = false
    add     = true
    create  = true
    update  = false
    process = false
  }
}

output "sas_url_query_string" {
  value = data.azurerm_storage_account_sas.example.sas
  sensitive = true
}

resource "azurerm_app_service_plan" "appserviceplan" {
    name                = "slotAppServicePlan"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    kind                = "Windows"
    sku {
        tier = "Standard"
        size = "S1"
    }
    tags = {
    environment = "newdaytest"
  }
}
resource "azurerm_application_insights" "appinsights" {
  name                = "newdayappinsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"

  tags = {
    environment = "newdaytest"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet01"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags = {
    environment = "newdaytest"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "newdaysubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  enforce_private_link_endpoint_network_policies = false


  delegation {
    name = "newday-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "subnet1" {
  name                 = "newdaysubnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  enforce_private_link_endpoint_network_policies = true
}


resource "azurerm_app_service" "appservice" {
  name                = "newday-app-service"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id
  https_only                 = true
  client_cert_enabled = true
  client_affinity_enabled = true

  tags = {
    my-Environment = "newdaytest"
}
  backup {
    name                = "newdaybkup"
    storage_account_url = "https://${azurerm_storage_account.storageacc.name}.blob.core.windows.net/${azurerm_storage_container.storage_container.name}${data.azurerm_storage_account_sas.example.sas}&sr=b"
    enabled             = false
    schedule {
      frequency_interval = 1
      frequency_unit     = "Day"
    }
  }


  identity {
    type = "SystemAssigned"
  }
/*
  auth_settings  {
     enabled = true 

     active_directory  {
         client_id = "${azuread_application.example.application_id}"
     }
     default_provider = "AzureActiveDirectory"
     issuer = "https://sts.windows.net/afc0d9a5-337e-48ba-a421-016b937257a9/v2.0"

}
*/
/*
  enable_backup        = true
  storage_account_name = azurerm_storage_account.storageacc.name
  backup_settings = {
    enabled                  = true
    name                     = "DefaultBackup"
    frequency_interval       = 1
    frequency_unit           = "Day"
    retention_period_in_days = 90
  }
*/
  site_config {
      http2_enabled = true
      min_tls_version = "1.2"
      always_on = "true"
      ftps_state = "Disabled"
      dotnet_framework_version = "v4.0"
  
      /*ip_restriction {
      ip_address  = "${var.ip_address_2}" 
     
Ensure your App Service is accessible via HTTPS only
Ensure to use the latest version of TLS protocols
Ensure to enable authentication
Ensure to disable FTP deployment
Ensure to register the app identity with AD
Ensure to enable to indicate the details of error messages
Ensure to select the latest version of the .NET framework
*/
    
    
    }
    app_settings = {
    "EVENT_CONTAINER"                     = azurerm_storage_container.storage_container.name
    "WEBSITE_RUN_FROM_PACKAGE"            = 1
    "APPINSIGHTS_INSTRUMENTATIONKEY"      = azurerm_application_insights.appinsights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appinsights.connection_string
  }

  connection_string {
    name  = "StorageAccount"
    type  = "Custom"
    value = azurerm_storage_account.storageacc.primary_connection_string
  }
        
}

resource "azurerm_app_service_virtual_network_swift_connection" "vnetconnect" {
  app_service_id = azurerm_app_service.appservice.id
  subnet_id      = azurerm_subnet.subnet.id
}

resource "azurerm_private_endpoint" "privateendpoint" {
  name                = "newday-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet1.id

  private_service_connection {
    name                           = "newday-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.storageacc.id
    subresource_names              = ["blob"]
  }

}
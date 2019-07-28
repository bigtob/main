variable "resourcegroup" {}
variable "location" {}
variable "sqlserver" {}
variable "env" {}
variable "application" {}
variable "tenantid" {  
}
 
# resource "azurerm_resource_group" "rg" {
#   name     = "${var.resource_group}"
#   location = "${var.location}"
# }

# Retrieve the sql admin secret
  data "azurerm_key_vault_secret" "SQLPaaSAdmin" {
  name      = "SQLPaaSAdmin"
  vault_uri = "https://yourvault.vault.azure.net/"
}
resource "azurerm_storage_account" "sqlsecuritysa" {
  name                      = "${substr(lower(var.application),0,10)}${lower(var.env)}sqlsecurity"
  resource_group_name       = "${var.resourcegroup}"
  location                  = "${var.location}"
  account_tier              = "Standard"
  account_kind              = "StorageV2" 
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
}
resource "azurerm_sql_server" "server" {
  name                         = "${lower(var.sqlserver)}"
  resource_group_name          = "${var.resourcegroup}"
  location                     = "${var.location}"
  version                      = "12.0"
  administrator_login          = "${data.azurerm_key_vault_secret.SQLPaaSAdmin.name}"
  administrator_login_password = "${data.azurerm_key_vault_secret.SQLPaaSAdmin.value}"
}
 
# Enables the "Allow Access to Azure services" box as described in the API docs
# https://docs.microsoft.com/en-us/rest/api/sql/firewallrules/createorupdate
resource "azurerm_sql_firewall_rule" "fw" {
  name                = "firewallrules"
  resource_group_name = "${var.resourcegroup}"
  server_name         = "${azurerm_sql_server.server.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_template_deployment" "sqlserveraudit" {
  name                = "sqlserveraudit"
  resource_group_name = "${var.resourcegroup}"
 
  template_body = <<DEPLOY
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location":{
      "type":"string"
    },
    "sqlserver":{
      "type":"string"
    },
    "securitytorageaccount":{
      "type":"string"
    }
  },
  "resources":[
    {
      "apiVersion": "2017-03-01-preview",
      "type": "Microsoft.Sql/servers/auditingSettings",
      "name": "[concat(parameters('sqlserver'),'/SQLServerAudit')]",
      "location": "[parameters('location')]",
      "properties": {
        "State": "Enabled",
        "storageEndpoint": "[concat('https://', parameters('securitytorageaccount'),'.blob.core.windows.net')]",
        "storageAccountAccessKey": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('securitytorageaccount')), providers('Microsoft.Storage', 'storageAccounts').apiVersions[0]).keys[0].value]",
        "retentionDays": 30,
        "auditActionsAndGroups": [ "DATABASE_ROLE_MEMBER_CHANGE_GROUP", "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP", "FAILED_DATABASE_AUTHENTICATION_GROUP", "DATABASE_OBJECT_PERMISSION_CHANGE_GROUP", "DATABASE_PERMISSION_CHANGE_GROUP", "SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP", "DATABASE_PRINCIPAL_IMPERSONATION_GROUP", "DATABASE_OBJECT_CHANGE_GROUP", "DATABASE_PRINCIPAL_CHANGE_GROUP", "SCHEMA_OBJECT_CHANGE_GROUP", "DATABASE_OPERATION_GROUP", "APPLICATION_ROLE_CHANGE_PASSWORD_GROUP", "DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP", "SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP" ],
        "storageAccountSubscriptionId": "[subscription().subscriptionId]",
        "isStorageSecondaryKeyInUse": false
      }
    }
  ]
}
DEPLOY
# these key-value pairs are passed into the ARM Template's `parameters` block
  parameters {
    "location" = "${var.location}"
    "sqlserver" = "${azurerm_sql_server.server.name}"
    "securitytorageaccount" = "${azurerm_storage_account.sqlsecuritysa.name}"
  }
  deployment_mode = "Incremental"
}
resource "azurerm_template_deployment" "vulnerabilityassessments" {
  name                = "vulnerabilityassessments"
  resource_group_name = "${var.resourcegroup}"
 
  template_body = <<DEPLOY
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location":{
      "type":"string"
    },
    "sqlserver":{
      "type":"string"
    },
    "securitytorageaccount":{
      "type":"string"
    },
    "emailAddresses":{
      "type":"string"
    }
  },
  "variables": {
    "emailAddresses": "[split(parameters('emailAddresses'),',')]"
  },
  "resources":[
    {
      "name": "[concat(parameters('sqlserver'),'/vulnerabilityAssessments')]",
      "type": "Microsoft.Sql/servers/vulnerabilityAssessments",
      "apiVersion": "2018-06-01-preview",
      "location": "[parameters('location')]",
      "properties": {
          "storageContainerPath": "[concat(reference(resourceId('Microsoft.Storage/storageAccounts', parameters('securitytorageaccount')), '2018-02-01').primaryEndpoints.blob, 'vulnerability-assessment')]",
          "storageAccountAccessKey": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('securitytorageaccount')), '2018-02-01').keys[0].value]",
          "recurringScans": {
              "isEnabled": true,
              "emailSubscriptionAdmins": false,
              "emails": "[variables('emailAddresses')]"
          }
      }
    }
  ]
}
DEPLOY
# these key-value pairs are passed into the ARM Template's `parameters` block
  parameters {
    "location" = "${var.location}"
    "sqlserver" = "${azurerm_sql_server.server.name}"
    "securitytorageaccount" = "${azurerm_storage_account.sqlsecuritysa.name}"
    "emailAddresses" = "you@yourdomain.com"
  }
  deployment_mode = "Incremental"
}
resource "azurerm_template_deployment" "advancedthreatprotection" {
  name                = "advancedthreatprotection"
  resource_group_name = "${var.resourcegroup}"
 
  template_body = <<DEPLOY
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location":{
      "type":"string"
    },
    "sqlserver":{
      "type":"string"
    },
    "securitytorageaccount":{
      "type":"string"
    },
    "emailAddresses": {
      "type": "string",
      "metadata": {
          "description": "Email addresses to receive alerts and scan reports"
      }
    }
  },
  "variables": {
    "emailAddresses": "[split(parameters('emailAddresses'),',')]"
  },
  "resources":[
    {
      "apiVersion": "2017-03-01-preview",
      "type": "Microsoft.Sql/servers/securityAlertPolicies",
      "name": "[concat(parameters('sqlserver'),'/AdvancedThreatProtection')]",
      "properties": {
          "state": "Enabled",
          "emailAddresses": "[variables('emailAddresses')]",
          "emailAccountAdmins": false,
          "retentionDays": 30
      }
    }
  ]
}
DEPLOY
# these key-value pairs are passed into the ARM Template's `parameters` block
  parameters {
    "location" = "${var.location}"
    "sqlserver" = "${azurerm_sql_server.server.name}"
    "emailAddresses" = "you@yourdomain.com"
    "securitytorageaccount" = "${azurerm_storage_account.sqlsecuritysa.name}"
  }
  deployment_mode = "Incremental"
}

resource "azurerm_sql_active_directory_administrator" "activedirectoryadmin" {
  server_name         = "${azurerm_sql_server.server.name}"
  resource_group_name = "${var.resourcegroup}"
  login               = "yourlogin"
  tenant_id           = "${var.tenantid}"
  object_id           = "yoursid"
}
output "sqlserver" {
  value = "${azurerm_sql_server.server.name}"
}
output "sqlserveraudit" {
  value = "${azurerm_template_deployment.sqlserveraudit.name}"
}
output "sqlserveradminpassword" {
  sensitive = true
  value = "${data.azurerm_key_vault_secret.SQLPaaSAdmin.value}"
}
output "sqlserveradmin" {
  value = "${data.azurerm_key_vault_secret.SQLPaaSAdmin.name}"
}
output "sqlserverva" {
  value = "${azurerm_template_deployment.vulnerabilityassessments.name}"
}

output "sqlserveratp" {
  value = "${azurerm_template_deployment.advancedthreatprotection.name}"
}

output "sqlsecuritysa" {
  value = "${azurerm_storage_account.sqlsecuritysa.name}"
}
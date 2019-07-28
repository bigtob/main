variable "resourcegroup" {}
variable "location" {}
variable "sqlserver" {}
variable "sqldb" {}
variable "edition" {}
variable "maxsizegb" {}
variable "dtu" {}
variable "adminpassword" {}
variable "admin" {}
variable "sqlsecuritysa" {}

variable scriptfile {
  description = "SQL Script file name to seed the database. Example: db-init.sql."
  default     = "db-init.sql"
}

variable logfile {
  description = "Log file name to create with the seeding results."
  default     = "db-init.log"
}
variable "sqlserveraudit" {}
variable "sqlserveratp" {}
variable "sqlserverva" {}

locals {
  fqdn = "${var.sqlserver}.database.windows.net"
}
resource "azurerm_sql_database" "sqldb" {
  name                             = "${var.sqldb}"
  resource_group_name              = "${var.resourcegroup}"
  location                         = "${var.location}"
  edition                          = "${var.edition}"
  collation                        = "SQL_Latin1_General_CP1_CI_AS"
  create_mode                      = "Default"
  requested_service_objective_name = "${var.dtu}"
  max_size_bytes                   = "${var.maxsizegb*1024*1024*1024}"
  server_name                      = "${var.sqlserver}"
  tags {
    security  = "${var.sqlserveraudit},${var.sqlserverva},${var.sqlserveratp}"
  }
  # Password                         = "${var.SQLAdmin_Password}"
  # init_script_file                 = "${var.init_script_file}"
  # log_file                         = "${var.log_file}"
  #provisioner "local-exec" {
  #  command = "sqlcmd -U ${var.admin} -P ${var.adminpassword} -S ${local.fqdn} -d ${azurerm_sql_database.sqldb.name} -i ${var.scriptfile} -o ${var.logfile}"
  #}
}

resource "azurerm_template_deployment" "recurringatpdbscan" {
  name                = "recurringatpdbscan"
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
    "sqldb":{
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
      "name": "[concat(parameters('sqlserver'),'/',parameters('sqldb'),'/AdvancedThreatProtection')]",
      "type": "Microsoft.Sql/servers/databases/vulnerabilityAssessments",
      "apiVersion": "2017-03-01-preview",
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
    "sqlserver" = "${var.sqlserver}"
    "securitytorageaccount" = "${var.sqlsecuritysa}"
    "emailAddresses" = "you@yourdomain.com"
    "sqldb" = "${azurerm_sql_database.sqldb.name}"
  }
  deployment_mode = "Incremental"
}
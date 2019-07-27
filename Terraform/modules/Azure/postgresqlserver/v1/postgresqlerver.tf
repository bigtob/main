variable "resourcegroup" {}
variable "location" {}
variable "postgresqlserver" {}
variable "env" {}
variable "application" {}
variable "tenantid" {}
variable "skutier" {}
variable "skucapacity" {}
variable "skufamily" {
  default = "Gen5"
}
variable "skusizegb" {}

variable "skunamep1" {
    description = "1st part of the sku name. Depends on sku skutier"
    type = "map"
    default = {
      "Basic" = "B"
      "GeneralPurpose" = "GP"
      "MemoryOptimized" = "MO"
    }
}

variable "backupretentiondays" {}
variable "georedundantbackup" {}
 
# # Configure the Microsoft Azure Provider
# provider "azurerm" {
#   #   client_id = "8a56aa9e-7ee9-46d5-9056-870c75a63e14",
#   #   client_secret = "q[7xNd&{ZMvLv3NNjn{-C!Y;iD8y5/#QvqNaUjmO/Q;",
# 	# subscription_id = "00783c89-ab88-46a8-bad6-7d02a57e054d"
#   #   tenant_id       = "a844252d-81e3-44c9-9291-fbc15d1218b5"
# }
 
# resource "azurerm_resource_group" "rg" {
#   name     = "${var.resource_group}"
#   location = "${var.location}"
# }

# Retrieve the postgresql admin secret
/* data "azurerm_key_vault_secret" "PostgreSQLAdmin" {
  name          = "PostgreSQLAdmin"
  vault_uri     = "https://ssebuildcreds.vault.azure.net/"
  #key_vault_id  = "/subscriptions/021c7ade-8661-49bd-b368-16cb17fdad24/resourceGroups/RG-CLOUDBUILD-PRD-001/providers/Microsoft.KeyVault/vaults/SSEBuildCreds"
} */
module "getsqliaasadminsecret" {
    source          = "../../getkeyvaultsecret/v1"
    secretname      = ["PostgreSQLAdmin"]
}
resource "azurerm_postgresql_server" "server" {
  name                         = "${lower(var.postgresqlserver)}"
  resource_group_name          = "${var.resourcegroup}"
  location                     = "${var.location}"
  version                      = "10.0"
  administrator_login          = "${element(module.getsqliaasadminsecret.secretname,0)}"
  administrator_login_password = "${element(module.getsqliaasadminsecret.secretvalue,0)}"
  ssl_enforcement              = "Enabled"
  sku {
    name       = "${lookup(var.skunamep1, var.skutier)}_${var.skufamily}_${var.skucapacity}"
    capacity   = "${var.skucapacity}"
    tier       = "${var.skutier}"
    family     = "${var.skufamily}"
  }
  storage_profile {
    storage_mb            = "${var.skusizegb * 1024}"
    backup_retention_days = "${var.backupretentiondays}"
    geo_redundant_backup  = "${var.georedundantbackup}"
  }
}

output "postgresqlserver" {
  value = "${azurerm_postgresql_server.server.name}"
}
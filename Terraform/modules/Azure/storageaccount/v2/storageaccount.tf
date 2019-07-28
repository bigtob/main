variable "application" {}
variable "env" {}
variable "stgacctpurpose" {}
variable "resourcegroup" {}
variable "location" {}
variable "salocation" {
    description = "Location for the storage account used for SQL Server backups"
    type = "map"
    default = {
        "UK South" = "UK West"
        "UK West" = "UK South"
        "North Europe" = "UK South"
    }
}
variable "satype" { 
    description = "Type of replication for storage account. GRS or LRS"
    type = "map"
    default = {
        "DEV" = "LRS"
        "TST" = "LRS"
        "UAT" = "LRS"
        "PRE" = "RAGRS"
        "PRD" = "RAGRS"
    }
}
resource "azurerm_storage_account" "stgacct" {
  name                     = "${lower(var.application)}${lower(var.env)}${lower(var.stgacctpurpose)}"
  resource_group_name      = "${var.resourcegroup}"
  location                 = "${lookup(var.salocation, var.location, "UK West")}"
  account_tier             = "Standard"
  account_replication_type = "${lookup(var.satype, var.env, "LRS")}"
}

output "stgacctname" {
  value = "${azurerm_storage_account.stgacct.name}"
}

output "stgacctprimaryblobendpoint" {
  value = "${azurerm_storage_account.stgacct.primary_blob_endpoint}"
}

output "stgacctprimaryconnectionstring" {
  value = "${azurerm_storage_account.stgacct.primary_connection_string}"
}
output "stgacctprimaryaccesskey" {
  value = "${azurerm_storage_account.stgacct.primary_access_key}"
}

output "stgacctprimaryfileserviceendpoint" {
  value = "${azurerm_storage_account.stgacct.primary_file_endpoint}"
}
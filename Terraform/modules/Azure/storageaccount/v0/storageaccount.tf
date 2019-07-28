variable "stgname" {}
variable "rsgname" {}
variable "location" {}
variable "stgtier" {}
variable "stgreplicationtype" {}
variable "stgaccountkind" {}

resource "azurerm_storage_account" "stgacct" {
  name                     = "${var.stgname}"
  resource_group_name      = "${var.rsgname}"
  location                 = "${var.location}"
  account_tier             = "${var.stgtier}"
  account_replication_type = "${var.stgreplicationtype}"
  account_kind             = "${var.stgaccountkind}"
}

output "stgacctname" {
  value = "${azurerm_storage_account.stgacct.name}"
}

output "stgacctprimaryblobendpoint" {
  value = "${azurerm_storage_account.stgacct.primary_blob_endpoint}"
}

output "stgacctprimaryaccesskey" {
  value = "${azurerm_storage_account.stgacct.primary_access_key}"
}
variable "resourcegroup" {}
variable "name" {}
variable "stgacctname" {}
variable "connectionstring" {}

    
resource "azurerm_storage_share" "backupshare" {
  name                  = "${var.name}"
  resource_group_name   = "${var.resourcegroup}"
  storage_account_name  = "${var.stgacctname}"
}

output "stgacctsharename" {
  value = "${azurerm_storage_share.backupshare.name}"
} 

variable "resourcegroup" {}
variable "location" {}
variable "name" {}
#variable "avsetcount" {}


resource "azurerm_availability_set" "availset" {
  name                        = "${var.name}"
  location                    = "${var.location}"
  resource_group_name         = "${var.resourcegroup}"
  managed                     = "True"
  platform_fault_domain_count = "2"
  #count                       = "${var.avsetcount}"
}
output "availsetid" {
  value = "${azurerm_availability_set.availset.id}"
}

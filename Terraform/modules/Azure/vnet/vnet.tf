data "azurerm_virtual_network" "vnet" {
  name                 = "${var.vnet_name}"
  resource_group_name  = "${var.resourcegroup}"
}
output "virtual_network_id" {
  value = "${data.azurerm_virtual_network.vnet.id}"
}
output "vnetname" {
  value = "${data.azurerm_virtual_network.vnet.name}"
}

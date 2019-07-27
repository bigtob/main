variable "hostname" {}
variable "location" {}
variable "resourcegroup" {}
variable "subnetname" {}
#variable "count" {}
resource "azurerm_network_interface" "networkinterface" {
    name                              = "${var.hostname}-NIC-01"
    #name                              = "${var.hostname}-NIC-0${count.index + 1}"
    #count                             = "${var.count}"
    location                          = "${var.location}"
    resource_group_name               = "${var.resourcegroup}"
    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = "${var.subnetname}"
        private_ip_address_allocation = "Dynamic"
        primary                       = true
    }
    ip_configuration {
        name                          = "ipconfig2"
        subnet_id                     = "${var.subnetname}"
        private_ip_address_allocation = "Dynamic"
    }
}
output "networkinterface" {
  #value = "${azurerm_network_interface.linuxnetworkinterface.*.id}"
  value = "${azurerm_network_interface.networkinterface.id}"
}
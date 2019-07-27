variable "hostname" {}
variable "location" {}
variable "resourcegroup" {}
variable "subnetname" {}
resource "azurerm_network_interface" "networkinterface" {
    name                              = "${var.hostname}-NIC-01"
    location                          = "${var.location}"
    resource_group_name               = "${var.resourcegroup}"
    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = "${var.subnetname}"
        private_ip_address_allocation = "Dynamic"
    }
}
output "networkinterface" {
    value = "${azurerm_network_interface.networkinterface.id}"
}

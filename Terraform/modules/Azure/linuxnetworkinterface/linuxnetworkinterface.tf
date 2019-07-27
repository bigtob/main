variable "location" {}
variable "resourcegroup" {}
variable "subnetname" {}
variable "hostname" {}
variable "linuxvmcount" {}

# Create network interface for app server
resource "azurerm_network_interface" "networkinterface" {
    name                      = "${var.hostname}-NIC-01"
    location                  = "${var.location}"
    resource_group_name       = "${var.resourcegroup}"
	count                     = "${var.linuxvmcount}"
    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = "${var.subnetname}"
        private_ip_address_allocation = "Dynamic"
    }
}
output "linuxvmnic" {
  value = ["${azurerm_network_interface.networkinterface.*.id}"]  
  }

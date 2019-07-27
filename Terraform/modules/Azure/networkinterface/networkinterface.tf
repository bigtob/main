variable "location" {}
variable "resourcegroup" {}
variable "subnetref" {}
variable "hostname" {}
variable "serverseed" {}
variable "winvmcount" {}

# Create network interface for app server
resource "azurerm_network_interface" "networkinterface" {
    name                      = "${var.hostname}${var.serverseed + count.index}-NIC-01"
    location                  = "${var.location}"
    resource_group_name       = "${var.resourcegroup}"
	count                     = "${var.winvmcount}"
    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = "${var.subnetref}"
        private_ip_address_allocation = "Dynamic"
        #private_ip_address            = "${var.appipaddress}"
    }
}
output "winvmnic" {
  value = ["${azurerm_network_interface.networkinterface.*.id}"]  
  }

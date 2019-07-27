# Create the NSG for a subnet/NIC
# This should be suitably hardened!
variable "resourcegroup" {}
variable "location" {}
variable "project" {}
variable "env" {}
#variable "count" {}
variable "nsgname" {}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.nsgname}"
  location            = "${var.location}"
  resource_group_name = "${var.resourcegroup}"
  #count               = "${var.count}"

  security_rule {
    name                       = "in-RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

#  tags {
#    environment = "${var.environment}"
#  }
#  depends_on = ["azurerm_resource_group.azu-rg"]
#
}

output "nsgid" {
  value = "${azurerm_network_security_group.nsg.id}"
}

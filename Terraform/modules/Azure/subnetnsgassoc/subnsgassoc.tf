variable "subnetref" {}
variable "nsgref" {}
#variable "count" {}

resource "azurerm_subnet_network_security_group_association" "subnsgass" {
  subnet_id                 = "${var.subnetref}"
  network_security_group_id = "${var.nsgref}"
}
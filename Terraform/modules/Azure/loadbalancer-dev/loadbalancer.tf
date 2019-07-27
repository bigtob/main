variable "location" {}
variable "resourcegroup" {}
variable "name" {}
variable "frontendsubnet" {}
variable "privateip" {}
variable "privateiptype" {}


#resource "azurerm_public_ip" "test" {
#  name                         = "PublicIPForLB"
#  location                     = "${var.location}"
#  resource_group_name          = "${var.resource_group}"
#  public_ip_address_allocation = "static"
#}

resource "azurerm_lb" "lb" {
  name                = "${var.name}"
  location            = "${var.location}"
  resource_group_name = "${var.resourcegroup}"

  frontend_ip_configuration {
    name                          = "FrontendIPConfiguration"
    subnet_id                     = "${var.frontendsubnet}"
    private_ip_address            = "${var.privateip}"
    private_ip_address_allocation = "${var.privateiptype}"
  }
}

output "loadbalancerid" {
  value = "${azurerm_lb.lb.id}"
}
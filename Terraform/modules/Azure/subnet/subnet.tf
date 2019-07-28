// NOTE: in a Production Environment you're likely to have Network Security Rules
// which lock down traffic between Subnets. These are omitted below to keep the
// examples easy to understand - and should be added before being used in Production.

variable "resourcegroup" {}
variable "subnetname" {}
variable "virtualnetwork" {}
variable "subnetrange" {}
#variable "count" {}

#variable "service_endpoints" { type ="list" }

resource "azurerm_subnet" "subnet" {
  name                      = "${var.subnetname}"
  resource_group_name       = "${var.resourcegroup}"
  virtual_network_name      = "${var.virtualnetwork}"
  address_prefix            = "${var.subnetrange}"
  #network_security_group_id = "${module.network.network_security_group_id.nsg.id}"
  #network_security_group_id = "${var.netsecgroupid}"
  #service_endpoints         = ["${var.service_endpoints}"]
}

output "subnetref" {
  value = "${azurerm_subnet.subnet.id}"
}


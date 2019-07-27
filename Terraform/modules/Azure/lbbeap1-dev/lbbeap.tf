variable "resourcegroup" {}
variable "loadbalancerid" {}
variable "backendaddresspoolname" {
  
}

resource "azurerm_lb_backend_address_pool" "lbbeap1" {
  resource_group_name = "${var.resourcegroup}"
  loadbalancer_id     = "${var.loadbalancerid}"
  name                = "${var.backendaddresspoolname}"
}

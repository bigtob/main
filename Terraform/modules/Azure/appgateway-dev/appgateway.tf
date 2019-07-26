variable "location" {}
variable "rsgname" {}
variable "name" {}
variable "subnetref" {}
variable "vnetref" {}


# Create a application gateway
resource "azurerm_public_ip" "pip" {
  name                         = "my-pip-12345"
  location                     = "${var.location}"
  resource_group_name          = "${var.rsgname}"
  public_ip_address_allocation = "dynamic"
}

# Create an application gateway
resource "azurerm_application_gateway" "appgw" {
  name                   = "${var.name}"
  resource_group_name    = "${var.rsgname}"
  location               = "${var.location}"

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    #subnet_id = "${azurerm_virtual_network.vnet.id}/subnets/${azurerm_subnet.sub1.name}"
    subnet_id = "${var.subnetref}"
  }

  frontend_port {
    name = "${var.name}-feport"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${var.name}-feip"
    public_ip_address_id = "${azurerm_public_ip.pip.id}"
  }

  backend_address_pool {
    name = "${var.name}-beap"
  }

  backend_http_settings {
    name                  = "${var.name}-be-htst"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = "${var.name}-httplstn"
    frontend_ip_configuration_name = "${var.name}-feip"
    frontend_port_name             = "${var.name}-feport"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${var.name}-rqrt"
    rule_type                  = "Basic"
    http_listener_name         = "${var.name}-httplstn"
    backend_address_pool_name  = "${var.name}-beap"
    backend_http_settings_name = "${var.name}-be-htst"
  }

  // Path-based routing example
  http_listener {
    name                           = "${var.name}-httplstn-pbr.contoso.com"
    host_name                      = "pbr.contoso.com"
    frontend_ip_configuration_name = "${var.name}-feip"
    frontend_port_name             = "${var.name}-feport"
    protocol                       = "Http"
  }

  backend_address_pool {
    name = "${var.name}-beap-fallback"
  }

  backend_address_pool {
    name = "${var.name}-beap-first"
  }

  backend_address_pool {
    name = "${var.name}-beap-second"
  }

  request_routing_rule {
    name               = "${var.name}-rqrt2"
    rule_type          = "PathBasedRouting"
    http_listener_name = "${var.name}-httplstn-pbr.contoso.com"
    url_path_map_name  = "pbr.contoso.com"
  }

  #url_path_map {
  #  name                               = "pbr.contoso.com"
  #  default_backend_address_pool_name  = "${var.name}-beap-fallback"
  #  default_backend_http_settings_name = "${var.name}-be-htst"

    #path_rule {
    #  name                       = "pbr.contoso.com_first"
    #  paths                      = ["/first/*"]
    #  backend_address_pool_name  = "${local.awg_clusters_name}-beap-first"
    #  backend_http_settings_name = "${local.awg_clusters_name}-be-htst"
    #}

    /*path_rule {
      name                       = "pbr.contoso.com_second"
      paths                      = ["/second/*"]
      backend_address_pool_name  = "${local.awg_clusters_name}-beap-second"
      backend_http_settings_name = "${local.awg_clusters_name}-be-htst"
    }*/
  
}

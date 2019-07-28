#---------------------------------------------------------------------------------------
# Configure the Microsoft Azure Provider
#---------------------------------------------------------------------------------------
provider "azurerm" {
    subscription_id = "${var.subscriptionid}"
    tenant_id       = "${var.tenantid}"
    client_id       = "${var.clientid}"
    client_secret   = "${var.clientsecret}"
    use_msi         = "true"
}
#---------------------------------------------------------------------------------------
# Call for module to build Resource Group
#---------------------------------------------------------------------------------------
module "resourcegroup" {
    source          = "../../../_Common/Terraform/modules/resourcegroup"
    rsgname         = "${var.service}-${var.env}-AGW-${var.versionno}-${var.instanceno}-rg"
    location        = "${var.location}"
    directorate     = "${var.directorate}"
    subdirectorate  = "${var.subdirectorate}"
    costcentre      = "${var.costcentre}"
    projectcode     = "${var.projectcode}"
    irnumber        = "${var.irnumber}"
    supportteam1    = "${var.supportteam1}"
    supportteam2    = "${var.supportteam2}"
    servicehours    = "${var.servicehours}"
    lifecyclestatus = "${var.lifecyclestatus}"
}
#---------------------------------------------------------------------------------------
# Create subnet for Application Gateway
#---------------------------------------------------------------------------------------
resource "azurerm_subnet" "subnet" {
    name = "yoursubnetname"
    resource_group_name  = "yourrsgname"
    virtual_network_name = "${var.vnetname}"
    address_prefix       = "10.x.x.x/28"
}
#---------------------------------------------------------------------------------------
# Create Public IP Address
#---------------------------------------------------------------------------------------
resource "azurerm_public_ip" "appgwpip" {
  name                = "yourpipname"
  location            = "${var.location}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  allocation_method   = "static"
}
#---------------------------------------------------------------------------------------
# Create Application Gateway
#---------------------------------------------------------------------------------------
resource "azurerm_application_gateway" "appgw" {
  name                = "yourappgwname"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  location            = "${var.location}"
  depends_on          = ["azurerm_public_ip.appgwpip"]

  sku { 
    name     = "WAF_Medium"
    tier     = "WAF"
    capacity = "2"
  }

  waf_configuration { 
    enabled          = true
    firewall_mode    = "Detection"
    rule_set_type    = "OWASP"
    rule_set_version = "3.0"
  }

  gateway_ip_configuration {
    name      = "configuration1"
    subnet_id = "${azurerm_subnet.subnet.id}"
  }

  frontend_port {
    name = "https"
    port = 443
  }

  frontend_ip_configuration { 
    name                 = "appGatewayFrontendIP"
    public_ip_address_id = "${azurerm_public_ip.appgwpip.id}"
  }

  backend_address_pool {
    name  = "backend1"
    fqdns = ["yourhost1.domain1"]
  }

  backend_address_pool {
    name  = "backend2"
    fqdns = ["yourhost2.domain1"]
  }

  backend_address_pool {
    name  = "backend3"
    fqdns = ["yourhost3.domain1","yourhost4.domain1"]
  }

  ssl_certificate {
    name     = "yourpfxcertname"
    data     = "${base64encode(file("./certs/???.pfx"))}"
    password = "${data.azurerm_key_vault_secret.certificate-password.value}"
  }

  http_listener {
    name                           = "yourlistener1"
    frontend_ip_configuration_name = "frontend1"
    frontend_port_name             = "https"
    protocol                       = "Https"
    require_sni                    = true
    host_name                      = "yourhost1.com"
    ssl_certificate_name           = "yourpfxcertname"
  }

  http_listener {
    name                           = "yourlistener1"
    frontend_ip_configuration_name = "frontend2"
    frontend_port_name             = "https"
    protocol                       = "Https"
    require_sni                    = true
    host_name                      = "yourhost2.com"
    ssl_certificate_name           = "yourpfxcertname"
  }

  http_listener {
    name                           = "yourlistener1"
    frontend_ip_configuration_name = "frontend3"
    frontend_port_name             = "https"
    protocol                       = "Https"
    require_sni                    = true
    host_name                      = "yourhost3.com"
    ssl_certificate_name           = "yourpfxcertname"
  }

  probe {
    name                = "yourprobe1"
    protocol            = "https"
    path                = "/somepath"
    host                = "yourhost1.domain1"
    interval            = "30"
    timeout             = "30"
    unhealthy_threshold = "3"
    match {
        status_codes = ["200-399"]
    }
  }

  probe {
    name                = "yourprobe2"
    protocol            = "https"
    path                = "/somepath"
    host                = "yourhost2.domain1"
    interval            = "30"
    timeout             = "30"
    unhealthy_threshold = "3"
    match {
        status_codes = ["200-399"]
    }
  }

  probe {
    name                = "yourprobe3"
    protocol            = "https"
    path                = "/"
    host                = "127.0.0.1"
    interval            = "30"
    timeout             = "30"
    unhealthy_threshold = "3"
    match {
        status_codes = ["200-399"]
    }
  }
  
  authentication_certificate {
    name = "Gateway-CER-Cert1"
    data = "${base64encode(file("./certs/???.cer"))}"
  }

  authentication_certificate {
    name = "Gateway-CER-Cert2"
    data = "${base64encode(file("./certs/???.cer"))}"
  }

  authentication_certificate {
    name = "Gateway-CER-Cert3"
    data = "${base64encode(file("./certs/???.cer"))}"
  }

  backend_http_settings {
    name                  = "backendname1"
    cookie_based_affinity = "Enabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    probe_name            = "yourprobe1"
    authentication_certificate {
      name = "Gateway-CER-Cert1"
    }
  }

  backend_http_settings {
    name                  = "backendname2"
    cookie_based_affinity = "Enabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    probe_name            = "yourprobe2"
    authentication_certificate {
      name = "Gateway-CER-Cert2"
    }
  }

  backend_http_settings {
    name                  = "backendname3"
    cookie_based_affinity = "Enabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    probe_name            = "yourprobe3"
    authentication_certificate {
      name = "Gateway-CER-Cert3"
    }
  }

  request_routing_rule { 
    name                       = "yourrule1"
    rule_type                  = "Basic"
    http_listener_name         = "yourlistener1"
    backend_address_pool_name  = "backend1"
    backend_http_settings_name = "backendname1"
  }
  
  request_routing_rule { 
    name                       = "yourrule2"
    rule_type                  = "Basic"
    http_listener_name         = "yourlistener2"
    backend_address_pool_name  = "backend2"
    backend_http_settings_name = "backendname2"
  }

  request_routing_rule { 
    name                       = "yourrule3"
    rule_type                  = "Basic"
    http_listener_name         = "yourlistener3"
    backend_address_pool_name  = "backend3"
    backend_http_settings_name = "backendname3"
  }
}

variable "location" {}
variable "resourcegroup" {}
variable "project" {}
variable "instanceno" {}
variable "env" {}
variable "environment" {}
variable "serverseed" {}
variable "hostname" {}
variable "frontendsubnet" {}


resource "azurerm_lb" "lb" {
  name                = "lb"
  location            = "${var.location}"
  resource_group_name = "${var.resourcegroup}"

  frontend_ip_configuration {
    name                          = "FrontendIPConfiguration"
    subnet_id                     = "${var.frontendsubnet}"
    private_ip_address            = "yourip"
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = "${var.resourcegroup}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  count                          = 3
  resource_group_name            = "${var.resourcegroup}"
  name                           = "ssh"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "FrontendIPConfiguration"
}



#resource "azurerm_lb_probe" "lbprobe" {
#  resource_group_name = "${var.resourcegroup}"
#  loadbalancer_id     = "${azurerm_lb.lb.id}"
#  name                = "http-probe"
#  request_path        = ""
#  port                = 80
#}
resource "azurerm_virtual_machine_scale_set" "winvmscaleset" {
  name                = "${var.project}-${var.env}-${var.instanceno}"
  location            = "${var.location}"
  resource_group_name = "${var.resourcegroup}"

  # automatic rolling upgrade
  automatic_os_upgrade = true
  upgrade_policy_mode  = "Rolling"
  rolling_upgrade_policy {
    max_batch_instance_percent              = 20
    max_unhealthy_instance_percent          = 20
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches              = "PT0S"
  }

  # required when using rolling upgrade policy
  #health_probe_id = "${azurerm_lb_probe.lbprobe.id}"

  sku {
    name     = "Standard_D2s_v3"
    tier     = "Standard"
    capacity = 4
  }

  storage_profile_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-DataCenter"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "testvm"
    admin_username       = "admin"
    admin_password       = "password"
  }

    network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = "${var.frontendsubnet}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
      load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.lbnatpool.*.id, count.index)}"]
    }
  }
}

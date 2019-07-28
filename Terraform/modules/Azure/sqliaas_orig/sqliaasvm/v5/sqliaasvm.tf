variable "location" {}
variable "vmcount" {}
variable "serverseed" {}
variable "hostname" {}
variable "resourcegroup" {}
variable "asid" {}
variable "offer" {}
variable "sku" {}
variable "env" {}
variable "application" {}
variable "datadisksize" {}
variable "vmsize" {}
variable "subnetname" {}
variable "virtualnetworkname" {}
variable "networkrgname" {}
# Maps
variable "disktype" {
    description = "Type of storage to use for the managed data and logs disks"
    type = "map"
    default = {
        "DEV" = "Standard_LRS"
        "TST" = "Standard_LRS"
        "UAT" = "Standard_LRS"
        "PRE" = "Premium_LRS"
        "PRD" = "Premium_LRS"
    }
}
variable "logdisksize" {
    description = "1st value is data disk size, 2nd value is resultant log disk size"
    type = "map"
    default = {
        "32" = "32"
        "64" = "32"
        "128" = "32"
        "256" = "32"
        "512" = "64"
        "1024" = "128"
        "2048" = "256"
        "4096" = "512"
    }
}

module "getsqliaasadminsecret" {
    source          = "../../../getkeyvaultsecret/v1"
    secretname      = ["SQLIaaSAdmin"]
}
data "azurerm_subnet" "subnetid" {
  name                 = "${var.subnetname}"
  virtual_network_name = "${var.virtualnetworkname}"
  resource_group_name  = "${var.networkrgname}"
}

resource "azurerm_network_interface" "networkinterfacestatic" {
  name                      = "${format("${var.hostname}%06d", var.serverseed + count.index)}-NIC-01"
  location                  = "${var.location}"
  resource_group_name       = "${var.resourcegroup}"
	count                     = "${var.vmcount}"
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${data.azurerm_subnet.subnetid.id}"
     private_ip_address_allocation = "Static"
     private_ip_address           = "${cidrhost(data.azurerm_subnet.subnetid.address_prefix, count.index + 4)}"
  }
}

resource "azurerm_virtual_machine" "sqlvm" {
  count                 = "${var.vmcount}"
  name                  = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
  location              = "${var.location}"
  resource_group_name   = "${var.resourcegroup}"
  network_interface_ids = ["${element(azurerm_network_interface.networkinterfacestatic.*.id, count.index)}"]
  vm_size               = "${var.vmsize}"
  availability_set_id   = "${var.asid}"

  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_os_disk_on_termination = true

  # This means the Data Disk Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher           = "MicrosoftSQLServer"
    offer               = "${var.offer}"
    sku                 = "${var.sku}"
    version             = "latest"
  }

  storage_os_disk {
    name                = "${format("${var.hostname}%06d", var.serverseed + count.index)}-OS"
    caching             = "ReadWrite"
    create_option       = "FromImage"
    managed_disk_type   = "${lookup(var.disktype,var.env,"Standard_LRS")}"
  }

  storage_data_disk {
    name                = "${format("${var.hostname}%06d", var.serverseed + count.index)}-SQL-Data"
    caching             = "ReadOnly"
    create_option       = "Empty"
    disk_size_gb        = "${var.datadisksize}"
    lun                 = "0"
    managed_disk_type   = "${lookup(var.disktype,var.env,"Standard_LRS")}"
  }

  storage_data_disk {
    name                = "${format("${var.hostname}%06d", var.serverseed + count.index)}-SQL-Logs"
    caching             = "None"
    create_option       = "Empty"
    disk_size_gb        = "${lookup(var.logdisksize, var.datadisksize)}"
    lun                 = "1"
    managed_disk_type   = "${lookup(var.disktype,var.env,"Standard_LRS")}"
  }

  os_profile {
    computer_name       = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
    admin_username      = "${element(module.getsqliaasadminsecret.secretname,0)}"
    admin_password      = "${element(module.getsqliaasadminsecret.secretvalue,0)}"
  }

  os_profile_windows_config {
    enable_automatic_upgrades   = true
    provision_vm_agent          = true
    timezone                    = "GMT Standard Time"
  }

}

output "vmnamelist" {
    value = ["${azurerm_virtual_machine.sqlvm.*.name}"]
}

output "vmnamestr" {
  value = "${join(",", azurerm_virtual_machine.sqlvm.*.name)}"
}

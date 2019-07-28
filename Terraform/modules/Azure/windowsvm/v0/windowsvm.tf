# Declare variables
variable "location" {}
variable "resourcegroup" {}
variable "hostname" {}
variable "winvmcount" {}
variable "vmsize" {}
variable "testing" {}
variable "env" {}
variable "subnetname" {}

# Retrieve host number
module "hostnumber" {
    source    = "../hostnumber/v1"
    testing   = "${var.testing}"
    increment = "${var.linuxvmcount}"
}

# Create NIC
resource "azurerm_network_interface" "networkinterfacedynamic" {
    name                = "${format("AZUW${upper(var.env)}%06d", count.index + module.hostnumber.number)}-NIC-01"
    location            = "${var.location}"
    resource_group_name = "${var.resourcegroup}"
	count               = "${var.linuxvmcount}"
    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = "${var.subnetname}"
        private_ip_address_allocation = "Dynamic"
    }
}
resource "azurerm_network_interface" "networkinterfacestatic" {
    name                = "${format("AZUW${upper(var.env)}%06d", count.index + module.hostnumber.number)}-NIC-01"
    location            = "${var.location}"
    resource_group_name = "${var.resourcegroup}"
    count               = "${var.linuxvmcount}"
    ip_configuration {
        name                          = "ipconfig1"
        subnet_id                     = "${var.subnetname}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "${element(azurerm_network_interface.networkinterfacedynamic.*.private_ip_address,count.index)}"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "winvm" {
    name                             = "${format("AZUW${upper(var.env)}%06d", count.index + module.hostnumber.number)}-Disk-00"
    location                         = "${var.location}"
    resource_group_name              = "${var.resourcegroup}"
    count                            = "${var.winvmcount}"
    network_interface_ids            = ["${element(azurerm_network_interface.networkinterfacestatic.*.id, count.index)}"]
    vm_size                          = "${var.vmsize}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "${format("AZUW${upper(var.env)}%06d", count.index + module.hostnumber.number)}-Disk-00"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2016-Datacenter"
        version   = "latest"
    }

    os_profile {
        computer_name  = "${format("AZUW${upper(var.env)}%06d", count.index + module.hostnumber.number)}"
        admin_username = "admin"
        admin_password = "password"
    }

    os_profile_windows_config {
        provision_vm_agent        = true
	    enable_automatic_upgrades = true
    }
}
output "virtualmachineid" {
    value = "${azurerm_virtual_machine.winvm.*.id}"
}
output "vmname" {
  value = "${azurerm_virtual_machine.winvm.*.name}"
}
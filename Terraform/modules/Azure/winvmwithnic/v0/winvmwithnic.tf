variable "winvmcount" {}
variable "location" {}
variable "resourcegroup" {}
variable "hostname" {}
variable "subnetref" {}
variable "serverseed" {}
variable "winvmsizelist" { type = "list"}
variable "env" {}
variable "winvmdisklist" { type = "list"}
variable "stgtier" {}
variable "availset" {}


# Create virtual machines
module "networkinterface" {
    source              = "../networkinterface"
    location            = "${var.location}"
    resourcegroup       = "${var.resourcegroup}"
    subnetref           = "${var.subnetref}"
    hostname            = "AZUW${var.env}0000"
    serverseed          = "${var.serverseed}"
    winvmcount          = "${var.winvmcount}"
}

resource "azurerm_virtual_machine" "winvm" {
    name                  = "${var.hostname}${var.serverseed + count.index}"
    location              = "${var.location}"
    resource_group_name   = "${var.resourcegroup}"
    network_interface_ids = ["${element(module.networkinterface.winvmnic, count.index)}"]
    vm_size               = "${element(var.winvmsizelist, count.index)}"
	count                 = "${var.winvmcount}"
    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true
    availability_set_id   = "${var.availset}"

    storage_os_disk {
        name              = "${var.hostname}${var.serverseed + count.index}-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_data_disk {
        name              = "${var.hostname}${var.serverseed + count.index}-Disk-01"
        caching           = "None"
        managed_disk_type = "${var.stgtier}"
        create_option     = "Empty"
        lun               = 0
        disk_size_gb      = "${element(var.winvmdisklist, count.index)}"
    }

    storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2016-Datacenter"
        version   = "latest"
    }

    os_profile {
        computer_name  = "${var.hostname}${var.serverseed + count.index}"
        admin_username = "admin"
        admin_password = "password"
    }

    os_profile_windows_config {
        provision_vm_agent        = true
		enable_automatic_upgrades = true
    }
}

output "vmname" {
  value = "${azurerm_virtual_machine.winvm.*.name}"
}

variable "winvmcount" {}
variable "location" {}
variable "resourcegroup" {}
variable "hostname" {}
variable "subnetref" {}
variable "serverseed" {}
variable "winvmsizelist" { type = "list"}
#variable "env" {}
#variable "datadisksize" { type = "list"}
#variable "stgtier" {}
variable "availset" {}
#variable "disktype" {}
variable "winvmsku" {}

data "azurerm_key_vault_secret" "windowsiaasadmin" {
  name      = "WindowsIaaSAdmin"
  vault_uri = "https://ssebuildcreds.vault.azure.net/"
}
resource "azurerm_network_interface" "networkinterfacedynamic" {
  #name                      = "${var.hostname}${var.serverseed + count.index}-NIC-01"
  name                      = "${format("${var.hostname}%06d", var.serverseed + count.index)}-NIC-01"
  location                  = "${var.location}"
  resource_group_name       = "${var.resourcegroup}"
	count                     = "${var.winvmcount}"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${var.subnetref}"
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_network_interface" "networkinterfacestatic" {
  #name                      = "${var.hostname}${var.serverseed + count.index}-NIC-01"
  name                      = "${format("${var.hostname}%06d", var.serverseed + count.index)}-NIC-01"
  location                  = "${var.location}"
  resource_group_name       = "${var.resourcegroup}"
  count                     = "${var.winvmcount}"
  #network_security_group_id = "${var.nsgref}"
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${var.subnetref}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "${element(azurerm_network_interface.networkinterfacedynamic.*.private_ip_address,count.index)}"
  }
}

resource "azurerm_virtual_machine" "winvm" {
    count                 = "${var.winvmcount}"
    #name                  = "${var.hostname}${var.serverseed + count.index}"
    name                      = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
    location              = "${var.location}"
    resource_group_name   = "${var.resourcegroup}"
    #network_interface_ids = ["${element(module.networkinterface.winvmnic, count.index)}"]
    network_interface_ids = ["${element(azurerm_network_interface.networkinterfacestatic.*.id, count.index)}"]
    vm_size               = "${element(var.winvmsizelist, count.index)}"
    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true
    availability_set_id   = "${var.availset}"

    # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_os_disk_on_termination = true

    # This means the Data  Disk will be deleted when Terraform destroys the Virtual Machine
    # NOTE: This may not be optimal in all cases.
    delete_data_disks_on_termination = true

    storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "${var.winvmsku}"
        version   = "latest"
    }

    storage_os_disk {
        #name              = "${var.hostname}${var.serverseed + count.index}-osdisk"
        name              = "${format("${var.hostname}%06d", var.serverseed + count.index)}-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    os_profile {
        computer_name       = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
        admin_username      = "${data.azurerm_key_vault_secret.windowsiaasadmin.name}"
        admin_password      = "${data.azurerm_key_vault_secret.windowsiaasadmin.value}"
    }

    os_profile_windows_config {
        provision_vm_agent        = true
		    enable_automatic_upgrades = true
    }
}


output "vmname" {
  value = "${azurerm_virtual_machine.winvm.*.name}"
}

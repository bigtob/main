# Modified from V2 by Toby.
# V3: Changed two disk configuration down to one (most common request).
#     Added winvmsku


variable "winvmcount" {}
variable "winvmsku" {}
variable "location" {}
variable "resourcegroup" {}
variable "hostname" {}
variable "subnetref" {}
variable "serverseed" {}
variable "winvmsize" {}
variable "env" {}
variable "datadisksize" {}
variable "stgtier" {}
variable "availset" {}
variable "disktype" {}

data "azurerm_key_vault_secret" "windowsiaasadmin" {
  name      = "WindowsIaaSAdmin"
  vault_uri = "https://yourvault.vault.azure.net/"
}
resource "azurerm_network_interface" "networkinterfacedynamic" {
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
  name                      = "${format("${var.hostname}%06d", var.serverseed + count.index)}-NIC-01"
  location                  = "${var.location}"
  resource_group_name       = "${var.resourcegroup}"
  count                     = "${var.winvmcount}"
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${var.subnetref}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "${element(azurerm_network_interface.networkinterfacedynamic.*.private_ip_address,count.index)}"
  }
}

resource "azurerm_virtual_machine" "winvm" {
    count                            = "${var.winvmcount}"
    name                             = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
    location                         = "${var.location}"
    resource_group_name              = "${var.resourcegroup}"
    network_interface_ids            = ["${element(azurerm_network_interface.networkinterfacestatic.*.id, count.index)}"]
    vm_size                          = "${var.winvmsize}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true
    availability_set_id              = "${var.availset}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "${var.winvmsku}"
        version   = "latest"
    }

    storage_os_disk {
        name              = "${format("${var.hostname}%06d", var.serverseed + count.index)}-Disk-00"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    os_profile {
        computer_name   = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
        admin_username  = "${data.azurerm_key_vault_secret.windowsiaasadmin.name}"
        admin_password  = "${data.azurerm_key_vault_secret.windowsiaasadmin.value}"
    }

    os_profile_windows_config {
        provision_vm_agent        = true
		    enable_automatic_upgrades = true
    }
}

resource "azurerm_managed_disk" "data1" {
  count                = "${var.winvmcount}"
  name                 = "${format("${var.hostname}%06d", var.serverseed + count.index)}-Disk-01"
  location             = "${var.location}"
  resource_group_name  = "${var.resourcegroup}"
  storage_account_type = "${var.disktype}"
  create_option        = "Empty"
  disk_size_gb         = "${var.datadisksize}"
}
resource "azurerm_virtual_machine_data_disk_attachment" "data1" {
  count                 = "${var.winvmcount}"
  managed_disk_id       = "${element(azurerm_managed_disk.data1.*.id, count.index)}"
  virtual_machine_id    = "${element(azurerm_virtual_machine.winvm.*.id, count.index)}"
  lun                   = "0"
  caching               = "None"
}
output "vmname" {
  value = "${azurerm_virtual_machine.winvm.*.name}"
}

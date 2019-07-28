variable "winvmcount" {}
variable "location" {}
variable "resourcegroup" {}
variable "hostname" {}
variable "subnetref" {}
variable "serverseed" {}
variable "winvmsizelist" { type = "list"}
variable "env" {}
variable "datadisksize" { type = "list"}
variable "stgtier" {}
variable "availset" {}
variable "disktype" {}

data "azurerm_key_vault_secret" "windowsiaasadmin" {
  name      = "WindowsIaaSAdmin"
  vault_uri = "https://yourvault.vault.azure.net/"
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
        sku       = "2016-Datacenter"
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

resource "azurerm_managed_disk" "data1" {
  count                = "${var.winvmcount}"
  name                 = "${format("${var.hostname}%06d", var.serverseed + count.index)}-Data1"
  #name                 = "${format("${var.hostname}%06d", module.hostnumber.number + count.index)}-Data1"
  location             = "${var.location}"
  resource_group_name  = "${var.resourcegroup}"
  storage_account_type = "${var.disktype}"
  create_option        = "Empty"
  disk_size_gb         = "${element(var.datadisksize, 0)}"
}

resource "azurerm_managed_disk" "data2" {
  count                = "${var.winvmcount}"
  name                 = "${format("${var.hostname}%06d", var.serverseed + count.index)}-Data2"
  #name                 = "${format("${var.hostname}%06d", module.hostnumber.number + count.index)}-Data2"
  location             = "${var.location}"
  resource_group_name  = "${var.resourcegroup}"
  storage_account_type = "${var.disktype}"
  create_option        = "Empty"
  disk_size_gb         = "${element(var.datadisksize, 1)}"
}

resource "azurerm_virtual_machine_data_disk_attachment" "data1" {
  count                 = "${var.winvmcount}"
  managed_disk_id       = "${element(azurerm_managed_disk.data1.*.id, count.index)}"
  virtual_machine_id    = "${element(azurerm_virtual_machine.winvm.*.id, count.index)}"
  lun                   = "0"
  caching               = "ReadOnly"
}

resource "azurerm_virtual_machine_data_disk_attachment" "data2" {
  count                 = "${var.winvmcount}"
  depends_on            = ["azurerm_virtual_machine_data_disk_attachment.data1"]
  managed_disk_id       = "${element(azurerm_managed_disk.data2.*.id, count.index)}"
  virtual_machine_id    = "${element(azurerm_virtual_machine.winvm.*.id, count.index)}"
  lun                   = "1"
  caching               = "None"
}

output "vmname" {
  value = "${azurerm_virtual_machine.winvm.*.name}"
}

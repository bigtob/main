# Modified from V1 by Toby
# V2: Removed hostnumber generation, just use server seed
#     Added avset functionality

# Declare variables
variable "location" {}
variable "resourcegroup" {}
variable "vmsize" {}
variable "rhelversion" {}
variable "linuxvmcount" {}
#variable "testing" {}
variable "env" {}
variable "subnetname" {}
variable "availset" {}
variable "serverseed" {}

# Retrieve host number
#module "hostnumber" {
#    source    = "../../hostnumber/v1"
#    testing   = "${var.testing}"
#    increment = "${var.linuxvmcount}"
#}

# Create NIC
resource "azurerm_network_interface" "networkinterfacedynamic" {
    name                = "${format("AZUL${upper(var.env)}%06d", var.serverseed + count.index)}-NIC-01"
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
    name                = "${format("AZUL${upper(var.env)}%06d", var.serverseed + count.index)}-NIC-01"
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
resource "azurerm_virtual_machine" "linuxvm" {
    name                             = "${format("AZUL${upper(var.env)}%06d", var.serverseed + count.index)}"
    location                         = "${var.location}"
    resource_group_name              = "${var.resourcegroup}"
    count                            = "${var.linuxvmcount}"
    network_interface_ids            = ["${element(azurerm_network_interface.networkinterfacestatic.*.id, count.index)}"]
    vm_size                          = "${var.vmsize}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true
    availability_set_id              = "${var.availset}"
    
    storage_os_disk {
        name              = "${format("AZUL${upper(var.env)}%06d", var.serverseed + count.index)}-Disk-00" 
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher         = "RedHat"
        offer             = "RHEL"
        sku               = "${var.rhelversion}"
        version           = "latest"
    }

    os_profile {
        computer_name     = "${format("azul${lower(var.env)}%06d", var.serverseed + count.index)}"
        admin_username    = "admin"
        admin_password    = "password"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }
}

# Run custom script extension
resource "azurerm_virtual_machine_extension" "yourscript" {
    name                 = "yourscript"
    location             = "${var.location}"
    resource_group_name  = "${var.resourcegroup}"
    count                = "${var.linuxvmcount}"
    virtual_machine_name = "${format("AZUL${upper(var.env)}%06d", var.serverseed + count.index)}"
    publisher            = "Microsoft.Azure.Extensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"
    depends_on = ["azurerm_virtual_machine.linuxvm"]
    settings = <<SETTINGS
        {
        "fileUris": ["https://yourstgacc.blob.core.windows.net/yourcontainer/yourscript.sh"],
        "commandToExecute": "sh yourscript.sh"
        }
SETTINGS
	protected_settings = <<SETTINGS
		{
	    "storageAccountKey": "yourkey",
        "storageAccountName": "yourstgacc"
        }
SETTINGS
}
output "virtualmachineid" {
    value = ["${azurerm_virtual_machine.linuxvm.*.id}"]
}
output "vmname" {
  value = ["${azurerm_virtual_machine.linuxvm.*.name}"]
}
output "linuxvmnic" {
  value = ["${azurerm_network_interface.networkinterfacestatic.*.id}"]  
}
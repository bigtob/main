# Declare variables
variable "location" {}
variable "resourcegroup" {}
variable "vmsize" {}
variable "rhelversion" {}
variable "linuxvmcount" {}
variable "testing" {}
variable "env" {}
variable "linuxvmnic" {}

# Retrieve host number
module "hostnumber" {
    source    = "../../hostnumber/v1"
    testing   = "${var.testing}"
    increment = "${var.linuxvmcount}"
}

# Create virtual machine
resource "azurerm_virtual_machine" "linuxvm" {
    name                             = "${format("AZUL${upper(var.env)}%06d", count.index + module.hostnumber.number)}"
    location                         = "${var.location}"
    resource_group_name              = "${var.resourcegroup}"
    count                            = "${var.linuxvmcount}"
    network_interface_ids            = ["${var.linuxvmnic}"]
    vm_size                          = "${var.vmsize}"
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    storage_os_disk {
        name              = "${format("AZUL${upper(var.env)}%06d", count.index + module.hostnumber.number)}-Disk-00" 
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
        computer_name     = "${format("azul${lower(var.env)}%06d", count.index + module.hostnumber.number)}"
        admin_username    = "admin"
        admin_password    = "password"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

#    boot_diagnostics {
#        enabled = "true"
#        storage_uri = "${var.storageuri}"
#    }
}

# Run custom script extension
resource "azurerm_virtual_machine_extension" "yourscript" {
    name                 = "yourscript"
    location             = "${var.location}"
    resource_group_name  = "${var.resourcegroup}"
    count                = "${var.linuxvmcount}"
    virtual_machine_name = "${format("AZUL${upper(var.env)}%06d", count.index + module.hostnumber.number)}"
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
        "storageAccountName": "youstgacc"
	    }
SETTINGS
}
output "virtualmachineid" {
    value = ["${azurerm_virtual_machine.linuxvm.*.id}"]
}
output "vmname" {
  value = ["${azurerm_virtual_machine.linuxvm.*.name}"]
}
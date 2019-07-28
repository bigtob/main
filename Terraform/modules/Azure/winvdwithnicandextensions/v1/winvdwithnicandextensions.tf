# Modified from V2 by Toby.
# V3: Changed two disk configuration down to one (most common request).

variable "winvmcount" {}
variable "location" {}
variable "resourcegroup" {}
variable "hostname" {}
variable "subnetref" {}
variable "serverseed" {}
variable "winvmsizelist" { type= "list" }
variable "availset" {}
variable "owner" {}

provider "azurerm" {
  subscription_id = "yoursubid"
  alias           = "keyvault"
}

data "azurerm_key_vault_secret" "windowsiaasadmin" {
  name      = "WindowsIaaSAdmin"
#  vault_uri = "https://yourvault.vault.azure.net/"
  provider     = "azurerm.keyvault"
  key_vault_id = "/subscriptions/yoursubid/resourceGroups/yourrg/providers/Microsoft.KeyVault/vaults/yourvault"
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
	license_type = "Windows_Client"
    storage_image_reference {
        publisher = "MicrosoftWindowsDesktop"
        offer     = "Windows-10"
        sku       = "rs5-pro"
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
	
	tags = {
		owner 				= "${var.owner}"
	}
}


resource "azurerm_virtual_machine_extension" "ssepostbuild" {
    count                   = "${var.winvmcount}"
    name                    = "ssepostbuild"
    location                = "${var.location}"
    resource_group_name     = "${var.resourcegroup}"
    virtual_machine_name    = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
    publisher               = "Microsoft.Compute"
	depends_on 				= ["azurerm_virtual_machine.winvm"]
    type                    = "CustomScriptExtension"
    type_handler_version    = "1.9"
    
    settings = <<SETTINGS
    {
      "fileUris": [
        "https://yourstgacc.blob.core.windows.net/scripts/VDPostBuild.ps1"
		
      ]
    }
SETTINGS
    protected_settings = <<PROTECTEDSETTINGS
    {
      "storageAccountName": "yourstgacc",
      "storageAccountKey": "yourkey",                            
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File vdpostbuild.ps1"
    }
PROTECTEDSETTINGS
}
output "vmname" {
  value = "${azurerm_virtual_machine.winvm.*.name}"
}

resource "azurerm_template_deployment" "vdishutdown" {
        name                    = "shutdowntemplate"
		count                   = "${var.winvmcount}"
        resource_group_name     = "${var.resourcegroup}"
        depends_on 				= ["azurerm_virtual_machine.winvm"]
        template_body = <<DEPLOY
{
  "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
      "virtualMachineName": {
          "type": "string",
          "metadata": {
              "description": "Name of the target virtual machine"
          }
      },
      "address": {
          "type": "string",
          "metadata": {
              "description": "E-mail address of the virtual machine owner"
          }
      },
      "minsBefore": {
          "type": "string",
          "metadata": {
              "description": "Time in minutes [15-120], prior to shutdown, to send e-mail"
          }
      },
      "shutDownTime" : {
          "type": "string",
          "metadata": {
              "description": "Time to shut down machine e.g. 2100, 1700"
          }
      }
  },
  "resources": [
    {
    "apiVersion": "2017-04-26-preview",
    "type": "Microsoft.devtestlab/schedules",
    "name": "[concat('shutdown-computevm-', parameters('virtualMachineName'))]",
    "location": "[resourceGroup().location]",
    "properties": {
        "status": "Enabled",
        "taskType": "ComputeVmShutdownTask",
        "dailyRecurrence": {
            "time": "[parameters('shutDownTime')]"
        },
        "timeZoneId": "GMT Standard Time",
        "notificationSettings": {
            "status": "Enabled",
            "emailRecipient": "[parameters('address')]",
            "timeInMinutes": "[parameters('minsBefore')]"
        },
        "targetResourceId": "[resourceId('Microsoft.Compute/virtualMachines', parameters('virtualMachineName'))]"
     }
    }
  ]
}
DEPLOY
# these key-value pairs are passed into the ARM Template's `parameters` block
  parameters {
    "virtualMachineName" = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
    "address" = "${var.owner}"
    "minsBefore" = "120"
    "shutDownTime" = "1800"
  }

  deployment_mode = "Incremental"
}
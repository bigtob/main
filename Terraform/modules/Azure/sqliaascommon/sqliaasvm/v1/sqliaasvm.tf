variable "location" {}
variable "vmcount" {}
variable "serverseed" {}
variable "hostname" {}
variable "resourcegroup" {}
#variable "diagssa" {}
variable "asid" {}
variable "offer" {}
variable "sku"{}
variable "env" {}
variable "application" {}
variable "datadisksize" {}
variable "vmsize" {}
variable "subnetref" {}


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
data "azurerm_key_vault_secret" "sqliaasadmin" {
  name      = "SQLIaaSAdmin"
  vault_uri = "https://yourvault.vault.azure.net/"
}

resource "azurerm_network_interface" "networkinterfacedynamic" {
  name                      = "${var.hostname}${var.serverseed + count.index}-nic1"
  location                  = "${var.location}"
  resource_group_name       = "${var.resourcegroup}"
	count                     = "${var.vmcount}"
  #network_security_group_id = "${var.nsgref}"
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${var.subnetref}"
    private_ip_address_allocation = "Dynamic"
    #private_ip_address            = "${var.appipaddress}"
  }
}
resource "azurerm_network_interface" "networkinterfacestatic" {
  name                      = "${var.hostname}${var.serverseed + count.index}-nic1"
  location                  = "${var.location}"
  resource_group_name       = "${var.resourcegroup}"
	count                     = "${var.vmcount}"
  #network_security_group_id = "${var.nsgref}"
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = "${var.subnetref}"
     private_ip_address_allocation = "Static"
     private_ip_address            = "${element(azurerm_network_interface.networkinterfacedynamic.*.private_ip_address,count.index)}"
  }
}

resource "azurerm_virtual_machine" "sqlvm" {
  count                 = "${var.vmcount}"
  name                  = "${var.hostname}${var.serverseed + count.index}"
  location              = "${var.location}"
  resource_group_name   = "${var.resourcegroup}"
  network_interface_ids = ["${element(azurerm_network_interface.networkinterfacestatic.*.id, count.index)}"]
  vm_size               = "${var.vmsize}"
  availability_set_id   = "${var.asid}"
  boot_diagnostics {
    enabled     = true
    storage_uri = "${azurerm_storage_account.vmdiagssa.primary_blob_endpoint}"
  }

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
    name                = "${var.hostname}${var.serverseed + count.index}_OS"
    caching             = "ReadWrite"
    create_option       = "FromImage"
    managed_disk_type   = "${lookup(var.disktype,var.env,"Standard_LRS")}"
  }

  os_profile {
    computer_name       = "${var.hostname}${var.serverseed + count.index}"
    #admin_username     = "sqliaasadmin"
    admin_username      = "${data.azurerm_key_vault_secret.sqliaasadmin.name}"
    admin_password      = "${data.azurerm_key_vault_secret.sqliaasadmin.value}"
  }

  os_profile_windows_config {
    enable_automatic_upgrades   = false
    provision_vm_agent          = true
  }

}
resource "azurerm_managed_disk" "externaldata" {
  count                = "${var.vmcount}"
  name                 = "${var.hostname}${var.serverseed + count.index}_SQL_Data"
  location             = "${var.location}"
  resource_group_name  = "${var.resourcegroup}"
  storage_account_type = "${lookup(var.disktype,var.env,"Standard_LRS")}"
  create_option        = "Empty"
  disk_size_gb         = "${var.datadisksize}"
}

resource "azurerm_managed_disk" "externallogs" {
  count                = "${var.vmcount}"
  name                 = "${var.hostname}${var.serverseed + count.index}_SQL_Logs"
  location             = "${var.location}"
  resource_group_name  = "${var.resourcegroup}"
  storage_account_type = "${lookup(var.disktype,var.env,"Standard_LRS")}"
  create_option        = "Empty"
  disk_size_gb         = "${lookup(var.logdisksize, var.datadisksize)}"
}

resource "azurerm_virtual_machine_data_disk_attachment" "externaldata" {
  count                 = "${var.vmcount}"
  managed_disk_id       = "${element(azurerm_managed_disk.externaldata.*.id, count.index)}"
  virtual_machine_id    = "${element(azurerm_virtual_machine.sqlvm.*.id, count.index)}"
  lun                   = "0"
  caching               = "ReadOnly"
}

resource "azurerm_virtual_machine_data_disk_attachment" "externallogs" {
  count                 = "${var.vmcount}"
  depends_on            = ["azurerm_virtual_machine_data_disk_attachment.externaldata"]
  managed_disk_id       = "${element(azurerm_managed_disk.externallogs.*.id, count.index)}"
  virtual_machine_id    = "${element(azurerm_virtual_machine.sqlvm.*.id, count.index)}"
  lun                   = "1"
  caching               = "None"
}

resource "azurerm_virtual_machine_extension" "sqlserver" {
  count                 = "${var.vmcount}"
  name                  = "SQLIaaSAgent"
  location              = "${var.location}"
  resource_group_name   = "${var.resourcegroup}"
  virtual_machine_name  = "${var.hostname}${var.serverseed + count.index}"
  #virtual_machine_name  = "${var.hostname}"
  publisher             = "Microsoft.SqlServer.Management"
  type                  = "SqlIaaSAgent"
  type_handler_version  = "1.2"
  depends_on            = ["azurerm_virtual_machine_data_disk_attachment.externallogs", "azurerm_virtual_machine_data_disk_attachment.externaldata"]
  
  settings = <<SETTINGS
  {
          "AutoTelemetrySettings": {
            "Region": "${var.location}"
          },
          "AutoPatchingSettings": {
            "PatchCategory": "WindowsMandatoryUpdates",
            "Enable": true,
            "DayOfWeek": "Sunday",
            "MaintenanceWindowStartingHour": "2",
            "MaintenanceWindowDuration": "60"
          },
          "KeyVaultCredentialSettings": {
            "Enable": false,
            "CredentialName": ""
          },
          "ServerConfigurationsManagementSettings": {
            "SQLConnectivityUpdateSettings": {
              "ConnectivityType": "Private",
              "Port": 1433
            },
            "SQLWorkloadTypeUpdateSettings": {
              "SQLWorkloadType": "General"
            },
            "SQLStorageUpdateSettings": {
              "DiskCount": "1",
              "NumberOfColumns": "1",
              "StartingDeviceID": "2",
              "DiskConfigurationType": "NEW"
            },
            "AdditionalFeaturesServerConfigurations": {
              "IsRServicesEnabled": "false"
            }
          }
  }
SETTINGS
}

resource "azurerm_storage_account" "vmdiagssa" {
  name                     = "${lower(var.application)}${lower(var.env)}vmdiags"
  resource_group_name      = "${var.resourcegroup}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

output "vmname" {
    value = "${azurerm_virtual_machine_extension.sqlserver.*.virtual_machine_name}"
}
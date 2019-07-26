#
variable "resourcegroup" {
  description = "The name of the Resource Group where the Domain Controllers resources will be created"
}
variable "location" {
  description = "The Azure Region in which the Resource Group exists"
}
variable "subnetref" {}
variable "hostname" {}
variable "active_directory_domain" {
  description = "The name of the Active Directory domain, for example `consoto.local`"
}
variable "active_directory_netbios_name" {
  description = "The netbios name of the Active Directory domain, for example `consoto`"
}
variable "admin_username" {
  description = "The username associated with the local administrator account on the virtual machine"
}
#variable "admin_password" {
#  description = "The password associated with the local administrator account on the virtual machine"
#}

# Create a network interface
resource "azurerm_network_interface" "primary" {
  name                    = "${var.hostname}-dc-primary"
  location                = "${var.location}"
  resource_group_name     = "${var.resourcegroup}"
  internal_dns_name_label = "${local.virtual_machine_name}"

  ip_configuration {
    name                          = "primary"
    subnet_id                     = "${var.subnetref}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.154.113.6"
  }
}

# Create a domain controller
locals {
  virtual_machine_name = "${var.hostname}-dc"
  virtual_machine_fqdn = "${local.virtual_machine_name}.${var.active_directory_domain}"
  custom_data_params   = "Param($RemoteHostName = \"${local.virtual_machine_fqdn}\", $ComputerName = \"${local.virtual_machine_name}\")"
  custom_data_content  = "${local.custom_data_params} ${file("${path.module}/files/winrm.ps1")}"
}

data "azurerm_key_vault_secret" "windowsiaasadmin" {
  name      = "WindowsIaaSAdmin"
  vault_uri = "https://ssebuildcreds.vault.azure.net/"
}

resource "azurerm_virtual_machine" "domain-controller" {
  name                          = "${local.virtual_machine_name}"
  location                      = "${var.location}"
  resource_group_name           = "${var.resourcegroup}"
  network_interface_ids         = ["${azurerm_network_interface.primary.id}"]
  vm_size                       = "Standard_D2s_v3"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${local.virtual_machine_name}-disk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.virtual_machine_name}"
    admin_username = "${var.admin_username}"
    admin_password = "${data.azurerm_key_vault_secret.windowsiaasadmin.value}"
    custom_data    = "${local.custom_data_content}"
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true

    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${data.azurerm_key_vault_secret.windowsiaasadmin.value}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = "${file("${path.module}/files/FirstLogonCommands.xml")}"
    }
  }
}

# provision the domain
// the `exit_code_hack` is to keep the VM Extension resource happy
locals {
  import_command       = "Import-Module ADDSDeployment"
  password_command     = "$password = ConvertTo-SecureString ${data.azurerm_key_vault_secret.windowsiaasadmin.value} -AsPlainText -Force"
  install_ad_command   = "Add-WindowsFeature -name ad-domain-services -IncludeManagementTools"
  configure_ad_command = "Install-ADDSForest -CreateDnsDelegation:$false -DomainMode Win2012R2 -DomainName ${var.active_directory_domain} -DomainNetbiosName ${var.active_directory_netbios_name} -ForestMode Win2012R2 -InstallDns:$true -SafeModeAdministratorPassword $password -Force:$true"
  shutdown_command     = "shutdown -r -t 10"
  exit_code_hack       = "exit 0"
  powershell_command   = "${local.import_command}; ${local.password_command}; ${local.install_ad_command}; ${local.configure_ad_command}; ${local.shutdown_command}; ${local.exit_code_hack}"
}

// NOTE: we **highly recommend** not using this configuration for your Production Environment
// this provisions a single node configuration with no redundancy.
resource "azurerm_virtual_machine_extension" "create-active-directory-forest" {
  name                 = "create-active-directory-forest"
  location             = "${azurerm_virtual_machine.domain-controller.location}"
  resource_group_name  = "${var.resourcegroup}"
  virtual_machine_name = "${azurerm_virtual_machine.domain-controller.name}"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe -Command \"${local.powershell_command}\""
    }
SETTINGS
}

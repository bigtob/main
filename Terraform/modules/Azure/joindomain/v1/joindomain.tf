# Retrieve the addcomputer  secret
variable "location" {}
variable "winvmcount" {}
variable "hostname" {}
variable "resourcegroup" {}
variable "fqdn" {}
variable "domainname" {}
variable "serverseed" {}
variable "vmname" { type = "list" }


# Get the addcomputer secret from the build key vault
  data "azurerm_key_vault_secret" "addcomputer" {
  name      = "addcomputer"
  vault_uri = "https://yourkeyvault.vault.azure.net/"
}

# Add the computer to the domain
resource "azurerm_virtual_machine_extension" "joindomain" {
      #name                 = "join${var.hostname}${var.serverseed + count.index}"
	  name                 = "join${element(var.vmname, count.index)}"
	  publisher            = "Microsoft.Compute"
	  location             = "${var.location}"
	  resource_group_name  = "${var.resourcegroup}"
	  #virtual_machine_name = "${var.hostname}${var.serverseed + count.index}"
	  virtual_machine_name = "${element(var.vmname, count.index)}"
	  publisher            = "Microsoft.Compute"
	  type                 = "JsonADDomainExtension"
	  type_handler_version = "1.3"
	  count                = "${var.winvmcount}"

	  # NOTE: the `OUPath` can be blank, to put it in the Computers OU
	  settings = <<SETTINGS
		{
			"Name": "${var.fqdn}",
			"OUPath": "OU=Servers,DC=domain1,DC=local",
			"User": "${var.domainname}\\${data.azurerm_key_vault_secret.addcomputer.name}",
			"Restart": "true",
			"Options": "3"
		}
SETTINGS
	  protected_settings = <<SETTINGS
		{
			"Password": "${data.azurerm_key_vault_secret.addcomputer.value}"
		}
SETTINGS
}

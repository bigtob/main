variable "domain" {
	description = "Which Domain? domain1, domain2, domain3 or domain4"
	default = "domain1"
}
variable "location" {}
variable "vmcount" {}
variable "hostname" {type = "list"}
variable "resourcegroup" {}

variable "djname" {
	description = "Name of the domain"
	type = "map"
	default = {
		"domain1" = "domain1.local"
		"domain2" = "domain2.local"
		"domain3" = "domain3.local"
		"domain4" = "domain4.local"
  }
}
variable "djuser" {
	description = "Name of the domain join user"
	type = "map"
	default = {
		"domain1" = "user1"
		"domain2" = "user2"
		"domain3" = "user3"
		"domain4" = "user4"
  }
}
variable "djoupath" {
	description = "Name of the domain join user"
	type = "map"
	default = {
		"domain1" = "OU=Servers,DC=domain1,DC=local"
		"domain2" = "OU=Servers,DC=domain2,DC=local"
		"domain3" = "OU=Servers,DC=domain3,DC=local"
		"domain4" = "OU=Servers,DC=domain4,DC=local"
  }
}

module "getdomainjoinsecret" {
    source          = "../../getkeyvaultsecret/v1"
    secretname      = ["${lookup(var.djuser,var.domain)}"]
}
resource "azurerm_virtual_machine_extension" "joindomain" {
	count				 = "${var.vmcount}"
	name                 = "ADJoinExt"
	publisher            = "Microsoft.Compute"
	location             = "${var.location}"
	resource_group_name  = "${var.resourcegroup}"
	virtual_machine_name = "${element(var.hostname, count.index)}"
	publisher            = "Microsoft.Compute"
	type                 = "JsonADDomainExtension"
	type_handler_version = "1.3"

	# NOTE: the `OUPath` can be blank, to put it in the Computers OU
	settings = <<SETTINGS
	{
		"Name": "${lookup(var.djname, var.domain)}",
		"OUPath": "${lookup(var.djoupath, var.domain)}",
		"User": "${var.domain}\\${lookup(var.djuser, var.domain)}",
		"Restart": "true",
		"Options": "3"
	}
SETTINGS
	protected_settings = <<SETTINGS
	{
    "Password": "${element(module.getdomainjoinsecret.secretvalue,0)}"
	}
SETTINGS
}
output "vmname" {
	value = "${azurerm_virtual_machine_extension.joindomain.*.virtual_machine_name}"
}
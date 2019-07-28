variable "hostname" {}
variable "location" {}
variable "resourcegroup" {}
#variable "subnetref" {}
variable "subnetname" {}
variable "virtualnetworkname" {}
variable "networkrgname" {}
#variable "domainjoin" {}
variable "domain" {}
variable "sqlvmcount" {}
variable "serverseed" {}
variable "env" {}
variable "sqlvmsize" {}
variable "sqloffer" {}
variable "sqlsku" {}
variable "sqlas" {}
variable "application" {}
variable "sqldatadisksize" {}
variable "ssrsenabled" {
  description = "Should SSRS be enabled?"
  default = "False"
}
variable "ssisenabled" {
  description = "Should SSIS be enabled?"
  default = "False"
}
variable "ssasenabled" {
  description = "Should SSAS be enabled?"
  default = "False"
}
variable "sqlcollation" {
  description = "Required SQL Server collation setting"
  default = "SQL_Latin1_General_CP1_CI_AS"
}
variable "sqlauthentication" {
  description = "Required SQL Server authentication method"
  description = "Integrated or Mixed"
  default = "Integrated"
}
variable "ServiceAccountAdmin" {
	description = "Name of the account in the domain with permissions to create service accounts"
	type = "map"
	default = {
		"UK" = "Azure-SVC-Account"
		"BASTION" = "InfraAdmin"
  }
}
resource "random_string" "sqlserviceacctpassword" {
  count                   = "${var.sqlvmcount}"
  length                  = 25
  special                 = true
}

resource "azurerm_key_vault_secret" "createsvcacctpwd" {
  count                   = "${var.sqlvmcount}"
  name                    = "${format("${var.hostname}%06d", var.serverseed + count.index)}-1-SVC"
  value                   = "${element(random_string.sqlserviceacctpassword.*.result, count.index)}"
  vault_uri               = "https://yourvault.vault.azure.net/"
  content_type            = "${var.domain} domain SQL Server service account"
  tags {
    Domain = "${var.domain}"
  }
}
data "azurerm_key_vault_secret" "addaccount" {
  name                    = "${lookup(var.ServiceAccountAdmin,var.domain)}"
  vault_uri               = "https://yourvault.vault.azure.net/"
}
data "azurerm_key_vault_secret" "svcacctpwd" {
  depends_on              = ["azurerm_key_vault_secret.createsvcacctpwd"]
  count                   = "${var.sqlvmcount}"
  name                    = "${format("${var.hostname}%06d", var.serverseed + count.index)}-1-SVC"
  vault_uri               = "https://yourvault.vault.azure.net/"
}
/* resource "null_resource" "createsvcacct" {
  count                   = "${var.sqlvmcount}"
  provisioner "local-exec" {
      command = "powershell ..\\..\\_Common\\Powershell\\CreateServiceAccount\\dev\\CreateServiceAccount.ps1 -AddAccountPwd \"${data.azurerm_key_vault_secret.addaccount.value}\" -SvcAcct ${element(data.azurerm_key_vault_secret.svcacctpwd.*.name,count.index)} -SvcAcctPwd \"${element(data.azurerm_key_vault_secret.svcacctpwd.*.value,count.index)}\""
  }
} */
 resource "azurerm_availability_set" "sqlas" {
  name                          = "${var.sqlas}"
  location                      = "${var.location}"
  resource_group_name           = "${var.resourcegroup}"
  platform_update_domain_count  = 5
  platform_fault_domain_count   = 2
  managed                       = true
}
# Create virtual machines
# module "joindomain" {
#     source              = "../../joindomain/v2"
#     domain              = "${var.domain}"
#     location            = "${var.location}"
#     vmcount             = "${var.domainjoin == "Yes" ? var.sqlvmcount : 0}"
#     hostname            = "${var.hostname}"
#     #vmname              = "${azurerm_virtual_machine_extension.sqlserver.virtual_machine_name}"
#     resourcegroup       = "${var.resourcegroup}"
#     serverseed          = "${var.serverseed}"
#     #dependson           = ["azurerm_virtual_machine_extension.sqlserver.SQLServerIaaSExt"]
#     dependson           = "${azurerm_virtual_machine_extension.sqlserver.*.sqlserverext}"
# }
module "sqliaasvm" {
  source                = "../sqliaasvm/v4"
  location              = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${var.hostname}"
  resourcegroup       = "${var.resourcegroup}"
  serverseed          = "${var.serverseed}"
  vmsize              = "${var.sqlvmsize}"
  #diagssa             = "${azurerm_storage_account.vmdiagssa.primary_blob_endpoint}"
  asid                = "${azurerm_availability_set.sqlas.id}"
  offer               = "${var.sqloffer}"
  sku                 = "${var.sqlsku}"
  #manageddisktype     = "${lookup(var.disktype,var.env,"Standard_LRS")}"
  env                 = "${var.env}"
  application         = "${var.application}"
  datadisksize        = "${var.sqldatadisksize}"
  subnetname          = "${var.subnetname}"
  virtualnetworkname  = "${var.virtualnetworkname}"
  networkrgname       = "${var.networkrgname}"
  #subnetref           = "${var.subnetref}"
  #testing             = "${var.testing}"
}
module "sqliaasextension" {
  source              = "../sqliaasextension/v1"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasvm.vmnamestr}"
  #hostname            = "${var.hostname}"
  resourcegroup       = "${var.resourcegroup}"
  #serverseed          = "${var.serverseed}"
}
module "joindomain" {
  source              = "../../joindomain/v2"
  #domainjoin          = "${var.domainjoin}"
  domain              = "${var.domain}"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasextension.virtualmachinename}"
  resourcegroup       = "${var.resourcegroup}"
  #serverseed          = "${var.serverseed}"
}

module "sqliaasconfig" {
  source              = "../sqliaasconfig/v2"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.joindomain.vmname}"
  # vmid                = "${module.sqliaasvm.vmid}"
  # logdiskid           = "${module.sqliaasvm.logdiskid}"
  #hostname            = "${module.sqliaasvm.sqliaasvm}"
  resourcegroup       = "${var.resourcegroup}"
  env                 = "${var.env}"
  application         = "${var.application}"
  ssrsenabled         = "${var.ssrsenabled}"
  ssisenabled         = "${var.ssisenabled}"
  ssasenabled         = "${var.ssasenabled}"
  sqlcollation        = "${var.sqlcollation}"
  sqlauthentication   = "${var.sqlauthentication}"
  domain              = "${var.domain}"
  #dependson           = "${module.joindomain.joindomain}"
  #domainjoin          = "${var.domainjoin}"
  #serverseed          = "${var.serverseed}"
}

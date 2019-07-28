variable "hostname" {}
variable "location" {}
variable "resourcegroup" {}
variable "subnetref" {}
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
# variable "keyvaulturl" {
#   default = "https://yourvault.vault.azure.net/"
# }
#variable "testing" {}
# Maps

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
#     source              = "../joindomain-dev"
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
  source              = "../../sqliaasvm/v2"
  location            = "${var.location}"
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
  subnetref           = "${var.subnetref}"
  #testing             = "${var.testing}"
}

module "sqliaasconfig" {
  source              = "../../sqliaasconfig/v1"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasvm.vmname}"
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
  #dependson           = "${module.joindomain.joindomain}"
  #domainjoin          = "${var.domainjoin}"
  #serverseed          = "${var.serverseed}"
}

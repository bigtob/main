variable "hostname" {}
variable "location" {}
variable "resourcegroup" {}
variable "subnetname" {}
variable "virtualnetworkname" {}
variable "networkrgname" {}
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

module "getsaadminsecret" {
    source          = "../../getkeyvaultsecret/v1"
    secretname      = ["${lookup(var.ServiceAccountAdmin,var.domain)}"]
}
resource "random_string" "sqlserviceacctpassword" {
  count                   = "${var.sqlvmcount}"
  length                  = 25
  special                 = true
}
resource "azurerm_availability_set" "sqlas" {
  name                          = "${var.sqlas}"
  location                      = "${var.location}"
  resource_group_name           = "${var.resourcegroup}"
  platform_update_domain_count  = 5
  platform_fault_domain_count   = 2
  managed                       = true
}
module "sqliaasvm" {
  source                = "../../sqliaascommon/sqliaasvm/v5"
  location              = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${var.hostname}"
  resourcegroup       = "${var.resourcegroup}"
  serverseed          = "${var.serverseed}"
  vmsize              = "${var.sqlvmsize}"
  asid                = "${azurerm_availability_set.sqlas.id}"
  offer               = "${var.sqloffer}"
  sku                 = "${var.sqlsku}"
  env                 = "${var.env}"
  application         = "${var.application}"
  datadisksize        = "${var.sqldatadisksize}"
  subnetname          = "${var.subnetname}"
  virtualnetworkname  = "${var.virtualnetworkname}"
  networkrgname       = "${var.networkrgname}"
}

module "createsasecret" {
    source          = "../../createkeyvaultsecret/v1"
    secretname      = "${formatlist("%s-1-SVC",module.sqliaasvm.vmnamelist)}"
    secretvalue     = "${random_string.sqlserviceacctpassword.*.result}"
    secretcount     = "${var.sqlvmcount}"
    domain          = "${var.domain}"
}

module "sqliaasextension" {
  source              = "../../sqliaascommon/sqliaasextension/v2"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasvm.vmnamestr}"
  resourcegroup       = "${var.resourcegroup}"
}

module "joindomain" {
  source              = "../../joindomain/BuildSQL"
  domain              = "${var.domain}"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasextension.virtualmachinename}"
  resourcegroup       = "${var.resourcegroup}"
}

module "sqliaasconfig" {
  source              = "../../sqliaascommon/sqliaasconfig/v5"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.joindomain.vmname}"
  resourcegroup       = "${var.resourcegroup}"
  env                 = "${var.env}"
  application         = "${var.application}"
  ssrsenabled         = "${var.ssrsenabled}"
  ssisenabled         = "${var.ssisenabled}"
  ssasenabled         = "${var.ssasenabled}"
  sqlcollation        = "${var.sqlcollation}"
  sqlauthentication   = "${var.sqlauthentication}"
  domain              = "${var.domain}"
  serviceacc          = "${module.createsasecret.secretname}"
  serviceaccpwd       = "${module.createsasecret.secretvalue}"
}

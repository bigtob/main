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
variable "sqllicensetype" {}

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
variable "sqlag" {
  default = "Yes"
}

data "azurerm_subnet" "subnetid" {
  name                 = "${var.subnetname}"
  virtual_network_name = "${var.virtualnetworkname}"
  resource_group_name  = "${var.networkrgname}"
}

resource "random_string" "sqlserviceacctpassword" {
  length                  = 25
  special                 = true
}

module "tmpsvcacctpwd" {
    source          = "../../getkeyvaultsecret/v1"
    secretname      = ["youraccount"]
}
resource "azurerm_availability_set" "sqlas" {
  name                          = "${var.sqlas}"
  location                      = "${var.location}"
  resource_group_name           = "${var.resourcegroup}"
  platform_update_domain_count  = 5
  platform_fault_domain_count   = 2
  managed                       = true
}

resource "azurerm_lb" "loadbalancerstatic" {
  name                            = "lb${var.application}${var.env}sql"
  location                        = "${var.location}"
  resource_group_name             = "${var.resourcegroup}"
  frontend_ip_configuration {
    name                          = "FrontendIPConfiguration"
    subnet_id                     = "${data.azurerm_subnet.subnetid.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "${cidrhost(data.azurerm_subnet.subnetid.address_prefix, var.sqlvmcount + 4)}"
  }
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
    secretname      = ["${upper(var.application)}${upper(var.env)}SQL-1-SVC"]
    secretvalue     = ["${random_string.sqlserviceacctpassword.result}"]
    domain          = "${var.domain}"
}
module "sqliaasextension" {
  source              = "../../sqliaascommon/sqliaasextension/v2"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasvm.vmnamestr}"
  resourcegroup       = "${var.resourcegroup}"
  sqllicensetype      = "${var.sqllicensetype}"
}
module "joindomain" {
  source              = "../../joindomain/BuildSQL"
  domain              = "${var.domain}"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasextension.virtualmachinename}"
  resourcegroup       = "${var.resourcegroup}"
}
 
module "sqliaaswfc" {
  source              = "../../sqliaascommon/sqliaaswfc/v2"
  location            = "${var.location}"
  application         = "${var.application}"
  env                 = "${var.env}"
  hostname            = "${module.joindomain.vmname}"
  resourcegroup       = "${var.resourcegroup}"
  sqlversion          = "${var.sqloffer}"
  sqlserversku        = "${var.sqlsku}"
  sqllicensetype      = "${var.sqllicensetype}"
  domain              = "${var.domain}"
  saaccount           = "${element(module.tmpsvcacctpwd.secretname,0)}"
  saaccountpwd        = "${element(module.tmpsvcacctpwd.secretvalue,0)}"
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
  sqlag               = "${module.sqliaaswfc.FailoverClusterName},ag${substr(var.application,0,min(6,length(var.application)))}${var.env},${join(",", module.joindomain.vmname)}"
  serviceacc          = "${module.createsasecret.secretname}"
  serviceaccpwd       = "${module.createsasecret.secretvalue}"
}

module "sqliaaslstnr" {
  source                        = "../../sqliaascommon/sqliaaslstnr/v1"
  resourcegroup                 = "${var.resourcegroup}"
  existingFailoverClusterName   = "${module.sqliaaswfc.FailoverClusterName}"
  application                   = "${var.application}"
  hostname                      = "${module.sqliaasconfig.vmnamelist}"
  env                           = "${var.env}"
  existingVnetResourcegroup     = "${var.networkrgname}"
  existingVnet                  = "${var.virtualnetworkname}"
  existingSubnet                = "${var.subnetname}"
  existingInternalLoadBalancer  = "${azurerm_lb.loadbalancerstatic.name}"
  location                      = "${var.location}"
  vmcount                       = "${var.sqlvmcount}"
}

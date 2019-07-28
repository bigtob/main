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

resource "azurerm_key_vault_secret" "createsvcacctpwd" {
  name                    = "${upper(var.application)}${upper(var.env)}SQL-1-SVC"
  value                   = "${element(random_string.sqlserviceacctpassword.*.result, count.index)}"
  vault_uri               = "https://yourvault.vault.azure.net/"
  content_type            = "${var.domain} domain SQL Server service account"
  tags {
    Domain = "${var.domain}"
  }
}

data "azurerm_key_vault_secret" "addaccount" {
  name                    = "youraccount"
  vault_uri               = "https://yourvault.vault.azure.net/"
}

data "azurerm_key_vault_secret" "tmpsvcacctpwd" {
  name                    = "youraccount"
  vault_uri               = "https://yourvault.vault.azure.net/"
}
data "azurerm_key_vault_secret" "svcacctpwd" {
  depends_on              = ["azurerm_key_vault_secret.createsvcacctpwd"]
  name                    = "${upper(var.application)}${upper(var.env)}SQL-1-SVC"
  vault_uri               = "https://yourvault.vault.azure.net/"
}
/* resource "null_resource" "createsvcacct" {
  provisioner "local-exec" {
      command = "powershell ..\\..\\_Common\\Powershell\\CreateServiceAccount\\dev\\CreateServiceAccount.ps1 -AddAccountPwd \"${data.azurerm_key_vault_secret.addaccount.value}\" -SvcAcct ${data.azurerm_key_vault_secret.svcacctpwd.name} -SvcAcctPwd \"${data.azurerm_key_vault_secret.svcacctpwd.value}\""
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

/* resource "azurerm_lb" "loadbalancerdynamic" {
  name                            = "lb${var.application}${var.env}sql"
  location                        = "${var.location}"
  resource_group_name             = "${var.resourcegroup}"
  frontend_ip_configuration {
    name                          = "FrontendIPConfiguration"
    subnet_id                     = "${var.subnetref}"
    private_ip_address_allocation = "Dynamic"
  }
} */

resource "azurerm_lb" "loadbalancerstatic" {
  name                            = "lb${var.application}${var.env}sql"
  location                        = "${var.location}"
  resource_group_name             = "${var.resourcegroup}"
  frontend_ip_configuration {
    name                          = "FrontendIPConfiguration"
    subnet_id                     = "${data.azurerm_subnet.subnetid.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "${cidrhost(data.azurerm_subnet.subnetid.address_prefix, 4)}"
  }
}

module "sqliaasvm" {
  source                = "../../sqliaas/sqliaasvm/v4"
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
  source              = "../../sqliaas/sqliaasextension/v1"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasvm.vmnamestr}"
  #hostname            = "${var.hostname}"
  resourcegroup       = "${var.resourcegroup}"
  #serverseed          = "${var.serverseed}"
}
module "joindomain" {
  source              = "../../joindomain/dev"
  #domainjoin          = "${var.domainjoin}"
  domain              = "${var.domain}"
  location            = "${var.location}"
  vmcount             = "${var.sqlvmcount}"
  hostname            = "${module.sqliaasextension.virtualmachinename}"
  resourcegroup       = "${var.resourcegroup}"
  #serverseed          = "${var.serverseed}"
}

module "sqliaaswfc" {
  source              = "../../sqliaasag/sqliaaswfc/v1"
  location            = "${var.location}"
  application         = "${var.application}"
  env                 = "${var.env}"
  hostname            = "${module.joindomain.vmname}"
  resourcegroup       = "${var.resourcegroup}"
  sqlversion          = "${var.sqloffer}"
  sqlserversku        = "${var.sqlsku}"
  domain              = "${var.domain}"
  saaccount           = "${data.azurerm_key_vault_secret.tmpsvcacctpwd.name}"
  saaccountpwd        = "${data.azurerm_key_vault_secret.tmpsvcacctpwd.value}"
  #serverseed          = "${var.serverseed}"
}

 module "sqliaasconfig" {
  source              = "../../sqliaas/sqliaasconfig/v2"
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
  sqlag               = "${module.sqliaaswfc.FailoverClusterName},ag${substr(var.application,0,6)}${var.env},${join(",", module.joindomain.vmname)}"
  #sqlag               = "${module.sqliaaswfc.FailoverClusterName}"
  #dependson           = "${module.joindomain.joindomain}"
  #domainjoin          = "${var.domainjoin}"
  #serverseed          = "${var.serverseed}"
}

module "sqliaaslstnr" {
  source                        = "../../sqliaasag/sqliaaslstnr/v1"
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
 
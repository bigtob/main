#---------------------------------------------------------------------------------------
# Variables
#---------------------------------------------------------------------------------------
variable "subscriptionid" {}
variable "tenantid" {}
variable "clientid" {}
variable "clientsecret" {}
variable "env" {}
variable "directorate" {}
variable "subdirectorate" {}
variable "projectcode" {}
variable "costcentre" {}
variable "irnumber" {}
variable "supportteam1" {}
variable "supportteam2" {}
variable "lifecyclestatus" {}
variable "location" {}
variable "vnetname" {}
variable "subnetname" {}
variable "rhelversion" {}
variable "stgtier" {}
variable "vmsizelist" { type = "list" }
#variable "fqdn" {}
#variable "domainname" {}
variable "versionno" {}
variable "service" {}
variable "instanceno" {}
variable "servicehours" {}
#---------------------------------------------------------------------------------------
# Configure the Microsoft Azure Provider
#---------------------------------------------------------------------------------------
provider "azurerm" {
    subscription_id = "${var.subscriptionid}"
    tenant_id       = "${var.tenantid}"
    client_id       = "${var.clientid}"
    client_secret   = "${var.clientsecret}"
    use_msi         = "true"
}
#---------------------------------------------------------------------------------------
# Call for module to build Resource Group
#---------------------------------------------------------------------------------------
module "resourcegroup" {
    source          = "../../../_Common/Terraform/modules/resourcegroup"
    rsgname         = "${var.service}-${var.env}-${var.versionno}-${var.instanceno}-rg"
    location        = "${var.location}"
    directorate     = "${var.directorate}"
    subdirectorate  = "${var.subdirectorate}"
    costcentre      = "${var.costcentre}"
    projectcode     = "${var.projectcode}"
    irnumber        = "${var.irnumber}"
    supportteam1    = "${var.supportteam1}"
    supportteam2    = "${var.supportteam2}"
    servicehours    = "${var.servicehours}"
    lifecyclestatus = "${var.lifecyclestatus}"
}
#---------------------------------------------------------------------------------------
# Use a data source to get the name of the target subnet_id
#---------------------------------------------------------------------------------------
data "azurerm_subnet" "subnetid" {
    name                 = "${var.subnetname}"
    virtual_network_name = "${var.vnetname}"
    resource_group_name  = "yourrsg"
}
#---------------------------------------------------------------------------------------
# Call for modules to build Windows VM's (2 x Smallworld EIS servers) 
#---------------------------------------------------------------------------------------
module "availset1" {
    source              = "../../../_Common/Terraform/modules/availset-dev"
    name                = "${var.service}-${var.env}-${var.versionno}-${var.instanceno}-as-001"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
}
module "windowsvm1" {
    source              = "../../../_Common/Terraform/modules/winvmwithnic/v3"
    hostname            = "AZUW${upper(var.env)}"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
    subnetref           = "${data.azurerm_subnet.subnetid.id}"
    winvmcount          = 2
    serverseed          = "158"
    env                 = "${var.env}"
    winvmsize           = "${var.vmsizelist[2]}"
    stgtier             = "${var.stgtier}"
    availset            = "${module.availset1.availsetid}"
    disktype            = "Standard_LRS"
    datadisksize        = 250
    winvmsku            = "2016-Datacenter"
}
#---------------------------------------------------------------------------------------
# Call for module to build Windows VM (1 x Smallworld EO Web Application server)
#---------------------------------------------------------------------------------------
module "windowsvm2" {
    source              = "../../../_Common/Terraform/modules/winvmwithnic/v3"
    hostname            = "AZUW${upper(var.env)}"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
    subnetref           = "${data.azurerm_subnet.subnetid.id}"
    winvmcount          = 1
    serverseed          = "160"
    env                 = "${var.env}"
    winvmsize           = "${var.vmsizelist[0]}"
    stgtier             = "${var.stgtier}"
    availset            = ""
    disktype            = "Standard_LRS"
    datadisksize        = 1000
    winvmsku            = "2016-Datacenter"
}
#---------------------------------------------------------------------------------------
# Call for module to build Windows VM's (4 x Mobility servers)
#---------------------------------------------------------------------------------------
module "availset2" {
    source              = "../../../_Common/Terraform/modules/availset-dev"
    name                = "${var.service}-${var.env}-${var.versionno}-${var.instanceno}-as-002"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
}
module "windowsvm3" {
    source              = "../../../_Common/Terraform/modules/winvmwithnic/v4"
    hostname            = "AZUW${upper(var.env)}"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
    subnetref           = "${data.azurerm_subnet.subnetid.id}"
    winvmcount          = 4
    serverseed          = "161"
    env                 = "${var.env}"
    winvmsize           = "${var.vmsizelist[1]}"
    stgtier             = "${var.stgtier}"
    availset            = "${module.availset2.availsetid}"
    disktype            = "Standard_LRS"
    datadisksize        = 150
    winvmsku            = "2012-R2-Datacenter"
}
#---------------------------------------------------------------------------------------
# Call for module to build Linux VM (1 x Smallworld Replica Datasets Server)
# Call for module to create and attach disks for 1 x Smallworld Replica Datasets Server
#---------------------------------------------------------------------------------------
module "linuxvm1" {
    source        = "../../../_Common/Terraform/modules/linuxvmwithnic/v2"
    location      = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup = "${module.resourcegroup.resourcegroupname}"
    vmsize        = "${var.vmsizelist[1]}"
    rhelversion   = "${var.rhelversion}"
    env           = "${var.env}"
    subnetname    = "${data.azurerm_subnet.subnetid.id}"
    linuxvmcount  = 1
    serverseed    = "165"
    availset      = ""
}
module "swrds1disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm1.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 1000
    virtualmachineid   = "${module.linuxvm1.virtualmachineid[0]}"
}
module "swrds1disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm1.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 1000
    virtualmachineid   = "${module.linuxvm1.virtualmachineid[0]}"
}
module "swrds1disk3" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm1.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 3
    size               = 10
    virtualmachineid   = "${module.linuxvm1.virtualmachineid[0]}"
}
#---------------------------------------------------------------------------------------
# Call for module to build Linux VM's (2 x Mobile Reverse Proxy Servers)
# Call for module to create and attach disks for 2 x Mobile Reverse Proxy Servers
#---------------------------------------------------------------------------------------
module "availset3" {
    source              = "../../../_Common/Terraform/modules/availset-dev"
    name                = "${var.service}-${var.env}-${var.versionno}-${var.instanceno}-as-003"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
}
module "linuxvm2" {
    source        = "../../../_Common/Terraform/modules/linuxvmwithnic/v2"
    location      = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup = "${module.resourcegroup.resourcegroupname}"
    vmsize        = "${var.vmsizelist[0]}"
    rhelversion   = "${var.rhelversion}"
    env           = "${var.env}"
    subnetname    = "${data.azurerm_subnet.subnetid.id}"
    linuxvmcount  = 2
    serverseed    = "166"
    availset      = "${module.availset3.availsetid}"
}
module "mrps1disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm2.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 50
    virtualmachineid   = "${module.linuxvm2.virtualmachineid[0]}"
}
module "mrps1disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm2.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 10
    virtualmachineid   = "${module.linuxvm2.virtualmachineid[0]}"
}
module "mrps2disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm2.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 50
    virtualmachineid   = "${module.linuxvm2.virtualmachineid[1]}"
}
module "mrps2disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm2.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 10
    virtualmachineid   = "${module.linuxvm2.virtualmachineid[1]}"
}
#---------------------------------------------------------------------------------------
# Call for module to build Linux VM's (2 x Couchbase Sync Gateway Servers)
# Call for module to create and attach disks for 2 x Couchbase Sync Gateway Servers
#---------------------------------------------------------------------------------------
module "availset4" {
    source              = "../../../_Common/Terraform/modules/availset-dev"
    name                = "${var.service}-${var.env}-${var.versionno}-${var.instanceno}-as-004"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
}
module "linuxvm3" {
    source        = "../../../_Common/Terraform/modules/linuxvmwithnic/v2"
    location      = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup = "${module.resourcegroup.resourcegroupname}"
    vmsize        = "${var.vmsizelist[0]}"
    rhelversion   = "${var.rhelversion}"
    env           = "${var.env}"
    subnetname    = "${data.azurerm_subnet.subnetid.id}"
    linuxvmcount  = 2
    serverseed    = "168"
    availset      = "${module.availset4.availsetid}"
}
module "sync1disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm3.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 50
    virtualmachineid   = "${module.linuxvm3.virtualmachineid[0]}"
}
module "sync1disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm3.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 10
    virtualmachineid   = "${module.linuxvm3.virtualmachineid[0]}"
}
module "sync2disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm3.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 50
    virtualmachineid   = "${module.linuxvm3.virtualmachineid[1]}"
}
module "sync2disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm3.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 10
    virtualmachineid   = "${module.linuxvm3.virtualmachineid[1]}"
}
#---------------------------------------------------------------------------------------
# Call for module to build Linux VM's (3 x Couchbase Servers)
# Call for module to create and attach disks for 3 x Couchbase Servers
#---------------------------------------------------------------------------------------
module "availset5" {
    source              = "../../../_Common/Terraform/modules/availset-dev"
    name                = "${var.service}-${var.env}-${var.versionno}-${var.instanceno}-as-005"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
}
module "linuxvm4" {
    source        = "../../../_Common/Terraform/modules/linuxvmwithnic/v2"
    location      = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup = "${module.resourcegroup.resourcegroupname}"
    vmsize        = "${var.vmsizelist[0]}"
    rhelversion   = "${var.rhelversion}"
    env           = "${var.env}"
    subnetname    = "${data.azurerm_subnet.subnetid.id}"
    linuxvmcount  = 3
    serverseed    = "170"
    availset      = "${module.availset5.availsetid}"
}
module "cb1disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm4.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 50
    virtualmachineid   = "${module.linuxvm4.virtualmachineid[0]}"
}
module "cb1disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm4.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 10
    virtualmachineid   = "${module.linuxvm4.virtualmachineid[0]}"
}
module "cb2disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm4.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 50
    virtualmachineid   = "${module.linuxvm4.virtualmachineid[1]}"
}
module "cb2disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm4.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 10
    virtualmachineid   = "${module.linuxvm4.virtualmachineid[1]}"
}
module "cb3disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm4.vmname[2]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 50
    virtualmachineid   = "${module.linuxvm4.virtualmachineid[2]}"
}
module "cb3disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm4.vmname[2]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 10
    virtualmachineid   = "${module.linuxvm4.virtualmachineid[2]}"
}
#---------------------------------------------------------------------------------------
# Call for module to build Linux VM's (2 x Oracle DB Servers)
# Call for module to create and attach disks for 2 x Oracle DB Servers
#---------------------------------------------------------------------------------------
module "availset6" {
    source              = "../../../_Common/Terraform/modules/availset-dev"
    name                = "${var.service}-${var.env}-${var.versionno}-${var.instanceno}-as-006"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup       = "${module.resourcegroup.resourcegroupname}"
}
module "linuxvm5" {
    source        = "../../../_Common/Terraform/modules/linuxvmwithnic/v2"
    location      = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup = "${module.resourcegroup.resourcegroupname}"
    vmsize        = "${var.vmsizelist[1]}"
    rhelversion   = "${var.rhelversion}"
    env           = "${var.env}"
    subnetname    = "${data.azurerm_subnet.subnetid.id}"
    linuxvmcount  = 2
    serverseed    = "173"
    availset      = "${module.availset6.availsetid}"
}
module "db1disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 10
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[0]}"
}
module "db1disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 20
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[0]}"
}
module "db1disk3" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 3
    size               = 100
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[0]}"
}
module "db1disk4" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 4
    size               = 40
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[0]}"
}
module "db1disk5" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[0]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 5
    size               = 25
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[0]}"
}
module "db2disk1" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 1
    size               = 10
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[1]}"
}
module "db2disk2" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 2
    size               = 20
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[1]}"
}
module "db2disk3" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 3
    size               = 100
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[1]}"
}
module "db2disk4" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 4
    size               = 40
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[1]}"
}
module "db2disk5" {
    source             = "../../../_Common/Terraform/modules/disk/v1"
    hostname           = "${module.linuxvm5.vmname[1]}"
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    storageaccounttype = "Standard_LRS"
    lunnumber          = 5
    size               = 25
    virtualmachineid   = "${module.linuxvm5.virtualmachineid[1]}"
}
#---------------------------------------------------------------------------------------
# Call for module to domain join all Windows VM's
#---------------------------------------------------------------------------------------
module "domainjoin" {
    source             = "../../../_Common/Terraform/modules/joindomain/v2"
    hostname           = ["${module.windowsvm1.vmname[0]}", "${module.windowsvm1.vmname[1]}", "${module.windowsvm2.vmname[0]}", "${module.windowsvm3.vmname[0]}", "${module.windowsvm3.vmname[1]}", "${module.windowsvm3.vmname[2]}", "${module.windowsvm3.vmname[3]}"]
    location           = "${module.resourcegroup.resourcegrouplocation}"
    resourcegroup      = "${module.resourcegroup.resourcegroupname}"
    vmcount            = 7
}
#---------------------------------------------------------------------------------------
# Build internal Load Balancer resources (x2) 1 x Mobility, 1 x Couchbase Sync Gateway
#---------------------------------------------------------------------------------------
resource "azurerm_lb" "mobilitylb" {
    name                = "LBINT-${var.service}-Mobility-${var.env}-${var.instanceno}"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resource_group_name = "${module.resourcegroup.resourcegroupname}"

    frontend_ip_configuration {
        name                          = "LoadBalancerFrontEnd"
        subnet_id                     = "${data.azurerm_subnet.subnetid.id}"
        private_ip_address_allocation = "Dynamic"
    }
}
resource "azurerm_lb_probe" "mobilitylbprobe1" {
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id     = "${azurerm_lb.mobilitylb.id}"
  name                = "MobilityProbe1"
  port                = 8443
}
resource "azurerm_lb_probe" "mobilitylbprobe2" {
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id     = "${azurerm_lb.mobilitylb.id}"
  name                = "MobilityProbe2"
  port                = 9093
}
resource "azurerm_lb_probe" "mobilitylbprobe3" {
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id     = "${azurerm_lb.mobilitylb.id}"
  name                = "MobilityProbe3"
  port                = 9090
}
resource "azurerm_lb_backend_address_pool" "mobilitylbbackend" {
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id     = "${azurerm_lb.mobilitylb.id}"
  name                = "BackEndAddressPool"
}
resource "azurerm_lb_rule" "mobilityrule1" {
  resource_group_name            = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id                = "${azurerm_lb.mobilitylb.id}"
  name                           = "MobilityRule1"
  protocol                       = "Tcp"
  frontend_port                  = 8443
  backend_port                   = 8443
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  probe_id                       = "${azurerm_lb_probe.mobilitylbprobe1.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.mobilitylbbackend.id}"
}
resource "azurerm_lb_rule" "mobilityrule2" {
  resource_group_name            = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id                = "${azurerm_lb.mobilitylb.id}"
  name                           = "MobilityRule2"
  protocol                       = "Tcp"
  frontend_port                  = 9093
  backend_port                   = 9093
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  probe_id                       = "${azurerm_lb_probe.mobilitylbprobe2.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.mobilitylbbackend.id}"
}
resource "azurerm_lb_rule" "mobilityrule3" {
  resource_group_name            = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id                = "${azurerm_lb.mobilitylb.id}"
  name                           = "MobilityRule3"
  protocol                       = "Tcp"
  frontend_port                  = 9090
  backend_port                   = 9090
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  probe_id                       = "${azurerm_lb_probe.mobilitylbprobe3.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.mobilitylbbackend.id}"
}
resource "azurerm_network_interface_backend_address_pool_association" "mobilityassoc1" {
  count                   = 4
  network_interface_id    = "${module.windowsvm3.winvmnic[count.index]}"
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.mobilitylbbackend.id}"
}
resource "azurerm_lb" "couchbaselb" {
    name                = "LBINT-${var.service}-CouchbaseSyncGateway-${var.env}-${var.instanceno}"
    location            = "${module.resourcegroup.resourcegrouplocation}"
    resource_group_name = "${module.resourcegroup.resourcegroupname}"

    frontend_ip_configuration {
        name                          = "LoadBalancerFrontEnd"
        subnet_id                     = "${data.azurerm_subnet.subnetid.id}"
        private_ip_address_allocation = "Dynamic"
    }
}
resource "azurerm_lb_probe" "couchbaselbprobe1" {
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id     = "${azurerm_lb.couchbaselb.id}"
  name                = "CouchbaseProbe1"
  port                = 4984
}
resource "azurerm_lb_probe" "couchbaselbprobe2" {
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id     = "${azurerm_lb.couchbaselb.id}"
  name                = "CouchbaseProbe2"
  port                = 4985
}
resource "azurerm_lb_backend_address_pool" "couchbaselbbackend" {
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id     = "${azurerm_lb.couchbaselb.id}"
  name                = "BackEndAddressPool"
}
resource "azurerm_lb_rule" "couchbaserule1" {
  resource_group_name            = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id                = "${azurerm_lb.couchbaselb.id}"
  name                           = "CouchbaseRule1"
  protocol                       = "Tcp"
  frontend_port                  = 4984
  backend_port                   = 4984
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  probe_id                       = "${azurerm_lb_probe.couchbaselbprobe1.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.couchbaselbbackend.id}"
}
resource "azurerm_lb_rule" "couchbaserule2" {
  resource_group_name            = "${module.resourcegroup.resourcegroupname}"
  loadbalancer_id                = "${azurerm_lb.couchbaselb.id}"
  name                           = "CouchbaseRule2"
  protocol                       = "Tcp"
  frontend_port                  = 4985
  backend_port                   = 4985
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  probe_id                       = "${azurerm_lb_probe.couchbaselbprobe2.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.couchbaselbbackend.id}"
}
resource "azurerm_network_interface_backend_address_pool_association" "couchbaseassoc1" {
  count                   = 2
  network_interface_id    = "${module.linuxvm3.linuxvmnic[count.index]}"
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.couchbaselbbackend.id}"
}
#---------------------------------------------------------------------------------------
# Build Application Security Group resources and associate to the relevant NIC's
#---------------------------------------------------------------------------------------
resource "azurerm_application_security_group" "nginxasg" {
  name                = "ASG-${var.service}-NGINX-${var.env}-001"
  location            = "${module.resourcegroup.resourcegrouplocation}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
}
#resource "azurerm_network_interface_application_security_group_association" "nginxassoc1" {
#  network_interface_id          = "${module.linuxvm2.linuxvmnic[0]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.nginxasg.id}"
#}
#resource "azurerm_network_interface_application_security_group_association" "nginxassoc2" {
#  network_interface_id          = "${module.linuxvm2.linuxvmnic[1]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.nginxasg.id}"
#}
###
resource "azurerm_application_security_group" "eowebasg" {
  name                = "ASG-${var.service}-EOWeb-${var.env}-001"
  location            = "${module.resourcegroup.resourcegrouplocation}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
}
#resource "azurerm_network_interface_application_security_group_association" "eowebassoc1" {
#  network_interface_id          = "${module.windowsvm2.winvmnic[0]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.eowebasg.id}"
#}
###
resource "azurerm_application_security_group" "eisasg" {
  name                = "ASG-${var.service}-EIS-${var.env}-001"
  location            = "${module.resourcegroup.resourcegrouplocation}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
}
#resource "azurerm_network_interface_application_security_group_association" "eisassoc1" {
#  network_interface_id          = "${module.windowsvm1.winvmnic[0]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.eisasg.id}"
#}
###
resource "azurerm_application_security_group" "cbsyncasg" {
  name                = "ASG-${var.service}-CouchbaseSyncGateway-${var.env}-001"
  location            = "${module.resourcegroup.resourcegrouplocation}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
}
#resource "azurerm_network_interface_application_security_group_association" "cbsyncassoc1" {
#  network_interface_id          = "${module.linuxvm3.linuxvmnic[0]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.cbsyncasg.id}"
#}
#resource "azurerm_network_interface_application_security_group_association" "cbsyncassoc2" {
#  network_interface_id          = "${module.linuxvm3.linuxvmnic[1]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.cbsyncasg.id}"
#}
###
resource "azurerm_application_security_group" "cbdbasg" {
  name                = "ASG-${var.service}-CouchbaseDB-${var.env}-001"
  location            = "${module.resourcegroup.resourcegrouplocation}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
}
#resource "azurerm_network_interface_application_security_group_association" "cbdbassoc1" {
#  network_interface_id          = "${module.linuxvm4.linuxvmnic[0]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.cbdbasg.id}"
#}
#resource "azurerm_network_interface_application_security_group_association" "cbdbassoc2" {
#  network_interface_id          = "${module.linuxvm4.linuxvmnic[1]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.cbdbasg.id}"
#}
#resource "azurerm_network_interface_application_security_group_association" "cbdbassoc3" {
#  network_interface_id          = "${module.linuxvm4.linuxvmnic[2]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.cbdbasg.id}"
#}
###
resource "azurerm_application_security_group" "mobilityasg" {
  name                = "ASG-${var.service}-Mobility-${var.env}-001"
  location            = "${module.resourcegroup.resourcegrouplocation}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
}
#resource "azurerm_network_interface_application_security_group_association" "mobilityassoc1" {
#  network_interface_id          = "${module.windowsvm3.winvmnic[0]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.mobilityasg.id}"
#}
#resource "azurerm_network_interface_application_security_group_association" "mobilityassoc2" {
#  network_interface_id          = "${module.windowsvm3.winvmnic[1]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.mobilityasg.id}"
#}
#resource "azurerm_network_interface_application_security_group_association" "mobilityassoc3" {
#  network_interface_id          = "${module.windowsvm3.winvmnic[2]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.mobilityasg.id}"
#}
#resource "azurerm_network_interface_application_security_group_association" "mobilityassoc4" {
#  network_interface_id          = "${module.windowsvm3.winvmnic[3]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.mobilityasg.id}"
#}
###
resource "azurerm_application_security_group" "oracleasg" {
  name                = "ASG-${var.service}-OracleDB-${var.env}-001"
  location            = "${module.resourcegroup.resourcegrouplocation}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
}
#resource "azurerm_network_interface_application_security_group_association" "oracleassoc1" {
#  network_interface_id          = "${module.linuxvm5.linuxvmnic[0]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.oracleasg.id}"
#}
#resource "azurerm_network_interface_application_security_group_association" "oracleassoc2" {
#  network_interface_id          = "${module.linuxvm5.linuxvmnic[1]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.oracleasg.id}"
#}
###
resource "azurerm_application_security_group" "replicadsasg" {
  name                = "ASG-${var.service}-ReplicaDataset-${var.env}-001"
  location            = "${module.resourcegroup.resourcegrouplocation}"
  resource_group_name = "${module.resourcegroup.resourcegroupname}"
}
#resource "azurerm_network_interface_application_security_group_association" "replicadsassoc1" {
#  network_interface_id          = "${module.linuxvm1.linuxvmnic[0]}"
#  ip_configuration_name         = "ipconfig1"
#  application_security_group_id = "${azurerm_application_security_group.replicadsasg.id}"
#}
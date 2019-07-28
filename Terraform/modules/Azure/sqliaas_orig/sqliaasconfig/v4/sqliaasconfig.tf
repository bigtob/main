variable "location" {}
variable "vmcount" {}
variable "hostname" {type = "list"}
variable "resourcegroup" {}
variable "env" {}
variable "application" {}
variable "ssrsenabled" {}
variable "ssisenabled" {}
variable "ssasenabled" {}
variable "sqlcollation" {}
variable "sqlauthentication" {}
variable "domain" {}
variable "serviceacc" {
  type = "list"
}
variable "serviceaccpwd" {
  type = "list"
}

variable "sqlag" {
  default = "No"
}


#Maps
variable "salocation" {
    description = "Location for the storage account used for SQL Server backups"
    type = "map"
    default = {
        "UK South" = "UK West"
        "UK West" = "UK South"
    }
}
variable "satype" { 
    description = "Type of replication for storage account. GRS or LRS"
    type = "map"
    default = {
        "DEV" = "LRS"
        "TST" = "LRS"
        "UAT" = "LRS"
        "PRE" = "RAGRS"
        "PRD" = "RAGRS"
    }
}
variable "addaccount" {
	description = "Name of the account with privs to create service accounts"
	type = "map"
	default = {
		"UK" = "Azure-SVC-Account"
		"ILMS" = "adadministrator"
		"ILMSDEV" = "adadministrator"
    "BASTION" = "InfraAdmin"
  }
}

variable "addcomputer" {
	description = "Name of the account with privs to create computer accounts"
	type = "map"
	default = {
		"UK" = "addcomputer"
		"ILMS" = "adadministrator"
		"ILMSDEV" = "adadministrator"
		"BASTION" = "InfraAdmin"
  }
}
module "getbuildsecrets" {
    source          = "../../../getkeyvaultsecret/v1"
    secretname      = ["SQLIaaSAdmin","JobListUpload","${lookup(var.addaccount, var.domain)}","${lookup(var.addcomputer, var.domain)}"]
}

resource "azurerm_storage_account" "sqlbackupssa" {
  name                     = "${lower(var.application)}${lower(var.env)}sqlbackups"
  resource_group_name      = "${var.resourcegroup}"
  location                 = "${lookup(var.salocation, var.location, "UK West")}"
  account_tier             = "Standard"
  account_kind             = "StorageV2" 
  account_replication_type = "${lookup(var.satype, var.env, "LRS")}"
}
resource "azurerm_storage_container" "sqlbackups" {
  name                  = "sqlbackups"
  resource_group_name   = "${var.resourcegroup}"
  storage_account_name  = "${azurerm_storage_account.sqlbackupssa.name}"
  container_access_type = "private"
}
data "azurerm_storage_account_sas" "sqlbackupssas" {
  connection_string = "${azurerm_storage_account.sqlbackupssa.primary_connection_string}"
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = "${timeadd(timestamp(), "-5m")}"
  expiry = "${timeadd(timestamp(), "100000h")}"

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = false
    create  = false
    update  = false
    process = false
  }
}

output "SAURL" {
  value = "${azurerm_storage_account.sqlbackupssa.primary_blob_endpoint}"
}

resource "azurerm_virtual_machine_extension" "sqlconfig" {
    count                   = "${var.vmcount}"
    name                    = "SQLConfig"
    location                = "${var.location}"
    resource_group_name     = "${var.resourcegroup}"
    virtual_machine_name    = "${element(var.hostname, count.index)}"
    publisher               = "Microsoft.Compute"
    type                    = "CustomScriptExtension"
    type_handler_version    = "1.9"
    settings = <<SETTINGS
    {
      "fileUris": [
        "https://yourstgacc.blob.core.windows.net/sqlpostbuild/SQL-Config.ps1",
        "https://yourstgacc.blob.core.windows.net/sqlpostbuild/Bootstrap.ps1",
        "https://yourstgacc.blob.core.windows.net/sqlpostbuild/Live Scripts.zip",
        "https://yourstgacc.blob.core.windows.net/sqlpostbuild/AzureRM.zip",
        "https://yourstgacc.blob.core.windows.net/sqlpostbuild/SqlServer.zip"
      ]
    }
SETTINGS
    protected_settings = <<PROTECTEDSETTINGS
    {
      "storageAccountName": "yourstgacc",
      "storageAccountKey": "yourkey",
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File Bootstrap.ps1 -SSRSEnabled ${var.ssrsenabled} -SSASEnabled ${var.ssasenabled} -SSISEnabled ${var.ssisenabled} -adminPassword ${element(module.getbuildsecrets.secretvalue,0)} -adminUsername ${element(module.getbuildsecrets.secretname,0)} -SQLBackupURL [${azurerm_storage_account.sqlbackupssa.primary_blob_endpoint}sqlbackups] -SQLBackupSAS \"${substr(data.azurerm_storage_account_sas.sqlbackupssas.sas,1,-1)}\" -SQLBackupSAKey ${azurerm_storage_account.sqlbackupssa.primary_access_key} -RequestedCollation ${var.sqlcollation} -SQLAuthentication ${var.sqlauthentication} -JobPwd ${element(module.getbuildsecrets.secretvalue,1)} -SvcAcc ${var.sqlag == "No" ? element(var.serviceacc,count.index) : element(var.serviceacc,0) } -SvcPwd \"${var.sqlag == "No" ? element(var.serviceaccpwd,count.index) : element(var.serviceaccpwd,0) }\" -AddAccount ${element(module.getbuildsecrets.secretname,2)} -AddAccountPwd \"${replace(element(module.getbuildsecrets.secretvalue,2),"\\","\\\\")}\" -sqlag \"${var.sqlag}\" -AddComputer ${element(module.getbuildsecrets.secretname,3)} -AddComputerPwd ${element(module.getbuildsecrets.secretvalue,3)}"
    }
PROTECTEDSETTINGS
}

output "vmnamestr" {
  value = "${join(",", azurerm_virtual_machine_extension.sqlconfig.*.virtual_machine_name)}"
}

output "vmnamelist" {
  value = ["${azurerm_virtual_machine_extension.sqlconfig.*.virtual_machine_name}"]
}

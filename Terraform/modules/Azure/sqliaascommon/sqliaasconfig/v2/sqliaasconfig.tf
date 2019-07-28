variable "location" {}
variable "vmcount" {}
#variable "serverseed" {}
variable "hostname" {type = "list"}
# variable "vmid" {type = "list"}
# variable "logdiskid" {type = "list"}
variable "resourcegroup" {}
variable "env" {}
variable "application" {}
variable "ssrsenabled" {}
variable "ssisenabled" {}
variable "ssasenabled" {}
variable "sqlcollation" {}
variable "sqlauthentication" {}
variable "domain" {}
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
locals {
  serviceaccts = "${formatlist("%s-1-SVC",var.hostname)}"
  agserviceacct = "${upper(var.application)}${upper(var.env)}SQL-1-SVC"
}
data "azurerm_key_vault_secret" "sqliaasadmin" {
  name      = "yourname"
  vault_uri = "https://yourvault.vault.azure.net/"
}
data "azurerm_key_vault_secret" "JobListUpload" {
  name      = "yourname"
  vault_uri = "https://yourvault.vault.azure.net/"
}

/* resource "random_string" "sqlserviceacctpassword" {
  count                   = "${var.vmcount}"
  length                  = 25
  special                 = true
}

resource "azurerm_key_vault_secret" "svcacctpwd" {
  count                   = "${var.vmcount}"
  name                    = "${element(var.hostname, count.index)}-1-SVC"
  value                   = "${element(random_string.sqlserviceacctpassword.*.result, count.index)}"
  vault_uri               = "https://yourvault.vault.azure.net/"
  tags {
    Domain = "${var.domain}"
  }
} */

data "azurerm_key_vault_secret" "svcacctpwd" {
  count                   = "${var.vmcount}"
  #name                    = "${element(var.hostname, count.index)}-1-SVC"
  name                    = "${var.sqlag == "No" ? element(local.serviceaccts, count.index) : local.agserviceacct}"
  vault_uri               = "https://yourvault.vault.azure.net/"
}

data "azurerm_key_vault_secret" "addaccount" {
  name                    = "youraccount"
  vault_uri               = "https://yourvault.vault.azure.net/"
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

# output "SAKey1" {
#   value = "${azurerm_storage_account.sqlbackupssa.primary_access_key}"
# }
# output "SAsas" {
#   value = "${substr(data.azurerm_storage_account_sas.sqlbackupssas.sas,1,-1)}"
# }
output "SAURL" {
  value = "${azurerm_storage_account.sqlbackupssa.primary_blob_endpoint}"
}

resource "azurerm_virtual_machine_extension" "ssesqlconfig" {
    count                   = "${var.vmcount}"
    #depends_on              = ["azurerm_virtual_machine_data_disk_attachment.externallogs"]
    name                    = "SQLConfig"
    location                = "${var.location}"
    resource_group_name     = "${var.resourcegroup}"
    virtual_machine_name    = "${element(var.hostname, count.index)}"
    publisher               = "Microsoft.Compute"
    type                    = "CustomScriptExtension"
    type_handler_version    = "1.9"
    # tags {
    #   DomainJoin = "${var.domainjoin == "Yes" ? "${element(var.dependson, count.index)}" : "NotDomainJoined" }"
    # }

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
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File Bootstrap.ps1 -SSRSEnabled ${var.ssrsenabled} -SSASEnabled ${var.ssasenabled} -SSISEnabled ${var.ssisenabled} -adminPassword ${data.azurerm_key_vault_secret.sqliaasadmin.value} -adminUsername ${data.azurerm_key_vault_secret.sqliaasadmin.name} -SQLBackupURL [${azurerm_storage_account.sqlbackupssa.primary_blob_endpoint}sqlbackups] -SQLBackupSAS \"${substr(data.azurerm_storage_account_sas.sqlbackupssas.sas,1,-1)}\" -SQLBackupSAKey ${azurerm_storage_account.sqlbackupssa.primary_access_key} -RequestedCollation ${var.sqlcollation} -SQLAuthentication ${var.sqlauthentication} -JobPwd ${data.azurerm_key_vault_secret.JobListUpload.value} -SvcAcc ${var.sqlag == "No" ? element(data.azurerm_key_vault_secret.svcacctpwd.*.name,count.index) : element(data.azurerm_key_vault_secret.svcacctpwd.*.name,1) } -SvcPwd \"${var.sqlag == "No" ? element(data.azurerm_key_vault_secret.svcacctpwd.*.value,count.index) : element(data.azurerm_key_vault_secret.svcacctpwd.*.value,1) }\" -AddAccountPwd \"${replace(data.azurerm_key_vault_secret.addaccount.value,"\\","\\\\")}\" -sqlag \"${var.sqlag}\""
    }
PROTECTEDSETTINGS
}

output "vmnamestr" {
  value = "${join(",", azurerm_virtual_machine_extension.ssesqlconfig.*.virtual_machine_name)}"
}

output "vmnamelist" {
  value = ["${azurerm_virtual_machine_extension.ssesqlconfig.*.virtual_machine_name}"]
}

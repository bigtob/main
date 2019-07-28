variable "resourcegroup" {}
variable "containername" {}
variable "stgacctname" {}
variable "connectionstring" {}
variable "containertype" {  
  description = "Type of container. One of:"
  description = "blob"
  description = "queue"
  description = "table"
  description = "file"
}
    
resource "azurerm_storage_container" "blobcontainer" {
  name                  = "${var.containername}"
  resource_group_name   = "${var.resourcegroup}"
  storage_account_name  = "${var.stgacctname}"
  container_access_type = "private"
}
data "azurerm_storage_account_sas" "containersas" {
  connection_string = "${var.connectionstring}"
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = "true"
    queue = "false"
    table = "false"
    file  = "false"
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

output "stgacctsas" {
  value = "${substr(data.azurerm_storage_account_sas.containersas.sas,1,-1)}"
}

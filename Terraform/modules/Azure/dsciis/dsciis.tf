variable "location" {}
variable "hostname" {}
variable "resourcegroup" {}
variable "iiscount" {}
variable "environment" {}
variable "serverseed" {}
variable "vmname" { type = "list" }

# Use DSC extension to install IIS
resource "azurerm_virtual_machine_extension" "dsciis" {
  #name				         = "dsciis${var.hostname}${var.serverseed + count.index}"
  name                 = "${element(var.vmname, count.index)}"
  location             = "${var.location}"
  resource_group_name  = "${var.resourcegroup}"
  #virtual_machine_name = "${var.hostname}${var.serverseed + count.index}"
  virtual_machine_name = "${element(var.vmname, count.index)}"
  publisher            = "Microsoft.Powershell"
  type                 = "DSC"
  type_handler_version = "2.20"
  count                = "${var.iiscount}"

  settings = <<SETTINGS
    {
        "configuration": {
            
            "url": "https://yourstgacct.blob.core.windows.net/scripts/dsc-iis.zip",
			"script": "dsc-iis.ps1",
            "function": "Main"
          },
          "configurationArguments": {
              "nodeName": "${element(var.vmname, count.index)}"
           }
    }
SETTINGS
	  protected_settings = <<SETTINGS
			{
              "configurationUrlSasToken": "yourtoken"
            }
SETTINGS

  tags {
    environment = "${var.environment}"
  }
  #depends_on = ["${var.hostname}${var.serverseed + count.index}"]
}

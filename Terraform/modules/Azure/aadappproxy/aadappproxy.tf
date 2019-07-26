# Retrieve the addcomputer  secrets
  data "azurerm_key_vault_secret" "appproxy" {
  name      = "addcomputer"
  vault_uri = "https://yourvault.vault.azure.net/"
}

# Use DSC extension to install IIS
resource "azurerm_virtual_machine_extension" "appproxy" {
  name				         = "appproxy${var.host_name}${var.serverseed}"
  location             = "${var.location}"
  resource_group_name  = "${var.resource_group}"
  virtual_machine_name = "${var.host_name}${var.serverseed}"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
		"fileUris": [
             "https://yourstgacct.blob.core.windows.net/install/appproxy.ps1","https://yourstgacct.blob.core.windows.net/install/AADApplicationProxyConnectorInstaller.exe"
             ],
		"commandToExecute": "powershell -ExecutionPolicy Unrestricted -File appproxy.ps1", 
        "configurationArguments": {
              "nodeName": "${var.host_name}${var.serverseed}"
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
  #depends_on = ["${var.host_name}${var.serverseed}"]
}

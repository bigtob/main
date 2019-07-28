variable "location" {}
variable "vmcount" {}
variable "hostname" {}
variable "resourcegroup" {}
#variable "serverseed" {}

/* 
"Enable": false,
"DayOfWeek": "Sunday",
"MaintenanceWindowStartingHour": "2",
"MaintenanceWindowDuration": "60" 
*/
resource "azurerm_template_deployment" "SQLIaaSExtension" {
  #count                 = "${var.vmcount}"
  name                  = "SQLIaaSExtension"
  resource_group_name   = "${var.resourcegroup}"
 
  template_body = <<DEPLOY
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "virtualMachineName":{
      "type":"string"
    },
    "location":{
      "type":"string"
    },
    "resourcegroup":{
        "type":"string"
    }
  },
  "variables": {
      "existingVMListArray": "[split(parameters('virtualMachineName'),',')]"
  },
  "resources":[
    {
      "name": "[trim(variables('existingVMListArray')[copyIndex()])]",
      "type": "Microsoft.SqlVirtualMachine/SqlVirtualMachines",
      "apiVersion": "2017-03-01-preview",
      "location": "[parameters('location')]",
      "copy": {
        "name": "sqlvirtualMachineLoop",
        "count": "[length(variables('existingVMListArray'))]"
        },
      "properties": {
          "virtualMachineResourceId": "[resourceId(parameters('resourcegroup'), 'Microsoft.Compute/virtualMachines', trim(variables('existingVMListArray')[copyIndex()]))]",
          "AutoPatchingSettings": {
              "Enable": false
          },
          "KeyVaultCredentialSettings": {
              "Enable": false,
              "CredentialName": ""
          },
          "ServerConfigurationsManagementSettings": {
              "SQLConnectivityUpdateSettings": {
                  "ConnectivityType": "private",
                  "Port": 1433
              },
              "SQLWorkloadTypeUpdateSettings": {
                  "SQLWorkloadType": "General"
              },
              "SQLStorageUpdateSettings": {
                  "DiskCount": "1",
                  "NumberOfColumns": "1",
                  "StartingDeviceID": "2",
                  "DiskConfigurationType": "NEW"
              },
              "AdditionalFeaturesServerConfigurations": {
                  "IsRServicesEnabled": "false"
              }
          }
      }
    }
  ],
  "outputs": {
    "virtualMachineName": {
      "type": "string",
      "value": "[parameters('virtualMachineName')]"
    }
  }
}
DEPLOY
# these key-value pairs are passed into the ARM Template's `parameters` block
  parameters {
    "location" = "${var.location}"
    #"virtualMachineName" = "${element(var.hostname, count.index)}"
    "virtualMachineName" = "${var.hostname}"
    #"virtualMachineName" = "${format("${var.hostname}%06d", var.serverseed + count.index)}"
    "resourcegroup" = "${var.resourcegroup}"
  }
  deployment_mode = "Incremental"
}

output "virtualmachinename" {
  value = "${split(",",azurerm_template_deployment.SQLIaaSExtension.outputs["virtualMachineName"])}"
}


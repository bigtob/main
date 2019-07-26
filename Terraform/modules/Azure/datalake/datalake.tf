#---------------------------------------------------------------------------------------
# Call to build a 'Data Lake Store'
#---------------------------------------------------------------------------------------
# .SYNOPSIS
#
# Resource is deployed via .TF wrapped ARM template . SA needs be set to Gen2 which is set by "isHnsEnabled": "true" 
# This feature is not available in the native .TF resource
# This example is passed a number of subnet id's and also uses inline data objects 
# This allows us to enable the firewall and create the appropriate exceptions
# The ARM template and variable defintiions will require modifcation dependent on how many subnets are required
# Edit the ARM templates "virtualNetworkRules" section 
# Note the machine you are deploying on also requires adding to the FW hence the 'myip' setting
#---------------------------------------------------------------------------------------

# '''''''''''''''''''''
# Variable Definition
# '''''''''''''''''''''

# DataLake Details
variable "location" {}
variable "datalakename" {}


# Passed Subnets
variable "cbdhdpsubnetid" {}  
variable "cbdsubnetid" {}     
variable "runtimesubnetid" {} 
variable "rdpsubnetid" {}

# '''''''''''''''''''''
# Resources
# '''''''''''''''''''''
resource "random_string" "randomId" {
  length  = 8
  special = false
  upper   = false

  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${var.resourcegroupname}"
  }
}

# Get this machines IP 
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "azurerm_template_deployment" "analyticsdatalakesa" {
  name                = "analyticsdatalakesa"
  resource_group_name = "${var.resourcegroupname}"

  template_body = <<DEPLOY
{
    "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {
            "type": "string"
        },
        "storageAccountName": {
            "type": "string"
        },
        "accountType": {
            "type": "string"
        },
        "kind": {
            "type": "string"
        },
        "accessTier": {
            "type": "string"
        },
        "cbdhdpsubnetid": {
            "type": "string"
        },
        "cbdsubnetid": {
            "type": "string"
        },
        "rdpsubnetid": {
            "type": "string"
        },
        "runtimesubnetid": {
            "type": "string"
        },
        "subnetpriv": {
            "type": "string"
        },
        "subnetpub": {
            "type": "string"
        },
        "deployip": {
            "type": "string"
        }
    },
    "variables": {},
    "resources": [
        {
            "name": "[parameters('storageAccountName')]",
            "type": "Microsoft.Storage/storageAccounts",
            "apiVersion": "2018-07-01",
            "location": "[parameters('location')]",
            "properties": {
                "accessTier": "[parameters('accessTier')]",
                                "networkAcls": {
                    "bypass": "AzureServices",
                    "virtualNetworkRules": [
                        {
                            "id": "[parameters('cbdhdpsubnetid')]",
                            "action": "Allow",
                            "state": "Succeeded"
                        },
                        {
                            "id": "[parameters('cbdsubnetid')]",
                            "action": "Allow",
                            "state": "Succeeded"
                        },
                        {
                            "id": "[parameters('rdpsubnetid')]",
                            "action": "Allow",
                            "state": "Succeeded"
                        },
                        {
                            "id": "[parameters('runtimesubnetid')]",
                            "action": "Allow",
                            "state": "Succeeded"
                        },
                        {
                            "id": "[parameters('subnetpriv')]",
                            "action": "Allow",
                            "state": "Succeeded"
                        },
                        {
                            "id": "[parameters('subnetpub')]",
                            "action": "Allow",
                            "state": "Succeeded"
                        }
                    ],
                    "ipRules": [
                        {
                            "value": "[parameters('deployip')]",
                            "action": "Allow"
                        }
                    ],
                    "defaultAction": "Deny"
                },
                "supportsHttpsTrafficOnly": "true",
                "isHnsEnabled": "true"
            },
            "dependsOn": [],
            "sku": {
                "name": "[parameters('accountType')]"
            },
            "kind": "[parameters('kind')]"
        }
    ],
    "outputs": {}
}
DEPLOY

  # these key-value pairs are passed into the ARM Template's `parameters` block

  parameters {
    "location"           = "${var.location}"
    "storageAccountName" = "${lower(random_string.randomId.result)}${var.datalakename}"
    "accountType"        = "Standard_RAGRS"
    "kind"               = "StorageV2"
    "accessTier"         = "Hot"
    "deployip"           = "${chomp(data.http.myip.body)}"
    "cbdhdpsubnetid"     = "${var.cbdhdpsubnetid}"
    "cbdsubnetid"        = "${var.cbdsubnetid}"
    "rdpsubnetid"        = "${var.rdpsubnetid}"
    "runtimesubnetid"    = "${var.runtimesubnetid}"
    "subnetpriv"         = "${data.azurerm_subnet.subnetpriv.id}"
    "subnetpub"          = "${data.azurerm_subnet.subnetpub.id}"
  }
  deployment_mode = "Incremental"
}

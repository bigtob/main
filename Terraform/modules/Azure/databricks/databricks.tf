
#---------------------------------------------------------------------------------------
# Call to build a Databricks Service with NSG and Subnets and inject into an existing VNET
#---------------------------------------------------------------------------------------
# .SYNOPSIS
#
# This utilises a modified ARM template. Source :
# https://github.com/Azure/azure-quickstart-templates/blob/master/101-databricks-all-in-one-template-for-vnet-injection/azuredeploy.json 
# This allows us to modify the subnet service endpoints which we cannot do with native .TF resource
# This module require a pre-created empty vnet in which it will create the subnets used by DataBricks
# For quick guide please see : 
# https://docs.azuredatabricks.net/administration-guide/cloud-configurations/azure/vnet-inject.html#all-in-one
##---------------------------------------------------------------------------------------

# '''''''''''''''''''''
# Variable Definition
# '''''''''''''''''''''

# Vnet Details
variable "dbvnetname"{}
variable "dbvnetresourcegroupname" {}

# DataBrick Details
variable "databricksname" {}
variable "resourcegroupname" {}
variable "publiccidr" {}
variable "privatecidr" {}


# '''''''''''''''''''''
# Resources
# '''''''''''''''''''''

data "azurerm_virtual_network" "dbvnet" {
  name                = "${var.dbvnetname}"
  resource_group_name = "${var.dbvnetresourcegroupname}"
}

resource "azurerm_template_deployment" "analyticsdatabricks" {
  name                = "${var.databricksname}"
  resource_group_name = "${var.resourcegroupname}"

  template_body = <<DEPLOY
{
    "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "vnetName": {
            "type": "string"
        },
        "vnetRG": {
            "type": "string"
        },
        "vnetId": {
            "type": "string"
        },
        "publicSubnetName": {
            "type": "string"
        },
        "publicSubnetCIDR": {
            "type": "string"
        },
        "privateSubnetName": {
            "type": "string"
        },
        "privateSubnetCIDR": {
            "type": "string"
        },
        "workspaceName": {
            "type": "string"
        },
        "tier": {
            "defaultValue": "premium",
            "type": "string"
        },
        "location": {
            "type": "string"
        }
    },
    "resources": [
        {
            "apiVersion": "2018-02-01",
            "type": "Microsoft.Network/networkSecurityGroups",
            "location": "[parameters('location')]",
            "name": "[variables('nsgName')]",
            "properties": {
                "securityRules": [
                    {
                        "name": "databricks-worker-to-worker",
                        "properties": {
                            "access": "Allow",
                            "description": "Required for worker nodes communication within a cluster.",
                            "destinationAddressPrefix": "*",
                            "destinationPortRange": "*",
                            "direction": "Inbound",
                            "priority": 200,
                            "protocol": "*",
                            "sourceAddressPrefix": "VirtualNetwork",
                            "sourcePortRange": "*"
                        }
                    },
                    {
                        "name": "databricks-control-plane-ssh",
                        "properties": {
                            "access": "Allow",
                            "description": "Required for Databricks control plane management of worker nodes.",
                            "destinationAddressPrefix": "*",
                            "destinationPortRange": "22",
                            "direction": "Inbound",
                            "priority": 100,
                            "protocol": "*",
                            "sourceAddressPrefix": "[variables('controlPlaneIp')]",
                            "sourcePortRange": "*"
                        }
                    },
                    {
                        "name": "databricks-control-plane-worker-proxy",
                        "properties": {
                            "access": "Allow",
                            "description": "Required for Databricks control plane communication with worker nodes.",
                            "destinationAddressPrefix": "*",
                            "destinationPortRange": "5557",
                            "direction": "Inbound",
                            "priority": 110,
                            "protocol": "*",
                            "sourceAddressPrefix": "[variables('controlPlaneIp')]",
                            "sourcePortRange": "*"
                        }
                    },
                    {
                        "name": "databricks-worker-to-webapp",
                        "properties": {
                            "access": "Allow",
                            "description": "Required for workers communication with Databricks Webapp.",
                            "destinationAddressPrefix": "[variables('webappIp')]",
                            "destinationPortRange": "*",
                            "direction": "Outbound",
                            "priority": 100,
                            "protocol": "*",
                            "sourceAddressPrefix": "*",
                            "sourcePortRange": "*"
                        }
                    },
                    {
                        "name": "databricks-worker-to-sql",
                        "properties": {
                            "access": "Allow",
                            "description": "Required for workers communication with Azure SQL services.",
                            "destinationAddressPrefix": "Sql",
                            "destinationPortRange": "*",
                            "direction": "Outbound",
                            "priority": 110,
                            "protocol": "*",
                            "sourceAddressPrefix": "*",
                            "sourcePortRange": "*"
                        }
                    },
                    {
                        "name": "databricks-worker-to-storage",
                        "properties": {
                            "access": "Allow",
                            "description": "Required for workers communication with Azure Storage services.",
                            "destinationAddressPrefix": "Storage",
                            "destinationPortRange": "*",
                            "direction": "Outbound",
                            "priority": 120,
                            "protocol": "*",
                            "sourceAddressPrefix": "*",
                            "sourcePortRange": "*"
                        }
                    },
                    {
                        "name": "databricks-worker-to-worker-outbound",
                        "properties": {
                            "access": "Allow",
                            "description": "Required for worker nodes communication within a cluster.",
                            "destinationAddressPrefix": "VirtualNetwork",
                            "destinationPortRange": "*",
                            "direction": "Outbound",
                            "priority": 130,
                            "protocol": "*",
                            "sourceAddressPrefix": "*",
                            "sourcePortRange": "*"
                        }
                    },
                    {
                        "name": "databricks-worker-to-any",
                        "properties": {
                            "access": "Allow",
                            "description": "Required for worker nodes communication with any destination.",
                            "destinationAddressPrefix": "*",
                            "destinationPortRange": "*",
                            "direction": "Outbound",
                            "priority": 140,
                            "protocol": "*",
                            "sourceAddressPrefix": "*",
                            "sourcePortRange": "*"
                        }
                    }
                ]
            }
        },
        {
            "apiVersion": "2017-05-10",
            "name": "nestedTemplate",
            "type": "Microsoft.Resources/deployments",
            "dependsOn": [
                "[concat('Microsoft.Network/networkSecurityGroups/', variables('nsgName'))]"
            ],
            "resourceGroup": "[parameters('vnetRG')]",
            "properties": {
                "mode": "Incremental",
                "template": {
                    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {},
                    "variables": {},
                    "resources": [
                        {
                            "apiVersion": "2018-04-01",
                            "type": "Microsoft.Network/virtualNetworks/subnets",
                            "name": "[concat(parameters('vnetName'), '/', parameters('publicSubnetName'))]",
                            "location": "[parameters('location')]",
                            "properties": {
                                "addressPrefix": "[parameters('publicSubnetCIDR')]",
                                "networkSecurityGroup": {
                                    "id": "[variables('nsgId')]"
                                },
                                    "serviceEndpoints": [
                                        {
                                        "service": "Microsoft.Storage",
                                        "locations": [
                                        "uksouth",
                                        "ukwest"
                                        ]
                                        }
                                        ]
                                }
                            },
                        {
                            "apiVersion": "2018-04-01",
                            "type": "Microsoft.Network/virtualNetworks/subnets",
                            "name": "[concat(parameters('vnetName'), '/', parameters('privateSubnetName'))]",
                            "location": "[parameters('location')]",
                            "dependsOn": [
                                "[concat('Microsoft.Network/virtualNetworks/', parameters('vnetName'), '/subnets/', parameters('publicSubnetName'))]"
                            ],
                            "properties": {
                                "addressPrefix": "[parameters('privateSubnetCIDR')]",
                                "networkSecurityGroup": {
                                    "id": "[variables('nsgId')]"
                                },
                                "serviceEndpoints": [
                                    {
                                    "service": "Microsoft.Storage",
                                    "locations": [
                                    "uksouth",
                                    "ukwest"
                                    ]
                                    }
                                    ]
                            }
                        }
                    ]
                },
                "parameters": {}
            }
        },
        {
            "apiVersion": "2018-04-01",
            "type": "Microsoft.Databricks/workspaces",
            "location": "[parameters('location')]",
            "name": "[parameters('workspaceName')]",
            "dependsOn": [
                "[concat('Microsoft.Network/networkSecurityGroups/', variables('nsgName'))]",
                "['Microsoft.Resources/deployments/nestedTemplate']"
            ],
            "sku": {
                "name": "[parameters('tier')]"
            },
            "comments": "Please do not use an existing resource group for ManagedResourceGroupId.",
            "properties": {
                "ManagedResourceGroupId": "[variables('managedResourceGroupId')]",
                "parameters": {
                    "customVirtualNetworkId": {
                        "value": "[parameters('vnetId')]"
                    },
                    "customPublicSubnetName": {
                        "value": "[parameters('publicSubnetName')]"
                    },
                    "customPrivateSubnetName": {
                        "value": "[parameters('privateSubnetName')]"
                    }
                }
            }
        }
    ],
    "variables": {
        "azureRegionToControlPlaneIp": {
            "australiacentral": "13.70.105.50/32",
            "australiacentral2": "13.70.105.50/32",
            "australiaeast": "13.70.105.50/32",
            "australiasoutheast": "13.70.105.50/32",
            "canadacentral": "40.85.223.25/32",
            "canadaeast": "40.85.223.25/32",
            "centralindia": "104.211.101.14/32",
            "centralus": "23.101.152.95/32",
            "eastasia": "52.187.0.85/32",
            "eastus": "23.101.152.95/32",
            "eastus2": "23.101.152.95/32",
            "eastus2euap": "23.101.152.95/32",
            "japaneast": "13.78.19.235/32",
            "japanwest": "13.78.19.235/32",
            "northcentralus": "23.101.152.95/32",
            "northeurope": "23.100.0.135/32",
            "southcentralus": "40.83.178.242/32",
            "southeastasia": "52.187.0.85/32",
            "southindia": "104.211.101.14/32",
            "uksouth": "51.140.203.27/32",
            "ukwest": "51.140.203.27/32",
            "westcentralus": "40.83.178.242/32",
            "westeurope": "23.100.0.135/32",
            "westindia": "104.211.101.14/32",
            "westus": "40.83.178.242/32",
            "westus2": "40.83.178.242/32"
        },
        "azureRegionToWebappIp": {
            "australiacentral": "13.75.218.172/32",
            "australiacentral2": "13.75.218.172/32",
            "australiaeast": "13.75.218.172/32",
            "australiasoutheast": "13.75.218.172/32",
            "canadacentral": "13.71.184.74/32",
            "canadaeast": "13.71.184.74/32",
            "centralindia": "104.211.89.81/32",
            "centralus": "40.70.58.221/32",
            "eastasia": "52.187.145.107/32",
            "eastus": "40.70.58.221/32",
            "eastus2": "40.70.58.221/32",
            "eastus2euap": "40.70.58.221/32",
            "japaneast": "52.246.160.72/32",
            "japanwest": "52.246.160.72/32",
            "northcentralus": "40.70.58.221/32",
            "northeurope": "52.232.19.246/32",
            "southcentralus": "40.118.174.12/32",
            "southeastasia": "52.187.145.107/32",
            "southindia": "104.211.89.81/32",
            "uksouth": "51.140.204.4/32",
            "ukwest": "51.140.204.4/32",
            "westcentralus": "40.118.174.12/32",
            "westeurope": "52.232.19.246/32",
            "westindia": "104.211.89.81/32",
            "westus": "40.118.174.12/32",
            "westus2": "40.118.174.12/32"
        },
        "controlPlaneIp": "[variables('azureRegionToControlPlaneIp')[parameters('location')]]",
        "webappIp": "[variables('azureRegionToWebappIp')[parameters('location')]]",
        "managedResourceGroupId": "[concat(subscription().id, '/resourceGroups/', variables('managedResourceGroupName'))]",
        "managedResourceGroupName": "[concat('databricks-rg-', parameters('workspaceName'), '-', uniqueString(parameters('workspaceName'), resourceGroup().id))]",
        "nsgName": "[concat('databricksnsg', uniqueString(parameters('workspaceName')))]",
        "nsgId": "[resourceId('Microsoft.Network/networkSecurityGroups', variables('nsgName'))]"
    },
    "outputs": {}
}
DEPLOY

  # these key-value pairs are passed into the ARM Template's `parameters` block

  parameters {
    "workspaceName"     = "${var.databricksname}"
    "location"          = "uksouth"
    "vnetName"          = "${var.dbvnetname}"
    "vnetRG"            = "${var.dbvnetresourcegroupname}"
    "vnetId"            = "${data.azurerm_virtual_network.dbvnet.id}"
    "publicSubnetName"  = "private-subnet"
    "publicSubnetCIDR"  = "${var.publiccidr}"
    "privateSubnetName" = "public-subnet"
    "privateSubnetCIDR" = "${var.privatecidr}"
  }
  deployment_mode = "Incremental"
}

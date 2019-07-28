variable "location" {}
variable "application" {}
variable "hostname" {type = "list"}
variable "env" {}
variable "resourcegroup" {}
variable "sqlversion" {}
variable "sqlserversku" {}
variable "domain" {}
variable "saaccount" {}
variable "saaccountpwd" {}

variable "djname" {
	description = "Name of the domain"
	type = "map"
	default = {
		"Domain1" = "domain1.local"
		"Domain2" = "domain2.local"
		"Domain3" = "domain3.local"
  }
}
variable "djupn" {
	description = "Name of the domain"
	type = "map"
	default = {
		"Domain1" = "domain1.local"
		"Domain2" = "domain2.local"
		"Domain3" = "domain3.local"
  }
}
variable "djuser" {
	description = "Name of the domain join user"
	type = "map"
	default = {
		"Domain1" = "User1"
		"Domain2" = "User2"
		"Domain3" = "User3"
  }
}
variable "djoupath" {
	description = "Name of the domain join user"
	type = "map"
	default = {
		"Domain1" = "OU=Servers,DC=domain1,DC=local"
		"Domain2" = "OU=Servers,DC=domain2,DC=local"
		"Domain3" = "OU=Servers,DC=domain3,DC=local"
  }
}

module "getaddcomputersecret" {
    source          = "../../../getkeyvaultsecret/v1"
    secretname      = ["${lookup(var.djuser,var.domain)}"]
}

resource "azurerm_template_deployment" "SQLIaaSWFC" {
  name                  = "SQLIaaSWFC"
  resource_group_name   = "${var.resourcegroup}"
 
  template_body = <<DEPLOY
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "FailoverClusterName": {
            "type": "String",
            "metadata": {
                "description": "Specify the Windows Failover Cluster Name"
            }
        },
        "existingVmList": {
            "type": "String",
            "metadata": {
                "description": "Specify comma separated list of names of SQL Server VM's to participate in the Availability Group (e.g. SQLVM1, SQLVM2). OS underneath should be at least WS 2016."
            }
        },
        "existingVmResourceGroup": {
            "defaultValue": "[resourceGroup().name]",
            "type": "String",
            "metadata": {
                "description": "Specify resourcegroup name for existing Vms."
            }
        },
        "SqlServerVersion": {
            "allowedValues": [
                "SQL2017",
                "SQL2016"
            ],
            "type": "String",
            "metadata": {
                "description": "Select the version of SQL Server present on all VMs in the list"
            }
        },
        "SqlServerSku" : {
            "allowedValues": [
                "Enterprise",
                "Standard"
            ],
            "type": "String",
            "metadata": {
                "description": "Select the Edition of SQL Server present on all VMs in the list"
            }
        },
        "existingFullyQualifiedDomainName": {
            "type": "String",
            "metadata": {
                "description": "Specify the Fully Qualified Domain Name under which the Failover Cluster will be created. The VM's should already be joined to it. (e.g. contoso.com)"
            }
        },
        "existingOuPath": {
            "defaultValue": "",
            "type": "String",
            "metadata": {
                "description": "Specify an optional Organizational Unit (OU) on AD Domain where the CNO (Computer Object for Cluster Name) will be created (e.g. OU=testou,OU=testou2,DC=contoso,DC=com). Default is empty."
            }
        },
        "existingDomainAccount": {
            "type": "String",
            "metadata": {
                "description": "Specify the account for WS failover cluster creation in UPN format (e.g. example@contoso.com). This account can either be a Domain Admin or at least have permissions to create Computer Objects in default or specified OU."
            }
        },
        "DomainAccountPassword": {
            "type": "SecureString",
            "metadata": {
                "description": "Specify the password for the domain account"
            }
        },
        "existingSqlServiceAccount": {
            "type": "String",
            "metadata": {
                "description": "Specify the domain account under which SQL Server service will run for AG setup in UPN format (e.g. sqlservice@contoso.com)"
            }
        },
        "SqlServicePassword": {
            "type": "SecureString",
            "metadata": {
                "description": "Specify the password for Sql Server service account"
            }
        },
        "CloudWitnessName": {
            "defaultValue": "[concat('clwitness', uniqueString(resourceGroup().id))]",
            "type": "String",
            "metadata": {
                "description": "Specify the name of the storage account to be used for creating Cloud Witness for Windows server failover cluster"
            }
        },
        "_artifactsLocation": {
            "defaultValue": "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-sql-vm-ag-setup",
            "type": "String",
            "metadata": {
                "description": "Location of resources that the script is dependent on such as linked templates and DSC modules"
            }
        },
        "_artifactsLocationSasToken": {
            "defaultValue": "",
            "type": "SecureString",
            "metadata": {
                "description": "The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated."
            }
        },
        "Location": {
            "defaultValue": "[resourceGroup().location]",
            "type": "String",
            "metadata": {
                "description": "Location for all resources."
            }
        }
    },
    "variables": {
        "existingVMListArray": "[split(parameters('existingVmList'),',')]",
        "GroupResourceId": "[resourceId('Microsoft.SqlVirtualMachine/SqlVirtualMachineGroups', parameters('FailoverClusterName'))]",
        "joinClusterTemplateURL": "[concat(parameters('_artifactsLocation'),'/nested/join-cluster.json',parameters('_artifactsLocationSasToken'))]"
    },
    "resources": [
        {
            "type": "Microsoft.SqlVirtualMachine/SqlVirtualMachines",
            "name": "[trim(variables('existingVMListArray')[copyIndex()])]",
            "apiVersion": "2017-03-01-preview",
            "location": "[parameters('Location')]",
            "copy": {
                "name": "sqlvirtualMachineLoop",
                "count": "[length(variables('existingVMListArray'))]"
            },
            "properties": {
                "virtualMachineResourceId": "[resourceId(parameters('existingVmResourceGroup'), 'Microsoft.Compute/virtualMachines', trim(variables('existingVMListArray')[copyIndex()]))]"
            }
        },
        {
            "type": "Microsoft.Storage/storageAccounts",
            "sku": {
                "name": "Standard_LRS"
            },
            "kind": "StorageV2",
            "name": "[parameters('CloudWitnessName')]",
            "apiVersion": "2018-07-01",
            "location": "[parameters('Location')]",
            "properties": {
                "accessTier": "Hot",
                "supportsHttpsTrafficOnly": true
            }
        },
        {
            "type": "Microsoft.SqlVirtualMachine/SqlVirtualMachineGroups",
            "name": "[parameters('FailoverClusterName')]",
            "apiVersion": "2017-03-01-preview",
            "location": "[parameters('Location')]",
            "properties": {
                "SqlImageOffer": "[concat(parameters('SqlServerVersion'),'-WS2016')]",
                "SqlImageSku": "[parameters('SqlServerSku')]",
                "WsfcDomainProfile": {
                    "DomainFqdn": "[parameters('existingFullyQualifiedDomainName')]",
                    "OuPath": "[parameters('existingOuPath')]",
                    "ClusterBootstrapAccount": "[parameters('existingDomainAccount')]",
                    "ClusterOperatorAccount": "[parameters('existingDomainAccount')]",
                    "SqlServiceAccount": "[parameters('existingSqlServiceAccount')]",
                    "StorageAccountUrl": "[reference(resourceId('Microsoft.Storage/storageAccounts', parameters('CloudWitnessName')), '2018-07-01').primaryEndpoints['blob']]",
                    "StorageAccountPrimaryKey": "[listKeys(resourceId('Microsoft.Storage/storageAccounts', parameters('CloudWitnessName')), '2018-07-01').keys[0].value]"
                }
            }
        },
        {
            "type": "Microsoft.Resources/deployments",
            "name": "joincluster",
            "apiVersion": "2017-05-10",
            "properties": {
                "mode": "Incremental",
                "templateLink": {
                    "uri": "[variables('joinClusterTemplateURL')]",
                    "contentVersion": "1.0.0.0"
                },
                "parameters": {
                    "existingVirtualMachineNames": {
                        "value": "[variables('existingVMListArray')]"
                    },
                    "Location": {
                        "value": "[parameters('Location')]"
                    },
                    "existingVmResourceGroup": {
                        "value": "[parameters('existingVmResourceGroup')]"
                    },
                    "GroupResourceId": {
                        "value": "[variables('GroupResourceId')]"
                    },
                    "DomainAccountPassword": {
                        "value": "[parameters('DomainAccountPassword')]"
                    },
                    "SqlServicePassword": {
                        "value": "[parameters('SqlServicePassword')]"
                    }
                }
            },
            "dependsOn": [
                "[parameters('FailoverClusterName')]",
                "[parameters('CloudWitnessName')]",
                "sqlvirtualMachineLoop"
            ]
        }
    ]
,
  "outputs": {
    "FailoverClusterName": {
      "type": "string",
      "value": "[parameters('FailoverClusterName')]"
    }
  }
}
DEPLOY
# these key-value pairs are passed into the ARM Template's `parameters` block
  parameters {
    "FailoverClusterName" = "cls${substr(var.application,0,min(6,length(var.application)))}${var.env}sql"
    "existingVmList" = "${join(",",var.hostname)}"
    "existingVmResourceGroup" = "${var.resourcegroup}"
    "SqlServerVersion" = "${substr(var.sqlversion, 0, 7)}"
    "SqlServerSku"  = "${var.sqlserversku}"
    "existingFullyQualifiedDomainName" = "${lookup(var.djname, var.domain)}"
	"existingOuPath" = "${lookup(var.djoupath, var.domain)}"
	"existingDomainAccount" = "${lookup(var.djuser, var.domain)}@${lookup(var.djname, var.domain)}"
    "domainAccountPassword" = "${element(module.getaddcomputersecret.secretvalue,0)}"
    "existingSqlServiceAccount" = "${var.saaccount}@${lookup(var.djupn, var.domain)}"
    "sqlServicePassword" = "${var.saaccountpwd}"
    "cloudWitnessName" = "clwitness${lower(var.application)}${lower(var.env)}sql"
    "location" = "${var.location}"
  }
  deployment_mode = "Incremental"
}
output "FailoverClusterName" {
    value = "${azurerm_template_deployment.SQLIaaSWFC.outputs["failoverClusterName"]}"
}


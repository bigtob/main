# Setup PowerShell environment (as admin)
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module PowerShellGet -Force
Install-Module -Name Az -AllowClobber
Set-ExecutionPolicy -ExecutionPolicy Unrestricted

# Connect to Azure with a browser sign in token
Connect-AzAccount

$credentials = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant b2ad35c6-030b-47d4-bfbf-b41a6859f311

# Subscription info
Get-AzSubscription

#Name       Id                                   TenantId                             State
#----       --                                   --------                             -----
#Free Trial 59685ae4-813b-4824-bca1-8e5be03ad959 b2ad35c6-030b-47d4-bfbf-b41a6859f311 Enabled

# Set Subscription context
Set-AzContext -SubscriptionId "59685ae4-813b-4824-bca1-8e5be03ad959"

# Deployment via PowerShell
New-AzResourceGroup -Name "test-rsg" -Location uksouth
New-AzResourceGroupDeployment -ResourceGroupName test-rsg -TemplateFile .\1vnet1subnet.json
New-AzResourceGroupDeployment -ResourceGroupName test-rsg -TemplateFile .\1vnet1subnet.json -TemplateParameterFile .\1vnet1subnet.parameters.json
New-AzResourceGroupDeployment -ResourceGroupName test-rsg -TemplateFile ".\Storage Account\storage.json" -TemplateParameterFile ".\Storage Account\storage.parameters.json"

New-AzResourceGroupDeployment -ResourceGroupName test-rsg -TemplateFile .\azuredeploy.json -TemplateParameterFile .\azuredeploy.parameters.json

# Delete Resource Group
Remove-AzResourceGroup -name "test-rsg" -Force

"virtualNetworkName": {
    "type": "string",
    "metadata": {
      "description": "Virtual Network name."
    }
  },
  "virtualNetworkAddressPrefix": {
    "type": "string",
    "metadata": {
      "description": "Virtual Network address prefix."
    }
  },
  "subnet1Prefix": {
    "type": "string",
    "metadata": {
      "description": "Subnet 1 prefix."
    }
  },
  "subnet1Name": {
    "type": "string",
    "metadata": {
      "description": "Subnet 1 name."
    }
  },
  "location": {
    "type": "string",
    "metadata": {
      "description": "Location for all resources."
    }
  },
  "storageAccountType": {
    "type": "string",
    "defaultValue": "Standard_LRS",
    "allowedValues": [
      "Standard_LRS",
      "Standard_GRS",
      "Standard_ZRS",
      "Premium_LRS"
    ],
    "metadata": {
      "description": "Storage Account type"
    }
  },
  "loadBalancerName": {
    "type": "string",
    "metadata": {
      "description": "Name for the load balancer."
    }
  }

  Fixing master parameter file
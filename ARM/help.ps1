################
## POWERSHELL ##
################

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
#Free Trial a b2ad35c6-030b-47d4-bfbf-b41a6859f311 Enabled

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

##############
### AZ CLI ###
##############
# Create Azure Container Registry
az acr create -n tobytestacr -g test-eastus-rsg --sku basic
az acr update -n tobytestacr --admin-enabled true

# AKS
az aks show
az aks install-cli # set path with $env:path += 'C:\Users\sleaz\.azure-kubectl'
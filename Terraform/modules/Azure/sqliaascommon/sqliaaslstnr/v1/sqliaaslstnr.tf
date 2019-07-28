variable "existingFailoverClusterName" {}
variable "application" {}
variable "hostname" {type = "list"}
variable "env" {}
variable "existingVnetResourcegroup" {}
variable "existingVnet" {}
variable "existingSubnet" {}
variable "existingInternalLoadBalancer" {}
variable "location" {}
variable "resourcegroup" {}
variable "vmcount" {}


data "azurerm_subnet" "subnetid" {
  name                 = "${var.existingSubnet}"
  virtual_network_name = "${var.existingVnet}"
  resource_group_name  = "${var.existingVnetResourcegroup}"
}

resource "azurerm_template_deployment" "SQLIaaSLstnr" {
  name                  = "SQLIaaSLstnr"
  resource_group_name   = "${var.resourcegroup}"
 
  template_body = <<DEPLOY
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "existingFailoverClusterName": {
            "type": "String",
            "metadata": {
                "description": "Specify the name of the failover cluster"
            }
        },
        "existingSqlAvailabilityGroup": {
            "type": "String",
            "metadata": {
                "description": "Specify the name of SQL Availability Group for which listener is being created"
            }
        },
        "existingVmList": {
            "type": "String",
            "metadata": {
                "description": "Specify the Virtual machine list participating in SQL Availability Group e.g. VM1, VM2. Maximum number is 6."
            }
        },
        "Listener": {
            "defaultValue": "aglistener",
            "type": "String",
            "metadata": {
                "description": "Specify a name for the listener for SQL Availability Group"
            }
        },
        "ListenerPort": {
            "defaultValue": 1433,
            "type": "Int",
            "metadata": {
                "description": "Specify the port for listener"
            }
        },
        "ListenerIp": {
            "defaultValue": "10.0.0.7",
            "type": "String",
            "metadata": {
                "description": "Specify the available private IP address for the listener from the subnet the existing Vms are part of."
            }
        },
        "existingVnetResourcegroup": {
            "defaultValue": "[resourcegroup().name]",
            "type": "String",
            "metadata": {
                "description": "Specify the resourcegroup for virtual network"
            }
        },
        "existingVnet": {
            "type": "String",
            "metadata": {
                "description": "Specify the virtual network for Listener IP Address"
            }
        },
        "existingSubnet": {
            "type": "String",
            "metadata": {
                "description": "Specify the subnet under Vnet for Listener IP address"
            }
        },
        "existingInternalLoadBalancer": {
            "type": "String",
            "metadata": {
                "description": "Name of existing internal load balancer for the AG listener. Choose Standard Sku if the VMs are not in an availability set."
            }
        },
        "ProbePort": {
            "defaultValue": 59999,
            "type": "Int",
            "metadata": {
                "description": "Specify the load balancer port number (e.g. 59999)"
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
        "LoadBalancerResourceId": "[resourceId('Microsoft.Network/loadBalancers', parameters('existingInternalLoadBalancer'))]",
        "SubnetResourceId": "[concat(resourceid(parameters('existingVnetResourcegroup'),'Microsoft.Network/virtualNetworks', parameters('existingVnet')), '/subnets/', parameters('existingSubnet'))]",
        "VmArray": "[split(parameters('existingVmList'),',')]",
        "VM0": "[if(less(0, length(variables('VmArray'))), createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(variables('VmArray')[0]))), json('[]'))]",
        "VM1": "[if(less(1, length(variables('VmArray'))), createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(variables('VmArray')[1]))), json('[]'))]",
        "VM2": "[if(less(2, length(variables('VmArray'))), createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(variables('VmArray')[2]))), json('[]'))]",
        "VM3": "[if(less(3, length(variables('VmArray'))), createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(variables('VmArray')[3]))), json('[]'))]",
        "VM4": "[if(less(4, length(variables('VmArray'))), createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(variables('VmArray')[4]))), json('[]'))]",
        "VM5": "[if(less(5, length(variables('VmArray'))), createArray(resourceId('Microsoft.SqlVirtualMachine/sqlVirtualMachines', trim(variables('VmArray')[5]))), json('[]'))]",
        "SqlVmResourceIdList": "[union(variables('VM0'), variables('VM1'), variables('VM2'), variables('VM3'), variables('VM4'), variables('VM5'))]"
    },
    "resources": [
        {
            "type": "Microsoft.SqlVirtualMachine/SqlVirtualMachineGroups/availabilityGroupListeners",
            "name": "[concat(parameters('existingFailoverClusterName'), '/', parameters('Listener'))]",
            "apiVersion": "2017-03-01-preview",
            "location": "[parameters('Location')]",
            "properties": {
                "AvailabilityGroupName": "[parameters('existingSqlAvailabilityGroup')]",
                "LoadBalancerConfigurations": [
                    {
                        "privateIPAddress": {
                            "IpAddress": "[parameters('ListenerIp')]",
                            "SubnetResourceId": "[variables('SubnetResourceId')]"
                        },
                        "LoadBalancerResourceId": "[variables('LoadBalancerResourceId')]",
                        "ProbePort": "[parameters('ProbePort')]",
                        "SqlVirtualMachineInstances": "[variables('SqlVmResourceIdList')]"
                    }
                ],
                "Port": "[parameters('ListenerPort')]"
            }
        }
    ]
}
DEPLOY
# these key-value pairs are passed into the ARM Template's `parameters` block
  parameters {
    "existingFailoverClusterName" = "${var.existingFailoverClusterName}"
    "existingSqlAvailabilityGroup" = "ag${substr(var.application,0,min(6,length(var.application)))}${var.env}"
    "existingVmList" = "${join(",",var.hostname)}"
    "Listener" = "lstnr${substr(var.application,0,min(6,length(var.application)))}${var.env}"
    "ListenerIp" = "${cidrhost(data.azurerm_subnet.subnetid.address_prefix, var.vmcount + 5)}"
    "existingVnetResourcegroup" = "${var.existingVnetResourcegroup}"
    "existingVnet" = "${var.existingVnet}"
    "existingSubnet" = "${var.existingSubnet}"
    "existingInternalLoadBalancer" = "${var.existingInternalLoadBalancer}"
    "location" = "${var.location}"
  }
  deployment_mode = "Incremental"
}

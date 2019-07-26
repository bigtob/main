variable "location" {}
variable "vmcount" {}
#variable "serverseed" {}
variable "hostname" {type = "list"}
variable "resourcegroup" {}
variable "csename" {}
variable "fileuris" {type = "list"}
variable "cmdtoexecute" {}

resource "azurerm_virtual_machine_extension" "customscriptextension" {
    count                   = "${var.vmcount}"
    #depends_on              = ["azurerm_virtual_machine_data_disk_attachment.externallogs"]
    name                    = "${var.csename}"
    location                = "${var.location}"
    resource_group_name     = "${var.resourcegroup}"
    virtual_machine_name    = "${element(var.hostname, count.index)}"
    publisher               = "Microsoft.Compute"
    type                    = "CustomScriptExtension"
    type_handler_version    = "1.9"
    # tags {
    #   DomainJoin = "${var.domainjoin == "Yes" ? "${element(var.dependson, count.index)}" : "NotDomainJoined" }"
    # }

    settings = <<SETTINGS
    {
        "fileUris": ["${join("\",\"",var.fileuris)}"]
    }
SETTINGS
    protected_settings = <<PROTECTEDSETTINGS
    {
        "commandToExecute": "${var.cmdtoexecute}",
        "storageAccountName": "yourstgacctname",
        "storageAccountKey": "yourstgacctkey"
    }
PROTECTEDSETTINGS
}

variable "rsgname" {}
variable "location" {}
variable "directorate" {}
variable "subdirectorate" {}
variable "costcentre" {}
variable "projectcode" {}
variable "irnumber" {}
variable "supportteam1" {}
variable "supportteam2" {}
variable "servicehours" {}
variable "lifecyclestatus" {}

resource "azurerm_resource_group" "rsg" {
  name     = "${var.rsgname}"
  location = "${var.location}"
  tags {
      BillingInfo     = "${var.directorate};${var.subdirectorate};${var.costcentre};${var.projectcode};${var.irnumber}"
      SupportInfo     = "${var.supportteam1};${var.supportteam2}"
      ServiceHours    = "${var.servicehours}"
      LifeCycleStatus = "${var.lifecyclestatus}"
  }
}
output "resourcegroupname" {
  value = "${azurerm_resource_group.rsg.name}"
}
output "resourcegrouplocation" {
  value = "${azurerm_resource_group.rsg.location}"
}

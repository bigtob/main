# This module will create and attach a managed disk
variable "hostname" {}
variable "location" {}
variable "resourcegroup" {}
variable "storageaccounttype" {}
variable "lunnumber" {}
variable "size" {}
variable "virtualmachineid" {}
resource "azurerm_managed_disk" "disk" {
    #name                 = "${var.hostname}-Disk-01"
    name                 = "${var.hostname}-Disk-0${var.lunnumber}"
    location             = "${var.location}"
    resource_group_name  = "${var.resourcegroup}"
    storage_account_type = "${var.storageaccounttype}"
    create_option        = "Empty"
    disk_size_gb         = "${var.size}"
}  
resource "azurerm_virtual_machine_data_disk_attachment" "attach" {
  managed_disk_id    = "${azurerm_managed_disk.disk.id}"
  virtual_machine_id = "${var.virtualmachineid}"
  lun                = "${var.lunnumber}"
  caching            = "None"
}
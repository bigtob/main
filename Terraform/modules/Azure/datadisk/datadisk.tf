resource "azure_data_disk" "data" {
  lun                  = "${var.disklun}"
  size                 = "${var.disksize}"
  label                = "${var.diskname}"
  virtual_machine      = "${var.virtualmachine}"
}
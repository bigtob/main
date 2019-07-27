variable "resourcegroup" {}
variable "servername" {}
variable "databasenames" {
  type = "list"
}

resource "azurerm_postgresql_database" "postgresqldb" {
    count               = "${length(var.databasenames)}"
    name                = "${element(var.databasenames, count.index)}"
    resource_group_name = "${var.resourcegroup}"
    server_name         = "${var.servername}"
    charset             = "UTF8"
    collation           = "English_United States.1252"
}
variable "secretname" {
  type = "list"
}
variable "secretvalue" {
  type = "list"
}
variable "secretcount" {
  default = 1
}

variable "domain" {}


provider "azurerm" {
    client_id       = "yourclientid"
    client_secret   = "yourclientsecret"
    tenant_id       = "yourtenantid"
    subscription_id = "yoursubid"
    alias           = "KeyVaultSub"
}

data "azurerm_key_vault" "buildcreds" {
    name                    = "yourkeyvaultname"
    resource_group_name     = "yourrsgname"
    provider                = "azurerm.KeyVaultSub"
}

resource "azurerm_key_vault_secret" "createsecret" {
  count                   = "${var.secretcount}"
  name                    = "${element(var.secretname,count.index)}"
  value                   = "${element(var.secretvalue, count.index)}"
  key_vault_id            = "${data.azurerm_key_vault.buildcreds.id}"
  content_type            = "${var.domain} domain SQL Server service account"
  provider                = "azurerm.KeyVaultSub"
  tags {
    Domain = "${var.domain}"
  }
}

output "secretname" {
  value = ["${azurerm_key_vault_secret.createsecret.*.name}"]
}

output "secretvalue" {
  value = ["${azurerm_key_vault_secret.createsecret.*.value}"]
}
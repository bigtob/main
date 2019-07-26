variable "secretname" {
    type    = "list"
}

provider "azurerm" {
    client_id       = "yourclientid"
    client_secret   = "yourclientsecret"
    tenant_id       = "yourtenantid"
    subscription_id = "yoursubid"
    alias           = "KeyVaultSub"
}

data "azurerm_key_vault" "buildcreds" {
    name                    = "yourkvname"
    resource_group_name     = "yourrsgname"
    provider                = "azurerm.KeyVaultSub"
}

data "azurerm_key_vault_secret" "secret" {
  count                   = "${length(var.secretname)}"
  name                    = "${element(var.secretname,count.index)}"
  key_vault_id            = "${data.azurerm_key_vault.buildcreds.id}"
  provider                = "azurerm.KeyVaultSub"
}

output "secretvalue" {
	value = "${data.azurerm_key_vault_secret.secret.*.value}"
}
output "secretname" {
	value = "${data.azurerm_key_vault_secret.secret.*.name}"
}
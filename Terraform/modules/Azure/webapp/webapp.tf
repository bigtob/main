variable "location" {}
variable "resourcegroup" {}
variable "webappname" {}
variable "serviceplanid" {}

# Create WebApp Service
resource "azurerm_app_service" "webapp" {
  name                = "${var.webappname}"
  location            = "${var.location}"
  resource_group_name = "${var.resourcegroup}"
  app_service_plan_id = "${var.serviceplanid}"

  site_config {
    dotnet_framework_version = "v4.0"
    scm_type                 = "LocalGit"
  }
}

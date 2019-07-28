variable "location" {}
variable "resourcegroup" {}
variable "webappservplan" {}
variable "tier" {}
variable "size" {}
variable "projectname" {}

# Create WebApp Service Plan component
resource "azurerm_app_service_plan" "servplan" {
  name                = "${var.webappservplan}"
  location            = "${var.location}"
  resource_group_name = "${var.resourcegroup}"

  sku {
    tier = "${var.tier}"
    size = "${var.size}"
  }
}
# Autoscaling settings for the above WebApp
resource "azurerm_autoscale_setting" "webapp-autoscale" {
  name                = "${var.projectname}AutoscaleSetting"
  resource_group_name = "${var.resourcegroup}"
  location            = "${var.location}"
  target_resource_id  = "${azurerm_app_service_plan.servplan.id}"

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 3
    }

# Un-comment the below sections to enable Autoscaling rules and notifications as required

 /*   rule {
      metric_trigger {
        metric_name         = "Percentage CPU"
        metric_resource_id  = "${azurerm_app_service_plan.servplan.id}"
        time_grain          = "PT1M"
        statistic           = "Average"
        time_window         = "PT5M"
        time_aggregation    = "Average"
        operator            = "GreaterThan"
        threshold           = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name         = "Percentage CPU"
        metric_resource_id  = "${azurerm_app_service_plan.servplan.id}"
        time_grain          = "PT1M"
        statistic           = "Average"
        time_window         = "PT5M"
        time_aggregation    = "Average"
        operator            = "LessThan"
        threshold           = 35
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }   */
  }  

/*  notification {
    operation = "Scale"
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = ["phil.brooker@sse.com"]
    }
  } */
} 

output "servplanid" {
  value = "${azurerm_app_service_plan.servplan.id}"
}

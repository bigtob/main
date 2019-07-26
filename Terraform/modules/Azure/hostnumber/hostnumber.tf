variable "testing" {
    default = true
}
variable "increment" {
# Number to increment on the back end (only one number is returned)
}
# Get number for hostname via a data source 
# testing should be set to true to use the dev website
data "http" "number" {
    url = "${var.testing == "true" ? "https://yoursite.azurewebsites.net/api/serversdev/${var.increment}" : "https://yoursite.azurewebsites.net/api/servers/${var.increment}"}" 
    request_headers {
        "AccessCode" = "yourcode"
    } 
}
output "number" {
    value = "${data.http.number.body}"
}
module "azure_location" {
  source   = "../../"
  location = "westus3"
}

output "location" {
  value = module.azure_location.location
}

module "azure_fake_location" {
  source   = "../../"
  location = "Test America"
}

output "fake_location" {
  value = module.azure_fake_location.location
}

# Output
# + fake_location = "none"
# + location      = {
#     + display_name          = "West US 3"
#     + name                  = "westus3"
#     + paired_region_name    = "eastus"
#     + regional_display_name = "(US) West US 3"
#     + short_name            = "WUS3"
#   }
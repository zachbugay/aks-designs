locals {
  locations_data = yamldecode(file("${path.module}/azure_locations.yaml"))

  locations_name = {
    for location in local.locations_data.locations : location.Name => {
      name                  = location.Name
      display_name          = location.DisplayName
      short_name            = try(location.ShortName, null)
      regional_display_name = location.RegionalDisplayName
      paired_region_name    = location.PairedRegion
    }
  }

  locations_display_name = {
    for location in local.locations_data.locations : location.DisplayName => {
      name                  = location.Name
      display_name          = location.DisplayName
      short_name            = try(location.ShortName, null)
      regional_display_name = location.RegionalDisplayName
      paired_region_name    = location.PairedRegion
    }
  }

  lookup_name         = lookup(local.locations_name, var.location, null)
  lookup_display_name = lookup(local.locations_display_name, var.location, null)
  location = try(coalesce(
    local.lookup_name,
    local.lookup_display_name
  ), "none")
}

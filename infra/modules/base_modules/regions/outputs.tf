output "vm_sku_region_zones" {
  description = "Map of region to VM SKU to availability zones. e.g. { westus3 = { Standard_D2s_v3 = [\"1\", \"2\", \"3\"] } }"
  value       = local.vm_sku_zones
}
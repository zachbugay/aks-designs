locals {
  module_tags = tomap(
    {
      terraform-azurerm-composite = "p2s_root_certificate"
    }
  )

  tags = merge(
    local.module_tags,
    var.workload != "" ? { workload = var.workload } : {},
    var.environment != "" ? { environment = var.environment } : {},
    var.tags
  )

  instance = coalesce(var.instance, "001")
  name     = coalesce(var.custom_name, "${var.environment}-p2s-root-${var.workload}-${local.instance}")

  # The Virtual Network Gateway expects the base64 encoded DER certificate, which is
  # the PEM body with the armour and line breaks removed.
  public_cert_data = replace(
    replace(
      replace(tls_self_signed_cert.this.cert_pem, "-----BEGIN CERTIFICATE-----", ""),
      "-----END CERTIFICATE-----", ""
    ),
    "\n", ""
  )
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "this" {
  private_key_pem       = tls_private_key.this.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = var.validity_period_hours
  early_renewal_hours   = var.early_renewal_hours

  subject {
    common_name = local.name
  }

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

module "certificate_secret" {
  source       = "../../base_modules/key_vault_secret"
  key_vault_id = var.key_vault_id
  name         = "${local.name}-cert"
  value        = tls_self_signed_cert.this.cert_pem
  tags         = local.tags
}

module "private_key_secret" {
  source       = "../../base_modules/key_vault_secret"
  key_vault_id = var.key_vault_id
  name         = "${local.name}-key"
  value        = tls_private_key.this.private_key_pem
  tags         = local.tags
}

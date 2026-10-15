# Run once by an identity administrator, interactively, with an explicit tenant.
# Azure CLI sign-in only: no client secret, certificate or service principal password.
provider "azuread" {
  tenant_id = var.tenant_id
  use_cli   = true
}

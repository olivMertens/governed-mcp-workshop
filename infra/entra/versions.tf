terraform {
  required_version = ">= 1.16.6, < 2.0.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.10.0"
    }
  }
}

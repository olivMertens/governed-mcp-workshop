# Module 03 - Microsoft Entra built-in authentication on the MCP Function App (level 1).
# Opt-in with enable_entra_auth = true (private .workshop/module03.tfvars.json from the infra/entra output).
# Pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
# 468c518c884ec318e3001b9573254c9e775409c9 (infra/app/api.bicep authsettingsV2), MIT License,
# Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
# Workshop changes: AzureRM auth_settings_v2 instead of Bicep, no client secret or federated credential setting
# (module 05), token store off, allowed audiences limited to this API, host.json kept at System.

locals {
  mcp_auth_enabled = local.mcp_enabled && var.enable_entra_auth
  mcp_auth_scope   = var.mcp_api_identifier_uri == null ? null : "${var.mcp_api_identifier_uri}/user_impersonation"
  mcp_auth_issuer  = var.entra_tenant_id == null ? null : "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"

  # One audience: the MCP API, named either by its Application ID URI (v1 tokens) or its client ID (v2 tokens).
  mcp_auth_audiences = compact([var.mcp_api_identifier_uri, var.mcp_api_client_id])

  # Documented app-setting equivalent of host.json extensions.mcp.system.webhookAuthorizationLevel.
  mcp_webhook_level_setting = "AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel"

  # The MCP webhook stops requiring the system key ONLY when built-in authentication already runs in front of it.
  # Two stages, two applies: (1) enable_entra_auth adds Entra in front of the key (token AND key required);
  # (2) entra_auth_replace_key_gate then drops the key. AzureRM writes app settings and auth settings in separate
  # calls, so doing both in one apply could expose an anonymous webhook for a moment. Clean-up reverses the order.
  mcp_key_gate_replaced = local.mcp_auth_enabled && var.entra_auth_replace_key_gate
  mcp_auth_app_settings = merge(
    local.mcp_auth_enabled ? {
      WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES = local.mcp_auth_scope # Preview
      WEBSITE_AUTH_AAD_ALLOWED_TENANTS     = var.entra_tenant_id
    } : {},
    local.mcp_key_gate_replaced ? { (local.mcp_webhook_level_setting) = "Anonymous" } : {},
  )
}

output "mcp_key_gate_replaced" {
  description = "True when the level 0 system key no longer gates the MCP webhook because built-in authentication does."
  value       = local.mcp_key_gate_replaced
}

output "mcp_auth_enabled" {
  description = "True when module 03 built-in Microsoft Entra authentication protects the MCP endpoint."
  value       = local.mcp_auth_enabled
}

output "mcp_auth_audience" {
  description = "Application ID URI to request tokens for (az account get-access-token --resource). Null when module 03 is off."
  value       = local.mcp_auth_enabled ? var.mcp_api_identifier_uri : null
}

output "mcp_auth_scope" {
  description = "Delegated scope advertised in Protected Resource Metadata (Preview). Null when module 03 is off."
  value       = local.mcp_auth_enabled ? local.mcp_auth_scope : null
}

output "mcp_auth_issuer" {
  description = "Expected token issuer and PRM authorization server. Null when module 03 is off."
  value       = local.mcp_auth_enabled ? local.mcp_auth_issuer : null
}

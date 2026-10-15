output "tenant_id" {
  description = "Tenant that issues tokens for the MCP API."
  value       = var.tenant_id
}

output "application_managed_by_workshop" {
  description = "True when this root created the registration; false when it only reads an administrator-provided one."
  value       = local.managed
}

output "application_client_id" {
  description = "Client ID of the MCP API registration (the v2 token audience)."
  value       = local.application_client_id
}

output "application_object_id" {
  description = "Object ID of the MCP API registration. Module 05 attaches its federated identity credential here."
  value       = local.application_object_id
}

output "identifier_uri" {
  description = "Application ID URI: the resource that clients request a token for."
  value       = local.identifier_uri
  precondition {
    condition     = local.identifier_uri != null
    error_message = "The MCP API registration must expose an api:// Application ID URI."
  }
}

output "user_impersonation_scope" {
  description = "Delegated scope for WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES (Preview) and client sign-in."
  value       = local.user_impersonation_scope
  precondition {
    condition     = contains(keys(local.scope_ids), "user_impersonation")
    error_message = "The MCP API registration must expose the delegated scope user_impersonation."
  }
}

output "service_principal_object_id" {
  description = "Enterprise application (service principal) that holds app role assignments."
  value       = local.service_principal_id
  precondition {
    condition     = local.assignment_required
    error_message = "Assignment required must be enabled on the enterprise application so that unassigned users such as Eve are refused."
  }
}

output "app_role_ids" {
  description = "App role IDs by value."
  value       = { for name in ["Tools.Read", "Tools.Write", "Tools.Execute.All"] : name => lookup(local.app_role_ids, name, null) }
  precondition {
    condition     = alltrue([for name in ["Tools.Read", "Tools.Write", "Tools.Execute.All"] : contains(keys(local.app_role_ids), name)])
    error_message = "The MCP API registration must define the app roles Tools.Read, Tools.Write and Tools.Execute.All."
  }
}

output "pre_authorized_client_ids" {
  description = "Public clients pre-authorized for user_impersonation (created path) and allowed by built-in authentication."
  value       = var.pre_authorized_client_ids
}

output "persona_assignments" {
  description = "Planned persona assignments by key (alice-read, alice-write, bob-read). Eve is never assigned."
  value       = { for key, value in local.assignments : key => value.role }
}

output "persona_object_ids" {
  description = "Existing test account object IDs, for the private validator persona cross-check. Not secrets; keep them out of Git."
  value       = { alice = var.test_user_object_ids.alice, bob = var.test_user_object_ids.bob, eve = var.test_user_object_ids.eve }
}

output "module05_federated_credential" {
  description = "Reserved for module 05 (not created here): the managed identity federated credential trust for On-Behalf-Of."
  value = {
    parent_application_object_id = local.application_object_id
    issuer                       = local.federated_issuer
    audience                     = local.federated_token_audience
    subject                      = "<module 05: principal ID of the workload user-assigned managed identity>"
  }
}

output "workload_module03_tfvars" {
  description = "Non-secret values to save as .workshop/module03.tfvars.json for infra/workload (module 03 opt-in)."
  value = {
    enable_entra_auth           = true
    entra_auth_replace_key_gate = false
    entra_tenant_id             = var.tenant_id
    mcp_api_client_id           = local.application_client_id
    mcp_api_identifier_uri      = local.identifier_uri
    mcp_allowed_client_ids      = var.pre_authorized_client_ids
  }
}

variable "tenant_id" {
  type        = string
  description = "Explicit non-production tenant ID. Supplied privately; never committed."
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "Use the tenant ID as a lowercase GUID."
  }
}

variable "participant_prefix" {
  type        = string
  description = "Participant label from the private participant parameters, not an email or real user identifier."
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.participant_prefix))
    error_message = "Use 2-8 lowercase letters/digits, starting with a letter."
  }
}

variable "resource_suffix" {
  type        = string
  description = "Stable random suffix from the private participant parameters. Used in display labels only."
  validation {
    condition     = can(regex("^([a-f0-9]{10}|[a-f0-9]{16})$", var.resource_suffix))
    error_message = "Use the saved 16-character lowercase hex suffix, or an existing 10-character legacy suffix."
  }
}

variable "owner" {
  type        = string
  description = "Non-sensitive participant label recorded in application tags."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,31}$", var.owner))
    error_message = "Use a 2-32 character lowercase label, not an email or personal data."
  }
}

variable "expiry" {
  type        = string
  description = "Cleanup date recorded in application tags, not an automatic deletion schedule."
  validation {
    condition     = can(formatdate("YYYY-MM-DD", "${var.expiry}T00:00:00Z"))
    error_message = "Use a valid yyyy-MM-dd date."
  }
}

variable "create_application" {
  type        = bool
  default     = true
  nullable    = false
  description = "True: create the workshop MCP API registration and enterprise application. False: read an administrator-provided application by client ID and never manage, change or delete it."
  validation {
    condition     = var.create_application || var.existing_application_client_id != null
    error_message = "When create_application is false, set existing_application_client_id."
  }
}

variable "existing_application_client_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Client ID of an administrator-provided MCP API registration. Read-only: never imported, changed or destroyed."
  validation {
    condition     = var.existing_application_client_id == null ? true : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.existing_application_client_id))
    error_message = "Use a lowercase GUID."
  }
}

variable "pre_authorized_client_ids" {
  type        = list(string)
  nullable    = false
  description = "Exact public clients pre-authorized for user_impersonation and allowed by built-in authentication. Defaults: Visual Studio Code and Azure CLI, as documented by Microsoft Learn. Never pre-authorize all applications."
  default = [
    "aebc6443-996d-45c2-90f0-388ff96faa56", # Visual Studio Code (Microsoft Learn functions-mcp-tutorial, pinned sample)
    "04b07795-8ddb-461a-bbee-02f9e1bf7b46", # Microsoft Azure CLI (used by validate.ps1 to obtain a token)
  ]
  validation {
    condition = length(var.pre_authorized_client_ids) >= 1 && length(var.pre_authorized_client_ids) <= 5 && length(distinct(var.pre_authorized_client_ids)) == length(var.pre_authorized_client_ids) && alltrue([
      for id in var.pre_authorized_client_ids : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))
    ])
    error_message = "Use 1 to 5 distinct lowercase client ID GUIDs. Each one must be a reviewed public client."
  }
}

variable "test_user_object_ids" {
  type = object({
    alice = optional(string)
    bob   = optional(string)
    eve   = optional(string)
  })
  default     = {}
  nullable    = false
  description = "Object IDs of existing, dedicated non-production test accounts created by the identity administrator. Read-only: users are never created, changed or deleted here. Alice gets Tools.Read and Tools.Write, Bob gets Tools.Read, Eve gets nothing."
  validation {
    condition = alltrue([
      for id in [var.test_user_object_ids.alice, var.test_user_object_ids.bob, var.test_user_object_ids.eve] :
      id == null ? true : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))
    ])
    error_message = "Use lowercase object ID GUIDs."
  }
  validation {
    condition = length(compact([var.test_user_object_ids.alice, var.test_user_object_ids.bob, var.test_user_object_ids.eve])) == length(distinct(compact([
      var.test_user_object_ids.alice, var.test_user_object_ids.bob, var.test_user_object_ids.eve
    ])))
    error_message = "Alice, Bob and Eve must be three different accounts. Eve must stay unassigned."
  }
}

variable "service_management_reference" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional service tree or asset reference, if your tenant's application policy requires one. Non-sensitive."
}

variable "enable_delegated_access" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 05 opt-in: request delegated Microsoft Graph User.Read and Azure Storage user_impersonation for the MCP API (On-Behalf-Of). Created path only; an existing application is never changed. Default off keeps module 03 unchanged."
}

variable "obo_identity_principal_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Module 05: principal (object) ID of the workload's OBO assertion user-assigned managed identity (infra/workload output delegated_obo_identity_principal_id). Becomes the federated identity credential subject. Not secret."
  validation {
    condition     = var.obo_identity_principal_id == null ? true : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.obo_identity_principal_id))
    error_message = "Use the managed identity principal ID as a lowercase GUID (case-sensitive subject)."
  }
  validation {
    condition     = var.obo_identity_principal_id == null || var.enable_delegated_access
    error_message = "obo_identity_principal_id requires enable_delegated_access = true."
  }
}

variable "grant_downstream_admin_consent" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 05 opt-in, identity administrator decision: grant tenant-wide admin consent for exactly Graph User.Read and Storage user_impersonation to the workshop MCP API. Requires Cloud Application Administrator or Application Administrator."
  validation {
    condition     = !var.grant_downstream_admin_consent || var.enable_delegated_access
    error_message = "grant_downstream_admin_consent requires enable_delegated_access = true."
  }
}
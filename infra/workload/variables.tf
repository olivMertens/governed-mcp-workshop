variable "participant_prefix" {
  type        = string
  description = "Participant label, not an email or real user identifier."
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,7}$", var.participant_prefix))
    error_message = "Use 2-8 lowercase letters/digits, starting with a letter."
  }
}

variable "resource_suffix" {
  type        = string
  description = "Stable 64-bit random suffix from the private preparation script. Existing 40-bit suffixes remain unchanged. Never regenerate during an active deployment."
  validation {
    condition     = can(regex("^([a-f0-9]{10}|[a-f0-9]{16})$", var.resource_suffix))
    error_message = "Use the saved 16-character lowercase hex suffix, or preserve an existing 10-character legacy suffix."
  }
}

variable "location" {
  type        = string
  description = "Explicit region approved after subscription quota, availability and policy checks."
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "Use the Azure location code, such as westeurope, not a display name."
  }
}

variable "owner" {
  type        = string
  description = "Non-sensitive participant label for ownership."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,31}$", var.owner))
    error_message = "Use a 2-32 character lowercase label, not an email or personal data."
  }
}

variable "expiry" {
  type        = string
  description = "Cleanup date tag, not an automatic deletion schedule."
  validation {
    condition     = can(formatdate("YYYY-MM-DD", "${var.expiry}T00:00:00Z"))
    error_message = "Use a valid yyyy-MM-dd date."
  }
}

variable "existing_resource_group_name" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional approved existing group. Read-only: never imported, tagged, renamed or destroyed here."
  validation {
    condition = var.existing_resource_group_name == null ? true : (
      can(regex("^[a-zA-Z0-9_().-]{1,90}$", var.existing_resource_group_name)) &&
      !endswith(var.existing_resource_group_name, ".")
    )
    error_message = "Use a 1-90 character resource group name without a trailing period."
  }
}

variable "public_portal_enabled" {
  type        = bool
  default     = false
  nullable    = false
  description = "Explicit opt-in to a paid B1 Linux App Service for public documentation only. Not an MCP server or tenant deployment control plane."
}

variable "enable_mcp_server" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 02 opt-in: Flex Consumption MCP server, Storage, ticket queue, telemetry and managed identity. Default off keeps the module 00 foundation unchanged."
}

variable "mcp_allowed_ip_ranges" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Optional module 02 inbound IPv4 allow-list in CIDR form. Empty keeps the key-protected endpoint public; any entry denies all other sources."
  validation {
    condition = length(var.mcp_allowed_ip_ranges) <= 10 && alltrue([
      for range in var.mcp_allowed_ip_ranges :
      can(cidrhost(range, 0)) && can(regex("^\\d{1,3}(\\.\\d{1,3}){3}/(8|9|[12]\\d|3[0-2])$", range))
    ])
    error_message = "Use at most 10 IPv4 CIDR ranges with a prefix of /8 to /32. Never allow 0.0.0.0/0."
  }
}

variable "mcp_maximum_instance_count" {
  type        = number
  default     = 10
  nullable    = false
  description = "Flex Consumption scale-out ceiling for the workshop server; keeps cost bounded."
  validation {
    condition     = var.mcp_maximum_instance_count >= 1 && var.mcp_maximum_instance_count <= 40 && floor(var.mcp_maximum_instance_count) == var.mcp_maximum_instance_count
    error_message = "Use a whole number from 1 to 40 for the workshop."
  }
}

variable "enable_entra_auth" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 03 opt-in: Microsoft Entra built-in authentication on the MCP Function App. Requires enable_mcp_server and the IDs from infra/entra. Default off keeps module 02 unchanged."
  validation {
    condition = !var.enable_entra_auth || (
      var.enable_mcp_server && var.entra_tenant_id != null && var.mcp_api_client_id != null &&
      var.mcp_api_identifier_uri != null && length(var.mcp_allowed_client_ids) > 0
    )
    error_message = "enable_entra_auth needs enable_mcp_server = true, entra_tenant_id, mcp_api_client_id, mcp_api_identifier_uri and at least one allowed client. Use the workload_module03_tfvars output of infra/entra."
  }
}

variable "entra_tenant_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Tenant that issues MCP tokens (token issuer). Not secret; keep it in the private module 03 var file."
  validation {
    condition     = var.entra_tenant_id == null ? true : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.entra_tenant_id))
    error_message = "Use the tenant ID as a lowercase GUID."
  }
}

variable "mcp_api_client_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Client ID of the MCP API registration from infra/entra. Accepted as token audience (v2 tokens)."
  validation {
    condition     = var.mcp_api_client_id == null ? true : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.mcp_api_client_id))
    error_message = "Use the client ID as a lowercase GUID."
  }
}

variable "mcp_api_identifier_uri" {
  type        = string
  default     = null
  nullable    = true
  description = "Application ID URI of the MCP API (api://...). The only other accepted audience."
  validation {
    condition     = var.mcp_api_identifier_uri == null ? true : can(regex("^api://[A-Za-z0-9][A-Za-z0-9._/-]{0,199}$", var.mcp_api_identifier_uri)) && !endswith(var.mcp_api_identifier_uri, "/")
    error_message = "Use an api:// Application ID URI without a trailing slash."
  }
}

variable "mcp_allowed_client_ids" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Client applications allowed to call the MCP server (built-in authorization policy). Must match the pre-authorized clients in infra/entra."
  validation {
    condition = length(var.mcp_allowed_client_ids) <= 5 && length(distinct(var.mcp_allowed_client_ids)) == length(var.mcp_allowed_client_ids) && alltrue([
      for id in var.mcp_allowed_client_ids : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))
    ])
    error_message = "Use at most 5 distinct lowercase client ID GUIDs. Never allow every application."
  }
}

variable "entra_auth_replace_key_gate" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 03 stage 2: drop the level 0 system key once built-in authentication is already enforced (applied in a previous run). Never set it in the same first apply as enable_entra_auth."
  validation {
    condition     = !var.entra_auth_replace_key_gate || var.enable_entra_auth
    error_message = "entra_auth_replace_key_gate requires enable_entra_auth = true: the key gate is only replaced by enforced Entra authentication."
  }
}

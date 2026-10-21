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

variable "mcp_private_storage" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 02 network opt-in for tenants whose Azure Policy disables public Storage network access. Adds the shared virtual network, a delegated Flex Consumption integration subnet, blob and queue private endpoints and their private DNS zones. Storage public network access is then disabled. The MCP endpoint itself stays public."
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

variable "enable_governed_gateway" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 04 stage 1 opt-in: API Management Standard v2 (provisioned capacity, cost approval required) as the governed MCP entry point, outbound virtual network integration, Function private endpoint and private DNS, payload-free Application Insights logging. Requires modules 02 and 03 (both stages). Default off keeps modules 00-03 unchanged."
  validation {
    condition     = !var.enable_governed_gateway || (var.enable_mcp_server && var.enable_entra_auth && var.entra_auth_replace_key_gate)
    error_message = "enable_governed_gateway needs enable_mcp_server, enable_entra_auth and entra_auth_replace_key_gate = true: the gateway forwards the MCP-audience token that the Function validates itself (one logical resource)."
  }
}

variable "gateway_lock_function" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 04 stage 2: disable public network access on the Function App so only the gateway (through the private endpoint) reaches it. Apply only after stage 1 is deployed and the gateway path works."
  validation {
    condition     = !var.gateway_lock_function || var.enable_governed_gateway
    error_message = "gateway_lock_function requires enable_governed_gateway = true: never lock the Function before the private path through the gateway exists."
  }
}

variable "enable_rest_mcp_demo" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 04 optional part B: expose a synthetic REST API (mocked responses) as a second MCP server on the same gateway (API-first pattern, Preview API). Same Entra token, role and rate-limit rules; no subscription key. Default off."
  validation {
    condition     = !var.enable_rest_mcp_demo || var.enable_governed_gateway
    error_message = "enable_rest_mcp_demo requires enable_governed_gateway = true: part B reuses the module 04 gateway, its token validation and its payload-free logging."
  }
}

variable "gateway_publisher_email" {
  type        = string
  default     = "mcp-workshop@example.com"
  nullable    = false
  description = "API Management publisher email (required by the service; receives service notifications). Use a team or reserved example address, never a personal address in a committed file."
  validation {
    condition     = can(regex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", var.gateway_publisher_email))
    error_message = "Use a valid email address."
  }
}

variable "gateway_mcp_path" {
  type        = string
  default     = "workshop-mcp"
  nullable    = false
  description = "Gateway base path of the MCP server. Clients call https://<gateway>/<path>/mcp."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,39}$", var.gateway_mcp_path))
    error_message = "Use 3-40 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "gateway_vnet_address_space" {
  type        = string
  default     = "10.42.0.0/23"
  nullable    = false
  description = "Address space of the shared workshop virtual network (module 02 private storage and module 04). The first /24 is the delegated API Management subnet, the next /27 the private endpoint subnet, the following /27 the Flex Consumption integration subnet."
  validation {
    condition     = can(cidrhost(var.gateway_vnet_address_space, 0)) && can(regex("^\\d{1,3}(\\.\\d{1,3}){3}/(1[6-9]|2[0-3])$", var.gateway_vnet_address_space))
    error_message = "Use an IPv4 CIDR from /16 to /23 so a /24 API Management subnet and two /27 subnets fit."
  }
}

variable "gateway_rate_limit_calls" {
  type        = number
  default     = 30
  nullable    = false
  description = "Calls allowed per caller object ID (oid) in each renewal period before the gateway returns HTTP 429."
  validation {
    condition     = var.gateway_rate_limit_calls >= 5 && var.gateway_rate_limit_calls <= 1000 && floor(var.gateway_rate_limit_calls) == var.gateway_rate_limit_calls
    error_message = "Use a whole number from 5 to 1000."
  }
}

variable "gateway_rate_limit_period" {
  type        = number
  default     = 60
  nullable    = false
  description = "Rate-limit renewal period in seconds (API Management maximum 300)."
  validation {
    condition     = var.gateway_rate_limit_period >= 10 && var.gateway_rate_limit_period <= 300 && floor(var.gateway_rate_limit_period) == var.gateway_rate_limit_period
    error_message = "Use a whole number of seconds from 10 to 300."
  }
}

variable "gateway_allowed_ip_ranges" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Optional gateway ip-filter allow-list (IPv4 CIDR). Empty: no IP filter, the token and role checks still apply. Any entry: other sources get HTTP 403."
  validation {
    condition = length(var.gateway_allowed_ip_ranges) <= 10 && alltrue([
      for range in var.gateway_allowed_ip_ranges :
      can(cidrhost(range, 0)) && can(regex("^\\d{1,3}(\\.\\d{1,3}){3}/(8|9|[12]\\d|3[0-2])$", range))
    ])
    error_message = "Use at most 10 IPv4 CIDR ranges with a prefix of /8 to /32. Never allow 0.0.0.0/0."
  }
}

variable "enable_delegated_access" {
  type        = bool
  default     = false
  nullable    = false
  description = "Module 05 opt-in: two new user-assigned identities (OBO assertion, app-only reader), a synthetic report container, container-scoped Storage Blob Data Reader roles and the WORKSHOP_* settings that switch whoami/read_report_* from demonstrations to real On-Behalf-Of and managed identity calls. Requires module 03 (enable_entra_auth). Default off keeps modules 00-04 unchanged."
  validation {
    condition     = !var.enable_delegated_access || (var.enable_mcp_server && var.enable_entra_auth)
    error_message = "enable_delegated_access needs enable_mcp_server and enable_entra_auth = true: On-Behalf-Of needs a platform-validated user token for the MCP audience."
  }
}

variable "delegated_persona_object_ids" {
  type = object({
    alice = optional(string)
    bob   = optional(string)
  })
  default     = {}
  nullable    = false
  description = "Module 05: object IDs of the existing Alice and Bob test accounts (infra/entra output workload_module05_tfvars). Alice gets Storage Blob Data Reader on the report container; Bob gets no Storage role. Both map to synthetic persona labels for whoami. Keep them in the private var file."
  validation {
    condition = alltrue([
      for id in [var.delegated_persona_object_ids.alice, var.delegated_persona_object_ids.bob] :
      id == null ? true : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))
    ])
    error_message = "Use lowercase object ID GUIDs."
  }
  validation {
    condition = (var.delegated_persona_object_ids.alice == null || var.delegated_persona_object_ids.bob == null ||
    var.delegated_persona_object_ids.alice != var.delegated_persona_object_ids.bob)
    error_message = "Alice and Bob must be two different accounts: Bob must stay without a Storage role."
  }
}

variable "delegated_report_publisher_object_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Module 05: object ID that publishes the synthetic report blob (Storage Blob Data Contributor on the report container only). Null: the signed-in Terraform user."
  validation {
    condition     = var.delegated_report_publisher_object_id == null ? true : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.delegated_report_publisher_object_id))
    error_message = "Use a lowercase object ID GUID."
  }
}
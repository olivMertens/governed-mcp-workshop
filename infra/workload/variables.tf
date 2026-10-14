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

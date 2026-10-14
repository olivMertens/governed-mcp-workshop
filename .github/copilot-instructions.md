# Copilot instructions — Governed MCP on Azure (hands-on workshop)

## Purpose
This repository is a self-paced, end-to-end workshop that takes one MCP server from "open" to "governed" on Azure:
open server → Microsoft Entra authentication → Azure API Management as the only entry point →
delegated (On-Behalf-Of) vs app-only access → observability and inventory.
Audience: enterprise platform, identity and Microsoft 365 administrators (PowerShell, C#, Terraform)
plus a few developers, most of them new to agents and MCP.
Goal: every participant can deploy, verify and destroy every module alone, in a non-production Azure subscription.
Build order, sources and expected results are in docs/BUILD-PLAN.md. Read it before any task.

## Content rules
- Public repository: generic content only. No customer or employer names, no internal or confidential material,
  no tenant/subscription IDs, no real user data, no secrets. Synthetic data only; personas are Alice, Bob and Eve (Contoso).
- English, plain language, short sentences. Define every acronym on first use.
- Reuse official samples and documentation instead of reinventing them. Pin versions or commit SHAs,
  keep upstream license notices, link the origin.
- Before writing code for a module, read the official pages listed for it. If they contradict this file,
  follow the docs and explain the gap in the pull request.
- Mark every preview feature "Preview" where it is used. Never present preview behaviour as generally available.
- Every module README ends with "Sources": links plus a "last verified" date.

## Security invariants — never weaken them, not even to make a test pass
1. One token per hop, one audience per token. The MCP server accepts only tokens issued for its own audience.
2. Never forward a client token to a downstream API (no token passthrough). Downstream calls use On-Behalf-Of
   (user context) or a managed identity (app-only). The choice is made per tool and documented.
3. Validate issuer, tenant, audience and expiry, then scope (scp) and/or role (roles), using platform features
   (Functions/App Service built-in authentication, APIM validate-azure-ad-token) or Microsoft.Identity.Web.
   Never hand-write JWT validation.
4. Scopes say what the client app may do for the user; app roles say what this user or app may do.
   Per-user authorization uses app roles.
5. No secrets: managed identities and federated identity credentials only. Nothing secret in code, mcp.json,
   scripts, tfvars or Terraform state committed to git.
6. Write tools require an explicit role and human approval in the client.
7. Logs never contain tokens, prompts, tool arguments or tool results (zero body bytes).
   Log tool name, caller object ID, status, latency and correlation ID.
8. Least privilege: role assignments scoped to the exact resource or resource group, time-bound where possible.
9. The "open" level (module 02) exists only to show the risk: function key, short-lived, optional IP allow-list.
   Never leave an anonymous MCP endpoint on the internet.

## Stack and conventions
- IaC: Terraform with azurerm, azuread and azapi (azapi for resources or API versions not yet in azurerm,
  e.g. API Management MCP servers with api-version 2025-09-01-preview).
  Two root modules: infra/entra (run once by an identity administrator, or skipped by passing existing IDs)
  and infra/workload.
- MCP server: Azure Functions (.NET, MCP extension), patterns from Azure-Samples/remote-mcp-functions-dotnet.
- Gateway: Azure API Management v2 tier. Do not use the preview AI Gateway tier in the core path.
- Scripts: PowerShell 7 first (preflight, deploy, validate, cleanup), bash equivalents second.
  Idempotent, fail fast, clear messages.
- Environment: .devcontainer (also used by Codespaces) and Azure Cloud Shell instructions;
  corporate laptops may block local tools.
- Naming: deterministic names from a participant prefix (p01, p02…) and a suffix, so URLs are known
  before deployment. Generate a cryptographically random suffix once in ignored private participant parameters;
  reuse it and the same state through cleanup. Default to a dedicated group, or read an administrator-provided group
  without managing/deleting it. Random names do not reset quotas. Tag workshop-owned resources: workshop, owner, expiry.

## Module contract (modules/NN-name/)
README sections in this order: Goal · Why it matters · What you deploy · Prerequisites and required roles ·
Steps (PowerShell, then bash) · What you should see · Validate · Troubleshooting · Clean up · Go further · Sources.
Files: infra/ (if any), validate.ps1 and validate.sh (one PASS/FAIL line per check with the expected HTTP status),
cleanup script. A module is done only when its validate script passes on a fresh subscription
right after the previous modules.

## When helping a participant
Explain simply and point to the module's sources. Never suggest disabling a control, widening a role,
using a client secret, or pasting a token into chat or a file as a workaround.

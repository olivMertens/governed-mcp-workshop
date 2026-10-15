#requires -Version 7.4
<#
.SYNOPSIS
    Module 07 cleanup. Nothing is created by this module, so nothing is deleted.

.DESCRIPTION
    Reminds the facilitator to remove any test agent or tool added to Microsoft Foundry
    or Copilot Studio during the demo. Makes no Azure, Entra or Copilot Studio calls.

.EXAMPLE
    pwsh ./modules/07-clients/cleanup.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest

Write-Output 'INFO module 07 creates no Azure, Entra or Copilot Studio resources.'
Write-Output 'INFO remove any test agent or MCP tool you added to the Foundry project or Copilot Studio after the demo, by hand.'
Write-Output 'PASS nothing to delete (module 07)'

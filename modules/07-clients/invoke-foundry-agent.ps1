<#
.SYNOPSIS
    Module 07: call a Microsoft Foundry agent (Responses API) as the signed-in user, and show consent, approval and results.
.DESCRIPTION
    Uses the Azure CLI token of the current profile for https://ai.azure.com. Never prints a token.
    1. Run with -Prompt. If the output is an oauth_consent_request, open the printed link in a browser signed in as the
       SAME user, then run again with the same prompt.
    2. If the output is an mcp_approval_request, read the tool name and arguments. Run again with -Approve (and the
       printed -PreviousResponseId) only if you agree. Approval never adds a missing app role: the gateway still decides.
.EXAMPLE
    pwsh ./modules/07-clients/invoke-foundry-agent.ps1 -ProjectEndpoint $endpoint -Prompt 'Call get_service_health for "workshop-api".'
.EXAMPLE
    pwsh ./modules/07-clients/invoke-foundry-agent.ps1 -ProjectEndpoint $endpoint -PreviousResponseId resp_123 -Approve
#>
[CmdletBinding(DefaultParameterSetName = 'Prompt')]
param(
    [Parameter(Mandatory)][ValidatePattern('^https://[a-z0-9-]+\.services\.ai\.azure\.com/api/projects/[A-Za-z0-9-]+$')][string]$ProjectEndpoint,
    [string]$AgentName = 'workshop-mcp-agent',
    [Parameter(Mandatory, ParameterSetName = 'Prompt')][string]$Prompt,
    [Parameter(Mandatory, ParameterSetName = 'Approve')][string]$PreviousResponseId,
    [Parameter(ParameterSetName = 'Approve')][switch]$Approve,
    [Parameter(ParameterSetName = 'Approve')][switch]$Deny
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\scripts\context-common.ps1')
$tenant = az account show --query tenantId -o tsv --only-show-errors
if (-not $tenant) { throw 'FAIL sign in with az login first (expected HTTP 200 from Microsoft Entra).' }
$token = Get-WorkshopAccessToken -TenantId $tenant -Resource 'https://ai.azure.com'
if (-not $token.Ok) { throw "FAIL no token for Microsoft Foundry ($($token.Value)). Check your Foundry role on the project." }
$agent = @{ name = $AgentName; type = 'agent_reference' }

if ($PSCmdlet.ParameterSetName -eq 'Approve') {
    if ($Approve -eq $Deny) { throw 'Choose exactly one of -Approve or -Deny.' }
    $previous = Invoke-RestMethod "$ProjectEndpoint/openai/v1/responses/$PreviousResponseId" -Headers @{ Authorization = "Bearer $($token.Value)" }
    $request = @($previous.output | Where-Object type -eq 'mcp_approval_request') | Select-Object -First 1
    if (-not $request) { throw 'FAIL the previous response has no mcp_approval_request to answer.' }
    $body = @{ previous_response_id = $PreviousResponseId; agent_reference = $agent
        input = @(@{ type = 'mcp_approval_response'; approve = [bool]$Approve; approval_request_id = $request.id }) }
} else {
    $body = @{ input = $Prompt; agent_reference = $agent }
}

$response = Invoke-WebRequest "$ProjectEndpoint/openai/v1/responses" -Method Post -Headers @{ Authorization = "Bearer $($token.Value)" } `
    -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 8) -SkipHttpErrorCheck
$token = $null
$json = $response.Content | ConvertFrom-Json -Depth 20
if ([int]$response.StatusCode -ne 200) {
    $message = "$($json.error.message)"
    $status = [regex]::Match($message, 'HTTP (\d{3})').Groups[1].Value
    Write-Output "REFUSED HTTP $([int]$response.StatusCode) from Foundry; the MCP server answered HTTP $status. $($message -replace 'https://\S+', '<gateway>' -replace '\. Please verify.*$', '.')"
    exit 1
}
Write-Output "RESPONSE $($json.id)"
foreach ($item in $json.output) {
    switch ($item.type) {
        'mcp_list_tools' { Write-Output "TOOLS $(@($item.tools.name | Sort-Object) -join ', ')" }
        'oauth_consent_request' { Write-Output "CONSENT open this link signed in as the same user, then run the same prompt again: $($item.consent_link)" }
        'mcp_approval_request' { Write-Output "APPROVAL $($item.name) $($item.arguments). Approve with: -PreviousResponseId $($json.id) -Approve (or -Deny)" }
        'mcp_call' { Write-Output "CALL $($item.name) -> $(if ($item.error) { "error: $($item.error)" } else { $item.output })" }
        'message' { Write-Output "ANSWER $(@($item.content.text) -join ' ')" }
        default { Write-Output "ITEM $($item.type)" }
    }
}

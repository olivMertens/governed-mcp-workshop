#requires -Version 7.4
<#
.SYNOPSIS
    Module 05 clean-up. Idempotent, plan-reviewed, refuses anything outside module 05.
.DESCRIPTION
    -Scope Workload (participant, default): one guarded phase on infra/workload with enable_delegated_access = false. Accepts only
      the deletion of the module 05 resources (two identities, report container and its blob, three container role assignments)
      and the in-place Function App update that removes the two identities and the WORKSHOP_* settings. Modules 02-04 stay:
      the server is back to the module 02 synthetic demonstrations for whoami and read_report_*.
    -Scope Entra (identity administrator): one guarded phase on infra/entra with enable_delegated_access = false, no OBO
      identity and no consent. Accepts only the deletion of the federated credential, the two delegated permission requests and
      the two admin consent grants. The MCP API registration from module 03 stays. Run it before modules/03 Entra clean-up.
    Without -Apply it only reports. With -Apply it applies the exact reviewed plan.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [guid]$SubscriptionId,
    [ValidateSet('Workload', 'Entra')][string]$Scope = 'Workload',
    [string]$ParametersPath,
    [string]$Module02VarFile,
    [string]$Module03VarFile,
    [string]$Module04VarFile,
    [string]$Module04bVarFile,
    [string]$Module05VarFile,
    [string]$EntraParametersPath,
    [string]$EntraModule05VarFile,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$private = Join-Path $root '.workshop'
. (Join-Path $root 'scripts' 'context-common.ps1')

# Plans, checks every change against the allow-list, keeps only module 05 work, then reports or applies.
function Invoke-GuardedPhase([string]$Directory, [string[]]$Arguments, [hashtable]$Allowed, [scriptblock]$Relevant, [string]$Label) {
    if (-not (Test-Path -LiteralPath $private)) { $null = New-Item -ItemType Directory -Path $private }
    $script:PhaseDone = $false
    $plan = Join-Path $private "module05-cleanup-$([guid]::NewGuid().ToString('N')).tfplan"
    try {
        & terraform "-chdir=$Directory" plan -input=false -no-color @Arguments "-out=$plan" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform plan for '$Label' (expected HTTP 200)." }
        $document = & terraform "-chdir=$Directory" show -json $plan | ConvertFrom-Json -AsHashtable -Depth 100
        # A plan with no change may omit resource_changes; treat it as an empty list.
        $all = if ($document -is [System.Collections.IDictionary] -and $document.Contains('resource_changes') -and $null -ne $document.resource_changes) { @($document.resource_changes) } else { @() }
        $changes = @($all | Where-Object { $null -ne $_ -and $_.change.actions -notcontains 'no-op' -and $_.change.actions -notcontains 'read' })
        $foreign = @($changes | Where-Object {
            $address = $_.address -replace '\[[^\]]+\]$', ''
            # API Management stores policies as normalised XML (tabs, entities, format 'xml'), so every plan re-sends the
            # module 04 policies unchanged. Accept that update only when the policy text is identical apart from
            # whitespace and XML entity encoding.
            $whitespaceOnly = $address -in @('azapi_resource.mcp_api_policy', 'azapi_resource.prm_operation_policy', 'azapi_resource.rest_api_policy',
                'azapi_resource.rest_mcp_policy', 'azapi_resource.rest_mcp_prm_operation_policy') -and
                ($_.change.actions -join ',') -eq 'update' -and
                ([Net.WebUtility]::HtmlDecode([string]$_.change.before.body.properties.value) -replace '\s', '') -ceq
                ([Net.WebUtility]::HtmlDecode([string]$_.change.after.body.properties.value) -replace '\s', '')
            -not $whitespaceOnly -and -not (Test-WorkshopPortalTierRestore $_) -and (-not $Allowed.ContainsKey($address) -or ($_.change.actions -join ',') -ne $Allowed[$address]) })
        if ($foreign.Count -gt 0) {
            throw "FAIL '$Label' plan contains $($foreign.Count) change(s) outside module 05; nothing was applied. Review 'terraform plan' privately (expected HTTP N/A)."
        }
        Write-WorkshopPortalTierNotes $changes
        $work = @($changes | Where-Object { & $Relevant $_ })
        if ($work.Count -eq 0) {
            Write-Output "PASS '$Label': nothing to do in this state (idempotent, expected HTTP N/A)."
            $script:PhaseDone = $true
            return
        }
        $work | ForEach-Object { Write-Output "PLAN $($_.change.actions -join ',') $($_.address) ($Label)" }
        if (-not $Apply) {
            Write-Output "PASS '$Label' plan changes only $($work.Count) module 05 object(s). Review it, then rerun with -Apply."
            return
        }
        & terraform "-chdir=$Directory" apply -input=false -no-color $plan
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform apply for '$Label'. Rerun this script; it plans again from the current state." }
        Write-Output "PASS '$Label' applied (expected HTTP 200)."
        $script:PhaseDone = $true
    }
    finally {
        Remove-Item -LiteralPath $plan -Force -ErrorAction SilentlyContinue
    }
}

if ($Scope -eq 'Workload') {
    if (-not $SubscriptionId -or $SubscriptionId -eq [guid]::Empty) { throw 'FAIL -SubscriptionId is required for the workload clean-up (expected HTTP N/A).' }
    if (-not $ParametersPath) { $ParametersPath = Join-Path $private 'participant.tfvars.json' }
    if (-not $Module02VarFile) { $Module02VarFile = Join-Path $private 'module02.tfvars.json' }
    if (-not $Module03VarFile) { $Module03VarFile = Join-Path $private 'module03.tfvars.json' }
    if (-not $Module04VarFile) { $Module04VarFile = Join-Path $private 'module04.tfvars.json' }
    if (-not $Module04bVarFile) { $Module04bVarFile = Join-Path $private 'module04b.tfvars.json' }
    if (-not $Module05VarFile) { $Module05VarFile = Join-Path $private 'module05.tfvars.json' }
    $null = Read-WorkshopParameters -Path $ParametersPath
    foreach ($file in @($Module02VarFile, $Module03VarFile)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw 'FAIL module 02 or 03 opt-in file not found. Without both, the plan would also remove the server or its authentication (expected HTTP N/A).'
        }
    }
    Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
    Write-Output 'PASS explicit Azure context and private participant parameters (expected HTTP 200 from Azure Resource Manager).'
    $directory = Join-Path $root 'infra' 'workload'
    & terraform "-chdir=$directory" init -lockfile=readonly -input=false -no-color | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform init (expected HTTP N/A). Use the pinned Terraform and the locked providers.' }
    $arguments = @("-var-file=$ParametersPath", "-var-file=$Module02VarFile", "-var-file=$Module03VarFile")
    if (Test-Path -LiteralPath $Module04VarFile -PathType Leaf) { $arguments += "-var-file=$Module04VarFile" }
    # Keep the optional module 04 part B as deployed: module 04's own clean-up removes it.
    if (Test-Path -LiteralPath $Module04bVarFile -PathType Leaf) { $arguments += "-var-file=$Module04bVarFile" }
    if (Test-Path -LiteralPath $Module05VarFile -PathType Leaf) { $arguments += "-var-file=$Module05VarFile" }
    $arguments += '-var=enable_delegated_access=false'
    $allowed = @{ 'azurerm_function_app_flex_consumption.mcp' = 'update' }
    foreach ($address in @('azurerm_role_assignment.report_app_reader', 'azurerm_role_assignment.report_persona_reader', 'azurerm_role_assignment.report_publisher',
            'azurerm_storage_container.reports', 'azurerm_user_assigned_identity.delegated_obo', 'azurerm_user_assigned_identity.delegated_report')) {
        $allowed[$address] = 'delete'
    }
    # The module 02 app_settings diff is a known in-place update on every plan; only deletions count as module 05 work.
    Invoke-GuardedPhase $directory $arguments $allowed { param($change) $change.change.actions -contains 'delete' } 'remove module 05 workload resources'
    if ($script:PhaseDone -and $Apply) {
        Write-Output 'PASS whoami and read_report_* are back to the module 02 demonstrations. Remove .workshop/module05.tfvars.json. The identity administrator runs -Scope Entra next.'
    }
    return
}

if (-not $EntraParametersPath) { $EntraParametersPath = Join-Path $private 'entra.tfvars.json' }
if (-not $EntraModule05VarFile) { $EntraModule05VarFile = Join-Path $private 'entra-module05.tfvars.json' }
if (-not (Test-Path -LiteralPath $EntraParametersPath -PathType Leaf)) { throw 'FAIL private infra/entra parameters not found (expected HTTP N/A).' }
Assert-WorkshopInteractiveEnvironment
$account = Invoke-WorkshopAzureJson -Arguments @('account', 'show', '--query', '{tenantId:tenantId,userType:user.type}')
if ($account.tenantId -ne $TenantId.ToString() -or $account.userType -ne 'user') {
    throw 'FAIL Azure CLI must be signed in interactively as the identity administrator in the explicit tenant (expected HTTP N/A).'
}
Write-Output 'PASS explicit tenant and interactive identity administrator sign-in (expected HTTP 200 from Microsoft Graph).'
$directory = Join-Path $root 'infra' 'entra'
& terraform "-chdir=$directory" init -lockfile=readonly -input=false -no-color | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform init (expected HTTP N/A). Use the pinned Terraform and the locked provider.' }
if (-not (Test-Path -LiteralPath $private)) { $null = New-Item -ItemType Directory -Path $private }
$off = Join-Path $private "module05-entra-off-$([guid]::NewGuid().ToString('N')).tfvars.json"
try {
    # JSON null clears the optional subject; a -var flag would pass the literal string "null".
    @{ enable_delegated_access = $false; obo_identity_principal_id = $null; grant_downstream_admin_consent = $false } | ConvertTo-Json | Set-Content -LiteralPath $off -Encoding utf8NoBOM
    $arguments = @("-var-file=$EntraParametersPath")
    if (Test-Path -LiteralPath $EntraModule05VarFile -PathType Leaf) { $arguments += "-var-file=$EntraModule05VarFile" }
    $arguments += "-var-file=$off"
    $allowed = @{
        'azuread_application_federated_identity_credential.obo' = 'delete'
        'azuread_application_api_access.downstream' = 'delete'
        'azuread_service_principal_delegated_permission_grant.downstream' = 'delete'
    }
    Invoke-GuardedPhase $directory $arguments $allowed { param($change) $true } 'remove module 05 Entra delegation'
}
finally {
    Remove-Item -LiteralPath $off -Force -ErrorAction SilentlyContinue
}
if ($script:PhaseDone -and $Apply) {
    Write-Output 'PASS the MCP API no longer trusts the workload identity or requests downstream permissions. Module 03 objects stay; use modules/03-entra-authentication/cleanup.ps1 -Scope Entra next if you continue.'
}

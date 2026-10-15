#requires -Version 7.4
<#
.SYNOPSIS
    Module 03 clean-up. Idempotent, plan-reviewed, refuses anything outside module 03.
.DESCRIPTION
    -Scope Workload (participant, default): two guarded phases on infra/workload, in the safe order:
      1. restore the level 0 key gate while built-in authentication still runs (entra_auth_replace_key_gate = false);
      2. remove built-in authentication (enable_entra_auth = false).
      Each phase accepts only an in-place update of the MCP Function App. The server itself stays;
      run modules/02-open-server/cleanup.ps1 afterwards to delete it.
    -Scope Entra (identity administrator): plans a destroy of infra/entra. Only workshop-created objects are accepted:
      the MCP API registration, its Application ID URI, enterprise application, pre-authorizations and persona
      assignments. Administrator-provided applications and existing test users are data sources and are never deleted.
    Without -Apply it only reports the next phase. With -Apply it applies each exact reviewed plan.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [guid]$SubscriptionId,
    [ValidateSet('Workload', 'Entra')][string]$Scope = 'Workload',
    [string]$ParametersPath,
    [string]$Module02VarFile,
    [string]$Module03VarFile,
    [string]$EntraParametersPath,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$private = Join-Path $root '.workshop'
$webhookSetting = 'AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel'
. (Join-Path $root 'scripts' 'context-common.ps1')

function Get-Before($Change, [string]$Name) {
    $before = $Change.change.before
    if ($before -is [System.Collections.IDictionary] -and $before.Contains($Name)) { return $before[$Name] }
    return $null
}

# Plans, checks every change against the allow-list, keeps only module 03 work, then reports or applies.
# Sets $script:PhaseDone to $true when nothing is left to do in this phase (output lines stay on the pipeline).
function Invoke-GuardedPhase([string]$Directory, [string[]]$Arguments, [hashtable]$Allowed, [scriptblock]$Relevant, [string]$Label) {
    if (-not (Test-Path -LiteralPath $private)) { $null = New-Item -ItemType Directory -Path $private }
    $script:PhaseDone = $false
    $plan = Join-Path $private "module03-cleanup-$([guid]::NewGuid().ToString('N')).tfplan"
    try {
        & terraform "-chdir=$Directory" plan -input=false -no-color @Arguments "-out=$plan" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FAIL Terraform plan for '$Label' (expected HTTP 200)." }
        $changes = @((& terraform "-chdir=$Directory" show -json $plan | ConvertFrom-Json -AsHashtable -Depth 100).resource_changes |
            Where-Object { $_.change.actions -notcontains 'no-op' -and $_.change.actions -notcontains 'read' })
        $foreign = @($changes | Where-Object {
            $address = $_.address -replace '\[[^\]]+\]$', ''
            -not $Allowed.ContainsKey($address) -or ($_.change.actions -join ',') -ne $Allowed[$address] })
        if ($foreign.Count -gt 0) {
            throw "FAIL '$Label' plan contains $($foreign.Count) change(s) outside module 03; nothing was applied. Review 'terraform plan' privately (expected HTTP N/A)."
        }
        $work = @($changes | Where-Object { & $Relevant $_ })
        if ($work.Count -eq 0) {
            Write-Output "PASS '$Label': nothing to do in this state (idempotent, expected HTTP N/A)."
            $script:PhaseDone = $true
            return
        }
        $work | ForEach-Object { Write-Output "PLAN $($_.change.actions -join ',') $($_.address) ($Label)" }
        if (-not $Apply) {
            Write-Output "PASS '$Label' plan changes only $($work.Count) module 03 object(s). Review it, then rerun with -Apply."
            $script:PhaseDone = $false
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
    $null = Read-WorkshopParameters -Path $ParametersPath
    if (-not (Test-Path -LiteralPath $Module02VarFile -PathType Leaf)) {
        throw 'FAIL module 02 opt-in file not found. Without it the plan would delete the server; use modules/02-open-server/cleanup.ps1 for that (expected HTTP N/A).'
    }
    Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
    Write-Output 'PASS explicit Azure context and private participant parameters (expected HTTP 200 from Azure Resource Manager).'
    $directory = Join-Path $root 'infra' 'workload'
    & terraform "-chdir=$directory" init -lockfile=readonly -input=false -no-color | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'FAIL Terraform init (expected HTTP N/A). Use the pinned Terraform and the locked provider.' }
    $allowed = @{ 'azurerm_function_app_flex_consumption.mcp' = 'update' }
    $common = @("-var-file=$ParametersPath", "-var-file=$Module02VarFile")

    # Module 02 has a known in-place app_settings diff on every plan; only module 03 settings count as work here.
    if (Test-Path -LiteralPath $Module03VarFile -PathType Leaf) {
        Invoke-GuardedPhase $directory ($common + @("-var-file=$Module03VarFile", '-var=entra_auth_replace_key_gate=false')) $allowed {
            param($change)
            $settings = Get-Before $change 'app_settings'
            $settings -is [System.Collections.IDictionary] -and $settings.Contains($webhookSetting)
        } 'phase 1: restore the key gate behind Entra'
        if (-not $script:PhaseDone) { return }
    }
    Invoke-GuardedPhase $directory ($common + @('-var=enable_entra_auth=false', '-var=entra_auth_replace_key_gate=false')) $allowed {
        param($change)
        @(Get-Before $change 'auth_settings_v2' | Where-Object { $null -ne $_ }).Count -gt 0
    } 'phase 2: remove built-in authentication'
    if ($script:PhaseDone -and $Apply) {
        Write-Output 'PASS the server is back to the level 0 key gate. Remove .workshop/module03.tfvars.json, then run modules/02-open-server/cleanup.ps1 to delete it.'
    }
    return
}

if (-not $EntraParametersPath) { $EntraParametersPath = Join-Path $private 'entra.tfvars.json' }
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
$allowed = @{
    'azuread_application.mcp' = 'delete'; 'azuread_application_identifier_uri.mcp' = 'delete'
    'azuread_service_principal.mcp' = 'delete'; 'azuread_application_pre_authorized.clients' = 'delete'
    'azuread_app_role_assignment.personas' = 'delete'
}
Invoke-GuardedPhase $directory @("-var-file=$EntraParametersPath", '-destroy') $allowed { param($change) $true } 'destroy workshop-created Entra objects'
if ($script:PhaseDone -and $Apply) {
    Write-Output 'PASS provided applications and existing test users were not touched. Deleted registrations stay restorable for 30 days in Microsoft Entra.'
}

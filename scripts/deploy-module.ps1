#requires -Version 7.4
<#
.SYNOPSIS
  Plans, applies (after you type yes) and validates one workshop module, reusing every private file from earlier modules.
.DESCRIPTION
  Iterative path: run it for 02, then 03, 04, 05, 07, in order. Each run passes the same cumulative Terraform var files
  you created by following the module guides, in the documented order. It never creates those files: the module guide
  explains each one (some need IDs from your identity administrator). It never uses -auto-approve or a secret.
  Run scripts/select-azure-context.ps1 first, in the same terminal.
.EXAMPLE
  & .\scripts\deploy-module.ps1 -Module 04
.EXAMPLE
  & .\scripts\deploy-module.ps1 -Module 03 -Root entra -PlanOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('00', '02', '03', '04', '04b', '05', '06', '07')][string]$Module,
    [ValidateSet('workload', 'entra')][string]$Root = 'workload',
    [switch]$PlanOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$private = Join-Path $repo '.workshop'
. (Join-Path $PSScriptRoot 'context-common.ps1')

# Cumulative private files, in the order the module guides pass them. 'from' is the first module that needs the file.
$catalog = @{
    workload = @(
        @{ file = 'participant.tfvars.json'; from = '00'; guide = 'docs/GETTING-STARTED.md (section 3)' }
        @{ file = 'module02.tfvars.json'; from = '02'; guide = 'modules/02-open-server/README.md (Steps, 1)' }
        @{ file = 'module03.tfvars.json'; from = '03'; guide = 'modules/03-entra-authentication/README.md (Steps)' }
        @{ file = 'module04.tfvars.json'; from = '04'; guide = 'modules/04-governed-gateway/README.md (Steps, 2)'; optionalAfter = $true }
        @{ file = 'module04b.tfvars.json'; from = '04b'; guide = 'modules/04-governed-gateway/README.md (part B)'; optionalAfter = $true }
        @{ file = 'module05.tfvars.json'; from = '05'; guide = 'modules/05-delegated-and-app-only/README.md (Steps, 2)' }
        @{ file = 'module07.tfvars.json'; from = '07'; guide = 'modules/07-clients/README.md (Steps)' }
    )
    entra = @(
        @{ file = 'entra.tfvars.json'; from = '03'; guide = 'modules/03-entra-authentication/README.md (identity administrator)' }
        @{ file = 'entra-module05.tfvars.json'; from = '05'; guide = 'modules/05-delegated-and-app-only/README.md (identity administrator)' }
        @{ file = 'entra-module07.tfvars.json'; from = '07'; guide = 'modules/07-clients/README.md (Steps)' }
    )
}
$order = '00', '02', '03', '04', '04b', '05', '06', '07'
$rank = { param($id) [array]::IndexOf($order, $id) }

function Write-Step([string]$text) { Write-Output ''; Write-Output "== $text ==" }

if ($Module -in '00', '06') {
    Write-Output "Module $Module deploys nothing with Terraform. Run its validator:"
    $validationArgs = if ($Module -eq '06') { '-Offline' } else { '-TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID' }
    Write-Output "  & .\modules\$(Split-Path (Resolve-Path (Join-Path $repo "modules\$Module-*")) -Leaf)\validate.ps1 $validationArgs"
    if ($Module -eq '06') { Write-Output 'INFO -Offline checks the guide and queries only. Run the live inventory and telemetry checks in the module guide separately.' }
    return
}
if ($Root -eq 'entra' -and $Module -notin '03', '05', '07') { throw 'infra/entra changes only in modules 03, 05 and 07.' }

Write-Step "1. Context: module $Module, root infra/$Root"
if (-not $env:ARM_TENANT_ID -or -not $env:ARM_SUBSCRIPTION_ID) {
    throw 'Run & .\scripts\select-azure-context.ps1 in this terminal first. It sets ARM_TENANT_ID and ARM_SUBSCRIPTION_ID.'
}
Assert-WorkshopAzureContext -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
Write-Output 'PASS the signed-in account matches the approved test tenant and subscription (expected HTTP 200).'

Write-Step '2. Private var files (cumulative, never committed)'
$varArgs = @()
foreach ($entry in $catalog[$Root]) {
    if ((& $rank $entry.from) -gt (& $rank $Module)) { continue }
    $path = Join-Path $private $entry.file
    if (Test-Path -LiteralPath $path) {
        $varArgs += "-var-file=$path"
        Write-Output "PASS $($entry.file)"
    } elseif ($entry.from -eq $Module -or -not $entry.ContainsKey('optionalAfter')) {
        throw "Missing .workshop\$($entry.file). Create it as shown in $($entry.guide), then run this script again."
    } else {
        Write-Output "INFO $($entry.file) not found: that optional module was skipped, so it is not passed."
    }
}

if ($Root -eq 'workload') {
    $null = Read-WorkshopParameters -Path (Join-Path $private 'participant.tfvars.json')
}
$planName = if ($Root -eq 'entra') { "entra$Module.tfplan" } else { "module$Module.tfplan" }
$plan = Join-Path $private $planName
$terraformRoot = Join-Path $repo 'infra' $Root
Write-Step "3. Terraform plan (read-only), saved to .workshop\$planName"
& terraform "-chdir=$terraformRoot" init -lockfile=readonly -input=false | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'terraform init failed. Run it alone to read the error.' }
& terraform "-chdir=$terraformRoot" plan -input=false @varArgs "-out=$plan"
if ($LASTEXITCODE -ne 0) { throw 'terraform plan failed. Nothing was changed.' }
if ($PlanOnly) { Write-Output 'INFO -PlanOnly: nothing was applied.'; return }

Write-Step '4. Apply the saved plan, after your review'
Write-Output 'Read the plan above: what is added, changed and, above all, destroyed. Compare it with the module guide.'
$answer = Read-Host "Type yes to apply exactly this plan to your test subscription"
if ($answer -cne 'yes') { Write-Output 'Stopped. Nothing was applied; the saved plan stays in .workshop.'; return }
& terraform "-chdir=$terraformRoot" apply -input=false $plan
if ($LASTEXITCODE -ne 0) { throw 'terraform apply failed. Read the error, fix the cause, then plan again.' }

Write-Step '5. Validate'
$folder = Split-Path (Resolve-Path (Join-Path $repo "modules\$($Module.Substring(0, 2))-*")) -Leaf
if ($Root -eq 'entra') {
    Write-Output "INFO infra/entra applied. Continue the module $Module guide: next is the workload step, then its validator."
    return
}
$validator = if ($Module -eq '04b') { 'validate-rest-mcp.ps1' } else { 'validate.ps1' }
if ($Module -eq '07') {
    & (Join-Path $repo "modules\$folder\$validator") -Offline
    Write-Output 'INFO module 07 validation is offline only. Complete the live client and consent checks in the module guide separately.'
} else {
    & (Join-Path $repo "modules\$folder\$validator") -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
}

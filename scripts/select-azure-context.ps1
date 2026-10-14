param([ValidateSet('en', 'fr')][string]$Language = 'en')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$fr = $Language -eq 'fr'
Get-Command az -ErrorAction Stop | Out-Null

. (Join-Path $PSScriptRoot 'context-common.ps1')
Assert-WorkshopInteractiveEnvironment

$cloud = az cloud show --query name --output tsv
if ($LASTEXITCODE -ne 0 -or $cloud -ne 'AzureCloud') {
    throw 'This workshop targets Azure public cloud. Cloud selection failed or does not match; nothing will be deployed.'
}
$tenant = Read-Host $(if ($fr) { 'ID du tenant Entra de test approuvé (terminal uniquement)' } else { 'Approved non-production Entra tenant ID (terminal only)' })
$subscription = Read-Host $(if ($fr) { 'ID de votre abonnement Azure de test approuvé' } else { 'Your approved non-production Azure subscription ID' })
$parsedTenant = [guid]::Empty
$parsedSubscription = [guid]::Empty
if (-not [guid]::TryParseExact($tenant, 'D', [ref]$parsedTenant) -or $parsedTenant -eq [guid]::Empty -or
    -not [guid]::TryParseExact($subscription, 'D', [ref]$parsedSubscription) -or $parsedSubscription -eq [guid]::Empty) {
    throw 'Enter valid tenant and subscription IDs from your approved environment. Do not paste them into the board.'
}
$confirmation = Read-Host $(if ($fr) { 'Tapez NONPROD pour confirmer le périmètre de test et la connexion interactive' } else { 'Type NONPROD to confirm the approved test scope and interactive sign-in' })
if ($confirmation -cne 'NONPROD') { throw 'Selection cancelled. No sign-in or deployment was started.' }

az login --tenant $tenant --output none
if ($LASTEXITCODE -ne 0) { throw 'Azure sign-in failed. Stop here; do not deploy.' }
az account set --subscription $subscription
if ($LASTEXITCODE -ne 0) { throw 'Subscription selection failed. Stop here; do not deploy.' }
$accountJson = az account show --query '{subscription:id,tenant:tenantId,state:state}' --output json
if ($LASTEXITCODE -ne 0) { throw 'Could not verify Azure context. Stop here; do not deploy.' }
$account = $accountJson | ConvertFrom-Json
if ($account.tenant -ne $tenant -or $account.subscription -ne $subscription -or $account.state -ne 'Enabled') {
    throw 'The active tenant/subscription does not match the approved target, or the subscription is not enabled. Stop here.'
}

$env:ARM_TENANT_ID = $tenant
$env:ARM_SUBSCRIPTION_ID = $subscription
Write-Output $(if ($fr) {
    'PASS contexte : tenant et abonnement vérifiés. Variables ARM définies dans ce processus uniquement. Aucune ressource créée ; ce contrôle ne valide pas le module 00.'
} else {
    'PASS context: tenant and subscription verified. ARM variables set in this process only. No resources created; this check does not validate module 00.'
})

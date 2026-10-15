#requires -Version 7.4
<#
.SYNOPSIS
    Module 05: publish the synthetic report blob to the report container. Idempotent.
.DESCRIPTION
    Uploads synthetic-data/monthly-usage.json as monthly-usage.json to the module 05 'reports' container with Microsoft Entra
    authentication (az storage blob upload --auth-mode login). Storage shared keys are disabled, so no key or SAS is used.
    The signed-in user needs Storage Blob Data Contributor on that container; infra/workload grants it to the person who ran
    Terraform (delegated_report_publisher_object_id). Role assignments can take a few minutes to apply, so upload is retried.
    Refuses to upload anything that is not the labelled synthetic report.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [ValidateRange(1, 10)][int]$Attempts = 6,
    [ValidateRange(0, 120)][int]$RetryDelaySeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'scripts' 'context-common.ps1')

$file = Join-Path $PSScriptRoot 'synthetic-data' 'monthly-usage.json'
$report = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -AsHashtable
if ($report.report -ne 'monthly-usage' -or $report.source -ne 'synthetic' -or @($report.rows).Count -lt 1) {
    throw 'FAIL synthetic-data/monthly-usage.json is not the labelled synthetic report; nothing was uploaded (expected HTTP N/A).'
}

Assert-WorkshopAzureContext -TenantId $TenantId -SubscriptionId $SubscriptionId
Write-Output 'PASS explicit Azure context (expected HTTP 200 from Azure Resource Manager).'
$outputs = & terraform "-chdir=$(Join-Path $root 'infra' 'workload')" output -json | ConvertFrom-Json -AsHashtable
if ($LASTEXITCODE -ne 0 -or $null -eq $outputs -or -not $outputs.delegated_access_enabled?.value) {
    throw 'FAIL module 05 is not deployed in this state (enable_delegated_access is false); apply it first (expected HTTP N/A).'
}
$account = $outputs.delegated_storage_account_name.value
$blob = $outputs.delegated_report_blob_name.value

for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
    $null = & az storage blob upload --auth-mode login --account-name $account --container-name reports --name $blob `
        --file $file --overwrite true --content-type application/json --only-show-errors --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "PASS synthetic report published as reports/$blob with Microsoft Entra authentication, no key or SAS (expected HTTP 201)."
        return
    }
    if ($attempt -lt $Attempts) {
        Write-Output "INFO upload attempt $attempt refused; the Storage Blob Data Contributor role may still be propagating. Retrying in $RetryDelaySeconds s."
        Start-Sleep -Seconds $RetryDelaySeconds
    }
}
throw "FAIL could not publish the synthetic report after $Attempts attempts. Check that you hold Storage Blob Data Contributor on the reports container (expected HTTP 201)."

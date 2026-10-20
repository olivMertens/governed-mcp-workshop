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
    -InsideVirtualNetwork: when Storage public network access is Disabled, the upload runs from a short-lived Azure Container
    Instance in a temporary subnet, signed in with a temporary managed identity that holds Storage Blob Data Contributor on
    the reports container only. All of them are deleted at the end. -StorageAccount and -ResourceGroup serve the low-code track.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [ValidateRange(1, 10)][int]$Attempts = 6,
    [ValidateRange(0, 120)][int]$RetryDelaySeconds = 20,
    # Low-code track: the storage account name instead of Terraform outputs.
    [string]$StorageAccount,
    # Private storage (public network access Disabled): upload from a short-lived container inside the virtual network.
    [switch]$InsideVirtualNetwork,
    [string]$ResourceGroup,
    [string]$SubnetPrefix
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
if ($StorageAccount) {
    $account = $StorageAccount; $blob = 'monthly-usage.json'
} else {
    $outputs = & terraform "-chdir=$(Join-Path $root 'infra' 'workload')" output -json | ConvertFrom-Json -AsHashtable
    if ($LASTEXITCODE -ne 0 -or $null -eq $outputs -or -not $outputs.delegated_access_enabled?.value) {
        throw 'FAIL module 05 is not deployed in this state (enable_delegated_access is false); apply it first (expected HTTP N/A).'
    }
    $account = $outputs.delegated_storage_account_name.value
    $blob = $outputs.delegated_report_blob_name.value
    if ($InsideVirtualNetwork -and -not $ResourceGroup) { $ResourceGroup = $outputs.resource_group_name?.value }
}

if ($InsideVirtualNetwork) {
    # Temporary subnet, managed identity with a role on the reports container only, and one container group; all deleted
    # at the end. No key, SAS or secret: the container signs in with its managed identity.
    if (-not $ResourceGroup -or -not $SubnetPrefix) { throw 'FAIL -InsideVirtualNetwork needs -ResourceGroup and a free -SubnetPrefix (/28) in the virtual network (expected HTTP N/A).' }
    $rg = $ResourceGroup; $name = 'aci-report-upload'; $subnet = 'snet-aci-upload-tmp'; $id = $null
    $vnet = (& az network vnet list -g $rg --query '[0].name' -o tsv --only-show-errors | Out-String).Trim()
    if (-not $vnet) { throw "FAIL no virtual network in $rg; without private storage, run this script without -InsideVirtualNetwork (expected HTTP N/A)." }
    $scope = (& az storage account show -g $rg -n $account --query id -o tsv --only-show-errors | Out-String).Trim() + '/blobServices/default/containers/reports'
    $payload = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
    $script = "echo `$REPORT_B64 | base64 -d > /tmp/r.json && az login --identity --client-id `$CLIENT_ID -o none && for i in 1 2 3 4 5 6; do " +
        "az storage blob upload --auth-mode login --account-name $account --container-name reports --name $blob --file /tmp/r.json " +
        "--overwrite true --content-type application/json -o none && echo UPLOADED && exit 0; sleep 20; done; echo FAILED; exit 1"
    try {
        & az network vnet subnet create -g $rg --vnet-name $vnet -n $subnet --address-prefixes $SubnetPrefix --delegations Microsoft.ContainerInstance/containerGroups -o none --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "FAIL could not create the temporary subnet $SubnetPrefix; pick a free /28 in $vnet (expected HTTP 200)." }
        $id = & az identity create -g $rg -n "id-$name" -o json --only-show-errors | ConvertFrom-Json
        & az role assignment create --assignee-object-id $id.principalId --assignee-principal-type ServicePrincipal --role 'Storage Blob Data Contributor' --scope $scope -o none --only-show-errors
        Write-Output 'INFO temporary subnet, identity and container-scoped role created; waiting 60 s for the role to apply.'
        Start-Sleep -Seconds 60
        & az container create -g $rg -n $name --image mcr.microsoft.com/azure-cli:2.91.0 --os-type Linux --cpu 1 --memory 1.5 --restart-policy Never `
            --assign-identity $id.id --vnet $vnet --subnet $subnet --environment-variables "REPORT_B64=$payload" "CLIENT_ID=$($id.clientId)" `
            --command-line "/bin/bash -c '$script'" -o none --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw 'FAIL could not start the temporary container (expected HTTP 200).' }
        for ($i = 0; $i -lt 40; $i++) {
            $state = (& az container show -g $rg -n $name --query 'containers[0].instanceView.currentState.state' -o tsv --only-show-errors | Out-String).Trim()
            if ($state -eq 'Terminated') { break }; Start-Sleep -Seconds 10
        }
        $log = & az container logs -g $rg -n $name --only-show-errors | Out-String
        if ($log -notmatch 'UPLOADED') { throw 'FAIL the container inside the virtual network could not upload the report (expected HTTP 201).' }
        Write-Output "PASS synthetic report published as reports/$blob from inside the virtual network, with a managed identity, no key or SAS (expected HTTP 201)."
    } finally {
        & az container delete -g $rg -n $name --yes -o none --only-show-errors 2>$null
        if ($id) {
            & az role assignment delete --assignee $id.principalId --scope $scope -o none --only-show-errors 2>$null
            & az identity delete -g $rg -n "id-$name" -o none --only-show-errors 2>$null
        }
        for ($i = 0; $i -lt 12; $i++) { & az network vnet subnet delete -g $rg --vnet-name $vnet -n $subnet -o none --only-show-errors 2>$null; if ($LASTEXITCODE -eq 0) { break }; Start-Sleep -Seconds 20 }
        & az network nsg list -g $rg --query '[].name' -o tsv --only-show-errors | Where-Object { $_ -match $subnet } | ForEach-Object { & az network nsg delete -g $rg -n $_ -o none --only-show-errors }
        Write-Output 'INFO temporary container, identity, role, subnet and its network security group deleted.'
    }
    return
}

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

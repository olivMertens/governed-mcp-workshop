#requires -Version 7.4
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][guid]$TenantId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [Parameter(Mandatory)][string]$CapacityReviewPath,
    [string]$ParametersPath = (Join-Path (Split-Path $PSScriptRoot -Parent) '.workshop/participant.tfvars.json'),
    [string]$BundlePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'portal-dist'),
    [string]$PackagePath = (Join-Path (Split-Path $PSScriptRoot -Parent) '.workshop/portal.zip')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'context-common.ps1')
$parameters = Read-WorkshopParameters -Path $ParametersPath
if (-not $parameters.Contains('public_portal_enabled') -or -not $parameters.public_portal_enabled) {
    throw 'Public portal is not opted in in the persistent participant parameters.'
}
& node (Join-Path $PSScriptRoot 'portal-server.mjs') --verify $BundlePath
if ($LASTEXITCODE -ne 0) { throw 'Portal bundle verification failed.' }
& (Join-Path $PSScriptRoot 'preflight.ps1') -TenantId $TenantId -SubscriptionId $SubscriptionId `
    -Stage portal -ParametersPath $ParametersPath -CapacityReviewPath $CapacityReviewPath
$stem = "mcp-$($parameters.participant_prefix)-$($parameters.resource_suffix)"
$name = "web-$stem-portal"
$group = if ($parameters.existing_resource_group_name) { $parameters.existing_resource_group_name } else { "rg-$stem" }
$id = "/subscriptions/$SubscriptionId/resourceGroups/$group/providers/Microsoft.Web/sites/$name"
$dynamicInstall = $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL
$env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'no'
try {
    $app = Invoke-WorkshopAzureJson -Arguments @('webapp', 'show', '--subscription', $SubscriptionId.ToString(),
        '--resource-group', $group, '--name', $name, '--query',
        '{id:id,httpsOnly:httpsOnly,defaultHostName:defaultHostName,tags:tags,serverFarmId:serverFarmId}')
    if ($app.id -ne $id -or -not $app.httpsOnly -or $app.tags.workshop -cne $stem -or
        $app.tags.owner -cne $parameters.owner -or $app.tags.expiry -cne $parameters.expiry -or
        $app.serverFarmId -ne "/subscriptions/$SubscriptionId/resourceGroups/$group/providers/Microsoft.Web/serverfarms/plan-$stem-portal" -or
        $app.defaultHostName -notmatch '^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.azurewebsites\.net$') {
        throw 'Portal ownership, target, plan, host or HTTPS protection differs from the expected Terraform deployment.'
    }
    $configuration = Invoke-WorkshopAzureJson -Arguments @('webapp', 'config', 'show', '--subscription', $SubscriptionId.ToString(),
        '--resource-group', $group, '--name', $name, '--query',
        '{linuxFxVersion:linuxFxVersion,appCommandLine:appCommandLine,ftpsState:ftpsState,minTlsVersion:minTlsVersion,scmMinTlsVersion:scmMinTlsVersion}')
    if ($configuration.linuxFxVersion -ine 'NODE|22-lts' -or $configuration.appCommandLine -cne 'node server.mjs' -or
        $configuration.ftpsState -ne 'Disabled' -or $configuration.minTlsVersion -notin @('1.2', '1.3') -or
        $configuration.scmMinTlsVersion -notin @('1.2', '1.3')) {
        throw 'Portal runtime or transport configuration differs from the reviewed setup.'
    }
    foreach ($policy in @('scm', 'ftp')) {
        $setting = Invoke-WorkshopAzureJson -Arguments @('rest', '--method', 'get', '--url',
            "https://management.azure.com$id/basicPublishingCredentialsPolicies/$policy`?api-version=2025-03-01")
        if ($setting.properties.allow -isnot [bool] -or $setting.properties.allow) {
            throw 'Basic publishing is not explicitly disabled. No key or publish-profile fallback is permitted.'
        }
    }
    if ($PSCmdlet.ShouldProcess("$name in $group", 'Replace public documentation code using Entra-authenticated ZIP deployment')) {
        & (Join-Path $PSScriptRoot 'package-portal.ps1') -BundlePath $BundlePath -OutputPath $PackagePath
        $deployOutput = & az webapp deploy --subscription $SubscriptionId.ToString() --resource-group $group --name $name `
            --src-path ([IO.Path]::GetFullPath($PackagePath)) --type zip --clean false --restart true `
            --track-status true --only-show-errors 2>&1
        if ($LASTEXITCODE -ne 0) {
            # The Kudu status can report a false failure while the OneDeploy log shows success, so check the log.
            $deployId = & az webapp log deployment list --subscription $SubscriptionId.ToString() --resource-group $group `
                --name $name --query '[0].id' -o tsv --only-show-errors 2>$null
            $deployLog = if ($deployId) {
                & az webapp log deployment show --subscription $SubscriptionId.ToString() --resource-group $group `
                    --name $name --deployment-id $deployId -o json --only-show-errors 2>$null
            }
            $succeeded = $deployLog -and (($deployLog | Out-String) -match 'Deployment successful')
            if (-not $succeeded) {
                Write-Warning (($deployOutput | Out-String).Trim())
                throw 'Entra ZIP deployment failed. Inspect the deployment status privately; do not enable basic publishing or use credentials as a fallback.'
            }
            Write-Warning 'az webapp deploy reported a non-zero exit, but the latest deployment log shows success. Continuing with the health check.'
        }
        $health = Invoke-WebRequest -Uri "https://$($app.defaultHostName)/health" -SkipHttpErrorCheck -TimeoutSec 30
        if ($health.StatusCode -ne 200 -or $health.Content -cne '{"status":"ok"}') {
            throw 'FAIL public portal health (expected HTTP 200 and the exact read-only health response).'
        }
        Write-Output 'PASS public portal health (expected HTTP 200). Verify EN/FR navigation and diagrams on the deployed host before sharing.'
    }
} finally { $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = $dynamicInstall }

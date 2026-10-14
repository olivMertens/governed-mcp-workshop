import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("../", import.meta.url));
test("preflight is read-only and fails closed for context, permission, provider, quota, runtime and evidence errors", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-preflight-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const script = join(root, "scripts", "preflight.ps1").replaceAll("'", "''");
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", `
$ErrorActionPreference = 'Stop'
Get-ChildItem Env: | Where-Object { $_.Name -match '^(ARM_|AZURE_)' } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
$global:tenant = [guid]::NewGuid()
$global:subscription = [guid]::NewGuid()
$global:calls = [Collections.Generic.List[string]]::new()
$global:pageCount = 0
function global:git { $global:LASTEXITCODE=0; 'git version 2.53.0' }
function global:terraform { $global:LASTEXITCODE=0; '{"terraform_version":"1.16.6"}' }
function global:dotnet { $global:LASTEXITCODE=0; '10.0.402 [synthetic]' }
function global:node { $global:LASTEXITCODE=0; 'v22.22.0' }
function global:func { $global:LASTEXITCODE=0; '4.14.0' }
function global:az {
    $global:LASTEXITCODE = 0
    $global:calls.Add(($args -join ' '))
    $result = switch ("$($args[0]) $($args[1])") {
        'version --output' { @{ 'azure-cli'='2.88.0' }; break }
        'cloud show' { @{ name='AzureCloud' }; break }
        'account show' { @{ id=$(if ($global:scenario -eq 'wrong-context') { [guid]::NewGuid().ToString() } else { $global:subscription.ToString() });
            tenantId=$global:tenant.ToString(); state='Enabled'; environmentName='AzureCloud'; userType='user' }; break }
        'account list-locations' { @(@{name='westeurope'}); break }
        'group show' { @{id="/subscriptions/$global:subscription/resourceGroups/rg-synthetic-admin"}; break }
        'group list' { if ($global:scenario -eq 'group-quota') { 980 } else { 3 }; break }
        'provider list' { @('Microsoft.Resources','Microsoft.Web','Microsoft.App','Microsoft.Storage','Microsoft.ManagedIdentity',
            'Microsoft.Network','Microsoft.Insights','Microsoft.OperationalInsights','Microsoft.ApiManagement','Microsoft.ApiCenter') |
            ForEach-Object { @{ namespace=$_; registrationState=$(if ($global:scenario -eq 'missing-provider' -and $_ -eq 'Microsoft.Web') { 'NotRegistered' } else { 'Registered' }) } }; break }
        'appservice list-locations' { @(@{name='West Europe'}); break }
        'functionapp list-flexconsumption-locations' { @(@{name=$(if ($global:scenario -eq 'wrong-region') { 'eastus' } else { 'westeurope' })}); break }
        'functionapp list-flexconsumption-runtimes' { @(@{name='dotnet-isolated';version=$(if ($global:scenario -eq 'wrong-runtime') { '8.0' } else { '10.0' })}); break }
        'rest --method' {
            if ($args[2] -ne 'get') { throw 'Write attempt refused by synthetic CLI.' }
            $global:pageCount++
            $permission = @{actions=@('*');notActions=@()}
            if ($global:scenario -eq 'permission-denied') { $permission.notActions=@('Microsoft.Resources/subscriptions/resourceGroups/write') }
            $response = @{value=@($permission)}
            if ($global:scenario -eq 'pagination' -and $global:pageCount -eq 1) {
                $response.value=@(@{actions=@('*/read');notActions=@()})
                $response.nextLink="https://management.azure.com/subscriptions/$global:subscription/providers/Microsoft.Authorization/permissions?api-version=2022-04-01&skiptoken=synthetic"
            }
            if ($global:scenario -eq 'unsafe-pagination') { $response.nextLink='https://example.invalid/never-call' }
            $response
            break
        }
        default { throw "Unexpected Azure command; synthetic CLI allows only read/check commands." }
    }
    if ($global:scenario -eq 'cli-error' -and $args[0] -eq 'provider') { $global:LASTEXITCODE=1; 'synthetic private error must not be printed'; return }
    if ($global:scenario -eq 'invalid-json' -and $args[0] -eq 'provider') { 'not-json'; return }
    ConvertTo-Json -InputObject $result -Depth 20 -Compress
}
$directory = '${directory.replaceAll("'", "''")}'
$path = Join-Path $directory 'parameters.json'
$reviewPath = Join-Path $directory 'capacity.json'
foreach ($global:scenario in @('valid', 'pagination', 'wrong-context', 'override', 'permission-denied', 'group-quota',
    'missing-provider', 'cli-error', 'invalid-json', 'unsafe-pagination', 'portal-valid', 'mcp-valid', 'wrong-runtime',
    'wrong-region', 'missing-review', 'stale-review', 'future-review', 'wrong-review-target', 'insufficient-review', 'unsafe-parameters')) {
    $global:pageCount=0
    $global:calls.Clear()
    $stage = if ($global:scenario -in @('portal-valid','missing-provider','missing-review','stale-review','future-review','wrong-review-target','insufficient-review')) { 'portal' }
        elseif ($global:scenario -in @('mcp-valid','wrong-runtime','wrong-region')) { 'mcp' } else { 'foundation' }
    $parameters = @{participant_prefix='p01';resource_suffix='0123456789';location='westeurope';owner='alice';
        expiry=[datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd');existing_resource_group_name=$(if ($stage -ne 'foundation') { 'rg-synthetic-admin' } else { $null })}
    if ($global:scenario -eq 'unsafe-parameters') { $parameters.resource_suffix='../../outside' }
    $parameters | ConvertTo-Json | Set-Content -LiteralPath $path
    $before = Get-Content -LiteralPath $path -Raw
    $checked = [datetime]::UtcNow.AddMinutes(-1)
    if ($global:scenario -eq 'stale-review') { $checked=$checked.AddDays(-2) }
    if ($global:scenario -eq 'future-review') { $checked=$checked.AddDays(1) }
    @{subscriptionId=$(if ($global:scenario -eq 'wrong-review-target') { [guid]::NewGuid().ToString() } else { $global:subscription.ToString() });
        location='westeurope';stage=$stage;unit=$(if ($stage -eq 'portal') { 'workers' } else { 'MB' });
        availableUnits=$(if ($global:scenario -eq 'insufficient-review') { 0 } else { 512000 });
        checkedAtUtc=$checked.ToString('yyyy-MM-ddTHH:mm:ssZ');costApproved=$true } | ConvertTo-Json | Set-Content -LiteralPath $reviewPath
    $arguments = @{TenantId=$global:tenant;SubscriptionId=$global:subscription;ParametersPath=$path;Stage=$stage}
    if ($stage -ne 'foundation' -and $global:scenario -ne 'missing-review') { $arguments.CapacityReviewPath=$reviewPath }
    if ($global:scenario -eq 'override') { $env:ARM_CLIENT_ID='synthetic-override' }
    $failed=$false
    try { $output = & '${script}' @arguments | Out-String }
    catch { $failed=$true; $output=$_.Exception.Message + ' ' + $_.ScriptStackTrace }
    finally { Remove-Item Env:ARM_CLIENT_ID -ErrorAction SilentlyContinue }
    $expected = $global:scenario -in @('valid','pagination','portal-valid','mcp-valid')
    if ($failed -eq $expected) { throw "Unexpected result for $global:scenario : $output" }
    if ($output -match 'synthetic private error must not be printed') { throw 'Private CLI error leaked.' }
    if ((Get-Content -LiteralPath $path -Raw) -cne $before) { throw 'Preflight changed participant parameters.' }
    if ($env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL) { throw 'Extension policy was not restored.' }
    if ($global:calls | Where-Object { $_ -match '(^| )(login|set|register|create|delete|update|deploy|apply)( |$)' }) { throw 'Preflight attempted a state-changing command.' }
    if ($global:scenario -eq 'pagination' -and $global:pageCount -ne 2) { throw 'Permission pagination was not followed.' }
    if ($global:scenario -eq 'unsafe-pagination' -and $global:pageCount -ne 1) { throw 'Unsafe pagination was followed.' }
    Write-Output "PASS synthetic $global:scenario (expected HTTP N/A; no Azure access)"
}
`], { encoding: "utf8", timeout: 60000 });
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic /g) ?? []).length, 20);
});

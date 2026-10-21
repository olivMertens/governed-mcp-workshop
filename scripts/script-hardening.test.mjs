import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync, cpSync, readFileSync, rmSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("../", import.meta.url));
const quote = (value) => value.replaceAll("'", "''");
function run(source) {
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", `$ErrorActionPreference='Stop'\n${source}`],
        { encoding: "utf8", timeout: 120000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    return result.stdout;
}
function fixture(t) {
    const directory = mkdtempSync(join(tmpdir(), "workshop-hardening-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    return directory;
}

test("expired parameters are accepted only for cleanup and malformed dates remain forbidden", (t) => {
    const directory = fixture(t);
    const path = join(directory, "parameters.json");
    const original = { participant_prefix: "p01", resource_suffix: "0123456789abcdef", owner: "alice",
        location: "westeurope", existing_resource_group_name: null, expiry: "2000-01-01" };
    writeFileSync(path, JSON.stringify(original));
    run(`
. '${quote(join(root, "scripts", "context-common.ps1"))}'
$path='${quote(path)}'
$failed=$false
try { Read-WorkshopParameters -Path $path | Out-Null } catch { $failed=$true }
if (-not $failed) { throw 'Deployment accepted expired parameters.' }
$p=Read-WorkshopParameters -Path $path -AllowExpired
if ($p.resource_suffix -cne '0123456789abcdef') { throw 'Cleanup changed the suffix.' }
$p.expiry='2099-02-30'; $p | ConvertTo-Json | Set-Content -LiteralPath $path
$failed=$false
try { Read-WorkshopParameters -Path $path -AllowExpired | Out-Null } catch { $failed=$true }
if (-not $failed) { throw 'Cleanup accepted an impossible date.' }
`);
    for (const module of ["02-open-server", "03-entra-authentication", "04-governed-gateway", "05-delegated-and-app-only"]) {
        assert.match(readFileSync(join(root, "modules", module, "cleanup.ps1"), "utf8"), /Read-WorkshopParameters -Path \$ParametersPath -AllowExpired/);
    }
    for (const script of ["preflight.ps1", "deploy-portal.ps1"]) {
        assert.doesNotMatch(readFileSync(join(root, "scripts", script), "utf8"), /Read-WorkshopParameters[^\r\n]*-AllowExpired/);
    }
});

test("portal cleanup refuses other tiers, reverse Always On changes and unknown planned values", () => {
    run(`
. '${quote(join(root, "scripts", "context-common.ps1"))}'
function C($before,$after,$unknown=@{}) {
    @{address='azurerm_service_plan.portal[0]';change=@{actions=@('update');before=@{sku_name=$before};after=@{sku_name=$after};after_unknown=$unknown}}
}
if (-not (Test-WorkshopPortalTierRestore (C 'F1' 'B1'))) { throw 'Exact restore refused.' }
foreach ($pair in @(@('B1','P3v3'),@('F1','P3v3'),@('B1','F1'),@('B1','B1'))) {
    if (Test-WorkshopPortalTierRestore (C $pair[0] $pair[1])) { throw 'Unreviewed tier accepted.' }
}
if (Test-WorkshopPortalTierRestore (C 'F1' 'B1' @{sku_name=$true})) { throw 'Unknown value accepted.' }
$app=@{address='azurerm_linux_web_app.portal[0]';change=@{actions=@('update');before=@{site_config=@(@{always_on=$true})};after=@{site_config=@(@{always_on=$false})}}}
if (Test-WorkshopPortalTierRestore $app) { throw 'Reverse Always On accepted.' }
if (Test-WorkshopPortalTierRestore @{address='malformed'}) { throw 'Malformed change accepted.' }
`);
});

test("policy renderer enforces every boundary before writing files and renders /8, /24 and /32 exactly", (t) => {
    const directory = fixture(t);
    const module = join(directory, "modules", "04-governed-gateway");
    mkdirSync(module, { recursive: true });
    copyFileSync(join(root, "modules", "04-governed-gateway", "render-policies.ps1"), join(module, "render-policies.ps1"));
    cpSync(join(root, "modules", "04-governed-gateway", "policies"), join(module, "policies"), { recursive: true });
    run(`
$script='${quote(join(module, "render-policies.ps1"))}'
$base=@{TenantId=[guid]'00000000-0000-4000-8000-000000000000';ApiClientId=[guid]'44444444-4444-4444-8444-444444444444';GatewayName='synthetic-gateway'}
$cases=@(
    @{RateLimitPeriod=9},@{RateLimitPeriod=301},@{RateLimitPeriod=3600},@{RateLimitCalls=4},@{RateLimitCalls=1001},
    @{RateLimitPeriod=10.5},@{RateLimitCalls=5.5},
    @{AllowedIpRanges=@('0.0.0.0/0')},@{AllowedIpRanges=@('203.0.113.0/7')},@{AllowedIpRanges=@('203.0.113.0/33')},
    @{AllowedIpRanges=@('999.0.0.1/24')},@{AllowedIpRanges=@('2001:db8::/32')},@{AllowedIpRanges=@('203.000.113.1/32')},
    @{AllowedIpRanges=@('203.0.113.1')},@{AllowedIpRanges=@('203.0.113.0/24')*11},
    @{AllowedClientIds=@()},@{AllowedClientIds=@([guid]::Empty)},@{TenantId=[guid]::Empty},@{ApiClientId=[guid]::Empty},
    @{McpPath='ab'},@{McpPath=('a'*41)},@{GatewayName='-bad'},@{GatewayName='bad-'}
)
foreach ($change in $cases) {
    $params=$base.Clone(); foreach($key in $change.Keys){$params[$key]=$change[$key]}
    $failed=$false
    try { & $script @params | Out-Null } catch { $failed=$true }
    if (-not $failed) { throw "Invalid renderer input accepted: $($change.Keys)" }
    if (Test-Path '${quote(join(directory, ".workshop"))}') { throw 'Invalid input created output.' }
}
foreach($period in @(10,300)){
    foreach($calls in @(5,1000)){
        & $script @base -RateLimitCalls $calls -RateLimitPeriod $period -AllowedIpRanges @('10.0.0.1/8','203.0.113.10/24','255.255.255.255/32') | Out-Null
    }
}
`);
    const policy = readFileSync(join(directory, ".workshop", "policy-mcp-server.xml"), "utf8");
    for (const expected of ['from="10.0.0.0" to="10.255.255.255"', 'from="203.0.113.0" to="203.0.113.255"',
        'from="255.255.255.255" to="255.255.255.255"', 'renewal-period="300"', 'calls="1000"']) assert.ok(policy.includes(expected), expected);
    assert.doesNotMatch(policy, /\$\{|%\{/);
});

test("launcher recommendations and module 07 automatic validation respect the real contracts", (t) => {
    const directory = fixture(t);
    mkdirSync(join(directory, "scripts"), { recursive: true });
    copyFileSync(join(root, "scripts", "deploy-module.ps1"), join(directory, "scripts", "deploy-module.ps1"));
    copyFileSync(join(root, "scripts", "context-common.ps1"), join(directory, "scripts", "context-common.ps1"));
    for (const name of ["00-prerequisites", "06-observe-inventory", "07-clients"]) mkdirSync(join(directory, "modules", name), { recursive: true });
    mkdirSync(join(directory, ".workshop"));
    for (const name of ["participant", "module02", "module03", "module05", "module07"]) writeFileSync(join(directory, ".workshop", `${name}.tfvars.json`), "{}");
    writeFileSync(join(directory, ".workshop", "participant.tfvars.json"), JSON.stringify({
        participant_prefix: "p01", resource_suffix: "0123456789abcdef", owner: "alice", location: "westeurope",
        existing_resource_group_name: null, expiry: new Date(Date.now() + 86400000).toISOString().slice(0, 10),
    }));
    writeFileSync(join(directory, "modules", "07-clients", "validate.ps1"), "[CmdletBinding()]param([switch]$Offline)\nif(-not $Offline){throw 'Offline required.'}\n'PASS synthetic offline validator'\n");
    const output = run(`
$script='${quote(join(directory, "scripts", "deploy-module.ps1"))}'
$six=(& $script -Module 06) -join [char]10
if ($six -notmatch 'validate.ps1 -Offline' -or $six -match '\\-TenantId') { throw 'Wrong module 06 contract.' }
$zero=(& $script -Module 00) -join [char]10
if ($zero -notmatch '\\-TenantId.*\\-SubscriptionId') { throw 'Wrong module 00 contract.' }
$env:ARM_TENANT_ID='00000000-0000-4000-8000-000000000000'
$env:ARM_SUBSCRIPTION_ID='11111111-1111-4111-8111-111111111111'
function global:az {
    $global:LASTEXITCODE=0
    if($args[0] -eq 'cloud'){return '{"name":"AzureCloud"}'}
    if($args[0] -eq 'account'){return (@{id=$env:ARM_SUBSCRIPTION_ID;tenantId=$env:ARM_TENANT_ID;state='Enabled';environmentName='AzureCloud';userType='user'} | ConvertTo-Json)}
    throw 'Unexpected Azure call.'
}
function global:terraform { $global:LASTEXITCODE=0; if($args[0] -notlike '-chdir=*${process.platform === "win32" ? "infra\\workload" : "infra/workload"}'){throw 'Root was not resolved from the script.'} }
function global:Read-Host { 'yes' }
& $script -Module 07
$parameters=Get-Content '${quote(join(directory, ".workshop", "participant.tfvars.json"))}' -Raw | ConvertFrom-Json
$parameters.expiry='2000-01-01'
$parameters | ConvertTo-Json | Set-Content '${quote(join(directory, ".workshop", "participant.tfvars.json"))}'
function global:terraform { throw 'Expired parameters must be rejected before Terraform.' }
$failed=$false
try { & $script -Module 07 | Out-Null } catch { if($_.Exception.Message -notmatch 'future date'){throw};$failed=$true }
if(-not $failed){throw 'Module launcher accepted expired deployment parameters.'}
`);
    assert.match(output, /PASS synthetic offline validator/);
    assert.match(output, /validation is offline only/);
});

test("module 07 cleanup fails closed and retains inventory on read, purge and delete failures", (t) => {
    const directory = fixture(t);
    const module = join(directory, "modules", "07-clients");
    mkdirSync(module, { recursive: true });
    mkdirSync(join(directory, "scripts"));
    mkdirSync(join(directory, ".workshop"));
    copyFileSync(join(root, "scripts", "context-common.ps1"), join(directory, "scripts", "context-common.ps1"));
    copyFileSync(join(root, "modules", "07-clients", "cleanup.ps1"), join(module, "cleanup.ps1"));
    writeFileSync(join(directory, "scripts", "context-common.ps1"),
        readFileSync(join(directory, "scripts", "context-common.ps1"), "utf8") +
        "\nfunction Get-WorkshopAccessToken { param($TenantId,$Resource) @{Ok=$true;Value='synthetic-not-a-token'} }\n");
    run(`
$script='${quote(join(module, "cleanup.ps1"))}'
$private='${quote(join(directory, ".workshop"))}'
$global:tenant=[guid]'00000000-0000-4000-8000-000000000000'
$global:subscription=[guid]'11111111-1111-4111-8111-111111111111'
$global:client='44444444-4444-4444-8444-444444444444'
$global:deletedId="/subscriptions/$global:subscription/resourceGroups/rg-synthetic/providers/Microsoft.CognitiveServices/accounts/synthetic-account"
function global:az {
    $global:LASTEXITCODE=0
    $key="$($args[0]) $($args[1])"
    if($key -eq 'cloud show'){return '{"name":"AzureCloud"}'}
    if($key -eq 'account show'){return (@{id="$global:subscription";tenantId="$global:tenant";state='Enabled';environmentName='AzureCloud';userType='user'} | ConvertTo-Json)}
    if($key -eq 'group exists'){
        if($global:scenario -eq 'group-read-error'){$global:LASTEXITCODE=1; return}
        if($global:scenario -eq 'group-invalid'){return 'null'}
        if($global:scenario -in @('untagged','group-delete-error','purge-error-live','apply-live')){return 'true'}
        return 'false'
    }
    if($key -eq 'group show'){
        if($global:scenario -eq 'untagged'){return '{"workshop":"other","module":"07"}'}
        return '{"workshop":"governed-mcp","module":"07"}'
    }
    if($key -eq 'group delete'){
        $saved=Get-Content (Join-Path $private 'module07.private.json') -Raw | ConvertFrom-Json
        if($saved.foundry_cleanup_accounts[0].name -ne 'synthetic-account'){throw 'Account inventory was not persisted before group deletion.'}
        if($global:scenario -eq 'group-delete-error'){$global:LASTEXITCODE=1}
        return
    }
    if($key -eq 'resource list'){return '[]'}
    if($key -eq 'cognitiveservices account'){
        if($args[2] -eq 'list'){return '[{"name":"synthetic-account","location":"westeurope"}]'}
        if($args[2] -eq 'list-deleted'){
            if($global:scenario -eq 'inventory-read-error'){$global:LASTEXITCODE=1;return}
            if($global:purges -gt 0 -and $global:scenario -in @('purge-success','apply-live')){return '[]'}
            if($global:scenario -in @('purge-error','purge-success','report','unknown-account','purge-error-live','apply-live','purge-unconfirmed')){
                return (ConvertTo-Json -InputObject @(@{id=$global:deletedId;name='synthetic-account';location='westeurope'}) -Compress)
            }
            if($global:scenario -eq 'foreign-account'){
                return (ConvertTo-Json -InputObject @(@{id=($global:deletedId -replace '/rg-synthetic/','/rg-foreign/');name='synthetic-account';location='westeurope'}) -Compress)
            }
            return '[]'
        }
        if($args[2] -eq 'purge'){
            $global:purges++
            if($global:scenario -in @('purge-error','purge-error-live')){$global:LASTEXITCODE=1}
            return
        }
    }
    if($key -eq 'ad app'){
        if($args[2] -eq 'list'){
            if($args[4] -cne "appId eq '$global:client'"){throw 'The app lookup did not use the canonical client ID.'}
            if($global:scenario -eq 'app-read-error'){$global:LASTEXITCODE=1;return}
            if($global:scenario -eq 'app-wrong-name'){return '["unrelated-app"]'}
            if($global:scenario -eq 'app-delete-error'){return '["workshop-mcp-foundry-client-synthetic"]'}
            return '[]'
        }
        if($args[2] -eq 'delete' -and $global:scenario -eq 'app-delete-error'){$global:LASTEXITCODE=1;return}
    }
    throw "Unexpected Azure command: $key"
}
function global:terraform { throw 'Low-code cleanup must not call Terraform.' }
foreach($global:scenario in @('group-read-error','group-invalid','untagged','inventory-read-error','app-read-error',
    'app-wrong-name','app-delete-error','group-delete-error','purge-error-live','apply-live','purge-error','purge-success',
    'purge-unconfirmed','unknown-account','foreign-account','invalid-client','empty-client','canonical-client','empty','report')){
    $state=@{foundry_client_app_id=$global:client;foundry_resource_group='rg-synthetic'}
    if($global:scenario -eq 'invalid-client'){$state.foundry_client_app_id='not-a-guid'}
    if($global:scenario -eq 'empty-client'){$state.foundry_client_app_id=''}
    if($global:scenario -eq 'canonical-client'){$state.foundry_client_app_id="  $global:client  "}
    if($global:scenario -ne 'unknown-account'){$state.foundry_cleanup_accounts=@(@{name='synthetic-account';location='westeurope'})}
    $state | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $private 'module07.private.json')
    '{}' | Set-Content (Join-Path $private 'module07.tfvars.json')
    '{}' | Set-Content (Join-Path $private 'entra-module07.tfvars.json')
    $global:purges=0;$failed=$false;$text=''
    try{$text=(& $script -TenantId $global:tenant -SubscriptionId $global:subscription -LowCodeTrack -Apply:($global:scenario -ne 'report')) -join [char]10}
    catch{$failed=$true;$text=$_.Exception.Message}
    $expectedFailure=$global:scenario -notin @('purge-success','apply-live','foreign-account','canonical-client','empty','report')
    if($failed -ne $expectedFailure){throw "Wrong result for $global:scenario : $text"}
    $reasons=@{'group-read-error'='read/check failed';'group-invalid'='returned no data';'untagged'='not tagged';
        'inventory-read-error'='read/check failed';'app-read-error'='read/check failed';'app-wrong-name'='name does not start';
        'app-delete-error'='app registration deletion';'group-delete-error'='resource group deletion';
        'purge-error-live'='account purge';'purge-error'='account purge';'purge-unconfirmed'='not yet confirmed';
        'unknown-account'='ownership inventory';'invalid-client'='client app ID is invalid';'empty-client'='client app ID is invalid'}
    if($expectedFailure -and $text -notmatch $reasons[$global:scenario]){throw "Wrong failure reason for $global:scenario : $text"}
    $exists=Test-Path (Join-Path $private 'module07.private.json')
    if($exists -ne ($expectedFailure -or $global:scenario -eq 'report')){throw "Wrong inventory preservation for $global:scenario"}
    $expectedPurges=if($global:scenario -in @('purge-error','purge-success','purge-error-live','apply-live','purge-unconfirmed')){1}else{0}
    if($global:purges -ne $expectedPurges){throw "Wrong purge count for $global:scenario : $text"}
}
`);
    assert.equal(existsSync(join(directory, ".workshop", "module07.private.json")), true, "report mode must retain inventory");
});

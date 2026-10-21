import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("../", import.meta.url));
const module02 = join(root, "modules", "02-open-server");

function pwsh(script) {
    return spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", script], { encoding: "utf8", timeout: 120000 });
}

test("module 02 keeps the key-only invariants in source: System webhook level, no secrets, no key outputs", () => {
    const host = JSON.parse(readFileSync(join(root, "src", "FunctionsMcpServer", "host.json"), "utf8"));
    assert.equal(host.extensions.mcp.system.webhookAuthorizationLevel, "System");
    const terraform = readFileSync(join(root, "infra", "workload", "mcp-server.tf"), "utf8");
    assert.match(terraform, /shared_access_key_enabled\s*=\s*false/);
    assert.doesNotMatch(terraform, /storage_access_key\s*=|listkeys|host_keys/i);
    for (const file of ["README.md", "README.fr.md"]) {
        const guide = readFileSync(join(module02, file), "utf8");
        const headings = [...guide.matchAll(/^## (.+)$/gm)].map((match) => match[1]);
        assert.equal(headings.length, 11, `${file} must keep the eleven contract sections`);
        assert.match(guide, /x-functions-key/);
        assert.doesNotMatch(guide, /"x-functions-key"\s*:\s*"[A-Za-z0-9]/);
        assert.match(guide, /Last verified|Dernière vérification/);
    }
});

test("module 02 live validator expects 401 without key, 200 with key, and never prints the key (synthetic Azure and HTTP)", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-open-server-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const secretKey = "SyntheticKeyValue-DoNotPrint-0123456789";
    const result = pwsh(`
$ErrorActionPreference='Stop'
$tenant=[guid]::NewGuid(); $global:subscription=[guid]::NewGuid(); $global:tenant=$tenant
function global:terraform { $global:LASTEXITCODE=0; if ($args -contains 'output') { '{"mcp_function_app_name":{"value":"func-mcp-p01-0123456789"},"resource_group_name":{"value":"rg-mcp-p01-0123456789"}}' } }
function global:az {
    $global:LASTEXITCODE=0
    if ($args[0] -eq 'cloud') { return '{"name":"AzureCloud"}' }
    if ($args[0] -eq 'account') { return (@{id="$global:subscription";tenantId="$global:tenant";state='Enabled';environmentName='AzureCloud';userType='user'} | ConvertTo-Json) }
    if ($args[0] -eq 'functionapp' -and $args[1] -eq 'show') { return '{"host":"func-mcp-p01-0123456789.azurewebsites.net","httpsOnly":true,"state":"Running"}' }
    if ($args[0] -eq 'functionapp' -and $args[1] -eq 'keys') { return '${secretKey}' }
    throw 'Unexpected Azure command.'
}
function global:Invoke-WebRequest {
    param($Uri, $Method, $Body, $ContentType, $Headers, [switch]$SkipHttpErrorCheck, $MaximumRedirection, $TimeoutSec)
    $request = $Body | ConvertFrom-Json
    $authorized = $Headers['x-functions-key'] -eq '${secretKey}'
    if ($global:scenario -eq 'anonymous') { $authorized = $true }
    if (-not $authorized) { return [pscustomobject]@{StatusCode=401;Content='';Headers=@{}} }
    $content = switch ($request.method) {
        'initialize' { '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"workshop-open-mcp","version":"0.2.0"}}}' }
        'notifications/initialized' { '' }
        'tools/list' {
            $names = if ($global:scenario -eq 'extra-tool') { @('create_ticket','get_service_health','read_report_as_app','read_report_as_user','whoami','delete_all') } else { @('create_ticket','get_service_health','read_report_as_app','read_report_as_user','whoami') }
            'event: message' + [char]10 + 'data: ' + (@{jsonrpc='2.0';id=2;result=@{tools=@($names | ForEach-Object { @{name=$_} })}} | ConvertTo-Json -Depth 5 -Compress) + [char]10
        }
        'tools/call' { '{"jsonrpc":"2.0","id":3,"result":{"isError":false,"content":[{"type":"text","text":"{}"}]}}' }
    }
    $type = if ($request.method -eq 'tools/list') { 'text/event-stream' } else { 'application/json' }
    $status = if ($request.method -eq 'notifications/initialized') { 202 } else { 200 }
    [pscustomobject]@{StatusCode=$status;Content=$content;Headers=@{'Content-Type'=@($type);'Mcp-Session-Id'=@('synthetic-session')}}
}
$validator='${join(module02, "validate.ps1").replaceAll("'", "''")}'
foreach ($global:scenario in @('valid','anonymous','extra-tool')) {
    $failed=$false; $output=@()
    try { $output = & $validator -TenantId $tenant -SubscriptionId $global:subscription -SkipBuild -DemonstrateWrite 6>&1 | ForEach-Object { "$_" } }
    catch { $failed=$true; $output += $_.Exception.Message }
    $text = $output -join [char]10
    if ($text -match 'SyntheticKeyValue') { throw 'The validator printed the key.' }
    if ($global:scenario -eq 'valid') {
        if ($failed) { throw "Valid scenario failed: $text" }
        foreach ($line in @('expected HTTP 401 without the mcp_extension key','(expected HTTP 401).','random wrong key is refused (expected HTTP 401)','negotiated protocol 2025-06-18 (expected HTTP 200)','exactly the five workshop tools (expected HTTP 200)','RISK SHOWN')) {
            if (-not $text.Contains($line)) { throw "Missing line: $line" }
        }
    } elseif (-not $failed -or $text -notmatch 'FAIL') { throw "Scenario $global:scenario must fail closed." }
    Write-Output "PASS synthetic validator $global:scenario"
}
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic validator /g) ?? []).length, 3);
    assert.doesNotMatch(result.stdout + result.stderr, /SyntheticKeyValue/);
});

test("module 02 validator offline mode passes without Azure and states it is not deployment evidence", () => {
    const result = pwsh(`& '${join(module02, "validate.ps1").replaceAll("'", "''")}' -Offline -SkipBuild`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, /PASS host\.json MCP webhook authorization level is System \(expected HTTP 401/);
    assert.match(result.stdout, /PASS no key, SAS, connection-string or client-secret pattern/);
    assert.match(result.stdout, /Module 02 is NOT deployed or Azure-validated/);
});

test("module 02 cleanup deletes only module 02 resources, refuses all legacy portal changes and is idempotent (synthetic Terraform)", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-open-cleanup-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const parameters = join(directory, "participant.tfvars.json");
    const expiry = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
    writeFileSync(parameters, JSON.stringify({ participant_prefix: "p01", resource_suffix: "0123456789abcdef", location: "swedencentral",
        owner: "alice", expiry, existing_resource_group_name: null }));
    const result = pwsh(`
$ErrorActionPreference='Stop'
$tenant=[guid]::NewGuid(); $global:subscription=[guid]::NewGuid(); $global:tenant=$tenant
function global:az {
    $global:LASTEXITCODE=0
    if ($args[0] -eq 'cloud') { return '{"name":"AzureCloud"}' }
    if ($args[0] -eq 'account') { return (@{id="$global:subscription";tenantId="$global:tenant";state='Enabled';environmentName='AzureCloud';userType='user'} | ConvertTo-Json) }
    throw 'Unexpected Azure command.'
}
function global:terraform {
    $global:LASTEXITCODE=0
    if ($args -contains 'apply') { $global:applied++; return }
    if ($args -contains 'plan' -and -not ($args -contains '-var=enable_mcp_server=false')) { throw 'Cleanup must plan with the module disabled.' }
    if ($args -contains 'show') {
        $changes = switch ($global:scenario) {
            'empty' { @(@{address='azurerm_resource_group.workshop[0]';change=@{actions=@('no-op')}}) }
            'foreign' { @(@{address='azurerm_storage_account.mcp[0]';change=@{actions=@('delete')}}, @{address='azurerm_resource_group.workshop[0]';change=@{actions=@('delete')}}) }
            'update' { @(@{address='azurerm_function_app_flex_consumption.mcp[0]';change=@{actions=@('update')}}) }
            'hint' { @(@{address='azurerm_private_endpoint.storage["blob"]';change=@{actions=@('delete')}},
                @{address='azurerm_linux_web_app.portal[0]';change=@{actions=@('update');before=@{https_only=$true;app_settings=@{A='1';WORKSHOP_MCP_ENDPOINT='https://func.example.invalid/runtime/webhooks/mcp'}};after=@{https_only=$true;app_settings=@{A='1'}}}}) }
            'portal' { @(@{address='azurerm_linux_web_app.portal[0]';change=@{actions=@('update');before=@{https_only=$true;app_settings=@{A='1';WORKSHOP_MCP_ENDPOINT='https://func.example.invalid/runtime/webhooks/mcp'}};after=@{https_only=$false;app_settings=@{A='1'}}}}) }
            default { @(@{address='azurerm_storage_account.mcp[0]';change=@{actions=@('delete')}}, @{address='azurerm_role_assignment.mcp_ticket_sender[0]';change=@{actions=@('delete')}}) }
        }
        return (@{resource_changes=$changes} | ConvertTo-Json -Depth 10)
    }
}
$cleanup='${join(module02, "cleanup.ps1").replaceAll("'", "''")}'
foreach ($global:scenario in @('report','apply','empty','foreign','update','hint','portal')) {
    $global:applied=0; $failed=$false; $text=''
    try { $text = (& $cleanup -TenantId $tenant -SubscriptionId $global:subscription -ParametersPath '${parameters.replaceAll("'", "''")}' -Apply:($global:scenario -eq 'apply')) -join [char]10 }
    catch { $failed=$true; $text=$_.Exception.Message }
    switch ($global:scenario) {
        'report' { if ($failed -or $global:applied -ne 0 -or $text -notmatch 'rerun with -Apply') { throw "report: $text" } }
        'apply' { if ($failed -or $global:applied -ne 1) { throw "apply: $text" } }
        'empty' { if ($failed -or $global:applied -ne 0 -or $text -notmatch 'nothing to delete') { throw "empty: $text" } }
        default { if (-not $failed -or $global:applied -ne 0) { throw "$global:scenario must refuse." } }
    }
    Write-Output "PASS synthetic cleanup $global:scenario"
}
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic cleanup /g) ?? []).length, 7);
});

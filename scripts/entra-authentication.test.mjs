import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, readFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("../", import.meta.url));
const module03 = join(root, "modules", "03-entra-authentication");
const quote = (path) => path.replaceAll("'", "''");

function pwsh(script) {
    return spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", script], { encoding: "utf8", timeout: 180000 });
}

test("module 03 guides keep the contract, teach aud/scp/roles with synthetic claims and contain no token", () => {
    for (const file of ["README.md", "README.fr.md"]) {
        const guide = readFileSync(join(module03, file), "utf8");
        const headings = [...guide.matchAll(/^## (.+)$/gm)].map((match) => match[1]);
        assert.equal(headings.length, 11, `${file} must keep the eleven contract sections`);
        for (const term of ["`aud`", "`scp`", "`roles`", "AADSTS50105", "Preview", "WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES",
            "aebc6443-996d-45c2-90f0-388ff96faa56", "04b07795-8ddb-461a-bbee-02f9e1bf7b46", "synthetic-claims/"]) {
            assert.ok(guide.includes(term), `${file} must mention ${term}`);
        }
        assert.doesNotMatch(guide, /eyJ[A-Za-z0-9_-]{8,}\.eyJ/);
        assert.doesNotMatch(guide, /client_secret|ClientSecret/);
        assert.match(guide, /Last verified|Dernière vérification/);
    }
    const claims = readdirSync(join(module03, "synthetic-claims")).filter((name) => name.endsWith(".json"));
    assert.deepEqual(claims.sort(), ["alice.json", "bob.json", "eve.json", "wrong-audience.json"]);
    const alice = JSON.parse(readFileSync(join(module03, "synthetic-claims", "alice.json"), "utf8"));
    const bob = JSON.parse(readFileSync(join(module03, "synthetic-claims", "bob.json"), "utf8"));
    const eve = JSON.parse(readFileSync(join(module03, "synthetic-claims", "eve.json"), "utf8"));
    assert.deepEqual(alice.decoded_payload.roles, ["Tools.Read", "Tools.Write"]);
    assert.deepEqual(bob.decoded_payload.roles, ["Tools.Read"]);
    assert.equal(alice.decoded_payload.scp, "user_impersonation");
    assert.equal(alice.decoded_payload.aud, bob.decoded_payload.aud);
    assert.equal(eve.decoded_payload, undefined);
    assert.deepEqual(eve.token_endpoint_error.error_codes, [50105]);
});

test("module 03 Terraform never creates secrets or users and ties the anonymous webhook to enforced authentication", () => {
    const entra = ["main.tf", "variables.tf", "outputs.tf", "providers.tf", "versions.tf"]
        .map((file) => readFileSync(join(root, "infra", "entra", file), "utf8")).join("\n");
    assert.doesNotMatch(entra, /azuread_application_password|azuread_service_principal_password|"azuread_user"|client_secret/);
    assert.match(entra, /app_role_assignment_required\s*=\s*true/);
    assert.match(entra, /version\s*=\s*"= 3\.10\.0"/);
    assert.match(readFileSync(join(root, "infra", "entra", ".terraform.lock.hcl"), "utf8"), /hashicorp\/azuread[\s\S]*version\s*=\s*"3\.10\.0"/);
    const auth = readFileSync(join(root, "infra", "workload", "entra-auth.tf"), "utf8");
    assert.match(auth, /mcp_key_gate_replaced\s*=\s*local\.mcp_auth_enabled\s*&&\s*var\.entra_auth_replace_key_gate/);
    const host = JSON.parse(readFileSync(join(root, "src", "FunctionsMcpServer", "host.json"), "utf8"));
    assert.equal(host.extensions.mcp.system.webhookAuthorizationLevel, "System");
});

test("module 03 validator offline mode passes without Azure and states it is not deployment evidence", () => {
    const result = pwsh(`& '${quote(join(module03, "validate.ps1"))}' -Offline -SkipBuild`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, /PASS the key gate is removed only together with enforced built-in authentication/);
    assert.match(result.stdout, /PASS infra\/entra: single tenant/);
    assert.match(result.stdout, /Module 03 is NOT deployed or Entra-validated/);
});

test("module 03 live validator: 401 without token or with Graph token, 200 for Alice/Bob, Eve refused, tokens never printed (synthetic)", () => {
    const missing = join(tmpdir(), "workshop-no-personas-file.json");
    const result = pwsh(`
$ErrorActionPreference='Stop'
$tenant=[guid]'00000000-0000-4000-8000-000000000000'; $global:subscription=[guid]::NewGuid(); $global:tenant=$tenant
$global:mcpToken='SyntheticMcpToken-DoNotPrint.payload.signature'
$global:graphToken='SyntheticGraphToken-DoNotPrint.payload.signature'
$global:fqdn='func-mcp-p01-0123456789.azurewebsites.net'
function global:terraform {
    $global:LASTEXITCODE=0
    if ($args -contains 'output') {
        return (@{
            mcp_function_app_name=@{value='func-mcp-p01-0123456789'}; resource_group_name=@{value='rg-mcp-p01-0123456789'}
            mcp_endpoint=@{value="https://$global:fqdn/runtime/webhooks/mcp"}; mcp_auth_enabled=@{value=$true}
            mcp_key_gate_replaced=@{value=($global:scenario -ne 'stage1')}
            mcp_auth_audience=@{value='api://44444444-4444-4444-8444-444444444444'}
            mcp_auth_scope=@{value='api://44444444-4444-4444-8444-444444444444/user_impersonation'}
            mcp_auth_issuer=@{value="https://login.microsoftonline.com/$global:tenant/v2.0"}
        } | ConvertTo-Json -Depth 5)
    }
}
function global:az {
    $global:LASTEXITCODE=0
    $line = $args -join ' '
    if ($args[0] -eq 'cloud') { return '{"name":"AzureCloud"}' }
    if ($args[0] -eq 'account' -and $args[1] -eq 'show') { return (@{id="$global:subscription";tenantId="$global:tenant";state='Enabled';environmentName='AzureCloud';userType='user'} | ConvertTo-Json) }
    if ($args[0] -eq 'account' -and $args[1] -eq 'get-access-token') {
        if ($line -match 'graph\\.microsoft\\.com') { return $global:graphToken }
        if ($global:persona -eq 'Eve' -and $global:scenario -ne 'eve-gets-token') { $global:LASTEXITCODE=1; return 'ERROR: AADSTS50105: The signed in user is not assigned to a role for the application.' }
        return $global:mcpToken
    }
    if ($args[0] -eq 'rest') {
        return (@{properties=@{platform=@{enabled=$true}; globalValidation=@{requireAuthentication=$true;unauthenticatedClientAction='Return401'}
            identityProviders=@{azureActiveDirectory=@{registration=@{openIdIssuer="https://login.microsoftonline.com/$global:tenant/v2.0";clientId='44444444-4444-4444-8444-444444444444'}
            validation=@{allowedAudiences=@('api://44444444-4444-4444-8444-444444444444','44444444-4444-4444-8444-444444444444')}}}}} | ConvertTo-Json -Depth 10)
    }
    if ($args[0] -eq 'functionapp' -and $args[1] -eq 'config') {
        return (@(@{name='AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel';value='Anonymous'},
            @{name='WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES';value='api://44444444-4444-4444-8444-444444444444/user_impersonation'}) | ConvertTo-Json)
    }
    if ($args[0] -eq 'functionapp' -and $args[1] -eq 'keys') { return 'SyntheticKeyValue-DoNotPrint-0123456789' }
    throw "Unexpected Azure command: $($args[0]) $($args[1])"
}
function global:Invoke-WebRequest {
    param($Uri, $Method, $Body, $ContentType, $Headers, [switch]$SkipHttpErrorCheck, $MaximumRedirection, $TimeoutSec)
    if ($Method -eq 'Get') {
        $prm = @{resource="https://$global:fqdn/runtime/webhooks/mcp"; authorization_servers=@("https://login.microsoftonline.com/$global:tenant/v2.0")
            scopes_supported=@('api://44444444-4444-4444-8444-444444444444/user_impersonation')} | ConvertTo-Json
        return [pscustomobject]@{StatusCode=200;Content=$prm;Headers=@{'Content-Type'=@('application/json')}}
    }
    $authorization = if ($Headers -and $Headers.ContainsKey('Authorization')) { $Headers['Authorization'] } else { '' }
    $ok = $authorization -eq "Bearer $global:mcpToken"
    if ($global:scenario -eq 'anonymous-open') { $ok = $true }
    if ($global:scenario -eq 'graph-accepted' -and $authorization -eq "Bearer $global:graphToken") { $ok = $true }
    if (-not $ok) { return [pscustomobject]@{StatusCode=401;Content='';Headers=@{'WWW-Authenticate'=@("Bearer realm=\`"$global:fqdn\`", resource_metadata=\`"https://$global:fqdn/.well-known/oauth-protected-resource/runtime/webhooks/mcp\`"")}} }
    $request = $Body | ConvertFrom-Json
    $content = switch ($request.method) {
        'initialize' { '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"workshop","version":"0.3.0"}}}' }
        'notifications/initialized' { '' }
        'tools/list' { 'event: message' + [char]10 + 'data: ' + (@{jsonrpc='2.0';id=2;result=@{tools=@('create_ticket','get_service_health','read_report_as_app','read_report_as_user','whoami' | ForEach-Object { @{name=$_} })}} | ConvertTo-Json -Depth 5 -Compress) + [char]10 }
    }
    $type = if ($request.method -eq 'tools/list') { 'text/event-stream' } else { 'application/json' }
    $status = if ($request.method -eq 'notifications/initialized') { 202 } else { 200 }
    [pscustomobject]@{StatusCode=$status;Content=$content;Headers=@{'Content-Type'=@($type);'Mcp-Session-Id'=@('synthetic-session')}}
}
$validator='${quote(join(module03, "validate.ps1"))}'
$cases = @(
    @{ scenario='operator'; persona=$null; sub=$true; ok=$true; lines=@('without a token is refused by built-in authentication (expected HTTP 401)','Protected Resource Metadata (Preview)','another audience (Microsoft Graph) is refused (expected HTTP 401)','deployed authsettingsV2','system key alone no longer opens the server (expected HTTP 401)','operator checks complete') }
    @{ scenario='valid'; persona='Alice'; sub=$false; ok=$true; lines=@('Alice initialize with a token for the MCP audience succeeds','Alice tools/list returns exactly the five workshop tools (expected HTTP 200)') }
    @{ scenario='valid'; persona='Bob'; sub=$false; ok=$true; lines=@('Bob tools/list returns exactly the five workshop tools (expected HTTP 200)') }
    @{ scenario='valid'; persona='Eve'; sub=$false; ok=$true; lines=@('Eve cannot obtain a token','AADSTS50105') }
    @{ scenario='eve-gets-token'; persona='Eve'; sub=$false; ok=$false }
    @{ scenario='anonymous-open'; persona='Alice'; sub=$false; ok=$false }
    @{ scenario='graph-accepted'; persona='Alice'; sub=$false; ok=$false }
    @{ scenario='stage1'; persona='Alice'; sub=$false; ok=$false }
)
foreach ($case in $cases) {
    $global:scenario=$case.scenario; $global:persona=$case.persona
    $parameters = @{ TenantId=$tenant; SkipBuild=$true; PersonaObjectIdsPath='${quote(missing)}' }
    if ($case.sub) { $parameters.SubscriptionId = $global:subscription }
    if ($case.persona) { $parameters.Persona = $case.persona }
    $failed=$false; $output=@()
    try { $output = & $validator @parameters 6>&1 | ForEach-Object { "$_" } } catch { $failed=$true; $output += $_.Exception.Message }
    $text = $output -join [char]10
    if ($text -match 'DoNotPrint') { throw "The validator printed a token or key in $($case.scenario)." }
    if ($case.ok) {
        if ($failed) { throw "$($case.scenario)/$($case.persona) failed: $text" }
        foreach ($line in $case.lines) { if (-not $text.Contains($line)) { throw "$($case.scenario)/$($case.persona) missing: $line" } }
    } elseif (-not $failed -or $text -notmatch 'FAIL') { throw "$($case.scenario) must fail closed: $text" }
    Write-Output "PASS synthetic validator $($case.scenario) $($case.persona)"
}
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic validator /g) ?? []).length, 8);
    assert.doesNotMatch(result.stdout + result.stderr, /DoNotPrint/);
});

test("module 03 cleanup: key gate first, then auth off; Entra destroy only workshop objects; refuses foreign changes (synthetic Terraform)", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-entra-cleanup-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const parameters = join(directory, "participant.tfvars.json");
    const module02 = join(directory, "module02.tfvars.json");
    const module03Vars = join(directory, "module03.tfvars.json");
    const entraParameters = join(directory, "entra.tfvars.json");
    const expiry = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
    writeFileSync(parameters, JSON.stringify({ participant_prefix: "p01", resource_suffix: "0123456789abcdef", location: "swedencentral",
        owner: "alice", expiry, existing_resource_group_name: null }));
    writeFileSync(module02, JSON.stringify({ enable_mcp_server: true }));
    writeFileSync(module03Vars, JSON.stringify({ enable_entra_auth: true, entra_auth_replace_key_gate: true }));
    writeFileSync(entraParameters, JSON.stringify({ tenant_id: "00000000-0000-4000-8000-000000000000" }));
    const result = pwsh(`
$ErrorActionPreference='Stop'
$tenant=[guid]::NewGuid(); $global:subscription=[guid]::NewGuid(); $global:tenant=$tenant
function global:az {
    $global:LASTEXITCODE=0
    if ($args[0] -eq 'cloud') { return '{"name":"AzureCloud"}' }
    if ($args[0] -eq 'account') { return (@{id="$global:subscription";tenantId="$global:tenant";state='Enabled';environmentName='AzureCloud';userType='user'} | ConvertTo-Json) }
    throw 'Unexpected Azure command.'
}
$webhook='AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel'
function global:terraform {
    $global:LASTEXITCODE=0
    if ($args -contains 'init') { return }
    if ($args -contains 'apply') { $global:applied += $global:phase; return }
    if ($args -contains 'plan') {
        if ($args -contains '-destroy') { $global:phase='entra' }
        elseif ($args -contains '-var=enable_entra_auth=false') { $global:phase='auth-off' }
        elseif (($args -contains '-var=entra_auth_replace_key_gate=false') -and ($args -match 'module03')) { $global:phase='key-back' }
        else { throw "Unexpected plan arguments: $args" }
        return
    }
    if ($args -contains 'show') {
        $app = 'azurerm_function_app_flex_consumption.mcp[0]'
        $module02Diff = @{address=$app;change=@{actions=@('update');before=@{app_settings=@{TICKET_QUEUE_NAME='tickets'};auth_settings_v2=@()}}}
        $changes = switch ("$global:scenario/$global:phase") {
            'report/key-back' { @(@{address=$app;change=@{actions=@('update');before=@{app_settings=@{$webhook='Anonymous'};auth_settings_v2=@(@{auth_enabled=$true})}}}) }
            'apply/key-back' { @(@{address=$app;change=@{actions=@('update');before=@{app_settings=@{$webhook='Anonymous'};auth_settings_v2=@(@{auth_enabled=$true})}}}) }
            'apply/auth-off' { @(@{address=$app;change=@{actions=@('update');before=@{app_settings=@{};auth_settings_v2=@(@{auth_enabled=$true})}}}) }
            'foreign/key-back' { @(@{address='azurerm_storage_account.mcp[0]';change=@{actions=@('delete');before=@{}}}) }
            'entra-apply/entra' { @(@{address='azuread_application.mcp[0]';change=@{actions=@('delete')}}, @{address='azuread_app_role_assignment.personas["alice-read"]';change=@{actions=@('delete')}}, @{address='azuread_application_pre_authorized.clients["aebc6443-996d-45c2-90f0-388ff96faa56"]';change=@{actions=@('delete')}}) }
            'entra-foreign/entra' { @(@{address='azuread_application.mcp[0]';change=@{actions=@('update')}}) }
            default { @($module02Diff) }
        }
        return (@{resource_changes=$changes} | ConvertTo-Json -Depth 10)
    }
}
$cleanup='${quote(join(module03, "cleanup.ps1"))}'
foreach ($global:scenario in @('report','apply','empty','foreign','entra-apply','entra-foreign')) {
    $global:applied=@(); $failed=$false; $text=''
    $entra = $global:scenario -like 'entra-*'
    $parameters = @{ TenantId=$tenant; Apply=($global:scenario -in @('apply','entra-apply')) }
    if ($entra) { $parameters.Scope='Entra'; $parameters.EntraParametersPath='${quote(entraParameters)}' }
    else { $parameters.SubscriptionId=$global:subscription; $parameters.ParametersPath='${quote(parameters)}'; $parameters.Module02VarFile='${quote(module02)}'; $parameters.Module03VarFile='${quote(module03Vars)}' }
    try { $text = (& $cleanup @parameters) -join [char]10 } catch { $failed=$true; $text=$_.Exception.Message }
    switch ($global:scenario) {
        'report' { if ($failed -or $global:applied.Count -ne 0 -or $text -notmatch 'phase 1' -or $text -notmatch 'rerun with -Apply' -or $text -match 'phase 2') { throw "report: $text" } }
        'apply' { if ($failed -or ($global:applied -join ',') -ne 'key-back,auth-off') { throw "apply order: $($global:applied -join ',') $text" } }
        'empty' { if ($failed -or $global:applied.Count -ne 0 -or ([regex]::Matches($text, 'nothing to do')).Count -ne 2) { throw "empty: $text" } }
        'entra-apply' { if ($failed -or ($global:applied -join ',') -ne 'entra') { throw "entra-apply: $text" } }
        default { if (-not $failed -or $global:applied.Count -ne 0) { throw "$global:scenario must refuse: $text" } }
    }
    Write-Output "PASS synthetic cleanup $global:scenario"
}
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic cleanup /g) ?? []).length, 6);
});

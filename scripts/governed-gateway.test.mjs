import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("../", import.meta.url));
const module04 = join(root, "modules", "04-governed-gateway");
const workload = join(root, "infra", "workload");
const quote = (path) => path.replaceAll("'", "''");

function pwsh(script) {
    return spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", script], { encoding: "utf8", timeout: 240000 });
}

test("module 04 guides keep the contract, teach the gateway controls, mark Preview and cost, and contain no key or token", () => {
    for (const file of ["README.md", "README.fr.md"]) {
        const guide = readFileSync(join(module04, file), "utf8");
        const headings = [...guide.matchAll(/^## (.+)$/gm)].map((match) => match[1]);
        assert.equal(headings.length, 11, `${file} must keep the eleven contract sections`);
        for (const term of ["validate-azure-ad-token", "rate-limit-by-key", "ip-filter", "Tools.Write", "Tools.Read", "HTTP 401", "HTTP 403",
            "HTTP 429", "HTTP 200", "Preview", "2025-09-01-preview", "Standard v2", "privatelink.azurewebsites.net", "preserveContent: true",
            "policies/mcp-server.xml", "cleanup.ps1", "04b", "export-rest-mcp-server", "1679e3137d2fe7592d2a668d77ff71550d35b69e"]) {
            assert.ok(guide.includes(term), `${file} must mention ${term}`);
        }
        assert.match(guide, /provisioned capacity|capacité provisionnée/);
        assert.match(guide, /one logical MCP resource|une seule ressource MCP logique/);
        assert.doesNotMatch(guide, /eyJ[A-Za-z0-9_-]{8,}\.eyJ/);
        assert.doesNotMatch(guide, /Ocp-Apim-Subscription-Key"\s*:/);
        assert.doesNotMatch(guide, /client_secret|ClientSecret|\*\*\*\*\*\*/);
        assert.match(guide, /Last verified|Dernière vérification/);
    }
});

test("module 04 policy and Terraform keep one audience, per-tool roles, zero body bytes and the staged Function lock", () => {
    const policy = readFileSync(join(module04, "policies", "mcp-server.xml"), "utf8");
    assert.match(policy, /As<JObject>\(preserveContent: true\)/);
    assert.match(policy, /if \(tool == "create_ticket"\) \{ return "Tools\.Write\|create_ticket"; \}/);
    assert.match(policy, /counter-key="@\("workshop-mcp-oid-" \+ \(string\)context\.Variables\["mcp-caller-oid"\]\)"/);
    assert.equal((policy.match(/<audience>/g) ?? []).length, 1, "a single audience loop over the module 03 audiences");
    assert.doesNotMatch(policy, /context\.Response\.Body|<validate-jwt|subscription-key|AsJwt\(/i);
    const prm = readFileSync(join(module04, "policies", "protected-resource-metadata.xml"), "utf8");
    assert.match(prm, /"scopes_supported":\["\$\{scope\}"\]/);
    assert.doesNotMatch(prm, /azurewebsites/);
    const gateway = readFileSync(join(workload, "gateway.tf"), "utf8");
    assert.match(gateway, /Microsoft\.ApiManagement\/service\/apis@2025-09-01-preview" # Preview/);
    assert.match(gateway, /subscriptionRequired\s*=\s*false/);
    assert.match(gateway, /audiences\s*=\s*local\.mcp_auth_audiences/);
    assert.doesNotMatch(gateway, /azurerm_api_management_subscription|subscriptionRequired\s*=\s*true/);
    const diagnostics = readFileSync(join(workload, "diagnostics.tf"), "utf8");
    assert.equal((diagnostics.match(/body_bytes\s*=\s*0/g) ?? []).length, 4);
    assert.doesNotMatch(diagnostics, /body_bytes\s*=\s*[1-9]/);
    assert.match(readFileSync(join(workload, "mcp-server.tf"), "utf8"), /public_network_access_enabled\s*=\s*!local\.gateway_function_locked/);
    assert.match(readFileSync(join(workload, "main.tf"), "utf8"), /source\s*=\s*"Azure\/azapi"\s*\n\s*version\s*=\s*"= 2\.13\.0"/);
    assert.match(readFileSync(join(workload, ".terraform.lock.hcl"), "utf8"), /azure\/azapi"[\s\S]*version\s*=\s*"2\.13\.0"/);
    assert.match(readFileSync(join(workload, "tests", "governed_gateway.tftest.hcl"), "utf8"), /run "gateway_stage_2_locks_the_function"/);
});

test("module 04 validator offline mode passes without Azure and states it is not deployment evidence", () => {
    const result = pwsh(`& '${quote(join(module04, "validate.ps1"))}' -Offline -SkipBuild`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, /PASS gateway policy: Entra token for the MCP audience only, create_ticket requires Tools\.Write/);
    assert.match(result.stdout, /PASS diagnostics: 0 body bytes/);
    assert.match(result.stdout, /Module 04 is NOT deployed or validated/);
});

test("module 04 live validator: 401/PRM/direct 403, Bob 403 and Alice 200 on create_ticket, 429 burst, payload-free telemetry, fails closed (synthetic)", () => {
    const missing = join(tmpdir(), "workshop-no-personas-file.json");
    const result = pwsh(`
$ErrorActionPreference='Stop'
$tenant=[guid]'00000000-0000-4000-8000-000000000000'; $global:subscription=[guid]::NewGuid(); $global:tenant=$tenant
$global:graphToken='SyntheticGraphToken-DoNotPrint.payload.signature'
$global:gatewayHost='apim-mcp-p01-0123456789.azure-api.net'
$global:functionHost='func-mcp-p01-0123456789.azurewebsites.net'
$global:prmUrl="https://$global:gatewayHost/.well-known/oauth-protected-resource/workshop-mcp/mcp"
function global:Get-PersonaToken([string]$name) { "SyntheticMcpToken-$name-DoNotPrint.payload.signature" }
function global:terraform {
    $global:LASTEXITCODE=0
    if ($args -contains 'output') {
        return (@{
            mcp_function_app_name=@{value='func-mcp-p01-0123456789'}; resource_group_name=@{value='rg-mcp-p01-0123456789'}
            resource_names=@{value=@{log_analytics='log-mcp-p01-0123456789'}}
            mcp_endpoint=@{value="https://$global:functionHost/runtime/webhooks/mcp"}
            mcp_auth_audience=@{value='api://44444444-4444-4444-8444-444444444444'}
            mcp_auth_scope=@{value='api://44444444-4444-4444-8444-444444444444/user_impersonation'}
            mcp_auth_issuer=@{value="https://login.microsoftonline.com/$global:tenant/v2.0"}
            gateway_enabled=@{value=$true}; gateway_name=@{value='apim-mcp-p01-0123456789'}; gateway_mcp_api_name=@{value='workshop-mcp'}
            gateway_mcp_endpoint=@{value="https://$global:gatewayHost/workshop-mcp/mcp"}; gateway_resource_metadata_url=@{value=$global:prmUrl}
            gateway_function_public_access_disabled=@{value=($global:scenario -ne 'stage1')}
            gateway_rate_limit=@{value=@{calls=30;period=60}}
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
        if ($global:persona -eq 'Eve') { $global:LASTEXITCODE=1; return 'ERROR: AADSTS50105: The signed in user is not assigned to a role for the application.' }
        return (Get-PersonaToken $global:persona)
    }
    if ($args[0] -eq 'rest' -and $line -match 'Microsoft\\.Web/sites') {
        $access = if ($global:scenario -eq 'site-public') { 'Enabled' } else { 'Disabled' }
        return (@{properties=@{publicNetworkAccess=$access}} | ConvertTo-Json -Depth 5)
    }
    if ($args[0] -eq 'rest' -and $line -match 'diagnostics/applicationinsights') {
        $bytes = if ($global:scenario -eq 'body-logged' -and $line -match '/apis/') { 1024 } else { 0 }
        $side = @{request=@{headers=@();body=@{bytes=0}};response=@{headers=@();body=@{bytes=$bytes}}}
        return (@{properties=@{frontend=$side;backend=@{request=@{headers=@();body=@{bytes=0}};response=@{headers=@();body=@{bytes=0}}}}} | ConvertTo-Json -Depth 10)
    }
    if ($args[0] -eq 'monitor' -and $args[2] -eq 'workspace') { return '{"customerId":"00000000-0000-4000-8000-0000000000aa"}' }
    if ($args[0] -eq 'monitor' -and $args[2] -eq 'query') {
        if ($line -match 'AppRequests') { $p = if ($global:scenario -eq 'telemetry-payload') { 2 } else { 0 }; return "[{\`"total\`":\`"12\`",\`"payload\`":\`"$p\`",\`"credential\`":\`"0\`"}]" }
        return '[{"total":"8","labelled":"8","payload":"0"}]'
    }
    throw "Unexpected Azure command: $($args[0]) $($args[1])"
}
function global:Invoke-WebRequest {
    param($Uri, $Method, $Body, $ContentType, $Headers, [switch]$SkipHttpErrorCheck, $MaximumRedirection, $TimeoutSec)
    $json = @{'Content-Type'=@('application/json')}
    if ($Method -eq 'Get') {
        $resource = if ($global:scenario -eq 'prm-leak') { "https://$global:functionHost/runtime/webhooks/mcp" } else { "https://$global:gatewayHost/workshop-mcp/mcp" }
        $prm = @{resource=$resource; authorization_servers=@("https://login.microsoftonline.com/$global:tenant/v2.0")
            scopes_supported=@('api://44444444-4444-4444-8444-444444444444/user_impersonation')} | ConvertTo-Json
        return [pscustomobject]@{StatusCode=200;Content=$prm;Headers=$json}
    }
    if ("$Uri" -match 'azurewebsites') {
        $status = if ($global:scenario -eq 'direct-open') { 401 } else { 403 }
        return [pscustomobject]@{StatusCode=$status;Content='';Headers=@{}}
    }
    $authorization = if ($Headers -and $Headers.ContainsKey('Authorization')) { $Headers['Authorization'] } else { '' }
    $caller = $null
    foreach ($name in 'Alice', 'Bob') { if ($authorization -eq ('Bearer ' + (Get-PersonaToken $name))) { $caller = $name } }
    if ($global:scenario -eq 'gateway-open' -and -not $caller) { $caller = 'Alice' }
    if (-not $caller) { return [pscustomobject]@{StatusCode=401;Content='';Headers=@{'WWW-Authenticate'=@("Bearer resource_metadata=\`"$global:prmUrl\`"")}} }
    $request = $Body | ConvertFrom-Json -AsHashtable
    if (-not $request.ContainsKey('method')) { return [pscustomobject]@{StatusCode=400;Content='{"error":"invalid_request"}';Headers=$json} }
    $global:calls++
    if ($global:calls -gt 30 -and $global:scenario -ne 'no-429') { return [pscustomobject]@{StatusCode=429;Content='';Headers=@{'Retry-After'=@('60')}} }
    $ok = { param($id, $result) [pscustomobject]@{StatusCode=200;Content=(@{jsonrpc='2.0';id=$id;result=$result} | ConvertTo-Json -Depth 6 -Compress);Headers=$json} }
    switch ($request.method) {
        'initialize' { return [pscustomobject]@{StatusCode=200;Content='{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}}}}';Headers=@{'Content-Type'=@('application/json');'Mcp-Session-Id'=@('synthetic-session')}} }
        'notifications/initialized' { return [pscustomobject]@{StatusCode=202;Content='';Headers=@{}} }
        'ping' { return (& $ok $request.id @{}) }
        'tools/list' {
            $data = @{jsonrpc='2.0';id=2;result=@{tools=@('create_ticket','get_service_health','read_report_as_app','read_report_as_user','whoami' | ForEach-Object { @{name=$_} })}} | ConvertTo-Json -Depth 5 -Compress
            return [pscustomobject]@{StatusCode=200;Content=('event: message' + [char]10 + 'data: ' + $data + [char]10);Headers=@{'Content-Type'=@('text/event-stream')}}
        }
        'tools/call' {
            $tool = $request.params.name
            if ($tool -eq 'create_ticket' -and $caller -eq 'Bob' -and $global:scenario -ne 'bob-can-write') { return [pscustomobject]@{StatusCode=403;Content='{"error":"forbidden"}';Headers=$json} }
            if ($tool -notin @('create_ticket','get_service_health')) { return [pscustomobject]@{StatusCode=403;Content='{"error":"forbidden"}';Headers=$json} }
            return (& $ok $request.id @{content=@(@{type='text';text='synthetic'});isError=$false})
        }
    }
    throw "Unexpected MCP method $($request.method)"
}
$validator='${quote(join(module04, "validate.ps1"))}'
$cases = @(
    @{ scenario='valid'; persona=$null; sub=$true; telemetry=$true; ok=$true; lines=@('gateway request without a token is refused with a challenge naming the gateway metadata (expected HTTP 401)','gateway Protected Resource Metadata names the gateway resource','direct call to the Function host is refused from the internet: HTTP 403 (expected HTTP 403)','another audience (Microsoft Graph) is refused by the gateway (expected HTTP 401)','publicNetworkAccess is Disabled','0 body bytes and no header at the all-APIs and MCP API scopes','Application Insights: 12 gateway requests and 8 tool traces','operator checks complete') }
    @{ scenario='valid'; persona='Alice'; ok=$true; lines=@('Alice tools/list through the gateway returns the five workshop tools (expected HTTP 200)','Alice get_service_health is allowed with Tools.Read (expected HTTP 200)','Alice create_ticket is allowed with Tools.Write and queues one synthetic ticket (expected HTTP 200)','denied safely (expected HTTP 403 and HTTP 400)') }
    @{ scenario='valid'; persona='Bob'; burst=$true; ok=$true; lines=@('Bob get_service_health is allowed with Tools.Read (expected HTTP 200)','Bob create_ticket is denied by the gateway: Tools.Write is missing (expected HTTP 403)','Bob burst of 40 calls is throttled per caller object ID (expected HTTP 429)') }
    @{ scenario='valid'; persona='Eve'; ok=$true; lines=@('Eve cannot obtain a token','AADSTS50105') }
    @{ scenario='gateway-open'; persona='Alice'; ok=$false }
    @{ scenario='bob-can-write'; persona='Bob'; ok=$false }
    @{ scenario='direct-open'; persona=$null; sub=$true; ok=$false }
    @{ scenario='stage1'; persona='Alice'; ok=$false }
    @{ scenario='site-public'; persona=$null; sub=$true; ok=$false }
    @{ scenario='body-logged'; persona=$null; sub=$true; ok=$false }
    @{ scenario='telemetry-payload'; persona=$null; sub=$true; telemetry=$true; ok=$false }
    @{ scenario='no-429'; persona='Bob'; burst=$true; ok=$false }
    @{ scenario='prm-leak'; persona='Alice'; ok=$false }
)
foreach ($case in $cases) {
    $global:scenario=$case.scenario; $global:persona=$case.persona; $global:calls=0
    $parameters = @{ TenantId=$tenant; SkipBuild=$true; PersonaObjectIdsPath='${quote(missing)}' }
    if ($case.sub) { $parameters.SubscriptionId = $global:subscription }
    if ($case.persona) { $parameters.Persona = $case.persona }
    if ($case.burst) { $parameters.Burst = $true }
    if ($case.telemetry) { $parameters.CheckTelemetry = $true }
    $failed=$false; $output=@()
    try { $output = & $validator @parameters 6>&1 | ForEach-Object { "$_" } } catch { $failed=$true; $output += $_.Exception.Message }
    $text = $output -join [char]10
    if ($text -match 'DoNotPrint') { throw "The validator printed a token in $($case.scenario)." }
    if ($case.ok) {
        if ($failed) { throw "$($case.scenario)/$($case.persona) failed: $text" }
        foreach ($line in $case.lines) { if (-not $text.Contains($line)) { throw "$($case.scenario)/$($case.persona) missing: $line" } }
    } elseif (-not $failed -or $text -notmatch 'FAIL') { throw "$($case.scenario) must fail closed: $text" }
    Write-Output "PASS synthetic validator $($case.scenario) $($case.persona)"
}
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic validator /g) ?? []).length, 13);
    assert.doesNotMatch(result.stdout + result.stderr, /DoNotPrint/);
});

test("module 04 cleanup: reopen the Function first, then delete only gateway resources; refuses foreign changes (synthetic Terraform)", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-gateway-cleanup-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const parameters = join(directory, "participant.tfvars.json");
    const module02 = join(directory, "module02.tfvars.json");
    const module03 = join(directory, "module03.tfvars.json");
    const module04Vars = join(directory, "module04.tfvars.json");
    const expiry = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
    writeFileSync(parameters, JSON.stringify({ participant_prefix: "p01", resource_suffix: "0123456789abcdef", location: "swedencentral",
        owner: "alice", expiry, existing_resource_group_name: null }));
    writeFileSync(module02, JSON.stringify({ enable_mcp_server: true }));
    writeFileSync(module03, JSON.stringify({ enable_entra_auth: true, entra_auth_replace_key_gate: true }));
    writeFileSync(module04Vars, JSON.stringify({ enable_governed_gateway: true, gateway_lock_function: true }));
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
    if ($args -contains 'init') { return }
    if ($args -contains 'apply') { $global:applied += $global:phase; return }
    if ($args -contains 'plan') {
        if ($args -contains '-var=enable_governed_gateway=false') { $global:phase='remove' }
        elseif (($args -contains '-var=gateway_lock_function=false') -and ($args -match 'module04')) { $global:phase='reopen' }
        else { throw "Unexpected plan arguments: $args" }
        return
    }
    if ($args -contains 'show') {
        $app = 'azurerm_function_app_flex_consumption.mcp[0]'
        $module02Diff = @{address=$app;change=@{actions=@('update');before=@{public_network_access_enabled=$true}}}
        $locked = @{address=$app;change=@{actions=@('update');before=@{public_network_access_enabled=$false}}}
        $gateway = @('azurerm_api_management.gateway[0]','azapi_resource.mcp_api[0]','azapi_resource.mcp_api_policy[0]','azurerm_private_endpoint.function[0]','azurerm_virtual_network.gateway[0]') |
            ForEach-Object { @{address=$_;change=@{actions=@('delete')}} }
        $changes = switch ("$global:scenario/$global:phase") {
            'report/reopen' { @($locked) }
            'apply/reopen' { @($locked) }
            'apply/remove' { @($module02Diff) + $gateway }
            'foreign/reopen' { @(@{address='azurerm_storage_account.mcp[0]';change=@{actions=@('delete')}}) }
            'server-delete/remove' { @(@{address=$app;change=@{actions=@('delete')}}) + $gateway }
            'normalised/reopen' { @($locked, @{address='azapi_resource.mcp_api_policy[0]';change=@{actions=@('update');before=@{body=@{properties=@{format='xml';value=('<policies>' + [char]10 + [char]9 + '<inbound>@(&quot;x&quot;)</inbound>' + [char]10 + '</policies>')}}};after=@{body=@{properties=@{format='rawxml';value=('<policies>' + [char]10 + '  <inbound>@("x")</inbound>' + [char]10 + '</policies>')}}}}},
                @{address='azurerm_linux_web_app.portal[0]';change=@{actions=@('update');before=@{https_only=$true;app_settings=@{A='1';WORKSHOP_MCP_ENDPOINT='https://gateway.example.invalid/workshop-mcp/mcp'}};after=@{https_only=$true;app_settings=@{A='1';WORKSHOP_MCP_ENDPOINT='https://func.example.invalid/runtime/webhooks/mcp'}}}}) }
            'policy-changed/reopen' { @($locked, @{address='azapi_resource.mcp_api_policy[0]';change=@{actions=@('update');before=@{body=@{properties=@{value='<policies><inbound>a</inbound></policies>'}}};after=@{body=@{properties=@{value='<policies><inbound>b</inbound></policies>'}}}}}) }
            'portal-other/reopen' { @($locked, @{address='azurerm_linux_web_app.portal[0]';change=@{actions=@('update');before=@{https_only=$true;app_settings=@{A='1';WORKSHOP_MCP_ENDPOINT='https://g'}};after=@{https_only=$true;app_settings=@{A='2';WORKSHOP_MCP_ENDPOINT='https://f'}}}}) }
            default { @($module02Diff) }
        }
        return (@{resource_changes=$changes} | ConvertTo-Json -Depth 10)
    }
}
$cleanup='${quote(join(module04, "cleanup.ps1"))}'
foreach ($global:scenario in @('report','apply','empty','foreign','server-delete','normalised','policy-changed','portal-other')) {
    $global:applied=@(); $failed=$false; $text=''
    $parameters = @{ TenantId=$tenant; SubscriptionId=$global:subscription; Apply=($global:scenario -ne 'report')
        ParametersPath='${quote(parameters)}'; Module02VarFile='${quote(module02)}'; Module03VarFile='${quote(module03)}'; Module04VarFile='${quote(module04Vars)}' }
    try { $text = (& $cleanup @parameters) -join [char]10 } catch { $failed=$true; $text=$_.Exception.Message }
    switch ($global:scenario) {
        'report' { if ($failed -or $global:applied.Count -ne 0 -or $text -notmatch 'phase 1' -or $text -notmatch 'rerun with -Apply' -or $text -match 'phase 2') { throw "report: $text" } }
        'apply' { if ($failed -or ($global:applied -join ',') -ne 'reopen,remove' -or $text -notmatch 'deletedservice purge') { throw "apply order: $($global:applied -join ',') $text" } }
        'empty' { if ($failed -or $global:applied.Count -ne 0 -or ([regex]::Matches($text, 'nothing to do')).Count -ne 2) { throw "empty: $text" } }
        'normalised' { if ($failed -or $global:applied -notcontains 'reopen') { throw "normalised: whitespace-only policy and portal hint updates must be accepted: $text" } }
        default { if (-not $failed -or $global:applied.Count -ne 0) { throw "$global:scenario must refuse: $text" } }
    }
    Write-Output "PASS synthetic cleanup $global:scenario"
}
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic cleanup /g) ?? []).length, 8);
});

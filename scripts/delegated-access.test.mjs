import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("../", import.meta.url));
const module05 = join(root, "modules", "05-delegated-and-app-only");
const workload = join(root, "infra", "workload");
const entra = join(root, "infra", "entra");
const quote = (path) => path.replaceAll("'", "''");

function pwsh(script) {
    return spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", script], { encoding: "utf8", timeout: 300000 });
}

test("module 05 guides keep the contract, contrast Alice and Bob, separate outer HTTP from isError, and contain no secret or token", () => {
    for (const file of ["README.md", "README.fr.md"]) {
        const guide = readFileSync(join(module05, file), "utf8");
        const headings = [...guide.matchAll(/^## (.+)$/gm)].map((match) => match[1]);
        assert.equal(headings.length, 11, `${file} must keep the eleven contract sections`);
        for (const term of ["On-Behalf-Of", "whoami", "read_report_as_user", "read_report_as_app", "isError", "HTTP 200", "HTTP 403",
            "User.Read", "user_impersonation", "api://AzureADTokenExchange", "Storage Blob Data Reader", "enable_delegated_access",
            "obo_identity_principal_id", "grant_downstream_admin_consent", "publish-report.ps1", "cleanup.ps1", "Preview",
            "468c518c884ec318e3001b9573254c9e775409c9", "swedencentral"]) {
            assert.ok(guide.includes(term), `${file} must mention ${term}`);
        }
        assert.match(guide, /\| Alice \|/);
        assert.match(guide, /\| Bob \|/);
        assert.doesNotMatch(guide, /eyJ[A-Za-z0-9_-]{8,}\.eyJ/);
        assert.doesNotMatch(guide, /client_secret|ClientSecret|clientSecretSettingName|\*\*\*\*\*\*/);
        assert.match(guide, /Last verified|Dernière vérification/);
    }
});

test("module 05 code and Terraform keep one token per hop, separate identities, container-scoped roles and no secret", () => {
    const credentials = readFileSync(join(root, "src", "FunctionsMcpServer", "Identity", "DownstreamCredentials.cs"), "utf8");
    assert.match(credentials, /new OnBehalfOfCredential\(/);
    assert.match(credentials, /api:\/\/AzureADTokenExchange\/\.default/);
    assert.doesNotMatch(credentials, /AzureCliCredential|DefaultAzureCredential|ChainedTokenCredential|ClientSecretCredential/);
    const caller = readFileSync(join(root, "src", "FunctionsMcpServer", "Logic", "CallerContext.cs"), "utf8");
    assert.match(caller, /App-only callers cannot use a user-context tool/);
    assert.doesNotMatch(caller, /JwtSecurityTokenHandler|JsonWebTokenHandler|ValidateToken/);
    const delegated = readFileSync(join(workload, "delegated-access.tf"), "utf8");
    const scopes = [...delegated.matchAll(/^\s*scope\s*=\s*(\S+)/gm)].map((match) => match[1]);
    assert.deepEqual(scopes, ["azurerm_storage_container.reports[0].id", "azurerm_storage_container.reports[0].id", "azurerm_storage_container.reports[0].id"]);
    assert.doesNotMatch(delegated, /^\s*principal_id\s*=\s*azurerm_user_assigned_identity\.(delegated_obo|mcp)\[0\]\.principal_id/m);
    const delegation = readFileSync(join(entra, "delegation.tf"), "utf8");
    assert.match(delegation, /resource "azuread_application_federated_identity_credential" "obo"/);
    assert.match(delegation, /e406a681-f3d4-42a8-90b6-c2b029497af1/);
    assert.doesNotMatch(delegation, /azuread_application_password|role_ids/);
    assert.match(readFileSync(join(entra, "main.tf"), "utf8"), /ignore_changes = \[identifier_uris, required_resource_access\]/);
    assert.match(readFileSync(join(workload, "tests", "delegated_access.tftest.hcl"), "utf8"), /run "delegated_default_off_keeps_modules_02_to_04"/);
    assert.match(readFileSync(join(entra, "tests", "entra.tftest.hcl"), "utf8"), /run "module05_default_off_changes_nothing"/);
});

test("module 05 validator offline mode passes without Azure and states it is not deployment evidence", () => {
    const result = pwsh(`& '${quote(join(module05, "validate.ps1"))}' -Offline -SkipBuild`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.match(result.stdout, /PASS server: On-Behalf-Of with a managed-identity assertion/);
    assert.match(result.stdout, /PASS infra\/workload: separate OBO assertion and app-only identities/);
    assert.match(result.stdout, /PASS no client secret, key, SAS or token/);
    assert.match(result.stdout, /Module 05 is NOT deployed or validated/);
});

test("module 05 live validator: Alice reads, Bob gets HTTP 200 with isError, as_app identical, whoami persona, no secret; fails closed for the right reason (synthetic)", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-delegated-validator-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const personas = join(directory, "personas.json");
    writeFileSync(personas, JSON.stringify({ alice: "a11ce000-0000-4000-8000-000000000001", bob: "b0b00000-0000-4000-8000-000000000002" }));
    const result = pwsh(`
$ErrorActionPreference='Stop'
$tenant=[guid]'00000000-0000-4000-8000-000000000000'; $global:tenant=$tenant; $global:subscription=[guid]::NewGuid()
$global:client='44444444-4444-4444-8444-444444444444'
$global:obo='0b0a5500-0000-4000-8000-000000000005'; $global:reportMi='7e9047a0-0000-4000-8000-000000000007'
$global:ids=@{ Alice='a11ce000-0000-4000-8000-000000000001'; Bob='b0b00000-0000-4000-8000-000000000002' }
$global:rows=@(@{service='workshop-api';requests=1200;errors=3},@{service='ticket-queue';requests=340;errors=12})
function global:Get-PersonaToken([string]$name) { "SyntheticMcpToken-$name-DoNotPrint.payload.signature" }
function global:terraform {
    $global:LASTEXITCODE=0
    if ($args -contains 'output') {
        return (@{
            delegated_access_enabled=@{value=($global:scenario -ne 'not-deployed')}
            delegated_obo_identity_principal_id=@{value=$global:obo}
            delegated_storage_account_name=@{value='stp01synthetic'}
            mcp_function_app_name=@{value='func-mcp-p01-0123456789'}; resource_group_name=@{value='rg-mcp-p01-0123456789'}
            mcp_endpoint=@{value='https://func-mcp-p01-0123456789.azurewebsites.net/runtime/webhooks/mcp'}
            gateway_enabled=@{value=$true}; gateway_mcp_endpoint=@{value='https://apim-mcp-p01-0123456789.azure-api.net/workshop-mcp/mcp'}
            mcp_auth_audience=@{value="api://$global:client"}
            mcp_auth_issuer=@{value="https://login.microsoftonline.com/$global:tenant/v2.0"}
        } | ConvertTo-Json -Depth 5)
    }
}
function global:az {
    $global:LASTEXITCODE=0
    $line = $args -join ' '
    if ($args[0] -eq 'cloud') { return '{"name":"AzureCloud"}' }
    if ($args[0] -eq 'account' -and $args[1] -eq 'show') { return (@{id="$global:subscription";tenantId="$global:tenant";state='Enabled';environmentName='AzureCloud';userType='user'} | ConvertTo-Json) }
    if ($args[0] -eq 'account' -and $args[1] -eq 'get-access-token') { return (Get-PersonaToken $global:persona) }
    if ($args[0] -eq 'ad' -and $args[1] -eq 'signed-in-user') { return $global:ids[$global:persona] }
    if ($args[0] -eq 'functionapp') {
        $names = @('AzureWebJobsStorage__clientId','WORKSHOP_DELEGATED_ACCESS','WORKSHOP_OBO_ASSERTION_CLIENT_ID','WORKSHOP_REPORT_IDENTITY_CLIENT_ID','WORKSHOP_REPORT_CONTAINER_URL')
        if ($global:scenario -eq 'secret-setting') { $names += 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET' }
        return (ConvertTo-Json -InputObject $names)
    }
    if ($args[0] -eq 'ad' -and $args[2] -eq 'credential') {
        if ($global:scenario -eq 'client-secret') { return '[{"displayName":"synthetic","keyId":"00000000-0000-4000-8000-0000000000aa"}]' }
        return '[]'
    }
    if ($args[0] -eq 'ad' -and $args[2] -eq 'federated-credential') {
        $subject = if ($global:scenario -eq 'fic-wrong-subject') { $global:reportMi } else { $global:obo }
        if ($global:scenario -eq 'no-fic') { return '[]' }
        return (ConvertTo-Json -Depth 5 -InputObject @(@{name='workshop-obo-p01';subject=$subject;issuer="https://login.microsoftonline.com/$global:tenant/v2.0";audiences=@('api://AzureADTokenExchange')}))
    }
    if ($args[0] -eq 'role') {
        $scope = $args[$args.IndexOf('--scope') + 1]
        $roles = @(@{role='Storage Blob Data Reader';principal=$global:reportMi;scope=$scope}, @{role='Storage Blob Data Reader';principal=$global:ids.Alice;scope=$scope},
            @{role='Storage Blob Data Contributor';principal='9b000000-0000-4000-8000-0000000000b9';scope=$scope})
        if ($global:scenario -eq 'bob-has-role') { $roles += @{role='Storage Blob Data Reader';principal=$global:ids.Bob;scope=$scope} }
        if ($global:scenario -eq 'obo-has-role') { $roles[1] = @{role='Storage Blob Data Reader';principal=$global:obo;scope=$scope} }
        return (ConvertTo-Json -Depth 5 -InputObject $roles)
    }
    throw "Unexpected Azure command: $($args[0]) $($args[1])"
}
function global:Invoke-WebRequest {
    param($Uri, $Method, $Body, $ContentType, $Headers, [switch]$SkipHttpErrorCheck, $MaximumRedirection, $TimeoutSec)
    $json = @{'Content-Type'=@('application/json')}
    $caller = $null
    foreach ($name in 'Alice', 'Bob') { if ($Headers['Authorization'] -eq ('Bearer ' + (Get-PersonaToken $name))) { $caller = $name } }
    if (-not $caller) { return [pscustomobject]@{StatusCode=401;Content='';Headers=@{}} }
    $request = $Body | ConvertFrom-Json -AsHashtable
    $tool = { param($id, $value, [bool]$isError) [pscustomobject]@{StatusCode=200;Headers=$json;Content=(@{jsonrpc='2.0';id=$id;result=@{isError=$isError;content=@(@{type='text';text=$value})}} | ConvertTo-Json -Depth 8 -Compress)} }
    switch ($request.method) {
        'initialize' { return [pscustomobject]@{StatusCode=200;Content='{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}}}}';Headers=@{'Content-Type'=@('application/json');'Mcp-Session-Id'=@('synthetic-session')}} }
        'notifications/initialized' { return [pscustomobject]@{StatusCode=202;Content='';Headers=@{}} }
        'tools/list' {
            $data = @{jsonrpc='2.0';id=2;result=@{tools=@('create_ticket','get_service_health','read_report_as_app','read_report_as_user','whoami' | ForEach-Object { @{name=$_} })}} | ConvertTo-Json -Depth 5 -Compress
            return [pscustomobject]@{StatusCode=200;Content=('event: message' + [char]10 + 'data: ' + $data + [char]10);Headers=@{'Content-Type'=@('text/event-stream')}}
        }
        'tools/call' {
            $name = $request.params.name; $label = $caller.ToLowerInvariant()
            if ($name -eq 'whoami') {
                if ($global:scenario -eq 'whoami-email') { return (& $tool $request.id '{"persona":"alice","graphMatchesCaller":true,"mail":"alice@contoso.example"}' $false) }
                $persona = if ($global:scenario -eq 'whoami-wrong') { 'unlisted' } else { $label }
                return (& $tool $request.id (@{persona=$persona;graphMatchesCaller=$true} | ConvertTo-Json -Compress) $false)
            }
            if ($name -eq 'read_report_as_user') {
                $denied = ($caller -eq 'Bob' -and $global:scenario -ne 'bob-reads') -or ($caller -eq 'Alice' -and $global:scenario -eq 'alice-denied')
                if ($denied -and $global:scenario -eq 'bob-http-403') { return [pscustomobject]@{StatusCode=403;Content='{"error":"forbidden"}';Headers=$json} }
                if ($denied) { return (& $tool $request.id "An error occurred invoking 'read_report_as_user'." $true) }
                return (& $tool $request.id (@{mode='as-user';persona=$label;source='synthetic';rows=$global:rows} | ConvertTo-Json -Depth 5 -Compress) $false)
            }
            if ($name -eq 'read_report_as_app') {
                $rows = if ($global:scenario -eq 'app-differs' -and $caller -eq 'Bob') { @($global:rows[0]) } else { $global:rows }
                return (& $tool $request.id (@{mode='as-app';persona=$null;source='synthetic';rows=$rows} | ConvertTo-Json -Depth 5 -Compress) $false)
            }
        }
    }
    throw "Unexpected MCP method $($request.method)"
}
$validator='${quote(join(module05, "validate.ps1"))}'
$cases = @(
    @{ scenario='valid'; persona=$null; sub=$true; ok=$true; lines=@('Function App settings name both module 05 identities and hold no secret setting','no client secret, exactly one federated credential trusting the OBO managed identity','2 Storage Blob Data Reader assignment(s)','operator checks complete') }
    @{ scenario='valid'; persona='Alice'; ok=$true; lines=@("Alice whoami: On-Behalf-Of to Microsoft Graph returns the synthetic persona 'alice'",'Alice read_report_as_user returns the synthetic report with her own Storage role (expected HTTP 200, isError false)','Run the other persona to compare') }
    @{ scenario='valid'; persona='Bob'; ok=$true; lines=@("Bob whoami: On-Behalf-Of to Microsoft Graph returns the synthetic persona 'bob'",'Bob read_report_as_user: the MCP call succeeds but the tool result is an error','(expected HTTP 200, isError true, downstream HTTP 403)','read_report_as_app returned the same result for Alice and Bob') }
    @{ scenario='not-deployed'; persona='Alice'; fail='module 05 is not deployed' }
    @{ scenario='bob-reads'; persona='Bob'; fail='Bob read_report_as_user returned HTTP 200, isError False' }
    @{ scenario='bob-http-403'; persona='Bob'; fail='Bob read_report_as_user returned HTTP 403' }
    @{ scenario='alice-denied'; persona='Alice'; fail='Alice read_report_as_user returned HTTP 200 without the synthetic report' }
    @{ scenario='app-differs'; persona='Alice'; then='Bob'; fail='Bob read_report_as_app returned HTTP 200 without the shared synthetic report' }
    @{ scenario='whoami-email'; persona='Alice'; fail='no name or email' }
    @{ scenario='whoami-wrong'; persona='Bob'; fail='Bob whoami returned HTTP 200 without the allowlisted persona label' }
    @{ scenario='client-secret'; persona=$null; sub=$true; fail='password credential (client secret)' }
    @{ scenario='no-fic'; persona=$null; sub=$true; fail='exactly one federated credential trusting the OBO identity' }
    @{ scenario='fic-wrong-subject'; persona=$null; sub=$true; fail='exactly one federated credential trusting the OBO identity' }
    @{ scenario='secret-setting'; persona=$null; sub=$true; fail='secret-like setting' }
    @{ scenario='bob-has-role'; persona=$null; sub=$true; fail='none for the OBO identity or Bob' }
    @{ scenario='obo-has-role'; persona=$null; sub=$true; fail='none for the OBO identity or Bob' }
)
$evidence = '${quote(directory)}'
foreach ($case in $cases) {
    $global:scenario=$case.scenario
    $runs = @($case.persona) + @($case.then | Where-Object { $_ })
    if ($case.scenario -ne 'valid') { Get-ChildItem -LiteralPath $evidence -Filter '*.sha256' -ErrorAction SilentlyContinue | Remove-Item -Force }
    $failed=$false; $output=@()
    foreach ($persona in $runs) {
        $global:persona=$persona
        $parameters = @{ TenantId=$tenant; SkipBuild=$true; PersonaObjectIdsPath='${quote(personas)}'; EvidenceDirectory=$evidence }
        if ($case.sub) { $parameters.SubscriptionId = $global:subscription }
        if ($persona) { $parameters.Persona = $persona }
        try { $output += & $validator @parameters 6>&1 | ForEach-Object { "$_" } } catch { $failed=$true; $output += $_.Exception.Message; break }
    }
    $text = $output -join [char]10
    if ($text -match 'DoNotPrint') { throw "The validator printed a token in $($case.scenario)." }
    if ($case.ok) {
        if ($failed) { throw "$($case.scenario)/$($case.persona) failed: $text" }
        foreach ($line in $case.lines) { if (-not $text.Contains($line)) { throw "$($case.scenario)/$($case.persona) missing: $line" } }
    } else {
        if (-not $failed -or $text -notmatch 'FAIL') { throw "$($case.scenario) must fail closed: $text" }
        if (-not $text.Contains($case.fail)) { throw "$($case.scenario) failed for the wrong reason: $text" }
    }
    Write-Output "PASS synthetic validator $($case.scenario) $($case.persona)"
}
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic validator /g) ?? []).length, 16);
    assert.doesNotMatch(result.stdout + result.stderr, /DoNotPrint/);
});

test("module 05 cleanup removes only module 05 objects in the workload and in Entra, and refuses anything else (synthetic Terraform)", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-delegated-cleanup-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const parameters = join(directory, "participant.tfvars.json");
    const files = Object.fromEntries(["module02", "module03", "module05", "entra"].map((name) => [name, join(directory, `${name}.tfvars.json`)]));
    const expiry = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
    writeFileSync(parameters, JSON.stringify({ participant_prefix: "p01", resource_suffix: "0123456789abcdef", location: "swedencentral",
        owner: "alice", expiry, existing_resource_group_name: null }));
    writeFileSync(files.module02, JSON.stringify({ enable_mcp_server: true }));
    writeFileSync(files.module03, JSON.stringify({ enable_entra_auth: true, entra_auth_replace_key_gate: true }));
    writeFileSync(files.module05, JSON.stringify({ enable_delegated_access: true }));
    writeFileSync(files.entra, JSON.stringify({ tenant_id: "00000000-0000-4000-8000-000000000000" }));
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
        $global:phase = if ($args -match 'infra[\\\\/]entra') { 'entra' } else { 'workload' }
        if ($global:phase -eq 'workload' -and $args -notcontains '-var=enable_delegated_access=false') { throw "Unexpected plan arguments: $args" }
        if ($global:phase -eq 'entra') {
            $off = @($args | Where-Object { $_ -match 'module05-entra-off-' })[0] -replace '^-var-file=', ''
            $values = Get-Content -LiteralPath $off -Raw | ConvertFrom-Json -AsHashtable
            if ($values.enable_delegated_access -or $values.grant_downstream_admin_consent -or $null -ne $values.obo_identity_principal_id) { throw 'Entra phase must turn module 05 off.' }
        }
        return
    }
    if ($args -contains 'show') {
        $app = @{address='azurerm_function_app_flex_consumption.mcp[0]';change=@{actions=@('update')}}
        $workloadDeletes = @('azurerm_user_assigned_identity.delegated_obo[0]','azurerm_user_assigned_identity.delegated_report[0]','azurerm_storage_container.reports[0]',
            'azurerm_role_assignment.report_app_reader[0]','azurerm_role_assignment.report_persona_reader["alice"]','azurerm_role_assignment.report_publisher[0]') |
            ForEach-Object { @{address=$_;change=@{actions=@('delete')}} }
        $entraDeletes = @('azuread_application_federated_identity_credential.obo[0]','azuread_application_api_access.downstream["graph"]','azuread_application_api_access.downstream["storage"]',
            'azuread_service_principal_delegated_permission_grant.downstream["graph"]','azuread_service_principal_delegated_permission_grant.downstream["storage"]') |
            ForEach-Object { @{address=$_;change=@{actions=@('delete')}} }
        $changes = switch ("$global:scenario/$global:phase") {
            'report/workload' { @($app) + $workloadDeletes }
            'apply/workload' { @($app) + $workloadDeletes }
            'empty/workload' { @($app) }
            'foreign/workload' { @($app) + $workloadDeletes + @(@{address='azurerm_storage_account.mcp[0]';change=@{actions=@('delete')}}) }
            'normalised/workload' { @($app) + $workloadDeletes + @(@{address='azapi_resource.prm_operation_policy[0]';change=@{actions=@('update');before=@{body=@{properties=@{format='xml';value=('<policies>' + [char]10 + [char]9 + '<set-body>@(&quot;x&quot;)</set-body>' + [char]10 + '</policies>')}}};after=@{body=@{properties=@{format='rawxml';value=('<policies>' + [char]10 + '  <set-body>@("x")</set-body>' + [char]10 + '</policies>')}}}}}) }
            'policy-changed/workload' { @($app) + $workloadDeletes + @(@{address='azapi_resource.mcp_api_policy[0]';change=@{actions=@('update');before=@{body=@{properties=@{value='<policies><inbound>a</inbound></policies>'}}};after=@{body=@{properties=@{value='<policies><inbound>b</inbound></policies>'}}}}}) }
            'entra-apply/entra' { $entraDeletes }
            'entra-foreign/entra' { $entraDeletes + @(@{address='azuread_application.mcp[0]';change=@{actions=@('delete')}}) }
            'entra-empty/entra' { @() }
            default { @() }
        }
        return (@{resource_changes=$changes} | ConvertTo-Json -Depth 10)
    }
}
$cleanup='${quote(join(module05, "cleanup.ps1"))}'
foreach ($global:scenario in @('report','apply','empty','foreign','normalised','policy-changed','entra-apply','entra-foreign','entra-empty')) {
    $global:applied=@(); $failed=$false; $text=''
    $common = @{ TenantId=$tenant; Apply=($global:scenario -ne 'report') }
    if ($global:scenario -like 'entra-*') {
        $common.Scope='Entra'; $common.EntraParametersPath='${quote(files.entra)}'; $common.EntraModule05VarFile=(Join-Path '${quote(directory)}' 'missing.json')
    } else {
        $common.SubscriptionId=$global:subscription; $common.ParametersPath='${quote(parameters)}'; $common.Module02VarFile='${quote(files.module02)}'
        $common.Module03VarFile='${quote(files.module03)}'; $common.Module04VarFile=(Join-Path '${quote(directory)}' 'missing.json'); $common.Module05VarFile='${quote(files.module05)}'
    }
    try { $text = (& $cleanup @common) -join [char]10 } catch { $failed=$true; $text=$_.Exception.Message }
    switch ($global:scenario) {
        'report' { if ($failed -or $global:applied.Count -ne 0 -or ([regex]::Matches($text, 'PLAN delete')).Count -ne 6 -or $text -notmatch 'rerun with -Apply') { throw "report: $text" } }
        'apply' { if ($failed -or ($global:applied -join ',') -ne 'workload' -or $text -notmatch 'back to the module 02 demonstrations') { throw "apply: $text" } }
        'empty' { if ($failed -or $global:applied.Count -ne 0 -or $text -notmatch 'nothing to do') { throw "empty: $text" } }
        'normalised' { if ($failed -or ($global:applied -join ',') -ne 'workload') { throw "normalised: a whitespace-only policy update must be accepted: $text" } }
        'entra-apply' { if ($failed -or ($global:applied -join ',') -ne 'entra' -or ([regex]::Matches($text, 'PLAN delete')).Count -ne 5 -or $text -notmatch 'Module 03 objects stay') { throw "entra-apply: $text" } }
        'entra-empty' { if ($failed -or $global:applied.Count -ne 0 -or $text -notmatch 'nothing to do') { throw "entra-empty: $text" } }
        default { if (-not $failed -or $global:applied.Count -ne 0 -or $text -notmatch 'outside module 05') { throw "$global:scenario must refuse: $text" } }
    }
    Write-Output "PASS synthetic cleanup $global:scenario"
}
if (Get-ChildItem -LiteralPath (Join-Path '${quote(root)}' '.workshop') -Filter 'module05-entra-off-*' -ErrorAction SilentlyContinue) { throw 'The temporary Entra var file was not removed.' }
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic cleanup /g) ?? []).length, 9);
});

test("module 05 publish step uploads only the synthetic report with Entra auth, retries role propagation, refuses when not deployed (synthetic)", () => {
    const result = pwsh(`
$ErrorActionPreference='Stop'
$tenant=[guid]::NewGuid(); $global:subscription=[guid]::NewGuid(); $global:tenant=$tenant
function global:terraform { $global:LASTEXITCODE=0; return (@{delegated_access_enabled=@{value=($global:scenario -ne 'not-deployed')};delegated_storage_account_name=@{value='stp01synthetic'};delegated_report_blob_name=@{value='monthly-usage.json'}} | ConvertTo-Json -Depth 4) }
function global:az {
    $line = $args -join ' '
    $global:LASTEXITCODE=0
    if ($args[0] -eq 'cloud') { return '{"name":"AzureCloud"}' }
    if ($args[0] -eq 'account') { return (@{id="$global:subscription";tenantId="$global:tenant";state='Enabled';environmentName='AzureCloud';userType='user'} | ConvertTo-Json) }
    if ($args[0] -eq 'storage') {
        if ($line -notmatch '--auth-mode login' -or $line -match 'account-key|sas-token|connection-string') { throw 'Upload must use Entra authentication only.' }
        if ($line -notmatch 'synthetic-data[\\\\/]monthly-usage\\.json' -or $line -notmatch '--container-name reports') { throw 'Unexpected upload.' }
        $global:uploads++
        if ($global:uploads -lt 2) { $global:LASTEXITCODE=1; return 'ERROR: AuthorizationPermissionMismatch' }
        return
    }
    throw 'Unexpected Azure command.'
}
$publish='${quote(join(module05, "publish-report.ps1"))}'
$global:scenario='valid'; $global:uploads=0
$text = (& $publish -TenantId $tenant -SubscriptionId $global:subscription -RetryDelaySeconds 0) -join [char]10
if ($global:uploads -ne 2 -or $text -notmatch 'PASS synthetic report published' -or $text -notmatch 'INFO upload attempt 1 refused') { throw "publish: $text" }
Write-Output 'PASS synthetic publish valid'
$global:scenario='not-deployed'; $global:uploads=0; $failed=$false
try { & $publish -TenantId $tenant -SubscriptionId $global:subscription -RetryDelaySeconds 0 | Out-Null } catch { $failed = $_.Exception.Message -match 'not deployed' }
if (-not $failed -or $global:uploads -ne 0) { throw 'publish must refuse when module 05 is not deployed' }
Write-Output 'PASS synthetic publish not-deployed'
`);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic publish /g) ?? []).length, 2);
});

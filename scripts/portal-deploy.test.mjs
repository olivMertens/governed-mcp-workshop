import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { buildPortal } from "./build-site.mjs";
import { publicPaths } from "./portal-server.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
test("portal deployment checks ownership and protection, honors WhatIf, and packages the exact public allowlist without real Azure access", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-deploy-fixture-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const scripts = join(directory, "scripts");
    mkdirSync(scripts);
    for (const file of ["deploy-portal.ps1", "context-common.ps1", "package-portal.ps1", "portal-server.mjs"]) {
        copyFileSync(join(root, "scripts", file), join(scripts, file));
    }
    writeFileSync(join(scripts, "preflight.ps1"), `
param($TenantId, $SubscriptionId, $Stage, $ParametersPath, $CapacityReviewPath)
if ($Stage -ne 'portal' -or -not $CapacityReviewPath) { throw 'Missing preflight stage/evidence.' }
Write-Output 'PASS synthetic preflight fixture; real implementation is tested separately.'
`);
    const bundle = join(directory, "bundle");
    buildPortal(root, bundle);
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", `
$ErrorActionPreference='Stop'
$directory='${directory.replaceAll("'", "''")}'
$global:subscription=[guid]::NewGuid()
$tenant=[guid]::NewGuid()
$global:writes=0
$expiry=[datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
$global:expectedExpiry=$expiry
$path=Join-Path $directory 'parameters.json'
$zipPath=Join-Path $directory 'public.zip'
$parameters=@{participant_prefix='p01';resource_suffix='0123456789abcdef';location='westeurope';owner='alice';
    expiry=$expiry;existing_resource_group_name=$null;public_portal_enabled=$true}
function global:az {
    $global:LASTEXITCODE=0
    if ($args[0] -eq 'webapp' -and $args[1] -eq 'deploy') { $global:writes++; return }
    $result = if ($args[0] -eq 'rest' -and $args[1] -eq '--method' -and $args[2] -eq 'get') {
        @{properties=@{allow=($global:scenario -eq 'basic-enabled')}}
    } elseif ($args[0] -eq 'webapp' -and $args[1] -eq 'show') {
        @{id="/subscriptions/$global:subscription/resourceGroups/rg-mcp-p01-0123456789abcdef/providers/Microsoft.Web/sites/web-mcp-p01-0123456789abcdef-portal";
            httpsOnly=$true;defaultHostName='web-mcp-p01-0123456789abcdef-portal.azurewebsites.net';
            serverFarmId="/subscriptions/$global:subscription/resourceGroups/rg-mcp-p01-0123456789abcdef/providers/Microsoft.Web/serverfarms/plan-mcp-p01-0123456789abcdef-portal";
            tags=@{workshop='mcp-p01-0123456789abcdef';owner=$(if ($global:scenario -eq 'wrong-owner') {'bob'} else {'alice'});expiry=$global:expectedExpiry}}
    } elseif ($args[0] -eq 'webapp' -and $args[1] -eq 'config' -and $args[2] -eq 'show') {
        @{linuxFxVersion=$(if ($global:scenario -eq 'wrong-runtime') {'NODE|20-lts'} else {'NODE|22-lts'});
            appCommandLine='node server.mjs';ftpsState='Disabled';minTlsVersion='1.2';scmMinTlsVersion='1.2'}
    } else { throw 'Unexpected Azure command.' }
    ConvertTo-Json -InputObject $result -Depth 10 -Compress
}
function global:Invoke-WebRequest { @{StatusCode=200;Content='{"status":"ok"}'} }
$script=Join-Path $directory 'scripts/deploy-portal.ps1'
foreach ($global:scenario in @('what-if','wrong-owner','basic-enabled','wrong-runtime','not-opted-in','valid','existing-package')) {
    $global:writes=0
    $parameters.public_portal_enabled=($global:scenario -ne 'not-opted-in')
    $parameters | ConvertTo-Json | Set-Content -LiteralPath $path
    $failed=$false
    try {
        $arguments=@{TenantId=$tenant;SubscriptionId=$global:subscription;ParametersPath=$path;
            CapacityReviewPath=(Join-Path $directory 'synthetic-capacity.json');BundlePath=(Join-Path $directory 'bundle');
            PackagePath=$zipPath;WhatIf=($global:scenario -eq 'what-if');Confirm=$false}
        & $script @arguments | Out-Null
    } catch { $failed=$true; $message=$_.Exception.Message }
    $expectedSuccess=$global:scenario -in @('what-if','valid')
    if ($failed -eq $expectedSuccess) { throw "Unexpected $global:scenario result: $message" }
    if ($global:writes -ne $(if ($global:scenario -eq 'valid') {1} else {0})) { throw 'Unexpected Azure write.' }
    if ($global:scenario -eq 'what-if' -and (Test-Path -LiteralPath $zipPath)) { throw 'WhatIf created a package.' }
    if ($global:scenario -eq 'valid') {
        $archive=[IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            if ($archive.Entries.Count -ne ${publicPaths.length + 2} -or $null -eq $archive.GetEntry('.nojekyll') -or
                $archive.Entries.FullName -match '(^|/)([.]workshop|[.]git)(/|$)|[.]tfstate|[.]tfplan|participant[.]tfvars') { throw 'Incorrect public ZIP contents.' }
            $expected=@(${[...publicPaths, "server.mjs", "site-manifest.json"].map((path) => `'${path}'`).join(",")})
            if (Compare-Object ($archive.Entries.FullName | Sort-Object) ($expected | Sort-Object)) { throw 'ZIP differs from the public allowlist.' }
        } finally { $archive.Dispose() }
    }
    Write-Output "PASS synthetic portal $global:scenario (expected HTTP N/A; no real Azure access)"
}
`], { encoding: "utf8", timeout: 60000 });
    assert.equal(result.status, 0, result.stderr + result.stdout);
    assert.equal((result.stdout.match(/PASS synthetic portal /g) ?? []).length, 7);
});

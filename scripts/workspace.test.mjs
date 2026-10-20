import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync, readFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("../", import.meta.url));
function powershell(source, t, timeout = 30000) {
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", source],
        { encoding: "utf8", timeout });
    if (result.error?.code === "ENOENT") { t.skip("PowerShell 7.4+ is required."); return null; }
    assert.ifError(result.error);
    return result;
}

test("participant preparation is stable, isolated and refuses replacements or malformed input", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-workspace-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    for (const participant of ["one", "two"]) {
        mkdirSync(join(directory, participant, "scripts"), { recursive: true });
        copyFileSync(join(root, "scripts", "prepare-workshop.ps1"), join(directory, participant, "scripts", "prepare-workshop.ps1"));
    }
    const escaped = directory.replaceAll("'", "''");
    const result = powershell(`
$ErrorActionPreference = 'Stop'
function az { throw 'Preparation must not call Azure.' }
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
$one = Join-Path '${escaped}' 'one'
$two = Join-Path '${escaped}' 'two'
$scriptOne = Join-Path $one 'scripts' 'prepare-workshop.ps1'
$scriptTwo = Join-Path $two 'scripts' 'prepare-workshop.ps1'
& $scriptOne -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry $expiry
$path = Join-Path $one '.workshop' 'participant.tfvars.json'
$before = [IO.File]::ReadAllText($path)
& $scriptOne -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry $expiry
if ([IO.File]::ReadAllText($path) -cne $before) { throw 'Rerun changed the participant file.' }
& $scriptTwo -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry $expiry -ExistingResourceGroupName rg-synthetic-admin
$first = $before | ConvertFrom-Json
$second = Get-Content (Join-Path $two '.workshop' 'participant.tfvars.json') -Raw | ConvertFrom-Json
if ($first.resource_suffix -eq $second.resource_suffix -or $second.existing_resource_group_name -ne 'rg-synthetic-admin') { throw 'Participant isolation failed.' }
$rejected = 0
foreach ($change in @(@{Owner='bob';Expiry=$expiry}, @{Owner='alice';Expiry='2000-01-01'}, @{Owner='alice';Expiry='2099-02-30'})) {
  try { & $scriptOne -ParticipantPrefix p01 -Location westeurope @change }
  catch { $rejected++ }
}
if ($rejected -ne 3 -or [IO.File]::ReadAllText($path) -cne $before) { throw 'Unsafe changes were accepted.' }
& $scriptOne -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry $expiry -EnablePublicPortal
$opted = [IO.File]::ReadAllText($path)
$portal = $opted | ConvertFrom-Json
if (-not $portal.public_portal_enabled -or $portal.resource_suffix -cne $first.resource_suffix) { throw 'Portal opt-in changed resource names.' }
& $scriptOne -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry $expiry
if ([IO.File]::ReadAllText($path) -cne $opted) { throw 'Rerun removed persistent portal opt-in.' }
Write-Output 'PASS stable parameters and safe rejection'
`, t);
    if (!result) return;
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /PASS stable parameters and safe rejection/);
});

test("100 participants with identical shared-group inputs get independent 64-bit suffixes and stable reruns", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-cohort-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const result = powershell(`
$ErrorActionPreference = 'Stop'
function az { throw 'Cohort preparation must never call Azure.' }
. '${join(root, "scripts", "context-common.ps1").replaceAll("'", "''")}'
$source = '${join(root, "scripts", "prepare-workshop.ps1").replaceAll("'", "''")}'
$root = '${directory.replaceAll("'", "''")}'
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
$suffixes = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
for ($index = 0; $index -lt 100; $index++) {
  $workspace = Join-Path $root "participant-$index"
  $scripts = Join-Path $workspace 'scripts'
  [void][IO.Directory]::CreateDirectory($scripts)
  $script = Join-Path $scripts 'prepare-workshop.ps1'
  Copy-Item -LiteralPath $source -Destination $script
  $arguments = @{ParticipantPrefix='p01';Location='westeurope';Owner='alice';Expiry=$expiry;
    ExistingResourceGroupName='rg-synthetic-shared'}
  & $script @arguments | Out-Null
  $path = Join-Path $workspace '.workshop' 'participant.tfvars.json'
  $before = [IO.File]::ReadAllText($path)
  $parameters = Read-WorkshopParameters -Path $path
  if ($parameters.resource_suffix -cnotmatch '^[a-f0-9]{16}$' -or -not $suffixes.Add($parameters.resource_suffix)) {
    throw 'A fresh participant suffix is malformed or duplicated.'
  }
  if ($parameters.existing_resource_group_name -cne 'rg-synthetic-shared') { throw 'Shared group was changed.' }
  & $script @arguments | Out-Null
  if ([IO.File]::ReadAllText($path) -cne $before) { throw 'A rerun changed participant names.' }
}
if ($suffixes.Count -ne 100) { throw 'Cohort isolation failed.' }
Write-Output 'PASS 100 independent participants, one shared group, identical inputs and unchanged reruns'
`, t, 120000);
    if (!result) return;
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /PASS 100 independent participants/);
});

test("legacy suffixes stay byte-for-byte stable and missing parameters never replace known state or plans", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-naming-guard-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const result = powershell(`
$ErrorActionPreference = 'Stop'
function az { throw 'Naming safety must not call Azure.' }
. '${join(root, "scripts", "context-common.ps1").replaceAll("'", "''")}'
$root = '${directory.replaceAll("'", "''")}'
$source = '${join(root, "scripts", "prepare-workshop.ps1").replaceAll("'", "''")}'
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
$arguments = @{ParticipantPrefix='abcdefgh';Location='westeurope';Owner='alice';Expiry=$expiry}
$scripts = Join-Path $root 'legacy' 'scripts'
[void][IO.Directory]::CreateDirectory($scripts)
$script = Join-Path $scripts 'prepare-workshop.ps1'
Copy-Item -LiteralPath $source -Destination $script
& $script @arguments | Out-Null
$path = Join-Path $root 'legacy' '.workshop' 'participant.tfvars.json'
$parameters = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
$parameters.resource_suffix = '0123456789'
[IO.File]::WriteAllText($path, ($parameters | ConvertTo-Json))
$before = [IO.File]::ReadAllText($path)
& $script @arguments | Out-Null
if ([IO.File]::ReadAllText($path) -cne $before -or (Read-WorkshopParameters -Path $path).resource_suffix -cne '0123456789') {
  throw 'Legacy parameters were migrated or rejected.'
}
foreach ($suffix in @('012345678', '01234567890', '0123456789abcde', '0123456789abcdeg', '0123456789ABCDEF')) {
  $parameters.resource_suffix = $suffix
  [IO.File]::WriteAllText($path, ($parameters | ConvertTo-Json))
  $rejected = 0
  try { & $script @arguments | Out-Null } catch { $rejected++ }
  try { Read-WorkshopParameters -Path $path | Out-Null } catch { $rejected++ }
  if ($rejected -ne 2) { throw 'Malformed saved suffix was accepted.' }
}
$cases = @(
  @('infra','workload','terraform.tfstate'),
  @('infra','workload','terraform.tfstate.backup'),
  @('infra','workload','terraform.tfstate.d'),
  @('infra','workload','.terraform','terraform.tfstate'),
  @('.workshop','workload.tfplan'),
  @('.workshop','terraform.tfstate.backup')
)
for ($index=0; $index -lt $cases.Count; $index++) {
  $workspace = Join-Path $root "guard-$index"
  $scripts = Join-Path $workspace 'scripts'
  [void][IO.Directory]::CreateDirectory($scripts)
  $script = Join-Path $scripts 'prepare-workshop.ps1'
  Copy-Item -LiteralPath $source -Destination $script
  $artifact = $workspace
  foreach ($part in $cases[$index]) { $artifact = Join-Path $artifact $part }
  [void][IO.Directory]::CreateDirectory((Split-Path $artifact -Parent))
  if ($artifact.EndsWith('.d')) { [void][IO.Directory]::CreateDirectory($artifact) }
  else { [IO.File]::WriteAllText($artifact, 'synthetic private artifact') }
  $rejected = $false
  try { & $script @arguments | Out-Null }
  catch { $rejected = $_.Exception.Message -match 'Restore the original private parameters' }
  if (-not $rejected -or (Test-Path -LiteralPath (Join-Path $workspace '.workshop' 'participant.tfvars.json'))) {
    throw 'Missing participant parameters silently produced replacement resource names.'
  }
  if (-not (Test-Path -LiteralPath $artifact)) { throw 'Existing state/plan was removed.' }
}
$workspace = Join-Path $root 'providers-only'
$scripts = Join-Path $workspace 'scripts'
[void][IO.Directory]::CreateDirectory($scripts)
[void][IO.Directory]::CreateDirectory((Join-Path $workspace 'infra' 'workload' '.terraform' 'providers'))
$script = Join-Path $scripts 'prepare-workshop.ps1'
Copy-Item -LiteralPath $source -Destination $script
& $script @arguments | Out-Null
if ((Read-WorkshopParameters -Path (Join-Path $workspace '.workshop' 'participant.tfvars.json')).resource_suffix.Length -ne 16) {
  throw 'Provider initialization without state must not block a genuinely new participant.'
}
Write-Output 'PASS legacy stability, invalid suffix rejection and six missing-parameter guards'
`, t);
    if (!result) return;
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /PASS legacy stability/);
});

test("shared tool checks accept working tools and reject incompatible versions without Azure login", (t) => {
    const script = join(root, "scripts", "check-tools.ps1").replaceAll("'", "''");
    for (const [compatible, track] of [[true, "terraform"], [false, "terraform"], [true, "low-code"], [false, "low-code"]]) {
        const result = powershell(`
function global:git { $global:LASTEXITCODE=0; 'git version 2.53.0' }
function global:az { if ($args[0] -ne 'version') { throw 'Unexpected Azure access.' }; $global:LASTEXITCODE=0; '{"azure-cli":"2.88.0"}' }
function global:terraform { ${track === "low-code" ? "throw 'Low-code must not execute Terraform.'" : "$global:LASTEXITCODE=0; '{\"terraform_version\":\"1.16.6\"}'"} }
function global:dotnet { $global:LASTEXITCODE=0; '${compatible ? "10.0.402" : "9.0.319"} [synthetic]' }
function global:node { $global:LASTEXITCODE=0; 'v22.22.0' }
function global:func { $global:LASTEXITCODE=0; '4.14.0' }
& '${script}' -Track '${track}'
`, t);
        if (!result) return;
        if (compatible) {
            assert.equal(result.status, 0, result.stderr);
            assert.match(result.stdout, /PASS local tools only/);
            if (track === "low-code") assert.doesNotMatch(result.stdout, /PASS terraform/);
        } else {
            assert.notEqual(result.status, 0);
            assert.match(result.stdout, /FAIL dotnet/);
        }
    }
});

test("bash preparation calls the same PowerShell implementation and persists its parameters", (t) => {
    const bash = process.platform === "win32" ? "C:\\Program Files\\Git\\bin\\bash.exe" : "bash";
    if (process.platform === "win32" && !existsSync(bash)) { t.skip("Git bash is not installed."); return; }
    const directory = mkdtempSync(join(tmpdir(), "workshop-bash-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    mkdirSync(join(directory, "scripts"));
    for (const file of ["prepare-workshop.ps1", "prepare-workshop.sh"]) {
        copyFileSync(join(root, "scripts", file), join(directory, "scripts", file));
    }
    const expiry = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    const result = spawnSync(bash, ["--noprofile", "--norc", "./scripts/prepare-workshop.sh",
        "-ParticipantPrefix", "p02", "-Location", "westeurope", "-Owner", "bob", "-Expiry", expiry],
        { cwd: directory, encoding: "utf8", timeout: 30000 });
    if (result.error?.code === "ENOENT") { t.skip("bash is not installed."); return; }
    assert.equal(result.status, 0, result.stderr);
    const parameters = JSON.parse(readFileSync(join(directory, ".workshop", "participant.tfvars.json"), "utf8"));
    assert.equal(parameters.participant_prefix, "p02");
    assert.match(parameters.resource_suffix, /^[a-f0-9]{16}$/);
});

test("dev container pins public images/features and uses the common checker without credential mounts", () => {
    const configuration = JSON.parse(readFileSync(join(root, ".devcontainer", "devcontainer.json"), "utf8"));
    assert.match(configuration.image, /^mcr\.microsoft\.com\/devcontainers\/base:ubuntu-24\.04@sha256:[a-f0-9]{64}$/);
    for (const reference of Object.keys(configuration.features)) {
        assert.match(reference, /^ghcr\.io\/devcontainers\/features\/[\w-]+:[\d.]+@sha256:[a-f0-9]{64}$/);
    }
    assert.equal(configuration.remoteUser, "vscode");
    assert.equal(configuration.mounts, undefined);
    const setup = readFileSync(join(root, ".devcontainer", "setup.sh"), "utf8");
    assert.match(setup, /check-tools\.ps1/);
    assert.doesNotMatch(setup, /az login|terraform (?:plan|apply)|auto-approve/);
});

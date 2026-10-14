import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, copyFileSync, readFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("../", import.meta.url));
function powershell(source, t) {
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", source],
        { encoding: "utf8", timeout: 30000 });
    if (result.error?.code === "ENOENT") { t.skip("PowerShell 7.4+ is required."); return null; }
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
Write-Output 'PASS stable parameters and safe rejection'
`, t);
    if (!result) return;
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /PASS stable parameters and safe rejection/);
});

test("shared tool checks accept working tools and reject incompatible versions without Azure login", (t) => {
    const script = join(root, "scripts", "check-tools.ps1").replaceAll("'", "''");
    for (const compatible of [true, false]) {
        const result = powershell(`
function global:git { $global:LASTEXITCODE=0; 'git version 2.53.0' }
function global:az { if ($args[0] -ne 'version') { throw 'Unexpected Azure access.' }; $global:LASTEXITCODE=0; '{"azure-cli":"2.88.0"}' }
function global:terraform { $global:LASTEXITCODE=0; '{"terraform_version":"1.16.5"}' }
function global:dotnet { $global:LASTEXITCODE=0; '${compatible ? "10.0.402" : "9.0.319"} [synthetic]' }
function global:node { $global:LASTEXITCODE=0; 'v22.22.0' }
function global:func { $global:LASTEXITCODE=0; '4.14.0' }
& '${script}'
`, t);
        if (!result) return;
        if (compatible) {
            assert.equal(result.status, 0, result.stderr);
            assert.match(result.stdout, /PASS local tools only/);
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
    assert.match(parameters.resource_suffix, /^[a-f0-9]{10}$/);
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

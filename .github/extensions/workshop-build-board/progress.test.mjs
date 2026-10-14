import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, symlinkSync, existsSync, renameSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createProgressStore, parseProgress } from "./progress.mjs";
import { startServer } from "./server.mjs";
import { readJourney } from "./journey.mjs";

const ids = ["00", "01", "02", "03", "04", "05", "06", "07", "99"];
const repository = fileURLToPath(new URL("../../../", import.meta.url));
const fixture = "# Progress\n\n| Module | Title | Status | Validated on | Evidence | Notes |\n" +
    "|---|---|---|---|---|---|\n" +
    ids.map((id) => `| ${id} | Synthetic module ${id} | todo | | | Keep note |`).join("\n") +
    "\n\n## Open decisions\n- Synthetic decision.\n\n## Deviations from the build plan\nNone yet.\n";

test("client commands reject credential URLs and quote endpoint data without executing it", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function connectionCommands(");
    const end = html.indexOf("function validationCommands(", start);
    assert.ok(start > 0 && end > start);
    const prepare = new Function(`${html.slice(start, end)}; return connectionCommands;`)();
    for (const value of ["", "http://example.com/mcp", "javascript:alert(1)",
        "https://user:password@example.com/mcp", "https://example.com/mcp?code=synthetic",
        "https://example.com/mcp#", "https://example.com/mcp?", "https://example.com/a b"]) {
        assert.throws(() => prepare(value));
    }
    const endpoint = "https://workshop.example.com/mcp/'synthetic";
    const commands = prepare(endpoint);
    assert.equal(JSON.parse(commands.configuration).servers.workshop.url, endpoint);
    assert.ok(commands.powershell.includes(endpoint.replaceAll("'", "''")));
    assert.ok(commands.bash.includes(endpoint.replaceAll("'", "'\\''")));
    assert.match(commands.powershell, /MCP_INSPECTOR_SECRET_STORE = 'memory'/);
    assert.match(commands.powershell, /MCP_INSPECTOR_PERSIST_TOKENS = 'none'/);
    assert.match(commands.bash, /HOST=127\.0\.0\.1/);
    assert.doesNotMatch(commands.configuration, /headers|Authorization|token/);
});

function setup(t, content = fixture) {
    const root = mkdtempSync(join(tmpdir(), "workshop-board-test-"));
    mkdirSync(join(root, "docs"));
    const path = join(root, "docs", "PROGRESS.md");
    writeFileSync(path, content);
    writeFileSync(join(root, "docs", "BUILD-PLAN.md"), "# Plan\n\n" +
        ids.map((id) => `## ${id} - Synthetic module\n- **Build:** Synthetic outcome ${id}.\n`).join("\n") +
        "\n## Unrelated section\nNot a module outline.\n");
    writeFileSync(join(root, "docs", "COPILOT-RUNBOOK.md"), "# Synthetic runbook\n");
    writeFileSync(join(root, "docs", "sources.md"), "# Synthetic sources\n");
    writeFileSync(join(root, "docs", "PRACTICE.md"), "# Synthetic practice\n\n" +
        ids.map((id) => `## ${id} - Synthetic hint\nExplain boundary ${id}.\n`).join("\n") +
        "\n## Sources\nSynthetic reference.\n");
    writeFileSync(join(root, "docs", "LEARNING-GUIDE.md"), "# Synthetic governance\n\n" +
        ids.map((id) => `## ${id} - Synthetic boundary\n**Diagram:** Synthetic boundary ${id}.\n`).join("\n"));
    writeFileSync(join(root, "docs", "DEPLOYMENT.md"), "# Synthetic deployment context\n");
    writeFileSync(join(root, "docs", "GETTING-STARTED.md"), "# Synthetic workstation choices\n");
    writeFileSync(join(root, "docs", "HOSTING.md"), "# Synthetic static publication\n");
    mkdirSync(join(root, "docs", "fr"));
    for (const file of ["BUILD-PLAN.md", "PRACTICE.md", "LEARNING-GUIDE.md", "DEPLOYMENT.md", "COPILOT-RUNBOOK.md", "GETTING-STARTED.md", "HOSTING.md"]) {
        writeFileSync(join(root, "docs", "fr", file), readFileSync(join(root, "docs", file), "utf8").replaceAll("Synthetic module", "Module français"));
    }
    writeFileSync(join(root, "docs", "fr", "REFERENCES.md"), "# Références synthétiques\n");
    mkdirSync(join(root, "assets", "architecture"), { recursive: true });
    mkdirSync(join(root, "assets", "icons"));
    writeFileSync(join(root, "assets", "architecture", "README.md"), "# Synthetic diagrams\n");
    writeFileSync(join(root, "assets", "architecture", "README.fr.md"), "# Schémas synthétiques\n");
    writeFileSync(join(root, "assets", "architecture", "00.fr.svg"), '<svg xmlns="http://www.w3.org/2000/svg"/>');
    writeFileSync(join(root, "assets", "icons", "azure.svg"), '<svg xmlns="http://www.w3.org/2000/svg"/>');
    t.after(() => rmSync(root, { recursive: true }));
    const store = createProgressStore(root);
    return { store, path, root };
}

test("reads nine modules and only the decisions section", (t) => {
    const { store } = setup(t);
    assert.equal(store.read().modules.length, 9);
    assert.equal(store.read().openDecisions, "- Synthetic decision.");
});

test("updates only the selected row, preserving notes and CRLF", (t) => {
    const original = fixture.replaceAll("\n", "\r\n");
    const { store, path } = setup(t, original);
    store.update({ module: "00", status: "in-progress", evidence: "Synthetic evidence", revision: store.read().revision });
    assert.equal(readFileSync(path, "utf8"), original.replace(
        "| 00 | Synthetic module 00 | todo | | | Keep note |",
        "| 00 | Synthetic module 00 | in-progress |  | Synthetic evidence | Keep note |"));
});

test("notes and evidence persist after a new store reads the file", (t) => {
    const { store, path } = setup(t);
    const state = store.update({ module: "01", status: "blocked", evidence: "", notes: "Synthetic note", revision: store.read().revision });
    assert.equal(state.modules[1].notes, "Synthetic note");
    assert.equal(parseProgress(readFileSync(path, "utf8")).modules[1].status, "blocked");
});

test("rejects stale changes without modifying any bytes", (t) => {
    const { store, path } = setup(t);
    const old = store.read();
    writeFileSync(path, fixture + "\nExternal edit.\n");
    const content = readFileSync(path, "utf8");
    assert.throws(() => store.update({ module: "00", status: "blocked", evidence: "", revision: old.revision }),
        (error) => error.code === "stale_revision");
    assert.equal(readFileSync(path, "utf8"), content);
});

test("rejects malformed values, table injection, unknown properties and false validation", (t) => {
    const { store, path } = setup(t);
    const input = { module: "00", status: "todo", evidence: "", revision: store.read().revision };
    for (const change of [
        { module: "88" }, { status: "done" }, { revision: "x" }, { evidence: "a|b" },
        { notes: "a\nb" }, { evidence: null }, { path: "another-file" }, { status: "validated" },
        { status: "validated", evidence: "Synthetic PASS", validatedOn: "2026-02-30" },
        { status: "validated", evidence: "Synthetic PASS", validatedOn: "2026-13-01" },
        { status: "todo", validatedOn: "2026-10-14" },
    ]) assert.throws(() => store.update({ ...input, ...change }));
    assert.equal(readFileSync(path, "utf8"), fixture);
});

test("validation needs evidence and date, and downgrading clears the date", (t) => {
    const { store } = setup(t);
    let state = store.update({ module: "00", status: "validated", evidence: "Synthetic PASS fixture only",
        validatedOn: "2026-10-14", revision: store.read().revision });
    assert.equal(state.modules[0].validatedOn, "2026-10-14");
    state = store.update({ module: "00", status: "todo", evidence: "", revision: state.revision });
    assert.equal(state.modules[0].validatedOn, "");
});

test("rejects duplicate modules and missing decisions rather than returning defaults", () => {
    assert.throws(() => parseProgress(fixture.replace("| 99 |", "| 00 |")));
    assert.throws(() => parseProgress(fixture.replace("## Open decisions", "## Other section")));
});

test("journey distinguishes planned outlines from published participant guides without changing progress", (t) => {
    const { store, path, root } = setup(t);
    const original = readFileSync(path, "utf8");
    let journey = readJourney(root, store.read());
    assert.equal(journey.modules.length, 9);
    assert.equal(journey.modules[0].guide, null);
    assert.equal(journey.modules[0].sourcePath, "docs/BUILD-PLAN.md");
    assert.match(journey.modules[0].hints, /Explain boundary 00/);
    assert.equal(journey.modules[0].validation.powershell, null);
    assert.equal(journey.environment.devcontainer, null);
    assert.equal(journey.environment.preflight, null);
    assert.match(journey.modules[0].outline, /Synthetic outcome 00/);
    assert.doesNotMatch(journey.modules[8].outline, /Unrelated section/);
    const directory = join(root, "modules", "00-prerequisites");
    mkdirSync(directory, { recursive: true });
    writeFileSync(join(directory, "README.md"), "# Synthetic guide\n\n## Steps\n1. Run the synthetic check.\n");
    writeFileSync(join(directory, "validate.ps1"), "Write-Output 'Synthetic PASS'\n");
    journey = readJourney(root, store.read());
    assert.match(journey.modules[0].guide, /## Steps/);
    assert.equal(journey.modules[0].sourcePath, "modules/00-prerequisites/README.md");
    assert.equal(journey.modules[0].validation.powershell, "modules/00-prerequisites/validate.ps1");
    assert.equal(journey.modules[0].validation.bash, null);
    assert.match(journey.documents.runbook.content, /Synthetic runbook/);
    assert.match(journey.documents.sources.content, /Synthetic sources/);
    assert.match(journey.documents.practice.content, /Synthetic practice/);
    assert.equal(journey.translations.fr.modules[0].title, "Module français");
    assert.equal(journey.translations.fr.modules[0].originalGuide.sourcePath, "modules/00-prerequisites/README.md");
    assert.equal(journey.translations.fr.modules[0].guide, null);
    writeFileSync(join(directory, "README.fr.md"), "# Guide français synthétique\n");
    journey = readJourney(root, store.read());
    assert.equal(journey.translations.fr.modules[0].originalGuide, null);
    assert.match(journey.translations.fr.modules[0].guide, /Guide français/);
    assert.match(journey.translations.fr.modules[0].sourcePath, /README\.fr\.md$/);
    assert.equal(readFileSync(path, "utf8"), original);
});

test("French content cannot silently disappear or alter shared status", (t) => {
    const { store, root, path } = setup(t);
    const before = readFileSync(path);
    const journey = readJourney(root, store.read());
    assert.deepEqual(journey.modules.map((module) => module.status),
        journey.translations.fr.modules.map((module) => module.status));
    assert.equal(journey.translations.fr.modules[4].diagram.svg, "/assets/architecture/04.fr.svg");
    assert.match(journey.translations.fr.documents.sources.content, /Références/);
    assert.equal(journey.environment.context.powershell, null);
    assert.deepEqual(readFileSync(path), before);
    writeFileSync(join(root, "docs", "fr", "LEARNING-GUIDE.md"), "# Missing modules\n");
    assert.throws(() => readJourney(root, store.read()), (error) => error.code === "invalid_document");
});

test("only allowlisted public assets are served, with no API or private-file exposure", async (t) => {
    const { store, root } = setup(t);
    const entry = await startServer(store, () => readJourney(root, store.read()), join(root, "assets"));
    t.after(() => entry.close());
    for (const path of ["?lang=fr", "?lang=en", "locale-fr.js", "assets/icons/azure.svg", "assets/architecture/00.fr.svg"]) {
        const response = await fetch(entry.url + path);
        assert.equal(response.status, 200, path);
        assert.equal(response.headers.get("Cross-Origin-Resource-Policy"), "same-origin");
    }
    for (const path of ["assets/confidential/document.svg", "assets/icons/unknown.svg",
        "assets/architecture/88.fr.svg", "assets/architecture/00.de.svg",
        "assets/architecture/00.fr.svg?path=private", "assets/icons/%2e%2e%2fprivate.svg"]) {
        assert.equal((await fetch(entry.url + path)).status, 404, path);
    }
    assert.equal((await fetch(entry.url + "assets/architecture/00.en.svg")).status, 404);
    assert.equal((await fetch(entry.url + "journey")).status, 403);
    const outside = join(root, "outside");
    mkdirSync(outside);
    writeFileSync(join(outside, "00.fr.svg"), "Synthetic private fixture");
    renameSync(join(root, "assets", "architecture"), join(root, "assets", "architecture-original"));
    try { symlinkSync(outside, join(root, "assets", "architecture"), process.platform === "win32" ? "junction" : "dir"); }
    catch (error) {
        if (error.code !== "EPERM") throw error;
        t.diagnostic("Symlink rejection requires symlink permission; not available on this host.");
        return;
    }
    assert.equal((await fetch(entry.url + "assets/architecture/00.fr.svg")).status, 403);
});

test("practice refuses missing hints and gates script commands on a published guide", (t) => {
    const { store, root } = setup(t);
    const directory = join(root, "modules", "00-prerequisites");
    mkdirSync(directory, { recursive: true });
    writeFileSync(join(directory, "validate.ps1"), "Write-Output 'Synthetic PASS'\n");
    assert.equal(readJourney(root, store.read()).modules[0].validation.powershell, null);
    mkdirSync(join(root, ".devcontainer"));
    writeFileSync(join(root, ".devcontainer", "devcontainer.json"), "{}");
    mkdirSync(join(root, "scripts"));
    writeFileSync(join(root, "scripts", "preflight.ps1"), "Write-Output 'Synthetic PASS'\n");
    const journey = readJourney(root, store.read());
    assert.equal(journey.environment.devcontainer, ".devcontainer/devcontainer.json");
    assert.equal(journey.environment.preflight, "scripts/preflight.ps1");
    writeFileSync(join(root, "docs", "PRACTICE.md"), "# No hints\n");
    assert.throws(() => readJourney(root, store.read()), (error) => error.code === "invalid_document");
});

test("journey reports missing module outlines and documents instead of inventing content", (t) => {
    const { store, root } = setup(t);
    writeFileSync(join(root, "docs", "BUILD-PLAN.md"), "# No modules\n");
    assert.throws(() => readJourney(root, store.read()), (error) => error.code === "invalid_document");
    rmSync(join(root, "docs", "BUILD-PLAN.md"));
    assert.throws(() => readJourney(root, store.read()), (error) => error.code === "ENOENT");
});

test("loopback server protects reads and writes and returns explicit errors", async (t) => {
    const { store, root } = setup(t);
    const entry = await startServer(store, () => readJourney(root, store.read()));
    t.after(() => entry.close());
    const html = await (await fetch(entry.url)).text();
    assert.match(html, /Workshop build board/);
    assert.doesNotMatch(html, /<form\b|<input\b|<select\b|<textarea\b/i);
    const key = html.match(/const key = "([A-Za-z0-9_-]+)"/)[1];
    assert.equal((await fetch(`${entry.url}progress`)).status, 403);
    const headers = { "x-board-key": key, "Content-Type": "application/json" };
    assert.equal((await fetch(`${entry.url}journey`)).status, 403);
    assert.equal((await fetch(`${entry.url}journey`, { headers: { ...headers, Origin: "https://example.com" } })).status, 403);
    const journey = await (await fetch(`${entry.url}journey`, { headers })).json();
    assert.equal(journey.modules[0].guide, null);
    assert.match(journey.documents.sources.content, /Synthetic sources/);
    assert.equal((await fetch(`${entry.url}progress`, { headers: { ...headers, Origin: "https://example.com" } })).status, 403);
    const state = await (await fetch(`${entry.url}progress`, { headers })).json();
    assert.equal(state.modules.length, 9);
    const input = { module: "00", status: "in-progress", evidence: "", notes: "Synthetic note", revision: state.revision };
    const saved = await fetch(`${entry.url}update`, { method: "POST", headers, body: JSON.stringify(input) });
    assert.equal(saved.status, 200);
    assert.equal((await saved.json()).modules[0].notes, "Synthetic note");
    const stale = await fetch(`${entry.url}update`, { method: "POST", headers, body: JSON.stringify(input) });
    assert.equal(stale.status, 409);
    assert.equal((await stale.json()).code, "stale_revision");
    assert.equal((await fetch(`${entry.url}update`, { method: "POST", headers, body: "{" })).status, 400);
    assert.equal((await fetch(`${entry.url}unknown`, { headers })).status, 404);
});

test("PowerShell context selection uses mocked Azure only and refuses unsafe or mismatched contexts", (t) => {
    const script = join(repository, "scripts", "select-azure-context.ps1").replaceAll("'", "''");
    const environment = Object.fromEntries(Object.entries(process.env).filter(([name]) => !/^(ARM_|AZURE_)/i.test(name)));
    const source = `
$global:tenant = [guid]::NewGuid().ToString()
$global:subscription = [guid]::NewGuid().ToString()
$global:signIns = 0
$global:answers = [Collections.Generic.Queue[string]]::new()
$global:answers.Enqueue($(if ($env:TEST_MODE -eq 'invalid') { 'invalid' } else { $global:tenant }))
$global:answers.Enqueue($global:subscription)
$global:answers.Enqueue($(if ($env:TEST_MODE -eq 'cancel') { 'NO' } else { 'NONPROD' }))
function global:Read-Host { $global:answers.Dequeue() }
function global:az {
  $global:LASTEXITCODE = 0
  if ($args[0] -eq 'cloud') { 'AzureCloud'; return }
  if ($args[0] -eq 'login') {
    $global:signIns++
    if ($env:TEST_MODE -eq 'login-fail') { $global:LASTEXITCODE = 1 }
    return
  }
  if ($args[0] -eq 'account' -and $args[1] -eq 'set') { return }
  if ($args[0] -eq 'account' -and $args[1] -eq 'show') {
    @{tenant=$(if ($env:TEST_MODE -eq 'mismatch') { [guid]::NewGuid().ToString() } else { $global:tenant })
      subscription=$global:subscription; state=$(if ($env:TEST_MODE -eq 'disabled') { 'Disabled' } else { 'Enabled' })} | ConvertTo-Json
    return
  }
  throw 'Unexpected Azure command in context selector.'
}
if ($env:TEST_MODE -eq 'override') { $env:ARM_CLIENT_SECRET = 'synthetic-fixture-only' }
try {
  & '${script}' -Language fr
  if ($env:TEST_MODE -ne 'match') { throw 'Expected rejection did not happen.' }
  if ($env:ARM_TENANT_ID -ne $global:tenant -or $env:ARM_SUBSCRIPTION_ID -ne $global:subscription) {
    throw 'Context was not exported in the current PowerShell process.'
  }
  Write-Output 'PASS matched target'
} catch {
  if ($env:TEST_MODE -eq 'match' -or $_.Exception.Message -eq 'Expected rejection did not happen.') { throw }
  if ($env:ARM_TENANT_ID -or $env:ARM_SUBSCRIPTION_ID) { throw 'Failed selection must not export a target.' }
  if ($env:TEST_MODE -in @('cancel', 'invalid', 'override') -and $global:signIns -ne 0) {
    throw 'Sign-in ran before validation and approval.'
  }
  Write-Output 'PASS rejected unsafe context'
}`;
    for (const mode of ["match", "cancel", "invalid", "override", "mismatch", "disabled", "login-fail"]) {
        const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", source],
            { env: { ...environment, TEST_MODE: mode }, encoding: "utf8", timeout: 30000 });
        if (result.error?.code === "ENOENT") { t.skip("PowerShell 7 is not installed."); return; }
        assert.equal(result.status, 0, `${mode}: ${result.stderr}`);
        assert.match(result.stdout, mode === "match" ? /PASS matched target/ : /PASS rejected unsafe context/);
    }
});

test("bash context selection preserves the current shell and refuses unsafe or mismatched contexts", (t) => {
    const bash = process.platform === "win32" ? "C:\\Program Files\\Git\\bin\\bash.exe" : "bash";
    if (process.platform === "win32" && !existsSync(bash)) { t.skip("Git bash is not installed."); return; }
    const environment = Object.fromEntries(Object.entries(process.env).filter(([name]) => !/^(ARM_|AZURE_)/i.test(name)));
    const source = `
az() {
  case "$1 $2" in
    'cloud show') printf '%s\\n' AzureCloud ;;
    'login --tenant') [[ "$TEST_MODE" != login-fail ]] ;;
    'account set') return 0 ;;
    'account show')
      if [[ "$TEST_MODE" == mismatch ]]; then
        printf '%s|%s|Enabled\\n' "$TEST_SUBSCRIPTION" "$TEST_SUBSCRIPTION"
      elif [[ "$TEST_MODE" == disabled ]]; then
        printf '%s|%s|Disabled\\n' "$TEST_SUBSCRIPTION" "$TEST_TENANT"
      else
        printf '%s|%s|Enabled\\n' "$TEST_SUBSCRIPTION" "$TEST_TENANT"
      fi ;;
    *) printf '%s\\n' 'Unexpected Azure command' >&2; return 1 ;;
  esac
}
if [[ "$TEST_MODE" == override ]]; then export ARM_CLIENT_SECRET=synthetic-fixture-only; fi
if source ./scripts/select-azure-context.sh fr; then
  [[ "$TEST_MODE" == match && "$ARM_TENANT_ID" == "$TEST_TENANT" &&
    "$ARM_SUBSCRIPTION_ID" == "$TEST_SUBSCRIPTION" ]] || exit 1
  printf '%s\\n' 'PASS matched target'
else
  [[ "$TEST_MODE" != match && -z "\${ARM_TENANT_ID:-}" && -z "\${ARM_SUBSCRIPTION_ID:-}" ]] || exit 1
  printf '%s\\n' 'PASS rejected unsafe context'
fi`;
    for (const mode of ["match", "cancel", "invalid", "override", "mismatch", "disabled", "login-fail"]) {
        const tenant = randomUUID(), subscription = randomUUID();
        const result = spawnSync(bash, ["--noprofile", "--norc", "-c", source], {
            cwd: repository, encoding: "utf8", timeout: 30000,
            env: { ...environment, TEST_MODE: mode, TEST_TENANT: tenant, TEST_SUBSCRIPTION: subscription },
            input: `${mode === "invalid" ? "invalid" : tenant}\n${subscription}\n${mode === "cancel" ? "NO" : "NONPROD"}\n`,
        });

        if (result.error?.code === "ENOENT") { t.skip("bash is not installed."); return; }
        assert.equal(result.status, 0, `${mode}: ${result.stderr}`);
        assert.match(result.stdout, mode === "match" ? /PASS matched target/ : /PASS rejected unsafe context/);
    }
});

test("editable architecture, SVGs and PNG source provenance remain synchronized", (t) => {
    const result = spawnSync(process.platform === "win32" ? "python" : "python3",
        [join(repository, "scripts", "render-architecture.py"), "--check"],
        { cwd: repository, encoding: "utf8", timeout: 30000 });
    if (result.error?.code === "ENOENT") { t.skip("Python 3 is required for architecture authoring checks."); return; }
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout.match(/^PASS /gm)?.length, 18);
});

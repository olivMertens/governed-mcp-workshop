import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, existsSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync, execFileSync } from "node:child_process";
import { gzipSync } from "node:zlib";
import { readScaffoldFiles, synchronizeScaffold } from "./sync-scaffold.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const quote = (value) => value.replaceAll("'", "''");
const mocks = `
$ErrorActionPreference='Stop'
function global:az { throw 'Setup must not call Azure.' }
function global:gh { throw 'Local setup must not call GitHub.' }
function global:git {
    $global:LASTEXITCODE=0
    if(($args -join ' ') -eq 'config --get user.name'){return 'Synthetic Workshop'}
    if(($args -join ' ') -eq 'config --get user.email'){return 'synthetic@example.invalid'}
    if($args[0] -in @('init','commit','-c')){return}
    throw 'Unexpected Git command.'
}
`;

test("standalone scaffold covers every tracked source with an enforced drift gate", () => {
    synchronizeScaffold(root, true);
    const files = readScaffoldFiles(root);
    for (const path of ["modules/07-clients/cleanup.ps1", "modules/06-observe-inventory/validate.ps1",
        "scripts/deploy-module.ps1", "scripts/script-hardening.test.mjs", "scripts/sync-scaffold.mjs"]) {
        assert.ok(files[path], `Missing standalone file: ${path}`);
    }
    assert.ok(Object.keys(files).length > 350);
    assert.doesNotMatch(Object.keys(files).join("\n"), /(^|\n)(?:\.workshop|\.azure|\.terraform)\//);
});

test("the scaffold drift gate detects a tracked source edit without publishing or committing", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-scaffold-drift-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    writeFileSync(join(directory, "setup-workshop-mcp.ps1"), "# --- 3. Embedded scaffold ---\n# --- 4. Git and GitHub ---\n");
    writeFileSync(join(directory, "sample.txt"), "synthetic source\n");
    execFileSync("git", ["init", "--quiet"], { cwd: directory });
    execFileSync("git", ["add", "--", "setup-workshop-mcp.ps1", "sample.txt"], { cwd: directory });
    synchronizeScaffold(directory);
    synchronizeScaffold(directory, true);
    writeFileSync(join(directory, "sample.txt"), "updated synthetic source\n");
    assert.throws(() => synchronizeScaffold(directory, true), /Scaffold is stale/);
});

test("standalone setup exports exact text and binary content, rejects nonempty destinations and never calls Azure", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-scaffold-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const destination = join(directory, "copy");
    const script = join(root, "setup-workshop-mcp.ps1");
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", `${mocks}
& '${quote(script)}' -Path '${quote(destination)}' -SkipGitHub
$failed=$false
try{& '${quote(script)}' -Path '${quote(destination)}' -SkipGitHub}catch{$failed=$true}
if(-not $failed){throw 'Existing destination was overwritten.'}
`], { encoding: "utf8", timeout: 120000, maxBuffer: 1024 * 1024 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr + result.stdout);
    for (const [path, bytes] of Object.entries(readScaffoldFiles(root))) {
        assert.deepEqual(readFileSync(join(destination, path)), Buffer.from(bytes, "base64"), path);
    }
    assert.deepEqual(readFileSync(join(destination, "setup-workshop-mcp.ps1")), readFileSync(script));
    assert.equal(existsSync(join(destination, ".workshop")), false);
});

test("standalone setup rejects traversal and absolute paths in its embedded manifest", (t) => {
    const directory = mkdtempSync(join(tmpdir(), "workshop-scaffold-paths-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const source = readFileSync(join(root, "setup-workshop-mcp.ps1"), "utf8");
    for (const [index, path] of ["../escape.txt", "/absolute.txt", "C:\\escape.txt"].entries()) {
        const payload = gzipSync(Buffer.from(JSON.stringify({ [path]: Buffer.from("synthetic").toString("base64") }))).toString("base64");
        const script = join(directory, `unsafe-${index}.ps1`);
        writeFileSync(script, source.replace(/\$scaffoldGzip = '[^']*'/, `$scaffoldGzip = '${payload}'`));
        const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", `${mocks}
$failed=$false
try{& '${quote(script)}' -Path '${quote(join(directory, `destination-${index}`))}' -SkipGitHub}
catch{if($_.Exception.Message -notmatch 'Invalid embedded file path'){throw};$failed=$true}
if(-not $failed){throw 'Unsafe manifest was accepted.'}
`], { encoding: "utf8", timeout: 30000 });
        assert.ifError(result.error);
        assert.equal(result.status, 0, result.stderr + result.stdout);
    }
    assert.equal(existsSync(join(directory, "escape.txt")), false);
});

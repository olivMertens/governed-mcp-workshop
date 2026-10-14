<#
.SYNOPSIS
    Create the workshop scaffold locally and optionally publish it on GitHub.

.DESCRIPTION
    Requires an empty destination. Embedded files include the source assessment
    and project build board. Uses a local GitHub noreply identity for publication.
    Does not create or change Azure or Microsoft Entra resources.

.EXAMPLE
    .\setup-workshop-mcp.ps1

.EXAMPLE
    .\setup-workshop-mcp.ps1 -Visibility private

.EXAMPLE
    .\setup-workshop-mcp.ps1 -Path D:\src\workshop-mcp -SkipGitHub
#>
[CmdletBinding()]
param(
    [string]$Path = 'C:\github\workshop-mcp',
    [string]$RepoName = 'workshop-mcp',
    [ValidateSet('public', 'private')]
    [string]$Visibility = 'public',
    [string]$Description = 'Hands-on workshop: take an MCP server from open to governed on Azure (Microsoft Entra ID, API Management, On-Behalf-Of, observability). Built with the GitHub Copilot app.',
    [switch]$SkipGitHub,
    [switch]$OpenVSCode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$Arguments = @(),
        [switch]$AllowFailure,
        [switch]$Quiet
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($Quiet) { & $Exe @Arguments *> $null } else { & $Exe @Arguments | Out-Host }
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "Command '$Exe' failed (exit code $code)."
    }
    return $code
}

function Get-NativeOutput {
    param([Parameter(Mandatory)][string]$Exe, [string[]]$Arguments = @(), [switch]$AllowFailure)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = & $Exe @Arguments 2> $null; $code = $LASTEXITCODE } finally { $ErrorActionPreference = $previous }
    if ($code -ne 0 -and -not $AllowFailure) { throw "Command '$Exe' failed (exit code $code)." }
    if ($null -eq $out) { return '' }
    return ($out | Out-String).Trim()
}

# --- 1. Prerequisites ----------------------------------------------------------
Write-Step 'Checking prerequisites'
if (-not (Test-Command 'git')) {
    throw 'Git is missing. Run winget install --id Git.Git -e, reopen the terminal, and retry.'
}
if (-not (Get-NativeOutput git @('config', '--get', 'user.name') -AllowFailure) -or -not (Get-NativeOutput git @('config', '--get', 'user.email') -AllowFailure)) {
    throw 'Git identity is missing. Configure user.name and a suitable user.email, then retry. Publication uses repository-local GitHub noreply identity.'
}
Write-Host '   Git : OK'

$owner = ''
$ownerId = ''
if ($RepoName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'RepoName must be a valid repository name, without an owner or path.' }
if (Test-Path -LiteralPath $Path) {
    if (Get-ChildItem -LiteralPath $Path -Force | Select-Object -First 1) {
        throw "Destination $Path is not empty. Use a new empty destination; do not overwrite an existing workshop."
    }
}
if (-not $SkipGitHub) {
    if (-not (Test-Command 'gh')) {
        throw 'GitHub CLI is missing. Run winget install --id GitHub.cli -e, reopen the terminal, and retry. Use -SkipGitHub for local-only setup.'
    }
    if ((Invoke-Native gh @('auth', 'status') -AllowFailure -Quiet) -ne 0) {
        Write-Step 'Signing in to GitHub (browser)'
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { & gh auth login --hostname github.com --git-protocol https --web; $loginCode = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previous }
        if ($loginCode -ne 0) { throw 'GitHub sign-in failed or was cancelled. Run gh auth login, then retry.' }
    }
    $owner = Get-NativeOutput gh @('api', 'user', '--jq', '.login')
    $ownerId = Get-NativeOutput gh @('api', 'user', '--jq', '.id')
    if (-not $owner -or $ownerId -notmatch '^\d+$') { throw 'Could not read the GitHub account. Check gh auth status.' }
    Write-Host "   GitHub CLI: OK ($owner)"
    $remoteCheck = Get-NativeOutput gh @('api', "repos/$owner/$RepoName", '--include') -AllowFailure
    if ($remoteCheck -match '(?m)^HTTP/\S+\s+200\b') {
        throw "Repository $owner/$RepoName already exists. Choose another RepoName; the existing repository will not be changed."
    }
    if ($remoteCheck -notmatch '(?m)^HTTP/\S+\s+404\b') {
        throw 'Could not confirm the remote repository is absent. Resolve network or permission errors before retrying.'
    }
}

# --- 2. Destination ------------------------------------------------------------
Write-Step "Preparing $Path"
if (Test-Path -LiteralPath $Path) {
    if (Get-ChildItem -LiteralPath $Path -Force | Select-Object -First 1) {
        throw "Destination $Path is not empty. Choose a new empty Path."
    }
}
else {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}
$Path = (Resolve-Path -LiteralPath $Path).ProviderPath

# --- 3. Embedded scaffold ------------------------------------------------------
Write-Step 'Writing the workshop scaffold'
$files = [ordered]@{}
$files['.gitattributes'] = @'
* text=auto
*.sh text eol=lf
*.ps1 text eol=crlf
'@

$files['.github/agents/workshop-builder.agent.md'] = @'
---
name: workshop-builder
description: Builds the "Governed MCP on Azure" workshop one module at a time (Terraform, Azure Functions .NET, Azure API Management, Microsoft Entra ID), deploys to a test subscription only after approval, and proves each module with its validation script.
---

You build this repository's workshop, one module per session, with the workshop-module-builder skill.

- Treat `.github/copilot-instructions.md` as non-negotiable, especially the nine security invariants.
- Follow `docs/BUILD-PLAN.md` for what to take, build and show. Keep `docs/PROGRESS.md` up to date.
- Read the official sources of a module before writing its code.
- Show the Terraform plan and the Microsoft Entra changes, and wait for approval, before changing anything in Azure or Entra.
- A module is done only when its `validate.ps1` passes. Report the PASS lines as evidence.
- Keep the content generic, in English, with synthetic data and no secrets.
'@

$files['.github/copilot-instructions.md'] = @'
# Copilot instructions — Governed MCP on Azure (hands-on workshop)

## Purpose
This repository is a self-paced, end-to-end workshop that takes one MCP server from "open" to "governed" on Azure:
open server → Microsoft Entra authentication → Azure API Management as the only entry point →
delegated (On-Behalf-Of) vs app-only access → observability and inventory.
Audience: enterprise platform, identity and Microsoft 365 administrators (PowerShell, C#, Terraform)
plus a few developers, most of them new to agents and MCP.
Goal: every participant can deploy, verify and destroy every module alone, in a non-production Azure subscription.
Build order, sources and expected results are in docs/BUILD-PLAN.md. Read it before any task.

## Content rules
- Public repository: generic content only. No customer or employer names, no internal or confidential material,
  no tenant/subscription IDs, no real user data, no secrets. Synthetic data only; personas are Alice, Bob and Eve (Contoso).
- English, plain language, short sentences. Define every acronym on first use.
- Reuse official samples and documentation instead of reinventing them. Pin versions or commit SHAs,
  keep upstream license notices, link the origin.
- Before writing code for a module, read the official pages listed for it. If they contradict this file,
  follow the docs and explain the gap in the pull request.
- Mark every preview feature "Preview" where it is used. Never present preview behaviour as generally available.
- Every module README ends with "Sources": links plus a "last verified" date.

## Security invariants — never weaken them, not even to make a test pass
1. One token per hop, one audience per token. The MCP server accepts only tokens issued for its own audience.
2. Never forward a client token to a downstream API (no token passthrough). Downstream calls use On-Behalf-Of
   (user context) or a managed identity (app-only). The choice is made per tool and documented.
3. Validate issuer, tenant, audience and expiry, then scope (scp) and/or role (roles), using platform features
   (Functions/App Service built-in authentication, APIM validate-azure-ad-token) or Microsoft.Identity.Web.
   Never hand-write JWT validation.
4. Scopes say what the client app may do for the user; app roles say what this user or app may do.
   Per-user authorization uses app roles.
5. No secrets: managed identities and federated identity credentials only. Nothing secret in code, mcp.json,
   scripts, tfvars or Terraform state committed to git.
6. Write tools require an explicit role and human approval in the client.
7. Logs never contain tokens, prompts, tool arguments or tool results (zero body bytes).
   Log tool name, caller object ID, status, latency and correlation ID.
8. Least privilege: role assignments scoped to the exact resource or resource group, time-bound where possible.
9. The "open" level (module 02) exists only to show the risk: function key, short-lived, optional IP allow-list.
   Never leave an anonymous MCP endpoint on the internet.

## Stack and conventions
- IaC: Terraform with azurerm, azuread and azapi (azapi for resources or API versions not yet in azurerm,
  e.g. API Management MCP servers with api-version 2025-09-01-preview).
  Two root modules: infra/entra (run once by an identity administrator, or skipped by passing existing IDs)
  and infra/workload.
- MCP server: Azure Functions (.NET, MCP extension), patterns from Azure-Samples/remote-mcp-functions-dotnet.
- Gateway: Azure API Management v2 tier. Do not use the preview AI Gateway tier in the core path.
- Scripts: PowerShell 7 first (preflight, deploy, validate, cleanup), bash equivalents second.
  Idempotent, fail fast, clear messages.
- Environment: .devcontainer (also used by Codespaces) and Azure Cloud Shell instructions;
  corporate laptops may block local tools.
- Naming: deterministic names from a participant prefix (p01, p02…) and a suffix, so URLs are known
  before deployment. Tag everything: workshop, owner, expiry.

## Module contract (modules/NN-name/)
README sections in this order: Goal · Why it matters · What you deploy · Prerequisites and required roles ·
Steps (PowerShell, then bash) · What you should see · Validate · Troubleshooting · Clean up · Go further · Sources.
Files: infra/ (if any), validate.ps1 and validate.sh (one PASS/FAIL line per check with the expected HTTP status),
cleanup script. A module is done only when its validate script passes on a fresh subscription
right after the previous modules.

## When helping a participant
Explain simply and point to the module's sources. Never suggest disabling a control, widening a role,
using a client secret, or pasting a token into chat or a file as a workaround.
'@

$files['.github/extensions/workshop-build-board/board.html'] = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Workshop build board</title>
  <style>
    body { margin: 0; padding: 24px; background: var(--background-color-default, #fff); color: var(--text-color-default, #1f2328); font-family: var(--font-sans, system-ui); font-size: var(--text-body-medium, 14px); line-height: 1.5; }
    h1 { font-size: var(--text-title-large, 26px); margin: 0; }
    .muted { color: var(--text-color-muted, #59636e); }
    #modules { display: grid; grid-template-columns: repeat(auto-fit, minmax(270px, 1fr)); gap: 16px; }
    article { border: 1px solid var(--border-color-default, #d1d9e0); border-radius: 12px; padding: 16px; }
    label { display: block; margin-top: 12px; }
    input, select, textarea, button { box-sizing: border-box; font: inherit; color: inherit; background: var(--background-color-default, #fff); border: 1px solid var(--border-color-default, #d1d9e0); border-radius: 6px; padding: 8px; }
    input, select, textarea { width: 100%; }
    textarea { resize: vertical; }
    button { cursor: pointer; margin-top: 12px; }
    button:disabled { cursor: wait; opacity: .6; }
    :focus-visible { outline: 2px solid var(--color-focus-outline, #0969da); outline-offset: 2px; }
    #message { min-height: 24px; white-space: pre-wrap; }
    #message.error { color: var(--true-color-red, #b42318); }
    #decisions { white-space: pre-wrap; }
  </style>
</head>
<body>
  <h1>Workshop build board</h1>
  <p class="muted">Preview: Copilot extension canvas API. Progress is stored only in docs/PROGRESS.md.</p>
  <p>A validated status requires the module's actual PASS evidence on a fresh test subscription. Saving here does not run validation. Never enter tokens, real identifiers, or confidential notes.</p>
  <button id="refresh" type="button">Refresh progress</button>
  <p id="message" role="status" aria-live="polite"></p>
  <main id="modules"></main>
  <h2>Open decisions</h2>
  <div id="decisions"></div>
  <script>
    const key = "__BOARD_KEY__";
    const message = document.getElementById("message");
    const statuses = ["todo", "in-progress", "validated", "blocked"];
    let saving = false;
    async function request(path, input) {
      const response = await fetch(path, {
        method: input ? "POST" : "GET",
        headers: { "x-board-key": key, ...(input ? { "Content-Type": "application/json" } : {}) },
        ...(input ? { body: JSON.stringify(input) } : {})
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error);
      return result;
    }
    function notify(text, error = false) {
      message.className = error ? "error" : "";
      message.textContent = text;
    }
    function field(form, title, tag, value) {
      const label = document.createElement("label");
      label.textContent = title;
      const control = document.createElement(tag);
      control.value = value;
      label.append(control);
      form.append(label);
      return control;
    }
    function render(state) {
      const list = document.getElementById("modules");
      list.replaceChildren();
      document.getElementById("decisions").textContent = state.openDecisions;
      for (const module of state.modules) {
        const card = document.createElement("article");
        const heading = document.createElement("h2");
        heading.textContent = `${module.module} - ${module.title}`;
        card.append(heading);
        const form = document.createElement("form");
        const status = field(form, "Status", "select", "");
        for (const value of statuses) {
          const option = document.createElement("option");
          option.value = option.textContent = value;
          status.append(option);
        }
        status.value = module.status;
        const date = field(form, "Validated on (only when validated)", "input", module.validatedOn);
        date.type = "date";
        const evidence = field(form, "Evidence (one line, no pipe character)", "input", module.evidence);
        evidence.maxLength = 2000;
        const notes = field(form, "Notes (one line, no pipe character)", "textarea", module.notes);
        notes.maxLength = 2000;
        const save = document.createElement("button");
        save.type = "submit";
        save.textContent = "Save module";
        form.append(save);
        form.addEventListener("submit", async (event) => {
          event.preventDefault();
          if (saving) return;
          saving = true;
          save.disabled = true;
          try {
            const input = { module: module.module, status: status.value, evidence: evidence.value,
              notes: notes.value, revision: state.revision };
            if (status.value === "validated") input.validatedOn = date.value;
            const updated = await request("/update", input);
            render(updated);
            notify(`Module ${module.module} saved to PROGRESS.md.`);
          } catch (error) {
            notify(error.message, true);
          } finally {
            saving = false;
            save.disabled = false;
          }
        });
        card.append(form);
        list.append(card);
      }
    }
    async function refresh() {
      if (saving) return;
      try {
        render(await request("/progress"));
        notify("Progress loaded. Refresh discards unsaved form edits.");
      } catch (error) {
        notify(error.message, true);
      }
    }
    document.getElementById("refresh").addEventListener("click", refresh);
    refresh();
  </script>
</body>
</html>
'@

$files['.github/extensions/workshop-build-board/extension.mjs'] = @'
import { fileURLToPath } from "node:url";
import { joinSession, createCanvas, CanvasError } from "@github/copilot-sdk/extension";
import { createProgressStore, BoardError, updateSchema } from "./progress.mjs";
import { startServer } from "./server.mjs";

const store = createProgressStore(fileURLToPath(new URL("../../../", import.meta.url)));
const servers = new Map();

function action(handler) {
    return (ctx) => {
        try {
            return handler(ctx.input);
        } catch (error) {
            if (error instanceof BoardError) throw new CanvasError(error.code, error.message);
            throw error;
        }
    };
}

await joinSession({
    canvases: [
        createCanvas({
            id: "workshop-build-board",
            displayName: "Workshop build board",
            description: "Read workshop progress and decisions; edit module status, evidence, and notes in PROGRESS.md.",
            inputSchema: { type: "object", properties: {}, additionalProperties: false },
            actions: [
                {
                    name: "get_progress",
                    description: "Read modules, open decisions, and the revision required for an update.",
                    inputSchema: { type: "object", properties: {}, additionalProperties: false },
                    handler: action(() => store.read()),
                },
                {
                    name: "set_module_status",
                    description: "Update a module using the last read revision. Validated needs actual evidence and a date.",
                    inputSchema: updateSchema,
                    handler: action((input) => store.update(input)),
                },
                {
                    name: "list_open_decisions",
                    description: "Read the Open decisions section from PROGRESS.md.",
                    inputSchema: { type: "object", properties: {}, additionalProperties: false },
                    handler: action(() => ({ openDecisions: store.read().openDecisions })),
                },
            ],
            open: async (ctx) => {
                store.read();
                let entry = servers.get(ctx.instanceId);
                if (!entry) {
                    entry = await startServer(store);
                    servers.set(ctx.instanceId, entry);
                }
                return { title: "Workshop build board", url: entry.url };
            },
            onClose: async (ctx) => {
                const entry = servers.get(ctx.instanceId);
                if (entry) {
                    servers.delete(ctx.instanceId);
                    await entry.close();
                }
            },
        }),
    ],
});
'@

$files['.github/extensions/workshop-build-board/progress.mjs'] = @'
import { createHash } from "node:crypto";
import { lstatSync, readFileSync, openSync, writeSync, ftruncateSync, fsyncSync, closeSync } from "node:fs";
import { join } from "node:path";

export const statuses = ["todo", "in-progress", "validated", "blocked"];
const moduleIds = ["00", "01", "02", "03", "04", "05", "06", "07", "99"];

export class BoardError extends Error {
    constructor(code, message, status = 400) {
        super(message);
        this.code = code;
        this.status = status;
    }
}

export const updateSchema = {
    type: "object",
    additionalProperties: false,
    required: ["module", "status", "evidence", "revision"],
    properties: {
        module: { type: "string", enum: moduleIds },
        status: { type: "string", enum: statuses },
        evidence: { type: "string", maxLength: 2000 },
        notes: { type: "string", maxLength: 2000 },
        validatedOn: { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" },
        revision: { type: "string", pattern: "^[a-f0-9]{64}$" },
    },
};

function revision(content) {
    return createHash("sha256").update(content).digest("hex");
}

export function parseProgress(content) {
    const lines = content.split(/\r?\n/);
    const modules = [];
    for (const [line, text] of lines.entries()) {
        if (!/^\|\s*\d{2}\s*\|/.test(text)) continue;
        const cells = text.split("|").slice(1, -1).map((cell) => cell.trim());
        if (cells.length !== 6 || !moduleIds.includes(cells[0]) || !statuses.includes(cells[2])) {
            throw new BoardError("invalid_progress", "Invalid module table in PROGRESS.md.");
        }
        modules.push({
            module: cells[0], title: cells[1], status: cells[2], validatedOn: cells[3],
            evidence: cells[4], notes: cells[5], line,
        });
    }
    if (modules.length !== moduleIds.length || new Set(modules.map((m) => m.module)).size !== moduleIds.length) {
        throw new BoardError("invalid_progress", "PROGRESS.md must contain each workshop module exactly once.");
    }
    const heading = lines.indexOf("## Open decisions");
    if (heading < 0) throw new BoardError("invalid_progress", "The Open decisions section is missing.");
    let end = lines.findIndex((line, index) => index > heading && line.startsWith("## "));
    if (end < 0) end = lines.length;
    return {
        revision: revision(content),
        modules: modules.map(({ line, ...module }) => module),
        openDecisions: lines.slice(heading + 1, end).join("\n").trim(),
        lines,
        rowLines: new Map(modules.map((m) => [m.module, m.line])),
    };
}

function validateUpdate(input) {
    if (!input || typeof input !== "object" || Array.isArray(input)) {
        throw new BoardError("invalid_input", "An update object is required.");
    }
    if (Object.keys(input).some((key) => !Object.hasOwn(updateSchema.properties, key))) {
        throw new BoardError("invalid_input", "Unknown update property.");
    }
    if (!moduleIds.includes(input.module) || !statuses.includes(input.status) ||
        typeof input.revision !== "string" || !/^[a-f0-9]{64}$/.test(input.revision)) {
        throw new BoardError("invalid_input", "A known module, status, and revision are required.");
    }
    for (const key of ["evidence", "notes"]) {
        if (key === "notes" && input.notes === undefined) continue;
        if (typeof input[key] !== "string" || input[key].length > 2000 || /[|\r\n\u0000-\u001f]/.test(input[key])) {
            throw new BoardError("invalid_input", `${key} must be a single table cell, without pipes or control characters.`);
        }
    }
    const timestamp = Date.parse(`${input.validatedOn}T00:00:00Z`);
    if (input.validatedOn !== undefined &&
        (typeof input.validatedOn !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(input.validatedOn) ||
        Number.isNaN(timestamp) || new Date(timestamp).toISOString().slice(0, 10) !== input.validatedOn)) {
        throw new BoardError("invalid_input", "validatedOn must be a real YYYY-MM-DD date.");
    }
    if (input.status === "validated" && (!input.evidence.trim() || !input.validatedOn)) {
        throw new BoardError("missing_evidence", "Validated requires actual module validation evidence and validatedOn.");
    }
    if (input.status !== "validated" && input.validatedOn !== undefined) {
        throw new BoardError("invalid_input", "Only a validated module can have a validation date.");
    }
}

export function createProgressStore(root) {
    const path = join(root, "docs", "PROGRESS.md");
    function load() {
        if (!lstatSync(path).isFile() || lstatSync(path).isSymbolicLink()) {
            throw new BoardError("invalid_progress", "PROGRESS.md must be a regular file.");
        }
        return readFileSync(path, "utf8");
    }
    function read() {
        const { lines, rowLines, ...state } = parseProgress(load());
        return state;
    }
    function update(input) {
        validateUpdate(input);
        const content = load();
        const parsed = parseProgress(content);
        if (parsed.revision !== input.revision) {
            throw new BoardError("stale_revision", "PROGRESS.md changed. Refresh before saving.", 409);
        }
        const module = parsed.modules.find((m) => m.module === input.module);
        const notes = input.notes === undefined ? module.notes : input.notes.trim();
        const date = input.status === "validated" ? input.validatedOn : "";
        parsed.lines[parsed.rowLines.get(input.module)] =
            `| ${module.module} | ${module.title} | ${input.status} | ${date} | ${input.evidence.trim()} | ${notes} |`;
        const updated = parsed.lines.join(content.includes("\r\n") ? "\r\n" : "\n");
        const fd = openSync(path, "r+");
        try {
            if (revision(readFileSync(fd, "utf8")) !== input.revision) {
                throw new BoardError("stale_revision", "PROGRESS.md changed. Refresh before saving.", 409);
            }
            const bytes = Buffer.from(updated);
            let written = 0;
            while (written < bytes.length) written += writeSync(fd, bytes, written, bytes.length - written, written);
            ftruncateSync(fd, bytes.length);
            fsyncSync(fd);
        } finally {
            closeSync(fd);
        }
        return read();
    }
    return { read, update };
}
'@

$files['.github/extensions/workshop-build-board/progress.test.mjs'] = @'
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createProgressStore, parseProgress } from "./progress.mjs";
import { startServer } from "./server.mjs";

const ids = ["00", "01", "02", "03", "04", "05", "06", "07", "99"];
const fixture = "# Progress\n\n| Module | Title | Status | Validated on | Evidence | Notes |\n" +
    "|---|---|---|---|---|---|\n" +
    ids.map((id) => `| ${id} | Synthetic module ${id} | todo | | | Keep note |`).join("\n") +
    "\n\n## Open decisions\n- Synthetic decision.\n\n## Deviations from the build plan\nNone yet.\n";

function setup(t, content = fixture) {
    const root = mkdtempSync(join(tmpdir(), "workshop-board-test-"));
    mkdirSync(join(root, "docs"));
    const path = join(root, "docs", "PROGRESS.md");
    writeFileSync(path, content);
    t.after(() => rmSync(root, { recursive: true }));
    const store = createProgressStore(root);
    return { store, path };
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

test("loopback server protects reads and writes and returns explicit errors", async (t) => {
    const { store } = setup(t);
    const entry = await startServer(store);
    t.after(() => entry.close());
    const html = await (await fetch(entry.url)).text();
    assert.match(html, /Workshop build board/);
    const key = html.match(/const key = "([A-Za-z0-9_-]+)"/)[1];
    assert.equal((await fetch(`${entry.url}progress`)).status, 403);
    const headers = { "x-board-key": key, "Content-Type": "application/json" };
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
'@

$files['.github/extensions/workshop-build-board/server.mjs'] = @'
import { createServer } from "node:http";
import { randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import { BoardError } from "./progress.mjs";

const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");

export async function startServer(store) {
    const key = randomBytes(32).toString("base64url");
    let origin;
    const server = createServer(async (req, res) => {
        res.setHeader("Cache-Control", "no-store");
        res.setHeader("X-Content-Type-Options", "nosniff");
        res.setHeader("Content-Security-Policy",
            "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'");
        function json(status, value) {
            res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
            res.end(JSON.stringify(value));
        }
        try {
            if (req.headers.host !== new URL(origin).host) {
                throw new BoardError("invalid_host", "Unexpected host.", 403);
            }
            if (req.method === "GET" && req.url === "/") {
                res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
                res.end(html.replace("__BOARD_KEY__", key));
                return;
            }
            if (req.headers["x-board-key"] !== key || (req.headers.origin && req.headers.origin !== origin)) {
                throw new BoardError("forbidden", "Open the board to access its local API.", 403);
            }
            if (req.method === "GET" && req.url === "/progress") {
                json(200, store.read());
                return;
            }
            if (req.method !== "POST" || req.url !== "/update") {
                throw new BoardError("not_found", "Unknown board endpoint.", 404);
            }
            if (req.headers["content-type"] !== "application/json") {
                throw new BoardError("invalid_input", "Expected application/json.", 415);
            }
            const chunks = [];
            let size = 0;
            for await (const chunk of req) {
                size += chunk.length;
                if (size > 16384) throw new BoardError("too_large", "Update is too large.", 413);
                chunks.push(chunk);
            }
            let input;
            try {
                input = JSON.parse(Buffer.concat(chunks).toString("utf8"));
            } catch (error) {
                if (!(error instanceof SyntaxError)) throw error;
                throw new BoardError("invalid_input", "Invalid JSON.");
            }
            json(200, store.update(input));
        } catch (error) {
            if (error instanceof BoardError) {
                json(error.status, { code: error.code, error: error.message });
            } else {
                process.stderr.write(`Workshop board error: ${error.message}\n`);
                json(500, { code: "board_error", error: "Could not read or save progress. Inspect the extension log." });
            }
        }
    });
    await new Promise((resolve, reject) => {
        server.once("error", reject);
        server.listen(0, "127.0.0.1", resolve);
    });
    origin = `http://127.0.0.1:${server.address().port}`;
    return {
        server, url: `${origin}/`,
        close: () => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())),
    };
}
'@

$files['.github/skills/workshop-module-builder/SKILL.md'] = @'
---
name: workshop-module-builder
description: Builds, deploys and validates the next module of the "Governed MCP on Azure" workshop in this repository. Use this when asked to continue the workshop build, to build or fix a module (00 to 07, or 99), or to update docs/PROGRESS.md.
---

# Workshop module builder

Always follow these steps, in this order.

1. **Load the context.** Read `.github/copilot-instructions.md`, `docs/BUILD-PLAN.md` and `docs/PROGRESS.md`.
2. **Pick the module.** Use the module named in the request. Otherwise take the first module in `docs/PROGRESS.md`
   whose status is not `validated` (module 07 is optional). If the previous module in the build order is not
   `validated`, stop and say so.
3. **Read the sources first.** Open every official page listed under "Take" for the module (use the Microsoft Learn
   MCP server when it is available). Note any difference between the documentation and the build plan.
4. **Plan and ask.** Present a short plan: files to create or change, Azure and Microsoft Entra changes, roles required,
   Preview features used, cost impact, clean-up. Wait for explicit approval before creating or changing any Azure or
   Microsoft Entra resource.
5. **Build** `modules/NN-name/` following the module contract: README sections in order, `infra/` if needed,
   `validate.ps1`, `validate.sh` and a clean-up script. Pin upstream versions or commit SHAs and keep license notices.
6. **Infrastructure.** Run `terraform fmt -recursive`, `terraform validate` and `terraform plan`. Summarize the plan
   and apply only after approval.
7. **Validate.** Run `validate.ps1` and fix until every check prints PASS. Never weaken a security invariant, widen a role
   or add a secret to get a PASS: stop and ask instead.
8. **Record.** Update `docs/PROGRESS.md` (status, date, PASS lines as evidence, notes, deviations, open decisions) and
   `docs/sources.md` (create it if missing) with every link used and its last verified date.
9. **Ship.** Commit as `module NN: <summary>` and open a pull request that lists what was built, the validation output,
   deviations from the plan, Preview features used and the clean-up command.
'@

$files['.gitignore'] = @'
# Terraform
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfplan
crash.log
crash.*.log
*.tfvars
*.tfvars.json
!*.tfvars.example
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# .NET and Azure Functions
bin/
obj/
local.settings.json
*.user
.vs/

# Node.js
node_modules/

# Azure Developer CLI
.azure/

# Secrets and local files
**/confidential/
.env
*.env
*.pfx
*.pem
*.key
*.log
coverage/

# OS
.DS_Store
Thumbs.db
'@

$files['.mcp.json'] = @'
{
  "mcpServers": {
    "microsoft-learn": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp"
    }
  }
}
'@

$files['.vscode/mcp.json'] = @'
{
  "servers": {
    "microsoft-learn": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp"
    }
  }
}
'@

$files['AGENTS.md'] = @'
# AGENTS.md

This repository builds a hands-on workshop: **Governed MCP on Azure**.

- Rules that always apply: `.github/copilot-instructions.md`.
- What to build, in which order, and what each module must show: `docs/BUILD-PLAN.md`.
- Current status, next module and open decisions: `docs/PROGRESS.md`.
- How to build a module: `.github/skills/workshop-module-builder/SKILL.md`.
- How a human drives the build with the GitHub Copilot app: `docs/COPILOT-RUNBOOK.md`.

Work on one module per session and per branch.
Never create or change Azure or Microsoft Entra resources without explicit approval in the session.
'@

$files['docs/BUILD-PLAN.md'] = @'
# Build plan — Governed MCP on Azure

Build the modules in this order, one session and one branch per module.
Do not start a module until the previous one validates.

## End-state architecture

```text
MCP clients: VS Code + GitHub Copilot, MCP Inspector (optional: Copilot Studio, Foundry agent)
 → Azure API Management (only entry point): Protected Resource Metadata (PRM), validate-azure-ad-token,
   per-tool role check, rate limit, IP filter, payload-free logs
   → Azure Functions MCP server (.NET isolated worker), built-in Entra authentication. Tools:
       get_service_health   read, synthetic data
       create_ticket        write, synthetic side effect (Storage queue)
       whoami               On-Behalf-Of → Microsoft Graph /me
       read_report_as_user  On-Behalf-Of → Azure Storage (the caller's RBAC applies)
       read_report_as_app   managed identity → Azure Storage (same result for everyone)
 → Application Insights / Log Analytics
Azure API Center registers the gateway endpoint (inventory, not a runtime hop).
```

Personas:
- **Alice**: assigned, app roles Tools.Read + Tools.Write, Storage Blob Data Reader.
- **Bob**: assigned, Tools.Read only, no storage role.
- **Eve**: not assigned.

## 00 — Prerequisites and environment
- **Take:** Azure CLI, Terraform, PowerShell 7, .NET 10 and Functions Core Tools >= 4.5.0 from the pinned sample;
  Node.js >= 22.19.0 for the selected MCP Inspector. See [source selections](sources.md) before pinning exact tool versions.
- **Build:** .devcontainer; preflight.ps1 (tools, versions, `az login`, subscription, resource providers, role checks,
  quota, region); docs/requests/identity-request.md listing exactly what an identity administrator must create or consent.
- **Show:** preflight passes; the identity request is clear enough to send as is.

## 01 — Discover MCP (no Azure)
- **Take:** MCP specification: https://modelcontextprotocol.io/specification (revision 2026-07-28 verified on 2026-10-14: architecture, tools, transports, authorization);
  https://code.visualstudio.com/docs/agent-customization/mcp-servers; MCP Inspector (@modelcontextprotocol/inspector).
- **Build:** a local MCP server from the official C# SDK quickstart (https://github.com/modelcontextprotocol/csharp-sdk);
  connect it to VS Code and to MCP Inspector.
- **Show:** tools/list, a tool call, the approval prompt in the client.
- **Validate:** Inspector lists the tools and returns a result. Check the negotiated protocol version: the current
  specification uses per-request metadata, while older clients use an initialization handshake. Do not mix message shapes.

## 02 — An "open" MCP server (level 0)
- **Take:** https://github.com/Azure-Samples/remote-mcp-functions-dotnet
  at `468c518c884ec318e3001b9573254c9e775409c9`;
  https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server;
  Functions MCP extension docs; Flex Consumption docs.
- **Build:** Terraform for Function App (Flex Consumption), Storage, Application Insights, managed identity;
  the five tools with synthetic data. Use a queue for synthetic tickets. In this module, downstream identity tools
  return clearly labeled synthetic demonstrations; their real authorization behavior is introduced in module 05.
- **Show:** with the key, anyone can call create_ticket.
- **Validate:** HTTP 401 without the MCP extension system key, HTTP 200 with the key and a valid MCP request;
  anonymous access disabled. Set webhook authorization to `System`: upstream `host.json` uses `Anonymous` because
  the upstream sample starts with Entra authentication. Never copy that setting into the key-only module.

## 03 — Identity with Microsoft Entra (level 1)
- **Take:** https://learn.microsoft.com/azure/app-service/configure-authentication-mcp;
  https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode;
  https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial;
  app roles: https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps.
- **Build:** infra/entra: app registration (Application ID URI, scope user_impersonation, app roles Tools.Read,
  Tools.Write, Tools.Execute.All), assignment required, pre-authorized client applications (VS Code client ID from
  the sample, Azure CLI); enable built-in authentication and Protected Resource Metadata (PRM) (setting
  WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES, Preview).
- **Show:** VS Code signs in; explain audience (`aud`), scopes (`scp`), and roles using synthetic claim examples;
  Eve is refused. Never paste a live token into a website, chat, committed file, or log.
- **Validate:** 401 without token; 401 with a token for another audience; 200 for Alice and Bob;
  Eve cannot get a token (assignment required).

## 04 — API Management as the only entry point (level 2)
- **Take:** https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server;
  https://learn.microsoft.com/azure/api-management/secure-mcp-servers;
  https://learn.microsoft.com/azure/api-management/mcp-server-overview (governance, limitations);
  https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api (REST, Bicep, Azure CLI, Terraform);
  https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy;
  https://github.com/Azure-Samples/AI-Gateway (labs mcp-client-authorization, mcp-prm-oauth).
- **Build:** APIM v2 (azapi, api-version 2025-09-01-preview), MCP server exposed; policies: validate-azure-ad-token
  (audience = the MCP server), role check per tool from the JSON-RPC body (create_ticket requires Tools.Write),
  rate-limit-by-key on the caller object ID, ip-filter; Application Insights with zero body bytes;
  Function reachable only through APIM (choose and document the network option in the plan step).
- **Recommendation:** Standard v2 outbound virtual network integration, a Function private endpoint, private DNS,
  and public Function access disabled. The MCP management API is **Preview**. Keep public protected resource metadata
  and OAuth challenges on the gateway. Do not expose the private Function URL to clients.
- **Show:** Bob calls create_ticket → 403, Alice → 200; burst → 429; direct call to the Function refused; logs without payload.
- **Validate:** all of the above as PASS/FAIL lines.
- **Optional 04b:** expose a synthetic REST API as an MCP server (https://learn.microsoft.com/azure/api-management/export-rest-mcp-server; AI-Gateway lab mcp-from-api).

## 05 — Who carries the rights? On-Behalf-Of vs app-only (level 3)
- **Take:** https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow;
  src/FunctionsMcpTool/HelloToolWithAuth.cs in the sample; federated identity credential with a user-assigned managed identity
  (https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).
- **Build:** whoami and read_report_as_user (On-Behalf-Of, Graph User.Read and Azure Storage user_impersonation);
  read_report_as_app (managed identity, Storage Blob Data Reader on one container).
- **Show:** same question, Alice vs Bob: as_user → 200 for Alice, 403 for Bob; as_app → same result for both.
- **Validate:** the four results; no client secret anywhere. Record both outer HTTP status and the MCP tool result:
  a downstream HTTP 403 can be returned as a tool error inside an HTTP 200 response.

## 06 — Observe and inventory (level 4)
- **Take:** APIM Application Insights integration and KQL; Azure API Center MCP inventory:
  https://learn.microsoft.com/azure/api-center/register-discover-mcp-server;
  AI-Gateway lab mcp-registry-apic;
  bring your own (BYO) MCP server in the Microsoft 365 admin center (Preview): https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server.
- **Build:** a workbook or saved KQL queries (tool, caller, status, latency, top denials); register the server in API Center.
- **Show:** who called which tool, when, with what result.
- **Optional 06b:** Agent 365 / Microsoft 365 admin center inventory as a demo only (Preview, licensing and Frontier
  requirements), no participant step.

## 07 — Optional: other clients
- **Take:** https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication;
  https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent.
- **Show:** the same governed server from a Foundry agent (project managed identity or OAuth identity passthrough, Preview)
  and from Copilot Studio. Facilitator demo only.

## 99 — Clean up
- terraform destroy for workload and entra; delete role assignments and test users;
  check that nothing remains (`az resource list --tag workshop=...`).

## Docs to produce
- docs/concepts/: token chain diagram, scopes vs app roles, On-Behalf-Of vs managed identity, MCP threat model
  (tool poisoning, prompt injection, token passthrough, confused deputy, over-broad tools).
- docs/facilitator-guide.md: timings, expected outputs, fallback recordings, common errors.
- docs/sources.md: every link above with its last verified date.

## P1 recommendations (design only)

Last source review: 2026-10-14. These are implementation recommendations, not a deployed or validated workshop.
The selected upstream files, versions, licenses, updates, and exclusions are in [sources.md](sources.md).

### Target repository tree

Only the existing scaffold, source assessment, and build board are present now. The following is the intended
tree to create in subsequent module sessions. Every module has the same README contract and its own
`validate.ps1`, `validate.sh`, `cleanup.ps1`, and `cleanup.sh`. Shared Terraform lives in two roots, not one
copy per module. Module folders contain only module-specific assets and instructions.

```text
.devcontainer/
  devcontainer.json
  Dockerfile
.github/
  agents/workshop-builder.agent.md
  copilot-instructions.md
  skills/workshop-module-builder/SKILL.md
  extensions/workshop-build-board/
    extension.mjs, progress.mjs, server.mjs, board.html, progress.test.mjs
.vscode/mcp.json
.mcp.json
docs/
  BUILD-PLAN.md, PROGRESS.md, COPILOT-RUNBOOK.md, sources.md
  requests/identity-request.md
  concepts/token-chain.md
  concepts/scopes-and-app-roles.md
  concepts/obo-and-managed-identity.md
  concepts/mcp-threat-model.md
  facilitator-guide.md
infra/
  entra/
    versions.tf, providers.tf, main.tf, variables.tf, outputs.tf
    .terraform.lock.hcl
  workload/
    versions.tf, providers.tf, main.tf, variables.tf, outputs.tf
    network.tf, gateway.tf, diagnostics.tf, inventory.tf
    .terraform.lock.hcl
src/
  LocalMcpServer/
    LocalMcpServer.csproj, Program.cs, Tools.cs
  FunctionsMcpServer/
    FunctionsMcpServer.csproj, Program.cs, host.json
    Tools/ServiceHealthTool.cs, Tools/CreateTicketTool.cs
    Tools/WhoAmITool.cs, Tools/ReadReportAsUserTool.cs, Tools/ReadReportAsAppTool.cs
    Identity/DownstreamCredentials.cs
tests/
  FunctionsMcpServer.Tests/
scripts/
  preflight.ps1, preflight.sh
  deploy.ps1, deploy.sh
  lib/Validation.psm1, lib/validation.sh
modules/
  00-prerequisites/             README, validation, cleanup
  01-discover-mcp/              README, validation, cleanup, client-config/
  02-open-server/               README, validation, cleanup, synthetic-data/
  03-entra-authentication/      README, validation, cleanup, synthetic-claims/
  04-governed-gateway/          README, validation, cleanup, policies/
  05-delegated-and-app-only/    README, validation, cleanup, synthetic-data/
  06-observe-and-inventory/    README, validation, cleanup, queries/
  07-other-clients/            README, validation, cleanup, demo-checklist.md
  99-cleanup/                  README, validation, cleanup
THIRD-PARTY-NOTICES.md          Add when upstream code is first adapted
README.md, LICENSE, AGENTS.md, setup-workshop-mcp.ps1
```

### Choices and implementation gates

| Area | Recommendation | Gate before implementation or deployment |
|---|---|---|
| Runtime | .NET 10 isolated worker; Functions host v4; ordinary MCP tool trigger extension 1.5.0 as the upstream starting point | Confirm deployed runtime support, restore and test the minimal tool project. Do not import the sample's Apps/QR/preview SDK dependencies unnecessarily. |
| Local introduction | C# SDK 2.2.0, minimal stdio tool, synthetic arguments | Pin its package and hosting dependencies; send logs to stderr. No weather API or model subscription needed. |
| Inspector | Published 2.11.0, Node.js >= 22.19.0 | Test both local and gateway connections. Learn still recommends 0.9.0 in older APIM tips; do not adopt it blindly. Keep tokens in memory or an OS keychain, not plaintext container storage. |
| Protocol | Teach current 2026-07-28 terminology and explicitly explain legacy negotiation | Verify what each pinned client/server actually supports. APIM documents a minimum of 2025-06-18, not proof of every 2026 feature. |
| Terraform | Candidate exact pins: azurerm 5.9.0, azuread 3.10.0, azapi 2.13.0 | Versions exist in the registry; compatibility is not deployment-tested. Commit lock files after module validation, with no state/tfvars. |
| Resource model | AzureRM for Flex, storage, identities, private networking, and supported gateway settings; AzAPI for missing properties and MCP APIs/policies at `2025-09-01-preview` (**Preview**) | Use `Microsoft.ApiManagement/service/apis` with `type: mcp`, `transportType: streamable` and the real Function endpoint `/runtime/webhooks/mcp`. Existing-server proxying does not need REST tool subresources. |
| Network | Standard v2 public gateway with outbound virtual network integration to a Function private endpoint; private DNS and public Function access disabled | Dedicated delegated APIM subnet with network security group; separate private endpoint subnet. Prove gateway access and public direct denial; decide how deployment reaches restricted services. Basic v2 lacks this outbound integration. |
| Region | Evaluate West Europe as the first candidate, with no assumed availability | Preflight must check current Flex locations/runtime, Standard v2 availability, regional quota and policy restrictions for the chosen subscription. Ask before using a different region. |
| Identity | One MCP audience, user scope plus Tools.Read/Tools.Write app roles; assignment required | Identity administrator approves exact objects, consent, test users, and preauthorized clients. Read existing IDs when creation is skipped. |
| Token boundary | Gateway and Function protect one logical MCP resource; the client token is validated there, never sent to Graph or Storage | Separate downstream tokens via On-Behalf-Of (OBO) or managed identity. If gateway and backend become distinct audiences, design explicit token exchange; do not broaden the Function's accepted audiences. |
| OBO | User-assigned managed identity plus a federated identity credential, supported Azure Identity libraries | Downstream Graph User.Read and Storage delegated consent; same-tenant application/identity trust. Reject app-only calls to user-context tools. Never fall back to developer identity in deployed validation. |
| App-only | Separate explicit managed-identity credential for the app-context tool | Storage Blob Data Reader on the one synthetic report container, not the entire subscription. |
| Authorization | Platform token validation plus per-tool role checks; no automatic approval for writes | Preserve the request body when inspecting JSON-RPC. Deny malformed or unsupported call shapes safely. Verify gateway HTTP 403 and distinguish downstream errors embedded in MCP HTTP 200. |
| Telemetry | Authenticated caller object ID, fixed tool name, status, latency and correlation ID only | Zero body bytes on frontend/backend requests/responses at all inherited scopes. Never read streaming response bodies, log arguments/results, or trust caller-supplied identity headers. |
| Inventory | Register only the governed gateway endpoint in API Center | Do not import a third-party server catalog. Inventory registration does not itself authorize runtime access. |

### Risks, permissions, costs, and cleanup

- **Identity permissions:** separate Azure resource creation from Microsoft Entra application/consent work.
  A workload participant needs resource deployment permissions on the workshop resource group. The identity
  administrator needs application management and the consent permissions required by the selected delegated
  APIs. Role assignment permissions are separate from Contributor. Do not request Owner by default.
- **Test identities:** Alice and Bob need actual assigned app roles; Eve remains unassigned. Use dedicated
  non-production test accounts. `whoami` must return an allowlisted synthetic persona, not a live display name
  or email copied into a workshop artifact.
- **Preview:** App Service protected resource metadata, the APIM MCP management API, the canvas SDK surface,
  and optional Microsoft 365 BYO inventory remain explicitly labeled. Self-hosted MCP on Functions is
  **Preview** and is not selected. Recheck optional client feature status before its demo.
- **Source conflicts:** the App Service VS Code walkthrough auto-creates a client secret; use the sample's
  managed-identity federation pattern instead. PRM lab text has an RFC number typo and older authorization
  language; the standard is RFC 9728. API Management overview and existing-server docs disagree on resources;
  use only tools in the core workshop. Do not copy OAuth-server emulation or permissive multi-audience examples.
- **Costs:** Standard v2 is provisioned gateway capacity, not a few Functions executions. Include private
  endpoint, storage, telemetry ingestion/retention, API Center and optional agent charges in the estimate
  before approval. Keep always-ready Functions instances off unless required. No prices are assumed here.
- **Cleanup:** module 99 destroys workload first, then only workshop-created Entra objects and test accounts.
  Preserve provided identities and existing infrastructure. Check role assignments, private DNS/endpoint
  resources, API Center records, soft-deletion/retention behavior, and the complete workshop-tagged inventory.
- **Completion:** prove the previous module first; never convert a design recommendation or canvas save into
  validation evidence. A private gateway design is not implemented until a fresh deployment proves it.

## Sources

See [sources.md](sources.md) for the source register, exact upstream pins, reuse decisions, and limitations.
Last verified: 2026-10-14.
'@

$files['docs/COPILOT-RUNBOOK.md'] = @'
# Runbook — build this workshop with the GitHub Copilot app

This runbook drives the build from this scaffold to a validated workshop: one module per session, one branch and one pull request per module.

## 1. Before you start

- **GitHub Copilot app** installed and signed in. With Copilot Business or Enterprise, your organization must allow it.
- **Local tools:** Git, GitHub CLI, Azure CLI, Terraform, PowerShell 7, Node.js LTS, and the .NET SDK and Azure Functions Core Tools versions used by
  [Azure-Samples/remote-mcp-functions-dotnet](https://github.com/Azure-Samples/remote-mcp-functions-dotnet).
- **A non-production Azure subscription** where you can create resources and role assignments:
  `az login` then `az account set --subscription <your-test-subscription>`.
- **Test identities:** a test Microsoft Entra tenant, or an identity administrator who can run `infra/entra`
  and create three test users: Alice, Bob and Eve.
- **Recommended — Microsoft Learn MCP server**, so the agent reads the official documentation before writing code:
  - GitHub Copilot app or Copilot CLI: add it from the Customize panel or with `/mcp add`
    (name `microsoft-learn`, type HTTP, URL `https://learn.microsoft.com/api/mcp`, no authentication).
  - Workspace: already configured in portable `.mcp.json`, with `.vscode/mcp.json` for compatibility.
    Both describe the same public endpoint, without credentials. Avoid adding a duplicate server in the same client.

### Bootstrap an empty destination

From the folder containing `setup-workshop-mcp.ps1`, run PowerShell 7:

```powershell
pwsh -ExecutionPolicy Bypass -File .\setup-workshop-mcp.ps1
```

The standalone bootstrap includes the scaffold, current P1 source assessment, and build board. It requires Git
and GitHub CLI (`gh`) unless `-SkipGitHub` is used. If missing, install them with
`winget install --id Git.Git -e` and `winget install --id GitHub.cli -e`, then reopen the terminal.
Git identity must be configured. For publication, the script uses repository-local GitHub noreply identity,
not the globally configured email. It does not change global Git settings.

The default destination is `C:\github\workshop-mcp`. The script refuses a nonempty destination or an existing
remote repository. Do not empty a working folder to bypass this protection.
Options: `-Visibility private`, `-SkipGitHub` (local only), `-OpenVSCode`, `-Path`, and `-RepoName`.
The script does not create or change Azure or Microsoft Entra resources.

### Start from an existing scaffold

If the workshop files are already present, open that folder in a local Copilot session. Do not run the bootstrap
against it. Initialize Git on the existing files, review the publication content, and then create/push the remote
repository only after explicit approval. Use a repository-local noreply Git identity and inspect the staged diff
before the first commit. Keep publication audit terms and local scan reports outside the repository.

The bootstrap contains embedded copies of the scaffold. When updating these files, update its embedded copies
in the same change, and verify a `-SkipGitHub` run in a new, empty test destination. Never test publication by
creating an extra public repository.

## 2. How the build works

| File | Role |
|---|---|
| `.github/copilot-instructions.md` | Permanent rules: content, nine security invariants, stack, module contract |
| `docs/BUILD-PLAN.md` | What to take, in which order, what each module must show and validate |
| `docs/PROGRESS.md` | Status of each module, validation evidence, open decisions |
| `docs/sources.md` | Verified upstream snapshots, useful elements, updates, exclusions and license boundaries |
| `.github/extensions/workshop-build-board/` | Project-scoped progress canvas (**Preview** SDK), backed only by PROGRESS.md |
| `.github/skills/workshop-module-builder/SKILL.md` | The procedure the agent follows for every module |
| `.github/agents/workshop-builder.agent.md` | Optional custom agent that applies the skill |
| `AGENTS.md` | Entry point for any coding agent |

Rules of the game:
- One module = one session = one branch = one pull request. Merge it before you start the next module.
- Use **Plan** mode to think, **Interactive** mode for anything that touches Azure or Microsoft Entra,
  **Autopilot** only for documentation.
- Use **local** sessions for modules that deploy to Azure: they need your `az login`.
- The agent must show you the Terraform plan and the Entra changes, and wait for your approval, before applying anything.

## 3. Session sequence

| Step | Mode | Session | Prompt | Done when |
|---|---|---|---|---|
| 1 | Plan | Local | P1 | You approved the tree, the technical choices and the risks |
| 2 | Interactive | Local | P2 | preflight.ps1 and the module 01 validate script pass |
| 3 | Interactive | Local | P3 | Module 02 validate passes |
| 4 | Interactive | Local | P4 | Module 03 validate passes |
| 5 | Interactive | Local | P5 | Module 04 validate passes |
| 6 | Interactive | Local | P6 | Module 05 validate passes |
| 7 | Interactive | Local | P7 | Module 06 validate passes |
| 8 | Interactive | Local | P8 | Module 99 leaves the subscription empty |
| D | Autopilot | Cloud or local, in parallel from step 3 | PD | Concept docs and facilitator guide merged |
| 9 | Plan | Local | P9 | Final review pull request open, no blocking gap left |

### P1 — Plan the whole build (no code)

```text
Read .github/copilot-instructions.md, docs/BUILD-PLAN.md and docs/PROGRESS.md, then the official pages listed in the plan.
Propose the full repository tree, the files of each module, the technical choices (network path from API Management
to the Function, Terraform providers and azapi resources, region) and the risks (Entra permissions, preview features,
cost). Do not write code. Record your recommendations under "Open decisions" in docs/PROGRESS.md.
```

### P2 — Modules 00 and 01

```text
Use the workshop-module-builder skill. Build module 00 (.devcontainer, preflight.ps1, docs/requests/identity-request.md),
and stop when its validation passes. Update docs/PROGRESS.md and open the pull request.
After merge, start a separate session/branch for module 01 and stop when its validate script passes.
```

### P3 — Module 02, the "open" server

```text
Use the workshop-module-builder skill for module 02. Participant prefix p00, my current Azure subscription.
Show me the Terraform plan before applying. Fix until validate.ps1 passes.
```

### P4 — Module 03, Microsoft Entra

```text
Use the workshop-module-builder skill for module 03. Generate infra/entra first and list exactly which Entra objects,
permissions and consents it creates; apply only after my approval. Then enable built-in authentication and the
Protected Resource Metadata on the Function, and prove the expected results for Alice, Bob and Eve.
```

### P5 — Module 04, API Management as the only entry point

```text
Use the workshop-module-builder skill for module 04. API Management must become the only entry point.
Prove with validate.ps1: Bob gets 403 on create_ticket, Alice gets 200, 429 after the limit,
a direct call to the Function is refused, and the logs show tool name and caller without any payload.
```

### P6 — Module 05, On-Behalf-Of vs app-only

```text
Use the workshop-module-builder skill for module 05. Compare On-Behalf-Of and app-only access with Alice and Bob.
validate.ps1 must check the four expected results automatically. No client secret anywhere.
```

### P7 — Module 06, observe and inventory

```text
Use the workshop-module-builder skill for module 06: saved KQL queries or a workbook (tool, caller, status, latency,
top denials) and the registration of the server in Azure API Center.
```

### P8 — Module 99, clean up

```text
Use the workshop-module-builder skill for module 99. Destroy workload and entra, remove role assignments and test users,
and prove that nothing tagged with the workshop remains.
```

### PD — Documentation (parallel session, Autopilot)

```text
Write docs/concepts/ (token chain diagram, scopes vs app roles, On-Behalf-Of vs managed identity, MCP threat model),
docs/facilitator-guide.md and docs/sources.md from docs/BUILD-PLAN.md and the modules already validated.
Do not change any module code or infrastructure. Open a pull request.
```

### P9 — Final review

```text
Review the whole repository against .github/copilot-instructions.md: the nine security invariants, no customer or
internal content, every link valid, Preview labels present, every module cleans up, and module 99 leaves a fresh
subscription empty. List every gap in a pull request and fix only what is safe to fix.
```

## 4. Workshop build board

The project-scoped canvas is already implemented in `.github/extensions/workshop-build-board/`.
Ask: "Show the workshop build board." Reload project extensions if discovery has not picked it up.
The Copilot canvas SDK is **Preview**; it is separate from Azure or Foundry agent infrastructure.

The board shows one card per module, its status, validation date, evidence, notes, and the open decisions.
It writes only `docs/PROGRESS.md`; no separate progress database exists.
Use **Refresh progress** after an external edit. Refresh discards unsaved form edits.
Conflicting saves are refused, rather than overwriting a newer version. Evidence and notes must be single-line
Markdown table cells without pipe characters.

Agent capabilities:

| Capability | Input and result |
|---|---|
| `get_progress` | Returns modules, open decisions, and the current revision. |
| `set_module_status` | Requires module, status, evidence and revision from the last read. Optional notes; validated also requires a real validation date. |
| `list_open_decisions` | Returns the Open decisions section. |

Mark a module `validated` only after its actual validation script passes in the required fresh-subscription
sequence. The board stores evidence; it neither runs tests nor certifies that evidence.
Do not enter confidential text, tokens, prompts, tool arguments/results, or live account identifiers.

To check the board locally without the Copilot runtime:

```powershell
node --test .github\extensions\workshop-build-board\progress.test.mjs
```

### Re-create the board in a different project

In a session, type `/create-canvas`, choose the **project** scope (the canvas is saved in `.github/extensions/`
and versioned with the repository), then paste:

```text
Create a canvas named "Workshop build board". It shows docs/PROGRESS.md as one card per module (status,
validated date, evidence, notes) plus the open decisions. I can change a status or add a note from the canvas.
Give the agent three capabilities: get_progress, set_module_status(module, status, evidence) and list_open_decisions.
docs/PROGRESS.md stays the only source of truth: the canvas reads and writes that file and nothing else.
```

Then ask in any session: "Show the workshop build board and start the next module."

## 5. Before the workshop day

- Dry run: modules 00 to 06 end to end on a fresh subscription with a new prefix, then module 99.
- Record a short video of each level as a fallback.
- Check the cost of the dry run, then clean up.

## Sources

[Build plan](BUILD-PLAN.md), [source register](sources.md), and
[VS Code MCP configuration](https://code.visualstudio.com/docs/agent-customization/mcp-servers).
Last verified: 2026-10-14.
'@

$files['docs/PROGRESS.md'] = @'
# Build progress

The agent updates this file at the end of every module session.
Status values: `todo` · `in-progress` · `validated` · `blocked`.
A module is `validated` only when its validate script passes on a fresh subscription right after the previous modules.

| Module | Title | Status | Validated on | Evidence (PASS lines or PR) | Notes |
|---|---|---|---|---|---|
| 00 | Prerequisites and environment | todo |  |  | P1 source assessment complete; environment implementation and validation pending. |
| 01 | Discover MCP (no Azure) | todo | | | |
| 02 | An "open" MCP server (level 0) | todo | | | |
| 03 | Identity with Microsoft Entra (level 1) | todo | | | |
| 04 | API Management as the only entry point (level 2) | todo | | | |
| 05 | On-Behalf-Of vs app-only (level 3) | todo | | | |
| 06 | Observe and inventory (level 4) | todo | | | |
| 07 | Optional: other clients | todo | | | Facilitator demo only |
| 99 | Clean up | todo | | | |

## Open decisions
- Network (module 04): recommend Standard v2 outbound virtual network integration, Function private endpoint,
  private DNS and public Function access disabled. Confirm deployment connectivity before applying.
- Identity ownership: confirm who runs infra/entra and grants delegated consent; accept existing object IDs
  without changing or deleting those objects when identity creation is skipped.
- Region: evaluate West Europe first. Confirm current Flex runtime support, Standard v2 availability, quota,
  subscription policies and costs before selecting it.
- Test identities: decide between a dedicated non-production tenant and dedicated Alice, Bob and Eve test
  accounts in an existing non-production tenant. Do not store live account details in the repository.
- Versions: source assessment pins upstream examples and records published provider/Inspector versions.
  Validate package/provider combinations and negotiated MCP protocol in module 00/01 before declaring compatibility.
- Gateway authorization: verify per-tool request inspection preserves JSON-RPC and streaming; distinguish gateway
  HTTP status from downstream status returned inside an MCP tool error.
- Optional clients: Copilot Studio's documented manual Entra OAuth path requests a client secret. Defer that
  connection unless an officially supported secretless flow is proven; never relax the workshop rules.
- Cost approval: estimate Standard v2 capacity, private endpoints, telemetry, storage and API Center before deployment.

## Deviations from the build plan
- P1 preparation only: source assessment, updated architecture recommendations, and the project build board.
  No module has been built or validated. No Azure or Microsoft Entra resource has been changed.
- Prefer current Inspector 2.11.0 as a compatibility-test candidate over the older APIM documentation's 0.9.0 tip.
- Upstream Functions sample now targets .NET 10; the Learn quickstarts still show .NET 8. Use the pinned project
  as the runtime starting point and verify Azure runtime support before deployment.
- Keep live tokens out of external token viewers. Use synthetic claim examples for the teaching exercise.
'@

$files['docs/sources.md'] = @'
# Sources and reuse decisions

Last verified: 2026-10-14. This is a design assessment, not evidence of a successful deployment.
Links were read from public upstream sources. No upstream application code has been vendored in this preparation.
Versions below are reproducible reference selections or compatibility-test candidates, not a promise that every
combination has been tested together.

## Selection method

Choose the smallest example that teaches one workshop outcome and can be validated and cleaned up by a participant.
Prefer official samples and standards. Check the actual files, not only marketing descriptions.
Keep the five synthetic tools and one identity story throughout the workshop.
Translate useful infrastructure concepts to Terraform and participant steps to PowerShell first, then bash.
Do not import notebooks, external data sources, model deployments, complete catalogs, or unrelated agent demos.

## Upstream snapshots

| Upstream | Selected snapshot | What was inspected | License and reuse boundary |
|---|---|---|---|
| [Functions .NET sample](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9) | `468c518c884ec318e3001b9573254c9e775409c9` | README, FunctionsMcpTool project, host.json, HelloToolWithAuth.cs, infra/app/api.bicep, repository tree and LICENSE.md | MIT, copyright Microsoft Corporation. Preserve the full notice in any adapted code. Link and summarize now; do not copy the whole sample. |
| [C# SDK release](https://github.com/modelcontextprotocol/csharp-sdk/tree/6fa3825973949a9c4f0cd8af344e15a8db09dc35) | Released `v2.2.0`, commit `6fa3825973949a9c4f0cd8af344e15a8db09dc35` | Getting-started guide, README, release metadata, sample paths and LICENSE | Licensing transition: Apache-2.0 for new/consented code, MIT for un-relicensed contributions; documentation CC-BY-4.0. Check the exact file's obligations before adaptation. Do not assume the workshop MIT license replaces upstream terms. |
| [AI Gateway labs](https://github.com/Azure-Samples/AI-Gateway/tree/1679e3137d2fe7592d2a668d77ff71550d35b69e) | `1679e3137d2fe7592d2a668d77ff71550d35b69e` | README, four selected lab READMEs, PRM policies, catalog OpenAPI, registry JSON, workbook JSON and LICENSE.md | MIT, copyright Microsoft Corporation. Preserve notices when adapting policy, infrastructure, query or schema code. No notebook output or whole-repo imports. |
| [MCP Inspector](https://github.com/modelcontextprotocol/inspector/releases/tag/2.11.0) | Published `2.11.0`; inspected main manifest snapshot `074b8108f340590268f2900741403755e923a11c` | Release metadata, package manifest and official Inspector documentation | Use the versioned package as tooling. No Inspector source is copied. Recheck its license if source is later adapted. |
| [MCP specification](https://modelcontextprotocol.io/specification/2026-07-28) | `2026-07-28` | Architecture, transports, tools and authorization | Link and summarize requirements. Do not reproduce documentation wholesale. |

The C# SDK main branch inspected at `3338e88e15c42cfc27465143c140d7d10f1a2707` includes changes
after the selected release, including removal guidance for `McpServerFactory`. Prefer the released package and
its matching examples rather than mixing a moving README with old APIs.
The Functions and AI Gateway snapshots are source pins, not release guarantees.

## Best elements to take, by module

All rows were last verified on 2026-10-14. Paths are relative to the pinned repositories above.

| Module | Best source element | Teaching value and integration | Adapt or exclude |
|---|---|---|---|
| 00 | Functions README and `src/FunctionsMcpTool/FunctionsMcpTool.csproj`; Inspector prerequisites | One consistent environment: .NET 10, Functions Core Tools >= 4.5.0, Node.js >= 22.19.0; local Azurite only when needed | Learn quickstarts still show .NET 8. Pin an exact SDK/container/tool set during implementation and test restore. Terraform replaces azd/Bicep deployment; no Docker requirement for the stdio introduction. |
| 01 | C# SDK `docs/concepts/getting-started.md`: minimal stdio EchoTool and stderr logging; QuickstartClient tools/list and tools/call | Smallest MCP discovery/call exercise with no Azure or model bill; make all inputs synthetic | Do not pull the weather sample's live external API. Pin SDK 2.2.0 and its hosting dependencies. Demonstrate client approval explicitly; annotations are not authorization. |
| 02 | Functions tool trigger project and `infra/app/api.bicep`: Flex deployment storage and managed identity | Keep the serverless hosting and identity-based storage design; replace snippet CRUD with synthetic service health and ticket queue | Upstream host.json sets `Anonymous` under Entra. The key-only module must use `System` and runtime-only `x-functions-key` input. Drop QR, Apps, prompts, website preview and unnecessary preview SDK packages. |
| 03 | App Service MCP authorization and VS Code walkthrough; app-role documentation; sample `infra/app/api.bicep` authsettingsV2 | Separate server audience, delegated client scope, user roles and assignment-required; show PRM discovery and unassigned-user denial | PRM is **Preview**. Portal defaults create a secret; use explicit identity configuration and managed-identity federation instead. Preauthorization is not a replacement for user-role assignment or scope checks. |
| 04 | APIM existing-server docs and programmatic resource model; `labs/mcp-prm-oauth/src/bicep/apim-mcp/mcp-prm.policy.xml` and `mcp-api.policy.xml` | Reuse PRM endpoint/challenge shape and platform token validation as design patterns; map to Terraform/AzAPI **Preview** resources | Use RFC 9728, the exact MCP audience and the workshop scope. Do not copy the lab's multiple accepted audiences, older OAuth-server wording or permissive defaults. Preserve streaming; never read response bodies. |
| 04b (optional) | `labs/mcp-from-api/src/product-catalog/api/openapi.json` and its REST-to-MCP lab | A compact schema demonstrates selecting REST operations as tools | Translate into a synthetic service-health API; do not retain its API-key requirement or unrelated catalog deployment. REST-exported tools do not replace the core Functions server. |
| 05 | Functions `src/FunctionsMcpTool/HelloToolWithAuth.cs`, OBO docs and managed-identity federation docs | Reuse the supported `OnBehalfOfCredential` client-assertion callback concept; obtain distinct Graph and Storage tokens | Do not reuse local developer-identity fallback in deployed tests, log exception details that can leak data, or return real display names/emails. Use fixed tenant/audience configuration and sanitized persona output. App-only tool uses explicit managed identity, not OBO. |
| 06 | APIM Application Insights docs; `labs/mcp-from-api/src/mcp-insights/workbook.json`; API Center registration docs and `labs/mcp-registry-apic` | Reuse correlation joins and a small request/denial view; register only the governed endpoint | Workbook `agent-id`/`user-id` header values are not authenticated identity proof. Emit validated caller metadata, zero body bytes, fixed tool name, status and latency. Do not import the lab's third-party/SSE catalog JSON. |
| 06b (optional) | Microsoft 365 BYO MCP inventory docs | Facilitator explanation of review, admin approval and inventory (**Preview**) | No tenant registration in the core path; recheck licensing and eligibility before a demo. Current docs list supported surfaces and exclude Foundry and declarative agents from this preview. |
| 07 (optional) | Foundry MCP authentication and Copilot Studio onboarding docs | Contrast shared project/agent identity with individual OAuth user context on the same governed server | Only a supported secretless flow may be demonstrated. Copilot Studio supports Streamable HTTP, not deprecated SSE. Its documented manual OAuth asks for a secret: defer rather than weaken the rules. Foundry client identity preservation does not permit forwarding the MCP token to Graph/Storage. |
| 99 | The selected labs' cleanup guidance plus the workshop's two Terraform roots | Teach deterministic teardown, ownership boundaries and a final empty-inventory check | Replace broad notebook/resource-group deletion with destruction of workshop-owned resources only. Do not remove passed-in identities, shared infrastructure, or unrelated accounts. |

## Verified updates and conflicts

- **Protocol revision:** 2026-07-28 is the current specification returned by the official index. It uses
  per-request version/capability metadata rather than the older initialization model. Dynamic client registration
  is deprecated in that revision. Microsoft Entra pre-registration remains the workshop choice.
- **Compatibility:** current documentation is not evidence that a pinned Functions extension, C# SDK release,
  gateway and every client implement the newest revision. Validate their negotiated era before writing examples.
- **Functions dependencies:** the selected project targets `net10.0`, Functions v4, worker `2.52.0`,
  MCP extension `1.5.0`, worker SDK `2.0.7`, Azure Identity `1.21.0`, and Graph `5.104.0`.
  It also includes MCP SDK `1.0.0-preview.4` (**Preview**) and unrelated UI dependencies.
  These are observed upstream values, not a mandate to copy every dependency.
- **Key protection:** `/runtime/webhooks/mcp` uses the `mcp_extension` **system key**, not a per-function key.
  Keep it out of source and Terraform outputs/state committed to Git. Under Entra, remove the key requirement
  only after platform authentication is active; `Anonymous` in host.json does not mean the public app may be anonymous.
- **Auth configuration:** the sample stores a managed identity client ID in a setting referenced by
  `clientSecretSettingName` as part of its federation override pattern. That name does not make the value a secret.
  Confirm the exact supported platform pattern before translating authsettingsV2; do not add a client secret.
- **PRM labs:** README text says RFC9729, but its linked standard and policy use RFC 9728.
  The client-authorization lab implements an older OAuth-server emulation, not a pattern to import as the core
  Entra resource-server flow.
- **Gateway limits:** existing-server docs say tools/resources, while the overview's availability note says
  tools only. Both exclude workspaces and prompts. The workshop uses tools only and records this discrepancy.
- **Inspector:** APIM articles retain a 0.9.0 tip; current Inspector release is 2.11.0 with legacy/modern negotiation.
  Prefer testing a maintained release, not downgrading controls to match an old tip.
- **Client configuration:** current VS Code docs prefer portable `.mcp.json` for new server configurations,
  with `.vscode/mcp.json` retained for compatibility. The repository supplies both for Microsoft Learn;
  each defines the same public documentation endpoint, with no credentials.
- **Network:** Standard v2 outbound integration plus a Flex private endpoint is documented. Outbound integration
  alone does not block direct public Function calls. Disable public access and prove private DNS/routing.
- **Telemetry:** upstream workbook structure is useful, but identity headers and exception text are unsuitable
  as authoritative or payload-free workshop audit data.
- **Optional clients:** distinguish product terminology such as Foundry "OAuth identity passthrough" (client identity
  to the MCP resource) from prohibited server-to-downstream token passthrough. The latter remains forbidden.

## Official reference register

Every row was last verified on 2026-10-14. This register covers the build plan's references and the additional
references used to resolve design choices.

| Module | Reference | Use and status |
|---|---|---|
| 00/02 | [Functions custom remote MCP quickstart](https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server) | Local run/deploy outline; C# SDK prerequisites lag the pinned sample. |
| 00/02 | [Functions MCP bindings](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp) | Isolated worker, endpoint, system key and host.json configuration. |
| 00/02 | [Flex Consumption hosting](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan) | Linux, scale-to-zero, instance sizing, cost drivers and networking. |
| 00/02 | [AzureRM Flex resource at v5.9.0](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown) | Supported user-assigned identity storage and public-access controls. Do not copy its key-based example. |
| 00 | [AzureRM registry](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0), [AzureAD registry](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0), [AzAPI registry](https://registry.terraform.io/providers/Azure/azapi/2.13.0) | Published candidate provider versions; combined schemas/runtime not yet validated. |
| 01 | [MCP specification](https://modelcontextprotocol.io/specification/2026-07-28), [architecture](https://modelcontextprotocol.io/specification/2026-07-28/architecture), [transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports), [tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools), [authorization](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization) | Current teaching reference; distinguish legacy wire examples. |
| 01 | [VS Code MCP configuration](https://code.visualstudio.com/docs/agent-customization/mcp-servers) | Trust, approvals, portable configuration and secure inputs. |
| 01 | [Inspector documentation](https://modelcontextprotocol.io/docs/tools/inspector) | UI, CLI, protocol negotiation, Node requirement and secret-storage caveat. |
| 03 | [App Service MCP authorization](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp) | Server-level authorization, preauthorization and PRM (**Preview**); not per-tool authorization. |
| 03 | [App Service MCP and VS Code](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode) | Client preauthorization and discovery; do not follow secret-creation defaults. |
| 03 | [Functions MCP tutorial](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial) | Select MCP extension path; self-hosted MCP is **Preview** and not selected. |
| 03 | [App roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps) | Distinguish role assignment from delegated scope consent. |
| 04 | [Expose an existing server](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server) | Streamable endpoint, minimum version, inherited diagnostics and streaming limitations. |
| 04 | [Secure MCP servers](https://learn.microsoft.com/azure/api-management/secure-mcp-servers) | Inbound/outbound boundaries; not permission to forward MCP tokens to downstream APIs. |
| 04 | [MCP overview](https://learn.microsoft.com/azure/api-management/mcp-server-overview) | Tier availability, governance, inventory and documented limitations. |
| 04 | [Programmatic MCP management](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) | API, policy and optional REST tool resource types; `2025-09-01-preview` (**Preview**). |
| 04 | [Validate Entra tokens](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy) | Exact tenant/audience and scope/role claim checks via platform policy. |
| 04 | [Outbound virtual network integration](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound) | Standard v2/Premium v2; dedicated subnet, delegation, network security group and permissions. |
| 04 | [Functions networking](https://learn.microsoft.com/azure/azure-functions/functions-networking-options) | Flex inbound private endpoints versus outbound integration; direct-access protection. |
| 04b | [Export REST to MCP](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server) | Optional operation-to-tool exercise; no prompts/resources; no response-body inspection. |
| 05 | [On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow) | Token A/Token B boundary and user-only delegation. Use libraries, not its client-secret example. |
| 05 | [Application trust in managed identity](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity) | Secretless client assertion, same-tenant trust and federated credential permissions. |
| 06 | [APIM Application Insights integration](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) | Managed-identity logger, resource-scoped Monitoring Metrics Publisher and diagnostics. |
| 06 | [Register and discover MCP servers](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server) | API Center asset, remote, environment, version and inventory metadata. |
| 06b | [Microsoft 365 BYO MCP](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) | **Preview**, review/approval workflow and supported-client restrictions; demo only. |
| 07 | [Foundry MCP authentication](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication) | Agent/project identity versus individual OAuth. Recheck selected feature availability before demo. |
| 07 | [Copilot Studio existing MCP server](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent) | Streamable HTTP and wizard authentication; manual-secret conflict remains unresolved. |

## Remaining evidence gates

- No Azure subscription was inspected and no runtime deployment compatibility was claimed.
- Region, quota, cost, consent, restricted deployment connectivity and optional client flows require module-specific
  verification and approval.
- Full execution of upstream notebooks and all their transitive assets is out of scope. Selected files were
  inspected for design suitability; future adaptation must inspect the exact code being imported.
- Before adapting source, add its full applicable license/notice and origin to THIRD-PARTY-NOTICES.md.
  Preserve copyright headers and mark changes where the upstream license requires it.

## Sources

The pinned upstream snapshots and official register above are the sources for this assessment.
Last verified: 2026-10-14.
'@

$files['LICENSE'] = @'
MIT License

Copyright (c) 2026 workshop-mcp contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'@

$files['README.md'] = @'
# Governed MCP on Azure — hands-on workshop

> **Status: work in progress.** This repository is built module by module with the GitHub Copilot app,
> following [`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md). Progress: [`docs/PROGRESS.md`](docs/PROGRESS.md).

A self-paced, end-to-end workshop that takes one Model Context Protocol (MCP) server from **open** to **governed** on Azure.

| Level | You add | You see |
|---|---|---|
| 0 | An open MCP server protected by a function key | Anyone with the key can call any tool, including write tools |
| 1 | Microsoft Entra ID authentication | 401 without a token, the token's audience and roles, unassigned users blocked |
| 2 | Azure API Management as the only entry point | Per-tool authorization, rate limiting, payload-free logs, direct calls refused |
| 3 | On-Behalf-Of vs app-only access | The same tool returns different results depending on who carries the rights |
| 4 | Observability and inventory | Who called which tool, when, with what result; the server listed in Azure API Center |

**Audience:** enterprise platform, identity and Microsoft 365 administrators (PowerShell, C#, Terraform)
and developers who are new to agents and MCP.
**Goal:** every participant can deploy, verify and destroy every module alone, in a non-production Azure subscription.

## Target architecture

```mermaid
flowchart LR
    C["MCP client<br/>VS Code + GitHub Copilot<br/>MCP Inspector"] -->|"Entra token<br/>audience = MCP server"| G["Azure API Management<br/>only entry point"]
    G -->|"same token<br/>same protected resource"| F["Azure Functions<br/>MCP server (.NET)"]
    F -->|"On-Behalf-Of"| U["Microsoft Graph / Azure Storage<br/>with the user's rights"]
    F -->|"Managed identity"| A["Azure Storage<br/>with the app's rights"]
    G -.-> L["Application Insights<br/>no payloads"]
    G -.->|"register gateway endpoint"| I["Azure API Center<br/>inventory"]
```

## Modules

| # | Module |
|---|---|
| 00 | Prerequisites and environment |
| 01 | Discover MCP (no Azure) |
| 02 | An "open" MCP server (level 0) |
| 03 | Identity with Microsoft Entra (level 1) |
| 04 | API Management as the only entry point (level 2) |
| 05 | On-Behalf-Of vs app-only (level 3) |
| 06 | Observe and inventory (level 4) |
| 07 | Optional: other clients (Microsoft Foundry, Copilot Studio) |
| 99 | Clean up |

What each module takes, builds, shows and validates: [`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md).

## How this repository is built

The workshop is written "as code" with the GitHub Copilot app:

| File | Role |
|---|---|
| [`.github/copilot-instructions.md`](.github/copilot-instructions.md) | Permanent rules: content, security invariants, stack, module contract |
| [`docs/BUILD-PLAN.md`](docs/BUILD-PLAN.md) | What to take, in which order, and what each module must show |
| [`docs/PROGRESS.md`](docs/PROGRESS.md) | Status and validation evidence of each module |
| [`.github/skills/workshop-module-builder/`](.github/skills/workshop-module-builder/SKILL.md) | Agent skill that builds, deploys and validates the next module |
| [`.github/agents/workshop-builder.agent.md`](.github/agents/workshop-builder.agent.md) | Custom agent that applies the skill |
| [`docs/COPILOT-RUNBOOK.md`](docs/COPILOT-RUNBOOK.md) | Step-by-step guide: sessions, modes and prompts |

Start with [`docs/COPILOT-RUNBOOK.md`](docs/COPILOT-RUNBOOK.md).

The [P1 recommendations](docs/BUILD-PLAN.md#p1-recommendations-design-only) describe the target tree,
networking and identity decisions. The [source assessment](docs/sources.md) selects the useful parts of official
samples, pins upstream snapshots, and records updates, licensing boundaries and unresolved compatibility gates.
**Modules are not implemented yet.** No Azure deployment has been validated.

The project includes a **Workshop build board** canvas under `.github/extensions/workshop-build-board/`.
In the Copilot app, ask: "Show the workshop build board." It reads and updates `docs/PROGRESS.md`.
The canvas SDK is **Preview**. Saving progress does not run module validation.

## Safety

- Use non-production subscriptions and synthetic data only.
- Preview features are labeled **Preview** wherever they are used.
- Every implemented module must ship a clean-up script; module 99 must remove workshop-owned resources.
- The key-only demonstration must use the MCP extension system key. Never publish an anonymous MCP endpoint.
- Keep live credentials, tenant data and confidential notes out of the repository and build board.

## Disclaimer

This is a community workshop. It is not an official Microsoft product, service or documentation, and it is provided
"as is" under the MIT License, without warranty. The official documentation linked in each module is the reference.

## Sources

[Verified sources and upstream reuse decisions](docs/sources.md). Last verified: 2026-10-14.
'@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
foreach ($relative in $files.Keys) {
    $target = Join-Path $Path ($relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $content = ($files[$relative] -replace "`r`n", "`n") + "`n"
    [System.IO.File]::WriteAllText($target, $content, $utf8NoBom)
    Write-Host "   + $relative"
}

# --- 4. Git and GitHub ---------------------------------------------------------
$repoUrl = ''
Push-Location -LiteralPath $Path
try {
    Write-Step 'Initializing Git and creating the first commit'
    Invoke-Native git @('init', '--initial-branch=main') | Out-Null
    if (-not $SkipGitHub) {
        Invoke-Native git @('config', '--local', 'user.name', $owner) | Out-Null
        Invoke-Native git @('config', '--local', 'user.email', "$ownerId+$owner@users.noreply.github.com") | Out-Null
    }
    Invoke-Native git @('-c', 'core.safecrlf=false', 'add', '--all') | Out-Null
    Invoke-Native git @('commit', '--quiet', '-m', 'Scaffold: workshop plan, verified sources, and build board',
        '-m', 'Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>') | Out-Null

    if (-not $SkipGitHub) {
        Write-Step "Creating and pushing $owner/$RepoName ($Visibility)"
        Invoke-Native gh @('repo', 'create', $RepoName, "--$Visibility", '--source', '.', '--remote', 'origin', '--push', '--description', $Description) | Out-Null
        Invoke-Native gh @('repo', 'edit', "$owner/$RepoName", '--add-topic', 'mcp,azure,workshop,github-copilot,entra-id,api-management') | Out-Null
        $repoUrl = Get-NativeOutput gh @('repo', 'view', "$owner/$RepoName", '--json', 'url', '--jq', '.url')
    }
}
finally {
    Pop-Location
}

# --- 5. Next steps -------------------------------------------------------------
Write-Step 'Done'
Write-Host "   Local folder: $Path"
if ($repoUrl) { Write-Host "   GitHub repository: $repoUrl" }
if ($SkipGitHub) { Write-Host '   GitHub: not published. Review all content and configure local noreply identity before publishing.' }
Write-Host @"

Next steps in GitHub Copilot app:
  1. Open $Path in a local session.
  2. Microsoft Learn is configured in .mcp.json and .vscode/mcp.json. Add it in the app if needed:
     /mcp add -> microsoft-learn, HTTP, https://learn.microsoft.com/api/mcp
  3. Read docs/sources.md and the P1 recommendations in docs/BUILD-PLAN.md.
  4. Ask: Show the workshop build board.
  5. Follow docs/COPILOT-RUNBOOK.md, one module per session/branch. No module is validated yet.
"@

if ($OpenVSCode -and (Test-Command 'code')) { & code $Path }

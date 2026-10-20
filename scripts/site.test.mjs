import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, rmSync, existsSync, mkdirSync, writeFileSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { buildSite, authorOnlyDocuments } from "./build-site.mjs";
import { screenshots } from "./portal-server.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));

test("Git preserves SVG bytes and binary PNG provenance on Windows checkouts", () => {
    const attributes = readFileSync(join(root, ".gitattributes"), "utf8");
    assert.match(attributes, /^\*\.svg text eol=lf$/m);
    assert.match(attributes, /^\*\.png binary$/m);
});

test("public site exports only the allowlist, with no capability, root URLs, private files or API dependency", (t) => {
    const temporary = mkdtempSync(join(tmpdir(), "workshop-site-"));
    t.after(() => rmSync(temporary, { recursive: true, force: true }));
    const output = join(temporary, "public");
    const result = buildSite(root, output);
    assert.equal(result.files, 82);
    assert.deepEqual(readdirSync(output).sort(), [".nojekyll", "assets", "index.html", "journey.json", "locale-fr.js"]);
    const html = readFileSync(join(output, "index.html"), "utf8");
    assert.match(html, /const staticSite = "true" === "true"/);
    assert.match(html, /const key = ""/);
    assert.doesNotMatch(html, /__BOARD_KEY__|__STATIC_SITE__|src="\/|image\.src = `\/assets/);
    assert.match(html, /Content-Security-Policy/);
    const journey = JSON.parse(readFileSync(join(output, "journey.json"), "utf8"));
    assert.equal(journey.revision, undefined);
    for (const language of [journey, journey.translations.fr]) {
        assert.equal(language.modules.length, 9);
        assert.match(language.documents.concepts.sourcePath, /MCP-CONCEPTS\.md$/);
        for (const term of ["tools/list", "tools/call", "get_service_health", "create_ticket", "Tools.Write", "JSON-RPC"]) {
            assert.ok(language.documents.concepts.content.includes(term), `Missing concept: ${term}`);
        }
        assert.match(language.documents.concepts.content, /2026-10-16/);
        assert.match(language.documents.concepts.content, /https:\/\/github.com\/microsoft\/mcp-for-beginners/);
        const concepts = language.documents.concepts.content;
        assert.equal((concepts.match(/^\*\*Question\s?:\*\*/gm) ?? []).length, 7);
        assert.equal((concepts.match(/^<summary>(?:Show answer|Afficher la réponse)<\/summary>$/gm) ?? []).length, 7);
        assert.doesNotMatch(concepts, /^\*\*(?:Answer|Réponse|Explain back|Expliquez|Predict|Prévoyez)\s?:\*\*/m);
        assert.match(concepts, /!\[[^\]]+\]\((?:\.\.\/)+assets\/architecture\/05\.(en|fr)\.svg\)/);
        assert.match(language.documents.presenter.sourcePath, /PRESENTER\.md$/);
        assert.match(language.documents.presenter.content, /\?lang=fr#\/start/);
        assert.match(language.documents.presenter.content, /\?lang=en#\/start/);
        assert.match(language.documents.gettingStarted.content, /PRESENTER\.md/);
        const local = language.modules.find((module) => module.module === "01");
        assert.equal(local.status, "authored");
        assert.match(local.guide, /get_service_health/);
        assert.match(local.guide, /isError: false/);
        assert.equal(local.validation.powershell, "modules/01-discover-mcp/validate.ps1");
        assert.equal(local.validation.bash, "modules/01-discover-mcp/validate.sh");
        const open = language.modules.find((module) => module.module === "02");
        assert.equal(open.status, "validated");
        assert.match(open.guide, /webhookAuthorizationLevel/);
        assert.match(open.guide, /create_ticket/);
        assert.match(open.guide, /HTTP 401/);
        assert.equal(open.validation.powershell, "modules/02-open-server/validate.ps1");
        assert.equal(open.validation.bash, "modules/02-open-server/validate.sh");
        const entra = language.modules.find((module) => module.module === "03");
        assert.equal(entra.status, "validated");
        assert.match(entra.guide, /user_impersonation/);
        assert.match(entra.guide, /AADSTS50105/);
        assert.match(entra.guide, /HTTP 401/);
        assert.equal(entra.validation.powershell, "modules/03-entra-authentication/validate.ps1");
        assert.equal(entra.validation.bash, "modules/03-entra-authentication/validate.sh");
        const gateway = language.modules.find((module) => module.module === "04");
        assert.equal(gateway.status, "validated");
        assert.match(gateway.guide, /validate-azure-ad-token/);
        assert.match(gateway.guide, /Tools\.Write/);
        assert.match(gateway.guide, /HTTP 429/);
        assert.match(gateway.guide, /Preview/);
        assert.equal(gateway.validation.powershell, "modules/04-governed-gateway/validate.ps1");
        assert.equal(gateway.validation.bash, "modules/04-governed-gateway/validate.sh");
        const delegated = language.modules.find((module) => module.module === "05");
        assert.equal(delegated.status, "validated");
        assert.match(delegated.guide, /On-Behalf-Of/);
        assert.match(delegated.guide, /isError/);
        assert.match(delegated.guide, /api:\/\/AzureADTokenExchange/);
        assert.equal(delegated.validation.powershell, "modules/05-delegated-and-app-only/validate.ps1");
        assert.equal(delegated.validation.bash, "modules/05-delegated-and-app-only/validate.sh");
        for (const [code, folder] of [["06", "06-observe-inventory"], ["07", "07-clients"]]) {
            const module = language.modules.find((item) => item.module === code);
            assert.ok(module.guide, `Module ${code} must publish its existing guide`);
            assert.equal(module.validation.powershell, `modules/${folder}/validate.ps1`);
            assert.equal(module.validation.bash, `modules/${folder}/validate.sh`);
            assert.equal(module.sourcePath, `modules/${folder}/README${language.language === "fr" ? ".fr" : ""}.md`);
            assert.match(module.guide, /<summary>(Show answer|Afficher la réponse)<\/summary>/);
            assert.match(module.guide, new RegExp(`!\\[[^\\]]+\\]\\(\\.\\./\\.\\./assets/architecture/${code}\\.${language.language}\\.svg\\)`));
        }
        const observe = language.modules.find((item) => item.module === "06").guide;
        for (const field of ["caller-oid", "workshop-mcp-gateway", "isError: true", "200"]) assert.ok(observe.includes(field));
        const clients = language.modules.find((item) => item.module === "07").guide;
        for (const field of ["Client secret", "Manual", "stdio", "OBO", "scope"]) assert.ok(clients.includes(field));
        for (const module of language.modules) {
            if (["02", "03", "04", "05"].includes(module.module)) {
                assert.match(module.guide, language.language === "fr" ?
                    /### Lire la documentation au moment de la démonstration/ : /### Read alongside the demonstration/);
            }
            assert.match(module.diagramSource.content, /^flowchart LR\n/);
            assert.ok(language.documents.architecture.content.replaceAll("\r\n", "\n").includes(module.diagramSource.content));
            for (const path of Object.values(module.diagram)) {
                assert.match(path, /^assets\/architecture\//);
                assert.ok(existsSync(join(output, path)));
            }
            for (const key of authorOnlyDocuments) assert.ok(!Object.hasOwn(language.documents, key), `${key} must not be published`);
        }
    }
    assert.ok(!Object.hasOwn(journey, "openDecisions"));
    assert.deepEqual(readdirSync(join(output, "assets")).sort(), ["architecture", "icons", "screenshots"]);
    assert.deepEqual(readdirSync(join(output, "assets", "screenshots")).sort(), screenshots.map((name) => `${name}.png`).sort());
    assert.throws(() => buildSite(root, output), { code: "EEXIST" });
});

test("static export refuses linked source directories before reading their contents or creating output", (t) => {
    const temporary = mkdtempSync(join(tmpdir(), "workshop-site-link-"));
    t.after(() => rmSync(temporary, { recursive: true, force: true }));
    const fixture = join(temporary, "repository");
    const outside = join(temporary, "outside");
    mkdirSync(fixture);
    mkdirSync(outside);
    writeFileSync(join(outside, "PROGRESS.md"), "Synthetic content that must not be read.");
    symlinkSync(outside, join(fixture, "docs"), process.platform === "win32" ? "junction" : "dir");
    const output = join(temporary, "public");
    assert.throws(() => buildSite(fixture, output), /regular files inside the repository/);
    assert.equal(existsSync(output), false);
});

test("bilingual cleanup guides reuse the generated Mermaid and all five portable alert types", () => {
    for (const language of ["en", "fr"]) {
        const suffix = language === "fr" ? ".fr" : "";
        const guide = readFileSync(join(root, "modules", "99-cleanup", `README${suffix}.md`), "utf8").replaceAll("\r\n", "\n");
        const diagrams = readFileSync(join(root, "assets", "architecture", `STEPS${suffix}.md`), "utf8").replaceAll("\r\n", "\n");
        const graphs = [...guide.matchAll(/^```mermaid\n([\s\S]*?)\n```/gm)];
        assert.equal(graphs.length, 1);
        const cleanup = diagrams.slice(diagrams.indexOf("## 99 -"), diagrams.indexOf("\n## Sources"));
        assert.equal(graphs[0][1], /^```mermaid\n([\s\S]*?)\n```/m.exec(cleanup)[1]);
        for (const type of ["TIP", "NOTE", "IMPORTANT", "WARNING", "CAUTION"]) {
            assert.ok(guide.includes(`> [!${type}]`), `${language}: ${type}`);
        }
        for (const format of ["svg", "png"]) {
            assert.ok(guide.includes(`../../assets/architecture/99.${language}.${format}`));
        }
        assert.match(guide, /<details>\n<summary>[^<]+<\/summary>/);
    }
});

test("authentication demonstrations link matching Learn/API references in both languages before validation", () => {
    const references = {
        "02-open-server": [
            "azure/azure-functions/function-keys-how-to",
            "azure/azure-functions/functions-bindings-mcp",
            "azure/azure-functions/functions-bindings-mcp-tool-trigger",
            "dotnet/api/azure.storage.queues.queueclient.sendmessageasync",
        ],
        "03-entra-authentication": [
            "azure/templates/microsoft.web/sites/config-authsettingsv2",
            "entra/identity-platform/howto-restrict-your-app-to-a-set-of-users",
            "entra/identity-platform/scopes-oidc",
            "entra/identity-platform/howto-add-app-roles-in-apps",
        ],
        "04-governed-gateway": [
            "azure/api-management/validate-azure-ad-token-policy",
            "azure/api-management/choose-policy",
            "azure/api-management/rate-limit-by-key-policy",
            "azure/api-management/monitor-mcp-servers",
            "azure/api-management/manage-mcp-servers-rest-api",
        ],
        "05-delegated-and-app-only": [
            "dotnet/api/azure.identity.onbehalfofcredential",
            "dotnet/api/azure.identity.managedidentitycredential",
            "graph/api/user-get?view=graph-rest-1.0",
            "rest/api/storageservices/get-blob#authorization",
            "dotnet/api/azure.storage.blobs.specialized.blobbaseclient.downloadcontentasync",
            "entra/workload-id/workload-identity-federation-config-app-trust-managed-identity",
        ],
    };
    const register = readFileSync(join(root, "docs", "sources.md"), "utf8");
    for (const [folder, required] of Object.entries(references)) {
        const languages = [];
        for (const language of ["en", "fr"]) {
            const guide = readFileSync(join(root, "modules", folder, language === "en" ? "README.md" : "README.fr.md"), "utf8");
            const heading = language === "en" ? "### Read alongside the demonstration" :
                "### Lire la documentation au moment de la démonstration";
            const start = guide.indexOf(heading);
            const results = guide.indexOf(language === "en" ? "## What you should see" : "## Ce que vous devez voir");
            const validation = guide.indexOf(language === "en" ? "\n## Validate" : "\n## Valider");
            assert.ok(results >= 0 && start > results && validation > start);
            const section = guide.slice(start, validation);
            assert.match(section, /2026-10-16/);
            const urls = [...section.matchAll(/\[[^\]]+\]\((https:\/\/learn\.microsoft\.com\/[^)]+)\)/g)].map((match) => match[1]);
            for (const path of required) assert.ok(urls.includes(`https://learn.microsoft.com/${path}`), `${folder}/${language}: ${path}`);
            for (const url of urls) assert.ok(register.includes(url), `Unregistered source: ${url}`);
            const rows = section.split(/\r?\n/).filter((line) => line.startsWith("| ")).slice(1);
            assert.ok(rows.length >= 4, `${folder}/${language}: missing demonstration rows`);
            for (const row of rows) {
                assert.ok(row.includes("https://learn.microsoft.com/"), `${folder}/${language}: demonstration without a Learn link`);
                if (/configure-authentication-mcp|manage-mcp-servers-rest-api/.test(row)) assert.match(row, /Preview/);
            }
            languages.push([...new Set(urls)].sort());
        }
        assert.deepEqual(languages[0], languages[1], `${folder}: EN/FR references differ`);
    }
});

test("presenter and delegation lessons separate plan, approval and apply instead of offering one bulk paste", () => {
    for (const parts of [
        ["docs", "PRESENTER.md"], ["docs", "fr", "PRESENTER.md"],
        ["modules", "05-delegated-and-app-only", "README.md"],
        ["modules", "05-delegated-and-app-only", "README.fr.md"],
    ]) {
        const source = readFileSync(join(root, ...parts), "utf8");
        for (const block of source.matchAll(/^```powershell\r?\n([\s\S]*?)\r?\n```/gm)) {
            const plans = /terraform[^\r\n]*\splan\s/.test(block[1]);
            const applies = /terraform[^\r\n]*\sapply\s/.test(block[1]);
            assert.ok(!(plans && applies), `${parts.join("/")}: do not combine plan and apply`);
            if (applies) {
                const explanation = source.slice(0, block.index).split(/^### /m).at(-1);
                assert.match(explanation, /\*\*STOP/);
                assert.match(block[1], /if \(\$LASTEXITCODE -ne 0\)/);
            }
        }
    }
});

test("bilingual Azure inspection commands fail closed and only list the selected group's participant tag", (t) => {
    const snippets = ["docs/DEPLOYMENT.md", "docs/fr/DEPLOYMENT.md"].map((path) => {
        const document = readFileSync(join(root, ...path.split("/")), "utf8").replaceAll("\r\n", "\n");
        const inspection = document.split(/^## (?:Inspect the resources from your terminal|Voir les ressources depuis votre terminal)\n/m)[1]?.split(/^## /m)[0];
        assert.ok(inspection, "Resource inspection must have a dedicated section");
        const blocks = [...inspection.matchAll(/^```powershell\n([\s\S]*?)\n```/gm)];
        assert.equal(blocks.length, 4, "Teach context, group, tag and query separately");
        for (const block of blocks) assert.ok(block[1].split("\n").length <= 9, "Inspection commands must stay short");
        return blocks.map((match) => match[1]).join("\n");
    });
    assert.ok(snippets[0]);
    assert.equal(snippets[0], snippets[1], "EN/FR must offer the same guarded commands");
    const source = `
$ErrorActionPreference = 'Stop'
$tenant = [guid]::NewGuid().ToString()
$subscription = [guid]::NewGuid().ToString()
function global:terraform {
    $global:LASTEXITCODE = 0
    if ($args[0] -cne "-chdir=$(Join-Path 'infra' 'workload')") { throw 'Unexpected Terraform root.' }
    switch ($args -join ' ') {
        "-chdir=$(Join-Path 'infra' 'workload') output -raw resource_group_name" {
            if ($global:mode -eq 'no-state') { $global:LASTEXITCODE = 1; return }
            'rg-synthetic'; return
        }
        "-chdir=$(Join-Path 'infra' 'workload') output -json resource_tags" {
            if ($global:mode -eq 'tags-fail') { $global:LASTEXITCODE = 1; return }
            if ($global:mode -eq 'invalid-json') { 'not-json'; return }
            @{workshop=$(if ($global:mode -eq 'invalid-tag') { '' } else { 'mcp-p01-0123456789' })} | ConvertTo-Json
            return
        }
        default { throw 'Unexpected Terraform command.' }
    }
}
function global:az {
    $global:LASTEXITCODE = 0
    switch ("$($args[0]) $($args[1])") {
        'cloud show' { @{name='AzureCloud'} | ConvertTo-Json; return }
        'account show' {
            $global:contextReads++
            @{id=$subscription; tenantId=$(if ($global:mode -eq 'mismatch' -or ($global:mode -eq 'context-changed' -and $global:contextReads -gt 1)) { [guid]::NewGuid().ToString() } else { $tenant })
              state='Enabled'; environmentName='AzureCloud'; userType='user'} | ConvertTo-Json
            return
        }
        'resource list' {
            $global:resourceReads++
            $values = @($args)
            if ($values[$values.IndexOf('--subscription') + 1] -ne $subscription -or
                $values[$values.IndexOf('--resource-group') + 1] -ne 'rg-synthetic' -or
                $values -contains '--tag' -or
                $values[$values.IndexOf('--query') + 1] -cne "[?tags.workshop=='mcp-p01-0123456789'].{Name:name,Type:type,Location:location}") {
                throw 'Query widened beyond the approved group and participant.'
            }
            if ($global:mode -eq 'resource-fail') { $global:LASTEXITCODE = 1; return }
            if ($global:mode -ne 'empty') { 'synthetic-resource Synthetic/Resource testregion' }
            return
        }
        default { throw 'Unexpected Azure command.' }
    }
}
function Invoke-Inspection {
${snippets[0]}
}
foreach ($global:mode in @('success', 'empty', 'no-context', 'mismatch', 'context-changed', 'no-state', 'tags-fail', 'invalid-json', 'invalid-tag', 'resource-fail')) {
    $env:ARM_TENANT_ID = $(if ($global:mode -eq 'no-context') { '' } else { $tenant })
    $env:ARM_SUBSCRIPTION_ID = $subscription
    $global:resourceReads = 0
    $global:contextReads = 0
    $failed = $false
    try { Invoke-Inspection } catch { $failed = $true }
    $expectSuccess = $global:mode -in @('success', 'empty')
    if ($failed -eq $expectSuccess) { throw "Wrong outcome: $global:mode" }
    $expectedReads = $(if ($global:mode -in @('success', 'empty', 'resource-fail')) { 1 } else { 0 })
    if ($global:resourceReads -ne $expectedReads) { throw "Unexpected read count: $global:mode" }
    Write-Output "PASS $global:mode"
}
`;
    const environment = Object.fromEntries(Object.entries(process.env).filter(([name]) => !/^(ARM_|AZURE_)/i.test(name)));
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", source], {
        cwd: root, env: environment, encoding: "utf8", timeout: 30000,
    });
    if (result.error?.code === "ENOENT") { t.skip("PowerShell 7 is required for mocked inspection checks."); return; }
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    assert.equal((result.stdout.match(/PASS /g) || []).length, 10, result.stdout);
});

test("module guides keep exact, copyable prompts and the KQL file in sync", () => {
    const repo = fileURLToPath(new URL("../", import.meta.url));
    const kql = readFileSync(join(repo, "modules", "06-observe-inventory", "queries", "mcp-traffic.kql"), "utf8").replace(/\r\n/g, "\n").trim();
    for (const name of ["README.md", "README.fr.md"]) {
        const guide = readFileSync(join(repo, "modules", "06-observe-inventory", name), "utf8").replace(/\r\n/g, "\n");
        const block = /```kql\n([\s\S]*?)\n```/.exec(guide);
        assert.ok(block, `${name} must show the exact KQL query in a kql block`);
        assert.equal(block[1].trim(), kql, `${name} KQL block must match queries/mcp-traffic.kql`);
    }
    for (const folder of ["02-open-server", "03-entra-authentication", "04-governed-gateway", "05-delegated-and-app-only", "06-observe-inventory", "07-clients"]) {
        for (const name of ["README.md", "README.fr.md"]) {
            const guide = readFileSync(join(repo, "modules", folder, name), "utf8").replace(/\r\n/g, "\n");
            const prompts = [...guide.matchAll(/^\s*```prompt\n([\s\S]*?)\n\s*```/gm)].map((match) => match[1].trim());
            assert.ok(prompts.length >= 1, `${folder}/${name} must give at least one exact prompt`);
            for (const prompt of prompts) {
                assert.ok(prompt.length > 30 && !/<[a-z-]+>/.test(prompt), `${folder}/${name}: prompts must be complete, with no placeholder`);
                assert.doesNotMatch(prompt, /eyJ[A-Za-z0-9_-]{8,}|Bearer |client_secret/i, `${folder}/${name}: prompts must contain no secret`);
            }
        }
    }
});

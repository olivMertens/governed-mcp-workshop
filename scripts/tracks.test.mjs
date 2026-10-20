import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync, mkdtempSync, writeFileSync, rmSync, mkdirSync, copyFileSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { readJourney } from "../.github/extensions/workshop-build-board/journey.mjs";
import { parseProgress } from "../.github/extensions/workshop-build-board/progress.mjs";
import { screenshots } from "./portal-server.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const html = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "board.html"), "utf8");
const journey = () => readJourney(root, parseProgress(readFileSync(join(root, "docs", "PROGRESS.md"), "utf8")));
const fences = (text, language) => [...text.matchAll(/^```([^\r\n]*)\r?\n([\s\S]*?)^```/gm)]
    .filter((match) => !language || match[1].split(/\s/)[0] === language).map((match) => match[2]);

test("every published module exports two independent bilingual guides, with module 01 shared", () => {
    const state = journey();
    for (const localized of [state, state.translations.fr]) {
        for (const module of localized.modules) {
            for (const [track, guide] of Object.entries(module.guides)) {
                assert.ok(guide.guide, `${localized.language}/${module.module}/${track}: guide missing`);
                assert.equal(guide.guide, readFileSync(join(root, guide.sourcePath), "utf8"));
                assert.match(guide.guide, /^## Sources\r?$/m);
            }
            if (module.module === "01") {
                assert.deepEqual(module.guides["low-code"], module.guides.terraform);
                continue;
            }
            assert.notEqual(module.guides["low-code"].sourcePath, module.guides.terraform.sourcePath);
            assert.match(module.guides["low-code"].sourcePath, /LOW-CODE(?:\.fr)?\.md$/);
            assert.match(module.guides.terraform.sourcePath, /README(?:\.fr)?\.md$/);
            assert.doesNotMatch(module.guides.terraform.guide,
                /^#{2,4} .*(?:Low-code track|Parcours low-code|A2 and A3 in the low-code|A2 et A3 dans le parcours low-code)/im);
            assert.doesNotMatch(fences(module.guides["low-code"].guide).join("\n"),
                /\bterraform\s+(?:-chdir|output|plan|apply|destroy|init|validate|test)\b/i);
            assert.doesNotMatch(module.guides["low-code"].guide, /\]\(\.\.\/(?:00|02|03|04|05|06|07|99)-[^)]+\/README(?:\.fr)?\.md(?:#[^)]*)?\)/,
                `${module.guides["low-code"].sourcePath}: another module must stay in the same track`);
        }
    }
});

test("track selection changes the guide, source and questions without mutating source data", () => {
    const source = html.slice(html.indexOf("function trackModules("), html.indexOf("let loading ="));
    const select = new Function(`${source}; return trackModules;`)();
    const readTrack = new Function(`${html.slice(html.indexOf("function readTrack("), html.indexOf("let selectedTrack ="))}; return readTrack;`)();
    assert.equal(readTrack("https://example.invalid/?lang=fr&track=low-code#/module/04"), "low-code");
    assert.equal(readTrack("https://example.invalid/?track=terraform"), "terraform");
    assert.equal(readTrack("https://example.invalid/?track=invalid"), null);
    assert.equal(readTrack("https://example.invalid/"), null);
    for (const localized of [journey(), journey().translations.fr]) {
        const before = JSON.stringify(localized.modules);
        for (const track of ["low-code", "terraform"]) {
            for (const module of select(localized.modules, track)) {
                assert.equal(module.guide, module.guides[track].guide);
                assert.equal(module.sourcePath, module.guides[track].sourcePath);
                assert.equal(module.originalGuide, null);
            }
        }
        assert.equal(JSON.stringify(localized.modules), before);
    }
    assert.match(html, /collectQuestions\(module\.guide\)/);
    assert.match(html, /pdfAction\([^\n]+module\.guide, module\.sourcePath/);
    assert.match(html, /selectedTrack = readTrack\(location\.href\);[\s\S]*activateLanguage\(\);[\s\S]*render\(true\);/);
    assert.ok(/if \(!selectedTrack && module\.module !== "01"\)[\s\S]*content\.append\(trackChoices\(\)\);[\s\S]*return;/.test(html),
        "Deployment modules must ask for a track before rendering commands");
    assert.match(html, /if \(selectedTrack && module\.guide === null\)/);
});

test("track cards retain the current module and language and do not silently migrate resources", () => {
    const source = html.slice(html.indexOf("function trackUrl("), html.indexOf("function dependencyNotice("));
    function node(tag, text, className) {
        return {
            tag, text, className, children: [], dataset: {}, attributes: {}, handlers: {},
            append(...items) { this.children.push(...items); },
            setAttribute(name, value) { this.attributes[name] = value; },
            addEventListener(name, handler) { this.handlers[name] = handler; },
        };
    }
    for (const hash of ["#/module/04", "#/tracks"]) {
        const location = { href: `https://example.invalid/workshop/?lang=fr&track=terraform${hash}`, hash };
        const events = [];
        const api = new Function("location", "URL", "element", "link", "t", "history", "activateLanguage", "render", `
            let selectedTrack = "terraform";
            ${source}
            return { trackChoices, get track() { return selectedTrack; } };
        `)(location, URL, node, (text, href, className) => Object.assign(node("a", text, className), { href }),
            (text) => text, { pushState: (...args) => events.push(args) },
            () => events.push("activate"), (focus) => events.push(["render", focus]));
        const choices = api.trackChoices();
        const options = choices.children.find((child) => child.className === "workspace-options").children;
        const target = new URL(options[0].href);
        assert.equal(target.searchParams.get("lang"), "fr");
        assert.equal(target.searchParams.get("track"), "low-code");
        assert.equal(target.hash, hash.startsWith("#/module") ? hash : "#/module/00");
        assert.equal(options[1].attributes["aria-current"], "true");
        options[0].handlers.click({ preventDefault() { events.push("prevent"); } });
        assert.equal(api.track, "low-code");
        assert.deepEqual(events.slice(1), [[null, "", target.href], "activate", ["render", true]]);
        assert.match(JSON.stringify(choices), /clean up your old track/);
    }
});

test("low-code guides have intact steps, concrete results, valid local links and real screenshot assets", () => {
    const split = new Function(`${html.slice(html.indexOf("function lessonSteps("), html.indexOf("function guidedDocument("))}; return lessonSteps;`)();
    const state = journey();
    for (const localized of [state, state.translations.fr]) {
        for (const module of localized.modules.filter((entry) => entry.module !== "01")) {
            const { guide, sourcePath } = module.guides["low-code"];
            assert.ok(guide, `${sourcePath}: missing guide`);
            const pages = split(guide.replaceAll("\r\n", "\n"));
            assert.equal(pages[0].title, localized.language === "fr" ? "Objectif" : "Goal",
                `${sourcePath}: first reading step must be Goal/Objectif`);
            assert.deepEqual(pages.flatMap((page) => fences(page.content)), fences(guide.replaceAll("\r\n", "\n")));
            assert.match(guide, localized.language === "fr" ? /## (?:Valider|Validation)/ : /## Validate/);
            assert.match(guide, localized.language === "fr" ? /## (?:Nettoyer|Nettoyage)/ : /## Clean up/);
            assert.match(guide, /(?:Expected result|Résultat attendu)/);
            assert.match(guide, /\bHTTP\b/);
            for (const match of guide.matchAll(/!?\[[^\]]*\]\(([^)\s]+)\)/g)) {
                const target = match[1];
                if (/^(?:https?:|#)/.test(target)) continue;
                const path = decodeURIComponent(target.split("#")[0]);
                assert.ok(existsSync(resolve(dirname(join(root, sourcePath)), path)), `${sourcePath}: broken ${target}`);
                if (path.includes("/screenshots/")) {
                    const filename = path.split("/").at(-1);
                    assert.ok(screenshots.includes(filename.replace(/\.png$/, "")), `${sourcePath}: unexported screenshot ${filename}`);
                }
            }
            if (["02", "03", "04", "05", "06", "07"].includes(module.module)) {
                assert.match(guide, /!\[[^\]]+\]\((?:\.\.\/)+assets\/screenshots\/[^)]+\.png\)/,
                    `${sourcePath}: a concrete existing capture is required`);
            }
        }
    }
});

test("all low-code PowerShell commands parse without running Azure or Terraform", (t) => {
    const temporary = mkdtempSync(join(tmpdir(), "workshop-track-syntax-"));
    t.after(() => rmSync(temporary, { recursive: true, force: true }));
    const state = journey();
    const blocks = [state, state.translations.fr].flatMap((localized) =>
        localized.modules.filter((module) => module.module !== "01").flatMap((module) => {
            const { guide, sourcePath } = module.guides["low-code"];
            return fences(guide, "powershell").map((code, index) => ({ path: sourcePath, index, code }));
        }));
    assert.ok(blocks.length >= 30, "Check actual runnable content, not just track labels");
    const input = join(temporary, "blocks.json");
    writeFileSync(input, JSON.stringify(blocks));
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", `
        $ErrorActionPreference = 'Stop'
        $blocks = Get-Content -LiteralPath '${input.replaceAll("'", "''")}' -Raw | ConvertFrom-Json
        foreach ($block in $blocks) {
            $errors = $null
            [void][Management.Automation.Language.Parser]::ParseInput($block.code, [ref]$null, [ref]$errors)
            if ($errors.Count) { throw "$($block.path) block $($block.index): $($errors.Message -join '; ')" }
        }
        Write-Output "PASS $($blocks.Count) low-code PowerShell blocks parsed; no command executed."
    `], { encoding: "utf8", timeout: 30000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
});

test("low-code resource inspection needs no state and stays scoped for new and administrator-provided groups", (t) => {
    const commands = ["docs/LOW-CODE-DEPLOYMENT.md", "docs/fr/LOW-CODE-DEPLOYMENT.md"].map((path) =>
        fences(readFileSync(join(root, path), "utf8"), "powershell").slice(1).join("\n"));
    assert.equal(commands[0], commands[1]);
    assert.doesNotMatch(commands[0], /\bterraform\b/);
    const temporary = mkdtempSync(join(tmpdir(), "workshop-low-code-inspect-"));
    t.after(() => rmSync(temporary, { recursive: true, force: true }));
    mkdirSync(join(temporary, "scripts"));
    mkdirSync(join(temporary, ".workshop"));
    copyFileSync(join(root, "scripts", "context-common.ps1"), join(temporary, "scripts", "context-common.ps1"));
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", `
        $ErrorActionPreference = 'Stop'
        Get-ChildItem Env: | Where-Object { $_.Name -match '^(ARM_|AZURE_)' } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
        $env:ARM_TENANT_ID = [guid]::NewGuid().ToString()
        $env:ARM_SUBSCRIPTION_ID = [guid]::NewGuid().ToString()
        function global:terraform { throw 'Low-code inspection must never read state.' }
        function global:az {
            $global:LASTEXITCODE = 0
            switch ("$($args[0]) $($args[1])") {
                'cloud show' { @{ name='AzureCloud' } | ConvertTo-Json; return }
                'account show' {
                    @{ id=$env:ARM_SUBSCRIPTION_ID; tenantId=$env:ARM_TENANT_ID; state='Enabled'; environmentName='AzureCloud'; userType='user' } | ConvertTo-Json
                    return
                }
                'resource list' {
                    $values = @($args)
                    if ($values[$values.IndexOf('--subscription') + 1] -cne $env:ARM_SUBSCRIPTION_ID -or
                        $values[$values.IndexOf('--resource-group') + 1] -cne $global:expectedGroup -or
                        $values[$values.IndexOf('--query') + 1] -cne "[?tags.workshop=='$global:expectedTag'].{Name:name,Type:type,Location:location}" -or
                        $values -contains '--tag') { throw 'Inspection widened beyond the selected participant and group.' }
                    Write-Output 'synthetic-resource Synthetic/Resource testregion'
                    return
                }
                default { throw 'Unexpected Azure operation in read-only inspection.' }
            }
        }
        foreach ($participantPrefix in @('p01', 'p1234567')) {
            foreach ($existing in @($null, 'rg-synthetic-admin')) {
                $global:expectedTag = "mcp-$($participantPrefix)lc-0123456789abcdef"
                $global:expectedGroup = if ($existing) { $existing } else { "rg-$global:expectedTag" }
                @{ participant_prefix=$participantPrefix; resource_suffix='0123456789abcdef'; location='westeurope';
                   owner='alice'; expiry=[datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd');
                   existing_resource_group_name=$existing } | ConvertTo-Json | Set-Content .\\.workshop\\participant.tfvars.json
                ${commands[0]}
                if ($resourceGroup -cne $global:expectedGroup -or $workshopTag -cne $global:expectedTag) { throw 'Derived names changed.' }
            }
        }
        Write-Output 'PASS four low-code group/tag scopes; synthetic Azure only.'
    `], { cwd: temporary, encoding: "utf8", timeout: 30000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
});

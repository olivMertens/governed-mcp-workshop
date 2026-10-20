import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, rmSync, existsSync, mkdirSync, writeFileSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { runInNewContext } from "node:vm";
import { buildSite, authorOnlyDocuments } from "./build-site.mjs";
import { screenshots } from "./portal-server.mjs";
import { readJourney } from "../.github/extensions/workshop-build-board/journey.mjs";
import { parseProgress } from "../.github/extensions/workshop-build-board/progress.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));

test("getting started offers tracks without a workspace choice and checks tools after cloning", () => {
    const html = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "board.html"), "utf8");
    const source = html.slice(html.indexOf("function showStart()"), html.indexOf("function deploymentContext()"));
    const clone = "git clone --branch main https://github.com/olivMertens/governed-mcp-workshop.git";
    const node = (tag, text, ...children) => ({
        tag, text, children,
        append(...items) { this.children.push(...items); },
    });
    for (const selectedTrack of [null, "terraform", "low-code"]) {
        const content = node("main");
        runInNewContext(`${source}\nshowStart();`, {
            selectedTrack, content, element: node, externalLink: node, link: node, notice: node,
            commandBlock: node, disclosure: (title, ...children) => node("details", title, ...children),
            markdown: node, trackChoices: () => node("tracks"),
            state: { environment: { tools: true }, documents: { gettingStarted: { content: "guide", sourcePath: "guide.md" } } },
        });
        const rendered = JSON.stringify(content);
        assert.equal(content.children.filter((item) => item.tag === "tracks").length, 1);
        assert.doesNotMatch(rendered, /Choose your workspace|VS Code dev container|Codespaces/);
        const commands = content.children.flatMap((item) => [item, ...item.children])
            .filter((item) => item.tag?.startsWith("Clone repository /"));
        assert.equal(commands.length, 1);
        assert.equal(commands[0].text, `${clone}\nif ($LASTEXITCODE -ne 0) { throw 'Clone failed. Do not continue in another directory.' }\nSet-Location .\\governed-mcp-workshop`);
        assert.doesNotMatch(rendered, /bash/i);
        assert.ok(commands.every((item) => item.children[1] === false), "Shell commands must not be translated");
        if (selectedTrack) {
            assert.ok(rendered.indexOf(clone) < rendered.indexOf("Check tools / PowerShell"));
            assert.ok(rendered.includes(`check-tools.ps1 -Track ${selectedTrack}`));
        }
        else assert.ok(!rendered.includes("Check tools / PowerShell"));
        assert.match(rendered, /https:\/\/github.com\/olivMertens\/governed-mcp-workshop/);
        assert.match(rendered, /The repository is public: HTTPS cloning needs no GitHub account\./);
        assert.match(rendered, /Keep your private .workshop files and Terraform state/);
    }
    assert.doesNotMatch(html, /workspaceChoices/);
    assert.match(html, /navLink\("start", "Get started", "terminal"\)/);
    assert.match(html, /\["#\/start", "#\/start\/devcontainer", "#\/start\/local", "#\/start\/codespaces"\]\.includes\(route\)\) showStart\(\)/);
    for (const parts of [["docs", "GETTING-STARTED.md"], ["docs", "fr", "GETTING-STARTED.md"]]) {
        const guide = readFileSync(join(root, ...parts), "utf8").replaceAll("\r\n", "\n");
        assert.ok(guide.includes(`\`\`\`bash\n${clone} && \\\n  cd governed-mcp-workshop\n\`\`\``));
    }
});

test("Git preserves SVG bytes and binary PNG provenance on Windows checkouts", () => {
    const attributes = readFileSync(join(root, ".gitattributes"), "utf8");
    assert.match(attributes, /^\*\.svg text eol=lf$/m);
    assert.match(attributes, /^\*\.png binary$/m);
});

test("PowerShell presentation removes bash alternatives before lesson splitting and PDF rendering without changing sources", () => {
    const html = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "board.html"), "utf8");
    const helpers = html.slice(html.indexOf("function powershellContent("), html.indexOf("function activateLanguage("));
    const tracks = html.slice(html.indexOf("function trackModules("), html.indexOf("let loading ="));
    const { powershellContent, powershellPresentation } = new Function(`${tracks}\n${helpers}; return { powershellContent, powershellPresentation };`)();
    const command = "Write-Output 'unchanged'\n# ### Bash is just code";
    const fixture = `## Steps
### PowerShell
\`\`\`powershell
${command}
\`\`\`
### Bash
Alternative instructions.
\`\`\`bash
echo omitted
\`\`\`
> **Expected result** — omitted
#### Nested bash heading
Also omitted.
## Validate
Keep this result.
<details>
<summary>Vous utilisez bash ?</summary>
<details>
<summary>Nested</summary>
Hidden.
</details>
\`\`\`sh
echo omitted
\`\`\`
</details>
<details>
<summary>Keep this answer</summary>
Keep this explanation.
</details>
Or, using bash in another terminal:
\`\`\`bash
echo omitted
\`\`\`
## Sources
Keep sources.`;
    const filtered = powershellContent(fixture);
    assert.ok(filtered.includes(command));
    assert.doesNotMatch(filtered, /omitted|Alternative instructions|Nested bash heading|Vous utilisez bash|Hidden|Or, using bash/);
    assert.match(filtered, /## Validate\nKeep this result/);
    assert.match(filtered, /<details>\n<summary>Keep this answer<\/summary>\nKeep this explanation\.\n<\/details>/);
    assert.match(filtered, /## Sources\nKeep sources/);
    assert.equal(powershellContent(filtered), filtered);
    assert.equal(powershellContent(null), null);
    const current = readJourney(root, parseProgress(readFileSync(join(root, "docs", "PROGRESS.md"), "utf8")));
    const powershell = (text) => [...text.matchAll(/^```powershell[^\r\n]*\r?\n([\s\S]*?)^```/gm)].map((match) => match[1].replaceAll("\r\n", "\n"));
    for (const localized of [current, current.translations.fr]) {
        const before = JSON.stringify(localized);
        for (const track of ["terraform", "low-code"]) {
            const state = powershellPresentation(localized, track);
            for (const module of state.modules) {
                assert.doesNotMatch(module.guide, /^```(?:bash|sh)(?:\s|$)|^#{1,6} .*bash/im);
                assert.deepEqual(powershell(module.guide), powershell(localized.modules.find((item) => item.module === module.module).guides[track].guide));
            }
            for (const [key, doc] of Object.entries(state.documents)) {
                assert.doesNotMatch(doc.content, /^```(?:bash|sh)(?:\s|$)|^#{1,6} .*bash/im);
                assert.deepEqual(powershell(doc.content), powershell(localized.documents[key].content), key);
            }
        }
        assert.equal(JSON.stringify(localized), before);
    }
    assert.match(html, /state = powershellPresentation\(localized, selectedTrack\)/);
    assert.doesNotMatch(html, /disclosure\("Using bash"|commandBlock\("[^"]+ \/ bash"/);
});

test("module 07 addresses participants across guides, summaries, navigation and French labels", () => {
    const html = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "board.html"), "utf8");
    const locale = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "locale-fr.js"), "utf8");
    assert.match(html, /module\.module === "07" \? "Optional participant exercise"/);
    assert.match(html, /module\.module === "07" \? "Optional \/ participant exercise"/);
    assert.match(html, /Needs modules 03 to 06 deployed and validated in your own approved test environment/);
    assert.match(locale, /"Optional participant exercise": "Exercice facultatif"/);
    assert.match(locale, /"Optional \/ participant exercise": "Exercice facultatif"/);
    assert.doesNotMatch(html + locale, /facilitator demo|démonstration (?:facultative )?de l'animateur|or a recording of them/i);
    for (const language of ["en", "fr"]) {
        const guide = readFileSync(join(root, "modules", "07-clients", language === "fr" ? "README.fr.md" : "README.md"), "utf8");
        assert.match(guide, language === "fr" ? /votre (?:propre )?environnement de test/ : /your own test environment/);
        assert.doesNotMatch(guide, /label them when you show them|signalez-les quand vous les montrez/);
        assert.match(guide, language === "fr" ? /partie B.*pas un exercice à exécuter/ : /Part B.*not a hands-on exercise/);
        for (const document of ["BUILD-PLAN.md", "LEARNING-GUIDE.md", "PRACTICE.md"]) {
            const parts = language === "fr" ? ["docs", "fr", document] : ["docs", document];
            const content = readFileSync(join(root, ...parts), "utf8");
            const section = content.split(/^## 07 [^\r\n]+/m)[1]?.split(/^## /m)[0];
            assert.ok(section, `${language}/${document}: missing module 07`);
            assert.doesNotMatch(section, /facilitator demo|réservée à l'animateur|démonstration de l'animateur|or a recording of them/i);
            assert.match(section, /Foundry/);
        }
    }
    for (const folder of readdirSync(join(root, "modules"))) {
        const path = join(root, "modules", folder, "README.fr.md");
        if (!existsSync(path)) continue;
        const guide = readFileSync(path, "utf8");
        assert.doesNotMatch(guide, /utilisateurs attribués|Alice.*Bob.*\(attribués\)|une espace|application seule/);
    }
});

test("public site exports only the allowlist, with no capability, root URLs, private files or API dependency", (t) => {
    const temporary = mkdtempSync(join(tmpdir(), "workshop-site-"));
    t.after(() => rmSync(temporary, { recursive: true, force: true }));
    const output = join(temporary, "public");
    const result = buildSite(root, output);
    assert.equal(result.files, 105);
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
                    /### Comprendre les résultats avec la documentation/ : /### Read alongside the demonstration/);
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
                "### Comprendre les résultats avec la documentation";
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

test("all 17 French module guides address participants and keep editorial status out of objectives", () => {
    const guides = readdirSync(join(root, "modules")).flatMap((folder) =>
        readdirSync(join(root, "modules", folder)).filter((name) => name.endsWith(".fr.md"))
            .map((name) => ({ folder, name })));
    assert.equal(guides.length, 17);
    assert.equal(new Set(guides.map(({ folder }) => folder)).size, 9);
    for (const { folder, name } of guides) {
        const guide = readFileSync(join(root, "modules", folder, name), "utf8").replaceAll("\r\n", "\n");
        const goal = guide.split(/^## Objectif\n/m)[1]?.split(/^## /m)[0];
        assert.ok(goal, `${folder}/${name}: missing participant objective`);
        assert.match(goal, /\bvous\b/i, `${folder}/${name}: address the participant`);
        assert.doesNotMatch(goal, /nouvellement séparé|guide séparé|ce guide.*(?:validé|exécuté)|chez l'auteur|sur le poste de l'auteur/i,
            `${folder}/${name}: editorial history belongs outside the objective`);
        assert.doesNotMatch(guide, /Gardez ce niveau très temporaire|une identité utilisateur, ouvre le serveur|passerelle gouvernée/);
        assert.match(guide, /^## (?:Valider|Validation|Vérifier)\b/m);
        assert.match(guide, /^## Sources\n/m);
    }
    const locale = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "locale-fr.js"), "utf8");
    assert.doesNotMatch(locale, /faites attribuer les rôles d'Alice, Bob et Eve|Les rôles d'Alice, Bob et Eve doivent être attribués/);
    assert.match(locale, /Eve ne doit avoir aucune attribution/);
});

test("French cleanup explains the separate Foundry group and preserves its participant assessment", () => {
    const progress = parseProgress(readFileSync(join(root, "docs", "PROGRESS.md"), "utf8"));
    const journey = readJourney(root, progress).translations.fr;
    for (const name of ["README.fr.md", "LOW-CODE.fr.md"]) {
        const guide = readFileSync(join(root, "modules", "99-cleanup", name), "utf8").replaceAll("\r\n", "\n");
        assert.doesNotMatch(guide, /groupe de charge de travail|nettoyage de Foundry facultatif|résultat attendu (?:avant|après) nettoyage/);
        assert.match(guide, /Foundry.*groupe de ressources distinct|Foundry utilise \*\*un autre groupe de ressources\*\*/);
        assert.match(guide, /comptes.*(?:fournis|partagés)|ressources partagées/);
    }
    const lowCode = readFileSync(join(root, "modules", "99-cleanup", "LOW-CODE.fr.md"), "utf8");
    assert.match(lowCode, /purger\*\*, c'est-à-dire les supprimer définitivement/);
    assert.match(lowCode, /compte Foundry.*ressource Azure, pas le compte d'un utilisateur/);
    const html = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "board.html"), "utf8");
    const source = html.slice(html.indexOf("function lessonSteps("), html.indexOf("function guidedDocument("));
    const split = new Function(`${source}; return lessonSteps;`)();
    const collect = new Function("lessonSteps",
        `${html.slice(html.indexOf("function collectQuestions("), html.indexOf("function reviewList("))}; return collectQuestions;`)(split);
    const module = journey.modules.find((item) => item.module === "99");
    assert.equal(collect(module.guides.terraform.guide).length, 3);
    const questions = collect(module.guides["low-code"].guide);
    assert.equal(questions.length, 1);
    assert.match(questions[0].text, /groupe de ressources du serveur MCP/);
    assert.match(questions[0].text, /agent Foundry/);
    assert.match(questions[0].text, /groupe de ressources de Foundry est distinct/);
    assert.match(questions[0].text, /étape 3/);
});

test("the review card uses singular and plural question labels in English and French", () => {
    const html = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "board.html"), "utf8");
    const source = html.slice(html.indexOf("if (lesson.reviewIndex !== -1) cards.push("),
        html.indexOf('cards.push([t("Architecture and context")'));
    const french = runInNewContext(`${readFileSync(join(root, ".github", "extensions", "workshop-build-board", "locale-fr.js"), "utf8")}\nfrench;`);
    for (const language of ["en", "fr"]) {
        for (const count of [1, 3]) {
            const cards = [];
            new Function("cards", "lesson", "stepWord", "language", "items", "t", source)(
                cards, { reviewIndex: 6 }, (number) => `${language === "fr" ? "Étape" : "Step"} ${number}`,
                language, Array(count), (key) => language === "fr" ? french[key] ?? key : key);
            const suffix = language === "fr"
                ? count === 1 ? "question, réponse masquée" : "questions, réponses masquées"
                : count === 1 ? "question, answer hidden" : "questions, answers hidden";
            assert.equal(cards[0][1], `${language === "fr" ? "Étape 7 : " : "Step 7: "}${count} ${suffix}`);
        }
    }
});

test("French modules pair copyable inspections with explanations and exported real result captures", () => {
    const snippets = [];
    const guides = readdirSync(join(root, "modules")).flatMap((folder) =>
        readdirSync(join(root, "modules", folder)).filter((name) => name.endsWith(".fr.md"))
            .map((name) => ({ folder, name })));
    assert.equal(guides.length, 17);
    for (const { folder, name } of guides) {
        const guide = readFileSync(join(root, "modules", folder, name), "utf8").replaceAll("\r\n", "\n");
        const section = guide.split(/^### Vérifier vous-même (?:avec Azure CLI(?:, avant de supprimer)?|dans le terminal et Inspector)\n/m)[1]
            ?.split(/^#{1,3} /m)[0];
        assert.ok(section, `${folder}/${name}: missing hands-on inspection`);
        assert.match(section, /\*\*Pourquoi :\*\*/);
        assert.match(section, /\*\*Résultat attendu/);
        const blocks = [...section.matchAll(/^```powershell\n([\s\S]*?)^```/gm)].map((match) => match[1]);
        assert.ok(blocks.length, `${folder}/${name}: missing copyable command`);
        snippets.push(...blocks);
        if (folder.startsWith("01-")) {
            assert.match(section, /pwsh -NoProfile -File/);
            assert.doesNotMatch(blocks.join("\n"), /^az /m);
        } else {
            assert.match(blocks.join("\n"), /^az /m);
            for (const block of blocks) {
                assert.doesNotMatch(block, /^az .*\b(?:create|update|delete|purge|register|set|get-access-token|invoke-action)\b/m);
                for (const line of block.matchAll(/^az [^\n]+\n([^\n]+)/gm)) {
                    assert.match(line[1], /if \(\$LASTEXITCODE -ne 0\)/, `${folder}/${name}: fail explicitly after az`);
                }
            }
        }
        const images = [...section.matchAll(/!\[[^\]]+\]\(\.\.\/\.\.\/assets\/screenshots\/([^)]+)\.png\)/g)];
        assert.ok(images.length, `${folder}/${name}: missing result screenshot`);
        for (const image of images) {
            assert.ok(screenshots.includes(image[1]), `Not exported: ${image[1]}`);
            const bytes = readFileSync(join(root, "assets", "screenshots", `${image[1]}.png`));
            assert.equal(bytes.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
        }
        if (folder.startsWith("99-")) {
            assert.match(section, /avant nettoyage|avant de supprimer/i);
            assert.match(section, /pas une preuve de suppression|pas d'une capture de suppression/);
        }
    }
    const parse = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", `
        $ErrorActionPreference = 'Stop'
        foreach ($snippet in ([Console]::In.ReadToEnd() | ConvertFrom-Json)) {
            $tokens = $null; $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($snippet, [ref]$tokens, [ref]$errors)
            if ($errors.Count) { throw ($errors.Message -join '; ') }
        }
        Write-Output 'PASS copyable inspection syntax'
    `], { input: JSON.stringify(snippets), encoding: "utf8", timeout: 30_000 });
    assert.equal(parse.status, 0, parse.stdout + parse.stderr);
    const captures = JSON.parse(readFileSync(join(root, "tools", "capture", "terminal-shots.json"), "utf8"))
        .filter((shot) => shot.file.includes("-az-"));
    assert.equal(captures.length, 8);
    for (const shot of captures) {
        assert.equal(shot.preserveLines, true);
        assert.equal(shot.expectExit, 0);
        assert.ok(shot.requireOutput.length, `${shot.file}: reject missing/null output`);
        assert.ok(guides.some(({ folder, name }) => {
            const guide = readFileSync(join(root, "modules", folder, name), "utf8");
            return shot.show.every((command) => guide.includes(command));
        }), `${shot.file}: displayed command must be copyable from a guide`);
    }
});

test("module 02 French objectives address participants and keep authoring status in validation notes", () => {
    const instructions = readFileSync(join(root, ".github", "copilot-instructions.md"), "utf8");
    assert.match(instructions, /## French participant-facing writing/);
    assert.match(instructions, /Write idiomatic French, not a sentence-by-sentence translation/);
    assert.match(instructions, /standalone participant guide/);
    for (const name of ["README.fr.md", "LOW-CODE.fr.md"]) {
        const guide = readFileSync(join(root, "modules", "02-open-server", name), "utf8").replaceAll("\r\n", "\n");
        const objective = guide.split("## Objectif\n")[1].split("\n## ")[0];
        assert.match(objective, /Vous allez déployer/);
        assert.match(objective, /toute personne qui (?:possède|détient) la clé/i);
        assert.doesNotMatch(objective, /nouvellement séparé|bout en bout|guide séparé|l'auteur/);
        assert.doesNotMatch(guide, /Gardez ce niveau très temporaire|une identité utilisateur, ouvre le serveur|passerelle gouvernée/);
        assert.match(guide, /Ne désactivez jamais la protection par clé/);
        assert.match(guide, /supprimez les ressources si vous vous arrêtez ici|Si vous vous arrêtez ici, suivez/);
    }
    const lowCode = readFileSync(join(root, "modules", "02-open-server", "LOW-CODE.fr.md"), "utf8");
    const validation = lowCode.slice(lowCode.indexOf("## Valider"));
    assert.match(validation, /parcours complet dans le portail n'a pas encore été testé sur un environnement neuf/);
});

test("French module 03 teaches server admission before per-tool rights and exports its complete assessment", () => {
    const guide = readFileSync(join(root, "modules", "03-entra-authentication", "README.fr.md"), "utf8").replaceAll("\r\n", "\n");
    const html = readFileSync(join(root, ".github", "extensions", "workshop-build-board", "board.html"), "utf8");
    const source = html.slice(html.indexOf("function lessonSteps("), html.indexOf("function guidedDocument("));
    const split = new Function(`${source}; return lessonSteps;`)();
    const collect = new Function("lessonSteps",
        `${html.slice(html.indexOf("function collectQuestions("), html.indexOf("function reviewList("))}; return collectQuestions;`)(split);
    const steps = split(guide);
    const questions = collect(guide);
    assert.equal(steps[0].title, "Objectif");
    assert.equal(questions.length, 6);
    for (const question of questions) {
        assert.ok(question.stepIndex >= 0 && question.stepIndex < steps.length);
        assert.match(question.text, /<summary>Afficher la réponse<\/summary>/);
        assert.match(question.text, /<\/details>$/);
    }
    for (const concept of [/Bob.*Eve/, /VS Code.*préautorisé/, /401.*clé/, /jeton Graph/, /Bob.*create_ticket/, /erreur MFA/]) {
        assert.ok(questions.some((item) => concept.test(item.text)), `Missing assessment concept: ${concept}`);
    }
    assert.match(guide, /Bob.*\| `Tools.Read` seulement \|.*encore appeler `create_ticket`/);
    assert.match(guide, /Eve.*\| Aucune \|.*AADSTS50105/);
    assert.doesNotMatch(guide, /Résultat réel|tenant de test de l'auteur|Chez l'auteur|Plan: 0 to add/);
    const activation = guide.indexOf("### 4. Activer Entra");
    const verification = guide.indexOf("### 5. Lire la protection");
    const removal = guide.indexOf("### 6. Retirer l'exigence");
    const server = guide.indexOf("### 7. Vérifier le serveur");
    const personas = guide.indexOf("### 9. Tester Alice");
    assert.ok(activation < verification && verification < removal && removal < server && server < personas);
    const fences = [...guide.matchAll(/^```powershell\n([\s\S]*?)^```/gm)];
    assert.ok(fences.some((block) => block[1].includes("az rest --method get")));
    for (const block of fences) {
        assert.ok(!(/\bplan\b/.test(block[1]) && /\bapply\b/.test(block[1])), "Separate plan from approved apply");
        assert.doesNotMatch(block[1], /az (?:rest --method (?:put|patch|delete)|.*\b(?:set|create|update)\b)/);
        assert.doesNotMatch(block[1], /get-access-token/);
        const next = guide.slice(block.index + block[0].length).trimStart();
        assert.match(next, /^(?:> \*\*Résultat attendu\*\* —|\*\*STOP —)/,
            "Keep the boxed result or the explicit plan-approval stop immediately after each command");
    }
    const testAccounts = guide.slice(personas, guide.indexOf("### Bash"));
    assert.match(testAccounts, /finally/);
    assert.match(testAccounts, /\$env:AZURE_CONFIG_DIR = \$operatorConfig/);
    assert.match(testAccounts, /\$ErrorActionPreference = 'Stop'/);
    const lowCode = readFileSync(join(root, "modules", "03-entra-authentication", "LOW-CODE.fr.md"), "utf8");
    assert.match(lowCode, /Bob.*`Tools.Read` seulement.*encore appeler `create_ticket`/);
    assert.match(lowCode, /Eve.*AADSTS50105/);
    assert.equal(collect(lowCode).length, 4);
});

test("French module 03 PowerShell examples parse and its pre-key-removal check fails closed", () => {
    const guide = readFileSync(join(root, "modules", "03-entra-authentication", "README.fr.md"), "utf8").replaceAll("\r\n", "\n");
    const snippets = [...guide.matchAll(/^```powershell\n([\s\S]*?)^```/gm)].map((match) => match[1]);
    const guard = guide.split("### 5. Lire la protection")[1].match(/^```powershell\n([\s\S]*?)^```/m)[1];
    const script = `
        $ErrorActionPreference = 'Stop'
        $data = [Console]::In.ReadToEnd() | ConvertFrom-Json
        foreach ($snippet in $data.snippets) {
            $tokens = $null; $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($snippet, [ref]$tokens, [ref]$errors)
            if ($errors.Count) { throw ($errors.Message -join '; ') }
        }
        foreach ($scenario in @('valid','disabled','optional','redirect','issuer','client','audience','http','cli')) {
            & {
                $env:ARM_SUBSCRIPTION_ID = 'synthetic-subscription'
                $env:ARM_TENANT_ID = 'synthetic-tenant'
                $rg = 'synthetic-group'; $fn = 'synthetic-function'
                $apiClientId = 'synthetic-api'; $audience = 'api://synthetic-api'
                $authData = @{
                    platform = @{ enabled = $true }
                    globalValidation = @{ requireAuthentication = $true; unauthenticatedClientAction = 'Return401' }
                    identityProviders = @{ azureActiveDirectory = @{
                        registration = @{ clientId = $apiClientId; openIdIssuer = "https://login.microsoftonline.com/$env:ARM_TENANT_ID/v2.0" }
                        validation = @{ allowedAudiences = @($audience, $apiClientId) }
                    } }
                }
                switch ($scenario) {
                    disabled { $authData.platform.enabled = $false }
                    optional { $authData.globalValidation.requireAuthentication = $false }
                    redirect { $authData.globalValidation.unauthenticatedClientAction = 'RedirectToLoginPage' }
                    issuer { $authData.identityProviders.azureActiveDirectory.registration.openIdIssuer = 'https://example.invalid' }
                    client { $authData.identityProviders.azureActiveDirectory.registration.clientId = 'wrong-api' }
                    audience { $authData.identityProviders.azureActiveDirectory.validation.allowedAudiences += 'https://graph.microsoft.com' }
                }
                function az {
                    if ($args[0] -eq 'rest') {
                        if ($args[1] -ne '--method' -or $args[2] -ne 'get') { throw 'Only read-only az rest is allowed.' }
                        $global:LASTEXITCODE = if ($scenario -eq 'cli') { 1 } else { 0 }
                        return ($authData | ConvertTo-Json -Depth 10)
                    }
                    if ($args[0] -ne 'functionapp' -or $args[1] -ne 'show') { throw 'Unexpected CLI command.' }
                    $global:LASTEXITCODE = 0
                    return 'function.example.invalid'
                }
                function Invoke-WebRequest {
                    param($Uri, $Method, $ContentType, $Body, [switch]$SkipHttpErrorCheck, $TimeoutSec)
                    if ($Uri -ne 'https://function.example.invalid/runtime/webhooks/mcp') { throw 'Unexpected endpoint.' }
                    return @{ StatusCode = $(if ($scenario -eq 'http') { 200 } else { 401 }) }
                }
                $rejected = $false
                try { $null = & ([scriptblock]::Create($data.guard)) }
                catch { $rejected = $true }
                if ($rejected -ne ($scenario -ne 'valid')) { throw "Unexpected guard outcome: $scenario" }
                Write-Output "PASS $scenario"
            }
        }
    `;
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command", script], {
        input: JSON.stringify({ snippets, guard }), encoding: "utf8", timeout: 30_000,
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal((result.stdout.match(/^PASS /gm) ?? []).length, 9);
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

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

function plainCodeBlock(title, text) {
    return { tag: "pre", children: [{ tag: "code", children: [text] }] };
}

test("appearance choices apply and persist only known themes, restore system colors and translate selection labels", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const buttons = ["template", "light", "dark"].map((key) => ({
        dataset: { themeChoice: key }, attributes: {},
        setAttribute(name, value) { this.attributes[name] = value; },
    }));
    const label = { dataset: { appearanceLabel: "Appearance" } };
    const close = { attributes: {}, setAttribute(name, value) { this.attributes[name] = value; } };
    const document = {
        documentElement: { dataset: {} },
        querySelectorAll(selector) { return selector === "[data-theme-choice]" ? buttons : [label]; },
        getElementById(id) { assert.equal(id, "appearance-close"); return close; },
    };
    const stored = [];
    const start = html.indexOf("const themeChoices =");
    const end = html.indexOf("function createAppearanceDialog(", start);
    const api = new Function("document", "preferences", "t", `
        ${html.slice(start, end)}
        function updateChrome() { updateAppearance(); }
        return { setTheme, updateAppearance };
    `)(document, { set: (...args) => stored.push(args) }, (text) => `translated:${text}`);
    api.updateAppearance();
    assert.equal(buttons[0].attributes["aria-pressed"], "true");
    for (const [index, value] of [[1, "light"], [2, "dark"], [0, "template"]]) {
        api.setTheme(value);
        assert.equal(document.documentElement.dataset.theme, value === "template" ? undefined : value);
        assert.deepEqual(buttons.map((button) => button.attributes["aria-pressed"]),
            buttons.map((_, i) => String(i === index)));
        assert.deepEqual(stored.at(-1), ["theme", value]);
    }
    assert.equal(label.textContent, "translated:Appearance");
    assert.equal(close.attributes["aria-label"], "translated:Close appearance settings");
    assert.throws(() => api.setTheme("untrusted"), /Unknown appearance template/);
    assert.equal(stored.length, 3);
    assert.match(html, /aria-haspopup="dialog" aria-controls="appearance-dialog"/);
    assert.match(html, /appearanceDialog\.showModal\(\)/);
    assert.match(html, /close\.addEventListener\("click", \(\) => dialog\.close\(\)\)/);
    assert.match(html, /\["Microsoft", "microsoft"\], \["Azure", "azure"\]/);
});

test("guided reading splits authored actions, never code fences or nested disclosures", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function lessonSteps(");
    const end = html.indexOf("function guidedDocument(", start);
    const split = new Function(`${html.slice(start, end)}; return lessonSteps;`)();
    const source = "# Title\nIntro.\n\n## Steps\n### PowerShell\nUse one terminal.\n\n" +
        "**1. Predict.** No cloud change.\n\n```powershell\n## Not a heading\n**2. Not an action.**\n```\n\n" +
        "**2. Observe.** Check the result.\n\n<details>\n<summary>Advanced</summary>\n\n" +
        "## Kept inside\n<details>\n<summary>Nested</summary>\n\n### Also inside\n\n</details>\n</details>\n";
    const steps = split(source);
    assert.deepEqual(steps.map((step) => step.title), ["Before you begin", "PowerShell", "Predict.", "Observe."]);
    assert.match(steps[2].content, /^No cloud change\./);
    assert.match(steps[2].content, /```powershell\n## Not a heading\n\*\*2\. Not an action\.\*\*\n```/);
    assert.match(steps[3].content, /## Kept inside[\s\S]*### Also inside[\s\S]*<\/details>\n<\/details>$/);
    assert.deepEqual(split("# Module\n[Français](README.fr.md)\n\n## Goal\nLearn one thing.").map((step) => step.title), ["Goal"]);
    // The Microsoft product chips are part of the visible module header, never hidden in a disclosure.
    assert.match(html, /content\.append\(intro, servicesList\(module\)\);/);
    assert.doesNotMatch(html, /disclosure\([^)]*servicesList/);
    // Every published module guide opens on its Goal: no language link, status note or banner becomes a preliminary step.
    for (const folder of ["00-prerequisites", "01-discover-mcp", "02-open-server", "03-entra-authentication", "04-governed-gateway",
        "05-delegated-and-app-only", "06-observe-inventory", "07-clients", "99-cleanup"]) {
        for (const [file, goal] of [["README.md", "Goal"], ["README.fr.md", "Objectif"]]) {
            const first = split(readFileSync(join(repository, "modules", folder, file), "utf8"))[0];
            assert.equal(first.title, goal, `${folder}/${file} must open on ${goal}, not "${first.title}"`);
        }
    }
    assert.deepEqual(split("# Concepts\n## 1. Discover\nOne idea.\n## 2. Execute\nAnother idea.").map((step) => step.title),
        ["Discover", "Execute"]);
    assert.throws(() => split("# Empty\n"), /at least one step/);
    const journey = readJourney(repository, parseProgress(readFileSync(join(repository, "docs", "PROGRESS.md"), "utf8")));
    const fences = (text) => [...text.matchAll(/^```[^\n]*\n[\s\S]*?^```/gm)].map((match) => match[0]);
    for (const language of [journey, journey.translations.fr]) {
        const documents = [
            ...language.modules.filter((module) => module.guide !== null).map((module) => ({ content: module.guide })),
            ...["deployment", "presenter", "hosting", "gettingStarted", "concepts", "governance"].map((name) => language.documents[name]),
        ];
        for (const doc of documents) {
            const original = doc.content.replaceAll("\r\n", "\n");
            const pages = split(original);
            assert.ok(pages.every((page) => page.content.trim()));
            assert.deepEqual(pages.flatMap((page) => fences(page.content)), fences(original),
                "Reading navigation must not alter, reorder or split runnable blocks");
        }
    }
});

test("long lessons paginate at intact content elements and label their continuation pages", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function lessonSteps(");
    const end = html.indexOf("function guidedDocument(", start);
    const split = new Function(`${html.slice(start, end)}; return lessonSteps;`)();
    const paragraph = (name) => `${name} ${"word ".repeat(69).trim()}`;
    const fenced = "```powershell\n# Keep checks together\nGet-Location\n\nif ($LASTEXITCODE) { throw 'Stop' }\n```";
    const details = "<details>\n<summary>Reference</summary>\n\n## Not a new page\n\n<details>\n<summary>Nested</summary>\n\nText\n\n</details>\n</details>";
    const long = `# Lesson\n[Français](fr/MCP-CONCEPTS.md)\n\n## Observe\n${paragraph("First")}\n\n${paragraph("Second")}\n\n${paragraph("Third")}\n\n${fenced}\n\n${details}\n\n#### Check\nOne short question.`;
    const pages = split(long);
    assert.deepEqual(pages.map(({ title, part, parts }) => ({ title, part, parts })), [
        { title: "Observe", part: 1, parts: 2 }, { title: "Observe", part: 2, parts: 2 },
        { title: "Check", part: undefined, parts: undefined },
    ]);
    assert.ok(pages[0].content.includes(paragraph("First")));
    assert.ok(pages[0].content.includes(paragraph("Second")));
    assert.ok(pages[1].content.includes(paragraph("Third")));
    assert.ok(pages[1].content.includes(fenced));
    assert.ok(pages[1].content.includes(details));
    const list = split(`## List\n${Array.from({ length: 6 }, (_, i) => `- Item ${i} ${"word ".repeat(49).trim()}\n  - Nested child stays with item ${i}`).join("\n")}`);
    assert.ok(list.length > 1);
    for (let i = 0; i < 6; i++) {
        assert.equal(list.filter((page) => page.content.includes(`- Item ${i}`) &&
            page.content.includes(`Nested child stays with item ${i}`)).length, 1);
    }
    assert.ok(list.every((page) => page.content.split(/\s+/).length <= 180));
    const command = "```powershell\nGet-Location\n```";
    const result = "> **Expected result** — synthetic.\n>\n> ```text\n> PASS done\n> ```\n>\n> **What it means for you:** one line.";
    const kept = split(`## Run\n${paragraph("Intro")}\n\n${paragraph("More")}\n\n${command}\n\n${paragraph("Long")}\n\n${command.replace("Get-Location", "Get-Date")}\n\n${result}\n\n${paragraph("After")}`);
    assert.ok(kept.length > 1);
    assert.equal(kept.filter((page) => page.content.includes("Get-Date") && page.content.includes(result)).length, 1,
        "A result box must stay on the same page as its command");
    assert.ok(list.some((page) => /- Item \d[^\n]*\n  - Nested child stays with item \d\n- Item/.test(page.content)),
        "Consecutive list items on one page must form a single list");
    const nested = "- Parent\n\n  - Keep the nested child\n\n- Next parent";
    assert.ok(split(`## Nested\n${nested}`)[0].content.includes("- Parent\n\n  - Keep the nested child"));
    const header = "| Element | Meaning |\n|---|---|";
    const rows = Array.from({ length: 8 }, (_, i) => `| Row ${i} | ${"word ".repeat(39).trim()} |`);
    const tables = split(`## Compare\n${header}\n${rows.join("\n")}`);
    assert.ok(tables.length > 1);
    assert.ok(tables.every((page) => page.content.startsWith(header) && page.content.split(/\s+/).length <= 180));
    for (const row of rows) assert.equal(tables.filter((page) => page.content.includes(row)).length, 1);
});

test("guided controls show one page, preserve commands and require opening long reference blocks", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function lessonSteps(");
    const end = html.indexOf("function notice(", start);
    function element(tag, text, className) {
        return {
            tag, textContent: text ?? "", className, children: [], attributes: {}, listeners: {},
            append(...children) {
                for (const child of children) {
                    if (child.parent) child.parent.children.splice(child.parent.children.indexOf(child), 1);
                    child.parent = this;
                    this.children.push(child);
                }
            },
            replaceChildren(...children) { this.children = []; this.append(...children); },
            replaceWith(node) {
                this.parent.children.splice(this.parent.children.indexOf(this), 1, node);
                node.parent = this.parent;
                this.parent = null;
            },
            setAttribute(name, value) { this.attributes[name] = value; },
            removeAttribute(name) { delete this.attributes[name]; },
            style: {},
            addEventListener(name, handler) { this.listeners[name] = handler; },
            querySelectorAll(selector) {
                return this.children.flatMap((child) => [
                    ...(selector === ".command" ? child.className === "command" : child.tag === selector) ? [child] : [],
                    ...child.querySelectorAll(selector),
                ]);
            },
            querySelector(selector) { return this.querySelectorAll(selector)[0]; },
            focus() { this.focused = true; },
            scrollIntoView() {},
        };
    }
    const markdown = (text) => {
        const body = element("div");
        for (const match of text.matchAll(/```[^\n]*\n([\s\S]*?)\n```/g)) {
            const block = element("section", undefined, "command");
            block.append(element("code", match[1]));
            body.append(block);
        }
        return body;
    };
    const disclosure = (title, ...children) => {
        const detail = element("details");
        detail.append(element("summary", title), ...children);
        return detail;
    };
    const render = new Function("element", "t", "markdown", "disclosure",
        `${html.slice(start, end)}; return guidedDocument;`)(element, (text) => text, markdown, disclosure);
    const long = Array(13).fill("synthetic").join("\n");
    const wide = "x".repeat(1201);
    const lesson = render(`## Predict\n\`\`\`powershell\nGet-Location\n\`\`\`\n## Review\n\`\`\`text\n${long}\n\`\`\`\n## Compare\n\`\`\`text\n${wide}\n\`\`\``, "synthetic.md");
    const [header, page, navigation, outline] = lesson.children;
    const position = header.children[0];
    const [previous, next] = navigation.children;
    // Top-to-bottom order: position, content, then navigation and the optional outline.
    assert.equal(header.className, "lesson-head");
    assert.equal(page.className, "lesson-page");
    assert.equal(navigation.className, "lesson-nav");
    assert.equal(outline.tag, "details");
    assert.equal(outline.open, undefined);
    assert.equal(position.textContent, "Step 1 / 3");
    assert.equal(previous.disabled, true);
    assert.equal(next.className, "primary");
    assert.equal(next.textContent, "Next: Review \u2192");
    assert.equal(page.children[0].textContent, "Predict");
    assert.equal(lesson.querySelectorAll(".command").length, 1);
    next.listeners.click();
    assert.equal(page.children[0].textContent, "Review");
    assert.equal(page.children[0].focused, true);
    const detail = page.children[1].children[0];
    assert.equal(detail.tag, "details");
    assert.equal(detail.open, undefined);
    assert.equal(detail.querySelector("code").textContent, long);
    const jumps = outline.children[1].children.map((item) => item.children[0]);
    assert.deepEqual(jumps.map((jump) => jump.textContent), ["Predict", "Review", "Compare"]);
    assert.equal(jumps[1].attributes["aria-current"], "step");
    jumps[2].listeners.click();
    assert.equal(jumps[2].attributes["aria-current"], "step");
    assert.equal(jumps[1].attributes["aria-current"], undefined);
    assert.equal(next.disabled, true);
    assert.equal(next.textContent, "End of this guide");
    assert.equal(page.children[1].children[0].tag, "details");
    assert.equal(page.querySelector("code").textContent, wide);
    previous.listeners.click();
    assert.equal(position.textContent, "Step 2 / 3");
});

test("French labels use the reviewed wording and copied prompts preserve the safety instructions", () => {
    const source = readFileSync(new URL("./locale-fr.js", import.meta.url), "utf8");
    const french = new Function(`${source}; return french;`)();
    assert.equal(french["Not sure what to ask?"], "Par quoi commencer ?");
    assert.equal(french["Make the call. Understand the boundary."], "Testez votre serveur, puis vérifiez le résultat.");
    assert.equal(french["Copy prompt"], "Copier la consigne");
    assert.equal(french["Why this boundary matters"], "Pour aller plus loin : comprendre les protections");
    assert.doesNotMatch(Object.values(french).join("\n"), /idée d'appel|Comprenez la frontière|vrai README|vrai guide/);
    const prompts = Object.entries(french).filter(([key]) =>
        key.startsWith("Use only my connected workshop") || key.startsWith("For my synthetic workshop"));
    assert.equal(prompts.length, 3);
    assert.match(prompts[0][1], /N'exécute aucun outil/);
    assert.match(prompts[1][1], /une seule fois/);
    assert.match(prompts[1][1], /N'utilise aucun outil qui modifie/);
    assert.match(prompts[2][1], /rôle applicatif nécessaire/);
    assert.match(prompts[2][1], /accord explicite.*confirmation manuelle/);
});

test("Markdown disclosures are closed by default, support nesting and code fences, and never render arbitrary HTML", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function markdown(");
    const end = html.indexOf("function notice(", start);
    assert.ok(start > 0 && end > start);
    const element = (tag, text) => ({
        tag, children: text === undefined ? [] : [text],
        append(...children) { this.children.push(...children); },
    });
    const render = new Function("element", "inline", "notice", "commandBlock",
        `${html.slice(start, end)}; return markdown;`)(element, (node, text) => node.append(text),
        () => element("aside"), plainCodeBlock);
    const rendered = render("À retenir.\n<details>\n<summary>Pour aller plus loin</summary>\n\n" +
        "Précisions.\n\n<details>\n<summary>Cas avancé</summary>\n\n" +
        "```text\n</details>\n<script>synthetic</script>\n```\n\n</details>\n\n</details>\n\nSuite.", "docs/fr/PRACTICE.md");
    const section = rendered.children[1];
    assert.equal(section.tag, "details");
    assert.equal(section.open, undefined);
    assert.equal(section.children[0].tag, "summary");
    assert.deepEqual(section.children[0].children, ["Pour aller plus loin"]);
    const nested = section.children[1].children[1];
    assert.equal(nested.tag, "details");
    assert.equal(nested.open, undefined);
    assert.equal(nested.children[1].children[0].tag, "pre");
    assert.deepEqual(nested.children[1].children[0].children[0].children,
        ["</details>\n<script>synthetic</script>"]);
    assert.deepEqual(rendered.children[2].children, ["Suite."]);
    assert.deepEqual(render("<img src=x onerror=synthetic>", "docs/fr/PRACTICE.md").children[0].children,
        ["<img src=x onerror=synthetic>"]);
    assert.throws(() => render("<details>\n<summary>Incomplet</summary>", "docs/fr/PRACTICE.md"), /closing tag/);
    assert.throws(() => render("<details>\n<summary><img src=x></summary>\n</details>", "docs/fr/PRACTICE.md"),
        /plain-text summary/);
});

test("Markdown diagram images reuse only published diagrams in the current language", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function markdown(");
    const end = html.indexOf("function disclosure(", start);
    const module = { module: "06" };
    const image = {};
    const figure = {
        classList: { add(value) { assert.equal(value, "inline-architecture"); } },
        querySelector(selector) { assert.equal(selector, "img"); return image; },
    };
    const element = (tag) => ({ tag, children: [], append(...children) { this.children.push(...children); } });
    const render = new Function("element", "state", "language", "architecture",
        `${html.slice(start, end)}; return markdown;`)(element, { modules: [module] }, "fr",
        (value) => { assert.equal(value, module); return figure; });
    const body = render("![Trois circuits distincts](../../assets/architecture/06.fr.svg)", "modules/06-observe-inventory/README.fr.md");
    assert.equal(body.children[0], figure);
    assert.equal(image.alt, "Trois circuits distincts");
    for (const path of ["https://example.com/image.svg", "../../assets/architecture/06.en.svg",
        "../../assets/architecture/42.fr.svg", "../../private.svg"]) {
        assert.throws(() => render(`![Not published](${path})`, "synthetic.md"), /published workshop diagram/);
    }
});

test("Markdown alerts preserve blocks, stop adjacent paragraphs, and keep quoted HTML inert", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    assert.doesNotMatch(html, /\.notice(?:\.[\w-]+)? strong\s*\{/);
    const start = html.indexOf("function markdown(");
    const end = html.indexOf("function notice(", start);
    const element = (tag, text) => ({
        tag, children: text === undefined ? [] : [text],
        append(...children) { this.children.push(...children); },
    });
    const render = new Function("element", "inline", "notice", "commandBlock",
        `${html.slice(start, end)}; return markdown;`)(element, (node, text) => node.append(text),
        (title, description, type) => ({ ...element("aside"), title, type }), plainCodeBlock);
    for (const [type, title] of Object.entries({
        TIP: "Tip", NOTE: "Note", IMPORTANT: "Important", WARNING: "Warning", CAUTION: "Danger",
    })) {
        const result = render(`Before.\n> [!${type}]\n> First **paragraph**.\n>\n` +
            "> - Keep the state.\n> - Review the plan.\n>\n> Second paragraph.\n>\n" +
            "> ```text\n> <script>synthetic</script>\n> ```\n\nAfter.", "modules/99-cleanup/README.md");
        assert.deepEqual(result.children[0].children, ["Before."]);
        const box = result.children[1];
        assert.equal(box.title, title);
        assert.equal(box.type, type.toLowerCase());
        const body = box.children[0];
        assert.equal(body.className, "notice-body");
        assert.deepEqual(body.children.map((node) => node.tag), ["p", "ul", "p", "pre"]);
        assert.equal(body.children[1].children.length, 2);
        assert.deepEqual(body.children[3].children[0].children, ["<script>synthetic</script>"]);
        assert.deepEqual(result.children[2].children, ["After."]);
    }
    const quote = render("Before.\n> A quote.\n>\n> <img src=x onerror=synthetic>\n\nAfter.", "README.md");
    assert.equal(quote.children[1].tag, "blockquote");
    assert.deepEqual(quote.children[1].children[0].children[1].children, ["<img src=x onerror=synthetic>"]);
    assert.deepEqual(quote.children[2].children, ["After."]);
    assert.deepEqual(render("```text\n> [!WARNING]\n```", "README.md").children[0].children[0].children,
        ["> [!WARNING]"]);
});

test("every non-Mermaid code fence uses the copy control with untranslated code and shell-only guidance", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function markdown(");
    const end = html.indexOf("function notice(", start);
    const element = (tag, text) => ({
        tag, children: text === undefined ? [] : [text],
        append(...children) { this.children.push(...children); },
    });
    const calls = [];
    const render = new Function("element", "inline", "commandBlock",
        `${html.slice(start, end)}; return markdown;`)(element, () => {}, (...args) => {
        calls.push(args);
        return element("section");
    });
    for (const language of ["powershell", "bash", "sh", "json", "text", "csharp", ""]) {
        const code = '  literal <script>synthetic</script>\n$env:EXAMPLE = "Do not translate"\n';
        const rendered = render(`\`\`\`${language}\n${code}\n\`\`\``, "README.md");
        assert.deepEqual(calls.at(-1), [{
            powershell: "PowerShell", bash: "Bash", sh: "Shell", json: "JSON", text: "Text",
        }[language] || language || "Code", code, "Copy code", false]);
        assert.equal(rendered.children[0].children.length, ["powershell", "bash", "sh"].includes(language) ? 1 : 0);
    }
});

test("copy controls preserve exact code, never execute it and report clipboard denial explicitly", async () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function commandBlock(");
    const end = html.indexOf("function connectionCommands(", start);
    const element = (tag, text, className) => ({
        tag, text, className, attributes: {}, children: [], listeners: {},
        append(...children) { this.children.push(...children); },
        setAttribute(key, value) { this.attributes[key] = value; },
        addEventListener(event, handler) { this.listeners[event] = handler; },
    });
    const message = {};
    const copied = [];
    const navigator = { clipboard: { writeText: async (text) => { copied.push(text); } } };
    const block = new Function("element", "t", "language", "navigator", "message",
        `${html.slice(start, end)}; return commandBlock;`)(element, (text) => `translated:${text}`,
        "fr", navigator, message);
    const text = '$env:EXAMPLE = "synthetic"\n<script>never execute</script>\n';
    const node = block("PowerShell", text, "Copy code", false);
    const copy = node.children[0].children[1];
    assert.equal(copy.type, "button");
    assert.equal(copy.attributes["aria-label"], "translated:Copy code : translated:PowerShell");
    assert.equal(node.children[1].children[0].text, text);
    assert.equal(copied.length, 0);
    await copy.listeners.click();
    assert.deepEqual(copied, [text]);
    assert.equal(message.className, "");
    assert.match(message.textContent, /Nothing has been executed/);
    navigator.clipboard.writeText = async () => { throw new Error("Synthetic clipboard denial"); };
    await copy.listeners.click();
    assert.equal(message.className, "error");
    assert.match(message.textContent, /copy it manually/);
    delete navigator.clipboard;
    await copy.listeners.click();
    assert.equal(message.className, "error");
    assert.equal(block("Prompt", "Original prompt").children[1].children[0].text, "translated:Original prompt");
});

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

test("published Mermaid blocks render their matching diagram, while arbitrary graphs fail explicitly", () => {
    const html = readFileSync(new URL("./board.html", import.meta.url), "utf8");
    const start = html.indexOf("function markdown(");
    const end = html.indexOf("function notice(", start);
    const content = 'flowchart LR\n  a["Synthetic client"] --> b["Synthetic server"]';
    const module = { module: "00", diagramSource: { content } };
    const element = (tag, text) => ({
        tag, children: text === undefined ? [] : [text],
        append(...children) { this.children.push(...children); },
    });
    const render = new Function("element", "inline", "notice", "state", "architecture",
        `${html.slice(start, end)}; return markdown;`)(element, () => {}, () => element("aside"),
        { modules: [module] }, (selected) => element("figure", selected.module));
    const result = render(`\`\`\`mermaid\n${content}\n\`\`\``, "assets/architecture/STEPS.md");
    assert.equal(result.children.length, 1);
    assert.equal(result.children[0].tag, "figure");
    assert.deepEqual(result.children[0].children, ["00"]);
    assert.throws(() => render("```mermaid\nflowchart LR\n  a --> unreviewed\n```",
        "assets/architecture/STEPS.md"), /does not match a published/);
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
    writeFileSync(join(root, "docs", "IMPLEMENTATION-STATUS.md"), "# Synthetic implementation status\n");
    writeFileSync(join(root, "docs", "MCP-CONCEPTS.md"), "# Synthetic MCP concepts\n\n## Tools\nSynthetic discovery and execution.\n");
    mkdirSync(join(root, "docs", "fr"));
    for (const file of ["BUILD-PLAN.md", "PRACTICE.md", "LEARNING-GUIDE.md", "DEPLOYMENT.md", "COPILOT-RUNBOOK.md", "GETTING-STARTED.md", "HOSTING.md", "IMPLEMENTATION-STATUS.md", "MCP-CONCEPTS.md"]) {
        writeFileSync(join(root, "docs", "fr", file), readFileSync(join(root, "docs", file), "utf8").replaceAll("Synthetic module", "Module français"));
    }
    writeFileSync(join(root, "docs", "fr", "REFERENCES.md"), "# Références synthétiques\n");
    mkdirSync(join(root, "assets", "architecture"), { recursive: true });
    mkdirSync(join(root, "assets", "icons"));
    writeFileSync(join(root, "assets", "architecture", "README.md"), "# Synthetic diagrams\n");
    writeFileSync(join(root, "assets", "architecture", "README.fr.md"), "# Schémas synthétiques\n");
    for (const [language, file] of [["en", "STEPS.md"], ["fr", "STEPS.fr.md"]]) {
        writeFileSync(join(root, "assets", "architecture", file), "# Synthetic architecture\n\n" +
            ids.map((id) => `## ${id} - Synthetic ${language} architecture\n\n\`\`\`mermaid\nflowchart LR\n  a["${language} ${id}"] --> b["Synthetic target"]\n\`\`\`\n`).join("\n"));
    }
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
        { status: "authored" }, { status: "authored", evidence: "Offline PASS", validatedOn: "2026-10-14" },
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

test("authored records offline evidence without a live validation date", (t) => {
    const { store } = setup(t);
    const state = store.update({ module: "02", status: "authored", evidence: "Synthetic offline PASS",
        revision: store.read().revision });
    assert.equal(state.modules[2].status, "authored");
    assert.equal(state.modules[2].validatedOn, "");
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

test("each language requires one Mermaid graph per module and exposes implementation status separately", (t) => {
    const { store, root, path } = setup(t);
    const before = readFileSync(path);
    const journey = readJourney(root, store.read());
    for (const language of [journey, journey.translations.fr]) {
        assert.match(language.documents.implementation.sourcePath, /IMPLEMENTATION-STATUS\.md$/);
        for (const module of language.modules) {
            assert.match(module.diagramSource.content, new RegExp(`${language.language} ${module.module}`));
            assert.ok(language.documents.architecture.content.includes(module.diagramSource.content));
        }
    }
    const source = join(root, "assets", "architecture", "STEPS.fr.md");
    const original = readFileSync(source, "utf8");
    writeFileSync(source, original.replaceAll("\n", "\r\n"));
    assert.equal(readJourney(root, store.read()).translations.fr.modules[0].diagramSource.content,
        journey.translations.fr.modules[0].diagramSource.content);
    writeFileSync(source, original +
        '\n## 00 - Duplicate graph\n```mermaid\nflowchart LR\n  a --> b\n```\n```mermaid\nflowchart LR\n  c --> d\n```\n');
    assert.throws(() => readJourney(root, store.read()), (error) => error.code === "invalid_document");
    writeFileSync(source, original.replace("## 04 -", "## Missing -"));
    assert.throws(() => readJourney(root, store.read()), (error) => error.code === "invalid_document");
    assert.deepEqual(readFileSync(path), before);
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
    assert.equal(result.stdout.match(/^PASS \d{2}\.(en|fr):/gm)?.length, 18);
    assert.equal(result.stdout.match(/^PASS STEPS(?:\.fr)?\.md:/gm)?.length, 2);
});

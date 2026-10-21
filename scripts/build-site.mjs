import { lstatSync, readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { parseProgress } from "../.github/extensions/workshop-build-board/progress.mjs";
import { readJourney } from "../.github/extensions/workshop-build-board/journey.mjs";

export const screenshots = ["azure-02-storage-public-access", "azure-02-storage-private-endpoints",
    "terminal-00-az-context", "terminal-02-az-runtime", "terminal-03-az-auth", "terminal-04-az-network",
    "terminal-05-az-identities", "terminal-06-az-counts", "terminal-07-az-gateway", "terminal-99-az-inventory",
    "azure-02-function-overview", "azure-02-function-keys", "azure-04-function-networking", "terminal-00-validate",
    "azure-03-function-authentication", "azure-03-app-registration-overview", "azure-03-app-roles",
    "azure-03-enterprise-app-properties", "terminal-03-operator", "terminal-03-alice",
    "azure-05-api-permissions", "azure-05-federated-credentials", "azure-06-kql-logs",
    "azure-06-observability-agent-answer", "azure-06-observability-agent-query", "azure-06-trace-span-attributes", "azure-06-trace-waterfall",
    "diagram-05-obo-hops-en", "diagram-05-obo-hops-fr", "diagram-05-rbac-checks-en", "diagram-05-rbac-checks-fr",
    "diagram-02-server-levels-en", "diagram-02-server-levels-fr",
    "client-01-inspector", "client-03-vscode", "azure-06-apic-register",
    "azure-04-mcp-servers", "azure-04b-mcp-tools", "azure-04b-mcp-policy", "terminal-04b-operator", "terminal-04b-alice",
    "terminal-04-operator", "terminal-04-bob", "terminal-05-bob",
    "azure-07-foundry-tool", "azure-07-foundry-approve", "azure-07-foundry-result", "terminal-07-foundry"];

const repository = fileURLToPath(new URL("../", import.meta.url));
const icons = ["azure", "microsoft", "entra", "apim", "functions", "storage", "insights", "api-center", "subscription", "foundry-agent-service", "copilot-studio"];
const modules = ["00", "01", "02", "03", "04", "05", "06", "07", "99"];
export const authorOnlyDocuments = ["runbook", "implementation", "buildProgress", "plan", "originalPlan",
    "architectureAuthoring", "originalArchitecture", "presenter", "hosting", "attendeeArchitecture", "sources"];

export function participantContent(text) {
    if (text === null) return null;
    let fenced = false, authorOnly = false;
    const lines = [];
    for (const line of text.split(/\r?\n/)) {
        if (/^\s*```/.test(line)) fenced = !fenced;
        if (!fenced && line === "<!-- author-only -->") {
            if (authorOnly) throw new Error("Nested author-only content is not supported.");
            authorOnly = true;
            continue;
        }
        if (!fenced && line === "<!-- /author-only -->") {
            if (!authorOnly) throw new Error("Unexpected author-only closing marker.");
            authorOnly = false;
            continue;
        }
        if (authorOnly) continue;
        lines.push(fenced ? line : line
            .replace("This is a talk track for the presenter, with no participant step.", "This integration is optional reading, not a participant exercise.")
            .replace("Do not run these steps in a participant tenant from the presenter side.", "Use your own approved account, not another participant's tenant.")
            .replace("Optional talk track, see", "Optional reading, see")
            .replace("optional talk track, not revalidated here", "optional reading, not revalidated here"));
    }
    if (authorOnly) throw new Error("An author-only block is missing its closing marker.");
    return lines.join("\n");
}

function readSource(root, parts) {
    for (let index = 0; index <= parts.length; index++) {
        const entry = lstatSync(join(root, ...parts.slice(0, index)));
        if (entry.isSymbolicLink() || (index < parts.length ? !entry.isDirectory() : !entry.isFile())) {
            throw new Error("Site sources must be regular files inside the repository.");
        }
    }
    return readFileSync(join(root, ...parts));
}

export function buildSite(root = repository, destination = join(root, "site-dist")) {
    const read = (parts) => readSource(root, parts);
    const progress = parseProgress(read(["docs", "PROGRESS.md"]).toString("utf8"));
    const journey = readJourney(root, progress);
    delete journey.revision;
    // Author-only pages (build runbook, open decisions, build status and plan, diagram authoring) stay in the repository
    // and the local authoring board; the published participant site never carries them.
    delete journey.openDecisions;
    for (const language of [journey, journey.translations.fr]) {
        const attendee = language.documents.attendeeArchitecture;
        if (!attendee?.content.includes("<!-- module-animations -->")) {
            throw new Error("The participant architecture guide needs its module animation marker.");
        }
        const animations = language.modules.filter((module) => module.animation).map((module) => {
            const french = language.language === "fr";
            const label = french ? `Mettre en pratique dans le module ${module.module}` : `Try it in module ${module.module}`;
            const target = `${french ? "../../" : "../"}${module.sourcePath}`;
            return `## ${Number(module.module)}. ${module.title}\n\n\`\`\`reveal\n${module.animation.content}\n\`\`\`\n\n[${label}](${target})\n`;
        }).join("\n");
        language.documents.integration = { ...attendee,
            content: attendee.content.replace("<!-- module-animations -->", animations) };
        for (const key of authorOnlyDocuments) delete language.documents[key];
        for (const doc of Object.values(language.documents)) doc.content = participantContent(doc.content);
        for (const module of language.modules) {
            for (const key of ["notes", "evidence", "validatedOn", "outline", "status"]) delete module[key];
            for (const key of ["guide", "learning", "hints"]) module[key] = participantContent(module[key]);
            for (const guide of Object.values(module.guides)) guide.guide = participantContent(guide.guide);
            if (module.originalGuide) module.originalGuide.content = participantContent(module.originalGuide.content);
        }
    }
    for (const language of [journey, journey.translations.fr]) {
        for (const module of language.modules) {
            for (const kind of ["svg", "png", "editable"]) module.diagram[kind] = module.diagram[kind].replace(/^\//, "");
        }
    }
    const extension = [".github", "extensions", "workshop-build-board"];
    let html = read([...extension, "board.html"]).toString("utf8");
    if (!html.includes('"__STATIC_SITE__"') || !html.includes('"__BOARD_KEY__"')) {
        throw new Error("The workshop template is missing its static-export markers.");
    }
    html = html.replace('"__STATIC_SITE__"', '"true"').replace('"__BOARD_KEY__"', '""');
    html = html.replace("<head>", `<head>
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'">
  <meta name="referrer" content="no-referrer">
  <meta name="description" content="Learn to govern Model Context Protocol on Azure. Separate portal-first and Terraform tracks, English and French guides, architecture and participant-owned preparation.">`);
    const files = new Map([
        ["index.html", html],
        ["locale-fr.js", read([...extension, "locale-fr.js"])],
        ["journey.json", JSON.stringify(journey)],
        [".nojekyll", ""],
    ]);
    for (const icon of icons) files.set(`assets/icons/${icon}.svg`, read(["assets", "icons", `${icon}.svg`]));
    for (const module of modules) {
        for (const language of ["en", "fr"]) {
            for (const format of ["svg", "png"]) {
                const name = `${module}.${language}.${format}`;
                files.set(`assets/architecture/${name}`, read(["assets", "architecture", name]));
            }
        }
    }
    files.set("assets/architecture/workshop.drawio", read(["assets", "architecture", "workshop.drawio"]));
    for (const name of ["session2.en.svg", "session2.en.png", "session2.fr.svg", "session2.fr.png", "session2.drawio"]) {
        files.set(`assets/architecture/${name}`, read(["assets", "architecture", name]));
    }
    for (const name of screenshots) files.set(`assets/screenshots/${name}.png`, read(["assets", "screenshots", `${name}.png`]));
    mkdirSync(destination);
    for (const [path, content] of files) {
        const parts = path.split("/");
        if (parts.length > 1) mkdirSync(join(destination, ...parts.slice(0, -1)), { recursive: true });
        writeFileSync(join(destination, ...parts), content, { flag: "wx" });
    }
    return { destination, files: files.size, paths: [...files.keys()] };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    const args = process.argv.slice(2);
    if (args.length && (args.length !== 2 || args[0] !== "--output")) {
        throw new Error("Usage: node scripts/build-site.mjs [--output <new-empty-directory>]");
    }
    const result = buildSite(repository, args.length ? resolve(args[1]) : undefined);
    console.log(`PASS static workshop site: ${result.files} allowlisted files in ${result.destination}. No cloud action executed.`);
}

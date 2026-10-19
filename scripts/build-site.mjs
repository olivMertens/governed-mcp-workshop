import { lstatSync, readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createHash } from "node:crypto";
import { parseProgress } from "../.github/extensions/workshop-build-board/progress.mjs";
import { readJourney } from "../.github/extensions/workshop-build-board/journey.mjs";
import { screenshots } from "./portal-server.mjs";

const repository = fileURLToPath(new URL("../", import.meta.url));
const icons = ["azure", "microsoft", "entra", "apim", "functions", "storage", "insights", "api-center", "subscription", "foundry-agent-service", "copilot-studio"];
const modules = ["00", "01", "02", "03", "04", "05", "06", "07", "99"];
export const authorOnlyDocuments = ["runbook", "implementation", "buildProgress", "plan", "originalPlan", "architectureAuthoring", "originalArchitecture"];

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
        for (const key of authorOnlyDocuments) delete language.documents[key];
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
  <meta name="description" content="Learn to govern Model Context Protocol on Azure. English and French guides, architecture, workspace choices and participant-owned Terraform preparation.">`);
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
    for (const name of screenshots) files.set(`assets/screenshots/${name}.png`, read(["assets", "screenshots", `${name}.png`]));
    mkdirSync(destination);
    for (const [path, content] of files) {
        const parts = path.split("/");
        if (parts.length > 1) mkdirSync(join(destination, ...parts.slice(0, -1)), { recursive: true });
        writeFileSync(join(destination, ...parts), content, { flag: "wx" });
    }
    return { destination, files: files.size, paths: [...files.keys()] };
}

export function buildPortal(root = repository, destination = join(root, "portal-dist")) {
    const server = readSource(root, ["scripts", "portal-server.mjs"]);
    const result = buildSite(root, destination);
    const manifest = {
        schema: 1,
        files: result.paths.map((path) => ({
            path,
            sha256: createHash("sha256").update(readFileSync(join(destination, ...path.split("/")))).digest("hex"),
        })),
    };
    writeFileSync(join(destination, "site-manifest.json"), JSON.stringify(manifest), { flag: "wx" });
    writeFileSync(join(destination, "server.mjs"), server, { flag: "wx" });
    return { destination, files: result.files + 2 };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    const args = process.argv.slice(2);
    if (args.length && (args.length !== 2 || args[0] !== "--output")) {
        throw new Error("Usage: node scripts/build-site.mjs [--output <new-empty-directory>]");
    }
    const result = buildSite(repository, args.length ? resolve(args[1]) : undefined);
    console.log(`PASS static workshop site: ${result.files} allowlisted files in ${result.destination}. No cloud action executed.`);
}

import { createServer } from "node:http";
import { createHash, timingSafeEqual } from "node:crypto";
import { lstatSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const entry = fileURLToPath(import.meta.url);
const icons = ["azure", "microsoft", "entra", "apim", "functions", "storage", "insights", "api-center", "subscription", "foundry-agent-service", "copilot-studio"];
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
export const publicPaths = ["index.html", "locale-fr.js", "journey.json", ".nojekyll",
    ...icons.map((icon) => `assets/icons/${icon}.svg`), "assets/architecture/workshop.drawio", "assets/architecture/session2.drawio",
    ...screenshots.map((name) => `assets/screenshots/${name}.png`)];
for (const module of ["00", "01", "02", "03", "04", "05", "06", "07", "99", "session2"]) {
    for (const language of ["en", "fr"]) {
        for (const format of ["svg", "png"]) publicPaths.push(`assets/architecture/${module}.${language}.${format}`);
    }
}
const types = { html: "text/html; charset=utf-8", js: "text/javascript; charset=utf-8",
    json: "application/json; charset=utf-8", svg: "image/svg+xml", png: "image/png",
    drawio: "application/xml; charset=utf-8" };
const headers = {
    "Content-Security-Policy": "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "X-Frame-Options": "DENY",
    "Cache-Control": "no-store",
};
function readRegular(root, path) {
    const parts = path.split("/");
    for (let index = 0; index <= parts.length; index++) {
        const info = lstatSync(join(root, ...parts.slice(0, index)));
        if (info.isSymbolicLink() || (index === parts.length ? !info.isFile() : !info.isDirectory())) {
            throw new Error("Portal bundle contains a linked or non-regular entry.");
        }
    }
    return readFileSync(join(root, ...parts));
}

export function verifyPortal(root) {
    const manifest = JSON.parse(readRegular(root, "site-manifest.json").toString("utf8"));
    if (manifest.schema !== 1 || !Array.isArray(manifest.files) || manifest.files.length !== publicPaths.length) {
        throw new Error("Portal manifest has an invalid schema or file count.");
    }
    const assets = new Map();
    for (const file of manifest.files) {
        if (!publicPaths.includes(file.path) || assets.has(`/${file.path}`) || !/^[a-f0-9]{64}$/.test(file.sha256)) {
            throw new Error("Portal manifest contains a duplicate, invalid or non-public entry.");
        }
        const content = readRegular(root, file.path);
        const actual = createHash("sha256").update(content).digest();
        if (!timingSafeEqual(actual, Buffer.from(file.sha256, "hex"))) {
            throw new Error("Portal asset integrity check failed.");
        }
        assets.set(`/${file.path}`, { content, type: types[file.path.split(".").at(-1)] ?? "application/octet-stream" });
    }
    if (!readRegular(root, "server.mjs").equals(readFileSync(entry))) {
        throw new Error("Bundled server differs from the reviewed runtime.");
    }
    const allowed = new Set([...publicPaths, "server.mjs", "site-manifest.json"]);
    for (const file of readdirSync(root, { recursive: true, withFileTypes: true })) {
        const relative = join(file.parentPath, file.name).slice(resolve(root).length + 1).replaceAll("\\", "/");
        if (file.isSymbolicLink() || (!file.isDirectory() && (!file.isFile() || !allowed.has(relative)))) {
            throw new Error("Bundle contains an unexpected file; refusing publication.");
        }
    }
    return assets;
}

// Only non-secret, allowlisted connection hints from this participant's own deployment (Terraform app settings).
export function participantConfig(env = process.env) {
    const config = {};
    const endpoint = env.WORKSHOP_MCP_ENDPOINT;
    if (endpoint) {
        let url;
        try { url = new URL(endpoint); } catch { url = null; }
        if (!url || url.protocol !== "https:" || url.username || url.password || url.search || url.hash ||
            !url.pathname.endsWith("/mcp") || endpoint.length > 300) {
            throw new Error("WORKSHOP_MCP_ENDPOINT must be an HTTPS MCP endpoint without credentials or query.");
        }
        config.mcpEndpoint = url.href;
    }
    const scope = env.WORKSHOP_MCP_SCOPE;
    if (scope) {
        if (!/^api:\/\/[A-Za-z0-9][A-Za-z0-9._/-]{0,199}\/user_impersonation$/.test(scope)) {
            throw new Error("WORKSHOP_MCP_SCOPE must be an api:// user_impersonation scope.");
        }
        config.mcpScope = scope;
    }
    return Object.keys(config).length ? JSON.stringify(config) : null;
}

export function startPortal({ root = dirname(entry), port = Number(process.env.PORT ?? 8080), host = "127.0.0.1", env = process.env } = {}) {
    if (!Number.isInteger(port) || port < 0 || port > 65535) throw new Error("PORT must be a valid integer TCP port.");
    const assets = verifyPortal(resolve(root));
    const participant = participantConfig(env);
    const server = createServer((request, response) => {
        const send = (status, type, content) => {
            response.writeHead(status, { ...headers, "Content-Type": type, "Content-Length": Buffer.byteLength(content),
                ...(status === 405 ? { Allow: "GET, HEAD" } : {}) });
            response.end(request.method === "HEAD" ? undefined : content);
        };
        if (!["GET", "HEAD"].includes(request.method)) return send(405, "text/plain", "Method not allowed.");
        let url;
        try { url = new URL(request.url, "http://localhost"); }
        catch (error) {
            if (!(error instanceof TypeError)) throw error;
            return send(400, "text/plain", "Invalid request URL.");
        }
        const selectors = { lang: ["en", "fr"], track: ["low-code", "terraform"] };
        if ([...url.searchParams].some(([key, value]) => !Object.hasOwn(selectors, key) ||
            !selectors[key].includes(value) || url.searchParams.getAll(key).length !== 1)) {
            return send(400, "text/plain", "Only the public language and track selectors are supported.");
        }
        if (url.pathname === "/health") return send(200, "application/json", '{"status":"ok"}');
        if (url.pathname === "/participant.json") {
            return participant ? send(200, "application/json; charset=utf-8", participant) : send(404, "text/plain", "Not found.");
        }
        const asset = assets.get(url.pathname === "/" ? "/index.html" : url.pathname);
        if (!asset || url.pathname === "/.nojekyll") return send(404, "text/plain", "Not found.");
        send(200, asset.type, asset.content);
    });
    server.requestTimeout = 15000;
    server.headersTimeout = 10000;
    return server.listen(port, host);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    if (process.argv[2] === "--verify" && process.argv.length <= 4) {
        verifyPortal(resolve(process.argv[3] ?? dirname(entry)));
        console.log(`PASS ${publicPaths.length} public assets and the reviewed runtime; no private files or cloud access.`);
    } else if (process.argv.length === 2) {
        if (process.env.PORT && (!/^\d+$/.test(process.env.PORT) || Number(process.env.PORT) < 1)) {
            throw new Error("App Service PORT must be a positive integer.");
        }
        const server = startPortal({ host: process.env.PORT ? "0.0.0.0" : "127.0.0.1" });
        server.on("error", () => { console.error("FAIL public portal listener."); process.exitCode = 1; });
        for (const signal of ["SIGTERM", "SIGINT"]) process.once(signal, () => server.close());
    } else { throw new Error("Usage: node server.mjs [--verify [bundle-directory]]"); }
}

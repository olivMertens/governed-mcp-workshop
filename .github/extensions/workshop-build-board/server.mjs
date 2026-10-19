import { createServer } from "node:http";
import { randomBytes } from "node:crypto";
import { lstatSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { BoardError } from "./progress.mjs";

const boardUrl = new URL("./board.html", import.meta.url);
const frenchUrl = new URL("./locale-fr.js", import.meta.url);
const defaultAssets = fileURLToPath(new URL("../../../assets/", import.meta.url));

function publicAsset(url, root) {
    let type;
    if (/^\/assets\/icons\/(?:azure|microsoft|entra|apim|functions|storage|insights|api-center|subscription|foundry-agent-service|copilot-studio)\.svg$/.test(url) ||
        /^\/assets\/architecture\/(?:00|01|02|03|04|05|06|07|99)\.(?:en|fr)\.svg$/.test(url)) type = "image/svg+xml";
    else if (/^\/assets\/architecture\/(?:00|01|02|03|04|05|06|07|99)\.(?:en|fr)\.png$/.test(url) ||
        /^\/assets\/screenshots\/(?:azure-02-storage-(?:public-access|private-endpoints)|azure-03-(?:function-authentication|app-registration-overview|app-roles|enterprise-app-properties)|terminal-03-(?:operator|alice)|azure-05-(?:api-permissions|federated-credentials)|azure-06-kql-logs)\.png$/.test(url)) type = "image/png";
    else if (url === "/assets/architecture/workshop.drawio") type = "application/xml";
    else throw new BoardError("not_found", "Unknown public asset.", 404);
    const parts = url.slice("/assets/".length).split("/");
    for (let index = 0; index <= parts.length; index++) {
        let entry;
        try { entry = lstatSync(join(root, ...parts.slice(0, index))); }
        catch (error) {
            if (error.code === "ENOENT") throw new BoardError("not_found", "Public asset is not published.", 404);
            throw error;
        }
        if (entry.isSymbolicLink() || (index < parts.length ? !entry.isDirectory() : !entry.isFile())) {
            throw new BoardError("invalid_asset", "Public assets must be regular repository files.", 403);
        }
    }
    return { type, body: readFileSync(join(root, ...parts)) };
}

export async function startServer(store, readJourney, assetsRoot = defaultAssets) {
    const key = randomBytes(32).toString("base64url");
    let origin;
    const server = createServer(async (req, res) => {
        res.setHeader("Cache-Control", "no-store");
        res.setHeader("X-Content-Type-Options", "nosniff");
        res.setHeader("Cross-Origin-Resource-Policy", "same-origin");
        res.setHeader("Referrer-Policy", "no-referrer");
        res.setHeader("Content-Security-Policy",
            "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'");
        function json(status, value) {
            res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
            res.end(JSON.stringify(value));
        }
        try {
            if (req.headers.host !== new URL(origin).host) {
                throw new BoardError("invalid_host", "Unexpected host.", 403);
            }
            if (req.method === "GET" && /^\/(?:\?lang=(?:en|fr))?$/.test(req.url)) {
                // Read on each request so a long-lived canvas never serves a stale interface.
                res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
                res.end(readFileSync(boardUrl, "utf8").replace("__BOARD_KEY__", key));
                return;
            }
            if (req.method === "GET" && req.url === "/locale-fr.js") {
                res.writeHead(200, { "Content-Type": "text/javascript; charset=utf-8" });
                res.end(readFileSync(frenchUrl));
                return;
            }
            if (req.method === "GET" && req.url.startsWith("/assets/")) {
                const asset = publicAsset(req.url, assetsRoot);
                res.writeHead(200, { "Content-Type": asset.type });
                res.end(asset.body);
                return;
            }
            if (req.headers["x-board-key"] !== key || (req.headers.origin && req.headers.origin !== origin)) {
                throw new BoardError("forbidden", "Open the board to access its local API.", 403);
            }
            if (req.method === "GET" && req.url === "/progress") {
                json(200, store.read());
                return;
            }
            if (req.method === "GET" && req.url === "/journey" && readJourney) {
                json(200, readJourney());
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
                json(500, { code: "board_error", error: "Could not load workshop content or save progress. Inspect the extension log." });
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

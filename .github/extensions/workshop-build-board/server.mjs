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

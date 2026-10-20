import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { once } from "node:events";
import { buildPortal } from "./build-site.mjs";
import { startPortal, verifyPortal, publicPaths, participantConfig } from "./portal-server.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
function bundle(t) {
    const directory = mkdtempSync(join(tmpdir(), "workshop-public-portal-"));
    t.after(() => rmSync(directory, { recursive: true, force: true }));
    const destination = join(directory, "bundle");
    assert.equal(buildPortal(root, destination).files, 90);
    return destination;
}
test("public hosting verifies exact assets and refuses tampering, private extras or a changed server", (t) => {
    const directory = bundle(t);
    assert.equal(verifyPortal(directory).size, 88);
    const server = readFileSync(join(directory, "server.mjs"));
    writeFileSync(join(directory, "server.mjs"), "throw new Error('not the reviewed server');");
    assert.throws(() => verifyPortal(directory), /reviewed runtime/);
    writeFileSync(join(directory, "server.mjs"), server);
    writeFileSync(join(directory, "private.txt"), "synthetic private data");
    assert.throws(() => verifyPortal(directory), /unexpected file/);
    rmSync(join(directory, "private.txt"));
    writeFileSync(join(directory, "journey.json"), "{}");
    assert.throws(() => verifyPortal(directory), /integrity/);
});
test("public server serves bilingual assets and health, but never exposes code, files or canvas writes", async (t) => {
    const directory = bundle(t);
    const server = startPortal({ root: directory, port: 0, env: {} });
    await once(server, "listening");
    t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); }));
    const base = `http://127.0.0.1:${server.address().port}`;
    for (const path of ["/", "/?lang=fr", "/health", ...publicPaths.filter((path) => path !== ".nojekyll").map((path) => `/${path}`)]) {
        const response = await fetch(`${base}${path}`);
        assert.equal(response.status, 200, path);
        assert.equal(response.headers.get("x-content-type-options"), "nosniff");
        assert.match(response.headers.get("content-security-policy"), /connect-src 'self'/);
        if (path === "/") assert.match(await response.text(), /const staticSite = "true" === "true"/);
        else await response.arrayBuffer();
    }
    for (const path of ["/server.mjs", "/site-manifest.json", "/.git/config", "/.workshop/participant.tfvars.json",
        "/api/progress", "/assets/architecture/", "/.nojekyll", "/participant.json"]) {
        assert.equal((await fetch(`${base}${path}`)).status, 404, path);
    }
    assert.equal((await fetch(`${base}/?token=synthetic`)).status, 400);
    assert.equal((await fetch(`${base}/`, { method: "POST", body: "synthetic" })).status, 405);
    const head = await fetch(base, { method: "HEAD" });
    assert.equal(head.status, 200);
    assert.equal(await head.text(), "");
    assert.equal((await fetch(`${base}/health`)).headers.get("cache-control"), "no-store");
});
test("participant portal serves only allowlisted, non-secret connection hints", async (t) => {
    assert.equal(participantConfig({}), null);
    assert.equal(participantConfig({ ARM_CLIENT_SECRET: "synthetic", WORKSHOP_MCP_KEY: "synthetic" }), null);
    for (const endpoint of ["http://func.example.com/runtime/webhooks/mcp", "https://func.example.com/runtime/webhooks/mcp?code=synthetic",
        "https://user:pass@func.example.com/mcp", "https://func.example.com/admin", "not a url"]) {
        assert.throws(() => participantConfig({ WORKSHOP_MCP_ENDPOINT: endpoint }), /HTTPS MCP endpoint/, endpoint);
    }
    assert.throws(() => participantConfig({ WORKSHOP_MCP_SCOPE: "https://graph.microsoft.com/.default" }), /user_impersonation/);
    const directory = bundle(t);
    const server = startPortal({ root: directory, port: 0, env: {
        WORKSHOP_MCP_ENDPOINT: "https://func-mcp-p01-0123456789.azurewebsites.net/runtime/webhooks/mcp",
        WORKSHOP_MCP_SCOPE: "api://44444444-4444-4444-8444-444444444444/user_impersonation",
        APPLICATIONINSIGHTS_CONNECTION_STRING: "InstrumentationKey=synthetic",
    } });
    await once(server, "listening");
    t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); }));
    const response = await fetch(`http://127.0.0.1:${server.address().port}/participant.json`);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.deepEqual(await response.json(), {
        mcpEndpoint: "https://func-mcp-p01-0123456789.azurewebsites.net/runtime/webhooks/mcp",
        mcpScope: "api://44444444-4444-4444-8444-444444444444/user_impersonation",
    });
});
test("public manifest rejects duplicate and path traversal entries before starting HTTP", (t) => {
    const directory = bundle(t);
    const path = join(directory, "site-manifest.json");
    const manifest = JSON.parse(readFileSync(path, "utf8"));
    manifest.files[0].path = "../private.txt";
    writeFileSync(path, JSON.stringify(manifest));
    assert.throws(() => startPortal({ root: directory, port: 0 }), /non-public entry/);
    manifest.files[0] = manifest.files[1];
    writeFileSync(path, JSON.stringify(manifest));
    assert.throws(() => verifyPortal(directory), /duplicate/);
});

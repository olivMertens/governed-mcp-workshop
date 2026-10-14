import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));

test("module 01 validates the real SDK stdio server without Azure or payload logs", () => {
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-File",
        join(root, "modules", "01-discover-mcp", "validate.ps1")],
    { cwd: root, encoding: "utf8", timeout: 120_000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
    for (const name of [
        "locked local server build", "SDK protocol negotiation",
        "tools/list exposes exactly one read tool", "read-only synthetic tool annotations",
        "required service input schema", "exact synthetic result for workshop-api",
        "exact synthetic result for ticket-queue", "unknown service returns a tool error",
        "missing service returns a tool error", "write tool is not exposed",
        "server remains responsive after rejected inputs",
        "no server stderr logging during tested calls", "local MCP checks complete",
    ]) {
        assert.ok(result.stdout.includes(`PASS ${name} (`), `Missing check: ${name}`);
    }
    assert.match(result.stdout, /MANUAL CHECK: client approval prompts are not tested/);
    assert.doesNotMatch(result.stdout + result.stderr, /"structuredContent"|"service":|"source":/);
});

test("VS Code local server config preserves Learn and launches the built DLL without approval overrides", () => {
    const config = JSON.parse(readFileSync(join(root, ".vscode", "mcp.json"), "utf8"));
    assert.equal(config.servers["microsoft-learn"].url, "https://learn.microsoft.com/api/mcp");
    assert.deepEqual(config.servers["workshop-local"], {
        type: "stdio",
        command: "dotnet",
        args: ["${workspaceFolder}/modules/01-discover-mcp/server/bin/Release/net10.0/Workshop.LocalMcp.dll"],
    });
});

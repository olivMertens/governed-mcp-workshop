import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const script = readFileSync(new URL("deploy-module.ps1", import.meta.url), "utf8");

test("deploy-module parses as PowerShell", (t) => {
    const path = `${root}scripts/deploy-module.ps1`.replaceAll("'", "''");
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command",
        `$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('${path}',[ref]$null,[ref]$e); exit $e.Count`],
        { encoding: "utf8" });
    if (result.error?.code === "ENOENT") { t.skip("PowerShell 7.4+ is required."); return; }
    assert.equal(result.status, 0, result.stdout + result.stderr);
});

test("deploy-module applies only a saved plan after a typed yes, never auto-approve", () => {
    assert.doesNotMatch(script, /terraform[^\n]*-auto-approve/);
    assert.match(script, /Read-Host "Type yes to apply exactly this plan/);
    assert.match(script, /if \(\$answer -cne 'yes'\)/);
    assert.match(script, /apply -input=false \$plan/);
    assert.ok(script.indexOf("Assert-WorkshopAzureContext") < script.indexOf("plan -input=false"), "context is checked before the plan");
});

test("deploy-module passes the private files in the module guide order and keeps part B while it exists", () => {
    const order = [...script.matchAll(/file = '([\w-]+\.tfvars\.json)'/g)].map((match) => match[1]);
    assert.deepEqual(order, [
        "participant.tfvars.json", "module02.tfvars.json", "module03.tfvars.json", "module04.tfvars.json",
        "module04b.tfvars.json", "module05.tfvars.json", "module07.tfvars.json",
        "entra.tfvars.json", "entra-module05.tfvars.json", "entra-module07.tfvars.json",
    ]);
    // Module 04 guide: while part B exists, keep passing module04b.tfvars.json to every workload plan.
    assert.match(script, /if \(Test-Path -LiteralPath \$path\)/);
    assert.match(script, /validate-rest-mcp\.ps1/);
});

test("every private file named by deploy-module is created by a module guide", () => {
    const guides = ["00-prerequisites", "02-open-server", "03-entra-authentication", "04-governed-gateway",
        "05-delegated-and-app-only", "07-clients"].map((name) => readFileSync(`${root}modules/${name}/README.md`, "utf8")).join("\n")
        + readFileSync(`${root}docs/GETTING-STARTED.md`, "utf8");
    for (const [, file] of script.matchAll(/file = '([\w-]+\.tfvars\.json)'/g)) {
        assert.ok(guides.includes(file), `${file} is not documented in a guide`);
    }
});

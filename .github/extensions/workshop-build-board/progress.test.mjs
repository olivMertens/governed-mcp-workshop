import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createProgressStore, parseProgress } from "./progress.mjs";
import { startServer } from "./server.mjs";

const ids = ["00", "01", "02", "03", "04", "05", "06", "07", "99"];
const fixture = "# Progress\n\n| Module | Title | Status | Validated on | Evidence | Notes |\n" +
    "|---|---|---|---|---|---|\n" +
    ids.map((id) => `| ${id} | Synthetic module ${id} | todo | | | Keep note |`).join("\n") +
    "\n\n## Open decisions\n- Synthetic decision.\n\n## Deviations from the build plan\nNone yet.\n";

function setup(t, content = fixture) {
    const root = mkdtempSync(join(tmpdir(), "workshop-board-test-"));
    mkdirSync(join(root, "docs"));
    const path = join(root, "docs", "PROGRESS.md");
    writeFileSync(path, content);
    t.after(() => rmSync(root, { recursive: true }));
    const store = createProgressStore(root);
    return { store, path };
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

test("rejects duplicate modules and missing decisions rather than returning defaults", () => {
    assert.throws(() => parseProgress(fixture.replace("| 99 |", "| 00 |")));
    assert.throws(() => parseProgress(fixture.replace("## Open decisions", "## Other section")));
});

test("loopback server protects reads and writes and returns explicit errors", async (t) => {
    const { store } = setup(t);
    const entry = await startServer(store);
    t.after(() => entry.close());
    const html = await (await fetch(entry.url)).text();
    assert.match(html, /Workshop build board/);
    const key = html.match(/const key = "([A-Za-z0-9_-]+)"/)[1];
    assert.equal((await fetch(`${entry.url}progress`)).status, 403);
    const headers = { "x-board-key": key, "Content-Type": "application/json" };
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

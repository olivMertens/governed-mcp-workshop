import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, rmSync, existsSync, mkdirSync, writeFileSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildSite } from "./build-site.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));

test("Git preserves SVG bytes and binary PNG provenance on Windows checkouts", () => {
    const attributes = readFileSync(join(root, ".gitattributes"), "utf8");
    assert.match(attributes, /^\*\.svg text eol=lf$/m);
    assert.match(attributes, /^\*\.png binary$/m);
});

test("public site exports only the allowlist, with no capability, root URLs, private files or API dependency", (t) => {
    const temporary = mkdtempSync(join(tmpdir(), "workshop-site-"));
    t.after(() => rmSync(temporary, { recursive: true, force: true }));
    const output = join(temporary, "public");
    const result = buildSite(root, output);
    assert.equal(result.files, 50);
    assert.deepEqual(readdirSync(output).sort(), [".nojekyll", "assets", "index.html", "journey.json", "locale-fr.js"]);
    const html = readFileSync(join(output, "index.html"), "utf8");
    assert.match(html, /const staticSite = "true" === "true"/);
    assert.match(html, /const key = ""/);
    assert.doesNotMatch(html, /__BOARD_KEY__|__STATIC_SITE__|src="\/|image\.src = `\/assets/);
    assert.match(html, /Content-Security-Policy/);
    const journey = JSON.parse(readFileSync(join(output, "journey.json"), "utf8"));
    assert.equal(journey.revision, undefined);
    for (const language of [journey, journey.translations.fr]) {
        assert.equal(language.modules.length, 9);
        for (const module of language.modules) {
            assert.match(module.diagramSource.content, /^flowchart LR\n/);
            assert.ok(language.documents.architecture.content.replaceAll("\r\n", "\n").includes(module.diagramSource.content));
            for (const path of Object.values(module.diagram)) {
                assert.match(path, /^assets\/architecture\//);
                assert.ok(existsSync(join(output, path)));
            }
            assert.match(language.documents.implementation.sourcePath, /IMPLEMENTATION-STATUS\.md$/);
        }
    }
    assert.deepEqual(readdirSync(join(output, "assets")).sort(), ["architecture", "icons"]);
    assert.throws(() => buildSite(root, output), { code: "EEXIST" });
});

test("static export refuses linked source directories before reading their contents or creating output", (t) => {
    const temporary = mkdtempSync(join(tmpdir(), "workshop-site-link-"));
    t.after(() => rmSync(temporary, { recursive: true, force: true }));
    const fixture = join(temporary, "repository");
    const outside = join(temporary, "outside");
    mkdirSync(fixture);
    mkdirSync(outside);
    writeFileSync(join(outside, "PROGRESS.md"), "Synthetic content that must not be read.");
    symlinkSync(outside, join(fixture, "docs"), process.platform === "win32" ? "junction" : "dir");
    const output = join(temporary, "public");
    assert.throws(() => buildSite(fixture, output), /regular files inside the repository/);
    assert.equal(existsSync(output), false);
});

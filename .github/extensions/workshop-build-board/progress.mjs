import { createHash } from "node:crypto";
import { lstatSync, readFileSync, openSync, writeSync, ftruncateSync, fsyncSync, closeSync } from "node:fs";
import { join } from "node:path";

// "authored": built and offline checks pass; live validation runs in a participant's own subscription.
export const statuses = ["todo", "in-progress", "authored", "validated", "blocked"];
const moduleIds = ["00", "01", "02", "03", "04", "05", "06", "07", "99"];

export class BoardError extends Error {
    constructor(code, message, status = 400) {
        super(message);
        this.code = code;
        this.status = status;
    }
}

export const updateSchema = {
    type: "object",
    additionalProperties: false,
    required: ["module", "status", "evidence", "revision"],
    properties: {
        module: { type: "string", enum: moduleIds },
        status: { type: "string", enum: statuses },
        evidence: { type: "string", maxLength: 2000 },
        notes: { type: "string", maxLength: 2000 },
        validatedOn: { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" },
        revision: { type: "string", pattern: "^[a-f0-9]{64}$" },
    },
};

function revision(content) {
    return createHash("sha256").update(content).digest("hex");
}

export function parseProgress(content) {
    const lines = content.split(/\r?\n/);
    const modules = [];
    for (const [line, text] of lines.entries()) {
        if (!/^\|\s*\d{2}\s*\|/.test(text)) continue;
        const cells = text.split("|").slice(1, -1).map((cell) => cell.trim());
        if (cells.length !== 6 || !moduleIds.includes(cells[0]) || !statuses.includes(cells[2])) {
            throw new BoardError("invalid_progress", "Invalid module table in PROGRESS.md.");
        }
        modules.push({
            module: cells[0], title: cells[1], status: cells[2], validatedOn: cells[3],
            evidence: cells[4], notes: cells[5], line,
        });
    }
    if (modules.length !== moduleIds.length || new Set(modules.map((m) => m.module)).size !== moduleIds.length) {
        throw new BoardError("invalid_progress", "PROGRESS.md must contain each workshop module exactly once.");
    }
    const heading = lines.indexOf("## Open decisions");
    if (heading < 0) throw new BoardError("invalid_progress", "The Open decisions section is missing.");
    let end = lines.findIndex((line, index) => index > heading && line.startsWith("## "));
    if (end < 0) end = lines.length;
    return {
        revision: revision(content),
        modules: modules.map(({ line, ...module }) => module),
        openDecisions: lines.slice(heading + 1, end).join("\n").trim(),
        lines,
        rowLines: new Map(modules.map((m) => [m.module, m.line])),
    };
}

function validateUpdate(input) {
    if (!input || typeof input !== "object" || Array.isArray(input)) {
        throw new BoardError("invalid_input", "An update object is required.");
    }
    if (Object.keys(input).some((key) => !Object.hasOwn(updateSchema.properties, key))) {
        throw new BoardError("invalid_input", "Unknown update property.");
    }
    if (!moduleIds.includes(input.module) || !statuses.includes(input.status) ||
        typeof input.revision !== "string" || !/^[a-f0-9]{64}$/.test(input.revision)) {
        throw new BoardError("invalid_input", "A known module, status, and revision are required.");
    }
    for (const key of ["evidence", "notes"]) {
        if (key === "notes" && input.notes === undefined) continue;
        if (typeof input[key] !== "string" || input[key].length > 2000 || /[|\r\n\u0000-\u001f]/.test(input[key])) {
            throw new BoardError("invalid_input", `${key} must be a single table cell, without pipes or control characters.`);
        }
    }
    const timestamp = Date.parse(`${input.validatedOn}T00:00:00Z`);
    if (input.validatedOn !== undefined &&
        (typeof input.validatedOn !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(input.validatedOn) ||
        Number.isNaN(timestamp) || new Date(timestamp).toISOString().slice(0, 10) !== input.validatedOn)) {
        throw new BoardError("invalid_input", "validatedOn must be a real YYYY-MM-DD date.");
    }
    if (input.status === "validated" && (!input.evidence.trim() || !input.validatedOn)) {
        throw new BoardError("missing_evidence", "Validated requires actual module validation evidence and validatedOn.");
    }
    if (input.status === "authored" && !input.evidence.trim()) {
        throw new BoardError("missing_evidence", "Authored requires offline check evidence.");
    }
    if (input.status !== "validated" && input.validatedOn !== undefined) {
        throw new BoardError("invalid_input", "Only a validated module can have a validation date.");
    }
}

export function createProgressStore(root) {
    const path = join(root, "docs", "PROGRESS.md");
    function load() {
        if (!lstatSync(path).isFile() || lstatSync(path).isSymbolicLink()) {
            throw new BoardError("invalid_progress", "PROGRESS.md must be a regular file.");
        }
        return readFileSync(path, "utf8");
    }
    function read() {
        const { lines, rowLines, ...state } = parseProgress(load());
        return state;
    }
    function update(input) {
        validateUpdate(input);
        const content = load();
        const parsed = parseProgress(content);
        if (parsed.revision !== input.revision) {
            throw new BoardError("stale_revision", "PROGRESS.md changed. Refresh before saving.", 409);
        }
        const module = parsed.modules.find((m) => m.module === input.module);
        const notes = input.notes === undefined ? module.notes : input.notes.trim();
        const date = input.status === "validated" ? input.validatedOn : "";
        parsed.lines[parsed.rowLines.get(input.module)] =
            `| ${module.module} | ${module.title} | ${input.status} | ${date} | ${input.evidence.trim()} | ${notes} |`;
        const updated = parsed.lines.join(content.includes("\r\n") ? "\r\n" : "\n");
        const fd = openSync(path, "r+");
        try {
            if (revision(readFileSync(fd, "utf8")) !== input.revision) {
                throw new BoardError("stale_revision", "PROGRESS.md changed. Refresh before saving.", 409);
            }
            const bytes = Buffer.from(updated);
            let written = 0;
            while (written < bytes.length) written += writeSync(fd, bytes, written, bytes.length - written, written);
            ftruncateSync(fd, bytes.length);
            fsyncSync(fd);
        } finally {
            closeSync(fd);
        }
        return read();
    }
    return { read, update };
}

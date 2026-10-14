import { fileURLToPath } from "node:url";
import { joinSession, createCanvas, CanvasError } from "@github/copilot-sdk/extension";
import { createProgressStore, BoardError, updateSchema } from "./progress.mjs";
import { startServer } from "./server.mjs";

const store = createProgressStore(fileURLToPath(new URL("../../../", import.meta.url)));
const servers = new Map();

function action(handler) {
    return (ctx) => {
        try {
            return handler(ctx.input);
        } catch (error) {
            if (error instanceof BoardError) throw new CanvasError(error.code, error.message);
            throw error;
        }
    };
}

await joinSession({
    canvases: [
        createCanvas({
            id: "workshop-build-board",
            displayName: "Workshop build board",
            description: "Read workshop progress and decisions; edit module status, evidence, and notes in PROGRESS.md.",
            inputSchema: { type: "object", properties: {}, additionalProperties: false },
            actions: [
                {
                    name: "get_progress",
                    description: "Read modules, open decisions, and the revision required for an update.",
                    inputSchema: { type: "object", properties: {}, additionalProperties: false },
                    handler: action(() => store.read()),
                },
                {
                    name: "set_module_status",
                    description: "Update a module using the last read revision. Validated needs actual evidence and a date.",
                    inputSchema: updateSchema,
                    handler: action((input) => store.update(input)),
                },
                {
                    name: "list_open_decisions",
                    description: "Read the Open decisions section from PROGRESS.md.",
                    inputSchema: { type: "object", properties: {}, additionalProperties: false },
                    handler: action(() => ({ openDecisions: store.read().openDecisions })),
                },
            ],
            open: async (ctx) => {
                store.read();
                let entry = servers.get(ctx.instanceId);
                if (!entry) {
                    entry = await startServer(store);
                    servers.set(ctx.instanceId, entry);
                }
                return { title: "Workshop build board", url: entry.url };
            },
            onClose: async (ctx) => {
                const entry = servers.get(ctx.instanceId);
                if (entry) {
                    servers.delete(ctx.instanceId);
                    await entry.close();
                }
            },
        }),
    ],
});

import { lstatSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { BoardError } from "./progress.mjs";

const folders = {
    "00": "00-prerequisites", "01": "01-discover-mcp", "02": "02-open-server",
    "03": "03-entra-authentication", "04": "04-governed-gateway",
    "05": "05-delegated-and-app-only", "06": "06-observe-and-inventory",
    "07": "07-other-clients", "99": "99-cleanup",
};

function readDocument(root, parts, optional = false) {
    for (let index = 1; index <= parts.length; index++) {
        const path = join(root, ...parts.slice(0, index));
        let entry;
        try {
            entry = lstatSync(path);
        } catch (error) {
            if (optional && error.code === "ENOENT") return null;
            throw error;
        }
        if (entry.isSymbolicLink() || (index < parts.length ? !entry.isDirectory() : !entry.isFile())) {
            throw new BoardError("invalid_document", "Workshop documents must be regular files inside the repository.");
        }
    }
    return readFileSync(join(root, ...parts), "utf8");
}

function moduleSections(document) {
    const sections = new Map();
    const headings = [...document.matchAll(/^## (\d{2}) [^\r\n]+/gm)];
    for (const heading of headings) {
        const start = heading.index + heading[0].length;
        const next = document.slice(start).search(/\r?\n## /);
        sections.set(heading[1], document.slice(start, next < 0 ? undefined : start + next).trim());
    }
    return sections;
}

export function readJourney(root, progress) {
    function available(parts) {
        return readDocument(root, parts, true) !== null ? parts.join("/") : null;
    }
    function localize(language) {
        const french = language === "fr";
        const base = french ? ["docs", "fr"] : ["docs"];
        const planPath = [...base, "BUILD-PLAN.md"];
        const plan = readDocument(root, planPath);
        const sections = moduleSections(plan);
        const titles = new Map([...plan.matchAll(/^## (\d{2}) (?:-|—) (.+)$/gm)].map((match) => [match[1], match[2]]));
        const practice = readDocument(root, [...base, "PRACTICE.md"]);
        const hints = moduleSections(practice);
        const learning = readDocument(root, [...base, "LEARNING-GUIDE.md"]);
        const concepts = moduleSections(learning);
        function document(title, name, directory = base) {
            const parts = [...directory, name];
            return { title, sourcePath: parts.join("/"), content: readDocument(root, parts) };
        }
        return {
            language,
            modules: progress.modules.map((module) => {
                const outline = sections.get(module.module);
                const hint = hints.get(module.module);
                const concept = concepts.get(module.module);
                if (!outline || !hint || !concept || !titles.get(module.module)) {
                    throw new BoardError("invalid_document", `Module ${module.module} is missing required ${language} plan, hints or governance content.`);
                }
                const parts = ["modules", folders[module.module], "README.md"];
                const original = readDocument(root, parts, true);
                const translated = french ? readDocument(root, [...parts.slice(0, -1), "README.fr.md"], true) : original;
                const guide = original === null ? null : translated;
                return {
                    ...module, title: french ? titles.get(module.module) : module.title,
                    outline, guide, hints: hint, learning: concept,
                    hintsSourcePath: [...base, "PRACTICE.md"].join("/"),
                    learningSourcePath: [...base, "LEARNING-GUIDE.md"].join("/"),
                    originalGuide: french && original !== null && translated === null ?
                        { content: original, sourcePath: parts.join("/") } : null,
                    sourcePath: guide === null ? planPath.join("/") :
                        [...parts.slice(0, -1), french ? "README.fr.md" : "README.md"].join("/"),
                    diagram: {
                        svg: `/assets/architecture/${module.module}.${language}.svg`,
                        png: `/assets/architecture/${module.module}.${language}.png`,
                        editable: "/assets/architecture/workshop.drawio",
                    },
                    validation: {
                        powershell: original === null ? null : available(["modules", folders[module.module], "validate.ps1"]),
                        bash: original === null ? null : available(["modules", folders[module.module], "validate.sh"]),
                    },
                };
            }),
            documents: {
                gettingStarted: document(french ? "Choisir votre environnement" : "Choose your workspace", "GETTING-STARTED.md"),
                practice: { title: french ? "Tester votre serveur MCP" : "Try your MCP", sourcePath: [...base, "PRACTICE.md"].join("/"), content: practice },
                runbook: document(french ? "Construire avec Copilot" : "Build runbook", "COPILOT-RUNBOOK.md"),
                sources: document(french ? "Références vérifiées" : "Verified sources", french ? "REFERENCES.md" : "sources.md"),
                governance: { title: french ? "Comprendre la gouvernance" : "Understand governance",
                    sourcePath: [...base, "LEARNING-GUIDE.md"].join("/"), content: learning },
                deployment: document(french ? "Votre contexte Azure" : "Your Azure context", "DEPLOYMENT.md"),
                hosting: document(french ? "Publier ou héberger les guides" : "Publish or host the guides", "HOSTING.md"),
                ...(available(["docs", "requests", "identity-request.md"]) ? {
                    [french ? "originalIdentityRequest" : "identityRequest"]:
                        document(french ? "Demande à l'administrateur (version anglaise)" : "Identity administrator request",
                            "identity-request.md", ["docs", "requests"]),
                } : {}),
                architecture: document(french ? "Schémas et icônes" : "Diagrams and icons", french ? "README.fr.md" : "README.md", ["assets", "architecture"]),
                plan: document(french ? "Le parcours de l'atelier" : "Technical build plan", "BUILD-PLAN.md"),
                ...(french ? {
                    originalSources: document("Registre technique original (anglais)", "sources.md", ["docs"]),
                    originalArchitecture: document("Provenance détaillée (original anglais)", "README.md", ["assets", "architecture"]),
                    originalPlan: document("Plan technique original (anglais)", "BUILD-PLAN.md", ["docs"]),
                } : {}),
            },
        };
    }
    return {
        ...progress,
        ...localize("en"),
        environment: {
            devcontainer: available([".devcontainer", "devcontainer.json"]),
            preflight: available(["scripts", "preflight.ps1"]),
            tools: available(["scripts", "check-tools.ps1"]),
            preparation: available(["scripts", "prepare-workshop.ps1"]),
            context: {
                powershell: available(["scripts", "select-azure-context.ps1"]),
                bash: available(["scripts", "select-azure-context.sh"]),
            },
        },
        translations: { fr: localize("fr") },
    };
}

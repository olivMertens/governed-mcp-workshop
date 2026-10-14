import { resolve } from "node:path";
import { buildPortal } from "./build-site.mjs";

const args = process.argv.slice(2);
if (args.length && (args.length !== 2 || args[0] !== "--output")) {
    throw new Error("Usage: node scripts/build-portal.mjs [--output <new-directory>]");
}
const result = buildPortal(undefined, args.length ? resolve(args[1]) : undefined);
console.log(`PASS public App Service bundle: ${result.files} allowlisted files. No cloud action executed.`);

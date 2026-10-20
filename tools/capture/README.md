# Capture tools: real, masked, annotated screenshots

Optional author tools. They produce the captures in `assets/screenshots` from **your own test tenant**: real pages and
real validator output, with private values masked and pink numbered frames on what to check.
Participants do not need them to run the workshop.

## What they do

| Script | Produces | How |
|---|---|---|
| `capture-portal.mjs` | `azure-*.png` | Opens Azure portal pages in Microsoft Edge, masks private values in the page, draws the frames, then saves the PNG. |
| `capture-terminal.mjs` | `terminal-*.png` | Runs a real validator, masks its output, renders it in a terminal frame with the frames. |
| `browser.mjs` | a signed-in Edge window | Keeps one window open so you sign in (with MFA) only once. |

The pages and checks are listed in `portal-shots.json` and `terminal-shots.json`: file name, module, page or command,
and the elements to frame. Add an entry to add a capture. The `terminal-*-az-*.png` entries run only read-only
Azure CLI queries. Their `requireOutput` patterns reject a capture if the expected values are absent, even when
Azure CLI exits successfully. `preserveLines` keeps JSON and table output intact.

The new CLI examples use the Terraform track's existing resources. The French portal guides reuse them only as
labelled comparisons of fields, not as proof of a new low-code deployment.
The module 99 image is an inventory **before** cleanup; no deletion is performed or implied.

## Privacy by design

- Masking rules are built **at run time** from your context (`az account show`, Microsoft Graph `/organization`,
  `.workshop/participant.tfvars.json`). Nothing private is written to the repository.
- Your account becomes `admin@contoso.onmicrosoft.com`, the tenant `CONTOSO`, the subscription
  `Workshop test subscription`, resource names `p01-<suffix>`, and every GUID `00000000-0000-0000-0000-000000000000`.
- After masking, the script reads the page text again. If any private value or non-zero GUID is left, it **refuses**
  to save the capture. It checks again after the screenshot, in case the page changed.
- Key values stay hidden by the portal (`Show value` is never clicked). Never frame a secret.
- Look at every PNG before you commit it: masking covers text, not pictures.

## Run

Prerequisites: Node.js 20 or later, Microsoft Edge, Azure CLI signed in to your **test** tenant, and the module
resources deployed (a capture of a module needs that module's resources).

```powershell
npm ci --prefix tools/capture
node tools/capture/browser.mjs                     # terminal 1: sign in in the Edge window, keep it open
node tools/capture/capture-portal.mjs --cdp http://127.0.0.1:9333            # terminal 2: every portal capture
node tools/capture/capture-portal.mjs --cdp http://127.0.0.1:9333 --only azure-04-function-networking.png
node tools/capture/capture-terminal.mjs            # every validator capture (runs the validators, read-only)
node tools/capture/capture-terminal.mjs --only terminal-04-az-network.png # one read-only CLI result
```

The CLI entries substitute the current approved subscription and the deterministic names from the private participant
file. Keep that file and the selected Azure context consistent. Capturing one entry never deploys its prerequisites.

`--explore <function|apim|storage|app|rg> [--blade /path] [--menu "Menu item"] [--click "Text"]` opens a page and saves a
masked screenshot in `.workshop/capture-debug/` (ignored by Git): use it to find the page and the text to frame.
When a capture fails, the masked page is saved there too.

The debugging port of `browser.mjs` listens on `127.0.0.1` only. Close the window when you are done.

## Sources

- [Playwright `connectOverCDP`](https://playwright.dev/docs/api/class-browsertype#browser-type-connect-over-cdp) and
  [Microsoft Edge channel](https://playwright.dev/docs/browsers#google-chrome--microsoft-edge).
- Last verified: 2026-10-20.

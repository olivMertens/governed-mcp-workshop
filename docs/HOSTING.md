# Publish the guides on GitHub Pages

[Français](fr/HOSTING.md)

**GitHub Pages is the only published workshop website.** Do not deploy a duplicate documentation site
to Azure App Service or Azure Container Apps. Presenter notes and construction tools stay in the repository
and local authoring board.

The website and the Model Context Protocol (MCP) workload are separate:

| Component | Location | Responsibility |
|---|---|---|
| English and French participant guides, animations and practice instructions | GitHub Pages | Maintainer publishes reviewed content. No Azure credentials or deployment authority. |
| Presenter notes and construction tools | Repository and local authoring board | Authors only; not exported into participant journey data. |
| MCP server, gateway and downstream services | Participant's approved non-production Azure subscription | Participant deploys, validates and cleans up their own workload. |

The website never runs MCP tests. Participants use Visual Studio Code or MCP Inspector on their own
computer. The endpoint field only prepares commands in browser memory; it is not prefilled from Azure,
saved or sent to the server. See [practice instructions](PRACTICE.md).

## Build locally

From the repository root, use Node.js 22.19.0 or newer:

```powershell
node --test scripts/site.test.mjs
if ($LASTEXITCODE -ne 0) { throw 'Site checks failed.' }
node scripts/build-site.mjs
if ($LASTEXITCODE -ne 0) { throw 'Site build failed.' }
```

```bash
node --test scripts/site.test.mjs && node scripts/build-site.mjs
```

The build writes `site-dist`, ignored by Git, and refuses to overwrite an existing directory.
For another build, use `--output` with a new directory. Inspect an old output before deleting that exact directory.
Use a local HTTP server to preview it, not a `file://` URL.

Only allowlisted static assets are exported: HTML, French labels, public journey data, diagrams and screenshots.
The export excludes credentials, private participant parameters, Terraform state, the local board API and author-only
documents. The technical source register (`#/sources`) is author-only too; its public URL shows "Page not found."
Module source links, safety instructions, commands and expected results remain available.

Both languages and both tracks use the same participant reader. Modules 01 to 07 expose their animated
architecture directly. The `<!-- module-animations -->` marker expands into those animations.
`<!-- author-only -->` blocks are removed from public prose; literal code remains unchanged.

## Publish with GitHub Pages

1. Stage the source changes, then regenerate `setup-workshop-mcp.ps1` with `node scripts/sync-scaffold.mjs`.
   Include the regenerated file in the reviewed commit. The workflow checks that it matches the tracked files.
2. Merge the reviewed changes into `main`. Check that the source is public and contains no private material.
3. Run **Actions → Publish workshop guides → Run workflow**, on `main`.
4. Wait for both **build** and **deploy** to succeed. Publication is manual, not automatic after a merge.
5. Verify the English and French pages, both tracks, copied commands and module animations.

- [English attendee link](https://olivmertens.github.io/governed-mcp-workshop/?lang=en#/start)
- [French attendee link](https://olivmertens.github.io/governed-mcp-workshop/?lang=fr#/start)

The workflow uses a short-lived GitHub Pages deployment identity, not an Azure account or client secret.
Configure repository **Settings → Pages → Source → GitHub Actions**. Check your organization's Pages
visibility, plan and usage limits; do not assume that every organization plan is free.

## Retire an older Azure copy

Azure portal hosting was removed on 2026-10-21. This is migration guidance, not a participant exercise.
Do not run an ordinary workload apply to remove an old portal: the same state may also hold MCP resources.

1. Keep the original private parameters, suffix and Terraform state. Back up the state privately.
2. Confirm the exact portal web app and its App Service plan in that state. Verify ownership, subscription
   and resource group, and that no other app uses the plan.
3. With explicit deletion approval, prepare a saved, targeted destroy plan for only
   `azurerm_linux_web_app.portal[0]` and `azurerm_service_plan.portal[0]`.
   Targeting is an exceptional retirement operation, not the normal workshop deployment flow.
4. Inspect the plan privately. It must contain only the approved portal deletions: no additions, updates,
   resource group deletion or MCP/identity change. Stop on any other change.
5. Obtain approval for that exact plan, apply the saved plan, then verify that both Azure resources and
   both state addresses are absent. Deleting or stopping only the web app does not retire a paid plan.
6. Remove the obsolete `public_portal_enabled` key from private parameter files only after checking
   the retirement. Do not change any other value or regenerate names. Delete obsolete portal packages and
   saved deployment plans only after reviewing their exact paths. Never apply an old portal deployment plan.

If the old portal was deployed outside this state, ask its owner to retire those exact resources.
Do not import or delete a shared plan, delete a group, widen permissions or discard state to bypass a failed check.

## Clean up

GitHub Pages needs no workshop Azure resources. To unpublish the guides, use the repository's Pages settings.
For the MCP workload, follow [module 99](../modules/99-cleanup/README.md) with the same private parameters and state.
Preserve administrator-provided groups and identities.

## Sources

- [GitHub Pages with custom workflows](https://docs.github.com/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
- [Azure App Service plans and billing](https://learn.microsoft.com/azure/app-service/overview-hosting-plans).
- [Terraform destroy and exceptional resource targeting](https://developer.hashicorp.com/terraform/cli/commands/destroy).

Last verified: 2026-10-21. Publishing the guides does not validate a participant's deployment.

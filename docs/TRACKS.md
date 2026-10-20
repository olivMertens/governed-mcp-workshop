# Choose your track: low-code or full-code

[Français](fr/TRACKS.md)

Every module reaches the same result in two ways. Pick **one** track for the whole workshop.

| | Low-code track | Full-code track |
|---|---|---|
| How you build | Azure portal, or one short `az` command per step | Terraform (`infra/`) and the module scripts |
| Best for | Administrators who prefer the portal; learning where each setting lives | Repeatable deployments; teams that already use infrastructure as code |
| Names | Same participant file, with `lc` added (`rg-mcp-<prefix>lc-...`) | `rg-mcp-<prefix>-<suffix>` |
| Checks | The same validators, with your resource names as parameters | The validators read Terraform outputs |
| Clean-up | Module 99 low-code checklist: delete one resource group and the Entra objects you created | Module 99 script: guarded Terraform plans, module by module |
| Mistakes | The portal accepts anything: the validators are your safety net | Plans are reviewed before each change |

> [!IMPORTANT]
> **Do not mix the tracks.** Terraform only knows what it created. A setting changed by hand in the portal is undone by
> the next Terraform plan, and the module 99 script refuses plans that touch unknown objects. If you started with one
> track, finish with it, or clean up and start again.

> [!TIP]
> On a workshop day with a 90-minute afternoon, pick your track here, then follow the next step:
> **The 90-minute afternoon path**.

## The 90-minute afternoon path

This morning, the presenters showed an MCP server in TypeScript, protected by the `Mcp.Read` permission. This
afternoon, you build the same levels yourself in your own non-production subscription: a .NET server on Azure
Functions, the app roles `Tools.Read` and `Tools.Write`, and the test users Alice, Bob and Eve. Same ideas, your code.

| When | What you do | Module | Done when |
|---|---|---|---|
| Before the day | Install the tools, sign in, choose your non-production subscription | [00](../modules/00-prerequisites/README.md) | The module 00 validator passes |
| Before the day | Send the identity administrator request, so the module 03 objects exist or are approved | [Identity request](requests/identity-request.md) | You have the API client ID and the test users |
| First | Call a local MCP server, with no Azure | [01](../modules/01-discover-mcp/README.md) | Inspector lists the tools |
| Then | Deploy the open server and see the risk | [02](../modules/02-open-server/README.md) | A call without the key is refused; a call with the key works |
| Then | Protect it with Microsoft Entra | [03](../modules/03-entra-authentication/README.md) | Alice and Bob get HTTP 200; a token for another audience is refused |
| Stretch | Put API Management in front | [04](../modules/04-governed-gateway/README.md) | Bob's `create_ticket` gets HTTP 403; Alice's gets HTTP 200 |
| Before you leave | Clean up everything you created | [99](../modules/99-cleanup/README.md) | The report shows no workshop resource left |
| After the day | Module 04 part B, then 05, 06 and 07, at your own pace | [05](../modules/05-delegated-and-app-only/README.md) | Each module's validator passes |

> [!WARNING]
> Modules 02 and 04 create billed resources. Run module 99 before you leave, even if you stopped early.

No subscription, or no identity administrator approval? Join the observation plan on the prepared environment: you
call the same levels without deploying anything.

## What stays identical

- The security rules: one audience per token, no token passthrough, app roles per user, no long-lived secret,
  zero body bytes in logs.
- The tests: the same HTTP results (401, 403, 200, 429) for Alice, Bob and Eve.
- The order: modules 00 to 07, then 99.

## Where the low-code track starts in each module

In the portal, pick your track once above **Follow the guide** (**Full-code** or **Low-code**): the guide then shows only that track's steps, in every module, and remembers the choice. On GitHub, open the section **Low-code track** at the top of **Steps**. Each step shows the portal path first,
then the equivalent `az` command, then the real result the author got. Keep the same PowerShell terminal from step L1:
later steps reuse its variables.

| Module | Low-code section |
|---|---|
| 00, 01 | None needed: they build nothing in Azure, so there is one path |
| 02 to 05 | **Low-code track**, steps L1, L2 and so on (L-B for module 04 part B) |
| 06 | **Low-code track**, before Step 1: only the terminal lines differ |
| 07 | **A2 and A3 in the low-code track**, after step A3: the Foundry steps are the same |
| 99 | **Low-code track**, at the top of Steps: one resource group and two app registrations |

The author ran the low-code track live on 2026-10-20, from module 02 to module 99, with Alice, Bob and Eve. In module
07, only A2 and A3 differ, so only they were rerun; the Foundry steps were run live in the full-code track the same day.

Last verified: 2026-10-20.

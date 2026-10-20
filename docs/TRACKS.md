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

## What stays identical

- The security rules: one audience per token, no token passthrough, app roles per user, no long-lived secret,
  zero body bytes in logs.
- The tests: the same HTTP results (401, 403, 200, 429) for Alice, Bob and Eve.
- The order: modules 00 to 07, then 99.

## Where the low-code track starts in each module

Open the module, then the section **Low-code track** at the top of **Steps**. Each step shows the portal path first,
then the equivalent `az` command, then the real result the author got. Keep the same PowerShell terminal from step L1:
later steps reuse its variables.

Last verified: 2026-10-20.

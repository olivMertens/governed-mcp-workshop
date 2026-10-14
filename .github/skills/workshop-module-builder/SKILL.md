---
name: workshop-module-builder
description: Builds, deploys and validates the next module of the "Governed MCP on Azure" workshop in this repository. Use this when asked to continue the workshop build, to build or fix a module (00 to 07, or 99), or to update docs/PROGRESS.md.
---

# Workshop module builder

Always follow these steps, in this order.

1. **Load the context.** Read `.github/copilot-instructions.md`, `docs/BUILD-PLAN.md` and `docs/PROGRESS.md`.
2. **Pick the module.** Use the module named in the request. Otherwise take the first module in `docs/PROGRESS.md`
   whose status is not `validated` (module 07 is optional). If the previous module in the build order is not
   `validated`, stop and say so.
3. **Read the sources first.** Open every official page listed under "Take" for the module (use the Microsoft Learn
   MCP server when it is available). Note any difference between the documentation and the build plan.
4. **Plan and ask.** Present a short plan: files to create or change, Azure and Microsoft Entra changes, roles required,
   Preview features used, cost impact, clean-up. Wait for explicit approval before creating or changing any Azure or
   Microsoft Entra resource.
5. **Build** `modules/NN-name/` following the module contract: README sections in order, `infra/` if needed,
   `validate.ps1`, `validate.sh` and a clean-up script. Pin upstream versions or commit SHAs and keep license notices.
6. **Infrastructure.** Run `terraform fmt -recursive`, `terraform validate` and `terraform plan`. Summarize the plan
   and apply only after approval.
7. **Validate.** Run `validate.ps1` and fix until every check prints PASS. Never weaken a security invariant, widen a role
   or add a secret to get a PASS: stop and ask instead.
8. **Record.** Update `docs/PROGRESS.md` (status, date, PASS lines as evidence, notes, deviations, open decisions) and
   `docs/sources.md` (create it if missing) with every link used and its last verified date.
9. **Ship.** Commit as `module NN: <summary>` and open a pull request that lists what was built, the validation output,
   deviations from the plan, Preview features used and the clean-up command.

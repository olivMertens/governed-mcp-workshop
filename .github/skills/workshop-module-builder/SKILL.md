---
name: workshop-module-builder
description: Builds, deploys and validates the next module of the "Governed MCP on Azure" workshop in this repository. Use this when asked to continue the workshop build, to build or fix a module (00 to 07, or 99), or to update docs/PROGRESS.md.
---

# Workshop module builder

Always follow these steps, in this order.

1. **Load the context.** Read `.github/copilot-instructions.md`, `docs/BUILD-PLAN.md` and `docs/PROGRESS.md`.
2. **Pick the module.** Use the module named in the request. Otherwise take the first module in `docs/PROGRESS.md`
   whose status is not `authored` or `validated` (module 07 is optional). If the previous module in the build order is
   still `todo`, `in-progress` or `blocked`, stop and say so. `authored` is enough to continue: the presenter usually
   cannot deploy, so live validation happens later in each participant's own subscription.
3. **Read the sources first.** Open every official page listed under "Take" for the module (use the Microsoft Learn
   MCP server when it is available). Note any difference between the documentation and the build plan.
4. **Plan and ask.** Present a short plan: files to create or change, Azure and Microsoft Entra changes, roles required,
   Preview features used, cost impact, clean-up. Ask whether this session has an approved non-production tenant
   the author owns. Never target a participant's tenant or subscription. Wait for explicit approval before creating
   or changing any Azure or Microsoft Entra resource.
5. **Build** `modules/NN-name/` following the module contract: README sections in order, `infra/` if needed,
   `validate.ps1`, `validate.sh` and a clean-up script. Pin upstream versions or commit SHAs and keep license notices.
   When the module adds or changes a depicted architecture (a component, dependency, identity, network or ingress
   boundary), also load `.github/skills/architecture-diagram-author/SKILL.md` and update the matching diagram in
   `assets/architecture/` (drawio source first, then SVG and PNG exports via `scripts/render-architecture.py`).
   Skip this for modules that do not change the depicted architecture.
6. **Infrastructure.** Run `terraform fmt -recursive`, `terraform validate` and the mocked `terraform test`.
   Run `terraform plan` and apply only if step 4 confirmed an approved author-owned tenant, and only after approval.
7. **Validate.** Always run the offline checks (unit tests, Terraform tests, the offline mode of the validator).
   If deployed, run `validate.ps1` live and fix until every check prints PASS. Never weaken a security invariant,
   widen a role or add a secret to get a PASS: stop and ask instead.
8. **Record.** Update `docs/PROGRESS.md`: `authored` with offline PASS lines when nothing was deployed, or `validated`
   with the date and live PASS lines. Add notes, deviations and open decisions. If a diagram changed, run
   `python .\scripts\render-architecture.py --check` and record the result. Update `docs/sources.md`
   (create it if missing) with every link used and its last verified date.
9. **Ship.** Commit as `module NN: <summary>` and open a pull request. An `authored` module is shippable: do not refuse
   to open the pull request because live validation is pending. The pull request lists what was built, the validation
   output (offline or live, labelled), what participants still validate live, deviations from the plan,
   Preview features used and the clean-up command.

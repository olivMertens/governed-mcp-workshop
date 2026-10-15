---
name: workshop-builder
description: Builds the "Governed MCP on Azure" workshop one module at a time (Terraform, Azure Functions .NET, Azure API Management, Microsoft Entra ID), deploys to a test subscription only after approval, and proves each module with its validation script.
---

You build this repository's workshop, one module per session, with the workshop-module-builder skill.

- Treat `.github/copilot-instructions.md` as non-negotiable, especially the nine security invariants.
- Follow `docs/BUILD-PLAN.md` for what to take, build and show. Keep `docs/PROGRESS.md` up to date.
- Read the official sources of a module before writing its code.
- Show the Terraform plan and the Microsoft Entra changes, and wait for approval, before changing anything in Azure or Entra.
- The presenter cannot deploy into participants' tenants. Never target a participant tenant or subscription.
  Deploy only to an approved non-production tenant the author owns, if one is available in the session.
- A module is `authored` when its code, docs and offline checks pass; that is enough to open the pull request and
  start the next module. It is `validated` only when `validate.ps1` passes live. Report the PASS lines as evidence,
  labelled offline or live.
- Keep the content generic, in English, with synthetic data and no secrets.

# Presenter: share the GitHub Pages link

[Français](fr/PRESENTER.md)

**GitHub Pages hosts the participant guides. Participants run their own exercises.**
Do not deploy another landing page in Azure. This presenter guide stays in the repository and local
authoring board; it is excluded from the published participant site.

Publishing the guides does not deploy or validate a Model Context Protocol (MCP) server.
Follow the run order and validation limits in the [root README](../README.md).
Participants can run [module 01](../modules/01-discover-mcp/README.md) locally without Azure.

## Before the session

1. Publish the reviewed revision with the [GitHub Pages workflow](HOSTING.md#publish-with-github-pages).
   Wait for both build and deployment to succeed, then check both languages and tracks.
2. Open the participant site in a separate browser window. Do not project private parameters, tokens,
   Terraform state, account responses or administrator sessions.
3. Check multifactor authentication (MFA) registration for dedicated Alice, Bob and Eve test accounts
   in your approved demonstration tenant. Never weaken Conditional Access to skip registration.
4. Review quota and cost before deploying any demonstration MCP workload. API Management Standard v2
   incurs charges while deployed; check regional pricing and schedule cleanup after the exercise.
5. Open the fallback captures below. A screenshot illustrates an observation; it does not validate anyone else's deployment.

Architecture talk track: [Session 2 - integrate and expose MCP](INTEGRATION-OPTIONS.md).
The participant site uses a separate attendee version and the module animations, not these speaker notes.

## Share the participant links

- [English](https://olivmertens.github.io/governed-mcp-workshop/?lang=en#/start)
- [Français](https://olivmertens.github.io/governed-mcp-workshop/?lang=fr#/start)

Suggested message:

> Open the workshop link, choose your language and track, then follow module 00.
> Use only your approved test tenant and subscription. There is no documentation website to deploy.
> Module 01 runs locally without Azure. Follow the remaining modules in order and run module 99 after the paid exercises.
> To test a deployed server, use VS Code or MCP Inspector on your own computer.
> The website prepares instructions; it does not call your MCP server or record a passed test.
> Keep credentials and tokens private. Complete required MFA registration rather than disabling a sign-in control.

## Who deploys what

| Item | Who | Where |
|---|---|---|
| Shared participant guides | Maintainer | GitHub Pages, from reviewed `main`. No Azure account or participant tenant access. |
| Presenter notes and construction tools | Authors | Repository and local authoring board only. |
| MCP workload, modules 02 onward | Each participant | Their own approved non-production Azure subscription and Microsoft Entra tenant. |
| Demonstration workload | Presenter, only with approval | Presenter's own non-production environment, never a participant's tenant. |

A participant's PASS lines are evidence for their deployment only. Never ask them to send account identifiers,
tokens or body transcripts. Do not share credentials, deployment keys or administrator sessions.

## Teach one step at a time

Before module 01, use [MCP and agent concepts](MCP-CONCEPTS.md) to explain hosts, clients, servers,
the agent loop and tools/resources/prompts. Ask the prediction questions before revealing the answers.
Reading a concept or selecting **Next** does not execute a tool.

Ask participants to explain the goal and predict the result before copying a command.
Run one short block, inspect the real output, then continue. Keep separate pauses for plan review,
human approval, identity-administrator actions and cleanup. Do not combine plan and apply in one paste.

The reader shows position, content, then navigation. Use the **Outline** to return to an explanation.
Long reference blocks remain closed until opened. Continuation pages preserve commands and complete elements;
an indivisible element can exceed the normal reading budget.

Use the appearance button to select **Template**, **White** or **Dark**. This changes the local browser only.
It neither changes the shared guides nor deploys anything.

## Real captures to use as a fallback

Captures in the module guides use pseudonyms, zeroed identifiers and highlighted checks.
Use them when consent, MFA, quota or network access prevents a live step.

| Module | Observation |
|---|---|
| [02](../modules/02-open-server/README.md) | Storage public access disabled and private endpoints approved |
| [03](../modules/03-entra-authentication/README.md) | Function authentication, app roles, operator checks and Alice's call |
| [05](../modules/05-delegated-and-app-only/README.md) | Delegated API permissions and managed-identity federated credential |
| [06](../modules/06-observe-inventory/README.md) | Metadata-only queries and optional Observability Agent results |

Read each validator's purpose, numbered `== Step N ==` headers, `Why:` explanation and expected HTTP status.
The practice page's prepared commands are not test results. A real HTTP 200 can still contain an MCP tool error.

## Close the session safely

Each participant removes only their own resources with [module 99](../modules/99-cleanup/README.md).
The presenter does the same for an approved demonstration workload. There is no shared Azure website to keep running.
Preserve private parameters and state until deletion is verified. Never delete an administrator-provided group
or identity as a shortcut. For an older Azure documentation copy, use the [retirement guidance](HOSTING.md#retire-an-older-azure-copy).

## Sources

- [GitHub Pages publication procedure](HOSTING.md).
- [API Management pricing](https://azure.microsoft.com/pricing/details/api-management/).
- [Participant client-testing guide](PRACTICE.md).

Last verified: 2026-10-21. Reading or publishing a guide does not validate a participant deployment.

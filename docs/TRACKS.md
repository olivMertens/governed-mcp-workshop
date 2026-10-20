# Choose your track

[Français](fr/TRACKS.md)

Choose **one** deployment track before module 00. These are two separate sets of participant guides,
not alternatives to combine inside a module. Module 01, which runs locally without Azure, is shared.

In the workshop website, select a card above. The page address remembers your choice.
Every module, its PDF, validation instructions and cleanup then use that track.
Reading Markdown on GitHub? Use only the links in your track's table below.

## Low-code: portal first

Use this track to learn where the settings are in Azure and Microsoft Entra.
Each guide gives the menu path, the values to enter, the check before continuing and relevant real screenshots.
Captures are examples from the author's environment: use **your own** resource names.

This is not a no-terminal track. Use PowerShell 7 and Azure CLI for publishing the supplied server,
settings that the portal does not expose, and validation. The guide says when to leave the portal,
where to run the command and what you should see. **Terraform is not required.**

| Order | Your guide | Stop and check |
|---|---|---|
| 00 | [Prepare the low-code environment](../modules/00-prerequisites/LOW-CODE.md) | Tool and read-only subscription checks pass, without Terraform |
| 01 | [Discover MCP locally](../modules/01-discover-mcp/README.md) | Inspector lists the tools |
| 02 | [Create and publish the open server](../modules/02-open-server/LOW-CODE.md) | No key: HTTP 401; correct key: HTTP 200 |
| 03 | [Add Microsoft Entra authentication](../modules/03-entra-authentication/LOW-CODE.md) | Alice and Bob can connect; Eve is refused |
| 04 | [Make API Management the only entry point](../modules/04-governed-gateway/LOW-CODE.md) | Direct Function access: HTTP 403; Bob's write: HTTP 403 |
| 05 | [Compare delegated and app-only calls](../modules/05-delegated-and-app-only/LOW-CODE.md) | Bob cannot read the report as a user; app-only results match |
| 06 | [Inspect logs and inventory](../modules/06-observe-inventory/LOW-CODE.md) | Your queries show metadata, not message bodies |
| 07, optional | [Connect the Foundry client](../modules/07-clients/LOW-CODE.md) | You approve a real tool invocation; Copilot Studio is reading only |
| 99, always | [Clean up low-code resources](../modules/99-cleanup/LOW-CODE.md) | Verify all workshop-owned groups and identity objects, including optional resources |

## Terraform + PowerShell

Use this track to learn repeatable infrastructure deployment. Follow the PowerShell commands in order,
review every plan, then run the module validator. Bash equivalents are optional and stay in this track.
Portal screenshots help you inspect what was deployed; they are not a second deployment sequence.

| Order | Your guide | Stop and check |
|---|---|---|
| 00 | [Prepare the Terraform environment](../modules/00-prerequisites/README.md) | Tools, private parameters and read-only subscription checks pass |
| 01 | [Discover MCP locally](../modules/01-discover-mcp/README.md) | Inspector lists the tools |
| 02 | [Deploy the open server](../modules/02-open-server/README.md) | No key: HTTP 401; correct key: HTTP 200 |
| 03 | [Deploy Microsoft Entra authentication](../modules/03-entra-authentication/README.md) | Alice and Bob can connect; Eve is refused |
| 04 | [Deploy the governed gateway](../modules/04-governed-gateway/README.md) | Direct Function access: HTTP 403; Bob's write: HTTP 403 |
| 05 | [Deploy delegated and app-only access](../modules/05-delegated-and-app-only/README.md) | Bob's delegated report call is refused downstream |
| 06 | [Inspect logs and register inventory](../modules/06-observe-inventory/README.md) | Queries show metadata; inventory contains the gateway endpoint |
| 07, optional | [Connect the Foundry client](../modules/07-clients/README.md) | You approve a real tool invocation; Copilot Studio is reading only |
| 99, always | [Run guarded cleanup](../modules/99-cleanup/README.md) | The cleanup report shows no workshop-owned deployed resource left |

## Before you start

1. Get approval for your own non-production subscription. Do not use another participant's environment.
2. Send the [identity administrator request](requests/identity-request.md) before module 03.
   The guides distinguish administrator actions from participant actions.
3. Keep your private participant file. Low-code adds `lc` to the participant prefix for newly created
   workload resources; Terraform uses the prefix unchanged. An administrator-provided group keeps its existing name.
4. Follow the modules in order. If you will do module 05, publish its server code **before**
   module 04 locks the Function's deployment endpoints.
5. Reserve time for module 99, even if you stop after module 02.

> [!IMPORTANT]
> Changing the selected guide does not convert resources from one track to the other.
> Do not run Terraform against resources created through the low-code guides.
> Clean up the first deployment before changing tracks.

> [!WARNING]
> Functions, Storage, API Management and optional Foundry resources can incur charges.
> API Management provisioning can take longer than a short workshop session.
> A resource's expiry tag does not delete it. Follow your track's module 99.

Both tracks keep the same security controls: one token audience per hop, no client-token forwarding
to downstream APIs, app roles per user, explicit approval for writes and zero message-body bytes in logs.

## Evidence and screenshots

Existing live results were recorded in the author's approved test environment on 2026-10-20.
The previous low-code Foundry rerun covered its setup substitutions, not a complete new end-to-end run.
The separated guides and track navigation need their own participant run; earlier evidence does not prove
that every newly composed instruction has been followed live.
Existing screenshots are reused with that limitation. Missing captures are not invented.

Last editorial update: 2026-10-20.

# Module 07 — Optional: other clients (facilitator demo)

> Français : [README.fr.md](README.fr.md)

## Goal

Show that the same governed MCP server can be called from other clients: a Microsoft Foundry agent and Microsoft Copilot Studio. This module is a **facilitator demo**. Attendees watch and read the checklist. They do not need to build it.

## Why it matters

Governance must hold no matter which client calls the server. Each client has its own way of signing in and of sending the token. The questions to ask are the same every time:

- Which identity is used to call the MCP server (the user, a managed identity, or an agent identity)?
- Which audience does the token have, and is it the MCP server's own audience?
- Is there any token passthrough to a downstream service?

## What you deploy

Nothing. This module creates no Azure, Microsoft Entra or Copilot Studio resources. It only documents the steps and provides an offline check of this folder.

Preview features used in this demo (label them as Preview when you show them):

- **Preview:** OAuth identity passthrough for MCP tools in Microsoft Foundry.
- **Preview:** Microsoft Foundry MCP tool configuration in the Agent Builder.

## Prerequisites and required roles

- Modules 03 to 06 completed and validated (or a recording of them).
- The MCP server URL from module 04 (through the gateway, never the Function URL).
- For a live demo only: a Microsoft Foundry project and a Copilot Studio environment that your tenant allows. Your administrator approves both. Nothing in this module changes their roles.

## Steps

This is a demo. The facilitator runs it. Attendees follow along.

### Part A — Microsoft Foundry agent (Preview)

1. In the Foundry project, open the agent and add an **MCP tool**.
2. Set the server URL to the gateway URL from module 04. Use the **Streamable HTTP** transport.
3. Choose the authentication option:
   - **Project managed identity:** the project calls the server with its own identity. The server then needs an app role for that identity (module 03 pattern).
   - **OAuth identity passthrough (Preview):** each signed-in user's identity is used. The server must accept a token whose audience is the server's own audience. Microsoft tokens are not forwarded to untrusted MCP endpoints.
4. Ask the agent a read-only question that calls a read tool. Show the result.
5. Ask the agent to call a write tool. Show that the write requires the matching role and a human approval.

### Part B — Microsoft Copilot Studio (outline)

1. In the agent, open **Tools**, then **Add a tool**, then **New tool**, then **Model Context Protocol**.
2. Enter a **Server name**, a **Server description** and the **Server URL** (gateway URL).
3. Choose the authentication option: **None**, **API key** or **OAuth 2.0**. For this workshop, use **OAuth 2.0** and never **None** (see the invariants in the repository's `copilot-instructions.md`).
4. Only the **Streamable** transport is supported. SSE is no longer supported.
5. Test the tool in the agent test pane.

> The exact screen labels can change. Check the source page below before the session.

### Part C — Checklist for every client

- [ ] The token audience is the MCP server's own audience (not Microsoft Graph, not a downstream API).
- [ ] No client secret or API key is stored in the client configuration.
- [ ] Write tools require an explicit role and a human approval.
- [ ] The gateway logs show the call with a correlation ID and no request body (module 06).

## What you should see

- The Foundry agent returns a result from the read tool.
- The write attempt is refused, or it asks for approval, when the caller lacks the role.
- The gateway log in module 06 shows the calls from each client, with no bodies.

## Validate

Offline checks only. They confirm that this folder is complete and that the rules above are present:

```powershell
pwsh ./modules/07-clients/validate.ps1 -Offline
```

```bash
bash ./modules/07-clients/validate.sh --offline
```

Each check prints one `PASS` or `FAIL` line. No live check is scripted, because this demo depends on tenant settings.

## Troubleshooting

- **The client gets 401:** the audience in the token does not match the server. Check module 03.
- **The client gets 403:** the caller lacks the app role. Check module 03 and module 05.
- **The client cannot reach the server:** the URL must be the gateway URL (module 04). The Function URL is locked by design.
- **SSE transport fails:** use Streamable. SSE is no longer supported.

## Clean up

Nothing was created, so there is nothing to delete. Remove any test agent or tool you added to the Foundry project or Copilot Studio after the demo:

```powershell
pwsh ./modules/07-clients/cleanup.ps1
```

```bash
bash ./modules/07-clients/cleanup.sh
```

## Go further

- Add a second client and compare the authentication choices.
- Read the Preview notes in the Foundry documentation and track when OAuth passthrough becomes generally available.

## Sources

- Microsoft Foundry — MCP authentication: https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication
- Microsoft Copilot Studio — Add an existing MCP server to an agent: https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent

Last verified: 2026-10-15. The Copilot Studio page was only partly reviewed. Confirm the remaining steps before a live session.

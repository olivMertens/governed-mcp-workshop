# Explore the animated architecture

Follow the path of a tool call, then add one control at a time.
Choose a module below or use Next and Previous inside its diagram.
Each animation is part of its module, in both deployment tracks. Start with the diagram, then use the link below
it to continue with the module's exercises.
These diagrams explain the architecture. They do not run commands or validate your environment.

<!-- module-animations -->

## 9. What is Microsoft Agent 365?

**Agent 365 is a control plane for agents, not an agent builder or an MCP server.**
It helps you observe, govern and secure agents across your organisation, even when they come from different platforms.
Its central registry brings together inventory, owners and lifecycle management.
Microsoft Entra handles identity and access, Microsoft Purview supports data governance, and Microsoft Defender
provides threat protection. Available capabilities depend on licensing and configuration.

| Component | What it does |
|---|---|
| Azure API Center | Helps teams find approved MCP server endpoints. It is not a runtime hop. |
| Microsoft Agent 365 | Provides central visibility and governance decisions for agents and tools. |
| Azure API Management | Enforces configured controls on calls through the gateway. |

Agent 365 is generally available for the Commercial segment since 2026-05-01.
Its **integration with API Management remains Preview**. With API Management v2, that integration supports server
inventory and whole-server blocking (HTTP 403). Tool-level blocking through Agent 365 requires the
**AI Gateway tier (Preview)**. The workshop's v2 per-tool role policies are a separate control.

The integration requires tenant administrator consent for the **A365 MCP Gateway Policy Operator** role.
That role can read gateway resources and read/write API policies across tenant subscriptions.
This is optional reading, not a workshop setup step. No participant command requests that grant.

Agent 365 does not reroute clients through the gateway or replace audience checks, app roles or human approval
for write tools. Keep clients on the gateway URL and direct backend access blocked.
Keep workshop logs limited to metadata: never tokens, prompts, arguments or results.

**Remember:** API Center helps you find the door; Agent 365 helps administrators decide what is allowed;
API Management checks calls at the door.

## Sources

- [Microsoft Agent 365 overview and availability](https://learn.microsoft.com/microsoft-agent-365/overview)
- [Agent 365 and API Management integration (Preview)](https://learn.microsoft.com/azure/api-management/agent-365)
- [API Center and MCP discovery](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server)

Last verified: 2026-10-21.

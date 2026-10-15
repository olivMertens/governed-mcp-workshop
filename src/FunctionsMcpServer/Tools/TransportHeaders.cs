// Trigger pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
// 468c518c884ec318e3001b9573254c9e775409c9 (src/FunctionsMcpTool/HelloTool.cs and HelloToolWithAuth.cs), MIT License,
// Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md. Workshop changes: synthetic tools,
// strict argument shape, payload-free audit logging, module 05 behaviour only when WORKSHOP_DELEGATED_ACCESS is enabled.
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Mcp;
using Microsoft.Extensions.Logging;
using Workshop.FunctionsMcp.Logic;

namespace Workshop.FunctionsMcp.Tools;
/// <summary>Headers of the MCP HTTP transport (Streamable HTTP), or null for other transports.</summary>
internal static class TransportHeaders
{
    public static IReadOnlyDictionary<string, string>? Of(ToolInvocationContext context) =>
        context.TryGetHttpTransport(out var transport) ? transport!.Headers : null;
}

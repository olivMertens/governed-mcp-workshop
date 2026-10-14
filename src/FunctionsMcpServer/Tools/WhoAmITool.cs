// Trigger pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
// 468c518c884ec318e3001b9573254c9e775409c9 (src/FunctionsMcpTool/HelloTool.cs), MIT License,
// Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md. Workshop changes: synthetic tools,
// strict argument shape, payload-free audit logging.
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Mcp;
using Microsoft.Extensions.Logging;
using Workshop.FunctionsMcp.Logic;

namespace Workshop.FunctionsMcp.Tools;

public sealed class WhoAmITool(ILogger<WhoAmITool> logger)
{
    [Function(nameof(WhoAmI))]
    public Task<string> WhoAmI(
        [McpToolTrigger(ToolCatalog.WhoAmI, ToolCatalog.WhoAmIDescription)] ToolInvocationContext context,
        FunctionContext functionContext) =>
        ToolAudit.Run(logger, ToolCatalog.WhoAmI, functionContext.InvocationId, () => ToolLogic.WhoAmI(context.Arguments));
}

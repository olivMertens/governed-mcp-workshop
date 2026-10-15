// Trigger pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
// 468c518c884ec318e3001b9573254c9e775409c9 (src/FunctionsMcpTool/HelloTool.cs and HelloToolWithAuth.cs), MIT License,
// Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md. Workshop changes: synthetic tools,
// strict argument shape, payload-free audit logging, module 05 behaviour only when WORKSHOP_DELEGATED_ACCESS is enabled.
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Mcp;
using Microsoft.Extensions.Logging;
using Workshop.FunctionsMcp.Logic;

namespace Workshop.FunctionsMcp.Tools;
public sealed class WhoAmITool(DelegatedTools delegated, ILogger<WhoAmITool> logger)
{
    [Function(nameof(WhoAmI))]
    public Task<string> WhoAmI(
        [McpToolTrigger(ToolCatalog.WhoAmI, ToolCatalog.WhoAmIDescription)] ToolInvocationContext context,
        FunctionContext functionContext)
    {
        if (!delegated.Enabled)
        {
            return ToolAudit.Run(logger, ToolCatalog.WhoAmI, functionContext.InvocationId, () => ToolLogic.WhoAmI(context.Arguments));
        }

        var headers = TransportHeaders.Of(context);
        return ToolAudit.RunAsync(logger, ToolCatalog.WhoAmI, functionContext.InvocationId, CallerContext.AuditLabel(headers),
            () => delegated.WhoAmIAsync(context.Arguments, headers, functionContext.CancellationToken));
    }
}

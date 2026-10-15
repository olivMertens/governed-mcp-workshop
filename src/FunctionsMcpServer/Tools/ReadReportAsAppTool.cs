// Trigger pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
// 468c518c884ec318e3001b9573254c9e775409c9 (src/FunctionsMcpTool/HelloTool.cs and HelloToolWithAuth.cs), MIT License,
// Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md. Workshop changes: synthetic tools,
// strict argument shape, payload-free audit logging, module 05 behaviour only when WORKSHOP_DELEGATED_ACCESS is enabled.
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Mcp;
using Microsoft.Extensions.Logging;
using Workshop.FunctionsMcp.Logic;

namespace Workshop.FunctionsMcp.Tools;
public sealed class ReadReportAsAppTool(DelegatedTools delegated, ILogger<ReadReportAsAppTool> logger)
{
    [Function(nameof(ReadReportAsApp))]
    public Task<string> ReadReportAsApp(
        [McpToolTrigger(ToolCatalog.ReadReportAsApp, ToolCatalog.ReadReportAsAppDescription)] ToolInvocationContext context,
        FunctionContext functionContext)
    {
        if (!delegated.Enabled)
        {
            return ToolAudit.Run(logger, ToolCatalog.ReadReportAsApp, functionContext.InvocationId, () => ToolLogic.ReadReportAsApp(context.Arguments));
        }

        // App-only: the caller's token is not used at all. The caller label is for the audit line only.
        return ToolAudit.RunAsync(logger, ToolCatalog.ReadReportAsApp, functionContext.InvocationId, CallerContext.AuditLabel(TransportHeaders.Of(context)),
            () => delegated.ReadReportAsAppAsync(context.Arguments, functionContext.CancellationToken));
    }
}

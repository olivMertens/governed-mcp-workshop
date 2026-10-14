// Trigger pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
// 468c518c884ec318e3001b9573254c9e775409c9 (src/FunctionsMcpTool/HelloTool.cs), MIT License,
// Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md. Workshop changes: synthetic tools,
// strict argument shape, payload-free audit logging.
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Mcp;
using Microsoft.Extensions.Logging;
using Workshop.FunctionsMcp.Logic;

namespace Workshop.FunctionsMcp.Tools;

public sealed class ReadReportAsUserTool(ILogger<ReadReportAsUserTool> logger)
{
    [Function(nameof(ReadReportAsUser))]
    public Task<string> ReadReportAsUser(
        [McpToolTrigger(ToolCatalog.ReadReportAsUser, ToolCatalog.ReadReportAsUserDescription)] ToolInvocationContext context,
        FunctionContext functionContext) =>
        ToolAudit.Run(logger, ToolCatalog.ReadReportAsUser, functionContext.InvocationId, () => ToolLogic.ReadReportAsUser(context.Arguments));
}

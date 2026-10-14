// Bootstrap adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
// 468c518c884ec318e3001b9573254c9e775409c9 (src/FunctionsMcpTool/Program.cs), MIT License,
// Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
// Workshop changes: five synthetic tools with explicit input schemas, a managed-identity ticket queue,
// no connection strings, no OpenTelemetry exporter (the Functions host sends telemetry with Entra auth).
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Workshop.FunctionsMcp.Logic;

var builder = FunctionsApplication.CreateBuilder(args);

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<ITicketQueue>(_ => new StorageTicketQueue(Environment.GetEnvironmentVariable));

builder.ConfigureMcpTool(ToolCatalog.GetServiceHealth).WithInputSchema(ToolCatalog.GetServiceHealthSchema);
builder.ConfigureMcpTool(ToolCatalog.CreateTicket).WithInputSchema(ToolCatalog.CreateTicketSchema);
builder.ConfigureMcpTool(ToolCatalog.WhoAmI).WithInputSchema(ToolCatalog.NoArgumentsSchema);
builder.ConfigureMcpTool(ToolCatalog.ReadReportAsUser).WithInputSchema(ToolCatalog.ReportSchema);
builder.ConfigureMcpTool(ToolCatalog.ReadReportAsApp).WithInputSchema(ToolCatalog.ReportSchema);

builder.Build().Run();

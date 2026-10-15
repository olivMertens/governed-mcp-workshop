// Bootstrap adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
// 468c518c884ec318e3001b9573254c9e775409c9 (src/FunctionsMcpTool/Program.cs), MIT License,
// Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
// Workshop changes: five synthetic tools with explicit input schemas, a managed-identity ticket queue,
// no connection strings, no OpenTelemetry exporter (the Functions host sends telemetry with Entra auth),
// module 05 downstream identities (On-Behalf-Of and app-only managed identity) only when WORKSHOP_DELEGATED_ACCESS is enabled.
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Workshop.FunctionsMcp.Identity;
using Workshop.FunctionsMcp.Logic;

var builder = FunctionsApplication.CreateBuilder(args);

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<ITicketQueue>(_ => new StorageTicketQueue(Environment.GetEnvironmentVariable));

// Module 05: disabled unless infra/workload sets WORKSHOP_DELEGATED_ACCESS=enabled. Disabled keeps the module 02 demonstrations.
// No developer-credential fallback exists: deployed or local, a missing identity fails the tool instead.
var delegatedAccess = DelegatedAccessSettings.FromSettings(Environment.GetEnvironmentVariable);
builder.Services.AddSingleton(delegatedAccess);
builder.Services.AddSingleton<IDownstreamCredentials>(_ => new ManagedIdentityDownstreamCredentials(delegatedAccess));
builder.Services.AddSingleton<IDownstreamClients>(_ => new AzureDownstreamClients(delegatedAccess));
builder.Services.AddSingleton<DelegatedTools>();

builder.ConfigureMcpTool(ToolCatalog.GetServiceHealth).WithInputSchema(ToolCatalog.GetServiceHealthSchema);
builder.ConfigureMcpTool(ToolCatalog.CreateTicket).WithInputSchema(ToolCatalog.CreateTicketSchema);
builder.ConfigureMcpTool(ToolCatalog.WhoAmI).WithInputSchema(ToolCatalog.NoArgumentsSchema);
builder.ConfigureMcpTool(ToolCatalog.ReadReportAsUser).WithInputSchema(ToolCatalog.ReportSchema);
builder.ConfigureMcpTool(ToolCatalog.ReadReportAsApp).WithInputSchema(ToolCatalog.ReportSchema);

builder.Build().Run();

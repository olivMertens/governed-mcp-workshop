// Bootstrap adapted from Azure-Samples/remote-mcp-functions-dotnet at commit
// 468c518c884ec318e3001b9573254c9e775409c9 (src/FunctionsMcpTool/Program.cs), MIT License,
// Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
// Workshop changes: five synthetic tools with explicit input schemas, a managed-identity ticket queue,
// no connection strings, no OpenTelemetry exporter (the Functions host sends telemetry with Entra auth),
// module 05 downstream identities (On-Behalf-Of and app-only managed identity) only when WORKSHOP_DELEGATED_ACCESS is enabled,
// module 06 OpenTelemetry tool-call spans (traces only, exported with the managed identity; logs keep the host path).
using Azure.Identity;
using Azure.Monitor.OpenTelemetry.Exporter;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Azure.Functions.Worker.OpenTelemetry;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenTelemetry;
using OpenTelemetry.Trace;
using Workshop.FunctionsMcp.Identity;
using Workshop.FunctionsMcp.Logic;

var builder = FunctionsApplication.CreateBuilder(args);

// Module 06: spans for each tool call and its downstream steps. Only when deployed (connection string and identity set).
// Application Insights local authentication is disabled, so the exporter signs in with the Function's managed identity.
var insights = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");
var identityClientId = Environment.GetEnvironmentVariable("WORKSHOP_IDENTITY_CLIENT_ID");
if (!string.IsNullOrEmpty(insights) && !string.IsNullOrEmpty(identityClientId))
{
    builder.Services.AddOpenTelemetry()
        .UseFunctionsWorkerDefaults()
        .WithTracing(tracing => tracing
            .AddSource(ToolTelemetry.SourceName)
            // .NET HTTP client spans: method, host, path and status. The query string is redacted by default; no body or header.
            .AddSource("System.Net.Http")
            .AddAzureMonitorTraceExporter(options =>
            {
                options.ConnectionString = insights;
                options.Credential = new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(identityClientId));
                // Workshop volume is tiny: keep every trace. A rate limit, when set, would override the ratio.
                options.TracesPerSecond = null;
                options.SamplingRatio = 1.0F;
            }));
}

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

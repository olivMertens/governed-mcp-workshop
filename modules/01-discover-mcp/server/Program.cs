using System.ComponentModel;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModelContextProtocol;
using ModelContextProtocol.Protocol;
using ModelContextProtocol.Server;

if (args is ["--validate"])
{
    await Validation.RunAsync();
    return;
}

if (args.Length != 0)
{
    Console.Error.WriteLine("This server accepts no arguments. Use --validate for local checks.");
    Environment.ExitCode = 1;
    return;
}

var builder = Host.CreateApplicationBuilder(new HostApplicationBuilderSettings { DisableDefaults = true });
builder.Logging.ClearProviders();
builder.Services.AddMcpServer()
    .WithStdioServerTransport()
    .WithToolsFromAssembly();
await builder.Build().RunAsync();

[McpServerToolType]
public static class HealthTools
{
    [McpServerTool(Name = "get_service_health", ReadOnly = true, Destructive = false, Idempotent = true, OpenWorld = false)]
    [Description("Read fixed synthetic health data. No Azure access, network calls or real monitoring.")]
    public static CallToolResult GetServiceHealth(
        [Description("Synthetic service name: workshop-api or ticket-queue.")] string service)
    {
        if (service is not ("workshop-api" or "ticket-queue"))
        {
            throw new McpException("Unknown synthetic service. Use workshop-api or ticket-queue.");
        }

        var data = JsonSerializer.SerializeToElement(new
        {
            service,
            status = service == "workshop-api" ? "healthy" : "degraded",
            source = "synthetic",
            environment = "local-only",
        });
        return new CallToolResult
        {
            IsError = false,
            StructuredContent = data,
            Content = [new TextContentBlock { Text = data.GetRawText() }],
        };
    }
}

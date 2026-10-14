using System.Reflection;
using System.Text.Json;
using ModelContextProtocol;
using ModelContextProtocol.Client;
using ModelContextProtocol.Protocol;

internal static class Validation
{
    internal static async Task RunAsync()
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        var stderrLines = 0;
        var transport = new StdioClientTransport(new StdioClientTransportOptions
        {
            Name = "workshop-local-validation",
            Command = "dotnet",
            Arguments = [Assembly.GetExecutingAssembly().Location],
            InheritEnvironmentVariables = false,
            EnvironmentVariables = StdioClientTransportOptions.GetDefaultEnvironmentVariables(),
            StandardErrorLines = _ => Interlocked.Increment(ref stderrLines),
        });
        await using (var client = await McpClient.CreateAsync(transport, cancellationToken: timeout.Token))
        {
            Check(!string.IsNullOrWhiteSpace(client.NegotiatedProtocolVersion), "SDK protocol negotiation");
            Console.WriteLine($"INFO negotiated MCP protocol: {client.NegotiatedProtocolVersion}");

            var tools = await client.ListToolsAsync(cancellationToken: timeout.Token);
            Check(tools.Count == 1 && tools[0].Name == "get_service_health", "tools/list exposes exactly one read tool");
            var tool = tools[0].ProtocolTool;
            Check(tool.Annotations is { ReadOnlyHint: true, DestructiveHint: false, IdempotentHint: true, OpenWorldHint: false },
                "read-only synthetic tool annotations");
            Check(tool.InputSchema.GetProperty("type").GetString() == "object" &&
                tool.InputSchema.GetProperty("properties").EnumerateObject().Count() == 1 &&
                tool.InputSchema.GetProperty("properties").TryGetProperty("service", out var schema) &&
                schema.GetProperty("type").GetString() == "string" &&
                tool.InputSchema.GetProperty("required").GetArrayLength() == 1 &&
                tool.InputSchema.GetProperty("required").EnumerateArray().Any(value => value.GetString() == "service"),
                "required service input schema");

            foreach (var (service, status) in new[] { ("workshop-api", "healthy"), ("ticket-queue", "degraded") })
            {
                var result = await client.CallToolAsync("get_service_health",
                    new Dictionary<string, object?> { ["service"] = service }, cancellationToken: timeout.Token);
                Check(result.IsError is false && result.StructuredContent is not null, $"tools/call {service} succeeds");
                var data = result.StructuredContent!.Value;
                Check(data.EnumerateObject().Count() == 4 &&
                    data.GetProperty("service").GetString() == service &&
                    data.GetProperty("status").GetString() == status &&
                    data.GetProperty("source").GetString() == "synthetic" &&
                    data.GetProperty("environment").GetString() == "local-only" &&
                    result.Content is [TextContentBlock text] &&
                    JsonElement.DeepEquals(JsonSerializer.Deserialize<JsonElement>(text.Text), data),
                    $"exact synthetic result for {service}");
            }

            var invalid = await client.CallToolAsync("get_service_health",
                new Dictionary<string, object?> { ["service"] = "unknown-synthetic-service" }, cancellationToken: timeout.Token);
            Check(invalid.IsError is true, "unknown service returns a tool error");
            var missing = await client.CallToolAsync("get_service_health",
                new Dictionary<string, object?>(), cancellationToken: timeout.Token);
            Check(missing.IsError is true, "missing service returns a tool error");

            var unknownToolRejected = false;
            try
            {
                await client.CallToolAsync("create_ticket",
                    new Dictionary<string, object?>(), cancellationToken: timeout.Token);
            }
            catch (McpProtocolException error) when (error.ErrorCode == McpErrorCode.InvalidParams)
            {
                unknownToolRejected = true;
            }
            Check(unknownToolRejected, "write tool is not exposed");
            var recovered = await client.ListToolsAsync(cancellationToken: timeout.Token);
            Check(recovered.Count == 1 && recovered[0].Name == "get_service_health",
                "server remains responsive after rejected inputs");
        }
        Check(Volatile.Read(ref stderrLines) == 0, "no server stderr logging during tested calls");
        Console.WriteLine("PASS local MCP checks complete (expected HTTP N/A; stdio, no Azure).");
        Console.WriteLine("MANUAL CHECK: client approval prompts are not tested by this validator.");
    }

    private static void Check(bool passed, string name)
    {
        if (!passed)
        {
            throw new InvalidOperationException($"FAIL {name} (expected HTTP N/A; stdio).");
        }
        Console.WriteLine($"PASS {name} (expected HTTP N/A; stdio).");
    }
}

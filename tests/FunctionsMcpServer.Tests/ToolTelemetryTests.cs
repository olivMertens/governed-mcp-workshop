using System.Diagnostics;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Workshop.FunctionsMcp.Logic;

namespace FunctionsMcpServer.Tests;

/// <summary>
/// Module 06: one OpenTelemetry span per tool call, metadata only. No exporter, no Azure call: an in-memory listener.
/// </summary>
public sealed class ToolTelemetryTests
{
    private static readonly string[] AllowedKeys =
        ["mcp.method.name", "gen_ai.operation.name", "gen_ai.tool.name", "workshop.caller", "workshop.outcome", "error.type"];

    private static List<Activity> Listen(string caller, Func<Task> run)
    {
        var spans = new List<Activity>();
        using var listener = new ActivityListener
        {
            ShouldListenTo = source => source.Name == ToolTelemetry.SourceName,
            Sample = (ref ActivityCreationOptions<ActivityContext> _) => ActivitySamplingResult.AllDataAndRecorded,
            ActivityStopped = activity =>
            {
                if (Equals(activity.GetTagItem("workshop.caller"), caller))
                {
                    lock (spans) { spans.Add(activity); }
                }
            },
        };
        ActivitySource.AddActivityListener(listener);
        run().GetAwaiter().GetResult();
        return spans;
    }

    private static readonly ILogger Logger = NullLogger.Instance;

    [Fact]
    public void Successful_call_records_one_span_with_the_mcp_attributes_only()
    {
        var caller = "caller-" + Guid.NewGuid();
        var spans = Listen(caller, () => ToolAudit.RunAsync(Logger, ToolCatalog.GetServiceHealth, "inv-601", caller,
            () => Task.FromResult("{\"service\":\"synthetic-argument-value\"}")));

        var span = Assert.Single(spans);
        Assert.Equal($"tools/call {ToolCatalog.GetServiceHealth}", span.DisplayName);
        Assert.Equal("tools/call", span.GetTagItem("mcp.method.name"));
        Assert.Equal("execute_tool", span.GetTagItem("gen_ai.operation.name"));
        Assert.Equal(ToolCatalog.GetServiceHealth, span.GetTagItem("gen_ai.tool.name"));
        Assert.Equal("success", span.GetTagItem("workshop.outcome"));
        Assert.Null(span.GetTagItem("error.type"));
        Assert.Equal(ActivityStatusCode.Unset, span.Status);
        Assert.All(span.TagObjects, tag => Assert.Contains(tag.Key, AllowedKeys));
        Assert.All(span.TagObjects, tag => Assert.DoesNotContain("synthetic-argument-value", tag.Value?.ToString() ?? string.Empty));
    }

    [Fact]
    public async Task Downstream_denial_is_a_tool_error_with_a_fixed_status_text()
    {
        var caller = "caller-" + Guid.NewGuid();
        var spans = Listen(caller, async () => await Assert.ThrowsAsync<DownstreamAccessDeniedException>(() =>
            ToolAudit.RunAsync(Logger, ToolCatalog.ReadReportAsUser, "inv-602", caller,
                () => throw new DownstreamAccessDeniedException("Azure Storage", 403))));

        var span = Assert.Single(spans);
        Assert.Equal("tool_error", span.GetTagItem("error.type"));
        Assert.Equal("denied-downstream:403", span.GetTagItem("workshop.outcome"));
        Assert.Equal(ActivityStatusCode.Error, span.Status);
        Assert.Equal("denied-downstream:403", span.StatusDescription);
        Assert.Empty(span.Events);
        Assert.All(span.TagObjects, tag => Assert.Contains(tag.Key, AllowedKeys));
        await Task.CompletedTask;
    }

    [Fact]
    public void Unexpected_failure_never_records_the_exception_message()
    {
        var caller = "caller-" + Guid.NewGuid();
        var spans = Listen(caller, async () => await Assert.ThrowsAsync<InvalidOperationException>(() =>
            ToolAudit.RunAsync(Logger, ToolCatalog.CreateTicket, "inv-603", caller,
                () => throw new HttpRequestException("downstream detail https://contoso.invalid/?sig=synthetic"))));

        var span = Assert.Single(spans);
        Assert.Equal("failed:HttpRequestException", span.StatusDescription);
        Assert.Empty(span.Events);
        Assert.All(span.TagObjects, tag => Assert.DoesNotContain("contoso.invalid", tag.Value?.ToString() ?? string.Empty));
    }
}

using System.Diagnostics;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// OpenTelemetry spans for tool calls, following the OpenTelemetry MCP semantic conventions (status: Development).
/// Metadata only: tool name, caller label, outcome. Never tool arguments, results, prompts or tokens (security invariant 7).
/// The conventions mark gen_ai.tool.call.arguments and gen_ai.tool.call.result as Opt-In; this server never sets them.
/// </summary>
public static class ToolTelemetry
{
    public const string SourceName = "Workshop.FunctionsMcp";

    public static readonly ActivitySource Source = new(SourceName);

    /// <summary>One span per tool call. Its parent is the Functions invocation, so it joins the gateway trace.</summary>
    public static Activity? StartToolCall(string tool, string caller)
    {
        var activity = Source.StartActivity($"tools/call {tool}", ActivityKind.Internal);
        activity?.SetTag("mcp.method.name", "tools/call");
        activity?.SetTag("gen_ai.operation.name", "execute_tool");
        activity?.SetTag("gen_ai.tool.name", tool);
        activity?.SetTag("workshop.caller", caller);
        return activity;
    }

    /// <summary>Records the outcome. Any refused or failed call is a tool error for the client (isError true).</summary>
    public static void End(Activity? activity, string outcome)
    {
        if (activity is null)
        {
            return;
        }

        activity.SetTag("workshop.outcome", outcome);
        if (outcome != "success")
        {
            activity.SetTag("error.type", "tool_error");
            // Fixed text: never the exception message, which can carry downstream request details.
            activity.SetStatus(ActivityStatusCode.Error, outcome);
        }
    }

    /// <summary>A named step inside a tool, for example the On-Behalf-Of exchange or the Storage read.</summary>
    public static Activity? StartStep(string name, string identity) =>
        Source.StartActivity(name, ActivityKind.Internal)?.SetTag("workshop.identity", identity);
}

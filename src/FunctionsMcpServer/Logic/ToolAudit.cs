using System.Diagnostics;
using Microsoft.Extensions.Logging;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// Payload-free audit line: tool name, caller, outcome, latency and correlation ID only.
/// Never log arguments, results, prompts, keys or tokens (security invariant 7).
/// </summary>
public static partial class ToolAudit
{
    // Level 0 has no authenticated caller. Module 03 replaces this with the validated caller object ID.
    public const string KeyHolderOnly = "none (function key only)";

    [LoggerMessage(EventId = 2001, Level = LogLevel.Information,
        Message = "MCP tool {Tool} by {Caller}: {Outcome} in {ElapsedMs} ms (invocation {InvocationId})")]
    private static partial void Completed(ILogger logger, string tool, string caller, string outcome, long elapsedMs, string invocationId);

    public static async Task<string> RunAsync(ILogger logger, string tool, string invocationId, Func<Task<string>> action)
    {
        ArgumentNullException.ThrowIfNull(logger);
        ArgumentNullException.ThrowIfNull(action);
        var watch = Stopwatch.StartNew();
        try
        {
            var result = await action().ConfigureAwait(false);
            Completed(logger, tool, KeyHolderOnly, "success", watch.ElapsedMilliseconds, invocationId);
            return result;
        }
        catch (ToolInputException)
        {
            Completed(logger, tool, KeyHolderOnly, "rejected-input", watch.ElapsedMilliseconds, invocationId);
            throw;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // Do not log the exception object: downstream messages can contain request details.
            Completed(logger, tool, KeyHolderOnly, "failed:" + exception.GetType().Name, watch.ElapsedMilliseconds, invocationId);
            throw new InvalidOperationException($"The synthetic tool failed. Correlate with invocation {invocationId} in the server logs.");
        }
    }

    public static Task<string> Run(ILogger logger, string tool, string invocationId, Func<string> action) =>
        RunAsync(logger, tool, invocationId, () => Task.FromResult(action()));
}

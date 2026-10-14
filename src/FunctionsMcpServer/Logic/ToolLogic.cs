using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// Pure tool logic for the level 0 ("open") workshop server. Every result is synthetic and labeled.
/// Function triggers in Tools/ only adapt MCP invocations to these methods.
/// </summary>
public static partial class ToolLogic
{
    public const string Level = "0-open";

    public static readonly IReadOnlyList<string> Services = ["workshop-api", "ticket-queue"];
    public static readonly IReadOnlyList<string> Severities = ["low", "medium", "high"];
    public static readonly IReadOnlyList<string> Reports = ["monthly-usage"];

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    [GeneratedRegex(@"^[A-Za-z0-9 .,:;()'-]{10,120}\z", RegexOptions.CultureInvariant, matchTimeoutMilliseconds: 100)]
    private static partial Regex SyntheticSummary();

    public static string GetServiceHealth(IReadOnlyDictionary<string, object>? arguments)
    {
        ToolArguments.RequireOnly(arguments, "service");
        var service = ToolArguments.RequireOneOf(arguments, "service", Services);
        return Serialize(new
        {
            service,
            status = service == "workshop-api" ? "healthy" : "degraded",
            source = "synthetic",
            level = Level,
        });
    }

    public static async Task<string> CreateTicketAsync(
        IReadOnlyDictionary<string, object>? arguments,
        ITicketQueue queue,
        TimeProvider clock,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(queue);
        ArgumentNullException.ThrowIfNull(clock);

        // Validate the complete argument shape before any side effect.
        ToolArguments.RequireOnly(arguments, "service", "severity", "summary");
        var service = ToolArguments.RequireOneOf(arguments, "service", Services);
        var severity = ToolArguments.RequireOneOf(arguments, "severity", Severities);
        var summary = ToolArguments.RequireString(arguments, "summary");
        if (!SyntheticSummary().IsMatch(summary))
        {
            throw new ToolInputException("Argument 'summary' must be 10-120 plain characters (letters, digits, spaces and . , : ; ( ) ' -).");
        }

        var ticketId = $"TCK-{Convert.ToHexString(RandomNumberGenerator.GetBytes(4))}";
        var message = Serialize(new
        {
            ticketId,
            service,
            severity,
            summary,
            source = "synthetic",
            level = Level,
            createdAtUtc = clock.GetUtcNow().ToString("O"),
        });
        await queue.SendAsync(message, cancellationToken).ConfigureAwait(false);

        return Serialize(new
        {
            ticketId,
            service,
            severity,
            status = "queued",
            source = "synthetic",
            level = Level,
            warning = "Level 0: anyone holding the function key can call this write tool. No user identity or role was checked.",
        });
    }

    public static string WhoAmI(IReadOnlyDictionary<string, object>? arguments)
    {
        ToolArguments.RequireOnly(arguments);
        return Serialize(new
        {
            caller = "unknown",
            source = "synthetic-demonstration",
            level = Level,
            downstreamCall = "none",
            explanation = "A function key identifies no user. Module 03 adds Microsoft Entra sign-in; module 05 adds On-Behalf-Of to Microsoft Graph.",
        });
    }

    public static string ReadReportAsUser(IReadOnlyDictionary<string, object>? arguments) =>
        ReadReport(arguments, "as-user (demonstration)",
            "Not evaluated: there is no signed-in user at level 0. Module 05 uses On-Behalf-Of so the caller's Storage role applies.");

    public static string ReadReportAsApp(IReadOnlyDictionary<string, object>? arguments) =>
        ReadReport(arguments, "as-app (demonstration)",
            "Not evaluated: no downstream call. Module 05 uses the managed identity, so every caller gets the same result.");

    private static string ReadReport(IReadOnlyDictionary<string, object>? arguments, string mode, string authorization)
    {
        ToolArguments.RequireOnly(arguments, "report");
        var report = ToolArguments.RequireOneOf(arguments, "report", Reports);
        return Serialize(new
        {
            report,
            mode,
            source = "synthetic-demonstration",
            level = Level,
            downstreamCall = "none",
            authorization,
            rows = new[]
            {
                new { service = "workshop-api", requests = 1200, errors = 3 },
                new { service = "ticket-queue", requests = 340, errors = 12 },
            },
        });
    }

    private static string Serialize<T>(T value) => JsonSerializer.Serialize(value, Json);
}

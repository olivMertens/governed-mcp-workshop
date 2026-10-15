using System.Text.Json;
using Workshop.FunctionsMcp.Identity;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// Level 3 (module 05) behaviour of whoami, read_report_as_user and read_report_as_app. Who carries the rights is
/// decided per tool and never changes at run time:
/// <list type="bullet">
/// <item>whoami: On-Behalf-Of to Microsoft Graph (User.Read). Returns only an allowlisted synthetic persona label.</item>
/// <item>read_report_as_user: On-Behalf-Of to Azure Storage (user_impersonation). The caller's own Storage role applies.</item>
/// <item>read_report_as_app: the app-only managed identity. Same result for every authorized caller.</item>
/// </list>
/// The incoming MCP token is used only as the On-Behalf-Of assertion; Graph and Storage each get their own token.
/// </summary>
public sealed class DelegatedTools(DelegatedAccessSettings settings, IDownstreamCredentials credentials, IDownstreamClients clients)
{
    public const string Level = "3-delegated-and-app-only";
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public bool Enabled => settings.Enabled;

    public async Task<string> WhoAmIAsync(IReadOnlyDictionary<string, object>? arguments, IReadOnlyDictionary<string, string>? headers,
        CancellationToken cancellationToken)
    {
        ToolArguments.RequireOnly(arguments);
        var caller = RequireUser(headers);
        var graphObjectId = await clients.GetSignedInObjectIdAsync(credentials.ForUser(caller), cancellationToken).ConfigureAwait(false);
        if (!string.Equals(graphObjectId, caller.ObjectId, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Microsoft Graph returned a different user than the validated caller.");
        }

        return Serialize(new
        {
            persona = Persona(caller.ObjectId),
            level = Level,
            identity = "signed-in user (On-Behalf-Of)",
            downstream = "Microsoft Graph GET /me?$select=id with its own token (delegated User.Read)",
            graphMatchesCaller = true,
            privacy = "Only the object ID is requested from Graph and mapped to an allowlisted synthetic persona. No name or email is read or returned.",
        });
    }

    public async Task<string> ReadReportAsUserAsync(IReadOnlyDictionary<string, object>? arguments, IReadOnlyDictionary<string, string>? headers,
        CancellationToken cancellationToken)
    {
        var report = RequireReport(arguments);
        var caller = RequireUser(headers);
        var content = await clients.ReadReportAsync(credentials.ForUser(caller), AzureDownstreamClients.StorageUserScope, BlobName(report), cancellationToken)
            .ConfigureAwait(false);
        return ReportResult(report, "as-user", "signed-in user via On-Behalf-Of (delegated Azure Storage user_impersonation)",
            "The caller's own Storage Blob Data Reader role on the report container decided this result.", Persona(caller.ObjectId), content);
    }

    public async Task<string> ReadReportAsAppAsync(IReadOnlyDictionary<string, object>? arguments, CancellationToken cancellationToken)
    {
        var report = RequireReport(arguments);
        RequireConfigured();
        var content = await clients.ReadReportAsync(credentials.ForApp(), AzureDownstreamClients.StorageAppScope, BlobName(report), cancellationToken)
            .ConfigureAwait(false);
        return ReportResult(report, "as-app", "the app-only user-assigned managed identity",
            "The managed identity's Storage Blob Data Reader role on the one report container decided this result, for every caller.", null, content);
    }

    private CallerContext RequireUser(IReadOnlyDictionary<string, string>? headers)
    {
        RequireConfigured();
        return CallerContext.ForUser(headers, settings.TenantId);
    }

    private void RequireConfigured()
    {
        if (!settings.Enabled)
        {
            throw new InvalidOperationException("Module 05 is not enabled.");
        }

        if (settings.ConfigurationError is not null)
        {
            throw new InvalidOperationException(settings.ConfigurationError);
        }
    }

    private static string RequireReport(IReadOnlyDictionary<string, object>? arguments)
    {
        ToolArguments.RequireOnly(arguments, "report");
        return ToolArguments.RequireOneOf(arguments, "report", ToolLogic.Reports);
    }

    private static string BlobName(string report) => report + ".json";

    private string Persona(string objectId) =>
        settings.PersonaByObjectId.TryGetValue(objectId, out var persona) ? persona : "unlisted";

    private static string ReportResult(string report, string mode, string identity, string authorization, string? persona, string content)
    {
        using var document = ParseSynthetic(content, report);
        return Serialize(new
        {
            report,
            mode,
            level = Level,
            identity,
            authorization,
            persona,
            source = "synthetic",
            rows = document.RootElement.GetProperty("rows").Clone(),
        });
    }

    /// <summary>Accepts only the workshop's synthetic report shape, so the tool can never relay unrelated blob content.</summary>
    internal static JsonDocument ParseSynthetic(string content, string report)
    {
        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(content);
        }
        catch (JsonException)
        {
            throw new InvalidOperationException("The report blob is not the synthetic workshop report.");
        }

        var root = document.RootElement;
        var valid = root.ValueKind == JsonValueKind.Object &&
            root.TryGetProperty("report", out var name) && name.ValueKind == JsonValueKind.String && name.GetString() == report &&
            root.TryGetProperty("source", out var source) && source.ValueKind == JsonValueKind.String && source.GetString() == "synthetic" &&
            root.TryGetProperty("rows", out var rows) && rows.ValueKind == JsonValueKind.Array && rows.GetArrayLength() is > 0 and <= 20 &&
            rows.EnumerateArray().All(row => row.ValueKind == JsonValueKind.Object &&
                row.TryGetProperty("service", out var service) && service.ValueKind == JsonValueKind.String &&
                ToolLogic.Services.Contains(service.GetString()!, StringComparer.Ordinal) &&
                row.TryGetProperty("requests", out var requests) && requests.ValueKind == JsonValueKind.Number &&
                row.TryGetProperty("errors", out var errors) && errors.ValueKind == JsonValueKind.Number &&
                row.EnumerateObject().Count() == 3);
        if (!valid)
        {
            document.Dispose();
            throw new InvalidOperationException("The report blob is not the synthetic workshop report.");
        }

        return document;
    }

    private static string Serialize<T>(T value) => JsonSerializer.Serialize(value, Json);
}

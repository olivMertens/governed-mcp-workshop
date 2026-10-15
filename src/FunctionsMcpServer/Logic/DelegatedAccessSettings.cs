using System.Text.Json;
using System.Text.RegularExpressions;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// Module 05 (level 3) settings, written by infra/workload when enable_delegated_access = true.
/// When WORKSHOP_DELEGATED_ACCESS is not "enabled", the server keeps the module 02 synthetic demonstrations.
/// No setting is secret: client IDs, a tenant ID, a container URL and test-account object IDs only.
/// </summary>
public sealed partial class DelegatedAccessSettings
{
    public const string EnabledSetting = "WORKSHOP_DELEGATED_ACCESS";
    public const string TenantSetting = "WORKSHOP_TENANT_ID";
    public const string ApiClientSetting = "WORKSHOP_MCP_API_CLIENT_ID";
    public const string AssertionIdentitySetting = "WORKSHOP_OBO_ASSERTION_CLIENT_ID";
    public const string ReportIdentitySetting = "WORKSHOP_REPORT_IDENTITY_CLIENT_ID";
    public const string ReportContainerSetting = "WORKSHOP_REPORT_CONTAINER_URL";
    public const string PersonaSetting = "WORKSHOP_PERSONA_OBJECT_IDS";

    /// <summary>Synthetic persona labels that whoami may return. Anything else is reported as "unlisted".</summary>
    public static readonly IReadOnlyList<string> AllowedPersonas = ["alice", "bob", "eve"];

    [GeneratedRegex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", RegexOptions.CultureInvariant, matchTimeoutMilliseconds: 100)]
    private static partial Regex Guid();

    private DelegatedAccessSettings(bool enabled, string? error)
    {
        Enabled = enabled;
        ConfigurationError = error;
    }

    /// <summary>True when module 05 is deployed. The tools then call Microsoft Graph and Azure Storage for real.</summary>
    public bool Enabled { get; }

    /// <summary>Fixed text when Enabled is true but the settings are incomplete. Tools then fail closed.</summary>
    public string? ConfigurationError { get; }

    public string TenantId { get; private init; } = string.Empty;
    public string ApiClientId { get; private init; } = string.Empty;
    public string AssertionIdentityClientId { get; private init; } = string.Empty;
    public string ReportIdentityClientId { get; private init; } = string.Empty;
    public Uri? ReportContainer { get; private init; }
    public IReadOnlyDictionary<string, string> PersonaByObjectId { get; private init; } = new Dictionary<string, string>();

    public static DelegatedAccessSettings Disabled { get; } = new(false, null);

    public static DelegatedAccessSettings FromSettings(Func<string, string?> settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        if (!string.Equals(settings(EnabledSetting), "enabled", StringComparison.Ordinal))
        {
            return Disabled;
        }

        static DelegatedAccessSettings Broken(string message) => new(true, message);

        var tenant = settings(TenantSetting);
        var api = settings(ApiClientSetting);
        var assertion = settings(AssertionIdentitySetting);
        var report = settings(ReportIdentitySetting);
        foreach (var value in new[] { tenant, api, assertion, report })
        {
            if (value is null || !Guid().IsMatch(value))
            {
                return Broken("Module 05 settings are incomplete: tenant, MCP API client ID and both managed identity client IDs must be lowercase GUIDs.");
            }
        }

        if (string.Equals(assertion, report, StringComparison.Ordinal))
        {
            return Broken("Module 05 needs two different managed identities: one only for the On-Behalf-Of assertion, one for app-only Storage reads.");
        }

        var containerText = settings(ReportContainerSetting);
        if (!Uri.TryCreate(containerText, UriKind.Absolute, out var container) || container.Scheme != Uri.UriSchemeHttps ||
            !string.IsNullOrEmpty(container.UserInfo) || !string.IsNullOrEmpty(container.Query) || !string.IsNullOrEmpty(container.Fragment) ||
            container.AbsolutePath.Trim('/').Length == 0 || container.AbsolutePath.Trim('/').Contains('/', StringComparison.Ordinal))
        {
            return Broken("WORKSHOP_REPORT_CONTAINER_URL must be an HTTPS container URL without credentials, query string or blob path.");
        }

        var personas = new Dictionary<string, string>(StringComparer.Ordinal);
        var personaText = settings(PersonaSetting);
        if (!string.IsNullOrWhiteSpace(personaText))
        {
            try
            {
                using var document = JsonDocument.Parse(personaText);
                if (document.RootElement.ValueKind != JsonValueKind.Object)
                {
                    return Broken("WORKSHOP_PERSONA_OBJECT_IDS must be a JSON object of persona label to object ID.");
                }

                foreach (var property in document.RootElement.EnumerateObject())
                {
                    var objectId = property.Value.ValueKind == JsonValueKind.String ? property.Value.GetString() : null;
                    if (!AllowedPersonas.Contains(property.Name, StringComparer.Ordinal) || objectId is null || !Guid().IsMatch(objectId) ||
                        !personas.TryAdd(objectId, property.Name))
                    {
                        return Broken("WORKSHOP_PERSONA_OBJECT_IDS accepts only alice, bob or eve mapped to distinct lowercase object ID GUIDs.");
                    }
                }
            }
            catch (JsonException)
            {
                return Broken("WORKSHOP_PERSONA_OBJECT_IDS must be a JSON object of persona label to object ID.");
            }
        }

        return new DelegatedAccessSettings(true, null)
        {
            TenantId = tenant!,
            ApiClientId = api!,
            AssertionIdentityClientId = assertion!,
            ReportIdentityClientId = report!,
            ReportContainer = new Uri(container.GetLeftPart(UriPartial.Path).TrimEnd('/') + "/"),
            PersonaByObjectId = personas,
        };
    }

    public static bool IsGuid(string? value) => value is not null && Guid().IsMatch(value);
}

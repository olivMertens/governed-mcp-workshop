using System.Text;
using System.Text.Json;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// A caller refused before any downstream call. Messages are fixed text and never echo header or token values.
/// </summary>
public sealed class CallerRejectedException(string message) : Exception(message);

/// <summary>
/// The signed-in caller, as already validated by Functions/App Service built-in authentication.
/// This class never validates a JSON Web Token (JWT) itself (security invariant 3): built-in authentication has checked
/// issuer, tenant, audience and expiry before the request reaches the worker, and it injects X-MS-CLIENT-PRINCIPAL.
/// App Service does not let external requests set the X-MS-CLIENT-PRINCIPAL* headers; the module 04 gateway also deletes
/// any client-supplied copy. The bearer token is kept only as the On-Behalf-Of user assertion: it is sent to the
/// Microsoft Entra token endpoint, never to Microsoft Graph or Azure Storage (security invariant 2).
/// Pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit 468c518c884ec318e3001b9573254c9e775409c9
/// (src/FunctionsMcpTool/HelloToolWithAuth.cs), MIT License, Copyright (c) Microsoft Corporation. See THIRD-PARTY-NOTICES.md.
/// </summary>
public sealed class CallerContext
{
    public const string PrincipalHeader = "X-MS-CLIENT-PRINCIPAL";
    public const string PrincipalIdHeader = "X-MS-CLIENT-PRINCIPAL-ID";
    public const string RequiredScope = "user_impersonation";

    private static readonly string[] TenantClaims = ["tid", "http://schemas.microsoft.com/identity/claims/tenantid"];
    private static readonly string[] ObjectIdClaims = ["oid", "http://schemas.microsoft.com/identity/claims/objectidentifier"];
    private static readonly string[] ScopeClaims = ["scp", "http://schemas.microsoft.com/identity/claims/scope"];

    private CallerContext(string userAssertion, string objectId)
    {
        UserAssertion = userAssertion;
        ObjectId = objectId;
    }

    /// <summary>The incoming MCP-audience access token. Used only as the On-Behalf-Of assertion. Never logged or returned.</summary>
    internal string UserAssertion { get; }

    /// <summary>The caller's object ID (oid), from the platform-validated principal.</summary>
    public string ObjectId { get; }

    public override string ToString() => $"caller {ObjectId}";

    /// <summary>Caller label for the payload-free audit line: the platform-injected object ID, or "unknown".</summary>
    public static string AuditLabel(IReadOnlyDictionary<string, string>? headers) =>
        headers is not null && headers.TryGetValue(PrincipalIdHeader, out var id) && DelegatedAccessSettings.IsGuid(id?.ToLowerInvariant())
            ? id!.ToLowerInvariant()
            : "unknown";

    /// <summary>
    /// Builds the user context for On-Behalf-Of. Rejects anything that is not a delegated user token from the expected tenant:
    /// app-only callers (no scp claim), tokens without user_impersonation, missing platform principal or bearer token.
    /// </summary>
    public static CallerContext ForUser(IReadOnlyDictionary<string, string>? headers, string expectedTenantId)
    {
        if (headers is null || !headers.TryGetValue(PrincipalHeader, out var encoded) || string.IsNullOrWhiteSpace(encoded))
        {
            throw new CallerRejectedException("No platform-validated caller. Built-in Microsoft Entra authentication must run in front of this tool.");
        }

        var claims = ReadClaims(encoded);
        var tenant = First(claims, TenantClaims)?.ToLowerInvariant();
        var objectId = First(claims, ObjectIdClaims)?.ToLowerInvariant();
        if (tenant is null || !string.Equals(tenant, expectedTenantId, StringComparison.Ordinal))
        {
            throw new CallerRejectedException("The caller is not from the workshop tenant.");
        }

        if (objectId is null || !DelegatedAccessSettings.IsGuid(objectId))
        {
            throw new CallerRejectedException("The caller has no object ID.");
        }

        if (headers.TryGetValue(PrincipalIdHeader, out var principalId) && !string.Equals(principalId?.ToLowerInvariant(), objectId, StringComparison.Ordinal))
        {
            throw new CallerRejectedException("Inconsistent platform principal headers.");
        }

        var scopes = (First(claims, ScopeClaims) ?? string.Empty).Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var idType = First(claims, ["idtyp"]);
        if (scopes.Length == 0 || string.Equals(idType, "app", StringComparison.Ordinal))
        {
            // On-Behalf-Of works for user principals only; an application token must never be turned into a user context.
            throw new CallerRejectedException("App-only callers cannot use a user-context tool. Sign in as a user, or call read_report_as_app.");
        }

        if (!scopes.Contains(RequiredScope, StringComparer.Ordinal))
        {
            throw new CallerRejectedException("The delegated token lacks the user_impersonation scope of the MCP API.");
        }

        if (!headers.TryGetValue("Authorization", out var authorization) || authorization is null ||
            !authorization.StartsWith("Bearer ", StringComparison.Ordinal) || authorization.Length <= "Bearer ".Length)
        {
            throw new CallerRejectedException("No bearer token to use as the On-Behalf-Of user assertion.");
        }

        return new CallerContext(authorization["Bearer ".Length..].Trim(), objectId);
    }

    private static Dictionary<string, string> ReadClaims(string encoded)
    {
        try
        {
            var json = Encoding.UTF8.GetString(Convert.FromBase64String(encoded));
            using var document = JsonDocument.Parse(json);
            var claims = new Dictionary<string, string>(StringComparer.Ordinal);
            if (document.RootElement.TryGetProperty("claims", out var array) && array.ValueKind == JsonValueKind.Array)
            {
                foreach (var claim in array.EnumerateArray())
                {
                    if (claim.ValueKind == JsonValueKind.Object &&
                        claim.TryGetProperty("typ", out var type) && type.ValueKind == JsonValueKind.String &&
                        claim.TryGetProperty("val", out var value) && value.ValueKind == JsonValueKind.String)
                    {
                        claims.TryAdd(type.GetString()!, value.GetString()!);
                    }
                }
            }

            return claims;
        }
        catch (Exception exception) when (exception is FormatException or JsonException or DecoderFallbackException)
        {
            throw new CallerRejectedException("The platform principal header is malformed.");
        }
    }

    private static string? First(Dictionary<string, string> claims, string[] names)
    {
        foreach (var name in names)
        {
            if (claims.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value))
            {
                return value.Trim();
            }
        }

        return null;
    }
}

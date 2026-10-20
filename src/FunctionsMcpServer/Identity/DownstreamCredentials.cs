using Azure.Core;
using Azure.Identity;
using Workshop.FunctionsMcp.Logic;

namespace Workshop.FunctionsMcp.Identity;

/// <summary>
/// The two downstream identities of module 05. Chosen per tool and never mixed (security invariant 2):
/// <list type="bullet">
/// <item>user context (whoami, read_report_as_user): On-Behalf-Of, one token per downstream resource;</item>
/// <item>application context (read_report_as_app): the app-only user-assigned managed identity.</item>
/// </list>
/// There is no developer-credential fallback: when module 05 is enabled, a missing identity fails the tool.
/// </summary>
public interface IDownstreamCredentials
{
    /// <summary>On-Behalf-Of credential for this caller. Each downstream resource gets its own token from it.</summary>
    TokenCredential ForUser(CallerContext caller);

    /// <summary>App-only managed identity credential: the same rights for every caller.</summary>
    TokenCredential ForApp();
}

/// <summary>
/// Secretless implementation. The MCP API registration trusts the On-Behalf-Of assertion managed identity through a
/// federated identity credential (issuer https://login.microsoftonline.com/{tenant}/v2.0, subject = the identity's
/// principal ID, audience api://AzureADTokenExchange). The managed identity token is the client assertion; there is no
/// client secret or certificate anywhere.
/// Pattern adapted from Azure-Samples/remote-mcp-functions-dotnet at commit 468c518c884ec318e3001b9573254c9e775409c9
/// (src/FunctionsMcpTool/HelloToolWithAuth.cs, BuildClientAssertionCallback), MIT License, Copyright (c) Microsoft
/// Corporation. See THIRD-PARTY-NOTICES.md. Workshop changes: no local developer-credential chain, two separate user-assigned
/// identities, explicit settings instead of WEBSITE_AUTH_CLIENT_ID/OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID.
/// </summary>
public sealed class ManagedIdentityDownstreamCredentials : IDownstreamCredentials
{
    /// <summary>Token exchange audience for the Microsoft Entra global service (Learn: workload-identity-federation-config-app-trust-managed-identity).</summary>
    public const string TokenExchangeScope = "api://AzureADTokenExchange/.default";

    private readonly DelegatedAccessSettings settings;
    private readonly Lazy<TokenCredential> assertionIdentity;
    private readonly Lazy<TokenCredential> appIdentity;

    public ManagedIdentityDownstreamCredentials(DelegatedAccessSettings settings)
    {
        this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
        assertionIdentity = new(() => new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(Require(settings.AssertionIdentityClientId))));
        appIdentity = new(() => new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(Require(settings.ReportIdentityClientId))));
    }

    public TokenCredential ForUser(CallerContext caller)
    {
        ArgumentNullException.ThrowIfNull(caller);
        return new OnBehalfOfCredential(Require(settings.TenantId), Require(settings.ApiClientId), GetAssertionAsync, caller.UserAssertion);
    }

    public TokenCredential ForApp() => appIdentity.Value;

    private async Task<string> GetAssertionAsync(CancellationToken cancellationToken)
    {
        // Span name only: the assertion itself is a token and is never recorded.
        using var step = ToolTelemetry.StartStep("Managed identity assertion (no secret)", "OBO assertion managed identity");
        return (await assertionIdentity.Value.GetTokenAsync(new TokenRequestContext([TokenExchangeScope]), cancellationToken).ConfigureAwait(false)).Token;
    }

    private string Require(string value) =>
        settings.Enabled && settings.ConfigurationError is null && !string.IsNullOrEmpty(value)
            ? value
            : throw new InvalidOperationException("Module 05 identities are not configured. Deploy enable_delegated_access first.");
}

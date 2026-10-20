using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using Azure;
using Azure.Core;
using Azure.Storage.Blobs;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// A downstream API refused the identity used for this tool (for example, Azure Storage HTTP 403 for Bob).
/// The MCP response stays HTTP 200; the tool result carries isError: true. Fixed text, no downstream message.
/// </summary>
public sealed class DownstreamAccessDeniedException(string resource, int status)
    : Exception($"{resource} refused the identity used by this tool (downstream HTTP {status}).")
{
    public string Resource { get; } = resource;
    public int Status { get; } = status;
}

/// <summary>Downstream calls of module 05. Each method receives the credential chosen by the tool.</summary>
public interface IDownstreamClients
{
    /// <summary>Microsoft Graph GET /me?$select=id. Only the object ID is requested: no name, email or profile.</summary>
    Task<string> GetSignedInObjectIdAsync(TokenCredential credential, CancellationToken cancellationToken);

    /// <summary>Reads one synthetic report blob with a token for <paramref name="storageScope"/>.</summary>
    Task<string> ReadReportAsync(TokenCredential credential, string storageScope, string blobName, CancellationToken cancellationToken);
}

/// <summary>Real clients: Microsoft Graph over HTTPS and the Azure Storage Blob client library. No keys, no SAS.</summary>
public sealed class AzureDownstreamClients(DelegatedAccessSettings settings, HttpMessageHandler? graphHandler = null) : IDownstreamClients
{
    public const string GraphScope = "https://graph.microsoft.com/User.Read";
    public const string StorageUserScope = "https://storage.azure.com/user_impersonation";
    public const string StorageAppScope = "https://storage.azure.com/.default";
    public const int MaximumReportBytes = 16 * 1024;
    private static readonly Uri GraphMe = new("https://graph.microsoft.com/v1.0/me?$select=id");

    private readonly HttpClient graph = new(graphHandler ?? new SocketsHttpHandler(), disposeHandler: true) { Timeout = TimeSpan.FromSeconds(20) };

    public async Task<string> GetSignedInObjectIdAsync(TokenCredential credential, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(credential);
        using var step = ToolTelemetry.StartStep("Microsoft Graph GET /me", "signed-in user (On-Behalf-Of)");
        // A separate On-Behalf-Of token whose audience is Microsoft Graph; the MCP token never goes to Graph.
        AccessToken token;
        using (ToolTelemetry.StartStep("On-Behalf-Of token exchange (Microsoft Graph)", "signed-in user (On-Behalf-Of)"))
        {
            token = await credential.GetTokenAsync(new TokenRequestContext([GraphScope]), cancellationToken).ConfigureAwait(false);
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, GraphMe);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
        using var response = await graph.SendAsync(request, cancellationToken).ConfigureAwait(false);
        if (response.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.Unauthorized)
        {
            step?.SetStatus(ActivityStatusCode.Error, $"HTTP {(int)response.StatusCode}");
            throw new DownstreamAccessDeniedException("Microsoft Graph", (int)response.StatusCode);
        }

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Microsoft Graph returned HTTP {(int)response.StatusCode}.");
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
        return document.RootElement.TryGetProperty("id", out var id) && id.ValueKind == JsonValueKind.String
            ? id.GetString()!.ToLowerInvariant()
            : throw new InvalidOperationException("Microsoft Graph returned no object ID.");
    }

    public async Task<string> ReadReportAsync(TokenCredential credential, string storageScope, string blobName, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(credential);
        var blob = CreateBlobClient(settings, credential, storageScope, blobName);
        using var step = ToolTelemetry.StartStep("Azure Storage read report",
            storageScope == StorageUserScope ? "signed-in user (On-Behalf-Of)" : "app-only managed identity");
        try
        {
            var content = (await blob.DownloadContentAsync(cancellationToken).ConfigureAwait(false)).Value.Content;
            if (content.ToMemory().Length > MaximumReportBytes)
            {
                throw new InvalidOperationException("The report blob is larger than the synthetic workshop report.");
            }

            return content.ToString();
        }
        catch (RequestFailedException exception) when (exception.Status == 403)
        {
            step?.SetStatus(ActivityStatusCode.Error, "HTTP 403");
            throw new DownstreamAccessDeniedException("Azure Storage", 403);
        }
        catch (RequestFailedException exception) when (exception.Status == 404)
        {
            throw new InvalidOperationException("The synthetic report is not published yet. Run the module 05 publish step.");
        }
    }

    internal static BlobClient CreateBlobClient(DelegatedAccessSettings settings, TokenCredential credential, string storageScope, string blobName)
    {
        ArgumentNullException.ThrowIfNull(settings);
        if (settings.ReportContainer is null || settings.ConfigurationError is not null)
        {
            throw new InvalidOperationException("The report container is not configured. Deploy enable_delegated_access first.");
        }

        if (storageScope is not (StorageUserScope or StorageAppScope))
        {
            throw new InvalidOperationException("Unexpected Storage scope.");
        }

        return new BlobClient(new Uri(settings.ReportContainer, blobName), new ScopedCredential(credential, storageScope));
    }

    /// <summary>
    /// Requests exactly one Storage scope: user_impersonation for On-Behalf-Of, .default for the managed identity.
    /// Refuses any other resource, so a Storage client can never obtain a token for something else.
    /// </summary>
    internal sealed class ScopedCredential(TokenCredential inner, string scope) : TokenCredential
    {
        public override AccessToken GetToken(TokenRequestContext requestContext, CancellationToken cancellationToken) =>
            inner.GetToken(Narrow(requestContext), cancellationToken);

        public override ValueTask<AccessToken> GetTokenAsync(TokenRequestContext requestContext, CancellationToken cancellationToken) =>
            inner.GetTokenAsync(Narrow(requestContext), cancellationToken);

        private TokenRequestContext Narrow(TokenRequestContext requestContext)
        {
            if (requestContext.Scopes.Any(requested => !requested.StartsWith("https://storage.azure.com/", StringComparison.Ordinal)))
            {
                throw new InvalidOperationException("The Storage client asked for a token for another resource.");
            }

            return new TokenRequestContext([scope], requestContext.ParentRequestId, requestContext.Claims, requestContext.TenantId,
                requestContext.IsCaeEnabled);
        }
    }
}

using System.Net;
using System.Text;
using System.Text.Json;
using Azure.Core;
using Azure.Identity;
using Microsoft.Extensions.Logging;
using Workshop.FunctionsMcp.Identity;
using Workshop.FunctionsMcp.Logic;

namespace FunctionsMcpServer.Tests;

/// <summary>
/// Module 05 logic with fake credentials and fake downstream clients: no Azure, Entra, Graph or Storage call is made.
/// All IDs are synthetic. The "token" strings are labels, not tokens.
/// </summary>
public sealed class DelegatedToolsTests
{
    private const string Tenant = "00000000-0000-4000-8000-000000000000";
    private const string ApiClient = "44444444-4444-4444-8444-444444444444";
    private const string AssertionIdentity = "55555555-5555-4555-8555-555555555555";
    private const string ReportIdentity = "66666666-6666-4666-8666-666666666666";
    private const string Alice = "aaaaaaaa-0000-4000-8000-00000000a11c";
    private const string Bob = "bbbbbbbb-0000-4000-8000-000000000b0b";
    private const string Stranger = "cccccccc-0000-4000-8000-00000000c0de";
    private const string Container = "https://stp01synthetic.blob.core.windows.net/reports";

    private const string SyntheticReport = """
        {"report":"monthly-usage","source":"synthetic","rows":[{"service":"workshop-api","requests":1200,"errors":3},{"service":"ticket-queue","requests":340,"errors":12}]}
        """;

    private static Dictionary<string, string?> ValidSettings() => new()
    {
        [DelegatedAccessSettings.EnabledSetting] = "enabled",
        [DelegatedAccessSettings.TenantSetting] = Tenant,
        [DelegatedAccessSettings.ApiClientSetting] = ApiClient,
        [DelegatedAccessSettings.AssertionIdentitySetting] = AssertionIdentity,
        [DelegatedAccessSettings.ReportIdentitySetting] = ReportIdentity,
        [DelegatedAccessSettings.ReportContainerSetting] = Container,
        [DelegatedAccessSettings.PersonaSetting] = $$"""{"alice":"{{Alice}}","bob":"{{Bob}}"}""",
    };

    private static DelegatedAccessSettings Settings(Dictionary<string, string?>? values = null)
    {
        values ??= ValidSettings();
        return DelegatedAccessSettings.FromSettings(name => values.TryGetValue(name, out var value) ? value : null);
    }

    private sealed class FakeCredential(string label) : TokenCredential
    {
        public string Label { get; } = label;
        public List<string> Scopes { get; } = [];

        public override AccessToken GetToken(TokenRequestContext requestContext, CancellationToken cancellationToken)
        {
            Scopes.AddRange(requestContext.Scopes);
            return new AccessToken($"downstream-{Label}-{string.Join(',', requestContext.Scopes)}", DateTimeOffset.UtcNow.AddMinutes(5));
        }

        public override ValueTask<AccessToken> GetTokenAsync(TokenRequestContext requestContext, CancellationToken cancellationToken) =>
            ValueTask.FromResult(GetToken(requestContext, cancellationToken));
    }

    private sealed class FakeCredentials : IDownstreamCredentials
    {
        public List<string> UserAssertions { get; } = [];
        public int AppCalls { get; private set; }

        public TokenCredential ForUser(CallerContext caller)
        {
            UserAssertions.Add(caller.UserAssertion);
            return new FakeCredential("user:" + caller.ObjectId);
        }

        public TokenCredential ForApp()
        {
            AppCalls++;
            return new FakeCredential("app");
        }
    }

    /// <summary>Simulates Graph and Storage: Alice holds Storage Blob Data Reader on the container, Bob holds nothing.</summary>
    private sealed class FakeClients(string? graphObjectId = null, string report = SyntheticReport) : IDownstreamClients
    {
        public List<(string Credential, string Scope)> Calls { get; } = [];

        public Task<string> GetSignedInObjectIdAsync(TokenCredential credential, CancellationToken cancellationToken)
        {
            var label = ((FakeCredential)credential).Label;
            Calls.Add((label, "graph"));
            return Task.FromResult(graphObjectId ?? label["user:".Length..]);
        }

        public Task<string> ReadReportAsync(TokenCredential credential, string storageScope, string blobName, CancellationToken cancellationToken)
        {
            var label = ((FakeCredential)credential).Label;
            Calls.Add((label, storageScope));
            Assert.Equal("monthly-usage.json", blobName);
            if (label == "user:" + Bob)
            {
                throw new DownstreamAccessDeniedException("Azure Storage", 403);
            }

            return Task.FromResult(report);
        }
    }

    private sealed class RecordingLogger : ILogger
    {
        public List<string> Lines { get; } = [];
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => true;
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
        {
            Lines.Add(formatter(state, exception));
            Assert.Null(exception);
        }
    }

    private static Dictionary<string, string> UserHeaders(string objectId, string scopes = "user_impersonation", string tenant = Tenant,
        bool includeBearer = true, string? principalId = null, string? idType = null)
    {
        var claims = new List<object>
        {
            new { typ = "http://schemas.microsoft.com/identity/claims/tenantid", val = tenant },
            new { typ = "http://schemas.microsoft.com/identity/claims/objectidentifier", val = objectId },
            new { typ = "aud", val = ApiClient },
        };
        if (scopes.Length > 0)
        {
            claims.Add(new { typ = "http://schemas.microsoft.com/identity/claims/scope", val = scopes });
        }
        else
        {
            claims.Add(new { typ = "roles", val = "Tools.Execute.All" });
        }

        if (idType is not null)
        {
            claims.Add(new { typ = "idtyp", val = idType });
        }

        var principal = Convert.ToBase64String(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new { auth_typ = "aad", claims })));
        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [CallerContext.PrincipalHeader] = principal,
            [CallerContext.PrincipalIdHeader] = principalId ?? objectId,
        };
        if (includeBearer)
        {
            headers["Authorization"] = "Bearer mcp-audience-assertion-for-" + objectId;
        }

        return headers;
    }

    private static Dictionary<string, object> Report() => new() { ["report"] = "monthly-usage" };

    private static JsonElement Parse(string json) => JsonDocument.Parse(json).RootElement;

    [Fact]
    public void Settings_are_disabled_unless_explicitly_enabled_and_fail_closed_when_incomplete()
    {
        Assert.False(DelegatedAccessSettings.FromSettings(_ => null).Enabled);
        Assert.False(DelegatedAccessSettings.FromSettings(name => name == DelegatedAccessSettings.EnabledSetting ? "true" : null).Enabled);

        var valid = Settings();
        Assert.True(valid.Enabled);
        Assert.Null(valid.ConfigurationError);
        Assert.Equal(Container + "/", valid.ReportContainer!.ToString());
        Assert.Equal("alice", valid.PersonaByObjectId[Alice]);

        foreach (var (name, value) in new (string, string?)[]
        {
            (DelegatedAccessSettings.TenantSetting, null),
            (DelegatedAccessSettings.ReportIdentitySetting, AssertionIdentity), // one identity for both roles is refused
            (DelegatedAccessSettings.ReportContainerSetting, Container + "?sv=2024&sig=abc"),
            (DelegatedAccessSettings.ReportContainerSetting, "http://stp01synthetic.blob.core.windows.net/reports"),
            (DelegatedAccessSettings.ReportContainerSetting, Container + "/monthly-usage.json"),
            (DelegatedAccessSettings.PersonaSetting, $$"""{"mallory":"{{Alice}}"}"""),
            (DelegatedAccessSettings.PersonaSetting, $$"""{"alice":"{{Alice}}","bob":"{{Alice}}"}"""),
            (DelegatedAccessSettings.PersonaSetting, "not json"),
        })
        {
            var values = ValidSettings();
            values[name] = value;
            var broken = Settings(values);
            Assert.True(broken.Enabled);
            Assert.NotNull(broken.ConfigurationError);
        }
    }

    [Fact]
    public async Task Disabled_or_broken_settings_never_call_downstream()
    {
        var credentials = new FakeCredentials();
        var clients = new FakeClients();
        var values = ValidSettings();
        values[DelegatedAccessSettings.ReportIdentitySetting] = AssertionIdentity;
        var broken = new DelegatedTools(Settings(values), credentials, clients);
        await Assert.ThrowsAsync<InvalidOperationException>(() => broken.WhoAmIAsync(null, UserHeaders(Alice), CancellationToken.None));
        await Assert.ThrowsAsync<InvalidOperationException>(() => broken.ReadReportAsAppAsync(Report(), CancellationToken.None));
        var disabled = new DelegatedTools(DelegatedAccessSettings.Disabled, credentials, clients);
        Assert.False(disabled.Enabled);
        await Assert.ThrowsAsync<InvalidOperationException>(() => disabled.ReadReportAsUserAsync(Report(), UserHeaders(Alice), CancellationToken.None));
        Assert.Empty(credentials.UserAssertions);
        Assert.Equal(0, credentials.AppCalls);
        Assert.Empty(clients.Calls);
    }

    [Fact]
    public async Task Whoami_uses_on_behalf_of_to_graph_and_returns_only_an_allowlisted_persona()
    {
        var credentials = new FakeCredentials();
        var clients = new FakeClients();
        var tools = new DelegatedTools(Settings(), credentials, clients);

        var alice = Parse(await tools.WhoAmIAsync(null, UserHeaders(Alice), CancellationToken.None));
        Assert.Equal("alice", alice.GetProperty("persona").GetString());
        Assert.True(alice.GetProperty("graphMatchesCaller").GetBoolean());
        Assert.Equal(["mcp-audience-assertion-for-" + Alice], credentials.UserAssertions);
        Assert.Equal([("user:" + Alice, "graph")], clients.Calls);
        Assert.Equal(0, credentials.AppCalls);
        var text = alice.GetRawText();
        Assert.DoesNotContain(Alice, text);
        Assert.DoesNotContain("mcp-audience-assertion", text);
        Assert.DoesNotContain("@", text);

        var stranger = Parse(await tools.WhoAmIAsync(null, UserHeaders(Stranger), CancellationToken.None));
        Assert.Equal("unlisted", stranger.GetProperty("persona").GetString());

        var mismatch = new DelegatedTools(Settings(), new FakeCredentials(), new FakeClients(graphObjectId: Bob));
        await Assert.ThrowsAsync<InvalidOperationException>(() => mismatch.WhoAmIAsync(null, UserHeaders(Alice), CancellationToken.None));
        await Assert.ThrowsAsync<ToolInputException>(() => tools.WhoAmIAsync(new Dictionary<string, object> { ["upn"] = "alice@contoso.example" }, UserHeaders(Alice), CancellationToken.None));
    }

    [Fact]
    public async Task Report_as_user_applies_the_callers_storage_role_alice_reads_bob_is_denied()
    {
        var credentials = new FakeCredentials();
        var clients = new FakeClients();
        var tools = new DelegatedTools(Settings(), credentials, clients);

        var alice = Parse(await tools.ReadReportAsUserAsync(Report(), UserHeaders(Alice), CancellationToken.None));
        Assert.Equal("as-user", alice.GetProperty("mode").GetString());
        Assert.Equal("alice", alice.GetProperty("persona").GetString());
        Assert.Equal(2, alice.GetProperty("rows").GetArrayLength());

        var denied = await Assert.ThrowsAsync<DownstreamAccessDeniedException>(() => tools.ReadReportAsUserAsync(Report(), UserHeaders(Bob), CancellationToken.None));
        Assert.Equal(403, denied.Status);
        Assert.DoesNotContain("assertion", denied.Message);

        Assert.All(clients.Calls, call => Assert.Equal(AzureDownstreamClients.StorageUserScope, call.Scope));
        Assert.Equal(0, credentials.AppCalls);
    }

    [Fact]
    public async Task Report_as_app_uses_only_the_managed_identity_and_returns_the_same_result_for_everyone()
    {
        var credentials = new FakeCredentials();
        var clients = new FakeClients();
        var tools = new DelegatedTools(Settings(), credentials, clients);

        var first = await tools.ReadReportAsAppAsync(Report(), CancellationToken.None);
        var second = await tools.ReadReportAsAppAsync(Report(), CancellationToken.None);
        Assert.Equal(first, second);
        var result = Parse(first);
        Assert.Equal("as-app", result.GetProperty("mode").GetString());
        Assert.Equal(JsonValueKind.Null, result.GetProperty("persona").ValueKind);
        Assert.Empty(credentials.UserAssertions);
        Assert.Equal(2, credentials.AppCalls);
        Assert.All(clients.Calls, call => Assert.Equal(("app", AzureDownstreamClients.StorageAppScope), call));
        await Assert.ThrowsAsync<ToolInputException>(() => tools.ReadReportAsAppAsync(new Dictionary<string, object> { ["report"] = "../other" }, CancellationToken.None));
    }

    [Fact]
    public async Task User_context_tools_reject_app_only_and_unexpected_callers_before_any_downstream_call()
    {
        var credentials = new FakeCredentials();
        var clients = new FakeClients();
        var tools = new DelegatedTools(Settings(), credentials, clients);
        var rejected = new[]
        {
            UserHeaders(Alice, scopes: ""),                         // app-only token: roles, no scp
            UserHeaders(Alice, idType: "app"),                       // explicit app identity type
            UserHeaders(Alice, scopes: "Tools.Other"),               // delegated, but not user_impersonation
            UserHeaders(Alice, tenant: "99999999-9999-4999-8999-999999999999"),
            UserHeaders(Alice, includeBearer: false),
            UserHeaders(Alice, principalId: Bob),
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) { ["Authorization"] = "Bearer x" },
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) { [CallerContext.PrincipalHeader] = "%%%not-base64%%%" },
        };
        foreach (var headers in rejected)
        {
            await Assert.ThrowsAsync<CallerRejectedException>(() => tools.WhoAmIAsync(null, headers, CancellationToken.None));
            await Assert.ThrowsAsync<CallerRejectedException>(() => tools.ReadReportAsUserAsync(Report(), headers, CancellationToken.None));
        }

        await Assert.ThrowsAsync<CallerRejectedException>(() => tools.WhoAmIAsync(null, null, CancellationToken.None));
        Assert.Empty(credentials.UserAssertions);
        Assert.Empty(clients.Calls);
    }

    [Theory]
    [InlineData("""{"report":"monthly-usage","source":"production","rows":[{"service":"workshop-api","requests":1,"errors":0}]}""")]
    [InlineData("""{"report":"monthly-usage","source":"synthetic","rows":[{"service":"workshop-api","requests":1,"errors":0,"owner":"someone"}]}""")]
    [InlineData("""{"report":"other","source":"synthetic","rows":[{"service":"workshop-api","requests":1,"errors":0}]}""")]
    [InlineData("""{"report":"monthly-usage","source":"synthetic","rows":[]}""")]
    [InlineData("not json")]
    public async Task Only_the_synthetic_report_shape_is_relayed(string blob)
    {
        var tools = new DelegatedTools(Settings(), new FakeCredentials(), new FakeClients(report: blob));
        await Assert.ThrowsAsync<InvalidOperationException>(() => tools.ReadReportAsAppAsync(Report(), CancellationToken.None));
    }

    [Fact]
    public async Task Audit_records_downstream_denial_and_rejected_callers_with_the_oid_only()
    {
        var logger = new RecordingLogger();
        var tools = new DelegatedTools(Settings(), new FakeCredentials(), new FakeClients());
        var bob = UserHeaders(Bob);
        await Assert.ThrowsAsync<DownstreamAccessDeniedException>(() => ToolAudit.RunAsync(logger, ToolCatalog.ReadReportAsUser, "inv-501",
            CallerContext.AuditLabel(bob), () => tools.ReadReportAsUserAsync(Report(), bob, CancellationToken.None)));
        var app = UserHeaders(Alice, scopes: "");
        await Assert.ThrowsAsync<CallerRejectedException>(() => ToolAudit.RunAsync(logger, ToolCatalog.WhoAmI, "inv-502",
            CallerContext.AuditLabel(app), () => tools.WhoAmIAsync(null, app, CancellationToken.None)));
        await ToolAudit.RunAsync(logger, ToolCatalog.ReadReportAsApp, "inv-503", CallerContext.AuditLabel(bob),
            () => tools.ReadReportAsAppAsync(Report(), CancellationToken.None));

        Assert.Contains("denied-downstream:403", logger.Lines[0]);
        Assert.Contains(Bob, logger.Lines[0]);
        Assert.Contains("rejected-caller", logger.Lines[1]);
        Assert.Contains("success", logger.Lines[2]);
        Assert.Equal("unknown", CallerContext.AuditLabel(new Dictionary<string, string> { [CallerContext.PrincipalIdHeader] = "not-a-guid" }));
        foreach (var line in logger.Lines)
        {
            Assert.DoesNotContain("assertion", line);
            Assert.DoesNotContain("Bearer", line);
            Assert.DoesNotContain("workshop-api", line);
            Assert.DoesNotContain("monthly-usage", line);
        }
    }

    private sealed class GraphHandler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        public List<HttpRequestMessage> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(request);
            return Task.FromResult(new HttpResponseMessage(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") });
        }
    }

    [Fact]
    public async Task Graph_client_sends_its_own_graph_token_and_asks_only_for_the_object_id()
    {
        var handler = new GraphHandler(HttpStatusCode.OK, $$"""{"id":"{{Alice.ToUpperInvariant()}}"}""");
        var clients = new AzureDownstreamClients(Settings(), handler);
        var credential = new FakeCredential("user:" + Alice);
        Assert.Equal(Alice, await clients.GetSignedInObjectIdAsync(credential, CancellationToken.None));
        var request = Assert.Single(handler.Requests);
        Assert.Equal("https://graph.microsoft.com/v1.0/me?$select=id", request.RequestUri!.ToString());
        Assert.Equal([AzureDownstreamClients.GraphScope], credential.Scopes);
        Assert.Equal("downstream-user:" + Alice + "-" + AzureDownstreamClients.GraphScope, request.Headers.Authorization!.Parameter);

        var forbidden = new AzureDownstreamClients(Settings(), new GraphHandler(HttpStatusCode.Forbidden, "{}"));
        var denied = await Assert.ThrowsAsync<DownstreamAccessDeniedException>(() => forbidden.GetSignedInObjectIdAsync(credential, CancellationToken.None));
        Assert.Equal(403, denied.Status);
    }

    [Fact]
    public async Task Storage_credential_is_narrowed_to_one_storage_scope_and_refuses_other_resources()
    {
        var inner = new FakeCredential("user:" + Alice);
        var scoped = new AzureDownstreamClients.ScopedCredential(inner, AzureDownstreamClients.StorageUserScope);
        await scoped.GetTokenAsync(new TokenRequestContext(["https://storage.azure.com/.default"]), CancellationToken.None);
        Assert.Equal([AzureDownstreamClients.StorageUserScope], inner.Scopes);
        await Assert.ThrowsAsync<InvalidOperationException>(async () =>
            await scoped.GetTokenAsync(new TokenRequestContext(["https://graph.microsoft.com/.default"]), CancellationToken.None));

        var blob = AzureDownstreamClients.CreateBlobClient(Settings(), inner, AzureDownstreamClients.StorageAppScope, "monthly-usage.json");
        Assert.Equal(Container + "/monthly-usage.json", blob.Uri.ToString());
        Assert.Throws<InvalidOperationException>(() => AzureDownstreamClients.CreateBlobClient(Settings(), inner, "https://graph.microsoft.com/.default", "x.json"));
        Assert.Throws<InvalidOperationException>(() => AzureDownstreamClients.CreateBlobClient(DelegatedAccessSettings.Disabled, inner, AzureDownstreamClients.StorageAppScope, "x.json"));
    }

    [Fact]
    public void Real_credentials_are_secretless_and_never_fall_back_to_a_developer_identity()
    {
        var disabled = new ManagedIdentityDownstreamCredentials(DelegatedAccessSettings.Disabled);
        Assert.Throws<InvalidOperationException>(() => disabled.ForApp());
        var caller = CallerContext.ForUser(UserHeaders(Alice), Tenant);
        Assert.Throws<InvalidOperationException>(() => disabled.ForUser(caller));

        var enabled = new ManagedIdentityDownstreamCredentials(Settings());
        Assert.IsType<OnBehalfOfCredential>(enabled.ForUser(caller));
        Assert.IsType<ManagedIdentityCredential>(enabled.ForApp());
        Assert.Equal("api://AzureADTokenExchange/.default", ManagedIdentityDownstreamCredentials.TokenExchangeScope);
        Assert.Equal($"caller {Alice}", caller.ToString());
    }
}

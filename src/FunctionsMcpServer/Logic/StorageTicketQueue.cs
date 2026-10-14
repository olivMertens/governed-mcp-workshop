using Azure.Identity;
using Azure.Storage.Queues;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// Sends synthetic tickets with the app's user-assigned managed identity. No connection string or key.
/// Settings (set by Terraform): TICKET_QUEUE_SERVICE_URI, TICKET_QUEUE_NAME, WORKSHOP_IDENTITY_CLIENT_ID.
/// </summary>
public sealed class StorageTicketQueue : ITicketQueue
{
    private readonly Lazy<QueueClient> client;

    public StorageTicketQueue(Func<string, string?> settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        client = new Lazy<QueueClient>(() => Create(settings), LazyThreadSafetyMode.ExecutionAndPublication);
    }

    public Task SendAsync(string message, CancellationToken cancellationToken) =>
        client.Value.SendMessageAsync(message, cancellationToken: cancellationToken);

    internal static QueueClient Create(Func<string, string?> settings)
    {
        var serviceUri = settings("TICKET_QUEUE_SERVICE_URI");
        var queueName = settings("TICKET_QUEUE_NAME");
        var clientId = settings("WORKSHOP_IDENTITY_CLIENT_ID");
        if (string.IsNullOrWhiteSpace(serviceUri) || string.IsNullOrWhiteSpace(queueName) || string.IsNullOrWhiteSpace(clientId))
        {
            throw new InvalidOperationException("The ticket queue is not configured. Deploy the module 02 infrastructure first.");
        }

        if (!Uri.TryCreate(serviceUri, UriKind.Absolute, out var service) || service.Scheme != Uri.UriSchemeHttps ||
            !string.IsNullOrEmpty(service.UserInfo) || !string.IsNullOrEmpty(service.Query))
        {
            throw new InvalidOperationException("TICKET_QUEUE_SERVICE_URI must be an HTTPS endpoint without credentials or query string.");
        }

        var queueUri = new Uri(service, queueName);
        var credential = new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(clientId));
        return new QueueClient(queueUri, credential, new QueueClientOptions { MessageEncoding = QueueMessageEncoding.Base64 });
    }
}

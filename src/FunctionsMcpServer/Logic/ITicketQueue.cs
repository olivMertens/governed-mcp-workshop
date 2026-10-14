namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// The only write side effect of the level 0 server: one synthetic message in one Storage queue.
/// </summary>
public interface ITicketQueue
{
    Task SendAsync(string message, CancellationToken cancellationToken);
}

using System.Text.Json;

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// A rejected tool input. Messages are fixed text and never echo caller-supplied values.
/// </summary>
public sealed class ToolInputException(string message) : Exception(message);

/// <summary>
/// Strict argument reader: every tool declares its exact argument shape; anything else is refused.
/// </summary>
internal static class ToolArguments
{
    public static void RequireOnly(IReadOnlyDictionary<string, object>? arguments, params string[] allowed)
    {
        if (arguments is null)
        {
            return;
        }

        foreach (var key in arguments.Keys)
        {
            if (!allowed.Contains(key, StringComparer.Ordinal))
            {
                throw new ToolInputException("Unexpected argument. This tool accepts only its documented arguments.");
            }
        }
    }

    public static string RequireString(IReadOnlyDictionary<string, object>? arguments, string name)
    {
        if (arguments is null || !arguments.TryGetValue(name, out var value) || value is null)
        {
            throw new ToolInputException($"Missing required argument '{name}'.");
        }

        return value switch
        {
            string text => text,
            JsonElement { ValueKind: JsonValueKind.String } element => element.GetString()!,
            _ => throw new ToolInputException($"Argument '{name}' must be a string."),
        };
    }

    public static string RequireOneOf(IReadOnlyDictionary<string, object>? arguments, string name, IReadOnlyCollection<string> allowed)
    {
        var value = RequireString(arguments, name);
        if (!allowed.Contains(value, StringComparer.Ordinal))
        {
            throw new ToolInputException($"Unsupported value for '{name}'. Use one of: {string.Join(", ", allowed)}.");
        }

        return value;
    }
}

namespace Workshop.FunctionsMcp.Logic;

/// <summary>
/// Tool names, descriptions and explicit JSON input schemas. Schemas are hints for clients;
/// <see cref="ToolLogic"/> enforces the same shape on the server.
/// </summary>
public static class ToolCatalog
{
    public const string GetServiceHealth = "get_service_health";
    public const string CreateTicket = "create_ticket";
    public const string WhoAmI = "whoami";
    public const string ReadReportAsUser = "read_report_as_user";
    public const string ReadReportAsApp = "read_report_as_app";

    public const string GetServiceHealthDescription =
        "Read fixed synthetic health data for a workshop service. No real monitoring.";
    public const string CreateTicketDescription =
        "WRITE: queue one synthetic ticket in the workshop Storage queue. Synthetic text only. Level 0 checks no identity or role.";
    public const string WhoAmIDescription =
        "Who am I? Levels 0-2: synthetic explanation, no downstream call. Level 3 (module 05): On-Behalf-Of to Microsoft Graph /me; returns only an allowlisted synthetic persona label, never a name or email.";
    public const string ReadReportAsUserDescription =
        "Read the synthetic report as the signed-in user. Levels 0-2: labeled demonstration. Level 3 (module 05): On-Behalf-Of to Azure Storage, so the caller's own Storage role applies.";
    public const string ReadReportAsAppDescription =
        "Read the synthetic report as the application. Levels 0-2: labeled demonstration. Level 3 (module 05): the app-only managed identity reads Azure Storage, same result for every caller.";

    public static IReadOnlyList<string> All { get; } =
        [GetServiceHealth, CreateTicket, WhoAmI, ReadReportAsUser, ReadReportAsApp];

    public const string GetServiceHealthSchema = """
        {
          "type": "object",
          "properties": {
            "service": { "type": "string", "enum": ["workshop-api", "ticket-queue"], "description": "Synthetic service name." }
          },
          "required": ["service"],
          "additionalProperties": false
        }
        """;

    public const string CreateTicketSchema = """
        {
          "type": "object",
          "properties": {
            "service": { "type": "string", "enum": ["workshop-api", "ticket-queue"], "description": "Synthetic service name." },
            "severity": { "type": "string", "enum": ["low", "medium", "high"], "description": "Synthetic severity." },
            "summary": { "type": "string", "minLength": 10, "maxLength": 120, "description": "Synthetic summary: letters, digits, spaces and . , : ; ( ) ' - only." }
          },
          "required": ["service", "severity", "summary"],
          "additionalProperties": false
        }
        """;

    public const string NoArgumentsSchema = """
        {
          "type": "object",
          "properties": {},
          "additionalProperties": false
        }
        """;

    public const string ReportSchema = """
        {
          "type": "object",
          "properties": {
            "report": { "type": "string", "enum": ["monthly-usage"], "description": "Synthetic report name." }
          },
          "required": ["report"],
          "additionalProperties": false
        }
        """;
}

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
        "Synthetic demonstration: explains that a function key identifies no user. No Microsoft Graph call at level 0.";
    public const string ReadReportAsUserDescription =
        "Synthetic demonstration of a user-context report read. No downstream call at level 0.";
    public const string ReadReportAsAppDescription =
        "Synthetic demonstration of an app-only report read. No downstream call at level 0.";

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

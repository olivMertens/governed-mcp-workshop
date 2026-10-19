# The workshop MCP server: what runs and what it answers

[Français](fr/MCP-SERVER.md)

One MCP server runs through the whole workshop. Each module puts a new control **in front of it** or changes **who
reads the data behind it**. This page shows what the server is, how to reach it at each level, and its **real
responses**, captured on 2026-10-19 in the author's test tenant. Names are pseudonymised and IDs replaced by zeros.

## What runs

| | |
|---|---|
| Code | [src/FunctionsMcpServer](../src/FunctionsMcpServer) (.NET, Azure Functions MCP extension) |
| Name and version | `workshop-open-mcp` 0.2.0 |
| Endpoint | `https://func-mcp-<prefix>-<suffix>.azurewebsites.net/runtime/webhooks/mcp` |
| Transport | Streamable HTTP: one `POST` per JSON-RPC message, the answer comes back as `text/event-stream` |
| Data | Synthetic only: two services (`workshop-api`, `ticket-queue`) and one report (`monthly-usage`) |
| Tools | Five: four read tools and one write tool |

On 2026-10-19, the author's test tenant runs the **module 03** state: the module 02 server, protected by Microsoft Entra
built-in authentication. The module 04 gateway was cleaned up, and the module 05 mode is off.

## How you reach it at each level

![One MCP server, four levels: what you send at each level, who refuses, and when the answers change](../assets/screenshots/diagram-02-server-levels-en.png)

| Level | What you send | Without it | What changes in the answers |
|---|---|---|---|
| 02 Open server | `x-functions-key` header | HTTP 401 | Nothing: level `0-open` |
| 03 Entra identity | `Authorization: Bearer` token for the server's audience | HTTP 401 and a `WWW-Authenticate` challenge | Nothing yet (see the question below) |
| 04 Gateway | The same token, sent to API Management | HTTP 401; HTTP 403 without the right role | Nothing; the gateway filters before the server |
| 05 Delegated vs app-only | The same token | Same | `whoami` and `read_report_as_*` call Graph and Storage for real |

## The five tools

| Tool | Kind | Input | Answer at levels 0 to 2 | Answer at level 3 (module 05) |
|---|---|---|---|---|
| `get_service_health` | Read | `service`: `workshop-api` or `ticket-queue` | `healthy` or `degraded`, fixed | Same |
| `create_ticket` | **Write** | `service`, `severity` (`low`, `medium`, `high`), `summary` (10 to 120 plain characters) | Queues one synthetic ticket, returns its ID and a **risk warning** | Same tool; module 04 requires the `Tools.Write` role |
| `whoami` | Read | none | `caller: unknown`, no downstream call | Persona label from Microsoft Graph, through On-Behalf-Of |
| `read_report_as_user` | Read | `report`: `monthly-usage` | Labelled demonstration, no downstream call | Reads Storage **as the user**: the user's own role decides |
| `read_report_as_app` | Read | `report`: `monthly-usage` | Labelled demonstration, no downstream call | Reads Storage **as the app**: the same result for everyone |

## Real exchange, signed in as Alice (module 03 state)

**1. Without a token.** The server refuses, and tells the client where to get a token:

```text
HTTP 401
WWW-Authenticate: Bearer ... resource_metadata="https://func-mcp-p01-<suffix>.azurewebsites.net/.well-known/oauth-protected-resource/runtime/webhooks/mcp", scope="api://00000000-0000-0000-0000-000000000000/user_impersonation"
```

The metadata document (Protected Resource Metadata, **Preview** in Functions) names the authority and the scope:

```json
{"resource":"https://func-mcp-p01-<suffix>.azurewebsites.net",
 "authorization_servers":["https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"],
 "scopes_supported":["api://00000000-0000-0000-0000-000000000000/user_impersonation"]}
```

**2. `initialize`** with Alice's token: HTTP 200. The server introduces itself:

```text
event: message
data: {"result":{"protocolVersion":"2025-06-18",
  "capabilities":{"logging":{},"prompts":{},"resources":{},"tools":{}},
  "serverInfo":{"name":"workshop-open-mcp","version":"0.2.0"},
  "instructions":"Workshop level 0. Synthetic data only. Never send real names, tickets, tokens or secrets."},
  "id":1,"jsonrpc":"2.0"}
```

**3. `tools/list`**: HTTP 200, the five tools, each with its description and input schema (excerpt):

```json
{"name":"get_service_health",
 "description":"Read fixed synthetic health data for a workshop service. No real monitoring.",
 "inputSchema":{"type":"object",
   "properties":{"service":{"type":"string","enum":["workshop-api","ticket-queue"]}},
   "required":["service"],"additionalProperties":false}}
```

**4. `tools/call`.** The result is **text** inside `content`. Here that text is JSON:

| Call | Real answer (the `text` field, decoded) |
|---|---|
| `get_service_health` `{"service":"workshop-api"}` | `{"service":"workshop-api","status":"healthy","source":"synthetic","level":"0-open"}` |
| `get_service_health` `{"service":"ticket-queue"}` | `{"service":"ticket-queue","status":"degraded","source":"synthetic","level":"0-open"}` |
| `get_service_health` `{"service":"payroll"}` | `An error occurred invoking 'get_service_health'.` with `"isError": true` |
| `whoami` `{}` | `{"caller":"unknown","source":"synthetic-demonstration","level":"0-open","downstreamCall":"none","explanation":"A function key identifies no user. Module 03 adds Microsoft Entra sign-in; module 05 adds On-Behalf-Of to Microsoft Graph."}` |
| `read_report_as_user` `{"report":"monthly-usage"}` | `{"report":"monthly-usage","mode":"as-user (demonstration)","source":"synthetic-demonstration","level":"0-open","downstreamCall":"none","authorization":"Not evaluated: ...","rows":[{"service":"workshop-api","requests":1200,"errors":3},{"service":"ticket-queue","requests":340,"errors":12}]}` |
| `read_report_as_app` `{"report":"monthly-usage"}` | Same rows, `"mode":"as-app (demonstration)"` |

The full envelope of one call:

```text
event: message
data: {"result":{"content":[{"type":"text","text":"{\"service\":\"workshop-api\",\"status\":\"healthy\",\"source\":\"synthetic\",\"level\":\"0-open\"}"}]},"id":3,"jsonrpc":"2.0"}
```

Every call took about 1 second (Flex Consumption, warm instance).

> **What it means for you:** a wrong argument gets a short, generic error with `isError: true`, never a stack trace or
> internal detail. The HTTP status stays 200: in MCP, a **tool** error is part of the answer, not a transport error.

**Question:** Alice is signed in with Microsoft Entra, so why does `whoami` still say `caller: unknown` and `level: 0-open`?

<details>
<summary>Show answer</summary>

Because authentication runs **in front of** the code. In module 03, the Functions platform checks the token before the
request reaches the server, and the server code does not change. The tools keep their level 0 answers until module 05
turns on the code that reads the caller and calls Graph and Storage. The label describes the tool code, not the door.

</details>

`create_ticket` was not called here: it writes. In module 02, its answer looks like this (the ID changes every call):

```json
{"ticketId":"TCK-1A2B3C4D","service":"ticket-queue","severity":"low","status":"queued","source":"synthetic","level":"0-open",
 "warning":"Level 0: anyone holding the function key can call this write tool. No user identity or role was checked."}
```

## At level 3 (module 05)

With the module 05 mode on, the same calls answer with the real identity path. Module 05 shows the full results:
[module 05, what you should see](../modules/05-delegated-and-app-only/README.md#what-you-should-see).

| Tool | Answer shape at level 3 |
|---|---|
| `whoami` | `persona` (for example `alice`), `identity: signed-in user (On-Behalf-Of)`, `graphMatchesCaller: true`; never a name or an email |
| `read_report_as_user` | `mode: as-user`, the rows **if the user's own Storage role allows it**; Bob gets `isError: true` |
| `read_report_as_app` | `mode: as-app`, the same rows for Alice and Bob: the managed identity's role decides |

## Try it yourself

Use an MCP client, not a browser: VS Code or the Inspector signs you in through the metadata above. See
[Try your MCP](PRACTICE.md). Each module's validator also makes these calls for you and prints one `PASS` line per check.

## Sources

- [Model Context Protocol: Streamable HTTP transport](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports)
- [Model Context Protocol: tools, results and `isError`](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)
- [Azure Functions MCP extension](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp)
- [Protected Resource Metadata for App Service and Functions (Preview)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp)

Last verified: 2026-10-19.

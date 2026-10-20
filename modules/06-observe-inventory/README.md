# 06 - Observe and inventory (level 4)

[Français](README.fr.md)

## Goal

Your MCP server is now protected by Microsoft Entra ID (module 03), reachable only through Azure API Management
(APIM, module 04), and it calls downstream data with the right identity (module 05).
One question remains: **can you see what happens, and can other teams find the server?**

This module answers that question in two separate parts:

- **Observe:** see which tool was called, by which caller, when, with which status and how long it took.
  You read this metadata in Application Insights with a Kusto Query Language (KQL) query.
- **Inventory:** list the server in a catalog, so other teams know it exists, who owns it and where to call it.
  You register it in Azure API Center (**Preview**). An administrator can also list it in the Microsoft 365 admin
  center as a bring-your-own (BYO) MCP server (**Preview**).

You deploy nothing new. You read the telemetry, register the server, and learn what each piece of evidence proves
(a log line, an inventory entry, a BYO listing) and what it does not prove.

## Why it matters

A server that nobody can see is not governed. Without metadata, you cannot answer "who used the write tool yesterday?".
Without an inventory, teams build duplicate servers or use unknown ones ("shadow MCP").

Two traps to avoid:

- **Logging too much.** Storing prompts, tool arguments or tool results leaks data. This workshop logs metadata only.
- **Trusting too much.** A log line or a catalog entry is evidence, not a control. HTTP 200 does not prove that the tool
  succeeded, and an inventory entry authorizes nobody.

> [!WARNING]
> **Log rules for this module:** zero body bytes, no tokens, no prompts and no tool arguments or results in any log, query, workbook, ticket or slide. Log metadata only: operation, tool name, status, duration and error type.

## What you deploy

This module deploys **no new Azure resources**. It reuses the API Management instance and the Application Insights component from earlier modules and adds:

| Item | Type | Where | Status |
|---|---|---|---|
| MCP traffic query | KQL file (`queries/mcp-traffic.kql`) | This module folder | Stable |
| Tool-call spans and their query | OpenTelemetry in the server code, KQL file (`queries/tool-spans.kql`) | Published with the server in module 02; this module folder | Stable (MCP conventions: Development) |
| API Center MCP server registration | Asset in an API center | Azure portal (manual steps) | **Preview** |
| BYO MCP server listing | Entry in the Microsoft 365 admin center | Microsoft 365 admin center | **Preview** |
| Agent 365 with API Management (demo only) | Optional talk track, see "Go further" | Not built by participants | **Preview** |

No Terraform is used. The module has no `infra/` folder because it adds no infrastructure. Two steps touch tenant-level settings (the BYO listing and any Agent 365 policy). Those are performed by a tenant administrator, never by a participant.

## Prerequisites and required roles

- Modules 00 to 05 completed, with the APIM MCP endpoint answering requests.
- PowerShell 7.4 or later (`pwsh`) and, for the Linux or macOS steps, bash.
- Azure CLI, signed in to an approved non-production subscription that you own. Do not run these steps in a participant tenant from the presenter side.
- **Reader** on the Application Insights component, to run KQL queries.
- For API Center: a role that allows registering assets in the API center. Confirm the exact built-in role name in the Azure RBAC built-in roles page before you assign it. This module does not assume one.
- For the BYO listing: an IT administrator in the Microsoft 365 admin center. The participant does not need this role and must not request it.
- For Agent 365 (optional demo): a tenant administrator holding the Agent 365 MCP Gateway Policy Operator role. Never granted to a participant.

## Steps

### Read the three separate flows





**Build it step by step.** Select **Next** to add one piece at a time; the full diagram follows.

```reveal
{
  "title": "What the platform records",
  "audience": "attendee",
  "width": 760,
  "height": 380,
  "lanes": [
    {"x": 8, "width": 232, "label": "Calls"},
    {"x": 264, "width": 232, "label": "Telemetry"},
    {"x": 520, "width": 232, "label": "Inventory"}
  ],
  "nodes": [
    {"id":"apim","step":0,"x":30,"y":44,"width":188,"icon":"apim","title":"API Management","detail":["every MCP call"]},
    {"id":"fn","step":0,"x":30,"y":164,"width":188,"icon":"functions","title":"MCP server","detail":["one span per tool"]},
    {"id":"ai","step":1,"x":286,"y":44,"width":188,"icon":"insights","title":"App Insights","detail":["metadata only","zero body bytes"]},
    {"id":"kql","step":2,"x":286,"y":164,"width":188,"title":"KQL queries","detail":["mcp-traffic.kql","tool-spans.kql"]},
    {"id":"trace","step":3,"tone":"governed","x":286,"y":284,"width":188,"title":"One call, one trace","detail":["operation ID","gateway → tool → 403"]},
    {"id":"apic","step":4,"tone":"preview","x":542,"y":44,"width":188,"icon":"api-center","title":"API Center","detail":["Preview","gateway URL only"]},
    {"id":"byo","step":5,"tone":"preview","x":542,"y":164,"width":188,"icon":"microsoft","title":"Microsoft 365","detail":["BYO MCP listing","Preview"]}
  ],
  "edges": [
    {"from":"apim","to":"fn","step":0,"label":"private"},
    {"from":"apim","to":"ai","step":1,"label":"requests"},
    {"from":"fn","to":"ai","step":1,"label":"spans"},
    {"from":"kql","to":"ai","step":2,"label":"reads"},
    {"from":"fn","to":"trace","step":3,"tone":"governed","label":"span tree"},
    {"from":"apim","to":"apic","step":4,"tone":"preview","fromSide":"top","toSide":"top","bend":26,"label":"gateway URL"}
  ],
  "steps": [
    {"title": "Calls go through the gateway", "simple": "Every MCP call passes API Management, then reaches the server privately.", "say": "Nothing changes for the client. This module only reads what the platform already records."},
    {"title": "Metadata goes to Application Insights", "simple": "The gateway logs each request and the server adds one span per tool call. No content, no token.", "say": "Logged: tool name, caller object ID, status, latency, correlation ID. Never logged: prompts, arguments, results, tokens."},
    {"title": "Ask with KQL", "simple": "Two saved queries list the MCP traffic and the tool calls of the last 24 hours.", "say": "Run them in the portal (**Logs**) or from your terminal. An empty result proves neither success nor absence of activity."},
    {"title": "Follow one call", "simple": "One operation ID links the gateway, the tool and the downstream call that refused Bob.", "say": "In **Search**, paste the operation ID, then open **View timeline**: the red rows show where the call stopped."},
    {"title": "Register the gateway (Preview)", "simple": "API Center lists the server with the gateway URL, never the backend address.", "say": "API Center inventory is **Preview**. Registration authorizes nothing: the gateway still decides."},
    {"title": "List it in Microsoft 365 (Preview)", "simple": "An administrator can list the same gateway URL in the Microsoft 365 admin center.", "say": "The bring-your-own MCP listing is **Preview** and belongs to a tenant administrator, never to a participant."}
  ]
}
```

![Runtime requests go through API Management; metadata goes to Application Insights; API Center only inventories the gateway.](../../assets/architecture/06.en.svg)

> [!NOTE]
> Application Insights is not an authorization gate. API Center is not a runtime hop.
> Neither registration nor a successful HTTP status proves that a tool completed.

### What can you actually trace?

Kusto Query Language (KQL) queries read stored telemetry, not the agent's reasoning.

| Evidence | Available here | Limit |
|---|---|---|
| Time, operation, HTTP status, latency | Selected by the supplied query | Ingestion delay, sampling and the 200-row limit mean this is not a complete audit |
| Tool name and error type | Selected when emitted by MCP diagnostics | A missing field does not mean no tool ran |
| Caller object ID and correlation | Module 04 policy emits `caller-oid` in `workshop-mcp-gateway` traces; the tool span records `workshop.caller`; one operation ID links gateway, Function and downstream calls (Step 3b) | The traffic query does not select caller identity; use the span query |
| Downstream refusal | The tool span (`error.type = tool_error`) and the refused downstream call (Step 3b) | HTTP 200 can contain `isError: true`; HTTP success is not tool success |
| Human approval, prompt, arguments, result | Not collected here | Do not claim the gateway proves approval or records the conversation |

App-only downstream logs identify the application, not Alice or Bob.
OBO can preserve user identity, but downstream audit still needs its own configuration and permissions.
Correlate available metadata across services; never add tokens or bodies to fill a gap.

**Question:** a request returned HTTP 200. Does that prove Bob read the report?

<details>
<summary>Show answer</summary>

No. Storage can refuse Bob and the server can return an MCP tool error inside HTTP 200.
Check the client result and the available downstream evidence. An empty log query proves neither success nor absence of activity.

</details>

### Low-code track (portal and simple commands)

Steps 1, 2 and 5 are the same in both tracks, and steps 3 and 4 already give the portal path. Only their terminal lines
read Terraform outputs: in the low-code track, use the names below instead.

```powershell
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
$id = "$($p.participant_prefix)lc"; $sfx = $p.resource_suffix.Substring(0, 10)
$group = "rg-mcp-$id-$sfx"; $ai = "appi-mcp-$id-$sfx"; $apim = "apim-mcp-$id-$sfx"; $apic = "apic-mcp-$id-$sfx"
# Step 3: the same KQL file, on your Application Insights component.
az monitor app-insights query --app $ai --resource-group $group --offset 24h `
  --analytics-query '@modules/06-observe-inventory/queries/mcp-traffic.kql' --query 'tables[0].rows' -o json
# Step 4: the API center (Free plan) and its gateway environment; the URL to paste under Remotes.
az apic create --resource-group $group --name $apic --location (az group show --name $group --query location --output tsv)
az apic environment create --resource-group $group --service-name $apic --environment-id gateway --title "API Management gateway" --type development
"https://$apim.azure-api.net/workshop-mcp/mcp"
```

> **Real result** — low-code track, 2026-10-20, author's test tenant. 7 of the 102 rows from the modules 04 and 05 checks,
> then the API center (`"sku": { "name": "Free" }`) and the `gateway` environment.
>
> ```text
> [ "2026-10-20T10:27:38.6207559Z", "tools/call", "create_ticket", "200", "True", 442.5, "", "" ]
> [ "2026-10-20T10:27:51.7341172Z", "tools/call", "create_ticket", "403", "False", 3.3805, "", "" ]
> [ "2026-10-20T10:32:02.3050838Z", "tools/call", "list_tickets", "200", "True", 51.4503, "", "" ]
> [ "2026-10-20T10:46:54.2387598Z", "tools/call", "whoami", "200", "True", 1566.4731, "", "" ]
> [ "2026-10-20T10:46:56.2391415Z", "tools/call", "read_report_as_user", "200", "True", 569.971, "", "" ]
> [ "2026-10-20T10:46:57.2408390Z", "tools/call", "read_report_as_app", "200", "True", 258.4664, "", "" ]
> [ "2026-10-20T10:47:08.3307894Z", "tools/call", "read_report_as_user", "200", "True", 292.3766, "", "" ]
> ```
>
> **What it means for you:** the same metadata as in the full-code track, because the gateway policies are the same. Both
> `read_report_as_user` rows show HTTP 200, but one of them is Bob's: Storage refused him inside the tool result. HTTP
> success is not tool success. Bob's `create_ticket` (HTTP 403, 3 ms) never reached the Function.

### Step 1 - Run the offline checks

Confirm the module files, the KQL query and the logging rules before you query anything.

PowerShell:

```powershell
pwsh ./modules/06-observe-inventory/validate.ps1 -Offline
```

> **Real result** — offline validator, author's workstation, 2026-10-17. Names and IDs withheld.
>
> ```text
> PASS file exists: README.md (offline)
> PASS file exists: README.fr.md (offline)
> PASS file exists: validate.ps1 (offline)
> PASS file exists: validate.sh (offline)
> PASS file exists: cleanup.ps1 (offline)
> PASS file exists: cleanup.sh (offline)
> PASS file exists: queries/mcp-traffic.kql (offline)
> PASS README sections present and in order (offline)
> PASS README.fr.md has the same section count (offline)
> PASS Steps give PowerShell before bash (offline)
> PASS Preview label on API Center, BYO and Agent 365 (offline)
> PASS KQL selects no body, argument, result or token fields (offline)
> PASS KQL filters on api.type Mcp, pass-through-mcp and mcp-backend (offline)
> PASS README does not instruct enabling payload logging (offline)
> PASS no secrets or tokens in module files (offline)
> PASS only placeholder GUIDs in module files (offline)
> PASS PROGRESS row 06 claims validated only with a date and a live run (offline)
> PASS docs/sources.md has module 06 entries with last-verified dates (offline)
> PASS no infra folder (no Azure resources added) (offline)
> PASS README states the log rules (offline)
> RESULT: all offline checks passed
> ```
>
> **What it means for you:** the module files exist and the KQL query reads metadata only. Nothing in Azure was checked yet; exit code 0 means every offline rule passed.

bash:

```bash
./modules/06-observe-inventory/validate.sh --offline
```

> **Expected result** — the same PASS/FAIL lines as the PowerShell run above.

### Step 2 - Confirm payload logging is off

In the APIM instance, confirm that payload logging for the MCP API is off. Do not turn on `gen_ai.tool.call.arguments` or `gen_ai.tool.call.result` capture for this workshop.

### Step 3 - Query MCP traffic in Application Insights

Open `modules/06-observe-inventory/queries/mcp-traffic.kql` and run it in the Application Insights **Logs** blade of the component that API Management writes to.

The exact query, ready to paste:

```kql
// Module 06 - MCP traffic in Application Insights (synthetic, metadata only).
// Reads only request metadata. Never select request or response bodies,
// tool arguments, tool results, tokens or prompts.
// Single-quoted strings keep the query intact when PowerShell passes it to the Azure CLI on Windows.
requests
| where timestamp > ago(24h)
| extend apiType = tostring(customDimensions['api.type'])
// Microsoft Learn lists 'Mcp'. Verified live 2026-10-20: an existing MCP server behind a backend (part A, passthrough)
// logs 'pass-through-mcp'; a REST API exposed as an MCP server (part B) logs 'mcp-backend'.
| where apiType in ('Mcp', 'pass-through-mcp', 'mcp-backend')
| extend
    operation = tostring(customDimensions['gen_ai.operation.name']),
    toolName  = tostring(customDimensions['gen_ai.tool.name']),
    errorType = tostring(customDimensions['error.type']),
    clientApp = tostring(customDimensions['user_agent.name'])
| project timestamp, operation, toolName, resultCode, success, duration, errorType, clientApp
| order by timestamp desc
| take 200
```

The query uses the Application Insights table names (`requests`, `customDimensions`): run it in the scope of that
Application Insights component, not on its Log Analytics workspace, where the same data is in `AppRequests`.

**In the Azure portal:** search for `appi-mcp-<prefix>-<suffix>` (your Application Insights resource, printed by the first
line of the command below), open it, select **Monitoring → Logs**, switch the editor to **KQL mode**, paste the query and
select **Run**.

**Or from your terminal.** PowerShell, from the repository root (Azure CLI `application-insights` extension: `az extension add --name application-insights`):

```powershell
$ai = (terraform -chdir=infra/workload output -json resource_names | ConvertFrom-Json).application_insights
$group = terraform -chdir=infra/workload output -raw resource_group_name
# '@file' lets the Azure CLI read the query file itself: on Windows a multi-line argument is cut at its first line.
az monitor app-insights query --app $ai --resource-group $group --offset 24h `
  --analytics-query '@modules/06-observe-inventory/queries/mcp-traffic.kql' --query 'tables[0].rows' -o json
```

> **Real result** — gateway traffic from the module 04 operator checks, 2026-10-18, author's test tenant. No persona traffic yet. Names and IDs withheld.
>
> ```text
> [
>   [
>     "2026-10-18T14:38:02.4928994Z",
>     "initialize",
>     "",
>     "401",
>     "False",
>     690.08,
>     "",
>     "workshop-validator"
>   ],
>   [
>     "2026-10-18T14:37:54.7916733Z",
>     "initialize",
>     "",
>     "401",
>     "False",
>     1221.7192,
>     "",
>     "workshop-validator"
>   ]
> ]
> ```
>
> **Real result** — persona traffic from modules 04 and 05 (Alice and Bob), 2026-10-20, author's test tenant. 6 of the
> 134 rows; columns follow the query: timestamp, operation, toolName, resultCode, success, duration (ms), errorType, clientApp.
>
> ```text
> [
>   [ "2026-10-20T05:20:15.1801351Z", "tools/call", "create_ticket", "200", "True", 597.982, "", "" ],
>   [ "2026-10-20T05:31:02.2715503Z", "tools/call", "create_ticket", "403", "False", 3.6035, "", "" ],
>   [ "2026-10-20T06:20:18.3449395Z", "tools/call", "whoami", "200", "True", 1169.1348, "", "" ],
>   [ "2026-10-20T06:20:19.856923Z", "tools/call", "read_report_as_user", "200", "True", 337.9462, "", "" ],
>   [ "2026-10-20T05:31:21.3260289Z", "ping", "", "429", "False", 1.8206, "", "" ],
>   [ "2026-10-20T05:38:27.8248234Z", "tools/call", "list_tickets", "200", "True", 10.8423, "", "" ]
> ]
> ```
>
> **What it means for you:** each row is metadata only: no body, token, prompt, argument or result. Alice's `create_ticket`
> took about 600 ms because the Function ran it; Bob's took 3.6 ms and the throttled `ping` 1.8 ms: the gateway refused them
> (HTTP 403 and 429) without calling the Function. The query keeps three `api.type` values: Microsoft Learn lists `Mcp`; this
> workshop's existing server (part A) logs `pass-through-mcp`, and the REST API exposed as MCP (part B) logs `mcp-backend`.
> An empty list is possible when there was no MCP traffic in the last 24 hours or ingestion is still delayed; it proves
> neither success nor absence of activity.

The same query in the portal: Application Insights component → **Logs**, switch to **KQL mode**, paste the query, then
**Run** (real capture, 2026-10-19, author's test tenant; names pseudonymised). Frame 1 marks the filter that keeps only MCP
traffic; frame 2 marks the rows: operation, status, duration and client name, and nothing else.

![Real capture: Application Insights Logs in KQL mode with the MCP filter and two metadata-only rows, initialize refused with HTTP 401](../../assets/screenshots/azure-06-kql-logs.png)

bash:

```bash
ai=$(terraform -chdir=infra/workload output -json resource_names | jq -r .application_insights); group=$(terraform -chdir=infra/workload output -raw resource_group_name)
az monitor app-insights query --app "$ai" --resource-group "$group" --offset 24h \
  --analytics-query '@modules/06-observe-inventory/queries/mcp-traffic.kql' --query 'tables[0].rows' -o json
```

> **Expected result** — the same list as the PowerShell run above.
The query reads only metadata: operation name, tool name, status, duration and error type. It never reads request or response bodies.

### Optional - Ask the Observability Agent the same question

The Logs page has an **Agent** toggle that opens the Azure Copilot Observability Agent. You ask in plain English; the
agent writes a KQL query, runs it on this Application Insights component, and explains the result. No extra resource is
needed for chat. If the toggle is missing, your tenant may not offer Azure Copilot: skip this step, the module does not
depend on it.

1. In the same Application Insights component, open **Logs**, then switch **Agent** on (top right).
2. Type this question:

   ```prompt
   Show MCP requests from the last 7 days where customDimensions api.type is Mcp, pass-through-mcp or mcp-backend: timestamp, operation (gen_ai.operation.name), resultCode, success, duration and client (user_agent.name). Metadata only, no request or response bodies.
   ```

3. Expand **Reasoned for ...** to see the query the agent ran. Compare it with `queries/mcp-traffic.kql`.

> **Real result** — Observability Agent, 2026-10-19, author's test tenant. Names pseudonymised, IDs replaced.
> Frame 1 is the question; frame 2 is the table the agent returned: the same two `initialize` rows refused with HTTP 401
> as the KQL file.
>
> **What it means for you:** the agent reached the same answer because the logs hold only metadata. It can only find what
> was logged: no prompt, token or body exists to leak. The chat is temporary and scoped to this one resource.

![Real capture: Observability Agent chat in Logs, with the question and the two metadata-only rows it returned](../../assets/screenshots/azure-06-observability-agent-answer.png)

The query the agent generated (framed) uses the `api.type` filter of the 2026-10-19 prompt, before `pass-through-mcp` was added:

![Real capture: the KQL query generated by the Observability Agent, filtering api.type on Mcp and mcp-backend](../../assets/screenshots/azure-06-observability-agent-query.png)

**Question:** why keep `queries/mcp-traffic.kql` if the agent can write the query?

<details>
<summary>Show answer</summary>

Because the file is reproducible and reviewed: it gives the same result every time, it is versioned in Git, and it runs
from the Azure CLI and the validator, with no portal and no AI. The agent's query can change from one run to the next,
and AI-generated content may be incorrect. Use the agent to explore and to draft; keep the reviewed file as the reference.

</details>

### Step 3b - Follow one tool call from end to end (OpenTelemetry)

Step 3 counts calls. This step follows **one** call through every link of the chain: gateway, Function, tool, then the
services the tool calls. Nothing to deploy: the server you published in module 02 already sends one OpenTelemetry span
per tool call and one per downstream step to this Application Insights component, signed in with its managed identity.

> [!NOTE]
> The OpenTelemetry semantic conventions for MCP are in **Development** status: attribute names can still change.

Bob calls `read_report_as_user`. This is what the trace shows (real durations, 2026-10-20):

```text
API Management  POST /workshop-mcp/mcp            369 ms  HTTP 200
└ Function      ReadReportAsUser                  358 ms  failed
  └ tool        tools/call read_report_as_user    324 ms  tool_error
    └ step      Azure Storage read report         323 ms  failed
      ├ step    Managed identity assertion          0 ms  ok
      ├ HTTP    login.microsoftonline.com (OBO)   306 ms  200
      └ HTTP    Azure blob <account>/reports        5 ms  403
```

Read it top down: the gateway sees a success (HTTP 200). The OBO exchange with Entra works. Storage refuses Bob (403).

| A span records (metadata) | A span never records |
|---|---|
| Tool and method: `gen_ai.tool.name`, `mcp.method.name` | Tool arguments and results: the conventions mark them **Opt-In**; this server leaves them off |
| Caller object ID (`workshop.caller`), outcome, `error.type = tool_error` | Tokens, including the On-Behalf-Of assertion |
| Duration and status of each downstream call: host, path, HTTP status | Prompts, request and response bodies, query strings |

**In the Azure portal:**

1. Open your Application Insights resource `appi-mcp-<prefix>-<suffix>`, then **Investigate** → **Search**.
2. In the search box, paste an operation ID from the query below (or type `read_report_as_user`), then press Enter.
3. Select the trace row: **End-to-end transaction details** opens. Select **View timeline**.
4. Select the `read_report_as_user` row: its attributes are under **Custom Properties**.

**Or from your terminal.** The query lists the latest tool calls, with the operation ID to paste in step 2.

PowerShell:

```powershell
$ai = (terraform -chdir=infra/workload output -json resource_names | ConvertFrom-Json).application_insights
$group = terraform -chdir=infra/workload output -raw resource_group_name
az monitor app-insights query --app $ai --resource-group $group --offset 24h `
  --analytics-query '@modules/06-observe-inventory/queries/tool-spans.kql' --query 'tables[0].rows' -o json
```

> **Real result** — module 05 persona checks, 2026-10-20, author's test tenant. Columns: timestamp, tool, outcome,
> success, duration (ms), caller, operation ID. Object IDs replaced.
>
> ```text
> [ "2026-10-20T12:41:49.8297728Z", "read_report_as_app", "success", "True", 9.2244, "<bob-object-id>", "e87b9b4eb127eb41143869942a1ce275" ]
> [ "2026-10-20T12:41:48.6026728Z", "read_report_as_user", "denied-downstream:403", "False", 323.6665, "<bob-object-id>", "08beb1cec8d288bfb679974b4222bcc1" ]
> [ "2026-10-20T12:41:47.7550955Z", "whoami", "success", "True", 533.3178, "<bob-object-id>", "dc377674e8f2d0ce17bdbdfaed876754" ]
> [ "2026-10-20T12:41:37.1243308Z", "read_report_as_app", "success", "True", 252.9528, "<alice-object-id>", "fac868e66169055f59c7860e473ea7e1" ]
> [ "2026-10-20T12:41:36.4007953Z", "read_report_as_user", "success", "True", 350.2882, "<alice-object-id>", "e4953ce2d99878c9594c99d9d3d548e1" ]
> [ "2026-10-20T12:41:34.3688446Z", "whoami", "success", "True", 1563.1348, "<alice-object-id>", "4227ea095c3caeca474221ab324ec16f" ]
> ```
>
> **What it means for you:** the same tool, two outcomes. Alice's `read_report_as_user` succeeds; Bob's ends with
> `denied-downstream:403`. Each row carries its operation ID: paste Bob's in the portal to see where the call stopped.

bash:

```bash
ai=$(terraform -chdir=infra/workload output -json resource_names | jq -r .application_insights); group=$(terraform -chdir=infra/workload output -raw resource_group_name)
az monitor app-insights query --app "$ai" --resource-group "$group" --offset 24h \
  --analytics-query '@modules/06-observe-inventory/queries/tool-spans.kql' --query 'tables[0].rows' -o json
```

> **Expected result** — the same rows as the PowerShell run above.

Bob's trace, in **View timeline** (real capture, 2026-10-20; names pseudonymised). Box 1: the gateway answers HTTP 200,
in blue. Box 2: the tool span, in red. Box 3: the Storage call that refused Bob (HTTP 403).

![Real capture: end-to-end transaction timeline of Bob's read_report_as_user call; the gateway row is blue, the tool span and the Storage call are red](../../assets/screenshots/azure-06-trace-waterfall.png)

The attributes of the tool span (box 2). Nothing else is recorded: no argument, no result, no token.

![Real capture: Custom Properties of the read_report_as_user span: mcp.method.name, gen_ai.operation.name, gen_ai.tool.name, workshop.caller, workshop.outcome and error.type](../../assets/screenshots/azure-06-trace-span-attributes.png)

**Question:** the gateway logged HTTP 200 for Bob's call. Where does the trace show that it failed, and why?

<details>
<summary>Show answer</summary>

In the red rows. The tool span carries `error.type = tool_error`, and the last step is the Storage call refused with
HTTP 403. The step before it, the On-Behalf-Of exchange with Microsoft Entra, succeeded: Bob's token was valid. What he
lacks is a Storage role on the report container. MCP returns tool errors inside HTTP 200, so only the trace shows where
the call stopped.

</details>

> [!TIP]
> **Building your own MCP server?** Keep the same habits: one span per tool call named `tools/call <tool>`, W3C trace
> context passed from the gateway, metadata only (leave the Opt-In arguments and results off), and export with a managed
> identity rather than a key.

### Step 4 - Register the MCP server in API Center (Preview)

API Center inventory is in **Preview**.

**No API center yet?** Create one, then an environment that stands for the gateway. Run from the repository root,
after approval. The API center is created on the **Free** plan, in your workshop resource group. The
`Microsoft.ApiCenter` provider must already be registered: if it is not, ask your administrator.

```powershell
$group = terraform -chdir=infra/workload output -raw resource_group_name
$apic = (terraform -chdir=infra/workload output -raw mcp_function_app_name) -replace '^func-', 'apic-'
az apic create --resource-group $group --name $apic --location (az group show --name $group --query location --output tsv)
az apic environment create --resource-group $group --service-name $apic --environment-id gateway --title "API Management gateway" --type development
terraform -chdir=infra/workload output -raw gateway_mcp_endpoint
```

> **Expected result** — JSON for the new API center (`"sku": { "name": "Free" }`) and for the `gateway` environment,
> then the gateway URL to paste under **Remotes**. The first `az apic` command offers to install the `apic-extension`
> Azure CLI extension: accept. If the region is not offered for API Center, add the asset in a supported region instead.

In the Azure portal, search for **API Center**, open the API center you created, then:

1. Open your API center and choose **Assets**.
2. Choose **+ Register an asset**, then **MCP server**.
3. Enter a title, a summary and a description. Use synthetic text, for example "Contoso governed MCP demo".
4. Under **Remotes**, choose **Add remote**. Paste the gateway URL printed by the last command above, choose the
   environment **API Management gateway**, then **Save**.
5. Under **Version title**, enter `v1` and choose the lifecycle **Development**. The license is optional.
6. Choose **Create**. API Center generates the MCP definitions (SSE, and Streamable according to the documentation).

Check: the asset appears in **Assets** with the environment you selected.

![Real capture: API Center Assets, Register an asset, MCP server; then the MCP Remote panel with the gateway URL and the API Management gateway environment; then the new MCP asset in the list](../../assets/screenshots/azure-06-apic-register.png)

*Real capture, 2026-10-19, author's test tenant (names pseudonymised). Frames 1 to 3: open the form. Frames 4 to 6: add
the remote. Frame 7: the asset is listed as **MCP**, lifecycle **Development**.*

Check that the remote was saved too. In the author's test tenant, **Create** registered the asset but returned an error
for the remote (HTTP 400), and only an SSE definition was generated. If the asset has no deployment, add it from your
terminal. It uses the same names as above:

```powershell
$server = Join-Path $env:TEMP 'apic-server.json'
@{ runtimeUri = @((terraform -chdir=infra/workload output -raw gateway_mcp_endpoint)) } | ConvertTo-Json -Compress | Set-Content $server
az apic api deployment list --resource-group $group --service-name $apic --api-id contoso-governed-mcp-demo --query "[].name" --output tsv
az apic api deployment create --resource-group $group --service-name $apic --api-id contoso-governed-mcp-demo --deployment-id gateway --title "API Management gateway" --environment-id /workspaces/default/environments/gateway --definition-id /workspaces/default/apis/contoso-governed-mcp-demo/versions/v1/definitions/default-sse --server "@$server"
Remove-Item $server
```

> **Expected result** — the first command prints nothing (no deployment yet). The second one prints the new `gateway`
> deployment as JSON. Use the identification (`contoso-governed-mcp-demo`) and version (`v1`) shown in your form.

**Question:** the server now has an API Center asset. Can Eve call it because she can see it in the catalog?

<details>
<summary>Show answer</summary>

No. An inventory entry authorizes nobody. API Center is not a runtime hop. Every call still goes through API Management,
which validates the Microsoft Entra token (issuer, tenant, audience, expiry, scope), and the gateway checks the app role (`Tools.Read` or `Tools.Write`).
Without a valid token and the right role, Eve is refused.

</details>

### Step 5 - Confirm the BYO listing (Preview)

The BYO MCP listing is in **Preview** and is not for production. A tenant IT administrator reviews and approves it in the Microsoft 365 admin center. As a participant, you only confirm that the entry exists and that its status is what the administrator set. You do not approve it yourself.

Where to look: sign in to the [Microsoft 365 admin center](https://admin.microsoft.com/), then select **Agents → Tools** and
the **Registry** tab (pending entries are in the **Requests** tab). Viewing it needs an administrator role: if you have
none, ask the administrator to show you the entry.

Check: the listing shows the server name and an approval state. An approval state does not prove that the server is safe. Modules 04 and 05 still enforce the controls.

## What you should see

- With ingested MCP traffic, the KQL query returns available rows with `api.type` equal to `Mcp`, `pass-through-mcp` or `mcp-backend`, for `initialize`, `tools/list` and `tools/call`. It is not an exhaustive audit.
- Columns contain tool names and status codes, and no request body, response body, token, prompt or tool argument.
- One tool call is one trace: the timeline shows the gateway, the Function, the `tools/call` span and each downstream call.
- The API Center asset exists, with a remote URL and an environment.
- The offline validator prints one `PASS` line per check and exits with code 0.

## Validate

Offline (no Azure access):

```powershell
pwsh ./modules/06-observe-inventory/validate.ps1 -Offline
```

> **Real result** — offline validator, author's workstation, 2026-10-17. Names and IDs withheld.
>
> ```text
> PASS file exists: README.md (offline)
> PASS file exists: README.fr.md (offline)
> PASS file exists: validate.ps1 (offline)
> PASS file exists: validate.sh (offline)
> PASS file exists: cleanup.ps1 (offline)
> PASS file exists: cleanup.sh (offline)
> PASS file exists: queries/mcp-traffic.kql (offline)
> PASS README sections present and in order (offline)
> PASS README.fr.md has the same section count (offline)
> PASS Steps give PowerShell before bash (offline)
> PASS Preview label on API Center, BYO and Agent 365 (offline)
> PASS KQL selects no body, argument, result or token fields (offline)
> PASS KQL filters on api.type Mcp, pass-through-mcp and mcp-backend (offline)
> PASS README does not instruct enabling payload logging (offline)
> PASS no secrets or tokens in module files (offline)
> PASS only placeholder GUIDs in module files (offline)
> PASS PROGRESS row 06 claims validated only with a date and a live run (offline)
> PASS docs/sources.md has module 06 entries with last-verified dates (offline)
> PASS no infra folder (no Azure resources added) (offline)
> PASS README states the log rules (offline)
> RESULT: all offline checks passed
> ```
>
> **What it means for you:** every offline rule passes. KQL results, the API Center asset and the BYO listing are still checked by hand.

```bash
./modules/06-observe-inventory/validate.sh --offline
```

> **Expected result** — the same PASS/FAIL lines as the PowerShell run above.

Each check prints `PASS` or `FAIL` on one line. A `FAIL` line names the file or rule that failed. Live checks (KQL results, API Center asset, BYO listing) are manual in this version and are not run by the script.

**Question:** the check `KQL selects no body, argument, result or token fields` passes. Why test the query itself, not only the logs?

<details>
<summary>Show answer</summary>

Because people copy the query. If it selected a body or a token column, it would expose data as soon as someone turned
payload logging on, and it would suggest doing so. Testing the query keeps the "metadata only" rule in the material itself.

</details>


## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| The KQL query returns no rows | Traffic is older than the time window, or diagnostics are not enabled on the APIM API | Widen both `--offset` and the `ago(24h)` filter in `queries/mcp-traffic.kql`, then confirm the APIM diagnostic setting for the MCP API. |
| Rows exist but `tool.name` is empty | Only `tools/list` was called, or the MCP operation was not classified | Call a tool once from the client, then rerun. |
| Payload fields appear in the logs | Payload logging was turned on | Turn it off in APIM, remove the affected rows according to your retention policy, and report it as a finding. |
| The span query returns no `tools/call` rows | No tool was called yet, or your server was published before the spans were added | Call a tool, wait 2 to 5 minutes, rerun. Otherwise publish the server again ([module 02, step 5](../02-open-server/README.md#steps)); after module 04 stage 2, publish before locking (see module 04). |
| API Center asset cannot be created | The role is missing, or the environment does not exist | Confirm the role in RBAC and create the environment first. |
| BYO listing is missing | Preview feature not enabled, or the administrator has not approved it | Ask the tenant IT administrator. Do not request the role yourself. |

## Clean up

Terraform and the scripts of this module create no Azure resources, so the cleanup script is a guarded report. The only
resource you may add by hand is the optional API center from step 4: delete it with the command at the end of this section.

PowerShell:

```powershell
pwsh ./modules/06-observe-inventory/cleanup.ps1
pwsh ./modules/06-observe-inventory/cleanup.ps1 -Apply
```

> **Real result** — `cleanup.ps1`, then `cleanup.ps1 -Apply`, author's workstation, 2026-10-17. Names and IDs withheld.
>
> ```text
> Module 06 creates no Azure resources. Nothing is deleted by this script.
> Manual cleanup, if you created them:
>   - API Center asset: delete in the Azure portal (API center > Assets).
>   - BYO MCP listing: removed only by a Microsoft 365 administrator.
>   - Agent 365 policy (demo): removed only by a tenant administrator.
> Report only. Re-run with -Apply to confirm the guard passed (no deletions are performed).
> Module 06 creates no Azure resources. Nothing is deleted by this script.
> Manual cleanup, if you created them:
>   - API Center asset: delete in the Azure portal (API center > Assets).
>   - BYO MCP listing: removed only by a Microsoft 365 administrator.
>   - Agent 365 policy (demo): removed only by a tenant administrator.
> Guard passed. No module-owned resources to remove.
> ```
>
> **What it means for you:** both runs delete nothing, because this module created nothing. Remove the API Center asset yourself in the portal; leave the BYO listing and any Agent 365 policy to the administrators.

bash:

```bash
./modules/06-observe-inventory/cleanup.sh
./modules/06-observe-inventory/cleanup.sh --apply
```

> **Expected result** — the same report lines as the PowerShell run above.

Without `-Apply` (or `--apply`), the script only reports. With the flag it removes only what this module created, which is nothing. To remove the API Center asset, delete it in the portal. Remove the BYO listing only through the Microsoft 365 admin center, as the administrator.

If you created the API center in step 4, delete it with the same names. This removes the API center, its environment
and the asset:

```powershell
$group = terraform -chdir=infra/workload output -raw resource_group_name
$apic = (terraform -chdir=infra/workload output -raw mcp_function_app_name) -replace '^func-', 'apic-'
az apic delete --resource-group $group --name $apic --yes
```

> **Expected result** — no output and exit code 0. `az apic show --resource-group $group --name $apic` then reports that
> the resource was not found.

## Go further

- **Alerts**: create an Azure Monitor log alert on the rate of `403` responses from the MCP operation. Keep it synthetic and aggregate.
- **Agent 365 (Preview, demo only)**: Agent 365 can inventory MCP servers fronted by API Management and block a server that policy does not allow (the caller receives 403). Tool-level control, observability and Defender or Purview integration need the AI Gateway tier, which is also Preview. Tenant-level consent comes from a tenant administrator. This is a talk track for the presenter, with no participant step.
- **Retention**: decide how long MCP telemetry is kept, and align it with the data-protection policy.

## Sources

Official Microsoft Learn pages used for this module are recorded with last-verified dates in `docs/sources.md` under module 06:

- [Monitor MCP traffic](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers): default dimensions and payload logging, kept off here.
- [Application Insights integration](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights): sampling and correlation.
- [API Center inventory](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server) (Preview registration flow).
- [Bring your own MCP server](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) (Preview).
- [Agent 365 with API Management](https://learn.microsoft.com/azure/api-management/agent-365) (Preview; optional talk track, not revalidated here).
- [Azure Copilot Observability Agent](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-overview) and [chat with your observability data](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-chat): optional step. Autonomous operations and the agent resource are Preview and not used here. Last verified: 2026-10-19.
- [Use OpenTelemetry with Azure Functions](https://learn.microsoft.com/azure/azure-functions/opentelemetry-howto): worker packages and `UseFunctionsWorkerDefaults`; this server exports traces only, with its managed identity. Last verified: 2026-10-20.
- [OpenTelemetry semantic conventions for MCP](https://github.com/open-telemetry/semantic-conventions-genai/blob/547934afa90a34298441caf80c43b27255c3a292/docs/gen-ai/mcp.md) (status: Development, pinned commit): span name `{mcp.method.name} {target}`, `error.type = tool_error` when `isError` is true, arguments and results Opt-In. Last verified: 2026-10-20.
- [End-to-end transaction diagnostics](https://learn.microsoft.com/azure/azure-monitor/app/transaction-search-and-diagnostics): Search and the transaction timeline. Last verified: 2026-10-20.

Last verified: 2026-10-20.

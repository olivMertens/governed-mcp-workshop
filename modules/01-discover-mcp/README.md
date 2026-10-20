# 01 - Discover MCP locally

[Français](README.fr.md)

## Goal

Discover a Model Context Protocol (MCP) tool, read its input schema, then make a real call.
**You can run this module now. No Azure deployment, presenter portal or sign-in is required.**

## Why it matters

Discovery is not execution. A model's answer is not proof that a tool ran.
Client approval is not server authorization. This local exercise does not test identity or roles.

## What you deploy

Nothing in Azure. Your client starts one C# process using standard input/output (stdio).
It exposes only `get_service_health`. It returns fixed synthetic data and makes no downstream calls.
The server has no HTTP listener, persistent data, write tool or payload logging.

![Local discovery architecture](../../assets/architecture/01.en.svg)

The diagram is a learning view, not evidence of a deployed service.
No **Preview** feature is used by this module. Later Preview features remain labeled in their own modules.

## Prerequisites and required roles

- Your own [checkout](../../docs/GETTING-STARTED.md#0-get-the-repository-onto-your-computer).
- PowerShell 7.4+ and the .NET 10 software development kit (SDK). Check `pwsh --version` and `dotnet --list-sdks`.
- Package download access. Dependencies are pinned and locked; do not bypass certificate or registry controls.
- Node.js 22.19+ and npm for the optional Inspector exercise.
- Visual Studio Code (VS Code) with GitHub Copilot access for the manual client-approval exercise.
  Protocol tests do not need a model or a Copilot subscription. Copilot usage can consume your plan's allowance.

**Azure roles: none.** You may do this offline-from-Azure exercise while module 00's Azure checks are pending.
Those checks and deployment approvals are still required before any cloud exercise.

## Steps

### PowerShell

Open PowerShell 7 in the repository root. Stop on any failed command.

**1. Build and verify the local server.**

```powershell
& .\modules\01-discover-mcp\validate.ps1
```

> **Real result** — local capture on the authoring host, 2026-10-16. Synthetic data; your timings differ.
>
> ```text
> PASS locked local server build (expected HTTP N/A).
> PASS SDK protocol negotiation (expected HTTP N/A; stdio).
> INFO negotiated MCP protocol: 2026-07-28
> PASS tools/list exposes exactly one read tool (expected HTTP N/A; stdio).
> PASS tools/call workshop-api succeeds (expected HTTP N/A; stdio).
> PASS unknown service returns a tool error (expected HTTP N/A; stdio).
> PASS write tool is not exposed (expected HTTP N/A; stdio).
> PASS local MCP checks complete (expected HTTP N/A; stdio, no Azure).
> MANUAL CHECK: client approval prompts are not tested by this validator.
> ```
>
> **What it means for you:** your machine can build and run an MCP server, and a client can negotiate a protocol
> version with it. `MANUAL CHECK` is honest: a script cannot prove that a human saw an approval dialog. Step 3 covers that.

The validator restores locked packages, builds Release, starts its own server, calls it, then closes it.
It does not install a background service or use your Azure session.

**2. Inspect it without an AI model (optional second client).**

### Prepare Inspector in the same PowerShell terminal

**Why:** the client needs the compiled server path; later commands reuse these variables.
Review npm's package-install prompt. Keep Inspector credentials in memory only.

```powershell
$server = (Resolve-Path .\modules\01-discover-mcp\server\bin\Release\net10.0\Workshop.LocalMcp.dll).Path
$env:MCP_INSPECTOR_SECRET_STORE = 'memory'
$env:MCP_INSPECTOR_PERSIST_TOKENS = 'none'
```

> **Expected result** — from the commands themselves; these lines print nothing.
> Success is a silent return. Confirm with `Test-Path $server`, which prints `True`.
> If `Resolve-Path` reports that the path does not exist, step 1 did not finish.

**Observe:** no server has started. A missing DLL means step 1 did not finish; stop.

The next four requests use this same terminal. Each command starts and closes its own local server.
The portal shows recorded or expected examples, never your own execution. Compare your terminal output with them.
Do not paste tokens or terminal output into the public page.

### Request 1 of 4: Discover

**Why:** before choosing a tool, a client asks the server what it can do. This lists a contract; it does not check service health.

**Predict:** one tool, `get_service_health`, with a required `service` argument.

```powershell exchange
npx @modelcontextprotocol/inspector@2.9.0 --cli dotnet $server --method tools/list
if ($LASTEXITCODE -ne 0) { throw 'Inspector discovery failed.' }
```

> **Real result** — local capture, 2026-10-16 (excerpt of the Inspector output).
>
> ```text
> "name": "get_service_health",
> "description": "Read fixed synthetic health data. No Azure access, network calls or real monitoring.",
> "inputSchema": { "type": "object", "properties": { "service": { "type": "string", ... } }, "required": ["service"] },
> "annotations": { "readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false }
> ```
>
**What it means for you:** `description` helps the model choose a tool. `inputSchema` tells it how to build the arguments.
You have discovered the tool, not called it.

**Look for:** `get_service_health`, `required: ["service"]` and `readOnlyHint: true`. There is no health result yet.

**Question:** does `readOnlyHint: true` prevent a tool from writing?

<details>
<summary>Show answer</summary>

No. Annotations are hints the server declares for the client; they are not enforced. Only the server's own code and,
in later modules, its authentication and app-role checks decide what a caller may do.

</details>

### Request 2 of 4: Read a service

**Why:** discovery gave you the contract. Now use it to ask for one service's health.

**Predict:** `workshop-api` returns `healthy` and `isError: false`, with synthetic data.

```powershell exchange
npx @modelcontextprotocol/inspector@2.9.0 --cli dotnet $server --method tools/call --tool-name get_service_health --tool-arg service=workshop-api
if ($LASTEXITCODE -ne 0) { throw 'Inspector tool call failed.' }
```

> **Real result** — local capture, 2026-10-16.
>
> ```text
> "structuredContent": { "service": "workshop-api", "status": "healthy", "source": "synthetic", "environment": "local-only" },
> "isError": false
> ```
>
**What it means for you:** the client actually invoked the tool. `healthy` is the synthetic service's state.
`isError: false` means the tool succeeded; `source: synthetic` means this is not real monitoring.

**Look for:** `service: workshop-api`, `status: healthy`, `source: synthetic` and `isError: false` in your terminal.
Compare the fields, not spacing or timings.

### Request 3 of 4: Change the service

**Why:** keep the tool, change only `service`. This shows how arguments select data without adding a new tool.

**Predict:** `ticket-queue` returns `degraded`. Decide whether that means the tool itself failed.

```powershell exchange
npx @modelcontextprotocol/inspector@2.9.0 --cli dotnet $server --method tools/call --tool-name get_service_health --tool-arg service=ticket-queue
if ($LASTEXITCODE -ne 0) { throw 'Inspector tool call failed.' }
```

> **Expected result** — excerpt of the fixed synthetic response checked by the module validator. Not a live response from this page.
>
> ```text
> "structuredContent": { "service": "ticket-queue", "status": "degraded", "source": "synthetic", "environment": "local-only" },
> "isError": false
> ```

**What it means for you:** a degraded service is data, not a failed tool call. The tool successfully reported that state.

**Look for:** only the service and status change in the result. `isError` stays `false`.

### Request 4 of 4: Test a refusal

**Why:** a reliable tool rejects unsupported input instead of inventing an answer. Test that boundary.

**Predict:** `billing` returns `isError: true`, with no invented service health. Inspector 2.9.0 exits with code **5** for this tool error, not 0.

```powershell exchange
npx @modelcontextprotocol/inspector@2.9.0 --cli dotnet $server --method tools/call --tool-name get_service_health --tool-arg service=billing
if ($LASTEXITCODE -ne 5) { throw 'Expected Inspector exit code 5 for this tool error.' }
```

> **Real result** — local Inspector 2.9.0 capture, 2026-10-20 (excerpt). Synthetic data.
>
> ```text
> "text": "An error occurred invoking 'get_service_health': Unknown synthetic service. Use workshop-api or ticket-queue."
> "isError": true
> ```
>
> Inspector also writes an error summary with `code: tool_is_error` and exits with code **5**. The guard above expects that code for this request only.

**What it means for you:** an MCP exchange can succeed while the tool reports failure. This is an input refusal,
not an Azure outage or an identity check. The client received the tool's refusal and reports it with its own exit code.
No cloud service was contacted.

**Look for:** `isError: true`, the allowed service names and Inspector exit code 5. Any other result needs investigation.

**Question:** Inspector exits with code 5. Does that necessarily mean the connection failed?

<details>
<summary>Show answer</summary>

No. Here, the connection delivered a tool result with `isError: true`. Inspector maps that tool failure to exit code 5.
Read the error and the result content. Other clients may report tool errors differently.

</details>

### Optional: use the Inspector web page

Prefer clicking to typing? Start the Inspector without `--cli`:

```powershell
npx @modelcontextprotocol/inspector@2.9.0 dotnet $server
```

> **Expected result** — the terminal prints `MCP Inspector Web is up and running at: http://127.0.0.1:6274?MCP_INSPECTOR_API_TOKEN=...`
> and opens that page. The token protects the page on your machine: do not share it. Stop with **Ctrl+C** when finished.

In the page: switch **dotnet** on (A); open **Tools**, select `get_service_health`, type `workshop-api` in **service**
and select **Execute Tool** (B); read the result (C).

![Real capture: MCP Inspector web page; A the dotnet server Connected with MCP 2025-11-25, B the get_service_health tool with READ-ONLY and IDEMPOTENT badges, service workshop-api and Execute Tool, C the result workshop-api healthy synthetic local-only](../../assets/screenshots/client-01-inspector.png)

*Real capture, 2026-10-19, author's workstation. The badges in frame 2 are the tool annotations: hints, not controls.*

**3. Connect VS Code and observe one approval.**

Open this checkout in VS Code. Its reviewed `.vscode/mcp.json` contains `workshop-local` and preserves
the Microsoft Learn server. Run **MCP: List Servers**, select **workshop-local**, then **Start**.
The configuration runs the built DLL directly; do not start it manually in a second terminal.
There is no endpoint URL to paste.

Use a local chat session with **Manual permissions**, not Allow all or Autopilot.
For Agent Host sessions, use Folder isolation; worktree sessions can force Allow all.
Run **Chat: Manage Tool Approval** and turn off pre-approval for this tool.
If a confirmation is still skipped, use the documented per-tool
`chat.tools.eligibleForAutoApproval` setting with `false` for the actual tool identifier shown by your client.

> [!WARNING]
> Do not enable global auto-approval or change organization policy.
> Workspace Trust and starting a server are different from approving a tool call.

Select only `workshop-local` in the tool picker and send:

> Call get_service_health once with service workshop-api. Ask for my approval before the tool runs.
> Do not substitute a terminal command or invent the result.

Review the actual tool name and arguments; approve **once**.
Expand the tool-call record and inspect its result, not only the assistant's answer.

<details>
<summary>How to do it in VS Code, click by click</summary>

1. Open the repository folder with **File** > **Open Folder...**. If VS Code asks whether you trust the authors, trust
   only your own checkout.
2. Press **Ctrl+Shift+P** (macOS: **Cmd+Shift+P**), run **MCP: List Servers**, choose `workshop-local`, then
   **Start Server**. Its status becomes **Running**.
3. Open Chat with **Ctrl+Alt+I** (macOS: **Ctrl+Cmd+I**). In the mode list under the chat box, choose **Agent**. Select
   the tools icon (**Configure Tools**) and keep only the `workshop-local` tools.
4. Keep approvals manual: do not switch the permissions picker to **Allow all** or **Autopilot**.
5. Paste the prompt. VS Code shows the tool name `get_service_health` and the argument `service: workshop-api`: select
   **Allow** once. Expand the tool call in the chat to read its input and output.
6. When you have finished, run **MCP: List Servers**, choose `workshop-local`, then **Stop Server**.

</details>

> [!IMPORTANT]
> If your client cannot enforce per-call approval, record this exercise as **not verified**.
> The validator cannot prove that a human saw a dialog.

### Bash

The same validator runs through PowerShell 7; no separate server implementation:

```bash
bash ./modules/01-discover-mcp/validate.sh
server="$PWD/modules/01-discover-mcp/server/bin/Release/net10.0/Workshop.LocalMcp.dll"
export MCP_INSPECTOR_SECRET_STORE=memory MCP_INSPECTOR_PERSIST_TOKENS=none
```

> **Expected result** — the validator prints PASS checks, then the setup lines return silently. Stop if the build fails.

Then follow the same four requests. Run each block separately. The first three requests expect exit code 0;
the final refusal deliberately expects code 5.

```bash
npx @modelcontextprotocol/inspector@2.9.0 --cli dotnet "$server" --method tools/list
```

> **Expected result** — the discovery example in request 1: one tool and its required `service` argument, not a health result.

```bash
npx @modelcontextprotocol/inspector@2.9.0 --cli dotnet "$server" --method tools/call --tool-name get_service_health --tool-arg service=workshop-api
```

> **Expected result** — request 2: `workshop-api`, `healthy`, `source: synthetic` and `isError: false`.

```bash
npx @modelcontextprotocol/inspector@2.9.0 --cli dotnet "$server" --method tools/call --tool-name get_service_health --tool-arg service=ticket-queue
```

> **Expected result** — request 3: `ticket-queue`, `degraded` and `isError: false`.

```bash
code=0
npx @modelcontextprotocol/inspector@2.9.0 --cli dotnet "$server" --method tools/call --tool-name get_service_health --tool-arg service=billing || code=$?
if [ "$code" -ne 5 ]; then printf '%s\n' 'Expected Inspector exit code 5 for this tool error.' >&2; false; fi
```

> **Expected result** — request 4: the error names the allowed services, with `isError: true` and `tool_is_error`. The guard accepts only Inspector exit code 5.

Run the VS Code exercise above from the same checkout.
Keep each block separate and stop on an unexpected exit code.

## What you should see

| Action | Expected result | Meaning |
|---|---|---|
| `tools/list` | Exactly one tool, `get_service_health`; required string input `service` | You discovered a schema, not a result. |
| `service=workshop-api` | `isError: false`, `status: healthy` | A real call returned synthetic health data. |
| `service=ticket-queue` | `isError: false`, `status: degraded` | Degraded synthetic health is not a protocol failure. |
| Unknown service | `isError: true` | The tool rejects unsupported input; it does not check Azure. |
| `create_ticket` | Tool absent / rejected | This module exposes no writes, not a role-based denial. |

Example **synthetic** `structuredContent`, also returned as a text block:

```json
{"service":"workshop-api","status":"healthy","source":"synthetic","environment":"local-only"}
```

The validator prints, among other checks:

```text
PASS tools/list exposes exactly one read tool (expected HTTP N/A; stdio).
PASS exact synthetic result for workshop-api (expected HTTP N/A; stdio).
PASS unknown service returns a tool error (expected HTTP N/A; stdio).
PASS local MCP checks complete (expected HTTP N/A; stdio, no Azure).
MANUAL CHECK: client approval prompts are not tested by this validator.
```

**HTTP status: not applicable.** stdio is a local process transport, not an HTTP service.
The SDK-to-SDK check negotiated protocol `2026-07-28` on the authoring host.
Inspector 2.9.0 also listed and called the server successfully. Let clients negotiate; do not handcraft a handshake.
These observations do not prove compatibility with future Functions or gateway modules.

## Validate

Rerun `validate.ps1` or `validate.sh` above. Every automatic check must say `PASS`, with exit code 0.
It checks protocol negotiation, exact discovery/schema/annotations, both complete synthetic results,
unknown and missing service inputs, and rejection of a write-tool name.
It logs only concise checks, not tool arguments/results or protocol transcripts.

Separately observe the client approval and result in VS Code. Do not mark that manual check passed
because the automated validator succeeded.
The module remains `in-progress` until the manual check and the preceding environment gate are recorded.

**Question:** the validator prints `PASS unknown service returns a tool error`. Why does a refused input count as a success?

<details>
<summary>Show answer</summary>

Because the check **expects** the refusal. A good test proves a rule, not only the happy path: the server must reject an
unknown service with `isError: true` instead of guessing. `PASS` means the rule held.

</details>


## Troubleshooting

| Symptom | Check |
|---|---|
| .NET 10 missing / restore fails | Follow the installation guide. Reopen PowerShell. Use approved package/proxy access; do not disable TLS checks. |
| DLL not found | Run the validator first, from this checkout. Do not copy another participant's build output. |
| No tools in VS Code | Start `workshop-local`, refresh tools and select the correct server. Check its actual startup error. |
| No approval | Check permission level, per-tool pre-approval and organization settings. Do not confuse a result with a confirmation. |
| Inspector fails | Check Node/npm and the pinned package in your configured registry. Do not silently change the pin or managed registry. |
| A browser URL is requested | You selected HTTP instead of stdio. This server has no URL. |

## Clean up

Stop `workshop-local` through **MCP: List Servers** when finished. Inspector CLI commands stop themselves.
Then run:

```powershell
& .\modules\01-discover-mcp\cleanup.ps1
```

> **Expected result** — from the messages in `cleanup.ps1`; not yet a recorded capture.
>
> ```text
> PASS no Azure resources or persistent tool data created by module 01 (expected HTTP N/A).
> MANUAL CHECK: stop workshop-local in MCP: List Servers; stop Inspector with Ctrl+C in its terminal.
> MANUAL CHECK: you may leave workshop-local configured but stopped; do not remove other servers.
> KEEP private module 00 parameters and Terraform state. This script does not delete files or stop unrelated processes.
> ```
>
> **What it means for you:** there is nothing to delete in Azure. The `MANUAL CHECK` lines are yours to do in VS Code.

```bash
bash ./modules/01-discover-mcp/cleanup.sh
```

> **Expected result** — the same four lines as the PowerShell run above.

The helper reports manual actions; it does not kill other processes or delete files.
Build artifacts stay in ignored `server/bin` and `server/obj` for reuse.
Keep module 00's private parameters/state. No Azure teardown is needed for module 01.

## Go further

Explain why `degraded` with `isError: false` differs from an unsupported service with `isError: true`.
Explain why a read-only annotation is a hint, not an access check.
Next: [module 02](../02-open-server/README.md) deploys the same server to Azure, protected only by a key.
The presenter's optional portal hosts these instructions only.

## Sources

- [C# SDK 2.2.0 quickstart, pinned commit](https://github.com/modelcontextprotocol/csharp-sdk/blob/6fa3825973949a9c4f0cd8af344e15a8db09dc35/docs/concepts/getting-started.md).
- [Reuse and license notices](UPSTREAM.md).
- [MCP transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports) and [tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).
- [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector).
- [Inspector CLI output and exit codes](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/cli).
- [VS Code MCP configuration](https://code.visualstudio.com/docs/agent-customization/mcp-servers) and [tool approvals](https://code.visualstudio.com/docs/agents/run/approvals).

Last verified: 2026-10-20 (guided exercise and public tool/Inspector references; no cloud changes).

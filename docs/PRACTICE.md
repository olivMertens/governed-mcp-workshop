# Connect and test from your own client

> [!IMPORTANT]
> **This website does not run tests. Use VS Code or MCP Inspector on your computer.**

This guide helps you connect to a Model Context Protocol (MCP) server you have already deployed.
The page only prepares instructions, commands and prompts. Your client connects to the server and makes the real calls.
It does not deploy the workshop or certify your deployment.
**Starting without Azure?** Use [module 01's local stdio exercise](../modules/01-discover-mcp/README.md) first.
It has real commands and does not use the remote-endpoint field below.
An example or an expected result is not a recorded test result.

## Option A: VS Code (recommended)

You can use Visual Studio Code (VS Code) without entering anything on the practice page.

1. Finish your current module's deployment and prerequisites. Copy its exact HTTPS MCP endpoint.
   From module 04 onward, use only the API Management gateway endpoint.
2. In VS Code on your computer, open the Command Palette: **Ctrl+Shift+P** on Windows or **Cmd+Shift+P**
   on macOS. Run **MCP: Add Server**, choose **HTTP**, paste the endpoint and name the server `workshop`.
   Choose your private user configuration. Preserve other servers and never commit credentials.
3. Run **MCP: List Servers**, select `workshop`, and start it. Review the trust prompt.
   Follow the current module's authentication instructions: secure system-key input for module 02,
   Microsoft Entra sign-in from module 03 onward. An address alone does not grant access.
4. Open GitHub Copilot Chat in **Agent** mode and select only the workshop server's tools in its tool picker.
   Copy **Discover without invoking a tool** from the practice page into **chat**, not the terminal.
   Check the discovered tool list before sending **Make one read-only call**.
5. Inspect the actual `get_service_health` tool-call entry and result. If the tool is unavailable, stop.
   A connected badge or the assistant's prose alone is not evidence of a successful call.

## Option B: MCP Inspector

Inspector is a separate client for inspecting calls manually, without an AI conversation. Choose this
instead of VS Code; you do not need both.

1. Check PowerShell 7 and Node.js 22.19.0 or newer from module 00. For Microsoft Entra authentication,
   check that Inspector has its own approved public client settings; VS Code approval does not cover it.
2. Enter only your HTTPS endpoint in the practice page. This checks its format and generates a command;
   it does not connect to the server.
3. Copy **Start Inspector / PowerShell** into **PowerShell on your computer** and run it.
   Review the installation prompt, then open the private local URL printed in the terminal. Do not share it.
4. In Inspector, check **Streamable HTTP** and the endpoint. Follow the module's authentication setup,
   then choose **Connect**. The generated command does not supply credentials.
5. Open **Tools / List Tools**, select `get_service_health` and inspect its input schema.
   Supply only required synthetic arguments, then choose **Call Tool** once and read the result.
   Do not paste the Copilot Chat prompts into Inspector.
6. Stop Inspector with **Ctrl+C** when finished. Never export authentication headers or Network/Protocol transcripts.

## What counts as a successful test?

For the first read-only test, the client must list `get_service_health` and its actual call must return
the module's expected synthetic result without an MCP tool error. An HTTP 200 alone is not enough.
Neither a prepared command nor reading the expected result proves that a test ran.

Then return to your current module and run its validation command from the repository root in your own
terminal. Use the command for your selected track, including the low-code guide's explicit parameters.
Compare the `PASS`/`FAIL` lines and expected HTTP statuses. Later exercises deliberately test denied
access: do not grant extra rights to make an expected refusal disappear.

## Choose where to work

- **Local desktop:** open the repository in Visual Studio Code (VS Code). Install the module 00 prerequisites.
  The local command opens your current folder; run it from your existing checkout.
- **Codespaces:** the launch link opens GitHub's creation flow, not a running environment. Review the branch,
  machine size, payer and included quota before creating anything. Codespaces uses the published branch:
  unpushed local changes are not included. The workshop dev container is not implemented yet.
- **For authenticated Inspector tests:** prefer your local desktop, or connect to a codespace using VS Code
  desktop and private local port forwarding. A browser-only codespace changes the OAuth callback origin.
  Do not make an Inspector port public, disable its authentication, or widen its allowed origins to fix login.
  Stop the Inspector with Ctrl+C when finished. Stop unused codespaces; stored codespaces can still incur charges.

## Connect without moving credentials

1. Get the exact MCP endpoint from your deployment's outputs. Use Streamable HTTP for a remote server.
   From module 04 onward, use only the API Management gateway endpoint, never the private Function address.
2. Enter only that HTTPS URL in the canvas. No keys, tokens, query strings or account credentials.
   The value stays in page memory; it is not sent to the board server, saved or included in progress.
3. For VS Code, run **MCP: Add Server**, choose HTTP and use the endpoint. Use a private user configuration,
   not a committed workspace file. The canvas can copy a URL-only server configuration for reference.
   With an existing user configuration, merge the server entry; do not replace your other servers.
4. For Inspector, copy the PowerShell or bash command into your own terminal. It pins Inspector 2.9.0
   and requires Node.js 22.19.0 or newer. Review the package-install prompt.
   Open the local URL printed by the launcher; it contains a private per-launch capability. Do not share it.
   Version 2.9.0 was installable from the configured npm registry on 2026-10-14; the newer GitHub 2.11.0 source
   candidate was not. The command checks package availability and stops if it is missing. Do not change a
   managed registry or bypass a transport-security warning. The client explicitly negotiates the protocol era.
5. Inspector credentials stay in memory with the provided command; OAuth tokens are not persisted.
   The target is ad hoc, not a writable server catalog. Do not export headers or save a credential-bearing
   catalog: Inspector header values otherwise remain plaintext even when its secret store is protected.
6. For Microsoft Entra, use the administrator-approved public client ID, redirect URI and scopes for this
   specific client. Entra does not support dynamic client registration. In Inspector, use its OAuth settings
   and the exact Redirect URI shown there. Keep the client secret empty. A VS Code preauthorization does
   not preauthorize Inspector. Stop if the flow asks for a client secret or extra permissions.
7. For the module 02 key-only endpoint, use the module guide's secure client input for the MCP extension
   system key. The URL-only configuration is intentionally insufficient. Do not put the key in a URL,
   command argument, saved Inspector header, chat, log or repository. This is not the OAuth exercise.

App Service Protected Resource Metadata (PRM) is **Preview**. Successful sign-in does not grant every tool.
Client trust and tool approval do not replace server-side role checks.

## Make a real call

1. Select only the workshop server in your client's tool picker. Connect and use **Tools / List Tools**
   in Inspector, or **MCP: List Servers** and the tool picker in VS Code.
   A connected badge alone does not prove that a tool works.
2. Inspect the advertised tool names and input schemas. Start with `get_service_health`, if the deployed
   module exposes it. Supply only synthetic arguments required by the schema; do not guess field names.
3. In Inspector, select the tool and explicitly choose **Call Tool**. In VS Code, use the supplied discovery
   and read-only prompts. Inspect the actual tool-call entry, not just the model's prose answer.
4. Compare the actual transport status and the MCP result. An HTTP 200 can contain an MCP tool error.
   A missing tool is not a passing authorization check. Reconnect after changing the deployed module.
5. Try negative cases only with the dedicated workshop identities. Never borrow another person's session.
   A denied call can be the correct result. Do not grant more rights just to get a green response.
6. Test `create_ticket` only in the synthetic workshop environment and only after explicit human approval
   of that individual call. It creates a queue message and can incur storage/telemetry charges. Do not
   enable automatic approval. The Inspector's explicit Call Tool click is approval only for that one call.
7. Run the module's published validation script from the repository root, following its README.
   The canvas offers that command only when both the guide and script exist. Review it first: validation
   can make real calls, create synthetic test data, incur charges or require additional approval.

## Compare what happened

These are targets for the indicated module, not proof that your deployment passed.

| Stage | Exercise | Expected observation | What it demonstrates |
|---|---|---|---|
| 01 | List tools and call the local synthetic tool | A real tool list and a successful MCP result | Discovery and execution are different operations. |
| 02 | Connect without the system key, then with it using the secure module flow | HTTP 401, then HTTP 200 with a successful synthetic tool result | Possession of the key is not per-user authorization. |
| 03 | Connect without a token or with a wrong-audience token using the validation script | HTTP 401; Eve cannot obtain an assigned-user token | The token must belong to this protected resource. |
| 04 | Explicitly call `create_ticket` as Bob, then Alice | Gateway HTTP 403 for Bob; HTTP 200 and successful tool result for Alice | Tools.Read does not grant Tools.Write. |
| 04 | Exercise the published rate-limit and direct-backend checks | HTTP 429 at the limit; direct Function access denied | The gateway is the enforced entry point. |
| 05 | Call `read_report_as_user` as Alice and Bob | Alice succeeds; Bob has a downstream authorization denial, possibly inside HTTP 200 | On-Behalf-Of (OBO) preserves the user's downstream rights. |
| 05 | Call `read_report_as_app` as Alice and Bob | The same authorized synthetic report for both | App-only access uses the managed identity's rights. |
| 06 | Find the metadata for one call and inspect inventory | Tool, caller object ID, status, latency and correlation ID; gateway listed in API Center | Observability is not payload capture, and inventory is not authorization. |

Do not record tokens, prompts, tool arguments or results as evidence. Keep only approved metadata and concise
PASS/FAIL lines from the validator. Do not export Inspector Network or Protocol transcripts: they can contain
credentials and bodies. Module 05's identity tools are only synthetic placeholders before that module.

## If you are stuck

- **No tools:** check the selected server, transport and exact endpoint, then reconnect. Confirm the module
  actually implements the tool. An ordinary browser GET to an MCP URL is not a tools/list test.
- **HTTP 401:** check the client identity, tenant, audience, expiry and approved scopes. Use the client's
  sign-in flow. Do not paste a bearer token into a token-decoder website or this canvas.
- **HTTP 403:** check the intended app role or downstream resource permission. Expected denial for Bob is
  not a reason to assign Tools.Write or subscription-wide access.
- **HTTP 200 with an error:** inspect the MCP error indicator. A downstream Storage denial can be carried
  inside a successful HTTP envelope. Do not count the transport status alone as PASS.
- **HTTP 429:** wait for the documented window. Do not disable the rate limit or retry in an unbounded loop.
- **Timeout or callback failure:** check approved network reachability, exact redirect URI and private local
  port forwarding. Do not expose a private Function or Inspector port to make the test work.

## 00 - Understand your environment

**What you are proving:** your tools, identity permissions, region and cost approval are ready before deployment.
An Azure subscription role is not the same as permission to create Entra applications or grant consent.

**First hint:** run the published preflight when module 00 provides it. A codespace is a development machine,
not an Azure subscription or an approved identity configuration. Its default image is not a verified workshop image.

**If it still fails:** use the identity request rather than requesting Owner or adding a client secret.
Do not start paid deployment until the plan and costs are approved.

## 01 - Discover before calling

**What you are proving:** a client can discover a tool's schema and invoke it over standard input/output (stdio).
This module needs no Azure deployment or model-hosting subscription.

**First hint:** use the server startup command in the module README. There is no HTTP endpoint for a stdio server.
The remote connection field is for later modules, not a replacement for that local startup command.
Run `pwsh -File .\modules\01-discover-mcp\validate.ps1` from the repository root,
then start `workshop-local` in VS Code or use the pinned Inspector CLI commands in the guide.
Call `get_service_health` with `service=workshop-api`; expect synthetic `healthy`, not an Azure health check.

**If it still fails:** check the actual tool-call record and negotiated protocol. Current Inspector supports
legacy and modern protocol eras; let the client negotiate instead of copying initialization messages by hand.

## 02 - See the limits of a key

**What you are proving:** a key protects the endpoint, but it does not distinguish Alice from Bob.
This short-lived demonstration is not an acceptable enterprise authorization model.

**First hint:** use the MCP extension system key, not a random Function key. Keep webhook authorization enabled.
Use the secure input described by the module, not a saved HTTP header.

**If it still fails:** a 401 without the key is expected. The OBO and app-only tools are labeled simulations
at this stage; do not interpret their synthetic output as a real downstream permission test.

## 03 - Separate identity, scope and role

**What you are proving:** the token is issued for this server, the client has delegated permission, and the
user has the intended app roles. Assignment-required keeps Eve out.

**First hint:** ask which identity the client is signed in as. Scopes describe what the client can do for
the user; app roles describe which user or app is allowed to perform an operation.

**If it still fails:** check the approved client registration and consent with the identity administrator.
Do not reuse a Graph token for MCP or add another accepted audience to make a request pass.

## 04 - Prove the gateway cannot be bypassed

**What you are proving:** identity checks, per-tool permissions, rate limits and network isolation are enforced.
The API Management MCP management API is **Preview**.

**First hint:** use the gateway endpoint. Ask Bob to attempt one synthetic write with explicit approval:
a gateway 403 is the desired result. Ask Alice separately, with the same per-call approval.

**If it still fails:** test the private Function denial and inspect approved metadata. Do not enable public
Function access, remove token validation or relax the rate limit.

## 05 - Ask whose rights reach the data

**What you are proving:** OBO obtains a separate downstream token carrying user context. App-only access
uses a managed identity instead. The MCP token is never forwarded to Graph or Storage.

**First hint:** predict all four Alice/Bob and as_user/as_app results before calling. Then inspect both the
HTTP envelope and the tool's error state. Identical app-only results are intentional.

**If it still fails:** confirm Bob really lacks the report-container role and Alice has only the intended
resource-scoped permission. Do not fall back to a developer credential or broaden the managed identity's role.

## 06 - Observe without collecting the payload

**What you are proving:** you can explain who called which tool and whether it worked without storing its body.
API Center is an inventory, not an authentication or routing hop.

**First hint:** use the correlation ID from an approved metadata-only check. Look for status and latency,
not a serialized request or response. A listed server is not automatically authorized for every caller.

**If it still fails:** check diagnostic settings and the gateway metadata path. Do not enable body logging
or export an Inspector transcript as a workaround.

## 07 - Reuse the boundary, not another token

**What you are proving:** an optional client can use the same governed endpoint without bypassing its controls.
Part A is an optional participant exercise with Microsoft Foundry, not a prerequisite for cleanup.

**First hint:** clarify whether the client represents a user or an application. Recheck the selected client
feature's Preview status, licensing and callback support before connecting.

**If it still fails:** follow the module 07 troubleshooting guide. Do not weaken controls or substitute an undocumented
identity passthrough pattern for a separate downstream token. Part B (Copilot Studio) is a reading-only outline,
not a live-validated exercise.

## 99 - End the bill, preserve shared resources

**What you are proving:** workshop-owned resources and assignments are removed, but pre-existing identities
and shared infrastructure remain.

**First hint:** follow the published cleanup guide and review its exact resource scope. Workload and identity
cleanup are separate responsibilities. Stop Inspector and unused codespaces too.

**If it still fails:** inspect the workshop-tagged inventory and retention or soft-delete behavior.
Do not run an unreviewed broad resource-group deletion.

## Sources

- [VS Code MCP setup and user configuration](https://code.visualstudio.com/docs/agent-customization/mcp-servers).
- [Inspector web client and ad-hoc targets](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/web).
- [Inspector secret-store configuration](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/configuration).
- [Inspector authorization and callbacks](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/authorization).
- [Inspector 2.9.0 source](https://github.com/modelcontextprotocol/inspector/tree/ae865a19178ddf6f375780a02e9c77c4cf4da184).
- [Inspector 2.9.0 secret storage](https://github.com/modelcontextprotocol/inspector/blob/2.9.0/docs/secret-storage.md).
- [Create a codespace](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository).
- [Private port forwarding](https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace).
- [App Service MCP authorization (Preview)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).
- [Source selections](sources.md) for module-specific expectations.

Last verified: 2026-10-14. Client launch recipes are not evidence of deployment compatibility or completed modules.

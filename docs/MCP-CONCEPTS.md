# MCP and agent concepts

[Français](fr/MCP-CONCEPTS.md)

## 1. What problem does MCP solve?

Model Context Protocol (MCP) gives an artificial intelligence (AI) application a common way to discover
capabilities and request their execution. It connects the application to external tools and contextual data.

It does not replace your application programming interfaces (APIs). A server can wrap an existing API,
query a database or perform a calculation. MCP standardizes how a compatible client finds and calls that capability.

**Question:** if a server advertises a ticket tool, does that mean every user may create a ticket?

<details>
<summary>Show answer</summary>

No. Discovery describes a capability. Server authorization decides whether a caller may use it.

</details>

**Read:** [official architecture](https://modelcontextprotocol.io/specification/2026-07-28/architecture).

## 2. Host, client and server are different

| Element | Responsibility | Workshop example |
|---|---|---|
| Host | Runs the AI experience, controls context and approval | VS Code with GitHub Copilot |
| Client | Exchanges MCP messages with one server | The host's MCP connection |
| Server | Advertises capabilities and validates incoming requests | Local .NET server, then Azure Functions |
| Downstream service | Performs the underlying operation | Storage queue or Microsoft Graph |

One host can manage several clients and servers. An MCP server need not contain a language model.
> [!TIP]
> Do not send the whole conversation to a server when a narrow tool request is sufficient.

**Question:** which component displays the human approval, and which must enforce permissions?

<details>
<summary>Show answer</summary>

The host displays approval; the server and downstream service still enforce their own authorization.

</details>

## 3. What makes an agent?

An agent combines a model with an application loop. The model proposes a next action; application code
decides what may actually execute. MCP is one integration mechanism, not the agent itself.

| Building block | What to decide |
|---|---|
| Goal and instructions | What task is allowed? When should the agent stop? |
| Model | Can it select suitable tools and produce valid arguments? |
| Context and state | What information is relevant, and how long is it retained? |
| Tools | What operations are exposed, with what inputs and outputs? |
| Identity and policy | Whose permissions apply? Which actions need approval? |
| Evaluation and observation | Did the actual execution achieve the intended result? |

**Question:** can a strong model compensate for a missing server permission check?

<details>
<summary>Show answer</summary>

No. Instructions and model behavior are not access controls.

</details>

## 4. Tools, resources and prompts

| MCP capability | Purpose | Usual control |
|---|---|---|
| Tool | Execute an operation, including reads or writes | Model-selected, subject to application policy and approval |
| Resource | Expose contextual data identified by a uniform resource identifier (URI) | Application-managed context |
| Prompt | Offer a reusable message template | User-selected workflow |

These are interaction patterns, not mandatory user interface designs. Clients differ in supported features.
A resource is not an Azure resource, and an MCP prompt is not a secret system instruction.

**Classify:** checking service health is a tool; supplying a service manual could be a resource;
offering a reusable incident-summary template could be a prompt.

The workshop implements **tools**. Resources and prompts here are explanations, not deployed workshop features.

**Read:** [tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[resources](https://modelcontextprotocol.io/specification/2026-07-28/server/resources),
[prompts](https://modelcontextprotocol.io/specification/2026-07-28/server/prompts).

## 5. Read a tool contract before calling it

A useful tool has a precise name, description, input schema and a predictable result.
The description helps selection; the schema describes allowed inputs; the server must validate those inputs.

For this workshop's `get_service_health` tool:

- **Intention:** inspect synthetic service health, without changing data.
- **Input:** `service` is `workshop-api` or `ticket-queue`.
- **Output:** a synthetic health result, or an explicit tool error for invalid input.
- **Boundary:** no ticket is created, and no production health is queried.

`create_ticket` is different: it has a synthetic write side effect. Its description must make that explicit.
Read-only annotations are hints, not proof or permission enforcement.

**Question:** what should happen if a caller sends an unexpected argument?

<details>
<summary>Show answer</summary>

The server rejects it. It must not silently broaden the operation.

</details>

## 6. Follow one agent iteration

This is an illustrative sequence, not a live execution:

1. **Intention:** Alice asks for synthetic service health.
2. **Discovery:** the client requests `tools/list`.
3. **Selection:** the model proposes `get_service_health` with a supported service.
4. **Control:** the host applies its policy and approval requirements.
5. **Execution:** the client sends `tools/call`; the server validates identity, permissions and arguments.
6. **Observation:** the host receives the tool result and checks for errors.
7. **Next decision:** answer, make another justified call, or stop.

The model does not execute a tool merely by mentioning its name. An assistant's sentence claiming success
is not execution evidence. Inspect the actual tool-call record and result.

**Checkpoint:** identify the intention, selected tool, arguments, control decision and observed result in module 01.

## 7. Local and remote messages

MCP uses JavaScript Object Notation Remote Procedure Call (JSON-RPC) messages.
Standard input/output (stdio) connects a local client and process. Streamable Hypertext Transfer Protocol
(HTTP) carries remote requests. A browser GET is not a `tools/list` or `tools/call` test.

Version matters. The 2026-07-28 specification carries version and capability metadata per request.
Older implementations can use an `initialize` handshake. Follow the version supported by the actual
client and server; do not combine their message shapes.

The workshop validators construct the messages for their tested combination.
This page deliberately gives no partial JSON to copy as a runnable request.

**Read:** [transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports).

## 8. MCP, APIs, connectors and retrieval

| Mechanism | Main question |
|---|---|
| API | What operations and data does a service expose? |
| Connector | How does a product package an integration and its connection settings? |
| Retrieval-augmented generation (RAG) | What relevant knowledge should be retrieved to ground an answer? |
| MCP | How does a compatible host discover and use server capabilities? |

These mechanisms can work together. An MCP tool can call an API or retrieve documents.
MCP does not automatically add knowledge indexing, memory, identity or approval.

**Question:** does adding a server make every compatible agent safe to use with it?

<details>
<summary>Show answer</summary>

No. Check client support, identity flow, permissions, approval and logging separately.

</details>

## 9. Three independent controls

| Control | Question | Workshop example |
|---|---|---|
| Authentication | Who is calling? | Microsoft Entra token accepted for the MCP audience |
| Authorization | What may that identity do? | `Tools.Write` required for a write |
| Human approval | May this particular action run now? | Client confirmation before `create_ticket` |

A shared key identifies no individual user. A sign-in does not grant every tool.
Human confirmation cannot replace a missing server role check.

> [!WARNING]
> For a downstream API, obtain a separate token for that audience. Delegated On-Behalf-Of (OBO) access
> uses user context; managed-identity app-only access uses application permissions. Never pass the client token through.

**Question:** if Bob clicks Approve but lacks `Tools.Write`, should the write succeed?

<details>
<summary>Show answer</summary>

No. The authorization boundary must still refuse it.

</details>

## 10. On-Behalf-Of explained simply

**The question:** when the MCP server calls another API (Microsoft Graph, Storage…), **whose rights does it use?**

**Analogy.** A colleague runs an errand for you at the bank.

- **On-Behalf-Of (OBO):** they bring a mandate signed by you. The bank checks your account rights.
  They can never do more than you can.
- **App-only (managed identity):** they use the company card. The bank checks the company's rights,
  whoever asked for the errand.

**How OBO works, in three hops:**

1. The client sends the MCP server a token issued **for the MCP server** (audience = MCP API).
2. The server gives that token **only to Microsoft Entra ID** and asks: "the same user, but for Storage".
3. Entra returns a **new** token for Storage, still representing the user. The server calls Storage with it.

The client token is never forwarded to Storage. One token per hop, one audience per token.

![OBO and app-only calls obtain distinct Storage tokens after the MCP authorization boundary.](../assets/architecture/05.en.svg)

## 11. OBO or app-only: what to choose

| Question | On-Behalf-Of (user rights) | App-only (managed identity) |
|---|---|---|
| Who decides access to the data? | The **user's** own permissions | The **application's** permissions |
| Two users, same question | Can get different results (Alice yes, Bob no) | Always the same result |
| Main risk avoided | The server cannot exceed the user's rights | No dependency on each user's permissions |
| Main risk introduced | More moving parts: consent, user roles, token exchange errors | "Confused deputy": anyone allowed to call the tool reads what the app can read |
| Audit downstream | Shows the real user | Shows the application |
| Works without a signed-in user? | **No** (no background jobs, no app-to-app callers) | **Yes** |
| Typical use | Personal or sensitive data, per-user rights already exist | Shared reference data, scheduled jobs, same answer for everyone |

**Choose OBO when** the downstream system already holds per-user permissions you must respect,
or auditors need to see the real user on the data.

**Choose app-only when** every authorized caller should see the same data,
there is no user (automation), or the downstream API offers no delegated permission.
Then compensate with tight tool authorization (app roles) and a narrow role for the identity.

**Not a choice for MCP:** forwarding the client's token to the downstream API ("token passthrough"). It is forbidden.

## 12. What OBO implies for your implementation

| Area | What you must plan |
|---|---|
| Identity administrator | Delegated permissions on the MCP API registration, and **admin consent** for them |
| Server credential | OBO needs the server to prove its own identity. Use a **federated credential with a managed identity**, not a client secret |
| Downstream data | Each user needs a role on the data (here: Storage Blob Data Reader for Alice only) |
| Callers | Refuse app-only tokens on OBO tools: there is no user to act for |
| Errors | A downstream HTTP 403 comes back as an MCP **tool error inside HTTP 200**. Show it; do not hide it |
| Performance | One extra Entra call per downstream audience. Cache per user and audience, never across users |
| Policies | Conditional Access and user sign-in risk also apply to the exchange; the exchange can fail like a sign-in |

**Workshop example (module 05):** `whoami` and `read_report_as_user` use OBO; `read_report_as_app` uses a managed identity.
Alice and Bob ask the same question: only OBO shows a different answer.

**Question:** Bob has no Storage role. What does `read_report_as_user` return? And `read_report_as_app`?

<details>
<summary>Show answer</summary>

OBO returns a tool error for Bob (Storage refuses him). App-only returns the report, because the application may read it.

</details>

**Read:** [On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow),
[managed identity as federated credential](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity),
[module 05](../modules/05-delegated-and-app-only/README.md).

## 13. Descriptions and results are a trust boundary

Treat tool descriptions, retrieved documents and results as external input. They can contain misleading instructions.
Never let returned text grant itself a role, bypass approval or request credentials.

Expose narrow tools with bounded inputs and clear side effects. Ask for confirmation before writes.
Observe failures explicitly and limit retries to avoid repeated writes or unexpected cost.

In this workshop, logs contain metadata only: tool name, permitted caller identifier, outcome, latency and correlation.
Never log tokens, prompts, tool arguments or results. Do not copy a production payload to illustrate a lesson.

**What a trace does not prove:** an HTTP 200 can contain an MCP tool error. Gateway logs do not prove
human approval or show the model's reasoning. An app-only downstream log identifies the app, not the person.
Missing telemetry is not proof that no call happened. See [module 06](../modules/06-observe-inventory/README.md)
for the available fields and gaps.

**Read:** [tool-use guidance](https://learn.microsoft.com/azure/foundry/agents/concepts/tool-best-practice).
Its general tracing suggestions do not override this workshop's zero-body logging rule.

## 14. Place the workshop components

| Component | Role in the journey |
|---|---|
| VS Code and MCP Inspector | Discover tools and inspect actual calls |
| Azure Functions | Host this workshop's remote MCP implementation |
| Microsoft Entra ID | Authenticate the caller |
| Azure API Management | Apply gateway controls in module 04 |
| Storage and Microsoft Graph | Downstream operations with their own permissions |
| Application Insights | Payload-free evidence in later modules |

The separate [Azure MCP Server](https://learn.microsoft.com/azure/developer/azure-mcp-server/overview)
offers Azure management tools; it is not this workshop's five-tool server.
Do not use a broad management tool as a shortcut around the scoped workshop commands.

**Next:** use [module 01](../modules/01-discover-mcp/README.md) to see real local discovery and a synthetic read.
No Azure deployment is required for that demonstration.

## Sources

Last verified: 2026-10-16. Original generic explanations based only on public references; no private event content reused.

- [MCP architecture](https://modelcontextprotocol.io/specification/2026-07-28/architecture).
- [Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
  [resources](https://modelcontextprotocol.io/specification/2026-07-28/server/resources) and
  [prompts](https://modelcontextprotocol.io/specification/2026-07-28/server/prompts).
- [Transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports).
- [Microsoft MCP for Beginners](https://github.com/microsoft/mcp-for-beginners): optional further study; no code copied.
- [Foundry tool-use guidance](https://learn.microsoft.com/azure/foundry/agents/concepts/tool-best-practice).
- [Azure MCP Server overview](https://learn.microsoft.com/azure/developer/azure-mcp-server/overview).
- [Workshop governance boundaries](LEARNING-GUIDE.md) and their contextual identity sources.

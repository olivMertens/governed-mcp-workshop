# Sources and reuse decisions

Last verified: 2026-10-14. This is a design assessment, not evidence of a successful deployment.
Links were read from public upstream sources. Module 02 adapts the pinned Functions sample (see its section below
and THIRD-PARTY-NOTICES.md); it is authored and checked offline only, not deployed.
Module 01 now adapts the SDK bootstrap pattern; its provenance and complete upstream license are retained separately.
Versions below are reproducible reference selections or compatibility-test candidates, not a promise that every
combination has been tested together.

## Participant Azure CLI inspections and result captures

Last verified: 2026-10-20. Official command references:
[resource show](https://learn.microsoft.com/cli/azure/resource#az-resource-show),
[resource list](https://learn.microsoft.com/cli/azure/resource#az-resource-list),
[API Management show](https://learn.microsoft.com/cli/azure/apim#az-apim-show),
[identity show](https://learn.microsoft.com/cli/azure/identity#az-identity-show),
[Application Insights query](https://learn.microsoft.com/cli/azure/monitor/app-insights#az-monitor-app-insights-query),
[account show](https://learn.microsoft.com/cli/azure/account#az-account-show) and
[group exists](https://learn.microsoft.com/cli/azure/group#az-group-exists).
Authentication readback uses the existing `authsettingsV2` GET and API version 2024-11-01;
the [App Service V2 reference](https://learn.microsoft.com/rest/api/appservice/web-apps/get-auth-settings-v-2?view=rest-appservice-2024-11-01)
documents a `/list` read route, while this environment also accepts the existing non-`/list` GET.
No write operation is used.

With explicit session approval, read the existing author-owned non-production workshop resources and captured eight
new masked Azure CLI results for modules 00 and 02 through 07 and 99. Module 01 retains its real local Inspector image.
The tested CLI returned Function state, HTTPS and network access under `properties`, not the top-level aliases.
The new Function inspections therefore use `az resource show` with an explicit resource type and API version.
Capture assertions require `Running`, HTTPS enabled and public access disabled where applicable; null fields are rejected.
The telemetry query projects only HTTP codes and counts. No key, token, prompt, argument or tool result is collected.
Module 99 captures resources that still exist before cleanup, not a successful deletion.
No resource, identity or role was created, modified or deleted; the separate low-code paths were not redeployed or live-validated.

## Independent participant tracks

Module 03 French participant reassessment (last verified 2026-10-20):
reread [MCP authorization and PRM (Preview)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp),
[VS Code authentication](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode),
[Functions MCP tutorial](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial) and
[app roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).
The portal tutorials create a client secret by default; the workshop deliberately retains its existing secretless
configuration. Server admission is distinct from per-tool authorization: Bob can still write in module 03;
Eve signs into the tenant but cannot obtain the MCP token.
Azure CLI inspection references:
[Function show](https://learn.microsoft.com/cli/azure/functionapp#az-functionapp-show),
[filtered app settings](https://learn.microsoft.com/cli/azure/functionapp/config/appsettings#az-functionapp-config-appsettings-list),
[app registration show](https://learn.microsoft.com/cli/azure/ad/app#az-ad-app-show),
[service principal show](https://learn.microsoft.com/cli/azure/ad/sp#az-ad-sp-show) and
[az rest](https://learn.microsoft.com/cli/azure/reference-index#az-rest).
Terraform remains the only mutation path for Terraform-managed resources. New read-only snippets and expected
results are teaching instructions, not a new live deployment or a claim that the separate low-code guide is live-validated.

Editorial separation (2026-10-20): each deployed module now has a Terraform + PowerShell README
and a separate portal-first LOW-CODE guide in English and French. Module 00 also separates its tool
baseline so low-code does not execute Terraform; module 01 remains shared.
Deployment, identity, telemetry and cleanup instructions reuse the module sources and recorded examples below.
Existing live evidence does not validate the newly composed end-to-end guides.
Screenshots are existing author captures, not new low-code executions; missing captures are disclosed.

The additional low-code inspection reference uses
[az resource list](https://learn.microsoft.com/cli/azure/resource#az-resource-list)
with an explicit subscription, resource group and participant-tag query, and
[portal directory/subscription settings](https://learn.microsoft.com/azure/azure-portal/set-preferences).
These two references were reread on 2026-10-20. No resource or identity API was queried or changed.

## Concept and facilitator guides

Guided local exercise (last verified 2026-10-20):
[MCP tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools) distinguishes discovery,
tool invocation, annotation hints and tool errors. [Transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports)
and [architecture](https://modelcontextprotocol.io/specification/2026-07-28/architecture) explain client-launched stdio.
The [pinned C# SDK quickstart](https://github.com/modelcontextprotocol/csharp-sdk/blob/6fa3825973949a9c4f0cd8af344e15a8db09dc35/docs/concepts/getting-started.md)
and [Inspector guide](https://modelcontextprotocol.io/docs/tools/inspector) were reread without changing dependency pins.
The [Inspector CLI reference](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/cli) and a local run of
all four requests confirm that version 2.9.0 reports a tool error with `tool_is_error` and exit code 5.
Only the intentional refusal step accepts code 5; successful requests still require 0.
[VS Code MCP configuration](https://code.visualstudio.com/docs/agent-customization/mcp-servers) and
[approvals](https://code.visualstudio.com/docs/agents/run/approvals) remain separate from server authorization.
Module 01 now teaches four explicit requests, with recorded versus expected provenance and field comparisons.
The shared reader keeps each authored request together and reveals reference output without executing or accepting
output in the browser. No authentication, transport, deployment or architecture change is implied.

Reader repair and module 06/07 clarification (last verified 2026-10-16):
[API Management telemetry](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights)
documents sampling and request correlation; the shipped request query does not join `caller-oid` policy traces.
[MCP telemetry](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers) documents default dimensions,
tool-only fields and custom trace metadata; its optional payload capture is not adopted.
[API Center registration](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server)
is inventory, not runtime authorization.
[BYO registration](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) remains **Preview**.
[Foundry MCP authentication](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication)
distinguishes application and delegated user identities. The workshop's existing delegated-scope gateway
does not accept the project-managed-identity flow merely because an app role is assigned.
[Copilot Studio onboarding](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent)
documents a client secret in Manual OAuth setup. The workshop stops there rather than introducing a secret;
discovery is not evidence of a supported secretless connection.
These are documentation and local UI changes only. Existing Draw.io-derived 05/06/07 SVGs are reused unchanged.

MCP fundamentals page (2026-10-16): [English](MCP-CONCEPTS.md) and [French](fr/MCP-CONCEPTS.md)
provide original generic explanations of host/client/server, agent components, tools/resources/prompts,
discovery versus execution, local/remote transports, API/connector/retrieval differences and the three controls.
Only public references were used; private event planning and internal decks were excluded.
The [2026-07-28 architecture](https://modelcontextprotocol.io/specification/2026-07-28/architecture),
[tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[resources](https://modelcontextprotocol.io/specification/2026-07-28/server/resources) and
[prompts](https://modelcontextprotocol.io/specification/2026-07-28/server/prompts) were read directly.
[MCP for Beginners](https://github.com/microsoft/mcp-for-beginners) is linked for further study, without copied code.
[Foundry tool guidance](https://learn.microsoft.com/azure/foundry/agents/concepts/tool-best-practice)
does not override the workshop's zero-body logging rule.
[Azure MCP Server](https://learn.microsoft.com/azure/developer/azure-mcp-server/overview)
is distinguished from this workshop's server; no claim about current optional product support is inferred.
Protocol examples remain conceptual: per-request metadata and older initialization must not be mixed.

README presentation review (2026-10-16): [GitHub Mermaid diagrams](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams)
and [GitHub alerts](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts).
Module 99 reuses the existing Draw.io-derived Mermaid blocks and verified icon-rich SVGs.
The shared renderer preserves alert paragraphs, lists, code and ordinary blockquotes without loading external libraries.
This review covers formatting only, not Azure behavior or live clean-up.

Copy controls and read-only resource inspection (2026-10-16):
[Azure CLI resource listing](https://learn.microsoft.com/cli/azure/resource#az-resource-list) documents the
resource-group, subscription and tag filters used by the bilingual context guide.
The commands reuse the existing context guard and read only `resource_group_name` and `resource_tags`
from the local Terraform outputs. Ten mocked PowerShell scenarios check safe success, empty results,
missing context/state, mismatched tenant, invalid tags/JSON and CLI failures.
The initial evidence was mocked only. On 2026-10-16, an approved read-only check of the original tagged group
found that Azure CLI refuses `--tag` together with `--resource-group`. Both guides now keep exact group scoping
and filter the validated workshop tag in JMESPath. The corrected live query and the seven site tests pass.
The existing documentation portal returned HTTP 200 from `/health`; no MCP deployment or authentication success
is implied.

Module 02 preparation sources rechecked on 2026-10-16:
[pinned sample](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9),
[Functions quickstart](https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server),
[MCP bindings and System authorization](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp),
[Flex Consumption](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan) and
[management guide](https://learn.microsoft.com/azure/azure-functions/flex-consumption-how-to).
The workshop keeps pure Terraform rather than the quickstart's azd recipe and keeps System authorization
rather than the Entra-protected upstream sample's Anonymous setting.
[Official retail prices](https://prices.azure.com/api/retail/prices) were queried for West Europe in USD:
Flex On Demand execution time, execution count, Hot LRS Blob, LRS queue and Analytics Logs ingestion.
These are public unit prices, not an account quote or a spending cap. Free grants and negotiated discounts
are not assumed.

Last verified: 2026-10-14. The bilingual concept and facilitator guides summarize only public documentation and
reuse the existing Draw.io-derived architecture assets. They do not add another architecture source.

| Source | Use in the guides |
|---|---|
| [Access tokens](https://learn.microsoft.com/entra/identity-platform/access-tokens) and [claim validation](https://learn.microsoft.com/entra/identity-platform/claims-validation) | One token and audience per resource; platform validation of issuer, tenant, audience and expiry. |
| [Scopes](https://learn.microsoft.com/entra/identity-platform/scopes-oidc), [app roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps) and [API verification](https://learn.microsoft.com/entra/identity-platform/scenario-protected-web-api-verification-scope-app-roles) | Delegated `scp` and assigned `roles` have different purposes and are both enforced. |
| [On-Behalf-Of](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow), [secretless managed identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/secretless-authentication) and [managed-identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity) | Separate downstream user-context and app-only tokens without client secrets. |
| [App Service MCP authorization](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp) | Protected Resource Metadata is **Preview** and token passthrough to downstream resources is unsafe. |
| [Secure MCP servers](https://learn.microsoft.com/azure/api-management/secure-mcp-servers), [monitor MCP traffic](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers) and [programmatic MCP management](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) | Gateway authorization, payload-free workshop logging, and MCP management API `2025-09-01-preview` (**Preview**). |
| [MCP rug-pull attack](https://learn.microsoft.com/security/zero-trust/catalog-ai-attack-techniques/rug-pull-attack) and [prompt injection](https://learn.microsoft.com/security/zero-trust/catalog-ai-attack-techniques/prompt-injection) | Public threat descriptions and recommended layered controls. |
| [Agent 365 with API Management](https://learn.microsoft.com/azure/api-management/agent-365) | Optional facilitator-only **Preview** inventory and blocking; AI Gateway tier is **Preview** and outside the core path. |
| [Foundry MCP authentication](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication) | Optional identity passthrough is marked **Preview** where documented and never permits downstream token passthrough. |

## Selection method

### Progressive teaching interface

Last verified: 2026-10-16. The shared reader uses the existing EN/FR module guides,
[Azure context guide](DEPLOYMENT.md), [presenter guide](PRESENTER.md), [workspace guide](GETTING-STARTED.md)
and [hosting guide](HOSTING.md). It follows authored headings and numbered actions, not inferred command boundaries.
Complete fenced blocks and nested disclosures remain intact. Long blocks are closed references, not default bulk-copy exercises.
The local MCP lesson, resource inspection and presenter commands now separate intention, prediction, action and observation.
The delegation lesson separates planning, explicit approval, apply and the private administrator handoff.
No new upstream code or package was introduced. Existing API/SDK links and Preview labels remain authoritative.

### Contextual authentication references

Links last verified: 2026-10-16. Modules 02 to 05 now place these references next to their expected demonstrations
in both README languages. The application exports the same text; no independent source list or live result is invented.
SDK reference pages can show newer packages than the workshop pins. Keep the checked-in package versions and lock files.

| Module | Demonstrated mechanism and Microsoft Learn reference |
|---|---|
| 02 | [System keys](https://learn.microsoft.com/azure/azure-functions/function-keys-how-to), [MCP extension configuration](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp), [tool trigger](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp-tool-trigger), [Queue authorization](https://learn.microsoft.com/azure/storage/queues/authorize-access-azure-active-directory), [QueueClient.SendMessageAsync](https://learn.microsoft.com/dotnet/api/azure.storage.queues.queueclient.sendmessageasync); optional private storage: [Functions networking (Flex subnet, delegation)](https://learn.microsoft.com/azure/azure-functions/functions-networking-options), [secured storage account](https://learn.microsoft.com/azure/azure-functions/configure-networking-how-to#restrict-your-storage-account-to-a-virtual-network), [Storage private endpoints](https://learn.microsoft.com/azure/storage/common/storage-private-endpoints) and [default outbound access](https://learn.microsoft.com/azure/virtual-network/ip-services/default-outbound-access) (verified 2026-10-16). |
| 03 | [Built-in authentication](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization), [authsettingsV2 properties](https://learn.microsoft.com/azure/templates/microsoft.web/sites/config-authsettingsv2), [MCP authorization and PRM (**Preview**)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp), [access tokens](https://learn.microsoft.com/entra/identity-platform/access-tokens), [assignment required](https://learn.microsoft.com/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users), [scopes/consent](https://learn.microsoft.com/entra/identity-platform/scopes-oidc) and [app roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps). |
| 04 | [MCP security](https://learn.microsoft.com/azure/api-management/secure-mcp-servers), [validate-azure-ad-token](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy), [MCP management API (**Preview**)](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api), [choose](https://learn.microsoft.com/azure/api-management/choose-policy), [policy expressions](https://learn.microsoft.com/azure/api-management/api-management-policy-expressions), [rate-limit-by-key](https://learn.microsoft.com/azure/api-management/rate-limit-by-key-policy), [Functions networking](https://learn.microsoft.com/azure/azure-functions/functions-networking-options), [MCP proxy](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server), [default MCP telemetry](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers) and [trace](https://learn.microsoft.com/azure/api-management/trace-policy). |
| 05 | [OBO flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow), [OnBehalfOfCredential](https://learn.microsoft.com/dotnet/api/azure.identity.onbehalfofcredential), [Graph GET /me](https://learn.microsoft.com/graph/api/user-get?view=graph-rest-1.0), [Blob authorization](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory), [Get Blob authorization](https://learn.microsoft.com/rest/api/storageservices/get-blob#authorization), [DownloadContentAsync](https://learn.microsoft.com/dotnet/api/azure.storage.blobs.specialized.blobbaseclient.downloadcontentasync), [managed identities](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview), [ManagedIdentityCredential](https://learn.microsoft.com/dotnet/api/azure.identity.managedidentitycredential) and [federated application trust](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity). |

Documentation gaps and guardrails: the general token page mentions online decoders; never submit workshop tokens.
The general OBO article includes client-secret examples; use the managed-identity assertion path instead.
The MCP monitoring article describes optional argument/result capture; the workshop keeps payload logging disabled.
These links do not change controls, consent requirements, module statuses or deployment evidence.

Choose the smallest example that teaches one workshop outcome and can be validated and cleaned up by a participant.
Prefer official samples and standards. Check the actual files, not only marketing descriptions.
Keep the five synthetic tools and one identity story throughout the workshop.
Translate useful infrastructure concepts to Terraform and participant steps to PowerShell first, then bash.
Do not import notebooks, external data sources, model deployments, complete catalogs, or unrelated agent demos.

## Workstation choice and participant isolation

Last verified: 2026-10-14. [Start guide](GETTING-STARTED.md), [French guide](fr/GETTING-STARTED.md).
Take the official container workflow, not a second deployment implementation.
Both workstation routes call the same PowerShell tool checks and private parameter generator.
The Terraform foundation uses the already selected AzureRM 5.9.0 provider; it does not import sample code.
Provider-mocked plans are local evidence only. Container builds and fresh-subscription checks remain pending.

| Source | Useful guidance and workshop decision |
|---|---|
| [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers) | Reopen a checkout in a reviewed Linux container; use the startup log and the same checks as the local route. This is VS Code, not Visual Studio IDE. |
| [Alternative engines](https://code.visualstudio.com/remote/advancedcontainers/docker-options) | Podman 5+ can be selected explicitly through the Docker Path setting; CLI presence is not daemon reachability or full support. No automatic engine switch or VM creation. |
| [Official Features](https://github.com/devcontainers/features) and [JSON specification](https://containers.dev/implementors/json_reference/) | Pin base/Features by immutable digest, select exact tool versions, avoid credential/socket mounts and keep creation hooks free of cloud sign-in/deployment. |
| [Azure naming](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules) | Save a fresh 64-bit cryptographic suffix once. Preserve legacy 10-hex names. Storage keeps all random bits within 24 lowercase alphanumeric characters; Functions within the first 32 host-ID characters. Group uniqueness is subscription-scoped; Storage/app/API Management names have global constraints. Eleven mock plans check bounds, shared-group isolation and old names. Randomness is not a name reservation or quota increase. |
| [Azure quota limits](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits) | Random groups do not reset subscription, regional or service capacity. Plan cohort capacity separately. |
| [AzureRM group](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group) and [existing group](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/data-sources/resource_group) | Manage only a dedicated workshop group, or read an administrator-provided group. Keep nonempty-group deletion protection and disable automatic provider registration. |
| [Terraform mocks](https://developer.hashicorp.com/terraform/language/tests/mocking) and [state](https://developer.hashicorp.com/terraform/language/state) | Prove plan shape and ownership boundaries without Azure calls; preserve private parameters and one isolated state across modules/workstations. |

Verified public OCI selections:
`mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae`.
Feature digests are in `.devcontainer/devcontainer.json`; exact published tags were checked for Azure CLI 1.3.0,
Terraform 1.5.0, .NET 2.5.0, PowerShell 2.0.3 and Node 2.1.1.
Tools: Azure CLI 2.88.0, Terraform 1.16.6, .NET 10.0.402, PowerShell 7.6.6, Node 22.22.0,
Functions Core Tools 4.14.0. These are preparation selections, not a tested container/runtime combination.
The base index includes linux/amd64 and linux/arm64; that does not prove every feature/tool runs on both.
No engine was reachable on the Windows ARM64 authoring host. No engine or machine was started.

## Module 00 implementation and optional portal

Last verified: 2026-10-14. This iteration implements module 00 only; later runtime roots remain absent.
The code uses existing patterns plus original checks/server logic, not copied sample application source.

| Source | Verified decision |
|---|---|
| [Terraform release 1.16.6](https://releases.hashicorp.com/terraform/1.16.6/) and [checkpoint API](https://checkpoint-api.hashicorp.com/v1/check/terraform) | Release became current during this iteration. Updated container/minimum/check fixtures consistently; tested a session-local Windows binary against its official SHA-256 checksum without replacing the user's installation. |
| [AzureRM 5.9.0 metadata](https://registry.terraform.io/v1/providers/hashicorp/azurerm/5.9.0) and [Linux web app schema](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/linux_web_app) | Existing exact provider pin and lock are retained. Actual schema validation and eleven mock plans cover naming isolation, optional B1 Linux hosting, disabled basic publishing, TLS, runtime and default-off behavior. No unused AzureAD/AzAPI providers are added. |
| [Functions Core Tools 4.14.0 release](https://github.com/Azure/azure-functions-core-tools/releases/tag/4.14.0) | Known npm shim was incomplete and did not prove compatibility. Verified the official minimal Windows ARM64 asset against its published SHA-256 digest and ran version/tool checks in session scope, without altering global tools. A container build and Functions tool calls remain separate. |
| [ARM permissions API](https://learn.microsoft.com/rest/api/authorization/permissions/list-for-resource-group?view=rest-authorization-2022-04-01) | Read effective grants at subscription or existing-group scope, subtract each record's notActions, combine grants, validate same-scope HTTPS pagination. Do not infer rights from role names or claim absence of deny assignments/Policy. |
| [Subscription limits](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits) | New-group foundation checks the documented 980 group limit. Existing-group mode does not consume a new group. Names do not change quota. |
| [Flex hosting](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan) | Linux isolated .NET 10 is listed. Quota is regional/subscription-shared memory; review the documented portal diagnosis, not an invented quota metric. Stage evidence is a private human review, not a live reservation. |
| [Pinned Azure CLI 2.88.0 runtime helper](https://github.com/Azure/azure-cli/blob/azure-cli-2.88.0/src/azure-cli/azure/cli/command_modules/appservice/custom.py) | `list-flexconsumption-locations` exposes name; direct runtimes expose name/version. Use the documented command without an unsupported runtime-version flag. Source inspected for schema only, not copied. |
| [Node App Service](https://learn.microsoft.com/azure/app-service/configure-language-nodejs) | Listen on PORT, use an explicit Node 22 startup command, no implicit PM2/Oryx build. Public documentation only; no identity, API or credential collection. |
| [Deployment authentication](https://learn.microsoft.com/azure/app-service/deploy-authentication-types) | Azure CLI 2.48.1+ supports Entra with `az webapp deploy` when SCM basic publishing is disabled. Baseline 2.88.0 exceeds this. No key/profile fallback. |
| [Run from ZIP](https://learn.microsoft.com/azure/app-service/deploy-run-package) | Read-only package root with WEBSITE_RUN_FROM_PACKAGE=1; ZIP contains content, not its enclosing directory. Build only the explicit public allowlist and reviewed stdlib server. |
| [App Service pricing](https://azure.microsoft.com/pricing/details/app-service/linux/) | Basic B1 is provisioned paid capacity, opt-in only. No invented price, no free-hosting claim; stopping the site does not remove plan charges. |

The HTML quickstart URL now presents Static Web Apps guidance, not a reason to mix its deployment with
traditional App Service. ACA/private-portal authentication remains separate and unimplemented.
Local public server, ZIP boundary and synthetic deployment/preflight tests do not prove a live deployment.

## Upstream snapshots

### Module 01 local implementation

Last verified: 2026-10-14. [Runnable EN/FR guide](../modules/01-discover-mcp/README.md)
and [license/provenance](../modules/01-discover-mcp/UPSTREAM.md).
The official SDK 2.2.0 quickstart and actual v2 source APIs were used, not the unversioned documentation site's v1 redirect.
NuGet packages ModelContextProtocol 2.2.0 and Microsoft.Extensions.Hosting 10.0.13 are exact pins with a transitive lock.
The official SDK negotiates protocol 2026-07-28 in the actual local validator.
Pinned Inspector 2.9.0 CLI also discovers and calls the same compiled server.
The modern protocol rejects legacy `ping`; the validator proves recovery after rejected input by repeating
`tools/list`, not by assuming that an API present in the SDK is supported in every protocol era.
These are local process tests, not future Functions/APIM compatibility or manual approval evidence.

- [SDK quickstart at the selected commit](https://github.com/modelcontextprotocol/csharp-sdk/blob/6fa3825973949a9c4f0cd8af344e15a8db09dc35/docs/concepts/getting-started.md).
- [SDK session/version API](https://github.com/modelcontextprotocol/csharp-sdk/blob/6fa3825973949a9c4f0cd8af344e15a8db09dc35/src/ModelContextProtocol.Core/McpSession.cs).
- [SDK stdio process/environment/stderr options](https://github.com/modelcontextprotocol/csharp-sdk/blob/6fa3825973949a9c4f0cd8af344e15a8db09dc35/src/ModelContextProtocol.Core/Client/StdioClientTransportOptions.cs).
- [Tool annotations and errors](https://github.com/modelcontextprotocol/csharp-sdk/blob/6fa3825973949a9c4f0cd8af344e15a8db09dc35/src/ModelContextProtocol.Core/Server/McpServerToolAttribute.cs).
- [NuGet SDK](https://www.nuget.org/packages/ModelContextProtocol/2.2.0) and [Hosting](https://www.nuget.org/packages/Microsoft.Extensions.Hosting/10.0.13).
- [VS Code approvals](https://code.visualstudio.com/docs/agents/run/approvals): Manual permissions, individual pre-approval
  and per-tool false eligibility; client settings can change the actual prompt. No global auto-approval.
- [MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector): CLI discovery and explicit call, memory-only settings.

### Module 02 authored implementation (not deployed)

Last verified: 2026-10-14. [EN/FR guide](../modules/02-open-server/README.md),
[license notices](../THIRD-PARTY-NOTICES.md). Adapted from the pinned Functions sample
`468c518c884ec318e3001b9573254c9e775409c9` (MIT): `src/FunctionsMcpTool/FunctionsMcpTool.csproj`, `Program.cs`,
`host.json`, the `HelloTool.cs` trigger pattern, and `infra/main.bicep`, `infra/app/api.bicep`, `infra/app/rbac.bicep`
translated to Terraform. Only offline checks ran; no Azure or Entra change.

| Pin or source | Value and decision |
|---|---|
| NuGet `Microsoft.Azure.Functions.Worker` | `2.52.0` (exact, upstream value) |
| NuGet `Microsoft.Azure.Functions.Worker.Sdk` | `2.0.7` (exact, upstream value). Generates the WebJobs extension project at build time: `Microsoft.Azure.Functions.Extensions.Mcp` `1.5.0`, outside the lock file. |
| NuGet `Microsoft.Azure.Functions.Worker.Extensions.Mcp` | `1.5.0` (exact). `ConfigureMcpTool(...).WithInputSchema` used for explicit schemas; `ToolInvocationContext.Arguments` read and validated by the server. |
| NuGet `Azure.Identity` / `Azure.Storage.Queues` | `1.21.0` (upstream value) / `12.24.0` (workshop addition for the managed-identity ticket queue) |
| Test packages | `Microsoft.NET.Test.Sdk` `18.0.1`, `xunit` `2.9.3`, `xunit.runner.visualstudio` `3.1.5`; both projects have `packages.lock.json` |
| Not imported | `Microsoft.Azure.Functions.Worker.Extensions.Mcp.Sdk` `1.0.0-preview.4` (**Preview**), Graph, QRCoder, Blob extension, Apps/prompts/resources samples |
| NuGet OpenTelemetry (module 06) | `Microsoft.Azure.Functions.Worker.OpenTelemetry` `1.2.0`, `OpenTelemetry.Extensions.Hosting` `1.19.1`, `Azure.Monitor.OpenTelemetry.Exporter` `1.10.0` (exact). Traces only, exported with the Function's managed identity; logs keep the host path. |
| [Functions MCP bindings](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp) | `webhookAuthorizationLevel` defaults to `System`; `mcp_extension` system key in `x-functions-key`; HTTP 401 without it; Streamable HTTP at `/runtime/webhooks/mcp`. No queue roles are granted to the host (the SSE-only queue-role scope is not re-verified this session). |
| [MCP tool trigger](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp-tool-trigger) | `McpToolTrigger` + `ToolInvocationContext`; properties optional unless marked required. |
| [Identity-based connections](https://learn.microsoft.com/azure/azure-functions/functions-identity-based-connections-tutorial) | Storage Blob Data Owner is the minimum host role for identity-based `AzureWebJobsStorage`. |
| [Flex Consumption](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan) and [deployment how-to](https://learn.microsoft.com/azure/azure-functions/flex-consumption-how-to) | Lowest maximum scale is 1; 2048 MB instances; `az functionapp deployment source config-zip` deploys a package. |
| [AzureRM 5.9.0 Flex resource source](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/internal/services/appservice/function_app_flex_consumption_resource.go) | Writes `AzureWebJobsStorage` with an empty account key even for identity storage; user `app_settings` take precedence, so the workshop sets it to an empty value and expects an in-place diff. |
| [Azure CLI `functionapp keys`](https://learn.microsoft.com/cli/azure/functionapp/keys) | `--key-type systemKeys` to read or rotate `mcp_extension`; output suppressed with `--output none`. |
| [Terraform test mocks](https://developer.hashicorp.com/terraform/language/tests/mocking) | `override_during = plan` on the mock provider makes synthetic IDs and endpoints known in plan-only runs. |

### Module 03 authored implementation (not deployed)

Last verified: 2026-10-14. [EN/FR guide](../modules/03-entra-authentication/README.md), [infra/entra](../infra/entra/README.md),
[identity request](requests/identity-request.md). Adapted from the pinned sample's `infra/app/entra.bicep` and the
`authsettingsV2` block of `infra/app/api.bicep` (MIT, see THIRD-PARTY-NOTICES.md). Only offline checks ran: no plan against
Azure or Entra, no apply, no object created.

| Pin or source | Value and decision |
|---|---|
| [AzureAD 3.10.0](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0/docs) | Exact pin, lock file committed (`infra/entra/.terraform.lock.hcl`). `azuread_application_identifier_uri` requires `ignore_changes = [identifier_uris]` on the application; `azuread_application_pre_authorized` is a separate resource. |
| [AzureAD 3.10.0 `azuread_user` source](https://github.com/hashicorp/terraform-provider-azuread/blob/v3.10.0/internal/services/users/user_resource.go) | `password` is required at creation and stored in state (no write-only attribute). **Decision:** never create users in Terraform; accept existing object IDs. |
| [AzureRM 5.9.0 Flex `auth_settings_v2`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown) | Schema inspected locally: `active_directory_v2` with `client_id`, `tenant_auth_endpoint`, `allowed_audiences`, `allowed_applications`; `login` block required. **AzAPI is not needed.** |
| [App Service MCP authorization](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp) | Server-level access only, not per tool. PRM via `WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES` is **Preview**. Pre-authorize clients because VS Code shows no consent prompt. No token passthrough. |
| [App Service MCP and VS Code](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode) | VS Code client ID `aebc6443-996d-45c2-90f0-388ff96faa56` in **both** allowed client applications and pre-authorized applications. Portal path creates a client secret: not followed. |
| [Functions MCP tutorial](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial) | Disable the key gate with app setting `AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel=Anonymous` (equivalent to host.json, no republish). Require authentication, HTTP 401. One-click portal MCP auth is **Preview** and creates registrations and a secret: not used. Self-hosted MCP (**Preview**) not used. |
| [PRM in App Service authentication](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization#protected-resource-metadata-preview) | PRM `resource`, `authorization_servers`, `scopes_supported`; the 401 challenge carries the metadata URL, so the validator follows `resource_metadata` rather than hard-coding a path. |
| [App roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps) | Allowed member types User vs Application; `roles` claim only for assigned principals. |
| Azure CLI client ID `04b07795-8ddb-461a-bbee-02f9e1bf7b46` | Well-known first-party public client; pre-authorized so `az account get-access-token --resource api://<client-id>` works without consent for the validator. |

**Gaps between the sources and the build plan, and decisions:**

- The plan says "VS Code client ID from the sample". At the pinned commit the sample does not hard-code it: its README sets
  `PRE_AUTHORIZED_CLIENT_IDS=aebc6443-…`; Microsoft Learn documents the same ID. Used as default.
- The sample's Application ID URI is `api://<name>-<uniqueString>`; the workshop uses `api://<client-id>`, the form shown by
  Learn and accepted by tenants that restrict custom identifier URIs.
- The sample sets `clientSecretSettingName` to a managed-identity federated credential override and enables the token store
  for browser sign-in and On-Behalf-Of. Module 03 only validates bearer tokens: no secret setting, no federated credential,
  token store off. Module 05 adds the federated credential.
- The sample's allowed applications include the API's own client ID (for its browser login); the workshop allows only the
  pre-authorized clients.
- The sample requests Graph `User.Read` on the API registration; module 03 requests no API permission (no consent needed).
- Learn disables the key gate in the same step as enabling authentication. AzureRM writes app settings and auth settings in
  separate calls, so the workshop uses two applies (`entra_auth_replace_key_gate`) and reverses them in clean-up.
- Test users: the plan suggests creating Alice/Bob/Eve; the AzureAD provider would put their password in state, so the
  workshop accepts existing accounts only (deviation, see progress).
- Per-tool authorization: Learn states built-in authorization is server-level; Bob can still call `create_ticket` until module 04.

### Module 04 authored implementation (not deployed)

Last verified: 2026-10-15. [EN/FR guide](../modules/04-governed-gateway/README.md),
[policies](../modules/04-governed-gateway/policies/), `infra/workload/network.tf`, `gateway.tf`, `diagnostics.tf`.
Policies adapted from the AI-Gateway lab `mcp-prm-oauth` at the pinned commit below (MIT, see THIRD-PARTY-NOTICES.md).
Only offline checks ran: no plan against Azure, no apply, no resource created.

| Pin or source | Value and decision |
|---|---|
| [AzAPI 2.13.0](https://registry.terraform.io/providers/Azure/azapi/2.13.0/docs) | Exact pin, added to `infra/workload/.terraform.lock.hcl` (five platforms). Used only for the MCP server API, its policy and diagnostic, and the metadata API/operation/policy at `2025-09-01-preview` (**Preview**). `skip_provider_registration = true`, CLI credentials, like AzureRM. |
| [AzureRM 5.9.0 API Management](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/api_management.html.markdown) | `sku_name = "StandardV2_1"`, `virtual_network_type = "External"` + `virtual_network_configuration` for v2 outbound integration (no provider block on V2, verified in the v5.9.0 resource source). Logger `application_insights.identity_client_id` and diagnostic `body_bytes`/`headers_to_log` inspected in the local provider schema. |
| [Manage MCP servers programmatically](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) | Passthrough server: `type: mcp`, `mcpProperties.transportType: streamable`, one endpoint `{name, uriTemplate: "/mcp"}`, `serviceUrl` = backend base. **Decision:** `serviceUrl = https://<function-host>/runtime/webhooks`, `subscriptionRequired = false` (Learn's Terraform example uses `true` with a product; the workshop uses Entra tokens only). |
| [Expose an existing MCP server](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server) | Global-scope frontend response payload bytes must be 0; never access the response body in MCP policies (buffers the stream). Client URL `https://<apim>.azure-api.net/<path>/mcp`. |
| [Secure MCP servers](https://learn.microsoft.com/azure/api-management/secure-mcp-servers) | Inbound `validate-azure-ad-token`; subscription-key option not used. Authorization header forwarding to the backend is explicit in the inbound section. |
| [validate-azure-ad-token](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy) | `tenant-id`, `client-application-ids`, `audiences`, `required-claims` (`scp` with separator), `output-token-variable-name` (Jwt object for `oid` and `roles`). Validation failures go to `on-error` (`context.LastError.Source`). |
| [rate-limit-by-key](https://learn.microsoft.com/azure/api-management/rate-limit-by-key-policy) | Maximum renewal period 300 s; v2 uses a token bucket; limits are approximate, so the validator sends the limit plus 10 calls. |
| [ip-filter](https://learn.microsoft.com/azure/api-management/ip-filter-policy) | Single addresses or `from`/`to` ranges only (no CIDR): Terraform converts CIDR to ranges; at least one element required, so the policy is rendered only when ranges exist. |
| [Application Insights integration](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) | Connection string with managed identity (recommended, REST/IaC only; portal uses instrumentation keys). Identity needs Monitoring Metrics Publisher on the component. A more specific (API) logger setting overrides all-APIs. |
| [Standard v2 outbound integration](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound) | Same region and subscription; dedicated subnet delegated to `Microsoft.Web/serverFarms`, minimum /27 (recommended /24), NSG required with outbound Key Vault 443; inbound NSG rules do not apply; gateway stays public. |
| [App Service private endpoints](https://learn.microsoft.com/azure/app-service/overview-private-endpoint) | Sub-resource `sites`, zone `privatelink.azurewebsites.net` (zone group adds app and `scm` records), disable public access for isolation, public callers get HTTP 403, access restrictions are not evaluated for private endpoint traffic. |
| [Functions networking options](https://learn.microsoft.com/azure/azure-functions/functions-networking-options) | Flex Consumption supports inbound private endpoints; deployment through restricted networks needs a separate path (open item). |
| [AI-Gateway `mcp-prm-oauth` lab](https://github.com/Azure-Samples/AI-Gateway/tree/1679e3137d2fe7592d2a668d77ff71550d35b69e/labs/mcp-prm-oauth) | `mcp-api.policy.xml` (token validation, 401 challenge in `on-error`) and `mcp-prm.policy.xml` (RFC 9728 JSON on a `.well-known/oauth-protected-resource` API). Adapted, see decisions below. |
| [AI-Gateway `mcp-client-authorization` lab](https://github.com/Azure-Samples/AI-Gateway/tree/1679e3137d2fe7592d2a668d77ff71550d35b69e/labs/mcp-client-authorization) | Inspected only. It emulates an OAuth server in API Management with encryption keys in named values and a session check: **not used** (secret material, not Entra validation). Its MCP API diagnostic uses verbose logging without body-byte limits: not copied. |

**Gaps between the sources and the build plan, and decisions:**

- Endpoint shape: Learn uses `mcpProperties.endpoints` as an array of `{name, uriTemplate}`; the PRM lab uses an object map
  (`endpoints: { mcp: { uriTemplate } }`); the client-authorization lab sets only `transportType`. The workshop follows Learn.
- Audience: the PRM lab also accepts `{{APIMGatewayURL}}/{{McpApiPath}}` as an audience and advertises a gateway-URL scope.
  The workshop accepts only the module 03 MCP API (`api://<client-id>` and its client ID) and advertises
  `api://<client-id>/user_impersonation`: one logical resource, no broadened audience (BUILD-PLAN token boundary).
- Forwarding: `secure-mcp-servers` says headers are forwarded automatically, then shows `set-header Authorization` "in the
  outbound policy". The workshop sets it in the inbound section, after validation, and documents that the token goes only to
  the same logical resource (the Function), never downstream.
- Resources: the existing-server article says tools and resources are supported; the overview says tools only. The workshop
  exposes tools only.
- Diagnostics: Learn requires frontend response bytes 0 at global scope; the workshop sets 0 for all four directions at both
  scopes and logs no header.
- Inspector: Learn still suggests 0.9.0 for APIM tests; the workshop keeps 2.9.0 (module 01) and validates with HTTP scripts.
- The per-tool role check, the JSON-RPC parsing and streaming through the gateway are policy expressions that cannot run
  offline; they are proven only by the live persona checks.

### Module 04 optional part B authored implementation (not deployed)

Last verified: 2026-10-19. `infra/workload/rest-mcp.tf`, `policies/rest-api.xml`, `policies/rest-mcp-server.xml`,
`validate-rest-mcp.ps1`, `cleanup.ps1 -Scope RestDemo`. Only offline checks ran: no plan against Azure, no apply.

| Source | Value and decision |
|---|---|
| [Expose a REST API in API Management as an MCP server](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server) | Tiers Developer, Basic, Basic v2, Standard, Standard v2, Premium, Premium v2. Tools only (no MCP resources or prompts); not in workspaces; policies at MCP server scope apply to every tool; never access `context.Response.Body`; all-APIs frontend response payload bytes 0. **Decision:** reuse the module 04 Standard v2 instance and its all-APIs diagnostic; no API-scope diagnostic in part B. |
| [Manage MCP servers programmatically](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api), "ARM and Bicep templates > REST API-backed MCP server" | `Microsoft.ApiManagement/service/apis@2025-09-01-preview` with `type: mcp` and no `mcpProperties` (**Preview**), then `Microsoft.ApiManagement/service/apis/tools@2025-09-01-preview` with `displayName`, `description`, `operationId` = full resource ID of the backing operation (**Preview**). The template uses `subscriptionRequired: true` and a product; **decision:** `false`, Entra token and app roles only, no product. |
| [mock-response policy](https://learn.microsoft.com/azure/api-management/mock-response-policy) | API scope allowed; prefers the operation's response examples for the status code and content type. Used so the backing REST API returns synthetic Contoso data without a backend. |

**Open questions for the live run (not answerable offline):** whether API Management runs the backing REST API's policies
(`validate-azure-ad-token` then `mock-response`) for an MCP tool call; whether `tools/list` uses the tool resource name or its
`displayName` (both are set to `list_tickets` / `get_ticket`); the input-schema property name APIM derives for the
`ticketId` template parameter; and whether the provider's embedded schema knows the `apis/tools` type (schema validation is
disabled on that resource only).

### Module 05 authored implementation (not deployed)

Last verified: 2026-10-15. [EN/FR guide](../modules/05-delegated-and-app-only/README.md), `src/FunctionsMcpServer`
(`Identity/DownstreamCredentials.cs`, `Logic/CallerContext.cs`, `Logic/DelegatedTools.cs`, `Logic/DownstreamClients.cs`),
`infra/entra/delegation.tf`, `infra/workload/delegated-access.tf`. Patterns adapted from the pinned sample's
`HelloToolWithAuth.cs` and `infra/app/entra.bicep` / `api.bicep` (MIT, see THIRD-PARTY-NOTICES.md).
Only offline checks ran: no plan against Azure or Entra, no apply, no object created.

| Pin or source | Value and decision |
|---|---|
| [On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow) | The assertion must carry the middle tier's own audience; never send middle-tier tokens anywhere else; OBO works for **user principals only** (app-only callers use client credentials); only delegated scopes flow, roles stay with the user; admin consent for the middle tier avoids per-user consent; `.default` must not be combined with other delegated scopes. **Decision:** separate OBO requests for `https://graph.microsoft.com/User.Read` and `https://storage.azure.com/user_impersonation`; app-only callers refused. |
| [App trusts a managed identity](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity) | Issuer `https://login.microsoftonline.com/{tenant}/v2.0`, subject = the user-assigned identity's **principal (object) ID**, case-sensitive, audience `api://AzureADTokenExchange` (global cloud), app and identity in the same tenant, max 20 credentials, wrong values fail only at exchange, Application Administrator / Cloud Application Administrator / Application Developer or owner. .NET example: `ManagedIdentityCredential` token for `api://AzureADTokenExchange/.default` as `ClientAssertionCredential` callback. |
| [Certificateless Microsoft.Identity.Web](https://learn.microsoft.com/entra/msidweb/authentication/certificateless) | `SignedAssertionFromManagedIdentity` source type for ASP.NET Core APIs that validate tokens themselves. **Not used:** built-in authentication validates the token; Azure.Identity `OnBehalfOfCredential` with an assertion callback, as in the sample. |
| [Pinned sample `HelloToolWithAuth.cs`](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/blob/468c518c884ec318e3001b9573254c9e775409c9/src/FunctionsMcpTool/HelloToolWithAuth.cs) | Reads the user token from `X-MS-TOKEN-AAD-ACCESS-TOKEN` or `Authorization`, the tenant from `X-MS-CLIENT-PRINCIPAL`, builds `OnBehalfOfCredential(tenant, WEBSITE_AUTH_CLIENT_ID, MI assertion callback, userToken)`, falls back to a developer `ChainedTokenCredential` in Development, returns display name and mail. **Changes:** no developer fallback, token store off (Authorization only), tenant/oid/scp from the platform principal with a tenant match, app-only refusal, Graph `$select=id` and persona label only, explicit settings. |
| [Pinned sample `infra/app/entra.bicep`](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/blob/468c518c884ec318e3001b9573254c9e775409c9/infra/app/entra.bicep) | `requiredResourceAccess` Graph `User.Read` (`e1fe6dd8-ba31-4d61-89e7-88639da4683d`), federated credential with issuer `{loginEndpoint}{tenant}/v2.0`, subject = managed identity principal ID, audience `api://AzureADTokenExchange`. `api.bicep` reuses one identity for host storage and the assertion and sets `OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID`. **Changes:** Storage `user_impersonation` added, scope IDs read from the tenant, consent opt-in, two new identities. |
| [Grant tenant-wide admin consent](https://learn.microsoft.com/entra/identity/enterprise-apps/grant-admin-consent) | Cloud Application Administrator / Application Administrator can grant delegated permissions for any API; Privileged Role Administrator only for Graph app roles. Grants are not reviewed once made programmatically: kept as an explicit administrator opt-in. |
| Azure Storage delegated permission | Resource app ID `e406a681-f3d4-42a8-90b6-c2b029497af1`, delegated `user_impersonation`, token scope `https://storage.azure.com/user_impersonation` (Learn: Fabric data-plane and Entra app tutorials, [Authorize with Microsoft Entra ID](https://learn.microsoft.com/rest/api/storageservices/authorize-with-azure-active-directory)). Scope ID read from the tenant's service principal. |
| [Assign a role for blob data access](https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access) | Storage Blob Data Reader can be scoped to one container; data roles apply to OBO user tokens and managed identities alike. |
| [App Service user identities](https://learn.microsoft.com/azure/app-service/configure-authentication-user-identities) | `X-MS-CLIENT-PRINCIPAL` / `-ID` are injected by the platform and cannot be set by external requests; decoded as Base64 JSON claims (no JWT parsing). |
| [Functions MCP extension `worker-1.5.0`](https://github.com/Azure/azure-functions-mcp-extension/tree/worker-1.5.0) | `ToolInvocationContext.Transport` → `HttpTransport.Headers` (case-insensitive); the host listener rethrows worker failures. [MCP C# SDK](https://github.com/modelcontextprotocol/csharp-sdk) `McpServerImpl.CreateToolCallErrorResult`: non-MCP exceptions become `isError: true` with a generic message. Learn does not document this; verified in source only. |
| Azure.Identity 1.21.0, Azure.Storage.Blobs 12.26.0 | Exact pins with package locks. Blobs 12.26.0 shares Azure.Storage.Common 12.25.0 with Queues 12.24.0. No Microsoft.Graph SDK (one HTTPS call). |
| [AzureAD 3.10.0](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0/docs) | `azuread_application_api_access` (with `ignore_changes = [required_resource_access]` on the application), `azuread_application_federated_identity_credential`, `azuread_service_principal_delegated_permission_grant`, data `azuread_service_principal.oauth2_permission_scope_ids`; attributes checked in the local provider schema. |

**Gaps between the sources and the build plan, and decisions:**

- The OBO article describes the confidential client's `client_assertion` as a certificate-signed JWT; the federation article and
  the sample use the managed identity token as the assertion. The workshop follows the federation article (no certificate).
- The build plan names `Identity/DownstreamCredentials.cs`; the downstream clients and caller parsing are separate files for tests.
- One storage account: the report container is in the module 02 account because the deterministic name has no room for a second
  account; every module 05 role is container-scoped.
- Report publication uses `az storage blob upload --auth-mode login` instead of a Terraform blob (AzureRM data-plane access would
  require changing provider settings for the existing shared-key-disabled account).

### Selected upstreams

| Upstream | Selected snapshot | What was inspected | License and reuse boundary |
|---|---|---|---|
| [Functions .NET sample](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9) | `468c518c884ec318e3001b9573254c9e775409c9` | README, FunctionsMcpTool project, host.json, HelloToolWithAuth.cs, infra/app/api.bicep, repository tree and LICENSE.md | MIT, copyright Microsoft Corporation. Preserve the full notice in any adapted code. Link and summarize now; do not copy the whole sample. |
| [C# SDK release](https://github.com/modelcontextprotocol/csharp-sdk/tree/6fa3825973949a9c4f0cd8af344e15a8db09dc35) | Released `v2.2.0`, commit `6fa3825973949a9c4f0cd8af344e15a8db09dc35` | Getting-started guide, README, release metadata, sample paths and LICENSE | Licensing transition: Apache-2.0 for new/consented code, MIT for un-relicensed contributions; documentation CC-BY-4.0. Check the exact file's obligations before adaptation. Do not assume the workshop MIT license replaces upstream terms. |
| [AI Gateway labs](https://github.com/Azure-Samples/AI-Gateway/tree/1679e3137d2fe7592d2a668d77ff71550d35b69e) | `1679e3137d2fe7592d2a668d77ff71550d35b69e` | README, four selected lab READMEs, PRM policies, catalog OpenAPI, registry JSON, workbook JSON and LICENSE.md | MIT, copyright Microsoft Corporation. Preserve notices when adapting policy, infrastructure, query or schema code. No notebook output or whole-repo imports. |
| [MCP Inspector](https://github.com/modelcontextprotocol/inspector/releases/tag/2.11.0) | Published `2.11.0`; inspected main manifest snapshot `074b8108f340590268f2900741403755e923a11c` | Release metadata, package manifest and official Inspector documentation | Use the versioned package as tooling. No Inspector source is copied. Recheck its license if source is later adapted. |
| [MCP specification](https://modelcontextprotocol.io/specification/2026-07-28) | `2026-07-28` | Architecture, transports, tools and authorization | Link and summarize requirements. Do not reproduce documentation wholesale. |

The C# SDK main branch inspected at `3338e88e15c42cfc27465143c140d7d10f1a2707` includes changes
after the selected release, including removal guidance for `McpServerFactory`. Prefer the released package and
its matching examples rather than mixing a moving README with old APIs.
The Functions and AI Gateway snapshots are source pins, not release guarantees.

## Best elements to take, by module

All rows were last verified on 2026-10-14. Paths are relative to the pinned repositories above.

| Module | Best source element | Teaching value and integration | Adapt or exclude |
|---|---|---|---|
| 00 | Functions README and `src/FunctionsMcpTool/FunctionsMcpTool.csproj`; Inspector prerequisites | One consistent environment: .NET 10, Functions Core Tools >= 4.5.0, Node.js >= 22.19.0; local Azurite only when needed | Learn quickstarts still show .NET 8. Pin an exact SDK/container/tool set during implementation and test restore. Terraform replaces azd/Bicep deployment; no Docker requirement for the stdio introduction. |
| 01 | C# SDK `docs/concepts/getting-started.md`: minimal stdio EchoTool and stderr logging; QuickstartClient tools/list and tools/call | Smallest MCP discovery/call exercise with no Azure or model bill; make all inputs synthetic | Do not pull the weather sample's live external API. Pin SDK 2.2.0 and its hosting dependencies. Demonstrate client approval explicitly; annotations are not authorization. |
| 02 | Functions tool trigger project and `infra/app/api.bicep`: Flex deployment storage and managed identity | Keep the serverless hosting and identity-based storage design; replace snippet CRUD with synthetic service health and ticket queue | Upstream host.json sets `Anonymous` under Entra. The key-only module must use `System` and runtime-only `x-functions-key` input. Drop QR, Apps, prompts, website preview and unnecessary preview SDK packages. |
| 03 | App Service MCP authorization and VS Code walkthrough; app-role documentation; sample `infra/app/api.bicep` authsettingsV2 | Separate server audience, delegated client scope, user roles and assignment-required; show PRM discovery and unassigned-user denial | PRM is **Preview**. Portal defaults create a secret; use explicit identity configuration and managed-identity federation instead. Preauthorization is not a replacement for user-role assignment or scope checks. |
| 04 | APIM existing-server docs and programmatic resource model; `labs/mcp-prm-oauth/src/bicep/apim-mcp/mcp-prm.policy.xml` and `mcp-api.policy.xml` | Reuse PRM endpoint/challenge shape and platform token validation as design patterns; map to Terraform/AzAPI **Preview** resources | Use RFC 9728, the exact MCP audience and the workshop scope. Do not copy the lab's multiple accepted audiences, older OAuth-server wording or permissive defaults. Preserve streaming; never read response bodies. |
| 04b (optional) | `labs/mcp-from-api/src/product-catalog/api/openapi.json` and its REST-to-MCP lab | A compact schema demonstrates selecting REST operations as tools | Translate into a synthetic service-health API; do not retain its API-key requirement or unrelated catalog deployment. REST-exported tools do not replace the core Functions server. |
| 05 | Functions `src/FunctionsMcpTool/HelloToolWithAuth.cs`, OBO docs and managed-identity federation docs | Reuse the supported `OnBehalfOfCredential` client-assertion callback concept; obtain distinct Graph and Storage tokens | Do not reuse local developer-identity fallback in deployed tests, log exception details that can leak data, or return real display names/emails. Use fixed tenant/audience configuration and sanitized persona output. App-only tool uses explicit managed identity, not OBO. |
| 06 | APIM Application Insights docs; `labs/mcp-from-api/src/mcp-insights/workbook.json`; API Center registration docs and `labs/mcp-registry-apic` | Reuse correlation joins and a small request/denial view; register only the governed endpoint | Workbook `agent-id`/`user-id` header values are not authenticated identity proof. Emit validated caller metadata, zero body bytes, fixed tool name, status and latency. Do not import the lab's third-party/SSE catalog JSON. Last verified 2026-10-15. |
| 06b (optional) | Microsoft 365 BYO MCP inventory docs | Facilitator explanation of review, admin approval and inventory (**Preview**) | No tenant registration in the core path; recheck licensing and eligibility before a demo. Current docs list supported surfaces and exclude Foundry and declarative agents from this preview. Last verified 2026-10-15. |
| 07 (optional) | Foundry MCP authentication and Copilot Studio onboarding docs | Contrast shared project/agent identity with individual OAuth user context on the same governed server | Only a supported secretless flow may be demonstrated. Copilot Studio transport (Streamable HTTP per the existing-server page; SSE wording not re-verified). Its documented manual OAuth asks for a secret: defer rather than weaken the rules. Foundry client identity preservation does not permit forwarding the MCP token to Graph/Storage. |
| 99 | The selected labs' cleanup guidance plus the workshop's two Terraform roots | Teach deterministic teardown, ownership boundaries and a final empty-inventory check | Replace broad notebook/resource-group deletion with destruction of workshop-owned resources only. Do not remove passed-in identities, shared infrastructure, or unrelated accounts. |

## Verified updates and conflicts

- **Protocol revision:** 2026-07-28 is the current specification returned by the official index. It uses
  per-request version/capability metadata rather than the older initialization model. Dynamic client registration
  is deprecated in that revision. Microsoft Entra pre-registration remains the workshop choice.
- **Compatibility:** current documentation is not evidence that a pinned Functions extension, C# SDK release,
  gateway and every client implement the newest revision. Validate their negotiated era before writing examples.
- **Functions dependencies:** the selected project targets `net10.0`, Functions v4, worker `2.52.0`,
  MCP extension `1.5.0`, worker SDK `2.0.7`, Azure Identity `1.21.0`, and Graph `5.104.0`.
  It also includes MCP SDK `1.0.0-preview.4` (**Preview**) and unrelated UI dependencies.
  These are observed upstream values, not a mandate to copy every dependency.
- **Key protection:** `/runtime/webhooks/mcp` uses the `mcp_extension` **system key**, not a per-function key.
  Keep it out of source and Terraform outputs/state committed to Git. Under Entra, remove the key requirement
  only after platform authentication is active; `Anonymous` in host.json does not mean the public app may be anonymous.
- **Auth configuration:** the sample stores a managed identity client ID in a setting referenced by
  `clientSecretSettingName` as part of its federation override pattern. That name does not make the value a secret.
  Confirm the exact supported platform pattern before translating authsettingsV2; do not add a client secret.
- **PRM labs:** README text says RFC9729, but its linked standard and policy use RFC 9728.
  The client-authorization lab implements an older OAuth-server emulation, not a pattern to import as the core
  Entra resource-server flow.
- **Gateway limits:** existing-server docs say tools/resources, while the overview's availability note says
  tools only. Both exclude workspaces and prompts. The workshop uses tools only and records this discrepancy.
- **Inspector:** APIM articles retain a 0.9.0 tip; current Inspector release is 2.11.0 with legacy/modern negotiation.
  Prefer testing a maintained release, not downgrading controls to match an old tip.
- **Client configuration:** current VS Code docs prefer portable `.mcp.json` for new server configurations,
  with `.vscode/mcp.json` retained for compatibility. The repository supplies both for Microsoft Learn;
  each defines the same public documentation endpoint, with no credentials.
- **Network:** Standard v2 outbound integration plus a Flex private endpoint is documented. Outbound integration
  alone does not block direct public Function calls. Disable public access and prove private DNS/routing.
- **Telemetry:** upstream workbook structure is useful, but identity headers and exception text are unsuitable
  as authoritative or payload-free workshop audit data.
- **Optional clients:** distinguish product terminology such as Foundry "OAuth identity passthrough" (client identity
  to the MCP resource) from prohibited server-to-downstream token passthrough. The latter remains forbidden.

## Official reference register

Every row was last verified on 2026-10-14. This register covers the build plan's references and the additional
references used to resolve design choices.

| Module | Reference | Use and status |
|---|---|---|
| 00 | [Azure CLI Windows installation](https://learn.microsoft.com/cli/azure/install-azure-cli-windows), [.NET Windows installation](https://learn.microsoft.com/dotnet/core/install/windows), [PowerShell installation](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) | EN/FR local setup: WinGet options, reopen the terminal, SDK rather than runtime, and explicit tenant selection. No installer executed during this documentation update. Verified 2026-10-14. |
| 00 | [Subscription locations API](https://learn.microsoft.com/rest/api/resources/subscriptions/list-locations?view=rest-resources-2022-12-01) | Explicit-subscription read-only region discovery. Avoid the unsupported `az account list-locations --subscription` option. Verified 2026-10-14. |
| 00/02 | [Functions custom remote MCP quickstart](https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server) | Local run/deploy outline; C# SDK prerequisites lag the pinned sample. |
| 00/02 | [Functions MCP bindings](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp) | Isolated worker, endpoint, system key and host.json configuration. |
| 00/02 | [Flex Consumption hosting](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan) | Linux, scale-to-zero, instance sizing, cost drivers and networking. |
| 00/02 | [AzureRM Flex resource at v5.9.0](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown) | Supported user-assigned identity storage and public-access controls. Do not copy its key-based example. |
| 00 | [AzureRM registry](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0), [AzureAD registry](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0), [AzAPI registry](https://registry.terraform.io/providers/Azure/azapi/2.13.0) | Published candidate provider versions; combined schemas/runtime not yet validated. |
| 01 | [MCP specification](https://modelcontextprotocol.io/specification/2026-07-28), [architecture](https://modelcontextprotocol.io/specification/2026-07-28/architecture), [transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports), [tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools), [authorization](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization) | Current teaching reference; distinguish legacy wire examples. |
| 01 | [VS Code MCP configuration](https://code.visualstudio.com/docs/agent-customization/mcp-servers) | Trust, approvals, portable configuration and secure inputs. |
| 01 | [Inspector documentation](https://modelcontextprotocol.io/docs/tools/inspector) | UI, CLI, protocol negotiation, Node requirement and secret-storage caveat. |
| 03 | [App Service MCP authorization](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp) | Server-level authorization, preauthorization and PRM (**Preview**); not per-tool authorization. |
| 03 | [App Service MCP and VS Code](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode) | Client preauthorization and discovery; do not follow secret-creation defaults. |
| 03 | [Functions MCP tutorial](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial) | Select MCP extension path; self-hosted MCP is **Preview** and not selected. |
| 03 | [App roles](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps) | Distinguish role assignment from delegated scope consent. |
| 04 | [Expose an existing server](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server) | Streamable endpoint, minimum version, inherited diagnostics and streaming limitations. |
| 04 | [Secure MCP servers](https://learn.microsoft.com/azure/api-management/secure-mcp-servers) | Inbound/outbound boundaries; not permission to forward MCP tokens to downstream APIs. |
| 04 | [MCP overview](https://learn.microsoft.com/azure/api-management/mcp-server-overview) | Tier availability, governance, inventory and documented limitations. |
| 04 | [Programmatic MCP management](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) | API, policy and optional REST tool resource types; `2025-09-01-preview` (**Preview**). Live deviation 2026-10-18: the service rejects `mcpProperties.endpoints` as the documented array and accepts a map keyed by endpoint name. |
| 04 | [Validate Entra tokens](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy) | Exact tenant/audience and scope/role claim checks via platform policy. |
| 04 | [rate-limit-by-key](https://learn.microsoft.com/azure/api-management/rate-limit-by-key-policy), [ip-filter](https://learn.microsoft.com/azure/api-management/ip-filter-policy), [Application Insights integration](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) | Per-oid throttling, optional range filter, managed-identity logger and zero payload bytes. Verified 2026-10-15. |
| 04 | [Standard v2 outbound integration](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound), [App Service private endpoints](https://learn.microsoft.com/azure/app-service/overview-private-endpoint) | Delegated subnet + NSG, private endpoint, private DNS, public access disabled (HTTP 403). Verified 2026-10-15. |
| 04 | [Outbound virtual network integration](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound) | Standard v2/Premium v2; dedicated subnet, delegation, network security group and permissions. |
| 04 | [Functions networking](https://learn.microsoft.com/azure/azure-functions/functions-networking-options) | Flex inbound private endpoints versus outbound integration; direct-access protection. |
| 04b | [Export REST to MCP](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server), [REST API-backed MCP server template](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) | Optional part B, authored 2026-10-19: two read-only tools mapped by `operationId`; tools only, no prompts/resources; no response-body inspection; `2025-09-01-preview` (**Preview**). |
| 05 | [On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow) | Token A/Token B boundary and user-only delegation. Use libraries, not its client-secret example. |
| 05 | [Application trust in managed identity](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity) | Secretless client assertion, same-tenant trust and federated credential permissions. |
| 06 | [APIM Application Insights integration](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) | Managed-identity logger, resource-scoped Monitoring Metrics Publisher and diagnostics. Last verified 2026-10-15. |
| 06 | [Monitor MCP servers](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers) | Default MCP dimensions. Live deviation, corrected 2026-10-20: the passthrough server (part A, with a backend) logs `api.type` as `pass-through-mcp`; the REST-backed server (part B) logs `mcp-backend` (earlier note: `mcp-backend`, not the documented `Mcp`; the workshop query accepts both. |
| 06 | [Register and discover MCP servers](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server) | API Center asset, remote, environment, version and inventory metadata. Last verified 2026-10-15. |
| 06 | [Use OpenTelemetry with Azure Functions](https://learn.microsoft.com/azure/azure-functions/opentelemetry-howto) | Worker packages, `UseFunctionsWorkerDefaults`, Azure Monitor exporter. Verified live 2026-10-20: one operation ID joins the APIM request, the Function request, the `tools/call` span and its downstream calls. Last verified: 2026-10-20. |
| 06 | [OpenTelemetry semantic conventions for MCP](https://github.com/open-telemetry/semantic-conventions-genai/blob/547934afa90a34298441caf80c43b27255c3a292/docs/gen-ai/mcp.md) | Status Development, pinned commit. Span name `{mcp.method.name} {target}`, `gen_ai.tool.name`, `error.type = tool_error` when `isError` is true; `gen_ai.tool.call.arguments` and `.result` are Opt-In and never set here. Last verified: 2026-10-20. |
| 06 (optional) | [Azure Copilot Observability Agent](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-overview) and [chat with your observability data](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-chat) | Logs **Agent** toggle; chat needs no resource, is temporary and scoped to one resource. Autonomous operations and the agent resource are **Preview** and not used. Customer-managed keys are not supported for conversations. Run live 2026-10-19: same two `initialize`/401 rows as the workshop KQL file. Last verified 2026-10-19. |
| 06b | [Microsoft 365 BYO MCP](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) | **Preview**, review/approval workflow and supported-client restrictions; demo only. Last verified 2026-10-15. |
| 06b | [Govern tools with Agent 365 and API Management](https://learn.microsoft.com/azure/api-management/agent-365) and [Tech Community post](https://techcommunity.microsoft.com/blog/integrationsonazureblog/microsoft-agent-365-and-azure-api-management-integration-for-mcp-governance/4563335) | **Preview**. Tenant-level role consent; v2 tiers give inventory and server block only; tool-level control needs the AI Gateway tier (Preview). Demo only. Last verified 2026-10-15. |
| 07 | [Foundry MCP authentication](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication) | Agent/project identity versus individual OAuth. Recheck selected feature availability before demo. |
| 07 | [Copilot Studio existing MCP server](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent) | Streamable HTTP and wizard authentication; manual-secret conflict remains unresolved. |

## Practice workspace sources

Last verified: 2026-10-14. The [practice guide](PRACTICE.md) adds client launch and call-check help, not a deployed
MCP client or completed module.

| Source | Use and boundary |
|---|---|
| [VS Code MCP setup](https://code.visualstudio.com/docs/agent-customization/mcp-servers) | HTTP server setup, private user configuration, tool selection and the real tool-call record. No automatic approval or credentials in workspace configuration. |
| [Inspector web client](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/web) | Ad-hoc server, printed private launch URL, tools/list and explicit Call Tool. A connected badge is not a validation result. |
| [Inspector configuration](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/configuration) | Force memory secret store and no token persistence. Header values are not moved into its secret store: never save or export credential-bearing headers. |
| [Inspector authorization](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/authorization) | Web callback follows its actual origin. Register the exact redirect and approved public client; Entra has no dynamic client registration. No client-secret fallback. |
| [Inspector 2.9.0](https://github.com/modelcontextprotocol/inspector/tree/ae865a19178ddf6f375780a02e9c77c4cf4da184) and its [secret-store implementation](https://github.com/modelcontextprotocol/inspector/blob/2.9.0/core/auth/node/secret-store-selection.ts) | The configured npm registry resolves and runs 2.9.0; 2.11.0 returns no matching version despite its GitHub release. Practice commands explicitly pin 2.9.0, check availability and use protocol-era negotiation. The source-assessment candidate 2.11.0 is not an installability guarantee. No registry override or silent fallback. |
| [Create a codespace](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository) | User reviews branch, payer and quota before creating a machine. No automatic provisioning from the canvas; unpushed changes are not included. |
| [Codespaces port forwarding](https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace) | Prefer private local forwarding through VS Code desktop. Do not follow the page's token-printing example or expose Inspector publicly. |
| [App Service MCP authorization](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp) | PRM is **Preview**; consent/preauthorization applies to a particular client. Separate downstream tokens remain mandatory. |

## Bilingual learning board and architecture sources

Last verified: 2026-10-14. The [learning guide](LEARNING-GUIDE.md), [deployment-context guide](DEPLOYMENT.md),
[French reference guide](fr/REFERENCES.md) and [diagram provenance](../assets/architecture/README.md) are authored
workshop explanations, not copies of external documentation. The latter records every exact icon URL and usage boundary.

- [Azure CLI subscription/tenant selection](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli):
  interactive `az login --tenant`, explicit subscription selection and verification. Do not copy its password sign-in example.
- [Interactive Azure CLI sign-in](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively):
  participant browser/multifactor flow; no client secret or token capture.
- [Resource role assignment authority](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli):
  separate assignment authority, scoped to the exact resource.
- [Terraform destroy](https://developer.hashicorp.com/terraform/cli/commands/destroy):
  review ownership and the destroy plan before explicit approval.
- [Azure icon pack/terms](https://learn.microsoft.com/azure/architecture/icons/) and
  [Entra architecture icons/terms](https://learn.microsoft.com/entra/architecture/architecture-icons):
  verify community-mirrored service identities and permitted documentation use.
- [Microsoft trademark guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks):
  corporate logos are separate brand assets, not covered by this repository's MIT license.

## Iterative Markdown and application diagrams

Last verified: 2026-10-14. [English diagrams](../assets/architecture/STEPS.md) and
[French diagrams](../assets/architecture/STEPS.fr.md) are generated from the same Draw.io source as the SVG/PNG.


- [GitHub Mermaid blocks](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams):
  native Markdown rendering; use ordinary flowcharts, not plugins, remote images or diagrams sent to external services.
- [Mermaid flowcharts](https://mermaid.js.org/syntax/flowchart.html):
  preserve component labels, directed/dashed edges and actual ownership boundaries.
  Mermaid does not preserve Draw.io pixel routing or the verified embedded product icons.
- [Mermaid 11.12.0](https://www.npmjs.com/package/mermaid/v/11.12.0):
  pinned session-only syntax/rendering checker, not a website or dev-container dependency.
  The application uses its already generated SVG when a Mermaid block matches a published module.
  Unknown blocks fail explicitly. No Mermaid service, CDN, credential collection or new runtime dependency.

## Public portal hosting

Last verified: 2026-10-14. The [EN hosting guide](HOSTING.md) and [French hosting guide](fr/HOSTING.md)
separate static documentation publication from participant-owned Azure deployment.

- [Custom Pages workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages):
  upload only the allowlisted static output, separate build/deploy jobs, environment and minimum deployment permissions.
- [Pages source selection](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site):
  repository administrator chooses GitHub Actions; manual workflow execution does not implicitly change that setting.
- [GitHub OIDC with Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure):
  possible future participant-owned federation, not configured by this portal or required for Pages.
- [App Service authentication](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization)
  and [ACA authentication](https://learn.microsoft.com/azure/container-apps/authentication):
  different optional hosting services; authentication alone does not grant tenant access or authorize a workload deployment.
  The ACA example creates a client secret; do not adopt it. A supported secretless private-portal sign-in path
  remains to be proven for the exact target, not inferred from deployment-pipeline OIDC support.

The prepared workflow pins checkout v6, setup-node v6, configure-pages v5, upload-pages-artifact v4
and deploy-pages v4 to their verified release commits. No publication or Azure hosting has run.

## Remaining deployment evidence gates

- No Azure subscription was inspected and no runtime deployment compatibility was claimed.
- Region, quota, cost, consent, restricted deployment connectivity and optional client flows require module-specific
  verification and approval.
- Full execution of upstream notebooks and all their transitive assets is out of scope. Selected files were
  inspected for design suitability; future adaptation must inspect the exact code being imported.
- Before adapting source, add its full applicable license/notice and origin to THIRD-PARTY-NOTICES.md.
  Preserve copyright headers and mark changes where the upstream license requires it.

## Architecture diagram authoring skill

Retrieved 2026-10-15 from a personal skills repository by the workshop author (MIT License, notice kept with the original).
Copied verbatim to `.github/skills/architecture-diagram-author/SKILL.md` and loaded by the module builder when a module
changes a depicted architecture. The skill's Microsoft icon references point to
[az-icons.com](https://az-icons.com/), [MsiconsCollections](https://aka.ms/MsiconsCollections),
[Azure Architecture Center icons](https://learn.microsoft.com/en-us/azure/architecture/icons/),
[Power Platform icons](https://learn.microsoft.com/en-us/power-platform/guidance/icons) and
[DamoBird365/microsoft-cloud-icons](https://github.com/DamoBird365/microsoft-cloud-icons/tree/master). Verify each asset's
identity and terms as the skill requires before reuse; this repository's own diagrams keep the provenance in
[the diagram provenance guide](../assets/architecture/README.md).

## Module 07 and 99 sources

Initial source review: 2026-10-15. Module 07 now provides an optional participant exercise with Microsoft Foundry
(OAuth identity passthrough, **Preview**); Copilot Studio remains a reading-only outline. Module 99 orchestrates clean-up.
The Foundry exercise and clean-up were validated in the author's test environment on 2026-10-20;
see [build progress](PROGRESS.md) for evidence. Each participant still validates their own environment.
The participant-facing wording was aligned on 2026-10-20; this editorial review did not reverify the external sources.

- [Module 07 EN/FR guide](../modules/07-clients/README.md) and [Module 99 EN/FR guide](../modules/99-cleanup/README.md), with the source links in each README.
- [Copilot Studio MCP support](https://learn.microsoft.com/microsoft-copilot-studio/agent-extend-action-mcp): fetched 2026-10-15. The page says Copilot Studio supports MCP tools and resources. It does not name a transport, so this page alone does not confirm the Streamable HTTP and SSE wording in module 07. Recheck [Copilot Studio existing MCP server](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent) before attempting the Copilot Studio integration, which remains an outline rather than a validated exercise.

## Presenter App Service portal evidence

Last verified: 2026-10-16. Operational evidence from the presenter's deployment, not a Microsoft source.

- [App Service hosting procedure](../docs/HOSTING.md#optional-public-app-service-deployment): the ZIP deploy and `/health` steps used. `az webapp deploy` with `--track-status` is the deployment mechanism.
- [Azure App Service deployment with ZIP](https://learn.microsoft.com/azure/app-service/deploy-zip): fetched 2026-10-16. Used to confirm that the deployment log, not the Kudu status code alone, is the reliable success signal.

## Sources

The pinned upstream snapshots and official register above are the sources for this assessment.
Last verified: 2026-10-14.

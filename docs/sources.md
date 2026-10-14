# Sources and reuse decisions

Last verified: 2026-10-14. This is a design assessment, not evidence of a successful deployment.
Links were read from public upstream sources. No upstream application code has been vendored in this preparation.
Versions below are reproducible reference selections or compatibility-test candidates, not a promise that every
combination has been tested together.

## Selection method

Choose the smallest example that teaches one workshop outcome and can be validated and cleaned up by a participant.
Prefer official samples and standards. Check the actual files, not only marketing descriptions.
Keep the five synthetic tools and one identity story throughout the workshop.
Translate useful infrastructure concepts to Terraform and participant steps to PowerShell first, then bash.
Do not import notebooks, external data sources, model deployments, complete catalogs, or unrelated agent demos.

## Upstream snapshots

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
| 06 | APIM Application Insights docs; `labs/mcp-from-api/src/mcp-insights/workbook.json`; API Center registration docs and `labs/mcp-registry-apic` | Reuse correlation joins and a small request/denial view; register only the governed endpoint | Workbook `agent-id`/`user-id` header values are not authenticated identity proof. Emit validated caller metadata, zero body bytes, fixed tool name, status and latency. Do not import the lab's third-party/SSE catalog JSON. |
| 06b (optional) | Microsoft 365 BYO MCP inventory docs | Facilitator explanation of review, admin approval and inventory (**Preview**) | No tenant registration in the core path; recheck licensing and eligibility before a demo. Current docs list supported surfaces and exclude Foundry and declarative agents from this preview. |
| 07 (optional) | Foundry MCP authentication and Copilot Studio onboarding docs | Contrast shared project/agent identity with individual OAuth user context on the same governed server | Only a supported secretless flow may be demonstrated. Copilot Studio supports Streamable HTTP, not deprecated SSE. Its documented manual OAuth asks for a secret: defer rather than weaken the rules. Foundry client identity preservation does not permit forwarding the MCP token to Graph/Storage. |
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
| 04 | [Programmatic MCP management](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) | API, policy and optional REST tool resource types; `2025-09-01-preview` (**Preview**). |
| 04 | [Validate Entra tokens](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy) | Exact tenant/audience and scope/role claim checks via platform policy. |
| 04 | [Outbound virtual network integration](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound) | Standard v2/Premium v2; dedicated subnet, delegation, network security group and permissions. |
| 04 | [Functions networking](https://learn.microsoft.com/azure/azure-functions/functions-networking-options) | Flex inbound private endpoints versus outbound integration; direct-access protection. |
| 04b | [Export REST to MCP](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server) | Optional operation-to-tool exercise; no prompts/resources; no response-body inspection. |
| 05 | [On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow) | Token A/Token B boundary and user-only delegation. Use libraries, not its client-secret example. |
| 05 | [Application trust in managed identity](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity) | Secretless client assertion, same-tenant trust and federated credential permissions. |
| 06 | [APIM Application Insights integration](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) | Managed-identity logger, resource-scoped Monitoring Metrics Publisher and diagnostics. |
| 06 | [Register and discover MCP servers](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server) | API Center asset, remote, environment, version and inventory metadata. |
| 06b | [Microsoft 365 BYO MCP](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) | **Preview**, review/approval workflow and supported-client restrictions; demo only. |
| 07 | [Foundry MCP authentication](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication) | Agent/project identity versus individual OAuth. Recheck selected feature availability before demo. |
| 07 | [Copilot Studio existing MCP server](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent) | Streamable HTTP and wizard authentication; manual-secret conflict remains unresolved. |

## Remaining evidence gates

- No Azure subscription was inspected and no runtime deployment compatibility was claimed.
- Region, quota, cost, consent, restricted deployment connectivity and optional client flows require module-specific
  verification and approval.
- Full execution of upstream notebooks and all their transitive assets is out of scope. Selected files were
  inspected for design suitability; future adaptation must inspect the exact code being imported.
- Before adapting source, add its full applicable license/notice and origin to THIRD-PARTY-NOTICES.md.
  Preserve copyright headers and mark changes where the upstream license requires it.

## Sources

The pinned upstream snapshots and official register above are the sources for this assessment.
Last verified: 2026-10-14.

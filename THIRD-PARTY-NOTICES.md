# Third-party notices

This repository is MIT licensed (see [LICENSE](LICENSE)). Some files adapt third-party code.
The notices below apply to those adapted portions. They are not replaced by this repository's license.

## Azure-Samples/remote-mcp-functions-dotnet

- Origin: https://github.com/Azure-Samples/remote-mcp-functions-dotnet
- Pinned commit: `468c518c884ec318e3001b9573254c9e775409c9`
- Adapted files (module 02):
  - `src/FunctionsMcpServer/FunctionsMcpServer.csproj` from `src/FunctionsMcpTool/FunctionsMcpTool.csproj`
  - `src/FunctionsMcpServer/Program.cs` from `src/FunctionsMcpTool/Program.cs`
  - `src/FunctionsMcpServer/host.json` from `src/FunctionsMcpTool/host.json`
    (changed: `webhookAuthorizationLevel` is `System`, not `Anonymous`)
  - `src/FunctionsMcpServer/Tools/*.cs` from the trigger pattern in `src/FunctionsMcpTool/HelloTool.cs`
  - `infra/workload/mcp-server.tf`, translated to Terraform from `infra/main.bicep`, `infra/app/api.bicep`
    and `infra/app/rbac.bicep`
- Adapted files (module 03):
  - `infra/entra/main.tf`, translated to Terraform from `infra/app/entra.bicep`
    (changed: app roles and assignment required, Application ID URI `api://<client-id>`, no redirect URI,
    no Microsoft Graph permission and no federated identity credential yet)
  - `infra/workload/entra-auth.tf` and the `auth_settings_v2` block in `infra/workload/mcp-server.tf`, translated from the
    `authsettingsV2` configuration in `infra/app/api.bicep` (changed: no secret setting, token store off,
    allowed audiences limited to the MCP API, two-stage replacement of the key gate)
- Changes: synthetic workshop tools, strict input validation, payload-free audit logs, exact package pins with a
  lock file, no preview MCP SDK, Graph, QR, Apps or snippet code, queue-scoped least-privilege roles.

```text
MIT License

Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
```

## Azure-Samples/AI-Gateway

- Origin: https://github.com/Azure-Samples/AI-Gateway
- Pinned commit: `1679e3137d2fe7592d2a668d77ff71550d35b69e`
- Adapted files (module 04):
  - `modules/04-governed-gateway/policies/mcp-server.xml` from `labs/mcp-prm-oauth/src/bicep/apim-mcp/mcp-api.policy.xml`
    (changed: one audience only, allowed clients, required `user_impersonation` scope, per-tool app-role check from the
    JSON-RPC body, per-oid rate limit, optional IP filter, payload-free trace, identity headers removed, backend 401 rewritten)
  - `modules/04-governed-gateway/policies/protected-resource-metadata.xml` from
    `labs/mcp-prm-oauth/src/bicep/apim-mcp/mcp-prm.policy.xml` (changed: static JSON, module 03 scope, per-IP rate limit)
  - `infra/workload/gateway.tf`: the `.well-known/oauth-protected-resource` metadata API and operation pattern from
    `labs/mcp-prm-oauth/main.bicep` and `src/bicep/apim-mcp/mcp-api.bicep`, translated to Terraform/AzAPI
- Not adapted: the OAuth-server emulation, encryption keys and session policies of `labs/mcp-client-authorization`.

```text
MIT License

Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
```

## Model Context Protocol C# SDK

Module 01 adapts the SDK quickstart pattern. Its complete notice is in
[modules/01-discover-mcp/csharp-sdk-LICENSE.txt](modules/01-discover-mcp/csharp-sdk-LICENSE.txt)
with provenance in [modules/01-discover-mcp/UPSTREAM.md](modules/01-discover-mcp/UPSTREAM.md).

## NuGet packages

Packages restored at build time keep their own license metadata. They are not vendored in this repository.
Exact versions and content hashes are in each project's `packages.lock.json`.

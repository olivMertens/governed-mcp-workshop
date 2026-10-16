# Publish the guides, deploy the workload separately

The public workshop portal and the Azure Model Context Protocol (MCP) services are different deployments.
The portal can help participants prepare their environment. It must not collect their Azure credentials,
accept a shared deployment key, or obtain access to their tenant.

| Component | Recommended location | Identity boundary |
|---|---|---|
| Public EN/FR guides, diagrams and workspace choices | GitHub Pages | Public static content. No Azure connection or deployment authority. |
| Optional public Azure copy | Participant-owned Linux App Service B1, explicit Terraform opt-in | Public guides only. Entra authorizes deployment, not visitor access. |
| Optional internal copy | An explicitly selected App Service **or** Azure Container Apps application | Separate design; secretless visitor sign-in is not implemented here. |
| Participant MCP workload | The participant's approved non-production Azure subscription/resource group | Participant runs the reviewed Terraform plan in their own authenticated terminal. |

Azure App Service and Azure Container Apps (ACA) are different services, not one hosting target.
Hosting the portal in either service does not deploy the workshop infrastructure.
The core MCP design remains Azure Functions behind API Management; it is not automatically changed to ACA.

## Build the public portal locally

From the repository root, using Node.js 22.19+:

```powershell
node --test scripts/site.test.mjs
if ($LASTEXITCODE -ne 0) { throw 'Site checks failed.' }
node scripts/build-site.mjs
if ($LASTEXITCODE -ne 0) { throw 'Site build failed.' }
```

```bash
node --test scripts/site.test.mjs && node scripts/build-site.mjs
```

The build writes `site-dist`, ignored by Git. It refuses to overwrite an existing output directory.
For another build, specify a new directory with `--output`; remove only an inspected previous output yourself.
Serve the directory through an HTTP server, not a `file://` URL.
The output is portable static content: HTML, locale JavaScript, public journey JSON and allowlisted diagram/icon assets.
It does not copy the repository, `.git`, `.workshop`, credentials, Terraform state or the canvas server.
No live canvas capability is included. Relative paths support a project site such as `/workshop-mcp/`.

The landing route is `#/start`; French is `?lang=fr#/start`, English is `?lang=en#/start`.
Module links use hashes, so GitHub Pages does not need an application router or catch-all server.
The site reads only its static JSON. Connection preparation stays in browser memory; actual calls stay in the client.

## Publish with GitHub Pages

The prepared workflow is `.github/workflows/workshop-pages.yml`. It follows the official GitHub Pages flow,
pins its actions by commit, and uploads **only `site-dist`**, never the repository root.
It uses no Azure credentials or client secret. The short-lived GitHub deployment identity authorizes Pages,
not resource creation in any Azure tenant.

1. Review the public content, product-image usage notices and source changes. Publish the source and all needed
   scripts/configuration to the repository's default branch first. Otherwise clone/Codespaces instructions point
   to files participants cannot obtain. Do not publish a generated site that promises unpublished prerequisites.
2. In repository **Settings > Pages**, choose **GitHub Actions** as the source.
   This is a separate repository configuration step; the workflow does not silently enable Pages.
3. Configure the `github-pages` environment's allowed branches and any required reviewer.
4. In **Actions**, select **Publish workshop guides**, then **Run workflow** on the default branch.
   The workflow is manual-only: a pull request or push does not automatically publish the content.
5. Check the deployment result and its reported URL. Open the start page, EN/FR choices, module diagrams
   and client-preparation page from the actual deployed URL before sharing it.

For this repository, the expected project URL after successful publication is
`https://olivmertens.github.io/workshop-mcp/`; this is **not a claim that the site is live**.
GitHub reported Pages disabled during preparation. No workflow was dispatched and no repository setting changed.
Check plan entitlement, site visibility and Actions/Pages usage limits; do not assume every organization plan is free.

## If the guides must run inside a tenant

The same static output can be served by an approved existing App Service or ACA application.
Before preparing its deployment, establish the exact resource, subscription, resource group, runtime/image,
ingress and authentication requirements, existing content ownership, cost impact and rollback path.
Do not overwrite an existing app, create ingress, grant permissions or configure Entra without explicit approval.
Never use a production app as a convenient test destination.

For a private portal, review supported built-in Entra authentication, assignment/access rules and single-tenant
issuer/audience settings for the selected service. A sign-in screen alone does not establish authorization.
Use managed identity for approved app-to-resource access, or OpenID Connect (OIDC) federation for an explicitly
approved deployment pipeline. Do not use a copied publish profile, permanent deployment key or client secret.
The ACA authentication reference includes a client-secret setup example. Do not run that example:
a supported secretless private-portal sign-in path has not been established here and remains a deployment gate.

Do not add tenant IDs or app credentials to this public repository. Resolve and verify the selected target in
the private deployment session. This preparation does not use the author's Azure CLI login or discover/modify apps.

## Optional public App Service deployment

This implemented path serves the **same public SPA** (single-page application), not an internal authenticated site.
It uses Linux App Service Basic B1 with Node.js 22 LTS (long-term support). It needs no container registry,
image build, client secret, publish profile or deployment key. ACA is not implemented in this iteration.
The preflight/module guide is [module 00](../modules/00-prerequisites/README.md).
Only one `infra/workload` root and state are used. The opt-in is saved in private participant parameters,
so a later ordinary plan cannot silently disable the portal.

**Cost:** B1 runs a paid dedicated worker continuously. Review regional pricing and subscription policy.
Stopping the web app does not stop plan charges. HTTPS and Transport Layer Security (TLS) 1.2+ are enforced;
File Transfer Protocol (FTP) and basic publishing are disabled. The read-only server logs no request bodies,
queries, credentials or access payloads. It exposes only 52 public assets and `/health`, never the canvas API.
GitHub Pages remains the simpler choice for a shared public workshop.

### Prepare and review locally

First finish the approved **foundation-only** deployment from the [start guide](GETTING-STARTED.md),
with the portal still disabled, or use an administrator-provided existing group. Review and approve that
saved plan separately before applying it. The portal preflight requires this group to exist.

From the same approved terminal, add `-EnablePublicPortal` to your original preparation command,
with exactly the same region, owner, expiry, prefix and existing-group argument. This is also safe for an
existing foundation parameter file: only the explicit opt-in changes, not its saved suffix or state.
Do not regenerate parameters or move to another clone/state.

```powershell
# Repeat your original prepare-workshop.ps1 command, adding -EnablePublicPortal.
node scripts/build-portal.mjs
if ($LASTEXITCODE -ne 0) { throw 'Public bundle build failed.' }
node scripts/portal-server.mjs --verify portal-dist
if ($LASTEXITCODE -ne 0) { throw 'Public bundle verification failed.' }
node portal-dist/server.mjs
```

```bash
# Repeat your original preparation command with -EnablePublicPortal.
node scripts/build-portal.mjs &&
node scripts/portal-server.mjs --verify portal-dist &&
node portal-dist/server.mjs
```

The last command serves loopback port 8080. Inspect EN/FR routes and diagrams, then stop it with Ctrl+C.
The new `portal-dist` contains 54 exact files: the public static allowlist, a hash manifest and the reviewed
stdlib-only server. The builder refuses an existing destination; choose a fresh `--output` directory when rebuilding.
The server honors App Service's `PORT` and listens externally only when it is set.

**Live address shape (verified 2026-10-16):** the app is served at `https://<web-app-name>.azurewebsites.net`.
Routes are `/?lang=en#/start` and `/?lang=fr#/start`, plus `/health`, which returns `{"status":"ok"}`.
Paths such as `/en/` or `/fr/` return 404 by design: the server routes by query string and hash, not by path.
`/participant.json` returns 404 unless the endpoint and scope settings are configured.

**Deploy status note:** `scripts/deploy-portal.ps1` treats a non-zero `az webapp deploy` exit as a failure only when
the latest deployment log does not contain `Deployment successful`. A Kudu status of `4` alone is not a failure;
the health check is the final gate.

### Review capacity privately

For this optional stage the group must already exist: first review/apply the **foundation-only** plan from the
[start guide](GETTING-STARTED.md), before enabling the portal. Obtain approval separately before that apply.
If the administrator supplied the group, do not create or import it.

An administrator must register `Microsoft.Web` separately if needed.
Review Basic Linux B1 availability, regional worker quota, policy and the cost of one worker.
For future `-Stage mcp`, inspect **Diagnose and solve problems > Flex Consumption Quota** and review
the sum of all participant maximum memory allocations. Random names never reset quota.
The `mcp` stage checks the live Flex region and isolated .NET 10 runtime list; it does not implement later modules.

Keep evidence in ignored `.workshop/capacity-review.json`, not the portal or Git. This example intentionally
**fails** until a real reviewer supplies the correct target, available capacity, current UTC time and approval:

```json
{
  "subscriptionId": "<approved private subscription>",
  "location": "<approved region code>",
  "stage": "portal",
  "unit": "workers",
  "availableUnits": 0,
  "checkedAtUtc": "<yyyy-MM-ddTHH:mm:ssZ>",
  "costApproved": false
}
```

Use `MB` and `stage: "mcp"` for Flex. The default reviewed ceiling is 2048 MB times 10 instances;
pass the exact planned `-FlexMemoryMB` and `-FlexMaximumInstances` to `scripts/preflight.ps1` if different.
Evidence expires after 24 hours, rejects future timestamps and must match subscription, region and stage.
This is a **human-reviewed quota/cost gate**, not an automatic quota API result or capacity reservation.
API Management/network/telemetry capacity and policy still require the later module's actual plan.

### Plan, approve, deploy

The following commands can read the approved Azure target. They do not sign in, change subscription, register
providers or grant roles. Supply the exact context selected privately in the same terminal.

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\preflight.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID `
    -Stage portal -CapacityReviewPath .\.workshop\capacity-review.json
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\portal.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
terraform '-chdir=infra\workload' show '..\..\.workshop\portal.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan review failed.' }
# STOP: obtain explicit approval of this exact saved plan, target and B1 cost.
# Only after approval:
terraform '-chdir=infra\workload' apply '..\..\.workshop\portal.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform apply failed.' }
& .\scripts\deploy-portal.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID `
    -CapacityReviewPath .\.workshop\capacity-review.json
```

```bash
bash ./scripts/preflight.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" \
  -Stage portal -CapacityReviewPath ./.workshop/capacity-review.json &&
terraform -chdir=infra/workload init -lockfile=readonly &&
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/portal.tfplan &&
terraform -chdir=infra/workload show ../../.workshop/portal.tfplan
# STOP: obtain separate approval of the exact saved plan, target and B1 cost.
# Only after approval:
terraform -chdir=infra/workload apply ../../.workshop/portal.tfplan &&
bash ./scripts/deploy-portal.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" \
  -CapacityReviewPath ./.workshop/capacity-review.json
```

Applying a saved plan has no second Terraform approval prompt: **do not paste the whole example before approval**.
The code deployment separately asks before replacing the documentation on the specifically named participant app.
`-WhatIf` performs read checks but creates no package and uploads nothing.
The script verifies target, ownership tags, plan, runtime, TLS and disabled basic publishing, then creates
a private ZIP and uses `az webapp deploy` with Entra authentication. It never retrieves publishing credentials.
It refuses to overwrite an existing ZIP; choose a new private `-PackagePath` on repeat deployments.
Use the saved previous approved bundle with a fresh package path to roll back, through the same review and checks.

Check `terraform output public_portal_url`, its HTTPS `/health` (200 with `{"status":"ok"}`),
start page, both languages, diagrams and client preparation on the real host before sharing it.
No real Azure plan/apply/upload or deployed-site verification was performed during authoring.
Only Terraform schema/mock plans, local server and synthetic deployment checks are evidence so far.

## Clean up

Preflight creates nothing. If you applied this iteration's shared root, review a destroy plan against the
**same state and parameters**. This removes all workshop-owned resources currently tracked by that root,
not just the portal. Do not run it once later modules share that state unless full workshop teardown is intended.

```powershell
terraform '-chdir=infra\workload' plan -destroy '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\destroy.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Destroy plan failed.' }
terraform '-chdir=infra\workload' show '..\..\.workshop\destroy.tfplan'
# STOP: review exactly what is deleted and obtain separate approval.
# Only after approval:
terraform '-chdir=infra\workload' apply '..\..\.workshop\destroy.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Destroy failed.' }
```

```bash
terraform -chdir=infra/workload plan -destroy -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/destroy.tfplan &&
terraform -chdir=infra/workload show ../../.workshop/destroy.tfplan
# STOP: obtain separate deletion approval before applying this exact plan.
```

An existing administrator group is a data source, never a destroy target. Nonempty dedicated groups remain protected.
Preserve private state/parameters until deletion is verified; do not delete a whole group to hide untracked resources.

## Optional participant portal linked to your deployment

The presenter cannot deploy into participants' tenants. A participant who wants a portal that already knows
**their own** endpoint deploys the same App Service portal in **their own** subscription, with the same state
and parameters as their MCP workload, by following the procedure above.

When the portal and the MCP server share that Terraform state, the plan adds non-secret app settings to the portal:

| App setting | Source | When |
|---|---|---|
| `WORKSHOP_MCP_ENDPOINT` | `mcp_endpoint` (Function App HTTPS URL) | `enable_mcp_server = true` (module 02) |
| `WORKSHOP_MCP_SCOPE` | `mcp_auth_scope` (`api://…/user_impersonation`) | `enable_entra_auth = true` (module 03) |

The portal server checks both values again and serves only them at `/participant.json`.
The **Try your MCP** page prefills the endpoint and shows the delegated scope. Nothing is prefilled on GitHub Pages:
participants type their endpoint, which stays in browser memory.

- Never added: the module 02 system key, tokens, tenant or subscription IDs, connection strings or client secrets.
- The portal is public, so it reveals the endpoint hostname and scope. They are not secrets:
  the endpoint stays protected by the system key (level 0) or Microsoft Entra (level 1). Do not share the link
  outside your test group, and destroy the portal with the workload.
- Re-run the plan and the portal deployment after enabling a new module so the prefilled values follow it.
- Cost: one B1 plan per participant who opts in. This is optional; the shared GitHub Pages guides are enough.

## Deploy the participant workload

Start with [workspace choice](GETTING-STARTED.md) and [Azure context](DEPLOYMENT.md).
The participant signs into their approved tenant locally or inside their dev container, keeps their random
suffix/private state, and reviews a plan targeting their own resource group. Azure roles and Entra consent are distinct.
An optional participant-owned automation pipeline requires its own narrowly scoped federation and approval;
the public portal must never become a cross-tenant deployment control plane.

The Terraform group foundation and optional public App Service now exist. Full Functions, identity, gateway and observability
modules are not implemented or validated. Do not offer a one-click complete deployment or fabricate endpoint/key outputs.
The short-lived module 02 system key is entered only in the participant's client at runtime, never in the portal,
URL, chat, public output or saved client configuration.

## Sources

- [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
- [Pages publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
- [GitHub OIDC for Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure).
- [App Service built-in authentication](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization).
- [Node.js on App Service](https://learn.microsoft.com/azure/app-service/configure-language-nodejs).
- [Secretless ZIP deployment support](https://learn.microsoft.com/azure/app-service/deploy-authentication-types).
- [Run from package](https://learn.microsoft.com/azure/app-service/deploy-run-package).
- [App Service pricing](https://azure.microsoft.com/pricing/details/app-service/linux/).
- [Flex capacity](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan).
- [ACA authentication](https://learn.microsoft.com/azure/container-apps/authentication).
- [Source register](sources.md), [image usage notices](../assets/architecture/README.md).

Last verified: 2026-10-14. Local preparation only; no public-site or Azure deployment performed.

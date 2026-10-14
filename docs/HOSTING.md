# Publish the guides, deploy the workload separately

The public workshop portal and the Azure Model Context Protocol (MCP) services are different deployments.
The portal can help participants prepare their environment. It must not collect their Azure credentials,
accept a shared deployment key, or obtain access to their tenant.

| Component | Recommended location | Identity boundary |
|---|---|---|
| Public EN/FR guides, diagrams and workspace choices | GitHub Pages | Public static content. No Azure connection or deployment authority. |
| Optional internal copy of the guides | An explicitly selected App Service **or** Azure Container Apps application | Review its hosting, single-tenant access policy and costs separately. |
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

## Deploy the participant workload

Start with [workspace choice](GETTING-STARTED.md) and [Azure context](DEPLOYMENT.md).
The participant signs into their approved tenant locally or inside their dev container, keeps their random
suffix/private state, and reviews a plan targeting their own resource group. Azure roles and Entra consent are distinct.
An optional participant-owned automation pipeline requires its own narrowly scoped federation and approval;
the public portal must never become a cross-tenant deployment control plane.

Only the Terraform resource-group foundation currently exists. Full Functions, identity, gateway and observability
modules are not implemented or validated. Do not offer a one-click complete deployment or fabricate endpoint/key outputs.
The short-lived module 02 system key is entered only in the participant's client at runtime, never in the portal,
URL, chat, public output or saved client configuration.

## Sources

- [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
- [Pages publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
- [GitHub OIDC for Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure).
- [App Service built-in authentication](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization).
- [ACA authentication](https://learn.microsoft.com/azure/container-apps/authentication).
- [Source register](sources.md), [image usage notices](../assets/architecture/README.md).

Last verified: 2026-10-14. Static build preparation only; no public-site or Azure deployment performed.

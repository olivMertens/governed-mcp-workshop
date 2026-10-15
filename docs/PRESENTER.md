# Presenter: publish once, share the student link

[Français](fr/PRESENTER.md)

**You host the public guides. Participants run their own exercises.**
Publishing the portal does not deploy the Model Context Protocol (MCP) server.
Module 00 is validated, modules 01 to 03 are authored (offline checks pass), modules 04 onward remain planned.
Students can run [module 01](../modules/01-discover-mcp/README.md) without waiting for your portal or Azure deployment.

## Who deploys what

You cannot deploy into participants' tenants, and you must not try: no shared credential, no deployment key,
no guest account in their tenant. Each participant deploys in their own approved non-production subscription.

| Item | Who | Where |
|---|---|---|
| Shared guides (default) | Presenter | GitHub Pages, from this repository. No Azure, no tenant access. See [HOSTING.md](HOSTING.md#publish-with-github-pages). |
| Shared guides on App Service (optional) | Presenter | Only in a subscription the presenter owns (sections 1 to 4 below). Never in a participant tenant. |
| MCP workload, modules 02 onward | Each participant | Their own subscription and Microsoft Entra tenant, from their own terminal. |
| Personal portal prefilled with their endpoint (optional) | Each participant | Their own subscription. See [participant portal](HOSTING.md#optional-participant-portal-linked-to-your-deployment). |

Live validation of modules 02 onward happens in participants' subscriptions. A participant's PASS lines are
evidence for that participant only; do not ask them to send outputs that contain tenant or subscription IDs.

If you share the GitHub Pages link, skip to section 4's student message and section 5.
Sections 1 to 4 apply only if you host the shared copy in your own subscription.

## 1. Prepare your presenter workspace

Use a separate checkout and private Terraform state for this shared portal.
Use the default branch, `main`, for checkout and Codespaces.
Verify that everyone uses the same published revision before teaching.
Do not publish your administrator account, tenant, subscription, parameters, state or saved plans.

Follow the [module 00 PowerShell steps](../modules/00-prerequisites/README.md#steps):
check tools, prepare private parameters with a presenter label, select your approved test context,
then run the foundation validator. Choose a realistic expiry; the tag does not delete resources.

## 2. Create only the shared portal's resource group

From the repository root, in the same signed-in PowerShell terminal:

```powershell
terraform '-chdir=infra\workload' init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Foundation plan failed.' }
terraform '-chdir=infra\workload' show '..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Plan review failed.' }
```

**STOP: approve this exact target and saved plan.** Expect one new group, no service.
If using an existing administrator-provided group, Terraform does not create or own it.
Only after approval, run this separate command:

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Foundation apply failed.' }
```

## 3. Plan and publish the portal

Use the [App Service hosting procedure](HOSTING.md#optional-public-app-service-deployment).
It covers persistent `-EnablePublicPortal` opt-in with the original parameters, building the public bundle,
private quota/cost evidence, portal preflight, plan review and Entra-authenticated ZIP deployment.

Expect **one Linux B1 plan and one web app** in the group. No managed identity, Entra application,
Functions server or API Management is created by this portal deployment.
Public reading is intentional; deployment uses Microsoft Entra, not publishing keys.
B1 is billed while the plan exists, even when the website is stopped.
Apply the portal plan only after separate cost/plan approval. Keep the ZIP upload confirmation enabled.

## 4. Verify, then share

After a successful deployment, read the actual HTTPS hostname from Terraform:

```powershell
$portal = terraform '-chdir=infra\workload' output -raw public_portal_url
if ($LASTEXITCODE -ne 0 -or $portal -notmatch '^https://[a-z0-9.-]+\.azurewebsites\.net$') {
    throw 'No valid deployed portal URL.'
}
$health = Invoke-WebRequest -Uri "$portal/health" -TimeoutSec 30
if ($health.StatusCode -ne 200 -or $health.Content -cne '{"status":"ok"}') {
    throw 'Portal health check failed.'
}
"Student link (English): $portal/?lang=en#/start"
"Lien participant (francais) : $portal/?lang=fr#/start"
```

Open both links. Check language switching, modules 00/01 and diagrams before sending them.
Never send a guessed URL or one that has not passed these checks.

Suggested student message:

> Open the workshop link, choose your language and workspace, then follow module 00.
> Use only your approved test tenant and subscription. You do not need to host the shared guides.
> You deploy the MCP server yourself; optionally, you can deploy your own portal prefilled with your endpoint.
> Module 01 runs locally without Azure. Modules 02 and 03 are ready to run in your subscription; 04 onward are planned.
> Do not send credentials or tokens.

## 5. Close the session safely

Students clean up only resources they own. The presenter owns the shared portal.
Keep it until everyone has finished; then review and approve the
[Terraform destroy plan](HOSTING.md#clean-up). Stopping the site does not stop plan billing.
Keep private parameters and state until cleanup is confirmed.

## Sources

- [App Service deployment authentication](https://learn.microsoft.com/azure/app-service/deploy-authentication-types).
- [App Service Linux pricing](https://azure.microsoft.com/pricing/details/app-service/linux/).
- [Workshop hosting procedure](HOSTING.md).

Last verified: 2026-10-14. A prepared plan is not proof of deployment.

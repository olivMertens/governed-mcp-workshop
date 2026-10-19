# Presenter: publish once, share the student link

[Français](fr/PRESENTER.md)

**You host the public guides. Participants run their own exercises.**
Publishing the portal does not deploy the Model Context Protocol (MCP) server.
Modules 00 and 02 are validated live. Modules 03 to 06 passed their live operator checks in a test tenant,
but stay authored until the Alice, Bob and Eve persona checks pass. Modules 01, 07 and 99 are authored (offline checks pass).
See [PROGRESS.md](PROGRESS.md) for the evidence. Follow the run order in the [root README](../README.md).
Students can run [module 01](../modules/01-discover-mcp/README.md) without waiting for your portal or Azure deployment.

## Before the session: checklist

- [ ] **Register MFA for Alice, Bob and Eve.** Test tenants may require multifactor authentication (MFA).
  Sign in once with each test account and register a method (for example an authenticator app).
  Never weaken Conditional Access to skip it. Without this step, persona checks stop at the sign-in prompt.
- [ ] **Renew the capacity review before deploying the portal.** The portal preflight accepts a capacity review less than
  24 hours old only ([review capacity privately](HOSTING.md#review-capacity-privately)). Do it on the deployment day.
- [ ] **Plan API Management (module 04) for one day.** Standard v2 is billed per hour while it exists
  (roughly USD 1 per hour at the time of writing; check the pricing calculator for your region).
  Deploy it the same day you teach module 04 and clean it up that day.
- [ ] Open the real captures listed below, so you can fall back on them if a live step cannot run.

## Real captures to use as a fallback

Each module shows real captures from the author's test tenant at the step where they apply.
Names are pseudonymised, IDs are replaced by zeros, and pink frames mark what to check.
Use them when a live step cannot run (no consent yet, MFA not registered, quota, network).
A capture shows an expected result; it does not validate the participant's own deployment.

| Module | Step | Captures |
|---|---|---|
| 02 | [Steps](../modules/02-open-server/README.md#steps), private storage check | Storage networking: public access disabled, private endpoints approved |
| 03 | [Steps](../modules/03-entra-authentication/README.md#steps), operator and persona checks | Terminal: operator validator output, Alice persona check |
| 03 | [Check the same result in the Azure portal](../modules/03-entra-authentication/README.md#check-the-same-result-in-the-azure-portal) | Function authentication, app registration overview, app roles, enterprise app properties |
| 05 | [Identity administrator: approve trust and consent](../modules/05-delegated-and-app-only/README.md#identity-administrator-approve-trust-and-consent-before-applying) | API permissions, federated credential with no client secret |
| 06 | [Step 3 - Query MCP traffic](../modules/06-observe-inventory/README.md#step-3---query-mcp-traffic-in-application-insights) | Application Insights Logs in KQL mode, metadata only |
| 06 | [Optional - Observability Agent](../modules/06-observe-inventory/README.md#optional---ask-the-observability-agent-the-same-question) | Logs **Agent** toggle: question, generated KQL, same rows. Optional; skip if Azure Copilot is not offered in the tenant |

Each validator prints a purpose line, numbered `== Step N ==` headers with a `Why:` line, then one `PASS`/`FAIL` line per
check with the expected HTTP status. Read the terminal captures in that order with the room.

## Teach one step at a time

Before module 01, open **MCP and agent concepts** in the Start menu
([repository version](MCP-CONCEPTS.md)). Discuss host/client/server, the agent loop and tools/resources/prompts.
Use each prediction question before revealing its answer; the conceptual sequence does not execute a tool.

Module, Azure context and presenter pages show one authored step at a time.
Ask participants to explain the goal and predict the result **before** copying a command.
Run one short block in the same terminal, inspect the real output, then use **Next** at the bottom of the page.
That button only changes the page: it never executes code or records a passed exercise.

Pages read from top to bottom: position, content, then the buttons. To return to an explanation, open the
**Outline** below the buttons. Long blocks stay closed until deliberately opened;
their checks are never split automatically. The complete guide and architecture remain available in closed sections.
Long sections continue across numbered parts, targeting 180 visible words per page at complete content boundaries.
Paragraphs, table rows, nested list items, executable blocks and disclosures stay intact; table headers repeat on continuation pages.
An indivisible element can exceed the target.
Selecting another page does not validate the preceding one.
Do not project private outputs. Keep approvals, identity-administrator actions and cleanup as explicit pauses.

Use the appearance button in the top bar to open the Microsoft/Azure dialog.
Choose **Template** (original style, follows system colors), **White**, or **Dark**.
White and Dark use neutral surfaces with small Azure-blue accents. The choice stays in the current browser;
it does not change the shared guide or deploy anything. Press Escape or the close button to return to the lesson.

## Who deploys what

You cannot deploy into participants' tenants, and you must not try: no shared credential, no deployment key,
no guest account in their tenant. Each participant deploys in their own approved non-production subscription.

| Item | Who | Where |
|---|---|---|
| Shared guides on App Service (current) | Presenter | Only in a subscription the presenter owns (sections 1 to 4 below). Never in a participant tenant. The published portal uses this route; language is chosen with `?lang=en` or `?lang=fr`. |
| Shared guides on GitHub Pages (alternative, off today) | Presenter | From this repository once it is public. No Azure, no tenant access. See [HOSTING.md](HOSTING.md#publish-with-github-pages). |
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

### 2.1 Initialize without deploying

**Why:** Terraform must load the locked providers before it can plan.
**Predict:** initialization succeeds without creating Azure resources.

```powershell
terraform '-chdir=infra\workload' init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
```

**Observe:** initialization succeeds. Stop on an error; do not update the lock file to bypass it.

### 2.2 Predict the changes

**Why:** a plan is a proposal, not a deployment.
**Predict:** one group is added, or an existing approved group is read. No service should be created.

```powershell
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Foundation plan failed.' }
```

**Observe:** the plan summary. Explain the proposed changes before continuing.

### 2.3 Inspect the saved plan

**Why:** approval applies to this exact saved plan, not to a later recalculation.
**Action:** read the target group, tags and changes. Keep private output in your terminal.

```powershell
terraform '-chdir=infra\workload' show '..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Plan review failed.' }
```

**Observe:** only the approved foundation. If a paid service or unexpected deletion appears, stop.

### 2.4 Apply only after approval

**STOP: approve this exact target and saved plan.** Expect one new group, no service.
If using an existing administrator-provided group, Terraform does not create or own it.
Only after approval, run this separate command:

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Foundation apply failed.' }
```

**Observe:** the approved group exists, or the administrator-provided group is reused. No portal is published yet.

## 3. Plan and publish the portal

Use the [App Service hosting procedure](HOSTING.md#optional-public-app-service-deployment).
It covers persistent `-EnablePublicPortal` opt-in with the original parameters, building the public bundle,
private quota/cost evidence, portal preflight, plan review and Entra-authenticated ZIP deployment.

Live example (presenter subscription, 2026-10-16): the portal is served at `https://<web-app>.azurewebsites.net/?lang=en#/start` and `?lang=fr#/start`. Health check: `/health`. Language paths such as `/en/` return 404 by design; use the `?lang=` query.

Expect **one Linux B1 plan and one web app** in the group. No managed identity, Entra application,
Functions server or API Management is created by this portal deployment.
Public reading is intentional; deployment uses Microsoft Entra, not publishing keys.
B1 is billed while the plan exists, even when the website is stopped.
Apply the portal plan only after separate cost/plan approval. Keep the ZIP upload confirmation enabled.

## 4. Verify, then share

After a successful deployment, read the actual HTTPS hostname from Terraform:

### 4.1 Identify the deployed site

**Why:** a calculated name is not evidence that a site exists.
**Predict:** your deployed state returns an HTTPS App Service address.

```powershell
$portal = terraform '-chdir=infra\workload' output -raw public_portal_url
if ($LASTEXITCODE -ne 0 -or $portal -notmatch '^https://[a-z0-9.-]+\.azurewebsites\.net$') {
    throw 'No valid deployed portal URL.'
}
```

**Observe:** `$portal` contains the validated address in this terminal. Do not share it yet.

### 4.2 Test the site, not only its address

**Why:** the site can exist without serving the expected bundle.
**Predict:** the health endpoint returns HTTP 200 and exactly `{"status":"ok"}`.

```powershell
$health = Invoke-WebRequest -Uri "$portal/health" -TimeoutSec 30
if ($health.StatusCode -ne 200 -or $health.Content -cne '{"status":"ok"}') {
    throw 'Portal health check failed.'
}
$health.StatusCode
```

**Observe:** 200 and no error. If the check fails, investigate before sharing.

### 4.3 Open both languages before sharing

**Action:** only after the health check succeeds, print the two links.

```powershell
if (-not $health -or $health.StatusCode -ne 200 -or $health.Content -cne '{"status":"ok"}') { throw 'Check portal health first.' }
"Student link (English): $portal/?lang=en#/start"
"Lien participant (francais) : $portal/?lang=fr#/start"
```

Open both links. Check language switching, modules 00/01 and diagrams before sending them.
Never send a guessed URL or one that has not passed these checks.

**Before continuing:** have an attendee explain the first action. If it is unclear, do not send a larger script.

Suggested student message:

> Open the workshop link, choose your language and workspace, then follow module 00.
> Use only your approved test tenant and subscription. You do not need to host the shared guides.
> You deploy the MCP server yourself; optionally, you can deploy your own portal prefilled with your endpoint.
> Module 01 runs locally without Azure. Modules 02 to 07 run in your own subscription, in the order of the root README; run module 99 after every paid stage.
> If your test tenant asks you to register MFA at first sign-in, do it; never turn off a sign-in control.
> Do not send credentials or tokens.

## 5. Close the session safely

Students clean up only resources they own. The presenter owns the shared portal.
Before everyone leaves, remind attendees to remove module 04 API Management the same day (module 99 cleanup), because it is billed per hour.
Keep it until everyone has finished; then review and approve the
[Terraform destroy plan](HOSTING.md#clean-up). Stopping the site does not stop plan billing.
Keep private parameters and state until cleanup is confirmed.

## Sources

- [App Service deployment authentication](https://learn.microsoft.com/azure/app-service/deploy-authentication-types).
- [App Service Linux pricing](https://azure.microsoft.com/pricing/details/app-service/linux/).
- [Workshop hosting procedure](HOSTING.md).

Last verified: 2026-10-14. A prepared plan is not proof of deployment.

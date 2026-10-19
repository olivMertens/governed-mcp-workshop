# 03 - Identité avec Microsoft Entra (niveau 1)

[English](README.md)

## Objectif

Remplacer la clé partagée du module 02 par une connexion **Microsoft Entra ID**. L'authentification intégrée de la
Function App contrôle chaque requête avant qu'elle n'atteigne le serveur MCP. À la fin :

- une requête sans jeton reçoit **HTTP 401** ;
- un jeton valide pour **une autre audience** (Microsoft Graph) reçoit **HTTP 401** ;
- **Alice** et **Bob** (attribués) reçoivent **HTTP 200** ;
- **Eve** (non attribuée) **ne peut même pas obtenir de jeton**.

> [!WARNING]
> Ne collez jamais un vrai jeton dans un site web, une conversation, un fichier, une capture d'écran ou un journal.
> Utilisez les [exemples de revendications synthétiques](synthetic-claims/) pour apprendre ce que contient un jeton.

## Pourquoi cette étape compte

Une clé n'identifie personne. Un jeton d'accès Microsoft Entra indique **qui** appelle (`oid`), **depuis quel tenant**
(`tid`, `iss`), **avec quelle application** (`azp`), **pour quelle API** (`aud`), **ce que l'application peut faire pour
l'utilisateur** (`scp`) et **ce que l'utilisateur a le droit de faire** (`roles`). La plateforme vérifie tout cela ;
le code du serveur ne lit jamais le jeton lui-même.

| Revendication | Sens | Valeur synthétique (Alice, voir [alice.json](synthetic-claims/alice.json)) | Qui la vérifie au niveau 1 |
|---|---|---|---|
| `aud` | Audience : l'API à laquelle le jeton est destiné. Un jeton par appel, une audience par jeton. | `44444444-…` (ID client de l'API MCP) | Authentification intégrée : seulement l'API MCP |
| `iss`, `tid` | Émetteur et tenant | `https://login.microsoftonline.com/00000000-…/v2.0` | Authentification intégrée : seulement le tenant de l'atelier |
| `azp` | Application cliente appelante | `aebc6443-…` (Visual Studio Code) | Règle d'autorisation intégrée : seulement les clients autorisés |
| `scp` | **Scope** (permission déléguée) : ce que *l'application cliente* peut faire *pour l'utilisateur* | `user_impersonation` | Pré-autorisation du client dans Entra |
| `roles` | **Rôles d'application** : ce que *cet utilisateur* a le droit de faire | `Tools.Read`, `Tools.Write` | Entra n'émet des rôles qu'aux utilisateurs attribués ; le contrôle par outil arrive au module 04 |
| `exp`, `nbf` | Période de validité | horodatages synthétiques | Authentification intégrée |

### Prévoir les accès d'Alice, Bob et Eve

Bob a les mêmes `aud` et `scp`, mais seulement `Tools.Read` ([bob.json](synthetic-claims/bob.json)).
Eve n'obtient jamais de jeton : Entra refuse avec `AADSTS50105`, car **l'attribution est obligatoire** et elle n'a aucun rôle
([eve.json](synthetic-claims/eve.json)). Un jeton Graph détenu par Alice est valide, mais pour une autre audience :
le serveur MCP le refuse ([wrong-audience.json](synthetic-claims/wrong-audience.json)).

> [!IMPORTANT]
> L'authentification intégrée contrôle l'accès **au serveur**, pas à chaque outil. Au niveau 1, Bob peut encore appeler
> `create_ticket`. Le module 04 ajoute le contrôle de rôle par outil (`create_ticket` exige `Tools.Write`).

### Comprendre le changement d'authentification en deux étapes

**Pourquoi la clé de fonction n'est plus la barrière.** L'authentification intégrée s'exécute devant l'hôte Functions et
renvoie HTTP 401 avant l'exécution du moindre code MCP. Le paramètre documenté
`AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel = Anonymous` indique alors à l'extension MCP de ne
plus demander la clé système : une clé est un secret partagé que les clients devraient aussi détenir, et elle n'apporte
aucune identité. Le webhook n'est anonyme *que du point de vue de l'hôte* : aucun appel anonyme ne l'atteint depuis Internet. `host.json`
conserve `System` : un paquet déployé sans authentification intégrée reste protégé par la clé. Terraform ne définit ce paramètre
qu'une fois l'authentification intégrée en place, et seulement lors d'un **second apply** (deux étapes). En effet, Azure écrit
les paramètres d'application et ceux d'authentification en deux appels distincts : tout appliquer d'un coup pourrait exposer
brièvement le webhook.

## Ce que vous déployez

**Microsoft Entra (`infra/entra`, exécuté une fois par un administrateur des identités) :**

| Objet | Réglages |
|---|---|
| Inscription d'application « Workshop MCP API (mcp-&lt;préfixe&gt;-&lt;suffixe&gt;) » | Un seul tenant, jetons d'accès v2, URI d'ID d'application `api://<client-id>`, aucune URI de redirection, **aucun secret, certificat ni mot de passe** |
| Scope délégué | `user_impersonation` |
| Rôles d'application | `Tools.Read`, `Tools.Write` (membres : utilisateurs) ; `Tools.Execute.All` (membres : applications, non attribué ici) |
| Application d'entreprise (principal de service) | **Attribution obligatoire** = oui |
| Clients pré-autorisés pour `user_impersonation` | Visual Studio Code `aebc6443-996d-45c2-90f0-388ff96faa56`, Azure CLI `04b07795-8ddb-461a-bbee-02f9e1bf7b46` |
| Attributions de rôles (comptes de test existants seulement) | Alice → `Tools.Read` + `Tools.Write` ; Bob → `Tools.Read` ; Eve → aucune |

Aucune permission Microsoft Graph ou Storage n'est encore demandée, donc **aucun consentement administrateur** n'est
nécessaire : les clients pré-autorisés obtiennent `user_impersonation` sans demande de consentement. Le module 05 ajoute les
permissions On-Behalf-Of et la fédération d'identité pour l'identité managée (la sortie `module05_federated_credential`
en prépare les valeurs).

**Charge de travail (`infra/workload`, participant) :** une mise à jour en place de la Function App du module 02 :

| Réglage | Valeur |
|---|---|
| Authentification intégrée (authsettingsV2) | Activée, **authentification obligatoire**, non authentifié → **HTTP 401**, HTTPS seulement, magasin de jetons désactivé |
| Fournisseur Microsoft | ID client de l'API MCP, émetteur `https://login.microsoftonline.com/<tenant>/v2.0`, aucun paramètre de secret |
| Audiences autorisées | `api://<client-id>` et `<client-id>` seulement (la même API, formats de jeton v1 et v2) |
| Applications clientes autorisées | VS Code et Azure CLI |
| `WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES` | `api://<client-id>/user_impersonation` (**Preview** : métadonnées de ressource protégée) |
| `WEBSITE_AUTH_AAD_ALLOWED_TENANTS` | Votre ID de tenant |
| `AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel` | `Anonymous`, **étape 2 seulement**, une fois l'authentification intégrée appliquée |

![Architecture du niveau 1](../../assets/architecture/03.fr.svg)

**Preview :** les métadonnées de ressource protégée (PRM, RFC 9728) de l'authentification App Service sont en **Preview** ;
leur configuration peut changer. L'atelier n'utilise pas le bouton « authentification MCP » du portail (**Preview**) : il crée
un secret client.

**Coût :** aucune nouvelle ressource Azure. L'authentification intégrée et les objets Entra n'entraînent pas de frais
supplémentaires. Toute modification des paramètres d'application redémarre l'application.

## Prérequis et rôles nécessaires

- Module 02 déployé, avec les mêmes paramètres privés et le même état Terraform (`participant.tfvars.json`, `module02.tfvars.json`).
- Terraform 1.16.6 ou version ultérieure, Azure CLI, PowerShell 7.4+. VS Code avec GitHub Copilot pour la démonstration de connexion.
- Trois comptes de test **existants, dédiés et hors production** dans le tenant : Alice, Bob et Eve. L'administrateur des
  identités les crée séparément (par exemple avec un Temporary Access Pass) et ne transmet que leurs ID d'objet, en privé.
  Terraform ne crée jamais d'utilisateurs : le fournisseur AzureAD enregistrerait leur mot de passe initial dans l'état.

**Administrateur des identités** (personne ou session distincte, rôle limité dans le temps via Privileged Identity Management si possible) :

- **Administrateur d'applications cloud** (ou Administrateur d'applications) pour créer l'inscription, l'application
  d'entreprise, les pré-autorisations et les attributions de rôles. Pas d'Administrateur général, pas de consentement
  administrateur pour ce module.
- **Administrateur des utilisateurs** seulement pour créer les comptes de test, hors Terraform.

**Participant :** les rôles du module 02 sur le groupe de ressources de l'atelier (Contributeur). Aucune nouvelle attribution de rôle.

La demande complète à envoyer à l'administrateur des identités se trouve dans [identity-request.md](../../docs/requests/identity-request.md).

## Étapes

### PowerShell

Exécutez les commandes depuis la racine du dépôt. Les étapes 2 à 7 modifient Microsoft Entra ou Azure : ne les exécutez qu'après approbation.

**1. Vérifications hors ligne (sans Azure ni Entra).**

```powershell
& .\modules\03-entra-authentication\validate.ps1 -Offline
```

> **Résultat attendu** — d'après les messages du validateur ; pas encore une capture. Aucun appel à Azure ni à Entra.
>
> ```text
> PASS host.json keeps the level 0 System webhook level; the published package is never anonymous on its own (expected HTTP N/A).
> PASS the key gate is removed only together with enforced built-in authentication and Return401 (expected HTTP 401 without a token).
> PASS infra/entra: single tenant, user_impersonation, Tools.Read/Tools.Write/Tools.Execute.All, assignment required, no secret or user (expected HTTP N/A).
> PASS no access token, key, SAS or client secret in module 03, infra/entra or workload files (expected HTTP N/A).
> PASS synthetic claim examples use synthetic IDs only and contain no token (4 files, expected HTTP N/A).
> PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).
> NOT DEPLOYED CHECKS SKIPPED: supply -TenantId with -SubscriptionId (operator) or -Persona (test account) after an approved deployment.
> PASS offline checks only. Module 03 is NOT deployed or Entra-validated by this result.
> ```
>
> **Ce que cela signifie pour vous :** le code et Terraform gardent toutes les barrières fermées et ne contiennent aucun secret.
> Rien n'est encore déployé.

**2. Administrateur des identités : connexion au tenant seulement.** Utilisez un terminal distinct.
`--allow-no-subscriptions` suffit.

```powershell
az login --tenant <tenant-id> --allow-no-subscriptions
```

> **Résultat attendu** — forme de la sortie Azure CLI ; ce n'est pas une capture. Le navigateur ouvre une page de connexion.
> Azure CLI liste ensuite les comptes utilisables. Un tenant où cet administrateur n'a pas d'abonnement apparaît comme
> `N/A(tenant level account)`.
>
> **Ce que cela signifie pour vous :** l'administrateur travaille uniquement dans le tenant et n'a besoin d'aucun rôle sur un abonnement Azure.

**3. Administrateur des identités : paramètres privés.** Reprenez le préfixe, le suffixe, le propriétaire et l'expiration
du participant (reçus en privé) et les ID d'objet des trois comptes de test. Git ignore ce fichier.

```powershell
$p = Get-Content -LiteralPath .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
@{
    tenant_id = '<tenant-id>'; participant_prefix = $p.participant_prefix; resource_suffix = $p.resource_suffix
    owner = $p.owner; expiry = $p.expiry
    test_user_object_ids = @{ alice = '<alice-object-id>'; bob = '<bob-object-id>'; eve = '<eve-object-id>' }
} | ConvertTo-Json | Set-Content -LiteralPath .\.workshop\entra.tfvars.json
```

> **Résultat attendu** — aucune sortie. En cas de réussite, la commande n'affiche rien.
> Vérifiez avec `Test-Path .\.workshop\entra.tfvars.json`, qui affiche `True`. Le fichier ne contient que des ID, aucun secret.

Pour réutiliser une application déjà créée par un administrateur, ajoutez `"create_application": false` et
`"existing_application_client_id": "<client-id>"`. Terraform se contente alors de la lire (et de vérifier son scope,
ses rôles et l'attribution obligatoire) ; il ne la modifie ni ne la supprime jamais.

**4. Administrateur des identités : planifier, relire, appliquer.**

```powershell
terraform -chdir=infra/entra init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\entra' plan '-var-file=..\..\.workshop\entra.tfvars.json' '-out=..\..\.workshop\entra.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
# Relire : 8 ajouts (application, URI, application d'entreprise, 2 pré-autorisations, 3 attributions). Puis, après approbation :
terraform '-chdir=infra\entra' apply '..\..\.workshop\entra.tfplan'
```

> **Résultat réel** — extrait de l'apply pour la création, 2026-10-17, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> azuread_application.mcp[0]: Creation complete after 6s [id=/applications/<guid>]
> ...
> azuread_application_pre_authorized.clients["<guid>"]: Creation complete after 1s [id=<guid>/preAuthorizedApplication/<guid>]
> azuread_service_principal.mcp[0]: Creation complete after 3s [id=/servicePrincipals/<guid>]
> ...
> Apply complete! Resources: 8 added, 0 changed, 0 destroyed.
>
> Outputs:
> ...
> identifier_uri = "api://<guid>"
> ...
> persona_assignments = {
>   "alice-read" = "Tools.Read"
>   "alice-write" = "Tools.Write"
>   "bob-read" = "Tools.Read"
> }
> ...
> user_impersonation_scope = "api://<guid>/user_impersonation"
> ```
>
> Avec `create_application = false`, Terraform se contente de lire l'application existante : attendez-vous aux trois attributions seulement.
>
> **Ce que cela signifie pour vous :** huit objets Entra, sans mot de passe ni certificat : Eve n'a aucune attribution.
> Votre plan doit afficher `Plan: 8 to add, 0 to change, 0 to destroy.` Lors d'une première exécution, arrêtez-vous si
> le plan affiche `to destroy` ou `to change`.

**5. Transmission au participant (ID non secrets seulement).**

```powershell
terraform -chdir=infra/entra output -json workload_module03_tfvars | Set-Content -LiteralPath .\.workshop\module03.tfvars.json
terraform -chdir=infra/entra output -json persona_object_ids | Set-Content -LiteralPath .\.workshop\module03-personas.json
```

> **Résultat attendu** — aucune sortie. Les deux fichiers existent maintenant dans `.workshop` (ignoré par Git) et ne
> contiennent que des ID : ID client, ID de tenant, audience et ID d'objet. Vérifiez avec `Test-Path .\.workshop\module03.tfvars.json`.

**6. Participant, étape 1 : placer Entra devant la clé.** Sélectionnez d'abord votre contexte approuvé
(`& .\scripts\select-azure-context.ps1`). Passez désormais toujours les trois fichiers de variables.

```powershell
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-var-file=..\..\.workshop\module02.tfvars.json' '-var-file=..\..\.workshop\module03.tfvars.json' '-out=..\..\.workshop\module03.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
# Relire : une mise à jour en place de la Function App (auth_settings_v2 et deux paramètres WEBSITE_AUTH_*). Après approbation :
terraform '-chdir=infra\workload' apply '..\..\.workshop\module03.tfplan'
```

> **Résultat réel** — extrait du plan et de l'apply de l'étape 1, 2026-10-17, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> Plan: 0 to add, 2 to change, 0 to destroy.
> ...
> azurerm_function_app_flex_consumption.mcp[0]: Modifications complete after 53s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.Web/sites/func-mcp-p01-<suffix>]
> ...
> azurerm_linux_web_app.portal[0]: Modifications complete after 1m3s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.Web/sites/web-mcp-p01-<suffix>-portal]
> Apply complete! Resources: 0 added, 2 changed, 0 destroyed.
> ```
>
> **Ce que cela signifie pour vous :** le serveur est mis à jour en place, pas remplacé. L'application redémarre une fois.
> Chez l'auteur, **2** ressources ont changé, car le portail facultatif a aussi reçu l'indication de connexion
> `WORKSHOP_MCP_SCOPE`. Sans portail, attendez-vous à `Plan: 0 to add, 1 to change, 0 to destroy.` (la Function App seule).

Un appelant a maintenant besoin d'un jeton **et** de la clé : rien n'est anonyme.

**7. Participant, étape 2 : Entra remplace la clé.**

```powershell
$v = Get-Content -LiteralPath .\.workshop\module03.tfvars.json -Raw | ConvertFrom-Json
$v.entra_auth_replace_key_gate = $true
$v | ConvertTo-Json | Set-Content -LiteralPath .\.workshop\module03.tfvars.json
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-var-file=..\..\.workshop\module02.tfvars.json' '-var-file=..\..\.workshop\module03.tfvars.json' '-out=..\..\.workshop\module03.tfplan'
# Relire : une mise à jour en place qui ajoute le paramètre du webhook. Après approbation :
terraform '-chdir=infra\workload' apply '..\..\.workshop\module03.tfplan'
```

> **Résultat réel** — extrait du plan et de l'apply de l'étape 2, 2026-10-17, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> Plan: 0 to add, 1 to change, 0 to destroy.
> ...
> azurerm_function_app_flex_consumption.mcp[0]: Modifications complete after 49s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.Web/sites/func-mcp-p01-<suffix>]
> Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
> ```
>
> **Ce que cela signifie pour vous :** la seule modification est le paramètre du webhook. Si le plan retire aussi
> `auth_settings_v2`, arrêtez-vous : un fichier de variables manque.

Aucun code n'est republié : `host.json` ne change pas.

**8. Vérifications opérateur (aucun compte de test nécessaire).**

```powershell
& .\modules\03-entra-authentication\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

> **Résultat réel** — vérifications opérateur, 2026-10-19, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> Module 03 validator - only Microsoft Entra tokens issued for the MCP audience open the server.
>
> == Step 1: Offline - your copy keeps every gate closed (no Azure call) ==
>    Why: Proves the code, Terraform and examples tie access to Entra and hold no secret or token.
> PASS host.json keeps the level 0 System webhook level; the published package is never anonymous on its own (expected HTTP N/A).
> PASS the key gate is removed only together with enforced built-in authentication and Return401 (expected HTTP 401 without a token).
> PASS infra/entra: single tenant, user_impersonation, Tools.Read/Tools.Write/Tools.Execute.All, assignment required, no secret or user (expected HTTP N/A).
> PASS no access token, key, SAS or client secret in module 03, infra/entra or workload files (expected HTTP N/A).
> PASS synthetic claim examples use synthetic IDs only and contain no token (4 files, expected HTTP N/A).
>
> == Step 2: Live - the server refuses callers without the right token ==
>    Why: Proves no token, or a token for another audience, gets HTTP 401 while metadata guides clients.
> PASS MCP request without a token is refused by built-in authentication (expected HTTP 401).
> PASS Protected Resource Metadata (Preview) names the tenant authorization server and the user_impersonation scope (expected HTTP 200).
> PASS a valid token for another audience (Microsoft Graph) is refused (expected HTTP 401).
>
> == Step 3: Azure configuration matches Terraform ==
>    Why: Proves built-in authentication and app settings are deployed as the code describes, and the key alone fails.
> PASS explicit Azure context matches the approved test target (expected HTTP 200 from Azure Resource Manager).
> PASS deployed authsettingsV2: required, Return401, tenant issuer, MCP audience only, no secret setting (expected HTTP 200 from Azure Resource Manager).
> PASS app settings: webhook key gate replaced by Entra, PRM scope set (Preview) (expected HTTP 200 from Azure Resource Manager).
> PASS the level 0 system key alone no longer opens the server (expected HTTP 401).
> INFO persona checks skipped. Sign in as each test account in a separate AZURE_CONFIG_DIR and rerun with -Persona Alice, Bob, then Eve.
> PASS module 03 operator checks complete. Persona checks are still required for validation.
> ```n>
> **Ce que cela signifie pour vous :** la plateforme refuse désormais les appelants **avant que votre code s'exécute**.
> Un vrai jeton Microsoft ne suffit pas : il doit être émis **pour ce serveur** (audience). Seule, l'ancienne clé
> partagée ne sert plus à rien.

Comment lire cette sortie : chaque en-tête `== Step N ==` annonce ce qui est vérifié, et sa ligne `Why:` dit ce que
l'étape prouve. Chaque contrôle affiche ensuite une ligne `PASS` (ou `FAIL`) avec le statut HTTP attendu. Sur la capture
ci-dessous, les cadres numérotés montrent quoi regarder en premier : (1) sans le bon jeton, le serveur répond HTTP 401 ;
(2) l'ancienne clé seule ne l'ouvre plus ; (3) la partie opérateur est terminée, mais les comptes de test doivent encore
se connecter. Le script s'affiche en anglais.

![Sortie réelle du terminal : vérifications opérateur du module 03, cadres sur les contrôles HTTP 401, sur la clé qui n'ouvre plus le serveur et sur le rappel des personas](../../assets/screenshots/terminal-03-operator.png)

**Question :** Alice détient un jeton Microsoft Graph valide de votre tenant et l'envoie au serveur MCP. Est-il accepté ?

<details>
<summary>Afficher la réponse</summary>

Non, HTTP 401. Le jeton est authentique, mais son audience (`aud`) est Microsoft Graph, pas l'API MCP. Un jeton par appel,
une audience par jeton : le serveur n'accepte que les jetons émis pour `api://<client-id>`. L'inverse vaut aussi : le serveur
ne doit jamais transmettre le jeton d'Alice à Graph (pas de token passthrough) : le module 05 utilise On-Behalf-Of.

</details>

**9. Connecter VS Code avec une connexion Entra.** Dans votre configuration MCP **utilisateur**, remplacez le serveur
`workshop-open` (et sa demande de clé) par une simple URL. Aucun en-tête, rien de secret.

```json
{
  "servers": {
    "workshop-entra": { "type": "http", "url": "https://<function-app-host>/runtime/webhooks/mcp" }
  }
}
```

Démarrez le serveur. VS Code lit les métadonnées de ressource protégée et vous propose de vous **authentifier avec
Microsoft**. Connectez-vous en tant qu'Alice : les cinq outils apparaissent. Connectez-vous en tant qu'Eve (autre profil
VS Code) : Entra affiche `AADSTS50105`.

**10. Vérifications par persona.** Utilisez un profil Azure CLI distinct pour chaque compte de test afin de ne pas écraser votre session.

Votre tenant peut exiger l'authentification multifacteur (MFA). À sa première connexion, chaque compte de test doit
enregistrer une méthode (par exemple une application d'authentification). Faites-le dans le navigateur ouvert par
`az login` ; n'assouplissez jamais une stratégie d'accès conditionnel pour l'éviter.

```powershell
foreach ($persona in 'Alice', 'Bob', 'Eve') {
    $env:AZURE_CONFIG_DIR = Join-Path $PWD ".workshop\az-$($persona.ToLower())"
    az login --tenant $env:ARM_TENANT_ID --allow-no-subscriptions   # connectez-vous en tant que $persona dans le navigateur
    & .\modules\03-entra-authentication\validate.ps1 -TenantId $env:ARM_TENANT_ID -Persona $persona
    az logout
}
Remove-Item Env:\AZURE_CONFIG_DIR
```

> **Résultat réel** — Alice, 2026-10-19, tenant de test de l'auteur, après l'enregistrement de sa MFA. Noms et ID masqués.
>
> ```text
> == Step 3: Persona - Alice signs in and lists the tools ==
>    Why: Proves an assigned user gets a token for the MCP audience and sees the five tools.
> PASS signed-in account matches the private Alice object ID (expected HTTP 200 from Microsoft Graph).
> PASS Alice initialize with a token for the MCP audience succeeds; negotiated protocol 2025-06-18 (expected HTTP 200).
> PASS Alice tools/list returns exactly the five workshop tools (expected HTTP 200).
> PASS module 03 persona checks complete for Alice. Per-tool roles (Bob cannot write) are enforced in module 04.
> ```

![Sortie réelle du terminal : vérification persona du module 03 connectée en tant qu'Alice ; le cadre 1 marque l'étape persona, le cadre 2 le jeton accepté et les cinq outils listés](../../assets/screenshots/terminal-03-alice.png)

> **Résultat attendu** — Bob et Eve ; pas encore capturé (leur enregistrement MFA reste à faire dans le tenant de test).
>
> ```text
> PASS Bob initialize with a token for the MCP audience succeeds; negotiated protocol <version> (expected HTTP 200).
> PASS Bob tools/list returns exactly the five workshop tools (expected HTTP 200).
> PASS Eve cannot obtain a token: she is not assigned to the enterprise application (expected HTTP 400 from the token endpoint, AADSTS50105).
> ```
>
> **Ce que cela signifie pour vous :** vous savez maintenant **qui** appelle. Eve est arrêtée à la connexion et
> n'atteint jamais le serveur. Mais Alice et Bob voient les mêmes cinq outils, **écriture comprise** : être connecté
> ne veut pas encore dire être autorisé. Le module 04 ajoute les rôles par outil.

**Question :** Bob est connecté et reçoit HTTP 200. Son jeton ne porte que `Tools.Read`. Peut-il appeler `create_ticket` au niveau 1 ?

<details>
<summary>Afficher la réponse</summary>

Oui. L'authentification intégrée décide qui peut atteindre le serveur, pas quel outil s'exécute. La revendication `roles`
est bien dans le jeton de Bob, mais rien ne la contrôle encore outil par outil. Le module 04 exige `Tools.Write` pour
`create_ticket`. L'approbation humaine dans VS Code ne remplace pas ce contrôle de rôle.

</details>

### Bash

```bash
bash ./modules/03-entra-authentication/validate.sh -Offline
# Administrateur des identités, terminal séparé :
az login --tenant "<tenant-id>" --allow-no-subscriptions
jq -n --slurpfile p .workshop/participant.tfvars.json --arg t "<tenant-id>" \
  '{tenant_id:$t, participant_prefix:$p[0].participant_prefix, resource_suffix:$p[0].resource_suffix, owner:$p[0].owner, expiry:$p[0].expiry,
    test_user_object_ids:{alice:"<alice-object-id>", bob:"<bob-object-id>", eve:"<eve-object-id>"}}' > .workshop/entra.tfvars.json
terraform -chdir=infra/entra init -lockfile=readonly &&
terraform -chdir=infra/entra plan -var-file=../../.workshop/entra.tfvars.json -out=../../.workshop/entra.tfplan
terraform -chdir=infra/entra apply ../../.workshop/entra.tfplan    # après relecture et approbation
terraform -chdir=infra/entra output -json workload_module03_tfvars > .workshop/module03.tfvars.json
terraform -chdir=infra/entra output -json persona_object_ids > .workshop/module03-personas.json
# Participant, étape 1 puis étape 2 (relire chaque plan, appliquer après approbation) :
source ./scripts/select-azure-context.sh
vars="-var-file=../../.workshop/participant.tfvars.json -var-file=../../.workshop/module02.tfvars.json -var-file=../../.workshop/module03.tfvars.json"
terraform -chdir=infra/workload plan $vars -out=../../.workshop/module03.tfplan && terraform -chdir=infra/workload apply ../../.workshop/module03.tfplan
jq '.entra_auth_replace_key_gate = true' .workshop/module03.tfvars.json > .workshop/m03.tmp && mv .workshop/m03.tmp .workshop/module03.tfvars.json
terraform -chdir=infra/workload plan $vars -out=../../.workshop/module03.tfplan && terraform -chdir=infra/workload apply ../../.workshop/module03.tfplan
bash ./modules/03-entra-authentication/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
for persona in Alice Bob Eve; do
  export AZURE_CONFIG_DIR="$PWD/.workshop/az-${persona,,}"
  az login --tenant "$ARM_TENANT_ID" --allow-no-subscriptions
  bash ./modules/03-entra-authentication/validate.sh -TenantId "$ARM_TENANT_ID" -Persona "$persona"
  az logout
done
unset AZURE_CONFIG_DIR
```

> **Résultat attendu** — les mêmes lignes PASS, les mêmes résumés de plan et les mêmes écritures de fichiers silencieuses
> que l'exécution PowerShell ci-dessus.

## Ce que vous devez voir

| Action | Résultat attendu | Signification |
|---|---|---|
| Requête MCP sans jeton | HTTP 401 avec `WWW-Authenticate: Bearer … resource_metadata="…"` | L'authentification intégrée refuse avant l'exécution du code MCP. |
| `GET` sur l'URL `resource_metadata` | HTTP 200, `authorization_servers` = votre tenant, `scopes_supported` = `api://…/user_impersonation` | Les PRM (**Preview**) indiquent aux clients où se connecter. |
| Requête avec la seule clé du niveau 0 | HTTP 401 | La clé n'est plus la barrière. |
| Jeton Microsoft Graph d'Alice | HTTP 401 | Mauvaise audience : une audience par jeton. |
| Alice, puis Bob, avec un jeton pour `api://<client-id>` | HTTP 200, cinq outils | Les utilisateurs attribués atteignent le serveur. |
| Eve demande un jeton | `AADSTS50105`, aucun jeton | Attribution obligatoire : Eve n'atteint jamais le serveur. |
| Bob appelle `create_ticket` dans VS Code | Fonctionne encore au niveau 1 | Accès au serveur seulement ; le module 04 ajoute les rôles par outil. |

> **Résultat réel** — requête MCP sans jeton, 2026-10-17, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> HTTP 401
> WWW-Authenticate: Bearer ... resource_metadata="https://func-mcp-p01-<suffix>.azurewebsites.net/.well-known/oauth-protected-resource/runtime/webhooks/mcp", scope="api://<guid>/user_impersonation"
> ```
>
> **Ce que cela signifie pour vous :** ce 401 n'est pas une impasse. Le challenge indique au client où lire les
> métadonnées de ressource protégée (**Preview**) et quel scope demander : VS Code peut ainsi lancer seul la connexion Microsoft.

### Retrouver le même résultat dans le portail Azure

Captures réelles du portail, 2026-10-19, tenant de test de l'auteur. Les noms sont pseudonymisés et chaque ID est remplacé
par des zéros. Ouvrez les mêmes pages dans votre tenant pour vérifier ce que Terraform a configuré. Le portail est affiché en
anglais. Les cadres roses montrent quoi vérifier. Sélectionnez une image pour l'ouvrir en grand.

**1. Function App → Settings → Authentication.** L'authentification App Service est activée, les requêtes non
authentifiées reçoivent HTTP 401 et le magasin de jetons (*token store*) est désactivé : la plateforme vérifie le jeton,
le serveur ne le conserve jamais.

![Capture réelle : page Authentication de la Function App, authentification exigée, HTTP 401 pour les requêtes non authentifiées, magasin de jetons désactivé](../../assets/screenshots/azure-03-function-authentication.png)

**2. App registrations → Workshop MCP API → Overview.** Une seule organisation (*My organization only*), et le lien
« Add a certificate or secret » : l'application n'a aucun mot de passe.

![Capture réelle : vue d'ensemble de l'inscription d'application, une seule organisation, aucun secret ni certificat](../../assets/screenshots/azure-03-app-registration-overview.png)

**3. Même application → App roles.** `Tools.Read` et `Tools.Write` sont destinés aux utilisateurs, `Tools.Execute.All`
aux applications. Le module 04 les applique outil par outil.

![Capture réelle : page App roles avec Tools.Read et Tools.Write pour les utilisateurs et Tools.Execute.All pour les applications](../../assets/screenshots/azure-03-app-roles.png)

**4. Enterprise applications → Workshop MCP API → Properties.** « Assignment required? » vaut **Yes** : seuls les
utilisateurs affectés (Alice et Bob) obtiennent un jeton. C'est pourquoi Eve reçoit `AADSTS50105`.

![Capture réelle : propriétés de l'application d'entreprise, affectation obligatoire à Yes](../../assets/screenshots/azure-03-enterprise-app-properties.png)

**Question :** Eve fait partie du tenant. Quel réglage de la capture 4 l'arrête avant même le serveur MCP ?

<details>
<summary>Voir la réponse</summary>

« Assignment required? » = Yes. Microsoft Entra ID refuse d'émettre un jeton pour cette API à un utilisateur sans
affectation : Eve reçoit `AADSTS50105` dès la connexion. Le serveur MCP ne voit jamais sa requête.

</details>

### Lire la documentation au moment de la démonstration

Ouvrez chaque lien au moment du contrôle correspondant ci-dessus. Authentification, consentement et autorisation sont trois décisions distinctes.

| Démonstration ou choix | Ce qu'il faut comprendre dans Microsoft Learn | Référence de configuration ou d'API |
|---|---|---|
| Sans jeton ou avec la seule ancienne clé : HTTP 401 | [Authentification App Service](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization) : la plateforme contrôle l'identité avant l'exécution de l'outil. | [Ressource authsettingsV2](https://learn.microsoft.com/azure/templates/microsoft.web/sites/config-authsettingsv2) : `requireAuthentication`, `unauthenticatedClientAction` et `allowedAudiences`. |
| Le client découvre où se connecter | [Autorisation MCP et métadonnées de ressource protégée (**Preview**)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp). Cela protège l'accès au serveur, pas chaque outil. | La même page décrit `WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES` et la réponse indiquant l'URL des métadonnées. |
| Un jeton Graph est refusé ; un jeton MCP est accepté | [Jetons d'accès](https://learn.microsoft.com/entra/identity-platform/access-tokens) : l'audience désigne l'API cible. | [Audiences autorisées dans authsettingsV2](https://learn.microsoft.com/azure/templates/microsoft.web/sites/config-authsettingsv2), pas une liste de jetons d'API interchangeables. |
| Alice et Bob accèdent au serveur ; Eve reçoit `AADSTS50105` | [Exiger une attribution utilisateur](https://learn.microsoft.com/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users) : se connecter au tenant ne suffit pas. | [Attribuer des rôles d'application](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps), utilisés pour les comptes de test existants. |
| Scope `user_impersonation` comparé aux rôles `Tools.Read` / `Tools.Write` ; Bob peut encore écrire ici | [Scopes et consentement](https://learn.microsoft.com/entra/identity-platform/scopes-oidc) décrivent la permission déléguée accordée au client. Les [rôles d'application](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps) expriment les droits attribués à l'utilisateur. | Le module 04 ajoute le contrôle du rôle par outil. Définir un rôle ne l'applique pas automatiquement. |

Ne collez jamais de jeton de l'atelier dans un décodeur en ligne, même si un article lié l'utilise comme exemple.
Liens vérifiés le 2026-10-16. Cette vérification ne prouve aucun résultat d'authentification en ligne.

## Valider

`validate.ps1` (ou `validate.sh`) exécute toujours d'abord les vérifications hors ligne : `host.json` conserve `System` ;
le webhook anonyme n'existe qu'avec l'authentification intégrée appliquée et HTTP 401 ; `infra/entra` conserve un seul
tenant, `user_impersonation`, les trois rôles et l'attribution obligatoire, sans secret, mot de passe, certificat ni
utilisateur ; aucun motif de jeton ou de clé dans les fichiers du module ; les revendications synthétiques n'utilisent que
des ID synthétiques ; format, schéma et tests Terraform simulés pour les deux modules racines.

Sortie hors ligne (ce résultat **ne prouve pas** un déploiement) :

```text
PASS host.json keeps the level 0 System webhook level; the published package is never anonymous on its own (expected HTTP N/A).
PASS the key gate is removed only together with enforced built-in authentication and Return401 (expected HTTP 401 without a token).
PASS infra/entra: single tenant, user_impersonation, Tools.Read/Tools.Write/Tools.Execute.All, assignment required, no secret or user (expected HTTP N/A).
PASS no access token, key, SAS or client secret in module 03, infra/entra or workload files (expected HTTP N/A).
PASS synthetic claim examples use synthetic IDs only and contain no token (4 files, expected HTTP N/A).
PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).
PASS offline checks only. Module 03 is NOT deployed or Entra-validated by this result.
```

Modes en ligne, après un déploiement approuvé :

- **Opérateur** (`-TenantId -SubscriptionId`) : HTTP 401 sans jeton, métadonnées PRM, HTTP 401 pour un jeton Graph,
  authsettingsV2 et paramètres d'application lus dans Azure Resource Manager, HTTP 401 avec la seule clé.
- **Persona** (`-TenantId -Persona Alice|Bob|Eve`, connecté avec ce compte) : Alice et Bob obtiennent HTTP 200 pour
  `initialize` et `tools/list` ; Eve ne doit obtenir aucun jeton (erreur `AADSTS50105`). Si `.workshop/module03-personas.json`
  existe, le validateur vérifie aussi l'ID d'objet du compte connecté.

Les jetons et les clés restent en mémoire et ne sont jamais affichés. Le module n'est terminé que lorsque la vérification
opérateur et les trois vérifications par persona réussissent sur un abonnement neuf, juste après les modules 00 à 02.

## Dépannage

| Symptôme | À vérifier |
|---|---|
| VS Code ouvre `https://<app>/authorize` au lieu de la connexion Microsoft | Les PRM manquent : vérifiez `WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES` et attendez le redémarrage. |
| HTTP 401 pour Alice après l'étape 1 | Normal : l'étape 1 exige encore la clé. Appliquez l'étape 2. |
| HTTP 403 avec un jeton valide | L'application cliente n'est pas autorisée. Utilisez VS Code ou Azure CLI. |
| `AADSTS65001` (consentement requis) | Le client n'est pas pré-autorisé pour `user_impersonation`. Vérifiez les deux pré-autorisations. |
| `AADSTS50105` pour Alice ou Bob | L'attribution de rôle manque ou n'est pas encore propagée. Attendez quelques minutes, puis reconnectez-vous. |
| `AADSTS500011` (ressource introuvable) | Mauvaise URI d'ID d'application ou mauvais tenant. Utilisez la sortie `mcp_auth_audience`. |
| Le plan propose de retirer l'authentification | Vous avez oublié `-var-file=..\..\.workshop\module03.tfvars.json`. |
| `entra_auth_replace_key_gate requires enable_entra_auth` | N'activez jamais l'étape 2 sans l'étape 1. |

## Nettoyer

Nettoyez dans l'ordre inverse. Chaque script commence par un plan et refuse toute modification hors du module 03.
Lancez-le une première fois pour relire le plan, puis relancez-le avec `-Apply`. Les deux scripts sont idempotents.

```powershell
# Participant : remettre la clé derrière Entra (phase 1), puis retirer l'authentification intégrée (phase 2).
& .\modules\03-entra-authentication\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
& .\modules\03-entra-authentication\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
Remove-Item -LiteralPath .\.workshop\module03.tfvars.json, .\.workshop\module03-personas.json -ErrorAction SilentlyContinue
Remove-Item -LiteralPath .\.workshop\az-alice, .\.workshop\az-bob, .\.workshop\az-eve -Recurse -ErrorAction SilentlyContinue
# Administrateur des identités : supprimer seulement les objets Entra créés par l'atelier (jamais les applications ni utilisateurs fournis).
& .\modules\03-entra-authentication\cleanup.ps1 -TenantId <tenant-id> -Scope Entra
& .\modules\03-entra-authentication\cleanup.ps1 -TenantId <tenant-id> -Scope Entra -Apply
```

> **Résultat attendu** — d'après les messages du script de nettoyage ; pas encore une capture. Les lignes d'application de Terraform sont omises.
>
> ```text
> PASS explicit Azure context and private participant parameters (expected HTTP 200 from Azure Resource Manager).
> PLAN update azurerm_function_app_flex_consumption.mcp[0] (phase 1: restore the key gate behind Entra)
> PASS 'phase 1: restore the key gate behind Entra' plan changes only 1 module 03 object(s). Review it, then rerun with -Apply.
> ```
>
> L'exécution avec `-Apply` affiche ensuite `PASS 'phase 1: restore the key gate behind Entra' applied (expected HTTP 200).`,
> planifie la phase 2 (`PLAN update ... (phase 2: remove built-in authentication)`), l'applique et se termine par
> `PASS the server is back to the level 0 key gate. Remove .workshop/module03.tfvars.json, then run modules/02-open-server/cleanup.ps1 to delete it.`
> Les lignes `Remove-Item` n'affichent rien. Le rapport de l'administrateur des identités liste les huit objets :
>
> ```text
> PASS explicit tenant and interactive identity administrator sign-in (expected HTTP 200 from Microsoft Graph).
> PLAN delete azuread_app_role_assignment.personas["alice-read"] (destroy workshop-created Entra objects)
> PLAN delete azuread_app_role_assignment.personas["alice-write"] (destroy workshop-created Entra objects)
> PLAN delete azuread_app_role_assignment.personas["bob-read"] (destroy workshop-created Entra objects)
> PLAN delete azuread_application.mcp[0] (destroy workshop-created Entra objects)
> ...
> PASS 'destroy workshop-created Entra objects' plan changes only 8 module 03 object(s). Review it, then rerun with -Apply.
> ```
>
> Avec `-Apply`, il se termine par `PASS provided applications and existing test users were not touched. Deleted registrations stay restorable for 30 days in Microsoft Entra.`
>
> **Ce que cela signifie pour vous :** la clé revient **avant** le retrait d'Entra : le serveur n'est jamais anonyme.
> Une ligne `FAIL ... change(s) outside module 03` signifie que rien n'a été appliqué. Une seconde exécution affiche
> `PASS '<phase>': nothing to do in this state (idempotent, expected HTTP N/A).`

```bash
bash ./modules/03-entra-authentication/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -Apply
bash ./modules/03-entra-authentication/cleanup.sh -TenantId "<tenant-id>" -Scope Entra -Apply
```

> **Résultat attendu** — les mêmes lignes PASS et PLAN que les exécutions PowerShell avec `-Apply` ci-dessus.

Supprimez ensuite le serveur avec le script de nettoyage du module 02, retirez le serveur `workshop-entra` de VS Code et demandez à
l'administrateur des identités de supprimer les comptes de test s'ils n'ont été créés que pour cet atelier. Si vous
passez directement au module 04, conservez tout.

## Aller plus loin

- Ouvrez [alice.json](synthetic-claims/alice.json) et [bob.json](synthetic-claims/bob.json) : quelle revendication
  diffère, et quelle couche l'utilise ?
- En tant que Bob, appelez `create_ticket` dans VS Code. Cela fonctionne : pourquoi est-ce un problème, et quel module le corrige ?
- Lisez les concepts [scopes et rôles d'application](../../docs/fr/concepts/scopes-and-app-roles.md) et
  [chaîne de jetons](../../docs/fr/concepts/token-chain.md).
- Suite : [plan du module 04](../../docs/fr/BUILD-PLAN.md).

## Sources

- [Configurer l'autorisation d'un serveur MCP (App Service et Functions)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp)
- [Sécuriser des serveurs MCP avec Microsoft Entra et VS Code](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode)
- [Tutoriel : héberger un serveur MCP sur Azure Functions (authentification intégrée, paramètre du webhook, ID client VS Code)](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial)
- [Métadonnées de ressource protégée (Preview) dans l'authentification App Service](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization#protected-resource-metadata-preview)
- [Ajouter des rôles d'application et les recevoir dans un jeton](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps)
- [Exiger l'attribution des utilisateurs pour une application d'entreprise](https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-or-group-access-portal)
- [Référence des revendications des jetons d'accès](https://learn.microsoft.com/entra/identity-platform/access-token-claims-reference)
- [Azure-Samples/remote-mcp-functions-dotnet au commit 468c518 (infra/app/entra.bicep, infra/app/api.bicep)](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9)
- [Fournisseur AzureAD 3.10.0](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0/docs) et [AzureRM 5.9.0 Flex Consumption `auth_settings_v2`](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown)
- [RFC 9728 OAuth 2.0 Protected Resource Metadata](https://www.rfc-editor.org/rfc/rfc9728)

Dernière vérification : 2026-10-18. Vérifications opérateur validées en ligne dans le tenant de test de l'auteur le 2026-10-17 ; vérifications par persona pas encore exécutées (enregistrement MFA requis).

# 07 - Facultatif : autres clients (Microsoft Foundry en direct, plan Copilot Studio)

[English](README.md)

## Objectif

Appeler le même serveur MCP gouverné depuis un autre client : un **agent Microsoft Foundry** (partie A, exécutée en
conditions réelles) et, sous forme de plan, **Microsoft Copilot Studio** (partie B). La passerelle, les rôles
d'application et les journaux des modules 03 à 06 ne changent pas.

## Pourquoi c'est important

La gouvernance doit s'appliquer quel que soit le client qui appelle le serveur. Chaque client a sa propre manière de se connecter et d'envoyer le jeton. Les questions à poser sont toujours les mêmes :

- Quelle identité appelle le serveur MCP (l'utilisateur, une identité managée ou une identité d'agent) ?
- Quelle est l'audience du jeton, et s'agit-il bien de l'audience propre au serveur MCP ?
- Le jeton est-il transmis tel quel à un service en aval (token passthrough) ?

## Ce que vous déployez

Partie A seulement (facultative, facturée). Les parties B et C ne créent rien.

| Quoi | Où | Pourquoi |
|---|---|---|
| Un projet Foundry avec un déploiement `gpt-4.1-mini` | Son propre groupe de ressources, depuis le modèle `azd-ai-starter-basic` | Héberge l'agent |
| Une **inscription d'application cliente** `workshop-mcp-foundry-client-<prefix>` | Microsoft Entra | Le client OAuth avec lequel Foundry connecte les utilisateurs |
| Un **secret client valable un jour** sur cette application | Microsoft Entra, transmis uniquement à Foundry | Foundry n'accepte qu'un client confidentiel (vérifié le 2026-10-20) |
| La préautorisation de ce client pour `user_impersonation` | `infra/entra`, fichier privé `.workshop/entra-module07.tfvars.json` | Pas de demande de consentement pour le scope MCP |
| L'ID du client dans les applications autorisées | `infra/workload`, fichier privé `.workshop/module07.tfvars.json` | La stratégie de la passerelle et l'authentification de la Function acceptent ce client |
| Le rôle **Foundry User** sur le projet pour chaque utilisateur de test | Le projet Foundry | Chaque utilisateur appelle l'agent avec sa propre identité |
| Un **blueprint d'identité d'agent**, créé par Foundry pour l'agent | Microsoft Entra | Créé automatiquement ; non supprimé avec le groupe de ressources |

> [!NOTE]
> Fonctionnalités en préversion (signalez-les quand vous les montrez) :
>
> - **Préversion :** relais d'identité OAuth (OAuth identity passthrough) pour les outils MCP de Microsoft Foundry.
> - **Préversion :** le nouveau portail Foundry et sa configuration des outils MCP.

## Prérequis et rôles nécessaires

- Modules 03 à 06 déployés : l'URL de la passerelle du module 04 (jamais l'URL de la Function).
- Contributeur sur un abonnement pour le groupe de ressources Foundry ; Administrateur d'applications (ou propriétaire
  de l'application cliente) pour l'inscription et son secret ; l'administrateur des identités du module 03 pour `infra/entra`.
- Azure Developer CLI (`azd`) 1.34 ou plus récent, et les comptes de test Alice et Bob (Eve est déjà refusée au module 03).

## Étapes

### Garder la même frontière d'autorisation

![Les clients facultatifs utilisent les mêmes contrôles API Management et la même Function privée.](../../assets/architecture/07.fr.svg)

Le client change, pas les droits exigés par le serveur.

| Appel | Jeton et contrôle à prévoir |
|---|---|
| Client vers passerelle MCP | Jeton destiné à l'audience MCP. Les contrôles de la plateforme valident l'émetteur, le tenant, l'audience, l'expiration, le scope et le rôle |
| Passerelle vers Function | Même ressource logique MCP dans l'atelier ; pas d'échange vers une audience en aval. L'authentification et l'accès privé de la Function restent en place |
| Serveur MCP vers Graph ou Storage au nom de l'utilisateur | Nouveau jeton pour cette API par On-Behalf-Of (OBO) ; droits utilisateur et consentement délégué |
| Serveur MCP vers Storage en tant qu'application | Nouveau jeton Storage par identité managée ; droits applicatifs limités au conteneur |
| Serveur local en stdio | Pas de jeton OAuth HTTP sur ce transport ; l'accès au processus et les droits du système d'exploitation restent nécessaires |
| Calcul synthétique dans un outil | Aucun jeton en aval s'il n'y a aucun appel en aval ; l'accès MCP distant reste authentifié |

![Les outils utilisateur et applicatifs emploient des jetons en aval distincts, jamais le jeton MCP.](../../assets/architecture/05.fr.svg)

> [!IMPORTANT]
> **Point de compatibilité :** la passerelle exige un scope délégué et les outils OBO exigent un utilisateur.
> Une identité managée ou une identité d'agent Foundry est applicative : lui attribuer un rôle ne suffit **pas**.
> Le chemin qui fonctionne est le **relais d'identité OAuth** (partie A) : chaque utilisateur se connecte, et son jeton porte ses rôles.

**Question :** Foundry appelle le serveur avec son identité managée. `whoami` peut-il agir au nom d'Alice ?

<details>
<summary>Afficher la réponse</summary>

Non. Un jeton d'application ne porte aucun contexte délégué d'Alice. La passerelle actuelle refuse ce flux ;
les outils OBO doivent aussi refuser les appelants applicatifs. L'identité du client et l'identité managée utilisée par un outil en aval sont deux choix distincts.

</details>

### Partie A — Agent Microsoft Foundry avec relais d'identité OAuth (préversion)

L'auteur a exécuté toutes les étapes ci-dessous le 2026-10-20 dans un tenant de test. Lancez-les dans PowerShell depuis
la racine du dépôt, avec `$env:ARM_TENANT_ID` et `$env:ARM_SUBSCRIPTION_ID` définis comme au module 00.

**A1. Créer le projet Foundry** (environ 4 minutes). Le modèle crée son propre groupe de ressources `rg-<nom>`.

```powershell
$name = 'mcp07-<prefix>'                                  # lettres, chiffres et tirets
$dir = Join-Path $env:TEMP "foundry-07\$name"; New-Item -ItemType Directory -Force $dir | Out-Null; Push-Location $dir
$env:AZURE_DEV_USER_AGENT = 'microsoft_foundry_skill'
azd init -t https://github.com/Azure-Samples/azd-ai-starter-basic -e $name --no-prompt
azd env set AZURE_LOCATION swedencentral
azd env set AZURE_SUBSCRIPTION_ID $env:ARM_SUBSCRIPTION_ID
azd env set ENABLE_HOSTED_AGENTS false; azd env set ENABLE_CAPABILITY_HOST false
azd env set AI_PROJECT_DEPLOYMENTS '[{\"name\":\"gpt-4.1-mini\",\"model\":{\"name\":\"gpt-4.1-mini\",\"format\":\"OpenAI\",\"version\":\"2025-04-14\"},\"sku\":{\"name\":\"GlobalStandard\",\"capacity\":20}}]'
azd provision --no-prompt
$endpoint = azd env get-value AZURE_AI_PROJECT_ENDPOINT; Pop-Location
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
az group update -n "rg-$name" --tags workshop=governed-mcp owner=$($p.owner) expiry=$($p.expiry) module=07 -o none
```

> **Résultat réel** — 2026-10-20, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
>   (✓) Done: Foundry: ai-account-<id> (1m50.42s)
>   (✓) Done: Azure AI Services Model Deployment: ai-account-<id>/gpt-4.1-mini (4.36s)
>   (✓) Done: Foundry project: ai-account-<id>/ai-project-mcp07-p01 (8.454s)
> SUCCESS: Your application was provisioned in Azure in 3 minutes 21 seconds.
> ```
>
> La valeur JSON exige `\"` autour de chaque nom : `azd` l'insère dans une chaîne JSON. Sans cela, `azd provision`
> s'arrête avec `invalid character 'n' after object key:value pair`.

**A2. Créer l'inscription d'application cliente** (sans secret pour l'instant) et noter ses ID dans un fichier privé.

```powershell
$mcpApp = terraform -chdir=infra/entra output -raw application_client_id
$scopeId = az ad app show --id $mcpApp --query "api.oauth2PermissionScopes[?value=='user_impersonation'].id | [0]" -o tsv
$f = New-TemporaryFile
ConvertTo-Json -Depth 5 -AsArray @(@{ resourceAppId = $mcpApp; resourceAccess = @(@{ id = $scopeId; type = 'Scope' }) }) | Set-Content $f
$app = az ad app create --display-name "workshop-mcp-foundry-client-$($p.participant_prefix)" --sign-in-audience AzureADMyOrg `
    --required-resource-accesses "@$f" --query "{appId:appId,id:id}" -o json | ConvertFrom-Json
Remove-Item $f; az ad sp create --id $app.appId -o none
@{ foundry_client_app_id = $app.appId; foundry_client_object_id = $app.id; foundry_resource_group = "rg-$name" } |
    ConvertTo-Json | Set-Content .\.workshop\module07.private.json
```

> **Résultat attendu** — aucune sortie. `Get-Content .\.workshop\module07.private.json` affiche les deux ID et le nom du
> groupe de ressources. La nouvelle inscription n'a encore ni secret ni certificat.

**A3. Autoriser ce client dans Terraform** (l'administrateur des identités pour `infra/entra`, puis vous pour
`infra/workload`). Les listes gardent Visual Studio Code et Azure CLI. Relisez chaque plan : une préautorisation ajoutée,
puis des mises à jour en place des stratégies de la passerelle et de l'authentification de la Function, rien de supprimé.

```powershell
$ids = @(@(terraform -chdir=infra/entra output -json pre_authorized_client_ids | ConvertFrom-Json) + $app.appId | Select-Object -Unique)   # VS Code, Azure CLI, client Foundry
@{ pre_authorized_client_ids = $ids } | ConvertTo-Json | Set-Content .\.workshop\entra-module07.tfvars.json
@{ mcp_allowed_client_ids = $ids } | ConvertTo-Json | Set-Content .\.workshop\module07.tfvars.json
terraform '-chdir=infra\entra' plan '-var-file=..\..\.workshop\entra.tfvars.json' '-var-file=..\..\.workshop\entra-module05.tfvars.json' `
    '-var-file=..\..\.workshop\entra-module07.tfvars.json' '-out=..\..\.workshop\entra07.tfplan'
terraform '-chdir=infra\entra' apply '..\..\.workshop\entra07.tfplan'
$vars07 = $vars + '-var-file=..\..\.workshop\module05.tfvars.json', '-var-file=..\..\.workshop\module07.tfvars.json'   # $vars du module 04
terraform '-chdir=infra\workload' plan @vars07 '-out=..\..\.workshop\module07.tfplan'
terraform '-chdir=infra\workload' apply '..\..\.workshop\module07.tfplan'
```

> **Résultat réel** — 2026-10-20, tenant de test de l'auteur (extrait).
>
> ```text
> # azuread_application_pre_authorized.clients["<foundry-client-id>"] will be created
> Plan: 1 to add, 0 to change, 0 to destroy.
> ...
> Plan: 0 to add, 6 to change, 0 to destroy.
> Apply complete! Resources: 0 added, 6 changed, 0 destroyed.
> ```

**A4. Ajouter l'outil MCP dans le portail Foundry.** Ouvrez [Foundry](https://ai.azure.com/nextgen), choisissez votre
projet, puis **Build** → **Tools** → **Connect a tool** → **Custom** → **Model Context Protocol (MCP)** → **Create**
(portail en anglais). Remplissez :

| Champ | Valeur |
|---|---|
| Name | `workshop-governed` |
| Remote MCP Server endpoint | `terraform -chdir=infra/workload output -raw gateway_mcp_endpoint` |
| Authentication | **OAuth Identity Passthrough** |
| Client ID | le `foundry_client_app_id` de l'étape A2 |
| Client secret | laissez vide pour l'instant (l'étape A5 l'ajoute) |
| Token URL et Refresh URL | `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token` |
| Auth URL | `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize` |
| Scopes | `terraform -chdir=infra/entra output -raw user_impersonation_scope`, une espace, puis `offline_access` |

Sélectionnez **Connect**, puis copiez la **Redirect URL** affichée par Foundry. Sélectionnez ensuite **Use in an agent**,
nommez l'agent `workshop-mcp-agent` et gardez uniquement cet outil MCP (retirez **Web search** s'il apparaît, puis **Save**).

![Capture réelle : l'outil workshop-governed dans Foundry ; le cadre 1 marque le point de terminaison de la passerelle, le cadre 2 OAuth Identity Passthrough, le cadre 3 l'URL de redirection à inscrire](../../assets/screenshots/azure-07-foundry-tool.png)

*Capture réelle, 2026-10-20, tenant de test de l'auteur. Noms pseudonymisés, ID remplacés.*

**A5. Inscrire l'URL de redirection et donner à Foundry un secret d'un jour.** Collez ce bloc en une seule fois : le secret
n'existe qu'en mémoire, part directement dans la connexion Foundry et n'est jamais affiché.

```powershell
$redirect = '<redirect-url-de-A4>'
$s = Get-Content .\.workshop\module07.private.json -Raw | ConvertFrom-Json
$f = New-TemporaryFile
@{ web = @{ redirectUris = @($redirect) } } | ConvertTo-Json -Depth 4 | Set-Content $f
az rest --method patch --url "https://graph.microsoft.com/v1.0/applications/$($s.foundry_client_object_id)" --body "@$f" --headers 'Content-Type=application/json'
$end = (Get-Date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
$secret = az ad app credential reset --id $s.foundry_client_app_id --append --display-name 'foundry-module07-short-lived' --end-date $end --query password -o tsv --only-show-errors
$proj = az resource list -g $s.foundry_resource_group --resource-type Microsoft.CognitiveServices/accounts/projects --query "[0].id" -o tsv
$url = "https://management.azure.com$proj/connections/workshop-governed?api-version=2025-06-01"
$c = (az rest --url $url -o json | ConvertFrom-Json).properties
$body = @{ properties = @{ authType = 'OAuth2'; category = $c.category; group = $c.group; target = $c.target; authorizationUrl = $c.authorizationUrl
    tokenUrl = $c.tokenUrl; refreshUrl = $c.refreshUrl; scopes = $c.scopes; connectorName = $c.connectorName; redirectUrl = $c.redirectUrl
    isSharedToAll = $false; metadata = $c.metadata; credentials = @{ clientId = $s.foundry_client_app_id; clientSecret = $secret } } }
[IO.File]::WriteAllText($f, ($body | ConvertTo-Json -Depth 6 -Compress))
try { az rest --method put --url $url --body "@$f" --headers 'Content-Type=application/json' -o none } finally { Remove-Item $f -Force; $secret = $null; $body = $null }
```

> **Résultat réel** — 2026-10-20 : aucune sortie. Relire la connexion affiche `"credentials": null` : Foundry ne renvoie
> jamais le secret. Dans Microsoft Entra, l'application cliente montre un secret nommé `foundry-module07-short-lived`, valable un jour.

> **Pourquoi un secret ?** L'auteur a d'abord essayé sans (un client public, comme Visual Studio Code). La connexion
> d'Alice a réussi dans Microsoft Entra, mais le gestionnaire d'identifiants de Foundry n'a pas pu échanger le code. Le
> portail marque aussi **Client secret** comme obligatoire. La règle est donc : une application cliente dédiée, un secret
> valable un jour, jamais affiché ni stocké, supprimé par le nettoyage. Le secret identifie l'**application cliente** ;
> chaque utilisateur se connecte toujours avec sa propre identité.

**A6. Donner le rôle Foundry User sur le projet à chaque utilisateur de test**, pour qu'il appelle l'agent en son nom :

```powershell
$users = Get-Content .\.workshop\test-users.private.json -Raw | ConvertFrom-Json
foreach ($u in 'alice', 'bob') {
    az role assignment create --assignee-object-id $users.$u.objectId --assignee-principal-type User --role 'Foundry User' --scope $proj -o none
}
```

> **Résultat attendu** — aucune sortie. Attendez 2 à 3 minutes : tant que le rôle n'est pas appliqué, Foundry répond HTTP 403.

La documentation recommande **Foundry Agent Consumer** pour les agents publiés. Pour des appels directs au projet, comme
ici, ce rôle a renvoyé HTTP 403 lors du test de l'auteur ; **Foundry User** a fonctionné.

**A7. Appeler l'agent en tant qu'Alice, se connecter une fois, approuver la lecture.** Utilisez le profil Azure CLI
d'Alice (module 03) :

```powershell
$env:AZURE_CONFIG_DIR = Join-Path $PWD '.workshop\az-alice'
$prompt = 'Use the workshop MCP tool to call get_service_health with service "workshop-api". Summarise the result. Do not call any write tool.'
pwsh ./modules/07-clients/invoke-foundry-agent.ps1 -ProjectEndpoint $endpoint -Prompt $prompt
# CONSENT : ouvrez le lien affiché dans un navigateur connecté en tant qu'Alice, choisissez « Allow access », connectez-vous, puis relancez la même commande.
# APPROVAL : lisez le nom de l'outil et ses arguments, puis :
pwsh ./modules/07-clients/invoke-foundry-agent.ps1 -ProjectEndpoint $endpoint -PreviousResponseId <resp_id> -Approve
```

> **Résultat réel** — Alice, 2026-10-20, après son consentement (ID de réponse raccourcis).
>
> ```text
> TOOLS create_ticket, get_service_health, read_report_as_app, read_report_as_user, whoami
> APPROVAL get_service_health {"service":"workshop-api"}. Approve with: -PreviousResponseId resp_00442ff3... -Approve (or -Deny)
> CALL get_service_health -> {"service":"workshop-api","status":"healthy","source":"synthetic","level":"0-open"}
> ```

Recommencez ensuite en tant que Bob avec une écriture (`$env:AZURE_CONFIG_DIR` sur `.workshop\az-bob`) :

```prompt
Use the workshop MCP tool. Call create_ticket with service "ticket-queue", severity "medium" and summary "Synthetic ticket - Contoso workshop". Show the tool result, or the exact error if the call is refused.
```

![Sortie réelle du terminal : le cadre 1 marque l'approbation demandée par Foundry avant get_service_health, le cadre 2 le résultat d'Alice via la passerelle, le cadre 3 le create_ticket approuvé de Bob, refusé par la passerelle avec HTTP 403](../../assets/screenshots/terminal-07-foundry.png)

Le même parcours dans le playground du portail : Foundry affiche l'outil et ses arguments, puis attend **Approve** ou **Deny**.

![Capture réelle : playground Foundry ; le cadre 1 marque l'appel d'outil en attente d'approbation, le cadre 2 l'option Approve once, le cadre 3 le seul outil, la passerelle gouvernée](../../assets/screenshots/azure-07-foundry-approve.png)

![Capture réelle : playground Foundry après approbation ; le cadre 1 marque Request has been approved, le cadre 2 la réponse de l'agent issue de l'outil synthétique, le cadre 3 l'outil qui a répondu](../../assets/screenshots/azure-07-foundry-result.png)

*Captures réelles, 2026-10-20, tenant de test de l'auteur. Noms pseudonymisés, ID remplacés.*

> [!WARNING]
> Un lien de consentement appartient à l'utilisateur Foundry qui l'a reçu. Si quelqu'un d'autre l'ouvre et se connecte,
> l'agent du premier utilisateur agit ensuite avec le jeton du second. Ne partagez jamais un lien de consentement : chacun ouvre le sien.

**Question :** Bob choisit **Approve** dans Foundry pour `create_ticket`. Qui refuse l'appel, et pourquoi l'approbation ne suffit-elle pas ?

<details>
<summary>Afficher la réponse</summary>

La passerelle le refuse avec HTTP 403. L'approbation est l'accord de Bob pour lancer l'outil ; elle n'ajoute rien à son
jeton. La passerelle cherche `Tools.Write` dans la revendication `roles`, que Bob n'a pas : la Function ne voit jamais l'appel.

</details>

### Partie B — Microsoft Copilot Studio (plan)

1. Dans l'agent, ouvrez **Outils**, puis **Ajouter un outil**, puis **Nouvel outil**, puis **Model Context Protocol**.
2. Saisissez un **Nom du serveur**, une **Description du serveur** et l'**URL du serveur** (URL de la passerelle).
3. Choisissez **OAuth 2.0**, jamais **Aucune**. Le parcours **Manual** documenté demande un **Client secret**. La règle de
   l'atelier ne l'autorise que comme dans la partie A : une inscription d'application cliente dédiée, un secret valable un
   jour, transmis sans être affiché ni stocké, et supprimé au nettoyage. L'atelier n'implémente pas l'inscription dynamique
   de clients. Ne passez jamais à **Clé API** pour contourner cette étape.
4. Seul le transport **Streamable** est pris en charge. SSE n'est plus pris en charge.
5. Testez d'abord un outil de lecture, avec la bonne audience MCP, le scope délégué et les rôles. L'auteur n'a **pas**
   exécuté ce plan en conditions réelles : seule la partie A (Foundry) l'a été.

> [!CAUTION]
> Ne passez jamais à **Aucune** ni à **Clé API** pour faire fonctionner une connexion Copilot Studio : cela supprime
> le contrôle d'identité mis en place dans l'atelier. Un secret client n'est acceptable que de courte durée, sur une
> application cliente dédiée, et supprimé ensuite.

> Les libellés exacts des écrans peuvent changer. Vérifiez la page citée dans les sources avant la session.

**Question :** le parcours OAuth Manual de Copilot Studio demande un secret client. Pourquoi ne pas passer plutôt à **Clé API** ?

<details>
<summary>Afficher la réponse</summary>

Une clé API n'identifie aucun utilisateur. La passerelle ne pourrait plus vérifier un jeton pour l'audience MCP, un scope délégué
ni les rôles d'application d'Alice et de Bob : l'autorisation par utilisateur disparaîtrait. Un secret client de courte durée,
sur une application cliente dédiée, garde la connexion de chaque utilisateur : le secret identifie l'application cliente, pas l'utilisateur.

</details>

### Partie C — Checklist pour chaque client

- [ ] L'audience du jeton est l'audience propre au serveur MCP (ni Microsoft Graph, ni une API en aval).
- [ ] Le client connecte chaque utilisateur (OAuth) ; jamais **Aucune** ni une clé API.
- [ ] Tout secret client est de courte durée, sur une application cliente dédiée, jamais affiché ni stocké, et supprimé au nettoyage.
- [ ] Les outils d'écriture exigent un rôle explicite et une approbation humaine.
- [ ] Les journaux de la passerelle montrent l'appel avec un ID de corrélation et sans corps de requête (module 06).

## Ce que vous devez voir

- Alice : Foundry liste les cinq outils, demande l'approbation, puis renvoie le résultat synthétique `healthy`.
- Bob : l'approbation est demandée pour `create_ticket`, puis la passerelle répond **HTTP 403** ; l'outil ne s'exécute pas.
- Requête du module 06 : les appels de Foundry apparaissent avec le nom de l'outil, le statut et la durée, sans corps.

## Valider

**Hors ligne** (toujours) : le dossier est complet, la partie A est documentée avec son nettoyage, et aucune valeur de secret n'est écrite.

```powershell
pwsh ./modules/07-clients/validate.ps1 -Offline
```

> **Résultat réel** — validateur hors ligne, poste de l'auteur, 2026-10-20 (extrait).
>
> ```text
> PASS README sections present in contract order (offline)
> PASS lists what part A deploys and how to delete it (offline)
> PASS marks Preview features (offline)
> PASS never recommends the anonymous None option for Copilot Studio (offline)
> PASS client secrets are short-lived, never printed and deleted (offline)
> PASS no GUIDs or client secret values in module files (offline)
>
> RESULT: all offline checks passed
> ```

**En conditions réelles** (partie A déployée) : lancez l'étape A7 pour Alice et pour Bob. Attendu :
`CALL get_service_health -> {... "status":"healthy" ...}` pour Alice, et `REFUSED ... the MCP server answered HTTP 403`
pour Bob après son approbation.

```bash
bash ./modules/07-clients/validate.sh --offline
```

> **Résultat attendu** — les mêmes lignes PASS/FAIL que l'exécution PowerShell ci-dessus.

**Question :** tous les contrôles hors ligne passent. Cela prouve-t-il que Foundry peut appeler votre serveur ?

<details>
<summary>Afficher la réponse</summary>

Non. Les contrôles hors ligne prouvent que le dossier est complet et que les règles sont écrites. Seule l'étape A7 prouve
le parcours réel : la lecture d'Alice réussit après approbation, et l'écriture approuvée de Bob reçoit HTTP 403 de la passerelle.

</details>

## Dépannage

| Symptôme | Vérification |
|---|---|
| `Access denied ... while enumerating tools (HTTP 403 Forbidden)` | La liste de la passerelle doit accepter `server/discover` (MCP 2026-07-28), que Foundry appelle en premier. Votre copie de `policies/mcp-server.xml` l'accepte avec `Tools.Read`. Sinon : l'ID du client manque dans `mcp_allowed_client_ids` (étape A3). |
| La fenêtre de consentement se termine par « Nous n'avons pas pu effectuer l'authentification », sans connexion visible pour l'application cliente | L'application cliente n'a pas de secret, ou l'URL de redirection n'est pas sur la plateforme **Web** (étape A5). |
| Le même message, mais Entra montre une connexion réussie | Fermez la fenêtre et rappelez l'agent : le jeton est souvent enregistré malgré tout. |
| Votre compte Foundry reçoit AADSTS50105 dans la fenêtre de consentement | Normal : seuls les utilisateurs qui ont un rôle d'application (module 03) peuvent se connecter à l'API MCP. Utilisez Alice ou Bob. |
| HTTP 403 de Foundry avant tout appel d'outil | L'utilisateur n'a pas **Foundry User** sur le projet, ou le rôle se propage encore (attendez 2 à 3 minutes). |
| `invalid character 'n' after object key:value pair` lors de `azd provision` | Échappez les guillemets dans `AI_PROJECT_DEPLOYMENTS` (étape A1). |
| Le client n'atteint pas le serveur | Utilisez l'URL de la passerelle (module 04). L'URL de la Function est fermée volontairement. |
| Le transport SSE échoue | Utilisez Streamable. SSE n'est plus pris en charge. |

## Nettoyer

D'abord le rapport, puis l'application. Le script restaure les applications autorisées par des plans Terraform contrôlés,
puis supprime le groupe de ressources Foundry (seulement s'il porte l'étiquette `module=07`) et l'inscription
d'application cliente avec son secret.

```powershell
pwsh ./modules/07-clients/cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
pwsh ./modules/07-clients/cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
```

> **Résultat réel** — `-Apply`, lancé par le module 99 le 2026-10-20, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> PLAN update azapi_resource.mcp_api_policy[0] (remove the Foundry client from the allowed applications)
> ...
> PASS 'remove the Foundry client from the allowed applications' applied (expected HTTP 200).
> PLAN delete azuread_application_pre_authorized.clients["<foundry-client-id>"] (remove the Foundry client pre-authorization)
> PASS 'remove the Foundry client pre-authorization' applied (expected HTTP 200).
> PASS Foundry resource group deleted and accounts purged (expected HTTP 200 from Azure Resource Manager).
> PASS Foundry client app registration and secret deleted (expected HTTP 204 from Microsoft Graph).
> DONE module 07 part A removed. Private module 07 files deleted.
> ```
>
> **Ce que cela signifie pour vous :** la passerelle et la Function n'acceptent de nouveau que Visual Studio Code et
> Azure CLI, et plus aucun secret n'existe. L'exécution de l'auteur a ensuite trouvé le **blueprint d'identité d'agent**
> de Foundry encore présent dans Microsoft Entra : supprimer le groupe de ressources ne le supprime pas. Le script le
> supprime désormais aussi, avant le groupe de ressources.

```bash
bash ./modules/07-clients/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
```

> **Résultat attendu** — les mêmes lignes que le rapport PowerShell ; ajoutez `--apply` pour supprimer.

## Pour aller plus loin

- Publiez l'agent et comparez **Foundry Agent Consumer** et **Foundry User** pour ses utilisateurs.
- Suivez la disponibilité générale du relais d'identité OAuth, et la possibilité d'un client public.

## Sources

- Microsoft Foundry — Configurer l'authentification des outils MCP : https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication
- Azure Functions — Connecter un serveur MCP sur Azure Functions à un agent Foundry Agent Service : https://learn.microsoft.com/azure/azure-functions/functions-mcp-foundry-tools
- Spécification MCP 2026-07-28 — `server/discover` : https://modelcontextprotocol.io/specification/2026-07-28/server/discover
- Azure-Samples/azd-ai-starter-basic (MIT), vérifié au commit `5bf59a056c41ff37801dea334ba6a141e2dc5f67` : https://github.com/Azure-Samples/azd-ai-starter-basic
- Microsoft Copilot Studio — Ajouter un serveur MCP existant à un agent : https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent

Dernière vérification : 2026-10-20.

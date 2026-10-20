# 07 — Clients facultatifs : parcours low-code, portail d'abord

[English](LOW-CODE.md)

## Objectif

Vous allez appeler votre serveur Model Context Protocol (MCP), protégé par Microsoft Entra ID et accessible uniquement
via API Management, depuis un agent Microsoft Foundry (partie A, facultative).
Vous vérifierez qu'Alice peut lire les données fictives et que Bob ne peut pas écrire, même après
avoir approuvé l'appel. La partie B vous présente Copilot Studio par la **lecture uniquement**, sans action à réaliser.
Terminez le [module 06 low-code](../06-observe-inventory/LOW-CODE.fr.md) avant de commencer.

Utilisez vos propres ressources, dont les noms comportent `lc`.

## Pourquoi c'est important

Changer de client ne change pas les droits. Chaque utilisateur s'authentifie avec OAuth. La passerelle vérifie
l'audience MCP, le scope délégué et le rôle d'application. L'identité managée du projet est applicative :
elle ne peut pas représenter Alice pour les outils On-Behalf-Of (OBO, « pour le compte de »).
Ne transmettez jamais le jeton MCP aux autres API appelées par le serveur.

L'approbation humaine ne donne aucun rôle : Bob peut approuver une écriture, mais reste refusé sans `Tools.Write`.
Journaux : métadonnées seulement, jamais de jetons, prompts, arguments ou résultats.

> [!IMPORTANT]
> L'approbation humaine ne remplace jamais le contrôle du rôle par la passerelle. Gardez les deux contrôles.

**Question :** Bob approuve `create_ticket` dans Foundry. Obtient-il le droit d'écrire ?

<details>
<summary>Afficher la réponse</summary>

Non. L'approbation confirme son intention sans ajouter de rôle au jeton. La passerelle refuse toujours l'écriture
avec HTTP 403, car Bob n'a pas `Tools.Write`.

</details>

## Ce que vous déployez

La partie A est facultative et payante. Faites approuver changements et coûts, puis nettoyez le jour même.

| Élément | Limite |
|---|---|
| Projet Foundry et modèle `gpt-4.1-mini` | Groupe **séparé** `rg-<nom>` créé par le modèle Azure Developer CLI (`azd`) |
| Client OAuth dédié et principal de service | Microsoft Entra ID |
| Préautorisation et listes de clients autorisés | API MCP, authentification Function et stratégies de passerelle existantes |
| Secret client valable un jour, remis seulement à Foundry | Application dédiée uniquement ; jamais dans une conversation ni dans le dépôt |
| Rôle Foundry User pour Alice et Bob | Portée exacte du projet |
| Modèle d'identité d'agent (*agent identity blueprint*) | Créé par Foundry ; supprimer le groupe ne le supprime pas |

**Préversion (Preview)** : OAuth Identity Passthrough et configuration MCP du nouveau portail Foundry.
La partie B ne déploie rien.

## Prérequis et rôles requis

- Modules 03 à 06 low-code déployés et validés dans votre environnement hors production approuvé.
  Conservez `.workshop\participant.tfvars.json` et `.workshop\test-users.private.json`.
- PowerShell 7.4+, Azure CLI et `azd` 1.34+. Aucun état Terraform n'est nécessaire pour ce parcours.
- Participant : Contributor pour le groupe Foundry et droit d'attribuer **Foundry User** sur le projet exact.
- Administrateur des identités : gestion du client dédié, préautorisation sur l'API MCP et suppression du modèle d'identité d'agent.
  Ne donnez pas ces rôles à Alice ou Bob.
- Alice et Bob gardent leurs rôles MCP existants. Ne donnez pas `Tools.Write` à Bob.

## Étapes

### 1. Initialiser et retrouver votre passerelle

Dans **Portail Azure → Abonnements**, vérifiez l'abonnement approuvé. Utilisez votre compte de déploiement
ou celui de l'administrateur pour les opérations qui lui reviennent, pas le profil d'Alice ou de Bob.
Exécutez les blocs PowerShell dans la même session, à la racine du dépôt :

```powershell
$ErrorActionPreference = 'Stop'
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
$id = "$($p.participant_prefix)lc"; $sfx = $p.resource_suffix.Substring(0, 10)
$rg = if ($p.existing_resource_group_name) { $p.existing_resource_group_name } else { "rg-mcp-$id-$sfx" }
$fn = "func-mcp-$id-$sfx"; $apim = "apim-mcp-$id-$sfx"
$tenant = az account show --query tenantId -o tsv
$sub = az account show --query id -o tsv
az account show --query '{subscription:name,tenant:tenantId}' -o table
$apps = @(az ad app list --display-name "Workshop MCP API ($id-$sfx)" -o json | ConvertFrom-Json)
if ($apps.Count -ne 1) { throw 'Une seule API MCP attendue. Vérifiez noms et contexte.' }
$mcpApp = $apps[0].appId
$scopeId = az ad app show --id $mcpApp --query "api.oauth2PermissionScopes[?value=='user_impersonation'].id | [0]" -o tsv
if (-not $scopeId) { throw 'Scope délégué MCP introuvable.' }
$gateway = az apim show -g $rg -n $apim --query gatewayUrl -o tsv
if (-not $gateway) { throw 'Passerelle introuvable.' }
$mcpEndpoint = "$gateway/workshop-mcp/mcp"
$scopes = "api://$mcpApp/user_impersonation offline_access"
"MCP: $mcpEndpoint"; "Scopes: $scopes"
```

> **Résultat attendu** — URL de la passerelle, jamais de la Function, et scope de votre API.

Dans **Centre d'administration Entra → Inscriptions d'applications → Workshop MCP API → Exposer une API**,
confirmez `user_impersonation`.

### 2. Créer le projet Foundry avec le modèle de déploiement fourni

Utilisez `azd` pour préparer et déployer le projet et son modèle d'intelligence artificielle.
Les fichiers du modèle de déploiement décrivent les ressources à créer. Cette étape se fait dans le terminal :
aucune procédure équivalente dans le portail n'a été vérifiée pour cet atelier.
Ce modèle de déploiement, sous licence MIT, a été vérifié au commit `5bf59a056c41ff37801dea334ba6a141e2dc5f67`.
La commande ci-dessous utilise son URL publiée, sans épingler ce commit.

```powershell
$name = "mcp07-$id-$sfx"
$dir = Join-Path $PWD ".workshop\foundry-07\$name"
New-Item -ItemType Directory -Force $dir | Out-Null
Push-Location $dir
try {
    $env:AZURE_DEV_USER_AGENT = 'microsoft_foundry_skill'
    azd init -t https://github.com/Azure-Samples/azd-ai-starter-basic -e $name --no-prompt
    azd env set AZURE_LOCATION swedencentral
    azd env set AZURE_SUBSCRIPTION_ID $sub
    azd env set ENABLE_HOSTED_AGENTS false
    azd env set ENABLE_CAPABILITY_HOST false
    azd env set AI_PROJECT_DEPLOYMENTS '[{\"name\":\"gpt-4.1-mini\",\"model\":{\"name\":\"gpt-4.1-mini\",\"format\":\"OpenAI\",\"version\":\"2025-04-14\"},\"sku\":{\"name\":\"GlobalStandard\",\"capacity\":20}}]'
    azd provision --no-prompt
    if ($LASTEXITCODE -ne 0) { throw 'Échec Foundry. Inspectez le groupe dédié avant de réessayer.' }
    $endpoint = azd env get-value AZURE_AI_PROJECT_ENDPOINT
} finally { Pop-Location }
az group update -n "rg-$name" --tags workshop=governed-mcp owner=$($p.owner) expiry=$($p.expiry) module=07 -o none
```

> **Résultat attendu** — projet et modèle déployés. Prévoyez environ quatre minutes, sans garantie de durée.

Gardez les guillemets échappés du JSON. Dans **Portail Azure → Groupes de ressources → rg-<nom>**, vérifiez
le compte Foundry, le projet et la balise `module=07`. Ce groupe est **distinct** de celui des modules précédents.

### 3. Créer le client OAuth dédié (administrateur des identités)

Le script crée le client sans secret et conserve les identifiants de nettoyage dans un fichier privé.
Exécutez-le une seule fois. En cas d'interruption, inspectez les inscriptions avant toute nouvelle création.

```powershell
if (Test-Path .\.workshop\module07.private.json) { throw 'Fichier client déjà présent. Inspectez-le avant de continuer.' }
$f = Join-Path $PWD '.workshop\foundry-client-request.json'
try {
    @{ resourceAppId = $mcpApp; resourceAccess = @(@{ id = $scopeId; type = 'Scope' }) } |
        ConvertTo-Json -Depth 5 -AsArray | Set-Content $f
    $app = az ad app create --display-name "workshop-mcp-foundry-client-$id-$sfx" --sign-in-audience AzureADMyOrg `
        --required-resource-accesses "@$f" --query '{appId:appId,id:id}' -o json | ConvertFrom-Json
    if (-not $app.appId) { throw 'Échec création du client.' }
    @{ foundry_client_app_id = $app.appId; foundry_client_object_id = $app.id; foundry_resource_group = "rg-$name" } |
        ConvertTo-Json | Set-Content .\.workshop\module07.private.json
    az ad sp create --id $app.appId -o none
    if ($LASTEXITCODE -ne 0) { throw 'Échec du principal de service. Gardez le fichier de nettoyage.' }
} finally { Remove-Item $f -Force -ErrorAction SilentlyContinue }
```

> **Résultat attendu** — un client dédié et son principal de service ; le fichier privé contient des ID et un groupe, **aucun secret**.

### 4. Ajouter le client aux trois contrôles

Demandez à l'administrateur d'ouvrir **Entra → Inscriptions d'applications → Workshop MCP API → Exposer une API →
Applications clientes autorisées → Ajouter une application cliente**. Il doit entrer `$app.appId`, cocher
`user_impersonation`, puis sélectionner **Ajouter une application**, en conservant Visual Studio Code et Azure CLI.

Avec votre compte de déploiement, ouvrez **Function App → votre `$fn` → Paramètres → Authentification → Microsoft → Modifier →
Applications clientes autorisées**. Ajoutez `$app.appId` sans supprimer les applications existantes, puis sélectionnez
**Enregistrer**. Lisez la liste pour générer les stratégies correspondantes :

```powershell
$authUrl = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Web/sites/$fn/config/authsettingsV2?api-version=2024-04-01"
$auth = az rest --url $authUrl -o json | ConvertFrom-Json
$ids = @($auth.properties.identityProviders.azureActiveDirectory.validation.defaultAuthorizationPolicy.allowedApplications)
if ($ids -notcontains $app.appId) { throw "Client absent de l'authentification Function. Terminez la modification portail." }
& .\modules\04-governed-gateway\render-policies.ps1 -TenantId $tenant -ApiClientId $mcpApp -GatewayName $apim -AllowedClientIds $ids
```

> **Résultat attendu** — fichiers XML dans `.workshop` et client dans la liste Function. La génération ne déploie aucune stratégie.

Dans **API Management → votre instance → APIs**, ouvrez **All operations → Policies → Code editor**,
collez le XML complet généré, puis **Save**, pour chaque API réellement déployée :

| API | Fichier local |
|---|---|
| `workshop-mcp` | `.workshop\policy-mcp-server.xml` |
| `contoso-tickets-api`, si déployée | `.workshop\policy-rest-api.xml` |
| `contoso-tickets-mcp`, si déployée | `.workshop\policy-rest-mcp-server.xml` |

Vérifiez que les stratégies conservent les contrôles de l'émetteur, de l'audience, du scope et des rôles.
Le nouvel ID doit s'ajouter aux anciens.
Ne supprimez pas une validation pour contourner un refus.
La génération reprend les valeurs par défaut du module 04 : 30 appels par 60 secondes, sans filtre IP facultatif.
Si vous les avez modifiées, fournissez vos valeurs actuelles avec `-RateLimitCalls`, `-RateLimitPeriod` et `-AllowedIpRanges`
avant de coller le XML. Comparez d'abord la stratégie existante ; arrêtez-vous si vous ne pouvez pas retrouver ces valeurs.

### 5. Connecter l'outil MCP dans Foundry (Préversion)

Ouvrez [Foundry](https://ai.azure.com/nextgen), votre projet, puis **Build → Tools → Connect a tool → Custom →
Model Context Protocol (MCP) → Create** :

| Champ | Valeur de ce module |
|---|---|
| Name | `workshop-governed` |
| Remote MCP Server endpoint | `$mcpEndpoint` affiché à l'étape 1 |
| Authentication | **OAuth Identity Passthrough** |
| Client ID | `$app.appId`, aussi dans `.workshop\module07.private.json` |
| Client secret | Vide jusqu'à la remise directe de l'étape 6 |
| Token URL et Refresh URL | `https://login.microsoftonline.com/<votre-tenant-id>/oauth2/v2.0/token` |
| Auth URL | `https://login.microsoftonline.com/<votre-tenant-id>/oauth2/v2.0/authorize` |
| Scopes | `$scopes` affiché à l'étape 1 |

Remplacez `<votre-tenant-id>` par `$tenant`. Sélectionnez **Connect**, copiez seulement la **Redirect URL**.
Sélectionnez **Use in an agent**, nommez l'agent `workshop-mcp-agent`, retirez **Web search** s'il est présent,
puis sélectionnez **Save**.

![Capture réelle de l'auteur : connexion MCP Foundry](../../assets/screenshots/azure-07-foundry-tool.png)

*Exemple réel du 20 octobre 2026 : cadre 1, adresse de la passerelle ; cadre 2, OAuth Identity Passthrough ;
cadre 3, adresse de redirection à inscrire. Utilisez vos propres valeurs, pas celles de la capture.*

### 6. Inscrire la redirection et remettre le secret d'un jour à Foundry

Faites exécuter ce bloc par l'administrateur : il doit remplacer uniquement l'URL, puis coller tout le bloc.
N'affichez pas `$secret`, n'activez pas de transcription et ne conservez pas la sortie sensible.
Cette exception se limite au client confidentiel dédié et à un secret valable un jour ; elle n'autorise pas
l'emploi de secrets réutilisables. Le bloc utilise un fichier de requête privé, ignoré par Git et supprimé dans `finally` :
le transfert ne se fait donc pas uniquement en mémoire.

```powershell
$redirect = '<url-de-redirection-etape-5>'
$s = Get-Content .\.workshop\module07.private.json -Raw | ConvertFrom-Json
$f = Join-Path $PWD '.workshop\foundry-connection.private.json'
try {
    @{ web = @{ redirectUris = @($redirect) } } | ConvertTo-Json -Depth 4 | Set-Content $f
    az rest --method patch --url "https://graph.microsoft.com/v1.0/applications/$($s.foundry_client_object_id)" --body "@$f" --headers 'Content-Type=application/json'
    if ($LASTEXITCODE -ne 0) { throw 'Échec modification de la redirection.' }
    $end = (Get-Date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $secret = az ad app credential reset --id $s.foundry_client_app_id --append --display-name 'foundry-module07-short-lived' --end-date $end --query password -o tsv --only-show-errors
    if (-not $secret) { throw 'Échec création du secret.' }
    $proj = az resource list -g $s.foundry_resource_group --resource-type Microsoft.CognitiveServices/accounts/projects --query '[0].id' -o tsv
    $url = "https://management.azure.com$proj/connections/workshop-governed?api-version=2025-06-01"
    $c = (az rest --url $url -o json | ConvertFrom-Json).properties
    $body = @{ properties = @{ authType = 'OAuth2'; category = $c.category; group = $c.group; target = $c.target; authorizationUrl = $c.authorizationUrl
        tokenUrl = $c.tokenUrl; refreshUrl = $c.refreshUrl; scopes = $c.scopes; connectorName = $c.connectorName
        isSharedToAll = $false; metadata = $c.metadata; credentials = @{ clientId = $s.foundry_client_app_id; clientSecret = $secret } } }
    [IO.File]::WriteAllText($f, ($body | ConvertTo-Json -Depth 6 -Compress))
    az rest --method put --url $url --body "@$f" --headers 'Content-Type=application/json' -o none
    if ($LASTEXITCODE -ne 0) { throw 'Échec connexion. Nettoyez le client dédié avant de réessayer.' }
} finally { Remove-Item $f -Force -ErrorAction SilentlyContinue; $secret = $null; $body = $null }
```

> **Résultat attendu** — aucun secret affiché ; aucune sortie après mise à jour de la connexion.

Dans **Entra → client dédié → Certificats et secrets**, vérifiez la description
`foundry-module07-short-lived` et l'expiration d'un jour, jamais la valeur. Lors du test du 2026-10-20, un client public
permettait la connexion d'Alice à Entra, mais pas l'échange du code par Foundry ; le client confidentiel fonctionnait.
Ne passez pas à une clé API ou à un accès anonyme.

### 7. Donner l'accès au projet et tester dans le portail

Avec le compte autorisé à attribuer ce rôle, ouvrez **Portail Azure → projet Foundry → Contrôle d'accès (IAM) → Ajouter une attribution de rôle →
Foundry User → Membres → Sélectionner des membres**. Sélectionnez uniquement Alice et Bob avec leurs ID du fichier
`.workshop\test-users.private.json`, puis **Vérifier + attribuer**. Portée : ce projet, pas l'abonnement.
Attendez deux à trois minutes. L'appel direct au projet testé le 2026-10-20 nécessitait **Foundry User** ;
**Foundry Agent Consumer** renvoyait HTTP 403.

Dans un profil de navigateur connecté en tant qu'Alice, ouvrez le projet, puis **Build → Agents → workshop-mcp-agent → Playground** :

```prompt
Use the workshop MCP tool to call get_service_health with service "workshop-api". Summarise the result. Do not call any write tool.
```

Si Foundry demande un consentement, ouvrez le lien reçu par Alice, sélectionnez **Allow access**,
connectez-vous en tant qu'Alice et relancez la demande. Examinez l'outil et ses arguments, puis sélectionnez **Approve once**.
Vous devez obtenir la réponse synthétique `healthy`.

Bob : dans un autre profil de navigateur connecté comme Bob, ouvrez le même playground :

```prompt
Use the workshop MCP tool. Call create_ticket with service "ticket-queue", severity "medium" and summary "Synthetic ticket - Contoso workshop". Show the tool result, or the exact error if the call is refused.
```

Ouvrez uniquement le lien reçu par Bob et approuvez sa tentative. Vous devez observer un refus **HTTP 403**
de la passerelle : aucun ticket n'est créé.
Ne partagez jamais le lien de consentement : l'agent pourrait agir avec le jeton d'une autre personne.

![Capture réelle : approbation Foundry](../../assets/screenshots/azure-07-foundry-approve.png)

*Exemple réel du 2026-10-20 : cadre 1, appel en attente ; cadre 2, Approve once ;
cadre 3, connexion MCP via API Management, seul outil configuré dans l'agent.
L'approbation ne donne aucun rôle d'application.*

![Capture réelle : résultat de lecture synthétique](../../assets/screenshots/azure-07-foundry-result.png)

*Exemple réel du 2026-10-20 : vérifiez approbation, réponse synthétique et outil utilisé.
Ne versez aucune capture de prompt, argument ou résultat dans les journaux. Utilisez des données fictives seulement.*

### Partie B — Copilot Studio (lecture uniquement, non validée en conditions réelles)

Cette partie ne demande aucune action. La documentation décrit l'ajout sous **Agent → Tools → Add a tool → New tool →
Model Context Protocol**, avec le nom, la description et l'URL de la passerelle.
L'authentification à étudier est **OAuth 2.0**, jamais **None** ou **API key**. Le mode **Manual** documenté exige
un secret client : seule l'exception ci-dessus est acceptable, sur une application dédiée, pour un jour, sans affichage
ni copie conservée et avec suppression au nettoyage. L'atelier n'implémente pas l'inscription dynamique de clients.
Seul le transport **Streamable** est pris en charge ; SSE ne l'est plus.
Consultez les sources avant toute expérimentation séparée. Aucune connexion Copilot Studio n'a été validée ici.

## Ce que vous devriez voir

- Alice approuve et lit l'état synthétique ; Bob approuve mais son écriture est refusée avec HTTP 403.
- Les trois contrôles incluent le client ; la passerelle reste le seul point d'entrée.
- Le [module 06 low-code](../06-observe-inventory/LOW-CODE.fr.md) montre des métadonnées, statuts et durées seulement.

### Vérifier vous-même avec Azure CLI

**Pourquoi :** Foundry doit utiliser la même entrée protégée que VS Code.
Dans PowerShell 7, à la racine du dépôt, retrouvez la passerelle de votre parcours :

```powershell
$ErrorActionPreference = 'Stop'
$inspectParticipant = Get-Content -LiteralPath .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
$inspectId = "$($inspectParticipant.participant_prefix)lc"
$inspectSuffix = $inspectParticipant.resource_suffix.Substring(0, 10)
$inspectGroup = if ($inspectParticipant.existing_resource_group_name) { $inspectParticipant.existing_resource_group_name } else { "rg-mcp-$inspectId-$inspectSuffix" }
$inspectNames = [pscustomobject]@{ api_management = "apim-mcp-$inspectId-$inspectSuffix" }
```

> **Résultat attendu** — aucune sortie : les variables reçoivent les noms de votre déploiement. Vérifiez avec `$inspectNames`.

Copiez cette commande en lecture seule :

```powershell
az apim show -g $inspectGroup -n $inspectNames.api_management --query '{name:name,sku:sku.name,provisioningState:provisioningState,gatewayUrl:gatewayUrl}' -o json
if ($LASTEXITCODE -ne 0) { throw 'Passerelle introuvable. Reprenez les prérequis du module 04.' }
```

> **Résultat attendu** — `StandardV2`, `Succeeded` et votre `gatewayUrl`.
> L'adresse du serveur MCP se termine par `/workshop-mcp/mcp` sur cette passerelle.

![Résultat réel Azure CLI : état et URL de la passerelle, sans création de client](../../assets/screenshots/terminal-07-az-gateway.png)

Après les étapes de connexion approuvées, comparez aussi le résultat dans Foundry :

![Exemple réel d'un résultat d'outil dans Foundry via API Management](../../assets/screenshots/azure-07-foundry-result.png)

*La lecture Azure CLI a été capturée le 20 octobre 2026 ; vos noms low-code comportent `lc`.
Le résultat Foundry est une capture existante, pas une nouvelle validation de ce parcours.
Le contrôle d'APIM ne vérifie pas la connexion OAuth ni les droits par utilisateur : les essais ci-dessous restent nécessaires.
Ne réactivez jamais l'accès direct à la Function pour contourner un échec du client.*

## Valider

> [!NOTE]
> **Limites de validation :** le parcours Foundry initial a été testé par l'auteur le 2026-10-20,
> mais ce parcours low-code n'a pas été revalidé de bout en bout dans sa version actuelle.
> Les captures datées illustrent ces tests antérieurs ; certains noms viennent du parcours Terraform.
> Utilisez vos ressources `lc` et vérifiez vos propres résultats. La partie B (Copilot Studio) reste une lecture
> uniquement, non validée en conditions réelles. Le relais d'identité OAuth et la configuration MCP du nouveau
> portail Foundry restent en **préversion (Preview)**.

Vérifiez d'abord les fichiers du module avec PowerShell, sans accéder à Azure :

```powershell
pwsh .\modules\07-clients\validate.ps1 -Offline
```

> **Résultat attendu** — lignes `PASS` et code 0, sans preuve de connexion réelle.

Alternative bash :

```bash
bash ./modules/07-clients/validate.sh --offline
```

> **Résultat attendu** — les mêmes lignes `PASS` hors ligne et code 0.

Un code de sortie 0 confirme les contrôles hors ligne. Le validateur vérifie les fichiers du module,
pas les actions effectuées dans le portail. Pour valider votre connexion réelle, refaites l'étape 7 avec les deux comptes
distincts : Alice doit lire, et l'écriture de Bob doit recevoir HTTP 403. Exécutez ensuite les requêtes KQL du module 06.
Une requête vide ne prouve pas le succès. Aucun résultat réel n'est disponible pour la partie B.

## Dépannage

- **403 à la découverte des outils** : vérifiez les trois listes et la stratégie `server/discover` inchangée du module 04.
- **Erreur de consentement malgré une connexion Entra réussie** : réessayez une fois, le jeton est parfois déjà conservé.
- **Aucune connexion client** : vérifiez redirection Web et secret d'un jour, sans contourner l'authentification.
- **AADSTS50105** : utilisez Alice/Bob, pas le compte administrateur sans rôle MCP.
- **403 avant l'appel** : vérifiez Foundry User et attendez la propagation.
- **Erreur JSON au provisionnement** : gardez les guillemets échappés de l'étape 2.
- **Le champ obligatoire Client secret bloque l'étape 5** : arrêtez-vous avant de créer un autre secret.
  Lors du test du 2026-10-20, le portail permettait de poursuivre à ce stade. Si ce n'est plus le cas,
  la procédure doit être revérifiée ; ne contournez pas le blocage avec une clé API ou un accès anonyme.

## Nettoyer

Reprenez votre compte de déploiement ou celui de l'administrateur, pas celui d'Alice ou de Bob.
Initialisez le contexte ci-dessous, même si vous venez d'ouvrir une nouvelle session :

```powershell
$tenant = az account show --query tenantId -o tsv
$sub = az account show --query id -o tsv
az account show --query '{subscription:name,tenant:tenantId}' -o table
pwsh .\modules\07-clients\cleanup.ps1 -TenantId $tenant -SubscriptionId $sub -LowCodeTrack
# Après accord explicite et revue de chaque PLAN :
pwsh .\modules\07-clients\cleanup.ps1 -TenantId $tenant -SubscriptionId $sub -LowCodeTrack -Apply
```

> **Résultat attendu** — un rapport, puis des lignes `PASS` et `DONE` confirmant la suppression du client dédié
> et de son secret, du modèle d'identité d'agent et du groupe Foundry balisé, ainsi que la purge du compte Foundry.

Gardez `.workshop\module07.private.json` jusqu'à la fin.
**Passez toujours `-LowCodeTrack` : ce mode n'utilise jamais Terraform ni son état.**
Les anciennes entrées du client restent dans l'API MCP, l'authentification Function et les stratégies de passerelle.
**Continuez immédiatement au [module 99 low-code](../99-cleanup/LOW-CODE.fr.md)** pour supprimer les ressources du serveur
et l'API créées pour l'atelier. Si vous devez conserver une ressource partagée, faites retirer uniquement l'entrée
du client Foundry de chacune de ses listes de clients autorisés. Ne supprimez ni la liste entière ni les autres entrées.
Ne laissez pas ce nettoyage inachevé. Conservez les comptes et ressources partagés.

Si vous n'avez pas réalisé la partie A, vous n'avez rien à supprimer pour le module 07.
Si le déploiement a échoué avant la création du fichier privé, inspectez `rg-<nom>` dans le portail ;
le module 99 explique comment supprimer les ressources après avoir vérifié qu'elles appartiennent à votre atelier.

Depuis bash, appelez PowerShell sans oublier le commutateur de parcours :

```bash
tenant=$(az account show --query tenantId -o tsv); sub=$(az account show --query id -o tsv)
pwsh ./modules/07-clients/cleanup.ps1 -TenantId "$tenant" -SubscriptionId "$sub" -LowCodeTrack
```

> **Résultat attendu** — rapport seulement, aucune modification Azure ou Entra.

Ajoutez `-Apply` seulement après accord.

## Aller plus loin

Comparez Foundry Agent Consumer pour un agent publié avec l'accès direct au projet dans une expérience séparée approuvée.
Suivez l'évolution des fonctionnalités en préversion (Preview), sans remplacer le contexte délégué par une identité managée.

## Sources

- [Retrouver la passerelle avec Azure CLI](https://learn.microsoft.com/cli/azure/apim#az-apim-show), vérifié le 20 octobre 2026.

- [Authentification MCP Foundry](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication).
- [Functions MCP et Foundry](https://learn.microsoft.com/azure/azure-functions/functions-mcp-foundry-tools).
- [azd-ai-starter-basic, MIT, commit vérifié 5bf59a056c41ff37801dea334ba6a141e2dc5f67](https://github.com/Azure-Samples/azd-ai-starter-basic).
- [Connexion MCP Copilot Studio](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent).
- [MCP server/discover, spécification 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/server/discover).

Dernière vérification : 2026-10-20 (sources et parcours initial de l'auteur ; parcours low-code actuel non revalidé de bout en bout).

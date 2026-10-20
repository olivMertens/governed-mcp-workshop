# 03 - Se connecter au serveur avec Microsoft Entra

## Objectif

[English](README.md) · [Parcours low-code, portail d'abord](LOW-CODE.fr.md)

Au module 02, toute personne qui possède la clé peut utiliser votre serveur **Model Context Protocol (MCP)**.
Vous allez remplacer cette clé partagée par un accès nominatif avec **Microsoft Entra ID** :
seuls les comptes de test auxquels l'administrateur a attribué un rôle dans l'application pourront entrer.

Vous vérifierez qu'Alice et Bob peuvent accéder au serveur, mais pas Eve.
Vous constaterez aussi une limite volontaire : le serveur ne distingue pas encore
les outils que Bob peut consulter de ceux qui lui permettent d'écrire.
Le module 04 ajoutera ce contrôle.

### Le scénario : trois collègues, deux décisions différentes

Vous utilisez trois comptes de test, Alice, Bob et Eve, dans le **même tenant** (annuaire Microsoft Entra) Contoso.
Le compte d'Eve fonctionne : elle peut se connecter à Entra, mais elle n'a pas accès à cette application.

| Compte de test | Attribution dans l'application MCP | Résultat à la fin du module 03 | Ce que vous démontrez |
|---|---|---|---|
| Alice | `Tools.Read` et `Tools.Write` | Obtient un jeton pour le serveur et voit les cinq outils | Une utilisatrice autorisée entre |
| Bob | `Tools.Read` seulement | Obtient un jeton et voit les mêmes cinq outils ; il peut encore appeler `create_ticket` | Entrer dans le serveur ne suffit pas à limiter les actions |
| Eve | Aucune | Entra refuse de lui délivrer un jeton pour cette application : `AADSTS50105` | Appartenir au tenant ne donne pas accès au serveur |

**Vous avez terminé l'exercice** lorsque les contrôles du serveur et les tests des trois comptes donnent
les résultats attendus. Un refus prévu est une réussite du test, pas une erreur à contourner.

## Pourquoi c'est important

Deux décisions se succèdent :

1. **Qui peut accéder au serveur ?** C'est ce module : Entra exige une attribution à l'application.
   L'authentification intégrée de la Function App vérifie ensuite le jeton avant l'exécution du code MCP.
2. **Quels outils cette personne peut-elle utiliser ?** C'est le module 04 : la passerelle vérifiera le rôle requis
   par chaque outil. Définir `Tools.Read` ne rend pas automatiquement le serveur « lecture seule ».

### Comprendre le jeton sans en afficher un vrai

Un jeton d'accès est destiné à une **API** (interface de programmation), pas à tous les services Microsoft.
Un jeton pour Microsoft Graph doit donc être refusé par votre serveur MCP, même s'il appartient à Alice.

**Construisez-le étape par étape.** Cliquez sur **Suivant** pour ajouter un élément à la fois ; le schéma complet suit.

```reveal
{
  "title": "D'une clé partagée à un jeton personnel",
  "audience": "attendee",
  "width": 760,
  "height": 380,
  "lanes": [
    {"x": 8, "width": 232, "label": "Utilisateurs"},
    {"x": 264, "width": 232, "label": "Microsoft Entra ID"},
    {"x": 520, "width": 232, "label": "Azure Functions"}
  ],
  "nodes": [
    {"id":"entra","step":0,"x":286,"y":44,"width":188,"icon":"entra","title":"Workshop MCP API","detail":["inscription d'app","rôles : Tools.Read"]},
    {"id":"fn","step":0,"x":542,"y":164,"width":188,"icon":"functions","title":"Azure Functions","detail":["auth. intégrée","puis serveur MCP"]},
    {"id":"key","step":0,"until":2,"tone":"morning","x":542,"y":284,"width":188,"title":"Clé de fonction","detail":["module 02"]},
    {"id":"alice","step":1,"x":30,"y":44,"width":188,"title":"Alice ou Bob","detail":["comptes autorisés"]},
    {"id":"bad","step":3,"tone":"risk","x":30,"y":164,"width":188,"title":"Jeton absent ou faux","detail":["ex. audience Graph"]},
    {"id":"eve","step":4,"tone":"risk","x":30,"y":284,"width":188,"title":"Eve (non attribuée)","detail":["aucun jeton"]}
  ],
  "edges": [
    {"from":"alice","to":"entra","step":1,"label":"connexion"},
    {"from":"alice","to":"fn","step":2,"tone":"governed","labelDy":16,"label":"jeton → 200"},
    {"from":"bad","to":"fn","step":3,"tone":"risk","label":"HTTP 401"},
    {"from":"eve","to":"entra","step":4,"tone":"risk","toSide":"bottom","label":"AADSTS50105"}
  ],
  "steps": [
    {"title": "Inscrire l'API dans Entra", "simple": "Le serveur MCP reçoit une identité dans Microsoft Entra ID, avec deux rôles d'application.", "say": "L'inscription définit l'audience `api://<client-id>` et les rôles `Tools.Read` et `Tools.Write`. La clé de fonction du module 02 est encore là pour l'instant."},
    {"title": "Se connecter, recevoir un jeton", "simple": "Alice se connecte et reçoit un jeton fait pour cette API uniquement.", "say": "Le jeton désigne l'API comme audience et liste les rôles d'Alice. Le client ne voit jamais son mot de passe."},
    {"title": "La plateforme vérifie d'abord", "simple": "Avant que votre code s'exécute, Azure vérifie le jeton. Un jeton valide obtient HTTP 200 ; la clé disparaît.", "say": "L'authentification intégrée vérifie l'émetteur, le tenant, l'audience et l'expiration. Votre code ne lit jamais un jeton lui-même."},
    {"title": "Mauvais jeton, pas d'entrée", "simple": "Pas de jeton, ou un jeton pour une autre API : la plateforme répond HTTP 401.", "say": "Un jeton Microsoft Graph valide est quand même refusé : son audience est Graph, pas cette API. Une audience par jeton."},
    {"title": "Eve reste dehors", "simple": "Eve n'est pas attribuée à l'application : Entra refuse de lui donner un jeton.", "say": "L'attribution est obligatoire sur l'application d'entreprise. Eve s'arrête à la connexion avec `AADSTS50105`, avant même d'atteindre Azure."}
  ]
}
```

![Architecture du niveau 1](../../assets/architecture/03.fr.svg)

| Champ du jeton | Question à laquelle il répond | Dans cet atelier |
|---|---|---|
| `aud` — audience | À quelle API ce jeton est-il destiné ? | L'API MCP seulement |
| `iss`, `tid` — émetteur et tenant | Quel annuaire l'a émis ? | Votre tenant de test seulement |
| `exp`, `nbf` — validité | Peut-on l'utiliser maintenant ? | Vérifié par l'authentification intégrée |
| `azp` — application cliente | Quel logiciel appelle pour l'utilisateur ? | VS Code ou Azure CLI, autorisés dans la configuration |
| `scp` — permission déléguée, ou *scope* | Quelle permission le client a-t-il obtenue pour agir au nom de l'utilisateur ? | `user_impersonation`, préautorisé pour les deux clients |
| `roles` — rôles d'application | Quels droits ont été attribués à cet utilisateur dans cette application ? | Alice : lecture et écriture ; Bob : lecture ; contrôle par outil au module 04 |
| `oid` — identifiant d'objet | Quel compte appelle ? | Identifiant du compte dans le tenant |

La préautorisation du **client** évite une demande de consentement pour cette permission.
L'attribution d'un rôle à **l'utilisateur** est une décision différente : autoriser VS Code ne donne pas accès à Eve.
Ces rôles d'application ne sont pas les rôles Azure comme Contributeur sur un groupe de ressources.

> [!WARNING]
> Ne demandez jamais à afficher un jeton avec Azure CLI et ne le collez jamais dans un décodeur en ligne,
> une conversation, un fichier ou une capture. Les validateurs le gardent en mémoire.
> Comparez uniquement les [exemples fictifs Alice](synthetic-claims/alice.json) et [Bob](synthetic-claims/bob.json).

### Pourquoi procéder en deux étapes ?

Vous ne devez jamais retirer le verrou existant avant que le nouveau fonctionne.

| Moment | Protection devant le serveur | Ce que vous faites |
|---|---|---|
| Départ, module 02 | Clé système MCP | Vous reprenez le serveur existant |
| Étape 1 du déploiement | Entra **et** clé | Vous activez Entra, puis vérifiez sa configuration et le refus sans jeton |
| Étape 2 du déploiement | Entra, sans exigence de clé | Vous retirez l'exigence de clé, puis testez les trois comptes |

Azure enregistre les paramètres d'authentification et les paramètres d'application par des appels distincts.
Les deux déploiements évitent une période où aucun verrou ne serait actif.

## Ce que vous déployez

Vous conservez la Function App, son code et les cinq outils du module 02.

| Responsable | Changement | Pourquoi |
|---|---|---|
| Administrateur des identités | Inscription d'application dédiée à l'API MCP, limitée à un tenant, jetons v2, URI `api://<client-id>` | Donner au serveur sa propre audience |
| Administrateur des identités | Permission déléguée `user_impersonation`, clients VS Code et Azure CLI préautorisés | Permettre aux clients de demander un jeton pour ce serveur |
| Administrateur des identités | Application d'entreprise avec **Assignment required? = Yes** ; Alice : deux rôles, Bob : un, Eve : aucun | Refuser un jeton à Eve |
| Participant | Authentification intégrée obligatoire, requêtes sans authentification → HTTP 401, tenant et audience MCP seulement, clients autorisés, magasin de jetons désactivé | Protéger les requêtes avant le code |
| Participant | Métadonnées de ressource protégée (**PRM**, **Preview**) via `WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES` | Indiquer à VS Code où se connecter et quelle permission demander |
| Participant | Retrait de l'exigence de clé dans un second déploiement | Passer d'un secret partagé à l'identité |

`Tools.Read` et `Tools.Write` sont des rôles utilisateur. `Tools.Execute.All`, réservé aux applications, est défini
pour la suite mais n'est attribué à aucune application ici. Aucun utilisateur, secret ou certificat n'est créé par Terraform.
Aucune permission Graph ou Storage n'est ajoutée dans ce module.

![Architecture du niveau 1 : le client obtient un jeton auprès d'Entra puis appelle le serveur](../../assets/architecture/03.fr.svg)

**Coût :** pas de nouvelle ressource Azure facturée ; les coûts du module 02 continuent.
Les changements de paramètres peuvent redémarrer l'application.

**Écart volontaire avec certains tutoriels Microsoft :** les assistants du portail peuvent créer un secret client.
Ce parcours utilise la configuration sans secret déjà fournie dans le dépôt. N'utilisez pas l'assistant pour la remplacer.
Les PRM App Service restent en **Preview**.

## Prérequis et rôles nécessaires

- Votre module 02 est déployé et validé dans un environnement de test approuvé. Vous reprenez le **même dépôt,
  les mêmes fichiers privés et le même état Terraform**. Si le module 04 a déjà rendu la Function privée,
  ne rejouez pas ce module pour la rendre publique : utilisez un environnement suivant l'ordre 02 → 03 → 04.
- Terraform 1.16.6+, PowerShell 7.4+, Azure CLI et VS Code avec GitHub Copilot.
- Participant : droits du module 02 sur le groupe de ressources, notamment Contributeur.
  Aucun rôle d'administration Entra n'est nécessaire pour vos manipulations Azure.
- Administrateur des identités, dans une session distincte : Administrateur d'applications cloud
  ou Administrateur d'applications pour l'inscription, les préautorisations et les attributions.
  Pas besoin d'Administrateur général ni de consentement administrateur à Graph pour ce module.
- Trois comptes de test existants, dédiés et hors production : Alice, Bob et Eve.
  Seul l'administrateur autorisé les prépare, hors Terraform. Administrateur des utilisateurs n'est nécessaire que pour leur création.
  Chaque compte doit pouvoir terminer l'authentification multifacteur (**MFA**) imposée par le tenant.
  Ne désactivez pas une stratégie d'accès conditionnel.

Envoyez la [demande d'identité](../../docs/requests/identity-request.md) à l'administrateur avant l'atelier.
Vous n'avez pas à obtenir ses droits pour poursuivre.

## Étapes

### PowerShell

Exécutez toutes les commandes à la racine du dépôt et gardez le même terminal ouvert.
Les commandes `az ... show`, `az ... list` et `az rest --method get` ci-dessous **lisent** la configuration.
Terraform reste seul responsable des modifications : n'utilisez pas `az ... set` ou `az rest --method put`
sur ces ressources, sinon le prochain déploiement pourrait annuler vos réglages.

### 1. Retrouver votre serveur et vérifier le contexte

Sélectionnez votre tenant et votre abonnement de test. Le script vérifie leur correspondance avant la suite.
Puis lisez les noms dans l'état local, pour ne pas les deviner.

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\select-azure-context.ps1 -Language fr
$rg = terraform '-chdir=infra\workload' output -raw resource_group_name
if ($LASTEXITCODE -ne 0 -or -not $rg) { throw 'Groupe du module 02 introuvable.' }
$fn = terraform '-chdir=infra\workload' output -raw mcp_function_app_name
if ($LASTEXITCODE -ne 0 -or -not $fn) { throw 'Function du module 02 introuvable.' }
az functionapp show --subscription $env:ARM_SUBSCRIPTION_ID --resource-group $rg --name $fn --query '{name:name,state:state,host:defaultHostName}' -o table
if ($LASTEXITCODE -ne 0) { throw 'Lecture de la Function impossible. Vérifiez le contexte du module 02.' }
```

> **Résultat attendu** — votre Function, son état `Running` et son domaine.
> Retrouvez le même nom dans **Portail Azure → Function App → Overview**.
> Les deux commandes Terraform ne déploient rien : elles relisent les noms conservés au module 02.

### 2. Recevoir la préparation Entra de l'administrateur

Avant de modifier la Function, obtenez ces deux fichiers privés :

- `.workshop\module03.tfvars.json` : configuration de l'API, avec `enable_entra_auth = true`
  et `entra_auth_replace_key_gate = false` pour le premier déploiement ;
- `.workshop\module03-personas.json` : identifiants d'objet des trois comptes, pour vérifier que vous testez la bonne personne.

Ils contiennent des identifiants, **pas de mots de passe ni de jetons**. Ne les publiez pas.
Si l'administrateur les a déjà fournis, passez à l'étape 3.

<details>
<summary>À transmettre à l'administrateur : préparer l'application et les deux fichiers</summary>

Utilisez un terminal et l'état `infra\entra` distincts de ceux du participant.
Ne commencez qu'après approbation des modifications dans le tenant de test.
Reprenez les paramètres du participant et les identifiants d'objet des comptes existants.
Ils sont visibles dans **Microsoft Entra → Users → compte → Overview → Object ID**.

```powershell
$ErrorActionPreference = 'Stop'
$tenant = '<tenant-id>'
az login --tenant $tenant --allow-no-subscriptions --output none
if ($LASTEXITCODE -ne 0) { throw 'Connexion administrateur impossible.' }
$p = Get-Content -LiteralPath .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
@{
    tenant_id = $tenant; participant_prefix = $p.participant_prefix; resource_suffix = $p.resource_suffix
    owner = $p.owner; expiry = $p.expiry
    test_user_object_ids = @{ alice = '<alice-object-id>'; bob = '<bob-object-id>'; eve = '<eve-object-id>' }
} | ConvertTo-Json | Set-Content -LiteralPath .\.workshop\entra.tfvars.json
terraform '-chdir=infra\entra' init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Initialisation Entra impossible.' }
terraform '-chdir=infra\entra' plan '-var-file=..\..\.workshop\entra.tfvars.json' '-out=..\..\.workshop\entra.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Plan Entra impossible.' }
```

**STOP — relisez et faites approuver le plan.** Pour une première création, il prévoit huit ajouts :
application, URI, application d'entreprise, deux préautorisations et trois attributions.
Alice reçoit `Tools.Read` et `Tools.Write`, Bob `Tools.Read`, Eve rien.
Le plan ne doit prévoir aucune suppression ni création d'utilisateur ou de secret.
Lors d'une nouvelle exécution, des objets déjà présents peuvent ne plus apparaître dans les ajouts.

Pour une application fournie par l'administrateur, ajoutez `create_application = false` et
`existing_application_client_id = '<client-id>'` aux paramètres **avant** le plan.
Terraform lit alors la définition existante et gère les trois attributions, pas l'inscription elle-même.
L'administrateur doit avoir configuré ses scopes, rôles, préautorisations et l'attribution obligatoire.

```powershell
terraform '-chdir=infra\entra' apply '..\..\.workshop\entra.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Déploiement Entra incomplet. Ne transmettez pas les fichiers.' }
$config = terraform '-chdir=infra\entra' output -json workload_module03_tfvars
if ($LASTEXITCODE -ne 0) { throw 'Configuration participant indisponible.' }
$config | Set-Content -LiteralPath .\.workshop\module03.tfvars.json
$personas = terraform '-chdir=infra\entra' output -json persona_object_ids
if ($LASTEXITCODE -ne 0) { throw 'Identifiants des comptes indisponibles.' }
$personas | Set-Content -LiteralPath .\.workshop\module03-personas.json
```

> **Résultat attendu** — les deux fichiers sont prêts à transmettre en privé.
> Vérifiez également l'application avec Azure CLI, sans lire de jeton :

```powershell
$api = ($config | ConvertFrom-Json).mcp_api_client_id
az ad app show --id $api --query '{name:displayName,audience:signInAudience,uris:identifierUris,scopes:api.oauth2PermissionScopes[].value,roles:appRoles[].value,clients:api.preAuthorizedApplications[].appId}' -o json
if ($LASTEXITCODE -ne 0) { throw "Lecture de l'inscription impossible." }
az ad sp show --id $api --query '{name:displayName,assignmentRequired:appRoleAssignmentRequired}' -o json
if ($LASTEXITCODE -ne 0) { throw "Lecture de l'application d'entreprise impossible." }
```

> **Résultat attendu** — `AzureADMyOrg`, `api://<client-id>`, `user_impersonation`, les trois rôles,
> les clients VS Code `aebc6443-996d-45c2-90f0-388ff96faa56` et Azure CLI
> `04b07795-8ddb-461a-bbee-02f9e1bf7b46`, puis `assignmentRequired: true`.

L'attribution obligatoire concerne les utilisateurs ; la liste des clients autorisés concerne les logiciels.
Dans **Enterprise applications → votre API → Users and groups**, vérifiez les trois attributions, aucune pour Eve.

![Rôles à retrouver sur votre inscription d'application](../../assets/screenshots/azure-03-app-roles.png)
![Attribution obligatoire à retrouver dans les propriétés de votre application d'entreprise](../../assets/screenshots/azure-03-enterprise-app-properties.png)

Ces captures vous aident à retrouver les réglages. Leurs noms et identifiants ont été masqués ;
vérifiez les valeurs de votre propre application.

</details>

### 3. Vérifier ce que vous allez configurer

```powershell
$v = Get-Content -LiteralPath .\.workshop\module03.tfvars.json -Raw | ConvertFrom-Json
if (-not $v.enable_entra_auth -or $v.entra_auth_replace_key_gate -ne $false) {
    throw 'Cette première étape exige Entra activé et le retrait de clé désactivé. Ne rejouez pas un déploiement plus avancé.'
}
if ($v.entra_tenant_id -ne $env:ARM_TENANT_ID) { throw 'Le tenant reçu ne correspond pas au contexte approuvé.' }
if (-not (Test-Path -LiteralPath .\.workshop\module03-personas.json)) { throw "Demandez le fichier des trois comptes à l'administrateur." }
$apiClientId = $v.mcp_api_client_id
$audience = $v.mcp_api_identifier_uri
$v | Select-Object enable_entra_auth, entra_auth_replace_key_gate, entra_tenant_id, mcp_api_client_id, mcp_api_identifier_uri
```

> **Résultat attendu** — Entra est activé et la clé reste exigée.
> Vous retrouvez votre tenant et l'audience `api://<client-id>`.
> L'ID client identifie **l'API MCP**, pas VS Code. Vous ne saisissez aucun secret.

**Question :** Bob a `Tools.Read` et Eve n'a aucun rôle. Pourquoi Bob pourra-t-il entrer, mais pas Eve ?

<details>
<summary>Afficher la réponse</summary>

L'application d'entreprise exige une attribution. Bob en a une, Eve non. Entra peut délivrer à Bob un jeton pour
l'API MCP, mais refuse celui d'Eve avec `AADSTS50105`. Eve peut pourtant se connecter au même tenant.
`Tools.Read` n'est pas encore contrôlé outil par outil.

</details>

**Question :** VS Code est préautorisé pour `user_impersonation`. Cela donne-t-il accès à Eve ?

<details>
<summary>Afficher la réponse</summary>

Non. La préautorisation concerne la permission demandée par le logiciel client au nom d'un utilisateur.
Elle ne remplace pas l'attribution à cette personne. Eve n'a toujours aucun rôle dans l'application.
Les champs `scp` et `roles` répondent à deux questions différentes.

</details>

### 4. Activer Entra sans retirer la clé

Terraform ajoute l'authentification intégrée et les paramètres de découverte sur la Function existante.
Passez **les trois fichiers** pour conserver les réglages des modules précédents.

```powershell
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-var-file=..\..\.workshop\module02.tfvars.json' '-var-file=..\..\.workshop\module03.tfvars.json' '-out=..\..\.workshop\module03.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Plan impossible. Ne continuez pas.' }
```

> **Résultat attendu** — Terraform affiche le plan, l'enregistre dans `.workshop` et ne modifie encore rien.

**STOP — relisez le plan avant de l'appliquer.** Vous devez retrouver l'authentification obligatoire sur la Function,
la réponse `Return401`, votre tenant et l'audience MCP. Le serveur n'est ni remplacé ni supprimé.
Si vous avez déployé le portail facultatif, son indication de connexion peut aussi être mise à jour.
Le nombre total de changements n'est donc pas le critère de réussite.
Arrêtez-vous si le plan supprime une protection ou modifie une ressource sans lien avec cette étape.

Après approbation :

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\module03.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Déploiement incomplet. Gardez la clé en place.' }
```

> **Résultat attendu** — mise à jour terminée, aucun ajout ni retrait de serveur. Attendez son redémarrage.
> Un client doit maintenant présenter **un jeton et la clé** ; ne testez pas encore la connexion finale de Bob.

### 5. Lire la protection réellement déployée avant de continuer

Cette commande Azure CLI lit la configuration d'authentification dans **Azure Resource Manager**, l'API de gestion Azure.
Elle ne lit ni n'affiche de jeton.

```powershell
$authUrl = "https://management.azure.com/subscriptions/$env:ARM_SUBSCRIPTION_ID/resourceGroups/$rg/providers/Microsoft.Web/sites/$fn/config/authsettingsV2?api-version=2024-04-01"
$authJson = az rest --method get --uri $authUrl --query properties -o json
if ($LASTEXITCODE -ne 0) { throw 'Authentification illisible. Ne retirez pas la clé.' }
$auth = $authJson | ConvertFrom-Json
$aad = $auth.identityProviders.azureActiveDirectory
$expectedAudiences = @($audience, $apiClientId) | Select-Object -Unique
if ($auth.platform.enabled -ne $true -or $auth.globalValidation.requireAuthentication -ne $true -or
    $auth.globalValidation.unauthenticatedClientAction -ne 'Return401' -or
    $aad.registration.openIdIssuer -ne "https://login.microsoftonline.com/$env:ARM_TENANT_ID/v2.0" -or
    $aad.registration.clientId -ne $apiClientId -or
    (Compare-Object @($aad.validation.allowedAudiences) $expectedAudiences)) {
    throw 'La protection Entra ne correspond pas à la configuration attendue. Ne retirez pas la clé.'
}
$auth.globalValidation | Select-Object requireAuthentication, unauthenticatedClientAction
$aad.validation.allowedAudiences
$hostName = az functionapp show --subscription $env:ARM_SUBSCRIPTION_ID --resource-group $rg --name $fn --query defaultHostName -o tsv
if ($LASTEXITCODE -ne 0 -or -not $hostName) { throw 'Domaine de la Function introuvable.' }
$endpoint = "https://$hostName/runtime/webhooks/mcp"
$request = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"workshop","version":"1"}}}'
$r = Invoke-WebRequest -Uri $endpoint -Method Post -ContentType 'application/json' -Body $request -SkipHttpErrorCheck -TimeoutSec 60
if ($r.StatusCode -ne 401) { throw "HTTP $($r.StatusCode) au lieu de 401. Ne retirez pas la clé." }
$r.StatusCode
```

> **Résultat attendu** — `True`, `Return401`, les deux formes de la même audience MCP (`api://<client-id>` et `<client-id>`),
> puis **401**. Aucune audience Graph n'est autorisée.
> Un 401 seul ne suffirait pas : l'ancienne clé pouvait déjà le produire. C'est la lecture de la configuration
> **et** ce refus qui vous permettent de passer à la suite.

Dans **Function App → Settings → Authentication**, retrouvez l'authentification obligatoire,
HTTP 401 et le magasin de jetons désactivé.

![Repère de lecture : authentification exigée, HTTP 401 et magasin de jetons désactivé](../../assets/screenshots/azure-03-function-authentication.png)

**Question :** pourquoi ne suffit-il pas d'obtenir HTTP 401 avant de retirer l'exigence de clé ?

<details>
<summary>Afficher la réponse</summary>

Le serveur du module 02 renvoyait déjà HTTP 401 sans clé. Cette réponse seule ne prouve donc pas qu'Entra est actif.
Vous devez aussi lire la configuration déployée : authentification obligatoire, `Return401`, bon tenant et audience MCP.
Ensuite seulement, le second déploiement peut retirer l'exigence de clé sans laisser le serveur sans protection.

</details>

### 6. Retirer l'exigence de clé, sans retirer Entra

Seulement après réussite de l'étape 5 :

```powershell
$v.entra_auth_replace_key_gate = $true
$v | ConvertTo-Json | Set-Content -LiteralPath .\.workshop\module03.tfvars.json
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-var-file=..\..\.workshop\module02.tfvars.json' '-var-file=..\..\.workshop\module03.tfvars.json' '-out=..\..\.workshop\module03.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Plan impossible. Ne continuez pas.' }
```

> **Résultat attendu** — Terraform affiche le plan de l'étape 2, l'enregistre dans `.workshop` et ne modifie encore rien.

**STOP — relisez le plan.** Il ajoute le paramètre
`AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel = Anonymous`.
L'authentification Entra doit rester obligatoire. Si le plan retire `auth_settings_v2`, un fichier de variables manque :
ne l'appliquez pas.

Après approbation :

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\module03.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Déploiement incomplet. Vérifiez la configuration avant les tests.' }
az functionapp config appsettings list --subscription $env:ARM_SUBSCRIPTION_ID --resource-group $rg --name $fn --query "[?name=='WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES' || name=='AzureFunctionsJobHost__extensions__mcp__system__webhookAuthorizationLevel'].{name:name,value:value}" -o table
if ($LASTEXITCODE -ne 0) { throw 'Lecture des deux paramètres impossible.' }
```

> **Résultat attendu** — le scope `api://<client-id>/user_impersonation` et la valeur `Anonymous`.
> Ce mot concerne seulement le verrou interne de l'extension MCP : **Entra protège toujours l'accès public**.
> Le paquet conserve `System` dans `host.json`, pour ne pas devenir anonyme s'il est publié seul.
> Vous n'avez pas à republier le code.

### 7. Vérifier le serveur avec votre compte Azure habituel

Gardez votre session Azure habituelle pour cette étape.
Le validateur envoie les requêtes et affiche le résultat de chaque contrôle, sans montrer les jetons :

```powershell
& .\modules\03-entra-authentication\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

> **Résultat attendu** — le validateur confirme :
>
> - sans jeton : **HTTP 401** ;
> - métadonnées PRM (**Preview**) : **HTTP 200**, votre tenant et `user_impersonation` ;
> - jeton destiné à Graph : **HTTP 401** ;
> - configuration déployée : authentification obligatoire, `Return401`, audience MCP ;
> - ancienne clé seule : **HTTP 401**. Si le script indique que ce test est ignoré, ne le comptez pas comme réussi.

La ligne `operator checks complete` signifie « contrôles du serveur terminés ».
`Persona checks are still required` vous demande de continuer avec les trois comptes.
Les messages du script sont en anglais. Une ligne `PASS` hors ligne ne prouve pas que votre déploiement fonctionne.

**Question :** Alice possède un jeton Graph valide émis par votre tenant. Doit-il ouvrir le serveur MCP ?

<details>
<summary>Afficher la réponse</summary>

Non : HTTP 401. Le jeton est destiné à Graph, pas à l'API MCP. La validité du compte et du jeton ne change pas
son audience. Inversement, le serveur ne doit jamais transmettre le jeton MCP à Graph.
Le module 05 obtiendra un jeton distinct pour cet appel.

</details>

### 8. Vous connecter dans VS Code comme Alice

Affichez l'adresse sans clé : `$endpoint`. Dans **Ctrl+Maj+P → MCP: Open User Configuration**,
remplacez uniquement l'entrée `workshop-open` et sa demande de clé par cette entrée, en conservant vos autres serveurs :

```json
{
  "servers": {
    "workshop-entra": { "type": "http", "url": "https://<function-app-host>/runtime/webhooks/mcp" }
  }
}
```

1. Remplacez `<function-app-host>` par le domaine lu à l'étape 5, puis enregistrez.
2. Sélectionnez **Start** au-dessus du serveur, ou **MCP: List Servers → workshop-entra → Start Server**.
3. Autorisez l'authentification Microsoft. Choisissez **Alice**, pas votre compte Azure habituel.
   Enregistrez sa méthode MFA si le tenant le demande.
4. Dans **Copilot Chat → Agent → Configure Tools**, sélectionnez uniquement `workshop-entra`.
5. Envoyez la demande suivante. Lisez et approuvez l'appel proposé une seule fois.

```prompt
Utilise workshop-entra. Liste ses outils, puis appelle get_service_health avec service "workshop-api".
```

> **Résultat attendu** — serveur `Running`, `Discovered 5 tools` et réponse de santé fictive.
> Cette réponse prouve l'appel de l'outil, pas la santé réelle d'une ressource Azure.

![Repères dans VS Code : configuration utilisateur, serveur démarré et cinq outils découverts](../../assets/screenshots/client-03-vscode.png)

Pour comparer visuellement avec Bob ou Eve, utilisez un profil VS Code distinct (**Profiles: New Profile...**).
Un profil seul ne prouve pas quel compte est connecté : vérifiez le compte choisi dans la fenêtre Microsoft.
Les tests suivants vérifient son identifiant exact.

### 9. Tester Alice, Bob et Eve sans perdre votre session

Vous allez vous connecter **trois fois**, avec le compte nommé dans le terminal.
`AZURE_CONFIG_DIR` sépare les sessions Azure CLI. Les comptes de test n'ont besoin d'aucun rôle sur l'abonnement :
`--allow-no-subscriptions` permet leur connexion au tenant.
Ils doivent tous réussir leur connexion au tenant ; **le refus d'Eve est attendu ensuite, lorsqu'elle demande le jeton MCP**.

```powershell
$ErrorActionPreference = 'Stop'
$operatorConfig = $env:AZURE_CONFIG_DIR
try {
    foreach ($persona in 'Alice', 'Bob', 'Eve') {
        Write-Host "Connectez-vous avec le compte $persona dans le navigateur."
        $env:AZURE_CONFIG_DIR = Join-Path $PWD ".workshop\az-$($persona.ToLower())"
        az login --tenant $env:ARM_TENANT_ID --allow-no-subscriptions --output none
        if ($LASTEXITCODE -ne 0) { throw "Connexion au tenant impossible pour $persona." }
        & .\modules\03-entra-authentication\validate.ps1 -TenantId $env:ARM_TENANT_ID -Persona $persona
        az logout
        if ($LASTEXITCODE -ne 0) { throw "Déconnexion impossible pour $persona." }
    }
} finally {
    if ($null -eq $operatorConfig) { Remove-Item Env:\AZURE_CONFIG_DIR -ErrorAction SilentlyContinue }
    else { $env:AZURE_CONFIG_DIR = $operatorConfig }
}
```

> **Résultat attendu** — pour chaque compte :
>
> | Compte | Ce que le validateur doit confirmer | Interprétation |
> |---|---|---|
> | Alice | Identifiant du compte correct ; `initialize` HTTP 200 ; `tools/list` HTTP 200, exactement cinq outils | Entra et le serveur acceptent son accès |
> | Bob | Identifiant du compte correct ; mêmes résultats HTTP 200 et cinq outils | Son attribution de lecture lui permet d'entrer |
> | Eve | Identifiant du compte correct ; demande de jeton refusée avec `AADSTS50105` | L'attribution obligatoire bloque son accès avant tout appel authentifié au serveur |

Le refus d'Eve vient du service Entra qui délivre les jetons (**HTTP 400**), pas d'un outil MCP (**HTTP 403**).
Un autre code d'échec, par exemple un problème MFA, ne démontre pas le contrôle d'attribution.
Azure CLI peut tenter une nouvelle connexion après le refus ; le validateur limite le temps d'attente.
Ne donnez pas un rôle à Eve pour faire disparaître le refus attendu.

**Question :** Bob voit `create_ticket`. Son rôle `Tools.Read` suffit-il à empêcher cet outil d'écrire au module 03 ?

<details>
<summary>Afficher la réponse</summary>

Non. Ici, l'attribution ouvre l'accès au serveur ; aucun contrôle par outil n'exploite encore `roles`.
Bob peut donc encore appeler `create_ticket`. Ce n'est ni le comportement final souhaité ni une raison de lui attribuer
`Tools.Write`. Le module 04 exigera ce rôle pour l'écriture et renverra HTTP 403 à Bob.
Une approbation humaine dans le client ne remplace pas cette autorisation côté serveur.

</details>

### Bash

Le déploiement reste le même en deux étapes. Pour suivre exactement les vérifications intermédiaires ci-dessus
depuis un terminal bash, démarrez **PowerShell 7** avec `pwsh`, puis exécutez les étapes 1 à 9.
Ne collez pas les commandes PowerShell directement dans bash.

Si le déploiement est déjà terminé, les scripts bash permettent de lancer les mêmes contrôles.
Dans le terminal où vous utilisez votre compte Azure habituel :

```bash
source ./scripts/select-azure-context.sh
bash ./modules/03-entra-authentication/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
```

> **Résultat attendu** — les mêmes lignes `PASS` que la version PowerShell ci-dessus : `validate.sh` lance le même script.

Pour tester les trois comptes, utilisez un sous-shell : à sa fermeture, vous retrouvez votre configuration initiale.
Le fichier privé des identifiants doit être présent comme à l'étape 2.

```bash
(
  set -e
  for persona in Alice Bob Eve; do
    printf 'Connectez-vous avec le compte %s dans le navigateur.\n' "$persona"
    export AZURE_CONFIG_DIR="$PWD/.workshop/az-${persona,,}"
    az login --tenant "$ARM_TENANT_ID" --allow-no-subscriptions --output none
    bash ./modules/03-entra-authentication/validate.sh -TenantId "$ARM_TENANT_ID" -Persona "$persona"
    az logout
  done
)
```

> **Résultat attendu** — les mêmes contrôles et refus que dans le tableau de l'étape 9.

## Ce que vous devez voir

| Test | Résultat attendu | Contrôle démontré |
|---|---|---|
| Appel MCP sans jeton | HTTP 401 | Identité exigée avant le code |
| Découverte PRM (**Preview**) | HTTP 200, tenant et scope de votre API | Le client sait où demander l'accès |
| Ancienne clé seule | HTTP 401 | La possession du secret partagé ne suffit plus |
| Jeton valide pour Graph | HTTP 401 | Audience limitée à l'API MCP |
| Alice et Bob | HTTP 200 pour `initialize` et `tools/list`, cinq outils | Utilisateurs ayant une attribution |
| Eve | `AADSTS50105`, aucun jeton MCP | Refus d'une utilisatrice sans attribution |
| Bob et `create_ticket` | Encore utilisable à ce niveau | Limite à corriger au module 04, pas une preuve de lecture seule |

Ne comparez pas votre nombre de changements Terraform à une ancienne exécution.
Comparez **votre configuration et vos résultats** à ce tableau.

### Comprendre les résultats avec la documentation

Ces références expliquent les différences entre authentification, consentement et autorisation.
Elles ont été vérifiées le 2026-10-16 ; les quatre sources principales ont aussi été relues le 2026-10-20.

| Résultat observé ou choix technique | Ce qu'il faut comprendre dans Microsoft Learn | Référence de configuration ou d'API |
|---|---|---|
| Sans jeton ou avec la seule ancienne clé : HTTP 401 | [Authentification App Service](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization) : la plateforme contrôle l'identité avant l'exécution de l'outil. | [Ressource authsettingsV2](https://learn.microsoft.com/azure/templates/microsoft.web/sites/config-authsettingsv2) : `requireAuthentication`, `unauthenticatedClientAction` et `allowedAudiences`. |
| Le client découvre où se connecter | [Autorisation MCP et métadonnées de ressource protégée (**Preview**)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp). Cela protège l'accès au serveur, pas chaque outil. | La même page décrit `WEBSITE_AUTH_PRM_DEFAULT_WITH_SCOPES` et la réponse indiquant l'URL des métadonnées. |
| Un jeton Graph est refusé ; un jeton MCP est accepté | [Jetons d'accès](https://learn.microsoft.com/entra/identity-platform/access-tokens) : l'audience désigne l'API cible. | [Audiences autorisées dans authsettingsV2](https://learn.microsoft.com/azure/templates/microsoft.web/sites/config-authsettingsv2), pas une liste de jetons d'API interchangeables. |
| Alice et Bob accèdent au serveur ; Eve reçoit `AADSTS50105` | [Exiger une attribution utilisateur](https://learn.microsoft.com/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users) : se connecter au tenant ne suffit pas. | [Attribuer des rôles d'application](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps), utilisés pour les comptes de test existants. |
| Scope `user_impersonation` comparé aux rôles `Tools.Read` / `Tools.Write` ; Bob peut encore écrire ici | [Scopes et consentement](https://learn.microsoft.com/entra/identity-platform/scopes-oidc) décrivent la permission déléguée accordée au client. Les [rôles d'application](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps) expriment les droits attribués à l'utilisateur. | Le module 04 ajoute le contrôle du rôle par outil. Définir un rôle ne l'applique pas automatiquement. |

### Vérifier vous-même avec Azure CLI

**Pourquoi :** HTTP 401 ne suffit pas à prouver qu'Entra protège le serveur : au module 02, la clé provoquait déjà ce refus.
Relisez la configuration réellement déployée. Dans PowerShell 7, à la racine du dépôt :

```powershell
$ErrorActionPreference = 'Stop'
$inspectGroup = terraform '-chdir=infra\workload' output -raw resource_group_name
if ($LASTEXITCODE -ne 0) { throw 'Groupe de ressources indisponible.' }
$inspectNames = terraform '-chdir=infra\workload' output -json resource_names | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Noms des ressources indisponibles.' }
$inspectFunctionId = az resource show -g $inspectGroup -n $inspectNames.function_app --resource-type Microsoft.Web/sites --api-version 2024-11-01 --query id -o tsv
if ($LASTEXITCODE -ne 0 -or -not $inspectFunctionId) { throw "Identifiant de l'application indisponible." }
```

> **Résultat attendu** — aucune sortie : `$inspectFunctionId` contient l'identifiant de votre Function App.

La commande suivante fait un `GET` sur l'API de gestion Azure. Elle ne lit aucun jeton utilisateur ni secret :

```powershell
az rest --method get --url "https://management.azure.com$inspectFunctionId/config/authsettingsV2?api-version=2024-11-01" --query 'properties.{enabled:platform.enabled,required:globalValidation.requireAuthentication,action:globalValidation.unauthenticatedClientAction}' -o json
if ($LASTEXITCODE -ne 0) { throw "Lecture de la configuration d'authentification impossible." }
```

> **Résultat attendu** — `enabled` et `required` valent `true`, et `action` vaut `Return401`.
> L'authentification est donc activée et obligatoire, sans redirection vers une page de connexion.

![Lecture réelle Azure CLI : authentification activée, obligatoire, avec Return401](../../assets/screenshots/terminal-03-az-auth.png)

*Capture en lecture seule du 20 octobre 2026. Comparez ces trois champs, puis contrôlez aussi l'émetteur,
l'audience et les comptes avec le validateur. Cette capture ne prouve pas les droits d'Alice ou Bob.
Si un champ diffère, ne retirez pas la clé et ne poursuivez pas avant d'avoir corrigé votre configuration approuvée.*

## Valider

Pour une vérification **sans accès Azure ou Entra** :

```powershell
& .\modules\03-entra-authentication\validate.ps1 -Offline
```

> **Résultat attendu** — lignes `PASS` pour les protections dans les fichiers, les exemples fictifs et les tests Terraform simulés.
> Ce résultat vérifie votre copie du dépôt, **pas** la configuration de votre tenant.

Pour terminer votre exercice, vérifiez que vous avez :

- obtenu les résultats du contrôle serveur à l'étape 7, sans confondre test ignoré et test réussi ;
- testé les trois comptes à l'étape 9, avec une correspondance d'identifiant confirmée pour chacun ;
- obtenu HTTP 200 et cinq outils pour Alice **et** Bob ;
- obtenu exactement `AADSTS50105` pour Eve, et non un simple échec de connexion ;
- compris pourquoi Bob peut encore écrire ici.

Le validateur n'appelle pas `create_ticket` au module 03 : ses tests Alice/Bob prouvent la connexion et la découverte,
pas un refus d'écriture. Les outils d'accès aux données restent des simulations jusqu'au module 05.

**Question :** les contrôles du serveur passent et Eve échoue avec une erreur MFA. Le module est-il validé ?

<details>
<summary>Afficher la réponse</summary>

Non. Les connexions Alice et Bob doivent aussi être testées. Pour Eve, seul le refus `AADSTS50105` démontre
l'absence d'attribution. Terminez l'enregistrement MFA demandé, puis retestez sans modifier les stratégies du tenant.
Une capture d'un autre environnement ou un contrôle hors ligne ne remplace pas ces résultats.

</details>

## Dépannage

| Symptôme | Explication et action |
|---|---|
| Alice reçoit HTTP 401 entre les deux déploiements | La clé est encore exigée. Terminez la lecture de la configuration à l'étape 5, puis le second déploiement. |
| Alice reçoit HTTP 401 après le second déploiement | Vérifiez le tenant, l'audience MCP et le paramètre du webhook. N'ajoutez pas Graph aux audiences acceptées. |
| `AADSTS50105` pour Bob ou Alice | Faites vérifier leurs attributions par l'administrateur sur **cette** application ; attendez la propagation et reconnectez-vous. |
| `AADSTS50105` pour Eve | C'est le résultat attendu. Ne lui attribuez pas de rôle. |
| Autre refus pour Eve | Ce n'est pas encore la preuve attendue. Vérifiez le compte, la MFA et l'accès au tenant. |
| Le compte ne correspond pas à Alice, Bob ou Eve | Reconnectez le bon compte dans son profil CLI. Ne modifiez pas le fichier privé pour masquer une mauvaise connexion. |
| `AADSTS65001`, consentement demandé | Faites vérifier les clients préautorisés et leur scope par l'administrateur. |
| HTTP 403 avec un jeton MCP | Vérifiez que le client est VS Code ou Azure CLI et figure dans les clients autorisés. |
| VS Code ouvre `<function-host>/authorize` | Vérifiez les PRM (**Preview**), leur scope et la fin du redémarrage. |
| Le plan retire l'authentification ou recrée le serveur | Arrêtez-vous. Vérifiez les trois fichiers de variables et le même état du module 02. |
| Azure CLI ne peut pas lire l'application Entra | Demandez la vérification à l'administrateur ; n'élargissez pas vos droits pour ce contrôle. |

## Nettoyer

**Si vous continuez immédiatement au module 04, conservez les ressources et les fichiers privés.**
Sinon, procédez dans l'ordre inverse du déploiement : rétablissez l'exigence de clé,
retirez l'authentification Entra de la Function App, puis supprimez l'application Entra.
Ne supprimez jamais l'application Entra tant que la Function en dépend.

Le script commence par un plan. Exécutez-le sans `-Apply`, relisez son périmètre, puis appliquez après approbation :

```powershell
& .\modules\03-entra-authentication\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

> **Résultat attendu** — plan limité au module 03. Le nettoyage remet la clé **avant** de retirer l'authentification intégrée.
> S'il signale un changement extérieur au module, arrêtez-vous.

```powershell
& .\modules\03-entra-authentication\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
```

> **Résultat attendu** — la phase 1 remet la clé, la phase 2 retire l'authentification intégrée, puis le script se termine par `PASS the server is back to the level 0 key gate.`

Puis demandez à l'administrateur, dans sa session et son état Entra :

```powershell
& .\modules\03-entra-authentication\cleanup.ps1 -TenantId $tenant -Scope Entra
```

> **Résultat attendu** — sans `-Apply`, le plan de suppression des objets Entra du module 03, sans rien modifier. L'administrateur relance avec `-Apply` après approbation.

Après lecture et approbation du plan :

```powershell
& .\modules\03-entra-authentication\cleanup.ps1 -TenantId $tenant -Scope Entra -Apply
```

> **Résultat attendu** — seuls les objets Entra gérés pour l'atelier sont supprimés.
> Une inscription fournie par l'administrateur et les comptes existants sont conservés.

Équivalents bash pour afficher les plans, puis relancer avec `-Apply` après approbation :

```bash
bash ./modules/03-entra-authentication/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
# Dans la session de l'administrateur :
bash ./modules/03-entra-authentication/cleanup.sh -TenantId "<tenant-id>" -Scope Entra
```

> **Résultat attendu** — les mêmes lignes `PASS` et `PLAN` que les commandes PowerShell ci-dessus.

Ne laissez pas le serveur au niveau « clé seule » : terminez par le [nettoyage du module 02](../02-open-server/README.fr.md#nettoyer)
ou le [module 99](../99-cleanup/README.fr.md). Retirez l'entrée `workshop-entra` de VS Code.
Déconnectez les profils de test. Retirez les fichiers privés du module seulement après le nettoyage réussi.

## Aller plus loin

- Expliquez à un collègue pourquoi Bob et Eve n'ont pas le même résultat, puis pourquoi Bob n'est pas encore limité à la lecture.
- Comparez les [exemples fictifs Alice](synthetic-claims/alice.json) et [Bob](synthetic-claims/bob.json), sans décoder de vrai jeton.
- Lisez [scopes et rôles d'application](../../docs/fr/concepts/scopes-and-app-roles.md)
  et la [chaîne de jetons](../../docs/fr/concepts/token-chain.md).
- Continuez au [module 04](../04-governed-gateway/README.fr.md) : même serveur et mêmes comptes,
  mais `create_ticket` exigera `Tools.Write`. Bob devra alors recevoir HTTP 403.

## Sources

- [Lire les paramètres d'authentification V2](https://learn.microsoft.com/rest/api/appservice/web-apps/get-auth-settings-v-2?view=rest-appservice-2024-11-01), vérifié le 20 octobre 2026.

- [Autorisation MCP intégrée et PRM (Preview)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp)
- [Connexion VS Code et App Service](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode)
- [Tutoriel Functions MCP : authentification et paramètre du webhook](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial)
- [Rôles d'application](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps)
- [Exiger une attribution](https://learn.microsoft.com/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users)
- [Azure CLI : lire une Function](https://learn.microsoft.com/cli/azure/functionapp#az-functionapp-show)
- [Azure CLI : lire les paramètres d'application](https://learn.microsoft.com/cli/azure/functionapp/config/appsettings#az-functionapp-config-appsettings-list)
- [Azure CLI : lire une inscription](https://learn.microsoft.com/cli/azure/ad/app#az-ad-app-show)
- [Azure CLI : lire une application d'entreprise](https://learn.microsoft.com/cli/azure/ad/sp#az-ad-sp-show)
- [Azure CLI : appeler une API avec az rest](https://learn.microsoft.com/cli/azure/reference-index#az-rest)
- [Exemple Functions épinglé au commit 468c518](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9)
- [Fournisseur AzureAD 3.10.0](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0/docs)
  et [AzureRM 5.9.0, auth_settings_v2](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown)

Dernière vérification : 2026-10-20 (documentation et contrôles locaux ; aucun nouveau déploiement).

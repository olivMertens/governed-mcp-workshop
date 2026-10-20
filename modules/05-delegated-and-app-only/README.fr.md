# 05 - Avec les droits de qui ? Accès délégué ou applicatif (niveau 3)

[English](README.md)

## Objectif

[Guide low-code, portail d'abord](LOW-CODE.fr.md)

**Parcours Terraform + PowerShell.** Vous gérerez les identités du serveur dans `infra/workload`.
L'administrateur des identités configurera la relation de confiance dans `infra/entra`, avec son propre état Terraform.
Conservez vos paramètres privés et votre état existants. Si vous avez créé vos ressources dans le portail,
suivez plutôt le guide low-code.

Vous allez faire **la même demande** avec Alice et Bob, puis comparer **les droits utilisés** pour accéder aux données.
Vous activerez d'abord les identités du serveur, ferez configurer la confiance par l'administrateur, puis publierez
le rapport synthétique et comparerez les appels. À la fin :

- `whoami` appelle Microsoft Graph **au nom de** l'utilisateur connecté et ne renvoie qu'un libellé de compte de test
  (`alice` ou `bob`) ;
- `read_report_as_user` lit un rapport synthétique dans Azure Storage **en tant qu'utilisateur** (On-Behalf-Of, OBO) : **Alice**
  obtient le rapport, **Bob** obtient une **erreur d'outil Model Context Protocol (MCP) dans une réponse HTTP 200**,
  car Storage lui répond HTTP 403 ;
- `read_report_as_app` lit le même rapport **en tant qu'application** (une identité managée) : **Alice et Bob obtiennent le même
  résultat** ;
- **ce module n'utilise aucun secret client** : l'API MCP prouve son identité avec une identité managée via des informations d'identification fédérées.

> [!WARNING]
> Ne collez jamais un jeton réel dans un site web, une conversation, un fichier, une capture ou un journal. Le validateur ne
> conserve les jetons qu'en mémoire, et `whoami` ne renvoie jamais ni vrai nom ni adresse e-mail.

## Pourquoi c'est important

Jusqu'ici, les outils n'appelaient aucun service en aval (démonstrations synthétiques) ou utilisaient l'identité du serveur. Les
outils peuvent aussi appeler d'autres API. Il faut alors choisir : **avec les droits de qui** ces appels sont-ils effectués ?

| | Contexte utilisateur : **On-Behalf-Of** | Contexte application : **identité managée** |
|---|---|---|
| Outils | `whoami`, `read_report_as_user` | `read_report_as_app` |
| Jeton en aval | Un **nouveau** jeton pour Graph (`User.Read`) ou Storage (`user_impersonation`), émis pour l'utilisateur connecté | Un jeton propre à l'application, émis pour l'identité managée affectée par l'utilisateur |
| Qui décide de l'accès | Le rôle **de l'utilisateur** sur les données (Alice : Storage Blob Data Reader ; Bob : aucun) | Le rôle **de l'identité** (Storage Blob Data Reader sur un conteneur) |
| Résultat | Différent selon l'utilisateur | **Identique pour tout appelant** que la passerelle laisse passer |
| Risque en cas d'abus | Faible : le serveur ne peut pas dépasser les droits de l'utilisateur | « Confused deputy » (mandataire abusé) : quiconque peut appeler l'outil lit ce que l'application peut lire |

### Vérifier les droits utilisés pour appeler Graph et Storage, pas seulement le statut HTTP

**Un jeton par appel, une audience par jeton.** Le jeton du client MCP a pour audience l'API MCP. Le serveur ne le transmet jamais
à Graph ni à Storage (pas de transmission directe, ou *token passthrough*). Pour les outils en contexte utilisateur,
il présente ce jeton **uniquement à Microsoft Entra ID**, comme preuve de l'identité de l'utilisateur
(*assertion* OBO), et reçoit en échange un jeton distinct par ressource en aval. L'outil en mode
applicatif, lui, n'utilise pas du tout le jeton de l'appelant.

**OBO sans secret.** OBO exige que l'API MCP s'authentifie comme client confidentiel. Au lieu d'un secret client ou d'un
certificat, l'inscription de l'API fait confiance à **une identité managée affectée par l'utilisateur**, associée au serveur,
via une **information d'identification fédérée** (émetteur `https://login.microsoftonline.com/<tenant>/v2.0`, sujet = l'ID de principal
de l'identité, audience `api://AzureADTokenExchange`). Le serveur demande à cette identité un jeton dont l'audience est
`api://AzureADTokenExchange` et l'utilise comme assertion client ([concept](../../docs/fr/concepts/obo-and-managed-identity.md)).

**OBO est réservé aux utilisateurs.** Les outils en contexte utilisateur refusent un jeton d'application (sans revendication `scp`,
`idtyp=app`) avant tout appel en aval. Un tel jeton ne représente pas un utilisateur et ne peut pas servir à cet échange OBO.

**Statut HTTP reçu par le client ou résultat de l'outil.** MCP transporte les erreurs d'outil dans une réponse JSON-RPC réussie : l'appel de
Bob renvoie **HTTP 200** avec `result.isError: true`. Le HTTP 403 de la passerelle (module 04) signifie « vous ne pouvez pas
appeler cet outil » ; une erreur d'outil avec HTTP 200 signifie « l'outil s'est exécuté, et l'API en aval a refusé l'identité
qu'il a utilisée ».

## Ce que vous déployez

Tout s'active par des variables explicites, désactivées par défaut. Tant que `enable_delegated_access` vaut false, les modules 00 à 04
ne changent pas et le serveur garde les démonstrations du module 02 pour `whoami` et `read_report_*`.

### Examiner les identités du serveur

**Ressources Azure** (`infra/workload/delegated-access.tf`, à configurer par le participant) :

| Ressource | Paramètres |
|---|---|
| Identité affectée par l'utilisateur `id-mcp-<prefix>-<suffix>-obo` | Approuvée par les informations d'identification fédérées de l'API MCP. **Aucun rôle Azure.** Sert uniquement à obtenir l'assertion client OBO. |
| Identité affectée par l'utilisateur `id-mcp-<prefix>-<suffix>-report` | Identité utilisée pour l'accès applicatif de `read_report_as_app` |
| Conteneur blob `reports` (compte de stockage du module 02, clés partagées désactivées) | Privé ; contient le fichier synthétique `monthly-usage.json` ([synthetic-data](synthetic-data/monthly-usage.json)) |
| Attribution de rôle | **Storage Blob Data Reader** pour l'identité `-report`, portée limitée au seul conteneur `reports` |
| Attribution de rôle | **Storage Blob Data Reader** pour Alice (`delegated_persona_object_ids.alice`), même portée. **Bob n'a rien.** |
| Attribution de rôle | Storage Blob Data Contributor sur le conteneur pour la personne qui publie le rapport (par défaut : l'utilisateur Terraform connecté) |
| Function App (module 02) | Les deux identités attachées ; paramètres `WORKSHOP_*` non secrets : tenant, ID client de l'API MCP, ID client des deux identités, URL du conteneur, correspondance entre les comptes de test et leurs identifiants |

**Pourquoi deux nouvelles identités ?** L'identité OBO peut agir au nom de l'inscription de l'API MCP. C'est pourquoi elle n'a aucun
rôle sur les données : un appel en contexte utilisateur ne dispose que des droits délégués de l'utilisateur. Une autre identité porte
les droits applicatifs. Aucun outil n'utilise l'identité d'hébergement du module 02 (Blob Data Owner sur tout le compte, pour
l'hôte Functions).

### Examiner la confiance et le consentement Entra

**Microsoft Entra** (`infra/entra/delegation.tf`, administrateur des identités, application créée uniquement) :

| Variable | Ressource | Effet |
|---|---|---|
| `enable_delegated_access` | `azuread_application_api_access` | L'API MCP demande les autorisations déléguées Microsoft Graph `User.Read` et Azure Storage `user_impersonation`. Terraform lit les ID de scope dans les principaux de service du tenant. Aucune autorisation d'application. |
| `obo_identity_principal_id` | `azuread_application_federated_identity_credential` | Fait confiance à l'identité `-obo` (sujet = son ID de principal). |
| `grant_downstream_admin_consent` | `azuread_service_principal_delegated_permission_grant` | Consentement administrateur à l'échelle du tenant pour ces deux scopes exactement (décision de l'administrateur des identités). |





**Construisez-le étape par étape.** Cliquez sur **Suivant** pour ajouter un élément à la fois ; le schéma complet suit.

```reveal
{
  "title": "Qui porte les droits en aval ?",
  "audience": "attendee",
  "width": 760,
  "height": 380,
  "lanes": [
    {"x": 8, "width": 232, "label": "Appelants"},
    {"x": 264, "width": 232, "label": "Serveur MCP"},
    {"x": 520, "width": 232, "label": "Entra et données"}
  ],
  "nodes": [
    {"id":"alice","step":0,"x":30,"y":44,"width":188,"title":"Alice","detail":["rôle de lecteur Storage"]},
    {"id":"fn","step":0,"x":286,"y":44,"width":188,"icon":"functions","title":"Serveur MCP","detail":["vérifie votre jeton","ne le transmet pas"]},
    {"id":"obo","step":1,"tone":"governed","x":286,"y":164,"width":188,"title":"Identité OBO","detail":["identité managée","aucun secret client"]},
    {"id":"entra","step":1,"x":542,"y":44,"width":188,"icon":"entra","title":"Microsoft Entra ID","detail":["On-Behalf-Of","échange de jeton"]},
    {"id":"storage","step":2,"x":542,"y":164,"width":188,"icon":"storage","title":"Azure Storage","detail":["conteneur reports","rôle par utilisateur"]},
    {"id":"bob","step":3,"x":30,"y":164,"width":188,"title":"Bob","detail":["aucun rôle Storage"]},
    {"id":"deny","step":3,"tone":"risk","x":542,"y":284,"width":188,"title":"Bob : Storage 403","detail":["MCP : HTTP 200","isError: true"]},
    {"id":"app","step":4,"x":286,"y":284,"width":188,"title":"Identité applicative","detail":["identité managée","la même pour tous"]}
  ],
  "edges": [
    {"from":"alice","to":"fn","step":0,"tone":"governed","label":"jeton MCP"},
    {"from":"fn","to":"entra","step":1,"tone":"governed","label":"échange"},
    {"from":"obo","to":"fn","step":1,"label":"preuve"},
    {"from":"fn","to":"storage","step":2,"tone":"governed","labelDy":26,"label":"jeton Storage"},
    {"from":"bob","to":"fn","step":3,"label":"même outil"},
    {"from":"app","to":"storage","step":4,"label":"accès applicatif"}
  ],
  "steps": [
    {"title": "Votre jeton s'arrête ici", "simple": "Alice appelle le serveur avec un jeton fait pour le serveur MCP seulement. Il ne va pas plus loin.", "say": "Un jeton par appel : le jeton MCP n'est jamais transmis à Graph ni à Storage (pas de token passthrough)."},
    {"title": "Échanger, pas transmettre", "simple": "Le serveur demande à Entra un nouveau jeton au nom d'Alice, et prouve son identité sans aucun secret.", "say": "On-Behalf-Of : le serveur envoie le jeton d'Alice et une assertion signée par son identité managée, grâce à une information d'identification fédérée."},
    {"title": "Lire en tant qu'Alice", "simple": "Avec le nouveau jeton, le serveur lit le rapport avec les droits d'Alice.", "say": "Storage vérifie le rôle d'Alice sur le conteneur `reports`. `whoami` suit le même chemin vers Microsoft Graph."},
    {"title": "Même outil, Bob est refusé", "simple": "Bob appelle le même outil, mais Storage le refuse : il n'y a aucun rôle.", "say": "MCP répond quand même HTTP 200, avec `isError: true` dans le résultat de l'outil. Un succès HTTP n'est pas un succès de l'outil."},
    {"title": "Ou lire en tant qu'application", "simple": "read_report_as_app utilise l'identité de l'application : Alice et Bob obtiennent le même résultat.", "say": "Accès applicatif : l'identité managée détient le rôle, l'appelant ne compte plus en aval. Ce choix se fait outil par outil, en connaissance de cause."}
  ]
}
```

![Architecture du niveau 3](../../assets/architecture/05.fr.svg)

**Preview :** aucun nouvel élément en Preview dans ce module. Les métadonnées de ressource protégée sur la Function (module 03) et l'API de serveur
MCP d'API Management `2025-09-01-preview` (module 04) restent en **Preview** si vous les utilisez.

**Coût :** deux identités managées et un conteneur ne coûtent rien en eux-mêmes ; les transactions Storage et les appels Graph
supplémentaires sont négligeables. La passerelle du module 04 reste facturée tant qu'elle existe.

**Pour examiner le code :** ouvrez [src/FunctionsMcpServer](../../src/FunctionsMcpServer), en particulier
`Logic/DelegatedTools.cs`, `Identity/DownstreamCredentials.cs` et `Logic/CallerContext.cs`.
Ces outils s'appuient sur `HelloToolWithAuth.cs` de l'exemple épinglé
(`Azure-Samples/remote-mcp-functions-dotnet`, commit `468c518c884ec318e3001b9573254c9e775409c9`, MIT).
Ils n'utilisent jamais par défaut la connexion personnelle du développeur si une authentification échoue.
L'assertion utilisateur provient de la requête validée
par l'authentification intégrée. Graph ne fournit que l'ID d'objet (`/me?$select=id`) et une identité managée
distincte porte les droits applicatifs.

## Prérequis et rôles nécessaires

- Modules 02 et 03 déployés (module 04 recommandé) avec les mêmes fichiers privés et le même état Terraform. Publiez le code du
  serveur issu de cette version du dépôt (elle contient le module 05) **avant** l'étape 2 du module 04, qui rend privés les points de
  déploiement.
- Les comptes de test existants Alice et Bob du module 03 (ID d'objet uniquement) ; Eve reste sans affectation.
- Terraform 1.16.6+, Azure CLI, PowerShell 7.4+. Exemple de région : `swedencentral`.

**Participant :** rôle Contributeur sur le groupe de ressources de l'atelier, ainsi que le droit de créer trois attributions de rôle limitées
au conteneur `reports` (par exemple Role Based Access Control Administrator, restreint à Storage Blob Data Reader et Contributor,
limité dans le temps).

**Administrateur des identités :** Application Administrator ou Cloud Application Administrator (ou propriétaire de l'application
de l'atelier) pour ajouter les informations d'identification fédérées et les autorisations demandées. Pour accorder le consentement administrateur
à l'échelle du tenant sur des autorisations déléguées, il faut le rôle Cloud Application Administrator ou Application Administrator. Voir la
[demande d'identité](../../docs/requests/identity-request.md).

## Étapes


### PowerShell

Exécutez les commandes depuis la racine du dépôt. Les étapes 2 à 5 modifient Azure ou Microsoft Entra : ne les exécutez qu'après approbation du plan.

**1. Vérifiez les fichiers hors ligne, sans accéder à Azure.**

```powershell
& .\modules\05-delegated-and-app-only\validate.ps1 -Offline
```

> **Résultat attendu** — d'après les messages du validateur ; cet exemple n'est pas une capture d'exécution. Le nombre de fichiers dépend de votre copie.
>
> ```text
> PASS server: On-Behalf-Of with a managed-identity assertion, one token per downstream (Graph User.Read, Storage user_impersonation), app-only identity for read_report_as_app, app-only callers refused, no developer-credential fallback, no token parsing (expected HTTP N/A).
> PASS infra/entra: federated credential (tenant v2.0 issuer, managed identity principal ID subject, api://AzureADTokenExchange), delegated Graph User.Read + Storage user_impersonation only, admin consent opt-in, no password or certificate (expected HTTP N/A).
> PASS infra/workload: separate OBO assertion and app-only identities, every module 05 role on the one report container, no role for the OBO or host identity, Bob none, opt-in only (expected HTTP N/A).
> PASS synthetic report and expected results are labelled synthetic and contain no address, ID or token (<n> files, expected HTTP N/A).
> PASS no client secret, key, SAS or token in module 05, server, infra/entra or infra/workload files (<n> files, expected HTTP N/A).
> PASS locked build and unit tests: Alice reads, Bob denied downstream, app-only identical for everyone, app-only callers refused, Graph gets only its own token (expected HTTP N/A).
> PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).
> NOT DEPLOYED CHECKS SKIPPED: supply -TenantId with -SubscriptionId (operator) or -Persona (test account) after an approved deployment.
> PASS offline checks only. Module 05 is NOT deployed or validated by this result.
> ```
>
> **Comment lire vos résultats :** ces tests vérifient la conception On-Behalf-Of sans secret
> et les rôles limités au conteneur. Leur réussite ne prouve pas que l'accès fonctionne dans Azure.
> Rien n'a été déployé par ces contrôles.

**2. Créer le fichier privé qui active les accès aux données (ignoré par Git).** Demandez les ID d'objet d'Alice et de Bob à
l'administrateur des identités (sortie `workload_module05_tfvars` de `infra/entra`).

Si vous gérez `infra/entra` vous-même, écrivez plutôt le fichier directement depuis sa sortie :
`terraform -chdir=infra/entra output -json workload_module05_tfvars | Set-Content -LiteralPath .\.workshop\module05.tfvars.json`.
Sinon, utilisez les commandes ci-dessous avec les deux ID d'objet que l'administrateur vous a envoyés.

```powershell
@{ enable_delegated_access = $true; delegated_persona_object_ids = @{ alice = '<alice-object-id>'; bob = '<bob-object-id>' } } |
    ConvertTo-Json | Set-Content -LiteralPath .\.workshop\module05.tfvars.json
```

> **Résultat attendu** — aucune sortie : `Set-Content` n'affiche rien quand il réussit.
> Vérifiez avec `Test-Path .\.workshop\module05.tfvars.json` (`True`). Le fichier ne contient que des ID d'objet, jamais de secret.

**3. Planifier les modifications des ressources Azure.** Sélectionnez d'abord votre contexte approuvé (`& .\scripts\select-azure-context.ps1`).
Passez tous les fichiers de variables déjà utilisés, ainsi que celui du module 05 (retirez `module04.tfvars.json` si vous n'avez pas
fait le module 04).

```powershell
$vars = '-var-file=..\..\.workshop\participant.tfvars.json', '-var-file=..\..\.workshop\module02.tfvars.json',
        '-var-file=..\..\.workshop\module03.tfvars.json', '-var-file=..\..\.workshop\module04.tfvars.json',
        '-var-file=..\..\.workshop\module05.tfvars.json'
terraform '-chdir=infra\workload' plan @vars '-out=..\..\.workshop\module05.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
```

> **Résultat réel** — résumé du plan sauvegardé, 2026-10-18, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> Plan: 6 to add, 3 to change, 0 to destroy.
> ```
>
> **Comment lire votre plan :** les six ajouts correspondent aux deux identités, au conteneur et aux trois attributions
> de rôle : lecture pour Alice et l'identité `-report`, publication pour l'opérateur. Bob et l'identité `-obo`
> ne reçoivent aucun rôle. Les **3** modifications de cet exemple comprennent la mise à jour de la Function App
> et la normalisation des espaces de deux stratégies azapi du module 04, sans changement fonctionnel.
> Sans module 04, attendez-vous à 1 modification. Si vous voyez `to destroy`, vérifiez les fichiers de variables
> et n'appliquez pas.

Avant d'approuver, retrouvez dans votre plan les deux identités, le conteneur, les trois attributions limitées
au conteneur et la mise à jour en place de la Function App. Rien n'est encore appliqué.
Vérifiez que les droits applicatifs appartiennent à `-report`, pas à `-obo`.

### Appliquer le plan des ressources Azure, seulement après accord

**STOP :** faites approuver exactement ce plan sauvegardé avant de lancer cette commande.

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\module05.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform apply failed.' }
```

> **Résultat réel** — extrait de l'apply, 2026-10-18, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> azapi_resource.prm_operation_policy[0]: Modifications complete after 2s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.ApiManagement/service/apim-mcp-p01-<suffix>/apis/workshop-mcp-prm/operations/get-mcp-metadata/policies/policy]
> azurerm_storage_container.reports[0]: Creation complete after 19s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.Storage/storageAccounts/stp01<suffix>/blobServices/default/containers/reports]
> azurerm_user_assigned_identity.delegated_obo[0]: Creation complete after 38s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-mcp-p01-<suffix>-obo]
> azurerm_user_assigned_identity.delegated_report[0]: Creation complete after 41s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-mcp-p01-<suffix>-report]
> azurerm_role_assignment.report_publisher[0]: Creation complete after 39s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.Storage/storageAccounts/stp01<suffix>/blobServices/default/containers/reports/providers/Microsoft.Authorization/roleAssignments/<guid>]
> azurerm_role_assignment.report_persona_reader["alice"]: Creation complete after 39s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.Storage/storageAccounts/stp01<suffix>/blobServices/default/containers/reports/providers/Microsoft.Authorization/roleAssignments/<guid>]
> azurerm_role_assignment.report_app_reader[0]: Creation complete after 42s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.Storage/storageAccounts/stp01<suffix>/blobServices/default/containers/reports/providers/Microsoft.Authorization/roleAssignments/<guid>]
> azurerm_function_app_flex_consumption.mcp[0]: Modifications complete after 43s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.Web/sites/func-mcp-p01-<suffix>]
> azapi_resource.mcp_api_policy[0]: Modifications complete after 0s [id=/subscriptions/<subscription-id>/resourceGroups/rg-mcp-p01-<suffix>/providers/Microsoft.ApiManagement/service/apim-mcp-p01-<suffix>/apis/workshop-mcp/policies/policy]
> Apply complete! Resources: 6 added, 3 changed, 0 destroyed.
> ```
>
> **Ce que cela signifie pour vous :** les identités, le conteneur et les rôles existent. Chaque attribution de rôle est
> limitée au seul conteneur `reports`. Les attributions de rôle peuvent mettre quelques minutes à prendre effet.

Après un `apply` réussi, les ressources approuvées existent. Les outils OBO ne peuvent pas encore fonctionner :
l'administrateur des identités doit d'abord configurer la relation de confiance.

### Lire uniquement la sortie dont l'administrateur a besoin

**Action :** transmettez cette référence en privé à l'administrateur, jamais dans l'interface partagée ni dans le dépôt.

```powershell
terraform '-chdir=infra\workload' output -json entra_module05_tfvars   # à envoyer à l'administrateur des identités
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the administrator handoff.' }
```

> **Résultat attendu** — format de la sortie Terraform ; la valeur affichée ici est fictive.
>
> ```text
> {
>   "enable_delegated_access": true,
>   "obo_identity_principal_id": "<obo-principal-id>"
> }
> ```
>
> **Comment utiliser cette sortie :** transmettez l'ID de principal à l'administrateur par le canal privé approuvé.
> Ce n'est pas un secret, mais il identifie la ressource qui doit être approuvée.
> Pour cette étape, l'administrateur n'a besoin d'aucune autre sortie de votre état Terraform.

Tant que l'étape 4 n'est pas terminée, `whoami` et `read_report_as_user` renvoient une erreur d'outil sans accéder aux données : l'API ne fait pas
encore confiance à l'identité.

**4. Administrateur des identités : informations d'identification fédérées, autorisations, consentement.** Dans son propre terminal, avec son propre état :

L'ID du principal s'affiche à la fin de l'étape 3. Vous pouvez le relire avec
`terraform -chdir=infra/workload output -raw delegated_obo_identity_principal_id` (terminal du participant) ; envoyez-le à l'administrateur.

```powershell
@{ enable_delegated_access = $true; obo_identity_principal_id = '<principal-id-from-step-3>'; grant_downstream_admin_consent = $true } |
    ConvertTo-Json | Set-Content -LiteralPath .\.workshop\entra-module05.tfvars.json
terraform '-chdir=infra\entra' plan '-var-file=..\..\.workshop\entra.tfvars.json' '-var-file=..\..\.workshop\entra-module05.tfvars.json' '-out=..\..\.workshop\entra05.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Entra plan failed.' }
```

> **Résultat réel** — résumé du plan sauvegardé par l'administrateur des identités, 2026-10-18, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> Plan: 5 to add, 0 to change, 0 to destroy.
> ```
>
> **Ce que cela signifie pour vous :** cinq ajouts, tous des objets du module 05, sans mot de passe ni certificat. Si le
> plan modifie des objets du module 03, vous avez passé les mauvais fichiers de variables : n'appliquez pas.

Avant d'appliquer, vérifiez que le plan propose deux accès aux API, une information d'identification fédérée
et deux consentements. À ce stade, aucun consentement n'est encore accordé.

### Administrateur des identités : approuver la confiance et le consentement

**STOP :** examinez les autorisations déléguées exactes et le plan sauvegardé. Seul l'administrateur des identités exécute cette commande, dans son propre contexte.

```powershell
terraform '-chdir=infra\entra' apply '..\..\.workshop\entra05.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Entra apply failed.' }
```

> **Résultat réel** — extrait de l'apply, 2026-10-18, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> azuread_service_principal_delegated_permission_grant.downstream["graph"]: Creation complete after 3s [id=/oauth2PermissionGrants/<grant-id>]
> azuread_service_principal_delegated_permission_grant.downstream["storage"]: Creation complete after 3s [id=/oauth2PermissionGrants/<grant-id>]
> azuread_application_federated_identity_credential.obo[0]: Creation complete after 8s [id=<guid>/federatedIdentityCredential/<guid>]
> azuread_application_api_access.downstream["storage"]: Creation complete after 11s [id=/applications/<guid>/apiAccess/<guid>]
> azuread_application_api_access.downstream["graph"]: Creation complete after 12s [id=/applications/<guid>/apiAccess/<guid>]
> Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
> ```
>
> **Ce que cela signifie pour vous :** l'API MCP fait désormais confiance à l'identité `-obo` et dispose du consentement pour
> exactement deux scopes délégués. `whoami` et `read_report_as_user` peuvent maintenant échanger des jetons.

Vérifiez-le dans le centre d'administration Microsoft Entra (captures réelles, 2026-10-19, tenant de test de l'auteur ;
noms pseudonymisés, ID remplacés par des zéros ; portail affiché en anglais). Les cadres roses signalent les points à vérifier. Sélectionnez une image pour l'ouvrir en grand.

**App registrations → Workshop MCP API → API permissions.** Exactement deux autorisations déléguées : Azure Storage
`user_impersonation` (pour `read_report_as_user`) et Microsoft Graph `User.Read` (pour `whoami`). Aucune autorisation d'application.

![Capture réelle : page API permissions avec deux autorisations déléguées, Azure Storage user_impersonation et Microsoft Graph User.Read](../../assets/screenshots/azure-05-api-permissions.png)

**Même application → Certificates & secrets.** Certificates (0), Client secrets (0), Federated credentials (1) : l'échange
OBO prouve l'identité de l'API avec l'identité managée `-obo`, jamais avec un mot de passe.

![Capture réelle : page Certificates and secrets avec zéro certificat, zéro secret client et une information d'identification fédérée workshop-obo-p01](../../assets/screenshots/azure-05-federated-credentials.png)

**Question :** la documentation générale d'On-Behalf-Of montre un secret client. Où est-il ici ?

<details>
<summary>Afficher la réponse</summary>

Il n'y en a pas : la capture affiche Client secrets (0). Grâce à l'information d'identification fédérée,
l'API utilise une assertion obtenue avec l'identité managée `-obo` pour s'authentifier pendant l'échange.
Vous n'avez donc aucun secret client à conserver, à renouveler ou à enregistrer dans Git.

</details>

**5. Publier le rapport synthétique** (authentification Microsoft Entra, sans clé ; le script réessaie pendant la propagation du rôle) :

```powershell
& .\modules\05-delegated-and-app-only\publish-report.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

> **Résultat attendu** — d'après les messages du script ; pas encore capturé. La ligne `INFO` n'apparaît que pendant la propagation de votre rôle.
>
> ```text
> PASS explicit Azure context (expected HTTP 200 from Azure Resource Manager).
> INFO upload attempt 1 refused; the Storage Blob Data Contributor role may still be propagating. Retrying in <n> s.
> PASS synthetic report published as reports/monthly-usage.json with Microsoft Entra authentication, no key or SAS (expected HTTP 201).
> ```
>
> **Ce que cela signifie pour vous :** le rapport synthétique est dans le conteneur privé, déposé avec votre identité Entra, sans clé.

> [!NOTE]
> Si vous avez activé `mcp_private_storage = true` au module 02, l'accès réseau public du compte de stockage est désactivé et ce
> téléversement échoue depuis l'extérieur du réseau virtuel. Publiez alors le rapport **depuis** le réseau virtuel ;
> n'activez jamais l'accès public ni les clés partagées. Ajoutez
> `-InsideVirtualNetwork -SubnetPrefix <un /28 libre de votre réseau virtuel>`. Le script crée une Azure Container Instance
> de courte durée dans un sous-réseau temporaire, avec une identité managée temporaire qui détient Storage Blob Data
> Contributor sur le seul conteneur `reports`. Il dépose le rapport, puis supprime le tout. Résultat réel, 2026-10-20 :
> `PASS synthetic report published as reports/monthly-usage.json from inside the virtual network, with a managed identity,
> no key or SAS (expected HTTP 201).`

**6. Essayer dans VS Code.** Avec le serveur `workshop-governed` du module 04, connecté en tant qu'Alice, collez ce prompt
dans Copilot Chat (mode **Agent**). Recommencez en tant que Bob dans un autre profil VS Code et comparez.

```prompt
Utilise le serveur MCP workshop-governed. Appelle whoami. Appelle ensuite read_report_as_user avec report "monthly-usage", puis read_report_as_app avec report "monthly-usage". Pour chaque appel, montre le résultat de l'outil et indique si isError vaut true.
```

Alice obtient deux rapports identiques. Bob obtient `isError: true` pour `read_report_as_user`, et le même rapport qu'Alice
pour `read_report_as_app`.

<details>
<summary>Comment faire dans VS Code, clic par clic</summary>

1. En tant qu'Alice, gardez le serveur `workshop-governed` du module 04 et démarrez-le si besoin : **Ctrl+Maj+P**,
   **MCP: List Servers**, `workshop-governed`, **Start Server**.
2. Ouvrez le Chat avec **Ctrl+Alt+I**, choisissez **Agent**, ne gardez que les outils de `workshop-governed`, collez le
   prompt et sélectionnez **Allow** une seule fois pour chaque appel d'outil.
3. Pour Bob, lancez **Profiles: New Profile...**, nommez-le `Bob` et ouvrez-le. Dans cette fenêtre, ajoutez le même serveur
   avec **MCP: Open User Configuration**, démarrez-le, connectez-vous en tant que Bob, puis refaites l'étape 2.

</details>

**7. Lancez les vérifications avec votre compte habituel de déploiement, puis avec Alice et Bob.**

Le script appelle le premier mode « opérateur » : il vérifie la configuration.
Le mode « persona » vérifie ensuite les accès d'un compte de test.

```powershell
& .\modules\05-delegated-and-app-only\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
foreach ($persona in 'Alice', 'Bob') {
    $env:AZURE_CONFIG_DIR = Join-Path $PWD ".workshop\az-$($persona.ToLower())"
    az login --tenant $env:ARM_TENANT_ID --allow-no-subscriptions   # se connecter en tant que $persona dans le navigateur
    & .\modules\05-delegated-and-app-only\validate.ps1 -TenantId $env:ARM_TENANT_ID -Persona $persona
    az logout
}
Remove-Item Env:\AZURE_CONFIG_DIR
```

> **Résultat réel** — vérifications opérateur (la première commande), 2026-10-18, tenant de test de l'auteur. Noms et ID masqués.
>
> ```text
> PASS server: On-Behalf-Of with a managed-identity assertion, one token per downstream (Graph User.Read, Storage user_impersonation), app-only identity for read_report_as_app, app-only callers refused, no developer-credential fallback, no token parsing (expected HTTP N/A).
> PASS infra/entra: federated credential (tenant v2.0 issuer, managed identity principal ID subject, api://AzureADTokenExchange), delegated Graph User.Read + Storage user_impersonation only, admin consent opt-in, no password or certificate (expected HTTP N/A).
> PASS infra/workload: separate OBO assertion and app-only identities, every module 05 role on the one report container, no role for the OBO or host identity, Bob none, opt-in only (expected HTTP N/A).
> PASS synthetic report and expected results are labelled synthetic and contain no address, ID or token (2 files, expected HTTP N/A).
> PASS no client secret, key, SAS or token in module 05, server, infra/entra or infra/workload files (47 files, expected HTTP N/A).
> PASS explicit Azure context matches the approved test target (expected HTTP 200 from Azure Resource Manager).
> PASS Function App settings name both module 05 identities and hold no secret setting (expected HTTP 200 from Azure Resource Manager).
> PASS MCP API registration: no client secret, exactly one federated credential trusting the OBO managed identity (expected HTTP 200 from Microsoft Graph).
> PASS report container: 2 Storage Blob Data Reader assignment(s) (app-only identity, Alice), none for the OBO identity or Bob (expected HTTP 200 from Azure Resource Manager).
> INFO persona checks skipped. Sign in as each test account in a separate AZURE_CONFIG_DIR and rerun with -Persona Alice, then -Persona Bob.
> PASS module 05 operator checks complete. Persona checks are still required for validation.
> ```
>
> **Ce que cela signifie pour vous :** la confiance est en place sans aucun secret : une seule information d'identification
> fédérée, deux identités distinctes, et des rôles de lecteur sur l'unique conteneur pour l'identité applicative et pour
> Alice seulement. Le nombre de fichiers dépend de votre copie.

> **Résultat réel** — tests avec Alice et Bob, 2026-10-20, tenant de test de l'auteur ; Alice et Bob sont chacun
> connectés dans leur propre profil Azure CLI. Noms et ID masqués (extrait).
>
> ```text
> PASS Alice whoami: On-Behalf-Of to Microsoft Graph returns the synthetic persona 'alice' and no name or email (expected HTTP 200).
> PASS Alice read_report_as_user returns the synthetic report with her own Storage role (expected HTTP 200, isError false).
> PASS Bob whoami: On-Behalf-Of to Microsoft Graph returns the synthetic persona 'bob' and no name or email (expected HTTP 200).
> PASS Bob read_report_as_user: the MCP call succeeds but the tool result is an error, because Storage refuses Bob downstream (expected HTTP 200, isError true, downstream HTTP 403).
> PASS read_report_as_app returned the same result for Alice and Bob: the managed identity, not the caller, carries the rights (expected HTTP 200).
> ```
>
> **Comment lire vos résultats :** pour une même demande **avec On-Behalf-Of**, les droits de l'utilisateur sur les données
> déterminent le résultat. Avec l'identité de l'application, tous les appelants autorisés à utiliser l'outil obtiennent
> la même réponse : ce sont les droits **de l'application** qui décident. L'erreur d'outil dans la réponse HTTP 200 de Bob
> est attendue : la passerelle l'a laissé appeler l'outil, puis Storage **lui** a refusé l'accès.
> Le choix de l'identité doit être fixé pour chaque outil
> ([OBO expliqué simplement](../../docs/fr/MCP-CONCEPTS.md)).

![Résultat réel avec Bob : cadre 1, whoami par On-Behalf-Of ; cadre 2, refus de Storage dans une réponse MCP HTTP 200 ; cadre 3, rapport lu avec l'identité de l'application](../../assets/screenshots/terminal-05-bob.png)

### Bash

Suivez le même ordre qu'en PowerShell et arrêtez-vous pour faire approuver chaque plan avant son application.
L'administrateur exécute les commandes `infra/entra` dans son propre terminal, avec son propre état.
Si le stockage est privé, utilisez la publication depuis le réseau virtuel décrite à l'étape 5 ;
le bloc ci-dessous ne lève pas cette exigence.

```bash
bash ./modules/05-delegated-and-app-only/validate.sh -Offline
printf '%s\n' '{"enable_delegated_access": true, "delegated_persona_object_ids": {"alice": "<alice-object-id>", "bob": "<bob-object-id>"}}' > .workshop/module05.tfvars.json
source ./scripts/select-azure-context.sh
vars="-var-file=../../.workshop/participant.tfvars.json -var-file=../../.workshop/module02.tfvars.json -var-file=../../.workshop/module03.tfvars.json -var-file=../../.workshop/module04.tfvars.json -var-file=../../.workshop/module05.tfvars.json"
terraform -chdir=infra/workload plan $vars -out=../../.workshop/module05.tfplan      # relire, approuver
terraform -chdir=infra/workload apply ../../.workshop/module05.tfplan
terraform -chdir=infra/workload output -json entra_module05_tfvars                    # pour l'administrateur des identités
# administrateur des identités, son terminal et son état :
printf '%s\n' '{"enable_delegated_access": true, "obo_identity_principal_id": "<principal-id>", "grant_downstream_admin_consent": true}' > .workshop/entra-module05.tfvars.json
terraform -chdir=infra/entra plan -var-file=../../.workshop/entra.tfvars.json -var-file=../../.workshop/entra-module05.tfvars.json -out=../../.workshop/entra05.tfplan
terraform -chdir=infra/entra apply ../../.workshop/entra05.tfplan
# de nouveau le participant :
bash ./modules/05-delegated-and-app-only/publish-report.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
bash ./modules/05-delegated-and-app-only/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
for persona in Alice Bob; do
  export AZURE_CONFIG_DIR="$PWD/.workshop/az-${persona,,}"
  az login --tenant "$ARM_TENANT_ID" --allow-no-subscriptions
  bash ./modules/05-delegated-and-app-only/validate.sh -TenantId "$ARM_TENANT_ID" -Persona "$persona"
  az logout
done
unset AZURE_CONFIG_DIR
```

> **Résultat attendu** — les mêmes résumés Terraform et lignes PASS/FAIL que les étapes PowerShell ci-dessus.

## Ce que vous devez voir

Même demande, deux comptes de test. Lisez d'abord le statut HTTP reçu par le client, puis le résultat de l'outil MCP
([exemples synthétiques](synthetic-data/expected-tool-results.json)).

| Compte de test | Outil | Statut HTTP reçu par le client | Résultat de l'outil | Pourquoi |
|---|---|---|---|---|
| Alice | `whoami` | HTTP 200 | `isError: false`, `persona: "alice"` | Jeton OBO pour Graph `User.Read` ; seul l'ID d'objet est lu puis associé à une étiquette |
| Bob | `whoami` | HTTP 200 | `isError: false`, `persona: "bob"` | Même flux, avec le jeton de Bob |
| Alice | `read_report_as_user` | HTTP 200 | `isError: false`, les deux lignes synthétiques | Jeton OBO pour Storage ; Alice a Storage Blob Data Reader sur `reports` |
| Bob | `read_report_as_user` | **HTTP 200** | **`isError: true`** | Jeton OBO pour Storage ; Bob n'a aucun rôle, Storage répond **HTTP 403** en aval |
| Alice | `read_report_as_app` | HTTP 200 | `isError: false`, les deux lignes synthétiques | L'identité managée `-report` lit le conteneur |
| Bob | `read_report_as_app` | HTTP 200 | `isError: false`, lignes **identiques** | Même identité et mêmes droits en aval ; l'autorisation d'appeler l'outil reste obligatoire |
| Toute application agissant sans utilisateur | `whoami` / `read_report_as_user` | HTTP 200 (ou 403 à la passerelle) | `isError: true` | OBO est réservé aux utilisateurs ; refus avant tout appel en aval |

Les journaux du serveur contiennent une ligne par appel : nom de l'outil, ID d'objet de l'appelant, statut (`success`,
`denied-downstream:403`, `rejected-caller`), latence et ID d'invocation. Ils ne contiennent jamais les arguments, le rapport, un nom ni un jeton.

**Question :** pourquoi `read_report_as_app` donne-t-il le même résultat à Alice et à Bob, alors que `read_report_as_user` non ?

<details>
<summary>Afficher la réponse</summary>

`read_report_as_app` n'utilise jamais l'identité de l'appelant en aval. Il lit Storage avec l'identité managée `-report`, qui
détient Storage Blob Data Reader sur le conteneur : tout appelant admis par la passerelle obtient les mêmes lignes.
`read_report_as_user` utilise On-Behalf-Of : Storage vérifie alors le rôle propre de l'utilisateur. Alice en a un, Bob non. C'est
pourquoi, en mode application, il faut régler l'autorisation avec soin, outil par outil (risque de « confused deputy »).

</details>

**Question :** `read_report_as_user` renvoie HTTP 200 à Bob. A-t-il lu le rapport ?

<details>
<summary>Afficher la réponse</summary>

Non. HTTP 200 est la réponse MCP externe : la passerelle l'a autorisé à appeler l'outil et l'outil s'est exécuté. Le résultat de
l'outil contient `isError: true`, car Storage a refusé le jeton OBO de Bob avec HTTP 403. Lisez toujours le résultat de l'outil,
pas seulement le statut HTTP.

</details>

### Comprendre les résultats avec la documentation

Suivez l'identité utilisée pour chaque appel, pas seulement le statut HTTP externe. Le choix est fixé pour chaque outil ;
après un refus en mode délégué, l'outil ne bascule pas vers une identité applicative.

| Résultat observé ou choix technique | Ce qu'il faut comprendre dans Microsoft Learn | Référence API ou SDK |
|---|---|---|
| Alice et Bob appellent `whoami` | [On-Behalf-Of (OBO)](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow) échange le jeton utilisateur MCP contre un jeton Graph distinct. | [Graph GET /me](https://learn.microsoft.com/graph/api/user-get?view=graph-rest-1.0) avec `User.Read` et `$select=id` ; [OnBehalfOfCredential](https://learn.microsoft.com/dotnet/api/azure.identity.onbehalfofcredential). Le serveur associe l'ID à un persona fictif, pas à un vrai profil. |
| Alice lit en mode utilisateur ; Bob est refusé | [Autoriser Blob Storage avec Entra](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory) : Storage contrôle le rôle de l'appelant sur la ressource, pas seulement le scope MCP. | [Autorisation de Get Blob](https://learn.microsoft.com/rest/api/storageservices/get-blob#authorization) et [DownloadContentAsync](https://learn.microsoft.com/dotnet/api/azure.storage.blobs.specialized.blobbaseclient.downloadcontentasync), hérité par `BlobClient`. Le HTTP 403 renvoyé en aval à Bob devient une erreur d'outil MCP dans une réponse HTTP 200 externe. |
| Alice et Bob lisent le même rapport en mode application | [Identités managées](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) : les droits en aval appartiennent à l'identité de l'application. Le contrôle d'accès de l'appelant MCP reste appliqué. | [ManagedIdentityCredential](https://learn.microsoft.com/dotnet/api/azure.identity.managedidentitycredential), puis la même [API Get Blob](https://learn.microsoft.com/rest/api/storageservices/get-blob#authorization) avec le rôle de l'identité managée limité au conteneur. |
| Aucun secret client, y compris pour OBO | [Faire approuver une identité managée par une application](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity) : les informations d'identification fédérées prouvent l'identité de l'application API lors de l'échange de jeton. | La surcharge avec fonction de rappel d'[OnBehalfOfCredential](https://learn.microsoft.com/dotnet/api/azure.identity.onbehalfofcredential) fournit une assertion d'identité managée. Ne recopiez pas les exemples à secret client de la documentation OBO générale. |
| Un appelant applicatif tente `whoami` ou `read_report_as_user` | [Flux OBO](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow) : la délégation nécessite une assertion utilisateur. | Le serveur refuse l'appel avant de contacter Graph ou Storage ; aucun basculement silencieux vers [ManagedIdentityCredential](https://learn.microsoft.com/dotnet/api/azure.identity.managedidentitycredential). |

Les données du rapport sont fictives, mais l'autorisation déployée, elle, n'est pas simulée. À l'inverse, les clients simulés des
tests hors ligne ne prouvent pas l'autorisation Azure. Vous devez exécuter les contrôles avec Alice et Bob pour constater les différences attendues.
Liens documentaires vérifiés le 2026-10-16.

### Vérifier vous-même avec Azure CLI

**Pourquoi :** l'identité utilisée pour l'échange On-Behalf-Of (OBO) et celle qui lit le rapport en mode applicatif
ont des fonctions différentes. Elles doivent rester distinctes.
Dans PowerShell 7, à la racine du dépôt, lisez les noms du déploiement :

```powershell
$ErrorActionPreference = 'Stop'
$inspectGroup = terraform '-chdir=infra\workload' output -raw resource_group_name
if ($LASTEXITCODE -ne 0) { throw 'Groupe de ressources indisponible.' }
$inspectNames = terraform '-chdir=infra\workload' output -json resource_names | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Noms des ressources indisponibles.' }
```

> **Résultat attendu** — aucune sortie : les variables reçoivent les noms de votre déploiement. Vérifiez avec `$inspectNames`.

Copiez les deux lectures suivantes. Elles ne demandent aucun jeton MCP et ne lisent pas le rapport :

```powershell
az identity show -g $inspectGroup -n $inspectNames.obo_identity --query '{name:name,type:type}' -o json
if ($LASTEXITCODE -ne 0) { throw 'Identité OBO introuvable.' }
az identity show -g $inspectGroup -n $inspectNames.report_identity --query '{name:name,type:type}' -o json
if ($LASTEXITCODE -ne 0) { throw 'Identité applicative du rapport introuvable.' }
```

> **Résultat attendu** — deux identités managées de type `Microsoft.ManagedIdentity/userAssignedIdentities`,
> avec des noms qui se terminent respectivement par `-obo` et `-report`.

![Résultat réel Azure CLI : deux identités managées distinctes, OBO et rapport applicatif](../../assets/screenshots/terminal-05-az-identities.png)

*Capture en lecture seule du 20 octobre 2026 ; les noms sont masqués.
Elle confirme l'existence des identités, pas leurs droits effectifs. Le validateur doit aussi vérifier la fédération
et les attributions sur le conteneur ; les essais Alice/Bob montrent ensuite les droits réellement utilisés.
Si une identité manque, reprenez le déploiement prévu, sans donner à l'identité OBO les droits de lecture du rapport.*

## Valider

> **Note de validation :** les sorties réelles présentées ici proviennent du tenant de test de l'auteur,
> aux dates indiquées. Elles ne valident pas votre propre environnement. Les sorties « attendues »
> et les tests hors ligne ne prouvent aucun accès réel. Après le déploiement approuvé, exécutez les contrôles
> opérateur, puis ceux d'Alice et de Bob, y compris la comparaison des rapports.

`validate.ps1` (ou `validate.sh`) exécute toujours d'abord les vérifications hors ligne : On-Behalf-Of avec une assertion
d'identité managée et un jeton par ressource en aval ; refus des applications agissant sans utilisateur pour les outils OBO ; pas de repli sur l'identité du
développeur ni d'analyse de jeton dans le serveur ; informations d'identification fédérées Entra et scopes délégués exacts, consentement
activé explicitement, sans mot de passe ; tous les rôles du module 05 sur le seul conteneur du rapport, aucun pour l'identité OBO
ni pour Bob ; données synthétiques uniquement ; aucun motif de secret ; tests unitaires ; formatage, schéma et tests simulés Terraform
pour les deux modules racines.

Sortie hors ligne (ce résultat **n'est pas** une preuve de déploiement) :

```text
PASS server: On-Behalf-Of with a managed-identity assertion, one token per downstream (Graph User.Read, Storage user_impersonation), app-only identity for read_report_as_app, app-only callers refused, no developer-credential fallback, no token parsing (expected HTTP N/A).
PASS infra/entra: federated credential (tenant v2.0 issuer, managed identity principal ID subject, api://AzureADTokenExchange), delegated Graph User.Read + Storage user_impersonation only, admin consent opt-in, no password or certificate (expected HTTP N/A).
PASS infra/workload: separate OBO assertion and app-only identities, every module 05 role on the one report container, no role for the OBO or host identity, Bob none, opt-in only (expected HTTP N/A).
PASS synthetic report and expected results are labelled synthetic and contain no address, ID or token (2 files, expected HTTP N/A).
PASS no client secret, key, SAS or token in module 05, server, infra/entra or infra/workload files (46 files, expected HTTP N/A).
PASS locked build and unit tests: Alice reads, Bob denied downstream, app-only identical for everyone, app-only callers refused, Graph gets only its own token (expected HTTP N/A).
PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).
PASS offline checks only. Module 05 is NOT deployed or validated by this result.
```

### Vérifier les accès réels, délégués et applicatifs

En mode réel, après un déploiement approuvé :

- **Opérateur** (`-TenantId -SubscriptionId`) : les paramètres de la Function référencent les deux identités et ne contiennent aucun
  paramètre secret ; l'inscription de l'API MCP n'a **aucun secret client** et possède une seule information d'identification fédérée, qui
  établit la confiance avec l'identité OBO ; sur le conteneur `reports`, seules l'identité applicative et Alice ont Storage Blob Data
  Reader ; l'identité OBO et Bob n'ont rien.
- **Compte de test** (`-TenantId -Persona Alice|Bob`) : `whoami` renvoie le libellé du compte de test, sans nom ni adresse e-mail ;
  `read_report_as_user` d'Alice renvoie le rapport (HTTP 200, `isError: false`) ; celui de Bob renvoie **HTTP 200 avec
  `isError: true`** ; `read_report_as_app` renvoie les mêmes lignes synthétiques aux deux (le second passage compare une empreinte
  enregistrée par le premier, dans `.workshop/`).

Pour valider le module, faites réussir tous ces contrôles dans votre abonnement de test, à la suite des modules précédents.
Le statut de référence `validated` exige une exécution complète sur un abonnement neuf, après les modules 00 à 04.

**Question :** un contrôle hors ligne refuse tout « repli sur les identifiants du développeur » dans le serveur. Que pourrait-il se passer sans lui ?

<details>
<summary>Afficher la réponse</summary>

Sur un poste, des identifiants par défaut peuvent utiliser en silence **votre propre** connexion Azure CLI. Le serveur lirait
alors Storage avec vos droits, et non ceux de l'appelant (On-Behalf-Of) ou de l'application (identité managée). Une
configuration incorrecte aurait l'air de fonctionner. Le contrôle oblige le serveur à signaler l'erreur.

</details>


## Dépannage

| Symptôme | Vérification |
|---|---|
| `whoami` / `read_report_as_user` renvoient `isError: true`, même pour Alice | Étape 4 non effectuée (ni informations d'identification fédérées ni consentement), ou le sujet n'est pas l'ID de **principal** de l'identité `-obo`. Entra accepte un émetteur, un sujet ou une audience erronés à la création ; l'erreur n'apparaît qu'à l'échange de jeton. |
| Idem, et le journal du serveur indique `failed:AuthenticationFailedException` | L'échange de jeton a échoué. Vérifiez dans l'ordre : les valeurs des informations d'identification fédérées, le consentement administrateur (`grant_downstream_admin_consent = true` ou le portail), et que l'identité `-obo` est attachée à la Function. Le serveur ne journalise jamais le texte d'erreur d'Entra. |
| Alice obtient `isError: true` seulement sur `read_report_as_user` | Son rôle Storage est encore en cours de propagation (quelques minutes), ou `delegated_persona_object_ids.alice` est faux. |
| `read_report_as_app` renvoie `isError: true` | Rapport non publié (étape 5), ou rôle de l'identité `-report` encore en propagation. |
| `publish-report.ps1` échoue systématiquement | Vous avez besoin du rôle Storage Blob Data Contributor sur `reports` ; renseignez `delegated_report_publisher_object_id` si Terraform a été exécuté par quelqu'un d'autre. |
| `publish-report.ps1` échoue alors que vous avez le rôle, et vous avez activé `mcp_private_storage = true` au module 02 | L'accès réseau public du compte de stockage est désactivé : un dépôt depuis l'extérieur du réseau virtuel est refusé. Relancez le script avec `-InsideVirtualNetwork -SubnetPrefix <un /28 libre>` : il dépose le rapport depuis une Azure Container Instance de courte durée, avec une identité managée temporaire qui détient Storage Blob Data Contributor sur le seul conteneur `reports`, puis les supprime. N'activez jamais l'accès public ni les clés partagées. |
| `Invalid index` sur `oauth2_permission_scope_ids` dans `infra/entra` | Le principal de service Azure Storage est absent du tenant ; un administrateur doit le créer (`az ad sp create --id e406a681-f3d4-42a8-90b6-c2b029497af1`). |
| Les outils renvoient encore des résultats de « démonstration » | Le code déployé est antérieur au module 05, ou `WORKSHOP_DELEGATED_ACCESS` ne vaut pas `enabled`. Publiez le code (avant l'étape 2 du module 04). |
| HTTP 403 de la passerelle pour chaque appel | Le refus vient du module 04 (rôle ou scope). Un refus en aval n'est jamais un HTTP 403 externe. |

## Nettoyer

Si vous poursuivez immédiatement avec le module 06, conservez les ressources. Sinon, lancez le script une première fois
pour relire le plan, puis avec `-Apply` après accord. Il refuse toute modification hors du module 05.
Vous pouvez le relancer : une phase déjà terminée ne supprime rien de plus.

```powershell
# Participant : identités, conteneur (et rapport), attributions de rôle, paramètres
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
Remove-Item -LiteralPath .\.workshop\module05.tfvars.json, .\.workshop\module05-as-app-*.sha256 -ErrorAction SilentlyContinue
# Administrateur des identités : informations d'identification fédérées, autorisations demandées, consentements
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -Scope Entra -Apply
Remove-Item -LiteralPath .\.workshop\entra-module05.tfvars.json -ErrorAction SilentlyContinue
```

> **Résultat attendu** — d'après les messages du script de nettoyage (extrait). Premier rapport sur les ressources Azure, sans `-Apply` :
>
> ```text
> PASS explicit Azure context and private participant parameters (expected HTTP 200 from Azure Resource Manager).
> PLAN delete azurerm_role_assignment.report_app_reader[0] (remove module 05 workload resources)
> PLAN delete azurerm_role_assignment.report_persona_reader["alice"] (remove module 05 workload resources)
> PLAN delete azurerm_storage_container.reports[0] (remove module 05 workload resources)
> ...
> PASS 'remove module 05 workload resources' plan changes only 6 module 05 object(s). Review it, then rerun with -Apply.
> ```
>
> Avec `-Apply`, puis `-Scope Entra -Apply` par l'administrateur des identités :
>
> ```text
> Apply complete! Resources: 0 added, 1 changed, 6 destroyed.
> PASS 'remove module 05 workload resources' applied (expected HTTP 200).
> PASS whoami and read_report_* are back to the module 02 demonstrations. Remove .workshop/module05.tfvars.json. The identity administrator runs -Scope Entra next.
> PASS explicit tenant and interactive identity administrator sign-in (expected HTTP 200 from Microsoft Graph).
> PLAN delete azuread_application_federated_identity_credential.obo[0] (remove module 05 Entra delegation)
> ...
> Apply complete! Resources: 0 added, 0 changed, 5 destroyed.
> PASS 'remove module 05 Entra delegation' applied (expected HTTP 200).
> PASS the MCP API no longer trusts the workload identity or requests downstream permissions. Module 03 objects stay; use modules/03-entra-authentication/cleanup.ps1 -Scope Entra next if you continue.
> ```
>
> `Remove-Item` n'affiche rien.
>
> **Ce que cela signifie pour vous :** si vous relancez le script, il affiche `nothing to do in this state`. Une ligne
> `FAIL ... outside module 05` signifie que le plan toucherait d'autres modules : rien n'a été appliqué.

```bash
bash ./modules/05-delegated-and-app-only/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -Apply
bash ./modules/05-delegated-and-app-only/cleanup.sh -TenantId "$ARM_TENANT_ID" -Scope Entra -Apply
rm -f .workshop/module05.tfvars.json .workshop/module05-as-app-*.sha256 .workshop/entra-module05.tfvars.json
```

> **Résultat attendu** — les mêmes lignes PASS/PLAN que les exécutions PowerShell avec `-Apply` ci-dessus ; `rm` n'affiche rien.

Lancez le nettoyage Entra **avant** celui du module 03, qui n'accepte que les objets du module 03. Les modules 02 à 04 restent en place.
Si vous passez directement au module 06, conservez tout.

## Aller plus loin

- Lisez [DelegatedTools.cs](../../src/FunctionsMcpServer/Logic/DelegatedTools.cs) : où se fait le choix de l'identité pour chaque
  outil, et pourquoi ce choix ne peut-il jamais changer à l'exécution ?
- Pourquoi l'identité OBO n'a-t-elle aucun rôle Azure, et que se passerait-il si `read_report_as_app` l'utilisait ?
- Attribuez à Bob le rôle Storage Blob Data Reader sur `reports` pendant quelques minutes : quel résultat change, et lequel ne change jamais ?
- Microsoft.Identity.Web propose le même modèle sans secret pour les API ASP.NET Core (`SignedAssertionFromManagedIdentity`) ; ce
  module utilise Azure.Identity, car l'authentification intégrée valide déjà le jeton.

### Bon à savoir : OBO sur plusieurs sauts, et RBAC

**On-Behalf-Of (OBO) peut-il traverser trois sauts ?** Oui. Microsoft Entra ID n'impose pas de limite fixe : OBO est conçu
pour transmettre l'identité de l'utilisateur « tout au long de la chaîne de requêtes ». Mais chaque saut change ce que voit
le service suivant. Plus la chaîne est longue, plus son fonctionnement est difficile à diagnostiquer et à auditer.

![On-Behalf-Of sur trois sauts : l'utilisateur Alice est conservé, mais chaque saut émet un nouveau jeton pour l'audience suivante et le client devient l'API précédente ; règles à chaque saut : pas de relais, consentement préalable, MFA renvoyée, utilisateurs seulement](../../assets/screenshots/diagram-05-obo-hops-fr.png)

<details>
<summary>Version texte : ce que chaque saut conserve, et ce qu'il perd</summary>

| | Conservé | Modifié ou perdu |
|---|---|---|
| Jeton | — | Un **nouveau** jeton à chaque saut. Un service ne peut échanger qu'un jeton émis **pour lui-même** (`aud`) ; il ne réutilise ni ne transmet jamais celui qu'il a reçu. |
| Utilisateur | L'utilisateur (`oid`) et ses scopes délégués | — |
| Application appelante | — | `azp` (`appid` dans les jetons v1.0) désigne l'application qui a fait le dernier échange. Au 3ᵉ saut, l'API C voit l'API B, **pas** VS Code. Journalisez le client d'origine dès le premier saut si vous en avez besoin. |
| Droits | Les scopes délégués qui ont été consentis | Les rôles d'application restent attachés à l'utilisateur, **jamais** à l'application qui agit pour lui : un service intermédiaire ne peut pas ajouter ses propres droits à ceux de l'utilisateur. |
| Consentement | — | Les services intermédiaires ne peuvent pas afficher d'écran de consentement. Le consentement doit exister **à l'avance** pour chaque saut (ici, consentement administrateur). |
| Authentification multifacteur (MFA) et accès conditionnel | — | Si une API en aval exige la MFA, le point de terminaison de jeton renvoie un « claims challenge » (demande de revendications supplémentaires). **Chaque** service intermédiaire doit le renvoyer au client (HTTP 401 avec `WWW-Authenticate`). Si un seul service ne le transmet pas, le client ne peut pas satisfaire cette demande. |
| Appelant applicatif | — | OBO ne fonctionne que pour des **utilisateurs**. Un jeton applicatif ne peut pas être échangé : utilisez alors l'identité propre de l'application (client credentials ou identité managée). |

</details>

Dans cet atelier, la chaîne reste volontairement courte : un seul saut OBO, du serveur MCP vers Graph ou Storage.

**Le RBAC Azure (contrôle d'accès en fonction du rôle) est un contrôle à part, distinct des scopes et des rôles d'application.**

![Trois contrôles différents : scope (dans le jeton, scp), rôle d'application (dans le jeton, roles, appliqué par la passerelle) et rôle Azure (pas dans le jeton, appliqué par Storage à chaque appel)](../../assets/screenshots/diagram-05-rbac-checks-fr.png)

En détail :

- `user_impersonation` (un scope) indique que l'API MCP **peut agir pour** Alice. Storage Blob Data Reader (un rôle Azure)
  indique qu'Alice **peut lire** ce conteneur. Storage vérifie le rôle de l'utilisateur : Bob est donc refusé, même avec un
  jeton valide.
- Les rôles d'application (`Tools.Read`, `Tools.Write`) sont définis dans Microsoft Entra ID et figurent dans la revendication
  `roles` du jeton. Les rôles Azure, eux, sont vérifiés par la ressource Azure elle-même : ils n'apparaissent jamais dans le jeton.
  - Ajouter ou retirer une attribution de rôle Azure peut prendre **jusqu'à 10 minutes**. Pour une identité managée, un
  changement d'appartenance à un groupe ou à un rôle peut prendre **plusieurs heures**. C'est pourquoi `publish-report.ps1`
  réessaie, et pourquoi le test proposé plus haut avec Bob peut mettre du temps à refléter le changement.
- Attribuez les rôles au périmètre le plus étroit (ici, le conteneur `reports`) et limitez-les dans le temps quand c'est possible.

**Question :** au 3ᵉ saut, l'API C journalise l'appelant. Quel utilisateur et quel client voit-elle ?

<details>
<summary>Afficher la réponse</summary>

Utilisateur : Alice, avec le même identifiant d'objet (`oid`) qu'au départ. Client : l'API B, car `azp` désigne l'application
qui a fait le dernier échange. VS Code n'est plus visible au 3ᵉ saut. Pour suivre toute la chaîne, journalisez le client dès
le premier saut et transmettez un identifiant de corrélation, jamais le jeton.

</details>

## Sources

- [Lire une identité managée avec Azure CLI](https://learn.microsoft.com/cli/azure/identity#az-identity-show), vérifié le 20 octobre 2026.

- [Plateforme d'identités Microsoft et flux On-Behalf-Of OAuth 2.0](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow)
- [Référence des revendications des jetons d'accès (`azp`, `appid`, `roles`)](https://learn.microsoft.com/entra/identity-platform/access-token-claims-reference) et
  [Résoudre les problèmes de RBAC Azure (délais de propagation)](https://learn.microsoft.com/azure/role-based-access-control/troubleshooting)
- [Configurer une application pour faire confiance à une identité managée](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity)
- [Authentification sans certificat avec Microsoft.Identity.Web](https://learn.microsoft.com/entra/msidweb/authentication/certificateless)
- [Accorder un consentement administrateur à l'échelle du tenant](https://learn.microsoft.com/entra/identity/enterprise-apps/grant-admin-consent)
- [Autoriser l'accès aux blobs avec Microsoft Entra ID](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory) et
  [attribuer un rôle Azure pour l'accès aux données blob](https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access)
- [Microsoft Graph user : get (`/me`, `User.Read`)](https://learn.microsoft.com/graph/api/user-get)
- [Identités utilisateur dans l'authentification App Service (`X-MS-CLIENT-PRINCIPAL`)](https://learn.microsoft.com/azure/app-service/configure-authentication-user-identities)
- [`HelloToolWithAuth.cs` de l'exemple épinglé](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/blob/468c518c884ec318e3001b9573254c9e775409c9/src/FunctionsMcpTool/HelloToolWithAuth.cs)
  et [`infra/app/entra.bicep`](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/blob/468c518c884ec318e3001b9573254c9e775409c9/infra/app/entra.bicep) (MIT)
- [Extension MCP Azure Functions 1.5.0 (en-têtes `HttpTransport`)](https://github.com/Azure/azure-functions-mcp-extension/tree/worker-1.5.0) et
  [erreurs d'outil du SDK MCP C# (`isError`)](https://github.com/modelcontextprotocol/csharp-sdk)
- [AzureAD 3.10.0](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0/docs) (`azuread_application_api_access`,
  `azuread_application_federated_identity_credential`, `azuread_service_principal_delegated_permission_grant`) et
  [AzureRM 5.9.0](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs)

Dernière vérification : 2026-10-18.

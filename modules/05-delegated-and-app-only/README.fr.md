# 05 - Qui porte les droits ? On-Behalf-Of ou application seule (niveau 3)

[English](README.md)

## Objectif

Poser **la même question** en tant que deux utilisateurs différents et voir **qui porte les droits** en aval. À la fin :

- `whoami` appelle Microsoft Graph **au nom de** l'utilisateur connecté et ne renvoie qu'une étiquette de persona synthétique
  (`alice` ou `bob`) ;
- `read_report_as_user` lit un rapport synthétique dans Azure Storage **en tant qu'utilisateur** (On-Behalf-Of, OBO) : **Alice**
  obtient le rapport, **Bob** obtient une **erreur d'outil MCP dans une réponse HTTP 200**, car Storage lui répond HTTP 403 ;
- `read_report_as_app` lit le même rapport **en tant qu'application** (une identité managée) : **Alice et Bob obtiennent le même
  résultat** ;
- **aucun secret client n'existe nulle part** : l'API MCP prouve son identité avec une identité managée via un identifiant fédéré.

> [!WARNING]
> Ne collez jamais un jeton réel dans un site web, une conversation, un fichier, une capture ou un journal. Le validateur garde
> les jetons en mémoire uniquement, et `whoami` ne renvoie jamais un vrai nom ni une adresse e-mail.

## Pourquoi cette étape compte

Jusqu'ici, chaque outil n'appelait rien en aval (démonstrations synthétiques) ou utilisait l'identité du serveur. Les vrais
outils appellent d'autres API, et la question de conception clé est **avec les droits de qui** cet appel est fait :

| | Contexte utilisateur : **On-Behalf-Of** | Contexte application : **identité managée** |
|---|---|---|
| Outils | `whoami`, `read_report_as_user` | `read_report_as_app` |
| Jeton en aval | Un **nouveau** jeton pour Graph (`User.Read`) ou Storage (`user_impersonation`), émis pour l'utilisateur connecté | Un jeton de l'identité managée affectée par l'utilisateur, réservée à l'application |
| Qui décide de l'accès | Le rôle **de l'utilisateur** sur les données (Alice : Storage Blob Data Reader ; Bob : aucun) | Le rôle **de l'identité** (Storage Blob Data Reader sur un conteneur) |
| Résultat | Différent selon l'utilisateur | **Identique pour tout appelant** que la passerelle laisse passer |
| Risque en cas d'abus | Faible : le serveur ne peut pas dépasser les droits de l'utilisateur | Adjoint confus (confused deputy) : quiconque peut appeler l'outil lit ce que l'application peut lire |

**Un jeton par saut, une audience par jeton.** Le jeton du client MCP a l'audience de l'API MCP. Le serveur ne le transmet jamais
à Graph ni à Storage (pas de token passthrough). Pour les outils en contexte utilisateur, il envoie ce jeton **uniquement à
Microsoft Entra ID** comme *assertion* OBO et reçoit un jeton distinct par ressource en aval. Pour l'outil application seule, le
jeton de l'appelant n'est pas utilisé du tout.

**OBO sans secret.** OBO exige que l'API MCP s'authentifie comme client confidentiel. Au lieu d'un secret client ou d'un
certificat, l'inscription de l'API fait confiance à **une identité managée affectée par l'utilisateur** de la charge de travail,
via un **identifiant d'identité fédérée** (émetteur `https://login.microsoftonline.com/<tenant>/v2.0`, sujet = l'ID de principal
de l'identité, audience `api://AzureADTokenExchange`). Le serveur demande à cette identité un jeton d'audience
`api://AzureADTokenExchange` et l'utilise comme assertion client ([concept](../../docs/fr/concepts/obo-and-managed-identity.md)).

**OBO est réservé aux utilisateurs.** Un jeton d'application (sans revendication `scp`, `idtyp=app`) est refusé par les outils en
contexte utilisateur avant tout appel en aval : sinon OBO produirait un jeton qui ne représente pas l'appelant d'origine.

**Statut HTTP externe ou résultat de l'outil.** MCP transporte les erreurs d'outil dans une réponse JSON-RPC réussie : l'appel de
Bob renvoie **HTTP 200** avec `result.isError: true`. Le HTTP 403 de la passerelle (module 04) signifie « vous ne pouvez pas
appeler cet outil » ; une erreur d'outil avec HTTP 200 signifie « l'outil s'est exécuté, et l'API en aval a refusé l'identité
qu'il a utilisée ».

## Ce que vous déployez

Variables d'activation explicites, désactivées par défaut : les modules 00 à 04 ne changent pas quand `enable_delegated_access`
vaut false, et le serveur garde les démonstrations du module 02 pour `whoami` et `read_report_*`.

**Charge de travail** (`infra/workload/delegated-access.tf`, participant) :

| Ressource | Paramètres |
|---|---|
| Identité affectée par l'utilisateur `id-mcp-<prefix>-<suffix>-obo` | Approuvée par l'identifiant fédéré de l'API MCP. **Aucun rôle Azure.** Sert uniquement à obtenir l'assertion client OBO. |
| Identité affectée par l'utilisateur `id-mcp-<prefix>-<suffix>-report` | Identité application seule de `read_report_as_app` |
| Conteneur blob `reports` (compte de stockage du module 02, clés partagées désactivées) | Privé ; contient le fichier synthétique `monthly-usage.json` ([synthetic-data](synthetic-data/monthly-usage.json)) |
| Attribution de rôle | **Storage Blob Data Reader** pour l'identité `-report`, portée = le seul conteneur `reports` |
| Attribution de rôle | **Storage Blob Data Reader** pour Alice (`delegated_persona_object_ids.alice`), même portée. **Bob n'a rien.** |
| Attribution de rôle | Storage Blob Data Contributor sur le conteneur pour la personne qui publie le rapport (par défaut : l'utilisateur Terraform connecté) |
| Function App (module 02) | Les deux identités attachées ; paramètres `WORKSHOP_*` non secrets : tenant, ID client de l'API MCP, ID client des deux identités, URL du conteneur, table des personas |

**Pourquoi deux nouvelles identités ?** L'identité OBO peut agir en tant qu'inscription de l'API MCP ; elle n'a donc aucun rôle sur
les données : un appel en contexte utilisateur ne peut utiliser que les droits délégués de l'utilisateur. Les droits application
seule sont sur une autre identité. L'identité d'hébergement du module 02 (Blob Data Owner sur tout le compte pour l'hôte Functions)
n'est jamais utilisée par un outil.

**Microsoft Entra** (`infra/entra/delegation.tf`, administrateur des identités, application créée uniquement) :

| Variable | Ressource | Effet |
|---|---|---|
| `enable_delegated_access` | `azuread_application_api_access` | L'API MCP demande les autorisations déléguées Microsoft Graph `User.Read` et Azure Storage `user_impersonation`. Les ID d'étendue sont lus sur les principaux de service du tenant. Aucune autorisation d'application. |
| `obo_identity_principal_id` | `azuread_application_federated_identity_credential` | Fait confiance à l'identité `-obo` (sujet = son ID de principal). |
| `grant_downstream_admin_consent` | `azuread_service_principal_delegated_permission_grant` | Consentement administrateur à l'échelle du tenant pour exactement ces deux étendues (décision de l'administrateur des identités). |

![Architecture du niveau 3](../../assets/architecture/05.fr.svg)

**Preview :** rien de nouveau dans ce module. Les métadonnées de ressource protégée sur la Function (module 03) et l'API de serveur
MCP d'API Management `2025-09-01-preview` (module 04) restent en **Preview** si vous les utilisez.

**Coût :** deux identités managées et un conteneur ne coûtent rien en eux-mêmes ; les transactions Storage et appels Graph
supplémentaires sont négligeables. La passerelle du module 04 reste facturée tant qu'elle existe.

**Code :** les outils sont dans [src/FunctionsMcpServer](../../src/FunctionsMcpServer) (`Logic/DelegatedTools.cs`,
`Identity/DownstreamCredentials.cs`, `Logic/CallerContext.cs`). Ils suivent `HelloToolWithAuth.cs` de l'exemple épinglé
(`Azure-Samples/remote-mcp-functions-dotnet` à `468c518c884ec318e3001b9573254c9e775409c9`, MIT) avec ces changements : pas de
repli sur l'identité du développeur, l'assertion utilisateur vient de la requête validée par la plateforme (authentification
intégrée), seul l'ID d'objet Graph est demandé (`/me?$select=id`), et une seconde identité managée porte les droits application seule.

## Prérequis et rôles nécessaires

- Modules 02 et 03 déployés (module 04 recommandé) avec les mêmes fichiers privés et le même état Terraform. Publiez le code du
  serveur de cette version du dépôt (il contient le module 05) **avant** que l'étape 2 du module 04 rende privés les points de
  déploiement.
- Les comptes de test existants Alice et Bob du module 03 (ID d'objet uniquement) ; Eve reste non affectée.
- Terraform 1.16.6+, Azure CLI, PowerShell 7.4+. Exemple de région : `swedencentral`.

**Participant :** Contributeur sur le groupe de ressources de l'atelier, plus le droit de créer trois attributions de rôle limitées
au conteneur `reports` (par exemple Role Based Access Control Administrator, restreint à Storage Blob Data Reader et Contributor,
limité dans le temps).

**Administrateur des identités :** Application Administrator ou Cloud Application Administrator (ou propriétaire de l'application
de l'atelier) pour ajouter l'identifiant fédéré et les autorisations demandées. Accorder le consentement administrateur à
l'échelle du tenant pour des autorisations déléguées demande Cloud Application Administrator ou Application Administrator. Voir la
[demande d'identité](../../docs/requests/identity-request.md).

## Étapes

### PowerShell

Depuis la racine du dépôt. Les étapes 2 à 5 modifient Azure ou Microsoft Entra : faites-les seulement après approbation du plan.

**1. Vérifications hors ligne (sans Azure).**

```powershell
& .\modules\05-delegated-and-app-only\validate.ps1 -Offline
```

**2. Fichier privé d'activation de la charge de travail (ignoré par Git).** Demandez les ID d'objet d'Alice et de Bob à
l'administrateur des identités (sortie `workload_module05_tfvars` de `infra/entra`).

```powershell
@{ enable_delegated_access = $true; delegated_persona_object_ids = @{ alice = '<alice-object-id>'; bob = '<bob-object-id>' } } |
    ConvertTo-Json | Set-Content -LiteralPath .\.workshop\module05.tfvars.json
```

**3. Application sur la charge de travail.** Sélectionnez d'abord votre contexte approuvé (`& .\scripts\select-azure-context.ps1`).
Passez tous les fichiers de variables utilisés avant, plus celui du module 05 (retirez `module04.tfvars.json` si vous avez sauté le
module 04).

```powershell
$vars = '-var-file=..\..\.workshop\participant.tfvars.json', '-var-file=..\..\.workshop\module02.tfvars.json',
        '-var-file=..\..\.workshop\module03.tfvars.json', '-var-file=..\..\.workshop\module04.tfvars.json',
        '-var-file=..\..\.workshop\module05.tfvars.json'
terraform '-chdir=infra\workload' plan @vars '-out=..\..\.workshop\module05.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
# Relire : 2 identités, 1 conteneur, 3 attributions de rôle sur ce conteneur et une mise à jour en place de la Function App. Après approbation :
terraform '-chdir=infra\workload' apply '..\..\.workshop\module05.tfplan'
terraform '-chdir=infra\workload' output -json entra_module05_tfvars   # à envoyer à l'administrateur des identités
```

Tant que l'étape 4 n'est pas faite, `whoami` et `read_report_as_user` échouent de façon sûre (erreur d'outil) : l'API ne fait pas
encore confiance à l'identité.

**4. Administrateur des identités : identifiant fédéré, autorisations, consentement.** Dans son propre terminal et son propre état :

```powershell
@{ enable_delegated_access = $true; obo_identity_principal_id = '<principal-id-from-step-3>'; grant_downstream_admin_consent = $true } |
    ConvertTo-Json | Set-Content -LiteralPath .\.workshop\entra-module05.tfvars.json
terraform '-chdir=infra\entra' plan '-var-file=..\..\.workshop\entra.tfvars.json' '-var-file=..\..\.workshop\entra-module05.tfvars.json' '-out=..\..\.workshop\entra05.tfplan'
# Relire : 2 accès d'API, 1 identifiant fédéré, 2 consentements. Après approbation :
terraform '-chdir=infra\entra' apply '..\..\.workshop\entra05.tfplan'
```

**5. Publier le rapport synthétique** (authentification Microsoft Entra, sans clé ; nouvelles tentatives pendant la propagation du rôle) :

```powershell
& .\modules\05-delegated-and-app-only\publish-report.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

**6. Essayer dans VS Code.** Avec le serveur `workshop-governed` du module 04, demandez à Copilot en tant qu'Alice : « Qui suis-je ? »
puis « Lis le rapport monthly-usage en tant que moi, puis en tant qu'application ». Recommencez en tant que Bob dans un autre profil
VS Code.

**7. Vérifications opérateur, puis vérifications par persona.**

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

### Bash

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

## Ce que vous devez voir

Même question, deux personas. D'abord le statut HTTP externe, puis le résultat de l'outil MCP
([exemples synthétiques](synthetic-data/expected-tool-results.json)).

| Persona | Outil | HTTP externe | Résultat de l'outil | Pourquoi |
|---|---|---|---|---|
| Alice | `whoami` | HTTP 200 | `isError: false`, `persona: "alice"` | Jeton OBO pour Graph `User.Read` ; seul l'ID d'objet est lu puis associé à une étiquette |
| Bob | `whoami` | HTTP 200 | `isError: false`, `persona: "bob"` | Même flux, avec le jeton de Bob |
| Alice | `read_report_as_user` | HTTP 200 | `isError: false`, les deux lignes synthétiques | Jeton OBO pour Storage ; Alice a Storage Blob Data Reader sur `reports` |
| Bob | `read_report_as_user` | **HTTP 200** | **`isError: true`** | Jeton OBO pour Storage ; Bob n'a aucun rôle, Storage répond **HTTP 403** en aval |
| Alice | `read_report_as_app` | HTTP 200 | `isError: false`, les deux lignes synthétiques | L'identité managée `-report` lit le conteneur |
| Bob | `read_report_as_app` | HTTP 200 | `isError: false`, lignes **identiques** | Même identité, mêmes droits : l'appelant ne compte pas |
| Tout appelant application seule | `whoami` / `read_report_as_user` | HTTP 200 (ou 403 à la passerelle) | `isError: true` | OBO est réservé aux utilisateurs ; refus avant tout appel en aval |

Les journaux du serveur contiennent une ligne par appel : nom de l'outil, ID d'objet de l'appelant, résultat (`success`,
`denied-downstream:403`, `rejected-caller`), latence et ID d'invocation. Jamais les arguments, le rapport, un nom ou un jeton.

## Valider

`validate.ps1` (ou `validate.sh`) exécute toujours d'abord les vérifications hors ligne : On-Behalf-Of avec une assertion
d'identité managée et un jeton par ressource en aval ; appelants application seule refusés ; pas de repli sur l'identité du
développeur ni d'analyse de jeton dans le serveur ; identifiant fédéré Entra et étendues déléguées exactes, consentement en
activation explicite, sans mot de passe ; tous les rôles du module 05 sur le seul conteneur du rapport, aucun pour l'identité OBO
ni pour Bob ; données synthétiques uniquement ; aucun motif de secret ; tests unitaires ; format, schéma et tests simulés Terraform
pour les deux racines.

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

Modes réels, après un déploiement approuvé :

- **Opérateur** (`-TenantId -SubscriptionId`) : les paramètres de la Function nomment les deux identités et ne contiennent aucun
  paramètre secret ; l'inscription de l'API MCP n'a **aucun identifiant de mot de passe** et exactement un identifiant fédéré qui
  fait confiance à l'identité OBO ; le conteneur `reports` a Storage Blob Data Reader pour l'identité application seule et pour
  Alice uniquement, rien pour l'identité OBO ni pour Bob.
- **Persona** (`-TenantId -Persona Alice|Bob`) : `whoami` renvoie l'étiquette du persona, sans nom ni adresse e-mail ;
  `read_report_as_user` d'Alice renvoie le rapport (HTTP 200, `isError: false`) ; celui de Bob renvoie **HTTP 200 avec
  `isError: true`** ; `read_report_as_app` renvoie les mêmes lignes synthétiques aux deux (le second passage compare une empreinte
  enregistrée par le premier, dans `.workshop/`).

Le module n'est `validated` que lorsque tout cela passe sur un abonnement neuf, juste après les modules 00 à 04.

## Dépannage

| Symptôme | Vérification |
|---|---|
| `whoami` / `read_report_as_user` donnent `isError: true` aussi pour Alice | Étape 4 non faite (pas d'identifiant fédéré ni de consentement), ou le sujet n'est pas l'ID de **principal** de l'identité `-obo`. Un émetteur, sujet ou audience erroné est accepté à la création et n'échoue qu'à l'échange de jeton. |
| Idem, et le journal du serveur indique `failed:AuthenticationFailedException` | L'échange de jeton a échoué. Vérifiez dans l'ordre : les valeurs de l'identifiant fédéré, le consentement administrateur (`grant_downstream_admin_consent = true` ou le portail), et que l'identité `-obo` est attachée à la Function. Le serveur ne journalise jamais le texte d'erreur d'Entra. |
| Alice obtient `isError: true` seulement sur `read_report_as_user` | Son rôle Storage est encore en cours de propagation (quelques minutes), ou `delegated_persona_object_ids.alice` est faux. |
| `read_report_as_app` donne `isError: true` | Rapport non publié (étape 5), ou rôle de l'identité `-report` encore en propagation. |
| `publish-report.ps1` échoue toujours | Il vous faut Storage Blob Data Contributor sur `reports` ; renseignez `delegated_report_publisher_object_id` si Terraform a été exécuté par quelqu'un d'autre. |
| `Invalid index` sur `oauth2_permission_scope_ids` dans `infra/entra` | Le principal de service Azure Storage manque dans le tenant ; un administrateur le crée (`az ad sp create --id e406a681-f3d4-42a8-90b6-c2b029497af1`). |
| Les outils renvoient encore des résultats de « démonstration » | Le code déployé est antérieur au module 05, ou `WORKSHOP_DELEGATED_ACCESS` ne vaut pas `enabled`. Publiez le code (avant l'étape 2 du module 04). |
| HTTP 403 de la passerelle pour chaque appel | C'est le module 04 (rôle ou étendue). Un refus en aval n'est jamais un HTTP 403 externe. |

## Nettoyer

Le script planifie d'abord, refuse tout changement hors du module 05 et est idempotent ; lancez-le une fois pour relire, puis avec
`-Apply`. Non exécuté par l'auteur : aucun déploiement n'existe.

```powershell
# Participant : identités, conteneur (et rapport), attributions de rôle, paramètres
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
Remove-Item -LiteralPath .\.workshop\module05.tfvars.json, .\.workshop\module05-as-app-*.sha256 -ErrorAction SilentlyContinue
# Administrateur des identités : identifiant fédéré, autorisations demandées, consentements
& .\modules\05-delegated-and-app-only\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -Scope Entra -Apply
Remove-Item -LiteralPath .\.workshop\entra-module05.tfvars.json -ErrorAction SilentlyContinue
```

```bash
bash ./modules/05-delegated-and-app-only/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -Apply
bash ./modules/05-delegated-and-app-only/cleanup.sh -TenantId "$ARM_TENANT_ID" -Scope Entra -Apply
rm -f .workshop/module05.tfvars.json .workshop/module05-as-app-*.sha256 .workshop/entra-module05.tfvars.json
```

Lancez le nettoyage Entra **avant** celui du module 03, qui n'accepte que les objets du module 03. Les modules 02 à 04 restent. Si
vous continuez vers le module 06 maintenant, gardez tout.

## Aller plus loin

- Lisez [DelegatedTools.cs](../../src/FunctionsMcpServer/Logic/DelegatedTools.cs) : où se fait le choix de l'identité pour chaque
  outil, et pourquoi ne peut-il jamais changer à l'exécution ?
- Pourquoi l'identité OBO n'a-t-elle aucun rôle Azure, et qu'est-ce qui irait mal si `read_report_as_app` l'utilisait ?
- Donnez à Bob Storage Blob Data Reader sur `reports` pendant quelques minutes : quel résultat change, et lequel ne change jamais ?
- Microsoft.Identity.Web propose le même modèle sans secret pour les API ASP.NET Core (`SignedAssertionFromManagedIdentity`) ; ce
  module utilise Azure.Identity, car l'authentification intégrée valide déjà le jeton.

## Sources

- [Plateforme d'identités Microsoft et flux On-Behalf-Of OAuth 2.0](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow)
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

Dernière vérification : 2026-10-15. Rédigé et vérifié hors ligne uniquement ; pas encore déployé ni validé dans Azure.

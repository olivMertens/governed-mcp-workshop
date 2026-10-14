# 02 - Un serveur MCP « ouvert » (niveau 0)

[English](README.md)

## Objectif

Déployer le serveur Model Context Protocol (MCP) de l'atelier sur Azure Functions, protégé uniquement par une clé.
Prouver qu'une requête sans clé reçoit HTTP 401 et qu'une requête avec la clé reçoit HTTP 200.
Puis constater le risque : **toute personne qui détient la clé peut appeler l'outil d'écriture `create_ticket`.**

> [!WARNING]
> Le niveau 0 sert uniquement à montrer ce risque. Gardez-le peu de temps, ne rendez jamais le point de terminaison
> anonyme, et passez au module 03 (Microsoft Entra ID) puis au module 04 (API Management) pour le corriger.

## Pourquoi cette étape compte

Une clé est un secret partagé, pas une identité. Le serveur ne distingue pas Alice de Bob ni d'Eve.
Il ne peut pas appliquer de rôle par utilisateur, ni appeler une API en aval « au nom de l'utilisateur », et les journaux
ne peuvent pas dire qui a fait quoi. Une clé peut fuiter par une capture d'écran, une conversation, un fichier de
configuration enregistré ou un historique de navigateur.

L'extension MCP d'Azure Functions protège `/runtime/webhooks/mcp` avec la **clé système** `mcp_extension`
lorsque `host.json` fixe `webhookAuthorizationLevel` à `System` (valeur par défaut). L'exemple d'origine utilise
`Anonymous` parce qu'il ajoute l'authentification Microsoft Entra devant. Ce module n'a pas encore de couche Entra :
il garde `System`. Ne copiez jamais `Anonymous` dans un serveur protégé seulement par clé.

## Ce que vous déployez

Tout est créé dans votre groupe de ressources d'atelier, depuis `infra/workload` avec `enable_mcp_server = true` :

| Ressource | Rôle | Réglage de sécurité |
|---|---|---|
| Plan Flex Consumption (`FC1`) et application de fonctions | Héberge le serveur MCP .NET 10 (worker isolé) | HTTPS seulement, TLS 1.2, publication par mot de passe désactivée, liste d'adresses IPv4 autorisées en option |
| Identité managée attribuée par l'utilisateur | Seule identité de l'application | Aucun secret ; trois attributions de rôle ci-dessous |
| Compte de stockage | Stockage de l'hôte, paquet de déploiement et file `tickets` | Accès par clé partagée **désactivé**, autorisation Entra par défaut, aucun blob public |
| Espace Log Analytics et Application Insights | Télémétrie sans contenu | Authentification locale désactivée ; plafond de 1 Go/jour |

Attributions de rôle, chacune sur une ressource précise :

| Rôle | Portée | Pourquoi |
|---|---|---|
| Storage Blob Data Owner | Le compte de stockage de l'atelier | Stockage de l'hôte Functions et paquet de déploiement Flex (par identité) |
| Storage Queue Data Message Sender | La file `tickets` uniquement | `create_ticket` envoie un message synthétique |
| Monitoring Metrics Publisher | Le composant Application Insights | Télémétrie authentifiée par Entra |

Les cinq outils (toutes les données sont synthétiques) :

| Outil | Type | Comportement au niveau 0 |
|---|---|---|
| `get_service_health` | lecture | État fixe pour `workshop-api` ou `ticket-queue` |
| `create_ticket` | **écriture** | Vérifie `service`, `severity` et un court `summary`, puis met un ticket synthétique en file |
| `whoami` | démonstration | Indique que l'appelant est inconnu : une clé n'identifie personne |
| `read_report_as_user` | démonstration | Rapport synthétique étiqueté ; l'appel On-Behalf-Of réel arrive au module 05 |
| `read_report_as_app` | démonstration | Rapport synthétique étiqueté ; l'appel réel par identité managée arrive au module 05 |

Chaque outil refuse les arguments inconnus. `create_ticket` n'écrit rien si la forme exacte des arguments n'est pas valide.
Les journaux contiennent seulement le nom de l'outil, le résultat, la durée et l'identifiant d'invocation :
jamais les arguments, les résultats, les clés ni les jetons.

![Architecture du niveau 0](../../assets/architecture/02.fr.svg)

Aucune fonctionnalité en **Preview** n'est utilisée. Le code et l'infrastructure adaptent
[Azure-Samples/remote-mcp-functions-dotnet](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9)
(MIT) ; voir [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md).

**Coût :** Flex Consumption facture à l'exécution et au temps de mémoire, plus les transactions de stockage et
l'ingestion de télémétrie. Le plan descend à zéro instance et est limité à 10 instances, sans instance toujours prête.
Vérifiez les prix actuels de votre région avant l'accord. Nettoyez le jour même.

## Prérequis et rôles nécessaires

- Module 00 validé pour votre abonnement et module 01 terminé.
- Vos paramètres privés et votre état Terraform du module 00 (`.workshop/participant.tfvars.json`). Ne les régénérez pas.
- Terraform 1.16.6 ou plus récent, Azure CLI, PowerShell 7.4+, le SDK .NET 10.
- Un abonnement hors production où Flex Consumption prend en charge .NET 10 dans votre région (exemple : `swedencentral`).

Rôles Azure sur le groupe de ressources de l'atelier (demandez-les à votre administrateur ; ne demandez pas Owner) :

- **Contributor** pour créer les ressources, lire la clé système et publier le code.
- **Role Based Access Control Administrator**, idéalement avec une condition qui n'autorise que les trois rôles
  ci-dessus, pour créer les trois attributions. Contributor seul ne peut pas attribuer de rôle.

Aucune modification Microsoft Entra n'est nécessaire dans ce module.

## Étapes

### PowerShell

Exécutez depuis la racine du dépôt. Arrêtez-vous à la première commande en échec.
Les étapes 3 à 6 modifient Azure : faites-les uniquement après accord.

**1. Vérifications hors ligne (sans Azure).**

```powershell
& .\modules\02-open-server\validate.ps1 -Offline
```

**2. Sélectionnez votre contexte approuvé.**

```powershell
& .\scripts\select-azure-context.ps1 -Language fr
```

**3. Activez le module en privé, puis planifiez.** Le fichier d'activation est ignoré par Git. Ajoutez votre plage
IPv4 publique dans `mcp_allowed_ip_ranges` (par exemple `"203.0.113.10/32"`) pour limiter les appelants ;
laissez la liste vide pour montrer le niveau ouvert.

```powershell
'{ "enable_mcp_server": true, "mcp_allowed_ip_ranges": [] }' | Set-Content -LiteralPath .\.workshop\module02.tfvars.json
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-var-file=..\..\.workshop\module02.tfvars.json' '-out=..\..\.workshop\module02.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
```

Relisez le plan : il doit seulement **ajouter** les onze ressources du module 02. Passez les deux fichiers de variables
à chaque plan suivant, sinon Terraform propose de supprimer le serveur.

**4. Appliquez le plan relu (après accord).**

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\module02.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform apply failed.' }
```

**5. Publiez le code du serveur.** Azure CLI utilise votre connexion Microsoft Entra ; aucun mot de passe de publication n'existe.

```powershell
$group = terraform -chdir=infra/workload output -raw resource_group_name
$app = terraform -chdir=infra/workload output -raw mcp_function_app_name
dotnet publish .\src\FunctionsMcpServer --configuration Release --output .\.workshop\module02-publish
if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
Compress-Archive -Path .\.workshop\module02-publish\* -DestinationPath .\.workshop\module02.zip -Force
az functionapp deployment source config-zip --resource-group $group --name $app --src .\.workshop\module02.zip --output none
if ($LASTEXITCODE -ne 0) { throw 'Code deployment failed.' }
```

**6. Connectez VS Code sans enregistrer la clé.** Ajoutez ce serveur à votre configuration MCP **utilisateur**
(pas à un fichier versionné). VS Code demande la clé et la garde dans son stockage de secrets.

```json
{
  "inputs": [
    { "type": "promptString", "id": "workshop-mcp-key", "description": "mcp_extension system key", "password": true }
  ],
  "servers": {
    "workshop-open": {
      "type": "http",
      "url": "https://<function-app-host>/runtime/webhooks/mcp",
      "headers": { "x-functions-key": "${input:workshop-mcp-key}" }
    }
  }
}
```

Obtenez l'adresse avec `terraform -chdir=infra/workload output -raw mcp_endpoint`.
Lisez la clé seulement quand VS Code la demande, puis videz le presse-papiers :

```powershell
az functionapp keys list --resource-group $group --name $app --query systemKeys.mcp_extension --output tsv | Set-Clipboard
```

Après l'avoir collée dans la fenêtre de VS Code, exécutez `Set-Clipboard -Value $null`.
Ne mettez jamais la clé dans une URL (`?code=`), un fichier, une conversation ou une capture d'écran.

**7. Validez et montrez le risque.**

```powershell
& .\modules\02-open-server\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -DemonstrateWrite
```

Dans VS Code, demandez à l'agent d'appeler `create_ticket` avec des valeurs synthétiques.
L'appel réussit pour quiconque détient la clé.

**8. Renouvelez la clé après l'exercice.** Toutes les copies qui auraient fuité deviennent inutilisables.

```powershell
az functionapp keys set --resource-group $group --name $app --key-type systemKeys --key-name mcp_extension --output none
```

### Bash

```bash
bash ./modules/02-open-server/validate.sh -Offline
source ./scripts/select-azure-context.sh
printf '%s\n' '{ "enable_mcp_server": true, "mcp_allowed_ip_ranges": [] }' > .workshop/module02.tfvars.json
terraform -chdir=infra/workload init -lockfile=readonly &&
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json \
  -var-file=../../.workshop/module02.tfvars.json -out=../../.workshop/module02.tfplan
# Relisez, puis après accord :
terraform -chdir=infra/workload apply ../../.workshop/module02.tfplan
group="$(terraform -chdir=infra/workload output -raw resource_group_name)"
app="$(terraform -chdir=infra/workload output -raw mcp_function_app_name)"
dotnet publish ./src/FunctionsMcpServer --configuration Release --output ./.workshop/module02-publish &&
(cd ./.workshop/module02-publish && zip -qr ../module02.zip .) &&
az functionapp deployment source config-zip --resource-group "$group" --name "$app" --src ./.workshop/module02.zip --output none
bash ./modules/02-open-server/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -DemonstrateWrite
az functionapp keys set --resource-group "$group" --name "$app" --key-type systemKeys --key-name mcp_extension --output none
```

Utilisez la même configuration VS Code qu'à l'étape 6.

## Ce que vous devez voir

| Action | Résultat attendu | Signification |
|---|---|---|
| Requête MCP sans `x-functions-key` | HTTP 401 | Le webhook n'est pas anonyme. |
| Requête avec une mauvaise clé | HTTP 401 | Seule la clé système fonctionne. |
| `initialize`, puis `tools/list` avec la clé | HTTP 200, cinq outils | Le serveur fonctionne en Streamable HTTP. |
| `create_ticket` avec la clé | HTTP 200, `status: queued`, un `warning` | **Le risque :** ni utilisateur, ni rôle, ni approbation côté serveur. |
| `whoami` | `caller: unknown` | Une clé ne porte aucune identité. |
| `read_report_as_*` | `source: synthetic-demonstration` | L'accès réel en aval arrive au module 05. |

Le validateur en ligne affiche notamment :

```text
PASS MCP request without the mcp_extension key is refused (expected HTTP 401).
PASS anonymous access disabled: a random wrong key is refused (expected HTTP 401).
PASS MCP initialize with the key succeeds; negotiated protocol <version> (expected HTTP 200).
PASS tools/list with the key returns exactly the five workshop tools (expected HTTP 200).
PASS RISK SHOWN: create_ticket succeeds with only the key; no user or role was checked (expected HTTP 200).
```

## Valider

`validate.ps1` (ou `validate.sh`) lance toujours d'abord les vérifications hors ligne : niveau `System` dans
`host.json`, aucun niveau anonyme dans le code, aucun motif de clé ou de secret dans les fichiers du module,
clés partagées désactivées et aucune clé en sortie Terraform, compilation verrouillée et tests unitaires,
tests Terraform simulés. Avec `-Offline`, ou sans tenant ni abonnement, il s'arrête là et indique que le module
n'est **pas** déployé ni validé.

Avec `-TenantId` et `-SubscriptionId`, il vérifie le contexte, lit l'adresse depuis votre état Terraform et la clé
depuis Azure CLI **en mémoire seulement**, puis lance les vérifications HTTP ci-dessus. Chaque vérification affiche une
ligne PASS ou FAIL. Le module n'est terminé que lorsque ces vérifications passent sur un abonnement neuf,
juste après les modules 00 et 01.

## Dépannage

| Symptôme | Vérification |
|---|---|
| HTTP 401 avec la clé | Utilisez la clé **système** `mcp_extension`, dans l'en-tête `x-functions-key`. Une clé de fonction ou d'hôte est différente. |
| Clé vide | Le code n'est pas encore publié ou l'hôte n'a pas démarré. Publiez (étape 5), attendez une minute, réessayez. |
| HTTP 403 | Votre adresse IP n'est pas dans `mcp_allowed_ip_ranges`. Modifiez le fichier privé et planifiez de nouveau. |
| HTTP 404 sur `/runtime/webhooks/mcp` | La publication a échoué ou a utilisé le mauvais dossier. Vérifiez l'état du déploiement dans le portail. |
| L'hôte ne démarre pas / erreurs de stockage | Les attributions de rôle peuvent prendre quelques minutes. Vérifiez les trois attributions ; n'activez jamais les clés partagées. |
| Le plan propose de supprimer le serveur | Vous avez oublié `-var-file=..\..\.workshop\module02.tfvars.json`. |
| Erreur d'outil `Unexpected argument` | Les outils n'acceptent que leurs arguments documentés. C'est voulu. |

## Nettoyer

Lancez le nettoyage après l'exercice. Il planifie avec le module désactivé et refuse de continuer si une modification
n'est pas la suppression d'une ressource du module 02. Lancez-le une fois pour relire, puis avec `-Apply`.
Il est idempotent : s'il ne reste rien, il le dit et ne change rien.

```powershell
& .\modules\02-open-server\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
& .\modules\02-open-server\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
Remove-Item -LiteralPath .\.workshop\module02.tfvars.json, .\.workshop\module02.zip -ErrorAction SilentlyContinue
Remove-Item -LiteralPath .\.workshop\module02-publish -Recurse -ErrorAction SilentlyContinue
```

```bash
bash ./modules/02-open-server/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -Apply
```

Le groupe de ressources, vos paramètres privés et votre état restent pour les modules suivants. Retirez le serveur
`workshop-open` de votre configuration VS Code utilisateur. Si vous enchaînez directement avec le module 03,
vous pouvez garder le serveur et sauter le nettoyage ; le module 03 remplace la clé par l'authentification Microsoft Entra.

## Aller plus loin

- Limitez les appelants avec `mcp_allowed_ip_ranges` et observez HTTP 403 depuis un autre réseau.
- Renouvelez la clé et constatez que l'ancienne session VS Code reçoit HTTP 401.
- Lisez le [modèle de menaces](../../docs/fr/concepts/mcp-threat-model.md) : quelles menaces une clé ne traite-t-elle pas ?
- Suite : [plan du module 03](../../docs/fr/BUILD-PLAN.md).

## Sources

- [Liaisons MCP de Functions : host.json, point de terminaison, clé système](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp)
- [Déclencheur d'outil MCP](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp-tool-trigger)
- [Serveur MCP distant personnalisé sur Functions](https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server)
- [Plan Flex Consumption](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan)
- [Clés d'accès des fonctions](https://learn.microsoft.com/azure/azure-functions/function-keys-how-to)
- [Connexions par identité et rôle minimal du stockage de l'hôte](https://learn.microsoft.com/azure/azure-functions/functions-identity-based-connections-tutorial)
- [Azure-Samples/remote-mcp-functions-dotnet au commit 468c518](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9)
- [Ressource Flex Consumption d'AzureRM 5.9.0](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown)
- [Configuration MCP et saisies protégées dans VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers)

Dernière vérification : 2026-10-14. Rédigé et vérifié hors ligne seulement ; pas encore déployé ni validé dans Azure.

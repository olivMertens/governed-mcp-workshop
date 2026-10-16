# 04 - API Management comme seule entrée (niveau 2)

[English](README.md)

## Objectif

Placer **Azure API Management** (APIM) devant le serveur MCP et en faire la **seule** porte d'entrée. À la fin :

- une requête sans jeton reçoit **HTTP 401** de la passerelle, avec un défi qui pointe vers les métadonnées de ressource
  protégée (PRM) de la passerelle elle-même ;
- **Bob** (`Tools.Read`) appelle `create_ticket` → **HTTP 403** ; **Alice** (`Tools.Read` + `Tools.Write`) → **HTTP 200** ;
- Bob appelle `get_service_health` → **HTTP 200** ;
- une rafale d'appels d'un même utilisateur → **HTTP 429** ;
- un appel direct à l'hôte de la Function depuis Internet → **HTTP 403** (accès public désactivé) ;
- Application Insights montre qui a appelé quel outil, **sans contenu** ni jeton.

> [!WARNING]
> Ne collez jamais un jeton réel dans un site web, une conversation, un fichier, une capture ou un journal. Le validateur conserve
> les jetons uniquement en mémoire.

## Pourquoi cette étape compte

Le niveau 1 (module 03) vérifie **qui** appelle le serveur, pas **ce qu'il a le droit de faire** : Bob peut encore créer des
tickets, rien ne limite le débit et la Function est joignable depuis n'importe où sur Internet. Une passerelle ajoute les contrôles qu'un
serveur ne devrait pas réimplémenter :

| Contrôle | Où | Pourquoi |
|---|---|---|
| `validate-azure-ad-token` | Entrée de la passerelle | Validation par la plateforme de l'émetteur, du tenant, de l'expiration, de l'**audience = l'API MCP seulement**, du client autorisé et de l'étendue `user_impersonation`. Aucun code JWT écrit à la main. |
| Contrôle de rôle par outil | Entrée de la passerelle, depuis le corps JSON-RPC | `tools/call` avec `create_ticket` exige le rôle d'application `Tools.Write` ; tout autre outil ou méthode MCP exige `Tools.Read`. Les corps mal formés, les lots, les outils inconnus et les méthodes non prises en charge sont refusés. |
| `rate-limit-by-key` | Entrée de la passerelle, clé = identifiant d'objet de l'appelant (`oid`) du jeton validé | Un utilisateur qui envoie trop d'appels reçoit HTTP 429 sans gêner les autres. |
| `ip-filter` | Entrée de la passerelle, facultatif | Restreint les adresses sources si votre organisation l'exige (vide par défaut). |
| Chemin privé | Réseau | La Function a l'**accès réseau public désactivé** et un **point de terminaison privé** ; seule la passerelle l'atteint grâce à l'intégration au réseau virtuel sortante de Standard v2. |
| Journaux sans contenu | Application Insights | **0 octet de corps** pour les requêtes et réponses frontend/backend, aucun en-tête journalisé, et une trace limitée au libellé de l'outil et à l'`oid` de l'appelant. |

### Suivre le jeton et le chemin réseau privé

**Étendues et rôles d'application.** La revendication `scp` (`user_impersonation`) indique ce que l'*application cliente* peut
faire pour l'utilisateur. La revendication `roles` (`Tools.Read`, `Tools.Write`) indique ce que *cet utilisateur* peut faire.
L'autorisation par outil utilise les **rôles d'application** ([concept](../../docs/fr/concepts/scopes-and-app-roles.md)).

**Frontière du jeton.** La passerelle et la Function protègent **une seule ressource MCP logique** avec **une seule audience**
(`api://<client-id>`, du module 03). La passerelle valide le jeton puis transmet la **même** requête à la Function, dont
l'authentification intégrée le valide à nouveau (défense en profondeur). Ce n'est pas un relais de jeton vers une API en aval :
le jeton n'est jamais envoyé à Microsoft Graph, à Storage ni ailleurs, et aucune audience n'est ajoutée ou élargie. Le
module 05 obtient des jetons distincts pour les appels en aval via On-Behalf-Of ou une identité managée
([chaîne de jetons](../../docs/fr/concepts/token-chain.md)).

**Choix réseau.** Standard v2 conserve une **passerelle publique** pour les clients et utilise l'**intégration au réseau virtuel
sortante** pour appeler un **point de terminaison privé de la Function**, résolu par la zone DNS privée
`privatelink.azurewebsites.net`. L'accès public de la Function est ensuite désactivé. Basic v2 n'a pas d'intégration sortante,
et l'injection complète dans un réseau virtuel (Premium v2) dépasse les besoins de l'atelier. Les règles NSG entrantes ne
s'appliquent pas à l'intégration sortante : ce sont les stratégies de la passerelle qui contrôlent l'entrée.

## Ce que vous déployez

Toutes les ressources sont créées dans le groupe de ressources de l'atelier, avec les noms déterministes de vos paramètres
privés. Les variables d'activation sont désactivées par défaut : les modules 00 à 03 sont inchangés tant que `enable_governed_gateway` vaut false.

| Ressource | Paramètres |
|---|---|
| Réseau virtuel `vnet-mcp-<prefix>-<suffix>` | `10.42.0.0/23` par défaut (`gateway_vnet_address_space`) |
| Sous-réseau `snet-apim` + NSG | `/24`, **délégué à `Microsoft.Web/serverFarms`**, réservé à API Management ; NSG avec la règle sortante Key Vault documentée |
| Sous-réseau `snet-private-endpoints` | `/27`, pour le point de terminaison privé de la Function |
| Zone DNS privée `privatelink.azurewebsites.net` + lien | Résout le nom d'hôte de la Function en son adresse IP privée dans le réseau virtuel |
| Point de terminaison privé `pe-mcp-<prefix>-<suffix>-func` | Sous-ressource `sites` ; le groupe de zones écrit les enregistrements de l'application et de `scm` |
| API Management `apim-mcp-<prefix>-<suffix>` | **Standard v2** (`StandardV2_1`), passerelle publique, intégration sortante, identité managée attribuée par l'utilisateur |
| API de serveur MCP `workshop-mcp` | **Preview** (`Microsoft.ApiManagement/service/apis@2025-09-01-preview`, `type: mcp`, `transportType: streamable`), backend `https://<hôte-function>/runtime/webhooks` + `/mcp`, **aucune clé d'abonnement** |
| Stratégie du serveur MCP | [policies/mcp-server.xml](policies/mcp-server.xml) |
| API de métadonnées `.well-known/oauth-protected-resource` | [Métadonnées RFC 9728](policies/protected-resource-metadata.xml) anonymes : ressource de la passerelle, votre tenant, étendue `api://<client-id>/user_impersonation` |
| Journaliseur + diagnostics | Application Insights (module 02) via une chaîne de connexion **et l'identité managée de la passerelle** (Monitoring Metrics Publisher sur ce seul composant), 0 octet de corps aux portées « toutes les API » et « API MCP » |
| Function App (module 02) | Étape 2 seulement : `public_network_access_enabled = false` |

![Architecture du niveau 2](../../assets/architecture/04.fr.svg)

L'URL client devient `https://apim-mcp-<prefix>-<suffix>.azure-api.net/workshop-mcp/mcp`. L'URL privée de la Function n'est
jamais communiquée aux clients (le portail facultatif, lui aussi, ne préremplit que l'URL de la passerelle).

**Preview :** le type de ressource serveur MCP d'API Management et la version d'API `2025-09-01-preview` sont en **Preview**,
comme les métadonnées de ressource protégée de la Function (module 03). La prise en charge des serveurs MCP est documentée
pour Standard v2 ; le niveau AI Gateway (Preview) n'est pas utilisé.

**Coût :** API Management **Standard v2 est une capacité provisionnée facturée à l'heure** tant qu'elle existe, que vous
l'appeliez ou non. Le point de terminaison privé, la zone DNS privée et l'ingestion de télémétrie sont aussi facturés.
**Obtenez l'approbation du coût avant l'étape 1** et nettoyez le jour même. Ce guide n'indique aucun prix : consultez la
calculatrice de prix Azure pour votre région.

## Prérequis et rôles nécessaires

- Modules 02 et 03 (**les deux étapes**) déployés avec les mêmes fichiers privés et le même état Terraform :
  `participant.tfvars.json`, `module02.tfvars.json`, `module03.tfvars.json` (avec `entra_auth_replace_key_gate = true`).
- Comptes de test Alice, Bob et Eve avec leurs attributions de rôles du module 03 ; `.workshop/module03-personas.json`
  (contrôle croisé facultatif).
- Terraform 1.16.6+, Azure CLI, PowerShell 7.4+. Fournisseurs de ressources `Microsoft.ApiManagement`, `Microsoft.Network` et
  `Microsoft.Web` inscrits (le contrôle préalable du module 00 vérifie l'inscription).
- La région doit proposer Standard v2 (exemple : `swedencentral`) ; vérifiez la disponibilité et les quotas avant de commencer.

**Participant :** Contributeur sur le groupe de ressources de l'atelier, plus le droit de créer une attribution de rôle limitée
au composant Application Insights (par exemple Role Based Access Control Administrator, restreint à Monitoring Metrics
Publisher, limité dans le temps). Le droit de rejoindre le sous-réseau (`Microsoft.Network/virtualNetworks/subnets/join/action`)
est inclus dans Contributeur sur le groupe. **Aucune modification Microsoft Entra** dans ce module.

## Étapes

### PowerShell

Depuis la racine du dépôt. Les étapes 2 à 4 modifient Azure : ne les exécutez qu'après approbation du plan **et du coût**.

**1. Vérifications hors ligne (sans Azure).**

```powershell
& .\modules\04-governed-gateway\validate.ps1 -Offline
```

**2. Fichier d'activation privé (ignoré par Git).** Facultatif : ajoutez `gateway_allowed_ip_ranges` (liste CIDR) ou modifiez
`gateway_rate_limit_calls` / `gateway_rate_limit_period`. Pour `gateway_publisher_email`, utilisez une adresse d'équipe ou une
adresse d'exemple.

```powershell
@{ enable_governed_gateway = $true; gateway_lock_function = $false } | ConvertTo-Json | Set-Content -LiteralPath .\.workshop\module04.tfvars.json
```

**3. Étape 1 : passerelle, point de terminaison privé et DNS privé.** Sélectionnez d'abord votre contexte approuvé
(`& .\scripts\select-azure-context.ps1`). Désormais, passez toujours les quatre fichiers de variables.

```powershell
$vars = '-var-file=..\..\.workshop\participant.tfvars.json', '-var-file=..\..\.workshop\module02.tfvars.json',
        '-var-file=..\..\.workshop\module03.tfvars.json', '-var-file=..\..\.workshop\module04.tfvars.json'
terraform '-chdir=infra\workload' init -lockfile=readonly
terraform '-chdir=infra\workload' plan @vars '-out=..\..\.workshop\module04.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
# Relire : environ 19 ajouts (réseau, DNS, point de terminaison privé, API Management, API, stratégies, journaliseur,
# diagnostics, identité et une attribution de rôle) et la mise à jour en place connue des app_settings. Puis, après approbation :
terraform '-chdir=infra\workload' apply '..\..\.workshop\module04.tfplan'
```

La création d'une instance Standard v2 prend plusieurs minutes. La Function est encore publique mais exige toujours un jeton
Entra (module 03) : rien n'est anonyme pendant l'étape 1. Testez l'URL de la passerelle
(`terraform -chdir=infra/workload output gateway_mcp_endpoint`) dans VS Code avant l'étape 2.

**4. Étape 2 : verrouiller la Function.** Seul le point de terminaison privé subsiste.

```powershell
$v = Get-Content -LiteralPath .\.workshop\module04.tfvars.json -Raw | ConvertFrom-Json
$v.gateway_lock_function = $true
$v | ConvertTo-Json | Set-Content -LiteralPath .\.workshop\module04.tfvars.json
terraform '-chdir=infra\workload' plan @vars '-out=..\..\.workshop\module04.tfplan'
# Relire : une mise à jour en place de la Function App (public_network_access_enabled = false). Après approbation :
terraform '-chdir=infra\workload' apply '..\..\.workshop\module04.tfplan'
```

Publiez vos modifications de code **avant** l'étape 2 : une fois l'accès public désactivé, les points de déploiement sont aussi privés.

**5. Connecter VS Code à la passerelle.** Dans votre configuration MCP **utilisateur**, remplacez le serveur `workshop-entra` par
l'URL de la passerelle. Ni en-tête ni clé : VS Code lit les PRM de la passerelle et vous connecte.

```json
{
  "servers": {
    "workshop-governed": { "type": "http", "url": "https://apim-mcp-<prefix>-<suffix>.azure-api.net/workshop-mcp/mcp" }
  }
}
```

En tant qu'Alice, demandez à Copilot de créer un ticket synthétique : VS Code demande votre **approbation** avant d'exécuter
l'outil d'écriture, puis l'appel réussit. En tant que Bob (autre profil VS Code), la même demande échoue avec HTTP 403.

**6. Contrôles opérateur, puis contrôles par profil.**

```powershell
& .\modules\04-governed-gateway\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
foreach ($persona in 'Alice', 'Bob', 'Eve') {
    $env:AZURE_CONFIG_DIR = Join-Path $PWD ".workshop\az-$($persona.ToLower())"
    az login --tenant $env:ARM_TENANT_ID --allow-no-subscriptions   # se connecter en tant que $persona dans le navigateur
    & .\modules\04-governed-gateway\validate.ps1 -TenantId $env:ARM_TENANT_ID -Persona $persona -Burst:($persona -eq 'Bob')
    az logout
}
Remove-Item Env:\AZURE_CONFIG_DIR
Start-Sleep -Seconds 300   # délai d'ingestion de la télémétrie
& .\modules\04-governed-gateway\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -CheckTelemetry
```

> **Résultat attendu** — messages du validateur ; pas encore une capture de votre tenant (extrait).
>
> ```text
> PASS gateway request without a token is refused with a challenge naming the gateway metadata (expected HTTP 401).
> PASS direct call to the Function host is refused from the internet: HTTP 403 (expected HTTP 403).
> PASS Alice get_service_health is allowed with Tools.Read (expected HTTP 200).
> PASS Bob create_ticket is denied by the gateway: Tools.Write is missing (expected HTTP 403).
> PASS Alice create_ticket is allowed with Tools.Write and queues one synthetic ticket (expected HTTP 200).
> PASS an unknown tool and a JSON-RPC message without a method are denied safely (expected HTTP 403 and HTTP 400).
> PASS Bob burst of <count> calls is throttled per caller object ID (expected HTTP 429).
> PASS Application Insights: <n> gateway requests and <n> tool traces with tool label and caller oid, no body, argument or token (expected HTTP 200 from Log Analytics).
> ```
>
> **Ce que cela signifie pour vous :** il n'y a plus qu'**une seule porte**, et la Function derrière elle est
> injoignable depuis internet. Être connecté ne veut plus dire « tout faire » : Bob lit, seule Alice écrit, et
> personne ne peut saturer le serveur. Les journaux disent **qui** a appelé **quel outil**, jamais ce qu'il a envoyé.

### Bash

```bash
bash ./modules/04-governed-gateway/validate.sh -Offline
printf '%s\n' '{"enable_governed_gateway": true, "gateway_lock_function": false}' > .workshop/module04.tfvars.json
source ./scripts/select-azure-context.sh
vars="-var-file=../../.workshop/participant.tfvars.json -var-file=../../.workshop/module02.tfvars.json -var-file=../../.workshop/module03.tfvars.json -var-file=../../.workshop/module04.tfvars.json"
terraform -chdir=infra/workload init -lockfile=readonly
terraform -chdir=infra/workload plan $vars -out=../../.workshop/module04.tfplan     # relire, approuver le coût
terraform -chdir=infra/workload apply ../../.workshop/module04.tfplan
jq '.gateway_lock_function = true' .workshop/module04.tfvars.json > .workshop/m04.tmp && mv .workshop/m04.tmp .workshop/module04.tfvars.json
terraform -chdir=infra/workload plan $vars -out=../../.workshop/module04.tfplan     # relire : une mise à jour en place
terraform -chdir=infra/workload apply ../../.workshop/module04.tfplan
bash ./modules/04-governed-gateway/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
for persona in Alice Bob Eve; do
  export AZURE_CONFIG_DIR="$PWD/.workshop/az-${persona,,}"
  az login --tenant "$ARM_TENANT_ID" --allow-no-subscriptions
  extra=""; [ "$persona" = "Bob" ] && extra="-Burst"
  bash ./modules/04-governed-gateway/validate.sh -TenantId "$ARM_TENANT_ID" -Persona "$persona" $extra
  az logout
done
unset AZURE_CONFIG_DIR
sleep 300
bash ./modules/04-governed-gateway/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -CheckTelemetry
```

## Ce que vous devez voir

| Action (via la passerelle sauf mention) | Résultat attendu | Signification |
|---|---|---|
| Requête MCP sans jeton | HTTP 401, `WWW-Authenticate: Bearer resource_metadata="https://apim-…/.well-known/oauth-protected-resource/workshop-mcp/mcp"` | La passerelle refuse en premier et renvoie vers ses propres métadonnées. |
| `GET` sur cette URL de métadonnées | HTTP 200 : `resource` = URL de la passerelle, votre tenant, `api://…/user_impersonation` | L'hôte privé de la Function n'apparaît jamais. |
| Jeton Microsoft Graph d'Alice | HTTP 401 | Mauvaise audience. |
| Bob : `tools/list`, `get_service_health` | HTTP 200 | `Tools.Read` suffit. |
| Bob : `create_ticket` | **HTTP 403** | `Tools.Write` manque. La Function ne voit jamais l'appel. |
| Alice : `create_ticket` | **HTTP 200**, un ticket synthétique | `Tools.Write` présent ; VS Code demande toujours d'approuver l'écriture. |
| Outil inconnu / message sans `method` | HTTP 403 / HTTP 400 | Les formats non pris en charge sont refusés, sans tentative d'interprétation. |
| Un utilisateur dépasse la limite d'appels | **HTTP 429** avec `Retry-After` | Limite par `oid` de l'appelant. Les limites sont approximatives. |
| Appel direct à `https://func-…azurewebsites.net/runtime/webhooks/mcp` | **HTTP 403** (ou pas de connexion) | Accès réseau public désactivé. |
| Application Insights | Requêtes avec statut et durée, traces `mcp-request` avec `mcp-tool` et `caller-oid` | Ni corps, ni argument, ni résultat, ni jeton. |

### Lire la documentation au moment de la démonstration

Ouvrez ces liens en regard du résultat de passerelle correspondant ci-dessus. API Management (APIM) applique ces contrôles ; la connexion du client ne suffit pas.

| Démonstration ou choix | Ce qu'il faut comprendre dans Microsoft Learn | Référence de stratégie ou d'API |
|---|---|---|
| Sans jeton ou avec une mauvaise audience : HTTP 401 | [Sécuriser les serveurs MCP](https://learn.microsoft.com/azure/api-management/secure-mcp-servers) : protéger le point d'entrée gouverné. | [validate-azure-ad-token](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy) : tenant, audience, client autorisé et revendications requises. |
| Les métadonnées indiquent la passerelle, pas la Function privée | [Autorisation MCP App Service et métadonnées de ressource protégée (**Preview**)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp) explique la découverte de la ressource. | [Gérer les serveurs MCP par programme (**Preview**)](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) décrit l'API de gestion MCP utilisée par Terraform. Les métadonnées seules n'accordent aucun accès. |
| Bob lit mais reçoit HTTP 403 pour `create_ticket` ; Alice peut écrire après approbation du client | Les [rôles applicatifs](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps) fournissent `Tools.Read` / `Tools.Write`. L'atelier les vérifie explicitement par outil. | [choose](https://learn.microsoft.com/azure/api-management/choose-policy) et les [expressions de stratégie](https://learn.microsoft.com/azure/api-management/api-management-policy-expressions) appliquent la décision dans `policies/mcp-server.xml`. Un outil inconnu ou un message mal formé est aussi refusé. |
| Une rafale d'un appelant reçoit HTTP 429 | [rate-limit-by-key](https://learn.microsoft.com/azure/api-management/rate-limit-by-key-policy) : la clé est ici l'`oid` validé de l'appelant, pas une clé d'abonnement. Les limites distribuées sont approximatives. | La même référence décrit `calls`, `renewal-period` et `counter-key`. |
| L'accès direct à la Function est bloqué | Les [options réseau Functions](https://learn.microsoft.com/azure/azure-functions/functions-networking-options) expliquent les points de terminaison privés et leur prise en charge par Flex Consumption. | [Exposer un serveur MCP existant](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server) décrit le proxy de passerelle. Conservez l'architecture réseau Standard v2 de ce guide. |
| La télémétrie montre statuts et latence, jamais les contenus | [Télémétrie MCP par défaut](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers) : lisez les sections sur la télémétrie par défaut et les requêtes. | La [stratégie trace](https://learn.microsoft.com/azure/api-management/trace-policy) ajoute le nom fixe de l'outil et l'ID de l'appelant. Conservez zéro octet de corps ; ne suivez pas les étapes facultatives d'activation des journaux de contenu de la page liée. |

L'approbation d'une écriture par le client est distincte du contrôle de rôle par la passerelle. Aucun des deux ne remplace l'autre.
Liens documentaires vérifiés le 2026-10-16 ; les résultats attendus ne s'observent qu'après un déploiement réel approuvé.

## Valider

`validate.ps1` (ou `validate.sh`) exécute toujours d'abord les vérifications hors ligne : la stratégie valide le jeton Entra pour
la seule audience MCP (pas l'URL de la passerelle comme audience), exige `user_impersonation`, associe `create_ticket` à `Tools.Write` et
les autres outils à `Tools.Read` à partir du corps lu avec `preserveContent: true`, refuse les appels mal formés ou inconnus,
limite le débit par `oid`, n'ajoute le filtre IP que s'il est configuré, répond avec le défi PRM de la passerelle et ne lit
jamais le corps de la réponse ; Terraform conserve Standard v2, l'intégration sortante, le point de terminaison privé, le
verrouillage en étape 2 et l'absence de clé d'abonnement ; les diagnostics conservent 0 octet de corps et aucun en-tête aux deux
portées ; aucun motif de secret ; format, schéma et tests simulés Terraform pour les deux racines.

Sortie hors ligne (ce résultat ne prouve **pas** le déploiement) :

```text
PASS gateway policy: Entra token for the MCP audience only, create_ticket requires Tools.Write, other tools Tools.Read, malformed or unknown calls denied, per-oid rate limit, optional ip-filter, gateway PRM challenge (expected HTTP 401/403/429).
PASS Protected Resource Metadata is answered by the gateway itself and never names the private Function host (expected HTTP 200).
PASS Terraform: Standard v2 public gateway, outbound integration, Function private endpoint and private DNS, public access disabled only in stage 2, MCP API Preview with no subscription key (expected HTTP 403 on the direct host).
PASS diagnostics: 0 body bytes for frontend/backend requests/responses at both scopes, no header logged (no Authorization), no client IP (expected HTTP N/A).
PASS no access token, subscription key, function key, SAS or client secret in module 04 or workload files (expected HTTP N/A).
PASS Terraform format, schema and mock-only plans for infra/entra and infra/workload (expected HTTP N/A; no live plan/apply).
PASS offline checks only. Module 04 is NOT deployed or validated by this result.
```

### Vérifier la passerelle réelle après déploiement

Modes en ligne, après un déploiement approuvé des deux étapes :

- **Opérateur** (`-TenantId -SubscriptionId`) : HTTP 401 de la passerelle avec son défi, PRM de la passerelle HTTP 200,
  HTTP 401 pour un jeton Graph, hôte direct de la Function HTTP 403, `publicNetworkAccess = Disabled` et diagnostics à 0 octet
  lus dans Azure Resource Manager. `-CheckTelemetry` interroge ensuite Log Analytics : les requêtes de la passerelle et les
  traces `mcp-request` existent, sans corps, argument ni valeur Authorization.
- **Profil** (`-TenantId -Persona Alice|Bob|Eve`) : initialize et `tools/list` HTTP 200 ; `get_service_health` HTTP 200 ;
  `create_ticket` HTTP 403 pour Bob et HTTP 200 pour Alice ; outil inconnu HTTP 403 et méthode absente HTTP 400 ; Eve n'obtient
  pas de jeton (`AADSTS50105`). `-Burst` envoie 10 appels de plus que la limite et attend HTTP 429.

Le module n'est `validated` que lorsque tout cela réussit sur un abonnement neuf, juste après les modules 00 à 03.

## Dépannage

| Symptôme | Vérification |
|---|---|
| `enable_governed_gateway needs ... entra_auth_replace_key_gate` | Terminez les deux étapes du module 03 et passez `module03.tfvars.json`. |
| Le plan prévoit de détruire la passerelle ou l'authentification | Un fichier de variables manque. Passez toujours les quatre fichiers. |
| HTTP 500/502 de la passerelle après l'étape 2 | DNS : le lien de zone DNS privée et le groupe de zones du point de terminaison privé doivent exister ; attendez quelques minutes. |
| HTTP 401 pour Alice via la passerelle, alors que les PRM fonctionnent | Le jeton a été demandé pour une autre ressource. Utilisez la sortie `mcp_auth_audience` ; la passerelle n'accepte que l'audience de l'API MCP. |
| HTTP 403 pour Alice sur chaque appel | Son application cliente n'est pas autorisée (`mcp_allowed_client_ids`), ou le jeton n'a pas l'étendue `user_impersonation`. |
| Le streaming s'interrompt ou les outils se bloquent | Quelqu'un a activé la journalisation des corps ou une stratégie lit le corps de la réponse. Gardez 0 octet à chaque portée. |
| Pas de HTTP 429 pendant la rafale | Les limites sont approximatives dans une passerelle distribuée ; relancez `-Burst` ou baissez `gateway_rate_limit_calls` pour l'exercice. |
| La publication du code échoue après l'étape 2 | Normal : les points de déploiement sont désormais privés. Publiez avant l'étape 2, ou depuis le réseau virtuel. |
| Nom déjà utilisé après un nettoyage | Suppression réversible d'API Management : purgez l'instance (voir Nettoyer). |

## Nettoyer

Nettoyez dans l'ordre inverse. Le script commence par un plan et refuse toute modification hors du module 04 ; lancez-le une fois
pour relire, puis avec `-Apply`. Il est idempotent. L'auteur ne l'a pas exécuté : aucun déploiement n'existe.

```powershell
& .\modules\04-governed-gateway\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
& .\modules\04-governed-gateway\cleanup.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID -Apply
Remove-Item -LiteralPath .\.workshop\module04.tfvars.json -ErrorAction SilentlyContinue
# Facultatif, pour réutiliser le nom sous 48 heures (suppression réversible d'API Management) :
az apim deletedservice purge --service-name apim-mcp-<prefix>-<suffix> --location <region>
```

```bash
bash ./modules/04-governed-gateway/cleanup.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" -Apply
rm -f .workshop/module04.tfvars.json
```

La phase 1 remet la Function dans son état du module 03 (toujours protégée par Entra, jamais anonyme). La phase 2 supprime la
passerelle, les API, stratégies, diagnostics, le journaliseur, l'identité et le rôle de la passerelle, le point de terminaison
privé, le DNS privé, les sous-réseaux, le NSG et le réseau virtuel. Poursuivez ensuite avec le nettoyage des modules 03 et 02 si
vous avez terminé. Remplacez `workshop-governed` dans VS Code. Si vous enchaînez avec le module 05, conservez tout.

## Aller plus loin

- Lisez [policies/mcp-server.xml](policies/mcp-server.xml) : quelle ligne transforme le `create_ticket` de Bob en HTTP 403, et
  pourquoi faut-il lire le corps avec `preserveContent: true` ?
- Pourquoi la passerelle transmet-elle le même jeton à la Function, et pourquoi n'est-ce pas un « relais de jeton » ? Comparez
  avec le module 05.
- Renseignez `gateway_allowed_ip_ranges` avec votre plage de sortie et observez la réponse HTTP 403 depuis un autre réseau.
- **04b facultatif (documentation seulement) :** API Management peut aussi exposer une **API REST gérée comme serveur MCP**, où
  chaque opération devient un outil ([Exposer une API REST comme serveur MCP](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server),
  lab AI-Gateway `mcp-from-api`). Les mêmes stratégies `validate-azure-ad-token`, de rôle et de débit s'appliquent. Hors du
  parcours principal et non déployé par ce dépôt.

## Sources

- [Exposer et gouverner un serveur MCP existant](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server)
- [Sécuriser l'accès aux serveurs MCP dans API Management](https://learn.microsoft.com/azure/api-management/secure-mcp-servers)
- [Serveurs MCP dans Azure API Management](https://learn.microsoft.com/azure/api-management/mcp-server-overview)
- [Gérer les serveurs MCP par programmation (REST, Bicep, Azure CLI, Terraform ; 2025-09-01-preview)](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api)
- [Stratégie validate-azure-ad-token](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy),
  [stratégie rate-limit-by-key](https://learn.microsoft.com/azure/api-management/rate-limit-by-key-policy),
  [stratégie ip-filter](https://learn.microsoft.com/azure/api-management/ip-filter-policy)
- [Intégrer API Management à Application Insights (chaîne de connexion + identité managée, octets de contenu)](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights)
- [Intégration au réseau virtuel sortante de Standard v2](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound)
- [Points de terminaison privés pour les applications App Service et Functions](https://learn.microsoft.com/azure/app-service/overview-private-endpoint)
- [Options réseau d'Azure Functions](https://learn.microsoft.com/azure/azure-functions/functions-networking-options)
- [Azure-Samples/AI-Gateway, labs mcp-prm-oauth et mcp-client-authorization à 1679e31](https://github.com/Azure-Samples/AI-Gateway/tree/1679e3137d2fe7592d2a668d77ff71550d35b69e/labs)
- [RFC 9728 OAuth 2.0 Protected Resource Metadata](https://www.rfc-editor.org/rfc/rfc9728)
- [Fournisseur AzAPI 2.13.0](https://registry.terraform.io/providers/Azure/azapi/2.13.0/docs) et [AzureRM 5.9.0 API Management](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/api_management.html.markdown)

Dernière vérification : 2026-10-15. Rédigé et vérifié hors ligne uniquement ; pas encore déployé ni validé dans Azure.

# Module 06 - Observer et inventorier (niveau 4)

[English](README.md)

> [!NOTE]
> Statut : **authored**. Les vérifications hors ligne passent. Ce module n'a pas été validé en direct dans un tenant Azure.
> Toutes les données sont synthétiques (Contoso, Alice, Bob, Eve). Ne collez jamais un jeton, un prompt ou un argument d'outil dans un journal, un ticket ou une diapositive.

## Objectif

Rendre visible le serveur MCP gouverné. À la fin, vous pouvez :

1. Interroger, en KQL et filtrées sur le trafic MCP, toutes les requêtes MCP arrivées à API Management dans Application Insights.
2. Enregistrer le serveur MCP dans un inventaire Azure API Center afin que d'autres équipes puissent le découvrir.
3. Savoir où une entrée de serveur MCP apporté par le client (BYO) est listée dans le centre d'administration Microsoft 365, et ce que cette entrée prouve et ne prouve pas.

## Pourquoi c'est important

Un point de terminaison gouverné que personne ne voit n'est pas réellement gouverné. Le module 04 a placé une porte devant les outils. Le module 05 a prouvé qui est l'appelant. Ce module répond aux questions suivantes : qu'est-ce qui a été appelé, par qui, à quelle fréquence, et qu'est-ce qui a échoué, sans jamais stocker le contenu de l'appel.

L'observabilité et l'inventaire sont aussi des endroits où surviennent les erreurs de protection des données. La journalisation des charges utiles capture les prompts et les résultats d'outils. Ce module la laisse désactivée et montre comment vérifier qu'elle le reste.

**Règles de journalisation de ce module :** zéro octet de corps, aucun jeton, aucun prompt et aucun argument ou résultat d'outil dans un journal, une requête, un classeur, un ticket ou une diapositive. Ne journalisez que les métadonnées : opération, nom de l'outil, statut, durée et type d'erreur.

## Ce que vous déployez

Ce module ne déploie **aucune nouvelle ressource Azure**. Il réutilise l'instance API Management et le composant Application Insights des modules précédents, et ajoute :

| Élément | Type | Emplacement | Statut |
|---|---|---|---|
| Requête KQL du trafic MCP | Fichier KQL (`queries/mcp-traffic.kql`) | Dossier de ce module | Stable |
| Enregistrement du serveur MCP dans API Center | Asset d'un centre API | Portail Azure (étapes manuelles) | **Préversion** |
| Entrée de serveur MCP BYO | Entrée dans le centre d'administration Microsoft 365 | Centre d'administration Microsoft 365 | **Préversion** |
| Agent 365 avec API Management (démo uniquement) | Argumentaire optionnel, voir « Aller plus loin » | Non construit par les participants | **Préversion** |

Aucun Terraform n'est utilisé. Le module n'a pas de dossier `infra/` car il n'ajoute aucune infrastructure. Deux étapes touchent des paramètres au niveau du tenant (l'entrée BYO et une éventuelle stratégie Agent 365). Elles sont réalisées par un administrateur du tenant, jamais par un participant.

## Prérequis et rôles requis

- Modules 00 à 05 terminés, avec le point de terminaison MCP d'APIM qui répond.
- PowerShell 7.4 ou plus récent (`pwsh`) et, pour les étapes Linux ou macOS, bash.
- Azure CLI, connecté à un abonnement non productif approuvé que vous possédez. N'exécutez pas ces étapes dans un tenant de participant depuis le côté présentateur.
- **Lecteur** sur le composant Application Insights, pour exécuter les requêtes KQL.
- Pour API Center : un rôle qui autorise l'enregistrement d'assets dans le centre API. Confirmez le nom exact du rôle intégré dans la page des rôles intégrés Azure RBAC avant de l'attribuer. Ce module n'en suppose aucun.
- Pour l'entrée BYO : un administrateur informatique dans le centre d'administration Microsoft 365. Le participant n'a pas besoin de ce rôle et ne doit pas le demander.
- Pour Agent 365 (démo optionnelle) : un administrateur du tenant détenant le rôle Agent 365 MCP Gateway Policy Operator. Jamais attribué à un participant.

## Étapes

Chaque étape propose une version PowerShell et une version bash. Les deux appellent les mêmes ressources hors ligne et KQL.

### Étape 1 - Exécuter les vérifications hors ligne

Confirmez les fichiers du module, la requête KQL et les règles de journalisation avant d'interroger quoi que ce soit.

PowerShell :

```powershell
pwsh ./modules/06-observe-inventory/validate.ps1 -Offline
```

bash :

```bash
./modules/06-observe-inventory/validate.sh --offline
```

### Étape 2 - Confirmer que la journalisation des charges utiles est désactivée

Dans l'instance APIM, confirmez que la journalisation des charges utiles pour l'API MCP est désactivée. N'activez pas la capture de `gen_ai.tool.call.arguments` ni de `gen_ai.tool.call.result` pour cet atelier.

### Étape 3 - Interroger le trafic MCP dans Application Insights

Ouvrez `modules/06-observe-inventory/queries/mcp-traffic.kql` et exécutez-le dans le volet **Logs** du composant Application Insights où API Management écrit.

PowerShell (Azure CLI, avec un GUID d'espace de travail fictif) :

```powershell
$ws = '<log-analytics-workspace-guid>'
$kql = Get-Content -Raw ./modules/06-observe-inventory/queries/mcp-traffic.kql
az monitor log-analytics query --workspace $ws --analytics-query $kql --timespan PT24H -o table
```

bash :

```bash
ws='<log-analytics-workspace-guid>'
az monitor log-analytics query --workspace "$ws" \
  --analytics-query "$(cat modules/06-observe-inventory/queries/mcp-traffic.kql)" \
  --timespan PT24H -o table
```

La requête ne lit que des métadonnées : nom d'opération, nom d'outil, statut, durée et type d'erreur. Elle ne lit jamais les corps de requête ou de réponse.

### Étape 4 - Enregistrer le serveur MCP dans API Center (Préversion)

L'inventaire API Center est en **Préversion**. Dans le portail Azure :

1. Ouvrez votre centre API et choisissez **Assets**.
2. Choisissez **+ Register an asset**, puis **MCP server**.
3. Saisissez un titre, un résumé et une description. Utilisez un texte synthétique, par exemple « Contoso governed MCP demo ».
4. Sous **Remotes**, ajoutez l'URL d'exécution du point de terminaison MCP d'API Management et choisissez un environnement.
5. Ajoutez une version, une étape de cycle de vie et une licence.
6. Choisissez **Create**. API Center génère les définitions SSE et Streamable.

Contrôle : l'asset apparaît dans **Assets** avec l'environnement choisi.

### Étape 5 - Confirmer l'entrée BYO (Préversion)

L'entrée BYO MCP est en **Préversion** et n'est pas destinée à la production. Un administrateur informatique du tenant la examine et l'approuve dans le centre d'administration Microsoft 365. En tant que participant, vous confirmez seulement que l'entrée existe et que son statut est celui défini par l'administrateur. Vous ne l'approuvez pas vous-même.

Contrôle : l'entrée affiche le nom du serveur et un état d'approbation. Un état d'approbation ne prouve pas que le serveur est sûr. Les modules 04 et 05 appliquent toujours les contrôles.

## Ce que vous devriez voir

- La requête KQL renvoie des lignes avec `api.type` égal à `Mcp`, une ligne par requête, pour `tools/list` et `tools/call`.
- Les colonnes contiennent des noms d'outils et des codes de statut, et aucun corps de requête, corps de réponse, jeton, prompt ou argument d'outil.
- L'asset API Center existe, avec une URL d'exécution et un environnement.
- Le validateur hors ligne affiche une ligne `PASS` par vérification et se termine avec le code 0.

## Valider

Hors ligne (sans accès Azure) :

```powershell
pwsh ./modules/06-observe-inventory/validate.ps1 -Offline
```

```bash
./modules/06-observe-inventory/validate.sh --offline
```

Chaque vérification affiche `PASS` ou `FAIL` sur une ligne. Une ligne `FAIL` nomme le fichier ou la règle en échec. Les vérifications en direct (résultats KQL, asset API Center, entrée BYO) sont manuelles dans cette version et ne sont pas exécutées par le script.

## Dépannage

| Symptôme | Cause probable | Correction |
|---|---|---|
| La requête KQL ne renvoie aucune ligne | Le trafic est plus ancien que la fenêtre, ou les diagnostics ne sont pas activés sur l'API APIM | Élargissez `--timespan`, puis confirmez le paramètre de diagnostic APIM pour l'API MCP. |
| Des lignes existent mais `tool.name` est vide | Seul `tools/list` a été appelé, ou l'opération MCP n'a pas été classée | Appelez un outil une fois depuis le client, puis relancez. |
| Des champs de charge utile apparaissent dans les journaux | La journalisation des charges utiles a été activée | Désactivez-la dans APIM, supprimez les lignes concernées selon votre politique de rétention, et signalez-le comme constat. |
| L'asset API Center ne peut pas être créé | Le rôle manque, ou l'environnement n'existe pas | Confirmez le rôle dans RBAC et créez d'abord l'environnement. |
| L'entrée BYO est absente | Fonctionnalité en préversion non activée, ou administrateur n'a pas approuvé | Demandez à l'administrateur informatique du tenant. Ne demandez pas le rôle vous-même. |

## Nettoyer

Ce module ne crée aucune ressource Azure, donc le nettoyage est un rapport protégé.

PowerShell :

```powershell
pwsh ./modules/06-observe-inventory/cleanup.ps1
pwsh ./modules/06-observe-inventory/cleanup.ps1 -Apply
```

bash :

```bash
./modules/06-observe-inventory/cleanup.sh
./modules/06-observe-inventory/cleanup.sh --apply
```

Sans `-Apply` (ou `--apply`), le script ne fait que rapporter. Avec le drapeau, il ne supprime que ce que ce module a créé, c'est-à-dire rien. Pour supprimer l'asset API Center, supprimez-le dans le portail. Retirez l'entrée BYO uniquement via le centre d'administration Microsoft 365, par un administrateur.

## Aller plus loin

- **Alertes** : créez une alerte de journal Azure Monitor sur le taux de réponses `403` de l'opération MCP. Gardez-la synthétique et agrégée.
- **Agent 365 (Préversion, démo uniquement)** : Agent 365 peut inventorier les serveurs MCP exposés via API Management et bloquer un serveur que la stratégie n'autorise pas (l'appelant reçoit 403). Le contrôle au niveau des outils, l'observabilité et l'intégration Defender ou Purview nécessitent le niveau AI Gateway, lui aussi en Préversion. Le consentement au niveau du tenant vient d'un administrateur du tenant. C'est un argumentaire pour le présentateur, sans étape pour les participants.
- **Rétention** : décidez combien de temps la télémétrie MCP est conservée, et alignez-la sur la politique de protection des données.

## Sources

Les pages officielles Microsoft Learn utilisées pour ce module sont consignées avec leurs dates de dernière vérification dans `docs/sources.md`, sous le module 06 :

- Surveiller le trafic des serveurs MCP dans API Management (table `requests` d'Application Insights, `customDimensions`, journalisation des charges utiles désactivée par défaut).
- Inventorier et découvrir les serveurs MCP dans Azure API Center (flux d'enregistrement en Préversion).
- Apporter votre propre serveur MCP dans le centre d'administration Microsoft 365 (Préversion).
- Agent 365 avec API Management (Préversion).

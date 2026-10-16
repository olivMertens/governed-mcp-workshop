# 06 - Observer et inventorier (niveau 4)

[English](README.md)

## Objectif

Votre serveur MCP est protégé par Microsoft Entra ID (module 03), joignable uniquement via
Azure API Management (APIM, module 04), et il appelle les données en aval avec la bonne identité (module 05).
Reste une question : **voyez-vous ce qui se passe, et les autres équipes trouvent-elles ce serveur ?**

Ce module y répond en deux parties :

- **Observer :** quel outil, quel appelant, quand, quel statut, quelle durée. Vous lisez ces métadonnées dans
  Application Insights avec une requête KQL (Kusto Query Language).
- **Inventorier :** inscrire le serveur dans un catalogue (existence, responsable, adresse). Vous l'enregistrez dans
  Azure API Center (**Preview**). Un administrateur peut aussi le déclarer dans le centre d'administration
  Microsoft 365 comme serveur MCP apporté par le client (BYO) (**Preview**).

Vous ne déployez rien de nouveau. Vous apprenez aussi ce que prouve chaque élément (journal, inventaire,
déclaration BYO) et ce qu'il ne prouve pas.

## Pourquoi c'est important

Un serveur que personne ne voit n'est pas gouverné. Sans métadonnées, impossible de répondre à « qui a utilisé l'outil
d'écriture hier ? ». Sans inventaire, les équipes créent des serveurs en double ou utilisent des serveurs inconnus
(« shadow MCP »).

Deux pièges à éviter :

- **Trop journaliser.** Stocker les prompts, les arguments ou les résultats d'outils fait fuiter des données.
  Cet atelier ne journalise que des métadonnées.
- **Trop faire confiance.** Une ligne de journal ou une entrée de catalogue est une preuve, pas un contrôle. HTTP 200 ne
  prouve pas que l'outil a réussi, et une entrée d'inventaire n'autorise personne.

**Règles de journalisation de ce module :** zéro octet de corps, aucun jeton, aucun prompt et aucun argument ou résultat d'outil dans un journal, une requête, un classeur, un ticket ou une diapositive. Ne journalisez que les métadonnées : opération, nom de l'outil, statut, durée et type d'erreur.

## Ce que vous déployez

Ce module ne déploie **aucune nouvelle ressource Azure**. Il réutilise l'instance API Management et le composant Application Insights des modules précédents, et ajoute :

| Élément | Type | Emplacement | Statut |
|---|---|---|---|
| Requête KQL du trafic MCP | Fichier KQL (`queries/mcp-traffic.kql`) | Dossier de ce module | Stable |
| Enregistrement du serveur MCP dans API Center | Asset d'un centre API | Portail Azure (étapes manuelles) | **Préversion** |
| Entrée de serveur MCP BYO | Entrée dans le centre d'administration Microsoft 365 | Centre d'administration Microsoft 365 | **Préversion** |
| Agent 365 avec API Management (démo uniquement) | Argumentaire optionnel, voir « Aller plus loin » | Non mis en place par les participants | **Préversion** |

Ce module n'utilise pas Terraform. Il n'a pas de dossier `infra/` car il n'ajoute aucune infrastructure. Deux étapes concernent des paramètres au niveau du tenant (l'entrée BYO et une éventuelle stratégie Agent 365). Elles sont réalisées par un administrateur du tenant, jamais par un participant.

## Prérequis et rôles requis

- Modules 00 à 05 terminés ; le point de terminaison MCP d'APIM doit répondre.
- PowerShell 7.4 ou version ultérieure (`pwsh`) et, pour les étapes Linux ou macOS, bash.
- Azure CLI, connecté à un abonnement hors production approuvé que vous possédez. En tant que présentateur, n'exécutez pas ces étapes dans le tenant d'un participant.
- **Lecteur** sur le composant Application Insights, pour exécuter les requêtes KQL.
- Pour API Center : un rôle qui autorise l'enregistrement d'assets dans le centre API. Confirmez le nom exact du rôle intégré dans la page des rôles intégrés Azure RBAC avant de l'attribuer. Ce module ne présuppose aucun rôle précis.
- Pour l'entrée BYO : un administrateur informatique dans le centre d'administration Microsoft 365. Le participant n'a pas besoin de ce rôle et ne doit pas le demander.
- Pour Agent 365 (démo optionnelle) : un administrateur du tenant détenant le rôle Agent 365 MCP Gateway Policy Operator. Ce rôle n'est jamais attribué à un participant.

## Étapes

### Lire les trois circuits séparément

![Les appels passent par API Management ; les métadonnées vont dans Application Insights ; API Center inventorie seulement la passerelle.](../../assets/architecture/06.fr.svg)

Application Insights ne contrôle pas les droits. API Center ne relaie pas les appels.
Ni une inscription ni un statut HTTP réussi ne prouvent la réussite d'un outil.

### Que peut-on réellement tracer ?

Kusto Query Language (KQL) est le langage de requête des journaux. Il lit les traces enregistrées, pas le raisonnement de l'agent.

| Preuve | Présente ici | Limite |
|---|---|---|
| Heure, opération, statut HTTP, durée | Sélectionnés par la requête fournie | Délai d'ingestion, échantillonnage et limite de 200 lignes : ce n'est pas un audit exhaustif |
| Nom de l'outil et type d'erreur | Sélectionnés si les diagnostics MCP les émettent | Un champ vide ne signifie pas qu'aucun outil n'a été exécuté |
| Identifiant objet de l'appelant et corrélation | La stratégie du module 04 émet `caller-oid` dans les traces `workshop-mcp-gateway` ; les requêtes ont une corrélation | La requête fournie ne sélectionne pas l'identité et ne joint pas les traces ; les vérifier séparément |
| Refus du service en aval | Résultat MCP à examiner dans le client | HTTP 200 peut contenir `isError: true` ; succès HTTP ne signifie pas succès de l'outil |
| Confirmation humaine, prompt, arguments, résultat | Non collectés ici | La passerelle ne prouve pas la confirmation et ne conserve pas la conversation |

En accès applicatif, les journaux en aval identifient l'application, pas Alice ou Bob.
OBO peut conserver l'identité utilisateur, mais l'audit en aval exige sa propre configuration et ses propres droits.
Reliez les métadonnées disponibles entre services ; n'ajoutez jamais de jeton ni de corps pour combler un manque.

**Question :** une requête renvoie HTTP 200. Cela prouve-t-il que Bob a lu le rapport ?

<details>
<summary>Afficher la réponse</summary>

Non. Storage peut refuser Bob et le serveur renvoyer une erreur d'outil MCP dans HTTP 200.
Vérifiez le résultat dans le client et les traces disponibles en aval. Une requête de journaux vide ne prouve ni réussite ni absence d'activité.

</details>

### Étape 1 - Exécuter les vérifications hors ligne

Vérifiez les fichiers du module, la requête KQL et les règles de journalisation avant de lancer la moindre requête.

PowerShell :

```powershell
pwsh ./modules/06-observe-inventory/validate.ps1 -Offline
```

bash :

```bash
./modules/06-observe-inventory/validate.sh --offline
```

### Étape 2 - Confirmer que la journalisation des charges utiles est désactivée

Dans l'instance APIM, vérifiez que la journalisation des charges utiles pour l'API MCP est désactivée. N'activez pas la capture de `gen_ai.tool.call.arguments` ni de `gen_ai.tool.call.result` pour cet atelier.

### Étape 3 - Interroger le trafic MCP dans Application Insights

Ouvrez `modules/06-observe-inventory/queries/mcp-traffic.kql` et exécutez-le dans le volet **Logs** du composant Application Insights dans lequel écrit API Management.

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

1. Ouvrez votre centre API et sélectionnez **Assets**.
2. Choisissez **+ Register an asset**, puis **MCP server**.
3. Saisissez un titre, un résumé et une description. Utilisez un texte synthétique, par exemple « Contoso governed MCP demo ».
4. Sous **Remotes**, ajoutez l'URL d'exécution du point de terminaison MCP d'API Management et choisissez un environnement.
5. Ajoutez une version, une étape de cycle de vie et une licence.
6. Choisissez **Create**. API Center génère les définitions SSE et Streamable.

Contrôle : l'asset apparaît dans **Assets** avec l'environnement choisi.

### Étape 5 - Confirmer l'entrée BYO (Préversion)

L'entrée BYO MCP est en **Préversion** et n'est pas destinée à la production. Un administrateur informatique du tenant l'examine et l'approuve dans le centre d'administration Microsoft 365. En tant que participant, vous vérifiez seulement que l'entrée existe et que son statut est celui défini par l'administrateur. Vous ne l'approuvez pas vous-même.

Contrôle : l'entrée affiche le nom du serveur et un état d'approbation. Un état d'approbation ne prouve pas que le serveur est sûr. Ce sont toujours les modules 04 et 05 qui appliquent les contrôles.

## Ce que vous devriez voir

- Si du trafic MCP a été ingéré, la requête KQL renvoie les lignes disponibles avec `api.type` égal à `Mcp`, pour `tools/list` et `tools/call`. Ce n'est pas un audit exhaustif.
- Les colonnes contiennent des noms d'outils et des codes de statut, mais aucun corps de requête, corps de réponse, jeton, prompt ou argument d'outil.
- L'asset API Center existe, avec une URL d'exécution et un environnement.
- Le validateur hors ligne affiche une ligne `PASS` par vérification et se termine avec le code de sortie 0.

## Valider

Hors ligne (sans accès Azure) :

```powershell
pwsh ./modules/06-observe-inventory/validate.ps1 -Offline
```

```bash
./modules/06-observe-inventory/validate.sh --offline
```

Chaque vérification affiche `PASS` ou `FAIL` sur une ligne. Une ligne `FAIL` indique le fichier ou la règle en cause. Les vérifications en direct (résultats KQL, asset API Center, entrée BYO) sont manuelles dans cette version et ne sont pas exécutées par le script.

## Dépannage

| Symptôme | Cause probable | Correction |
|---|---|---|
| La requête KQL ne renvoie aucune ligne | Le trafic est plus ancien que la période interrogée, ou les diagnostics ne sont pas activés sur l'API APIM | Élargissez `--timespan`, puis vérifiez le paramètre de diagnostic APIM pour l'API MCP. |
| Des lignes existent mais `tool.name` est vide | Seul `tools/list` a été appelé, ou l'opération MCP n'a pas été classée | Appelez un outil une fois depuis le client, puis relancez la requête. |
| Des champs de charge utile apparaissent dans les journaux | La journalisation des charges utiles a été activée | Désactivez-la dans APIM, supprimez les lignes concernées selon votre politique de rétention, et consignez-le comme constat. |
| L'asset API Center ne peut pas être créé | Le rôle n'est pas attribué, ou l'environnement n'existe pas | Vérifiez le rôle dans RBAC et créez d'abord l'environnement. |
| L'entrée BYO est absente | Fonctionnalité en préversion non activée, ou l'administrateur ne l'a pas approuvée | Adressez-vous à l'administrateur informatique du tenant. Ne demandez pas le rôle vous-même. |

## Nettoyer

Ce module ne crée aucune ressource Azure : le nettoyage se limite donc à un rapport protégé.

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

Sans `-Apply` (ou `--apply`), le script se contente d'un rapport. Avec l'option, il ne supprime que ce que ce module a créé, c'est-à-dire rien. Pour supprimer l'asset API Center, passez par le portail. Seul un administrateur peut retirer l'entrée BYO, et uniquement via le centre d'administration Microsoft 365.

## Aller plus loin

- **Alertes** : créez une alerte de journal Azure Monitor sur le taux de réponses `403` de l'opération MCP. Gardez-la synthétique et agrégée.
- **Agent 365 (Préversion, démo uniquement)** : Agent 365 peut inventorier les serveurs MCP exposés via API Management et bloquer un serveur que la stratégie n'autorise pas (l'appelant reçoit 403). Le contrôle au niveau des outils, l'observabilité et l'intégration Defender ou Purview nécessitent le niveau AI Gateway, lui aussi en Préversion. Le consentement au niveau du tenant est donné par un administrateur du tenant. C'est un argumentaire pour le présentateur, sans étape pour les participants.
- **Rétention** : décidez de la durée de conservation de la télémétrie MCP et alignez-la sur la politique de protection des données.

## Sources

Les pages officielles Microsoft Learn utilisées pour ce module sont consignées avec leurs dates de dernière vérification dans `docs/sources.md`, sous le module 06 :

- [Surveiller le trafic MCP](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers) : dimensions par défaut et journalisation du contenu, maintenue désactivée ici.
- [Intégration Application Insights](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) : échantillonnage et corrélation.
- [Inventaire API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server) (enregistrement en Préversion).
- [Apporter son serveur MCP](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) (Préversion).
- [Agent 365 avec API Management](https://learn.microsoft.com/azure/api-management/agent-365) (Préversion ; argumentaire facultatif, non revérifié ici).

Dernière vérification : 2026-10-16 pour le lecteur et les précisions de traçabilité. Argumentaire Agent 365 : 2026-10-14.

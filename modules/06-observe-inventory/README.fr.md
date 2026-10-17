# 06 - Observer et inventorier (niveau 4)

[English](README.md)

## Objectif

Microsoft Entra ID protège votre serveur MCP (module 03). Le serveur n'est joignable que par
Azure API Management (APIM, module 04) et il accède aux données en aval avec la bonne identité (module 05).
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

> [!WARNING]
> **Règles de journalisation de ce module :** zéro octet de corps, aucun jeton, aucun prompt et aucun argument ou résultat d'outil dans un journal, une requête, un classeur, un ticket ou une diapositive. Ne journalisez que les métadonnées : opération, nom de l'outil, statut, durée et type d'erreur.

## Ce que vous déployez

Ce module ne déploie **aucune nouvelle ressource Azure**. Il réutilise l'instance API Management et le composant Application Insights des modules précédents, et ajoute :

| Élément | Type | Emplacement | Statut |
|---|---|---|---|
| Requête KQL du trafic MCP | Fichier KQL (`queries/mcp-traffic.kql`) | Dossier de ce module | Stable |
| Enregistrement du serveur MCP dans API Center | Asset d'un centre API | Portail Azure (étapes manuelles) | **Préversion** |
| Entrée de serveur MCP BYO | Entrée dans le centre d'administration Microsoft 365 | Centre d'administration Microsoft 365 | **Préversion** |
| Agent 365 avec API Management (démo uniquement) | Argumentaire optionnel, voir « Aller plus loin » | Non mis en place par les participants | **Préversion** |

Ce module n'utilise pas Terraform. Il n'a pas de dossier `infra/` car il n'ajoute aucune infrastructure. Deux étapes touchent des paramètres du tenant : l'entrée BYO et, s'il y en a une, la stratégie Agent 365. C'est un administrateur du tenant qui s'en charge, jamais un participant.

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

> [!NOTE]
> Application Insights ne contrôle pas les droits. API Center ne relaie pas les appels.
> Ni une inscription ni un statut HTTP réussi ne prouvent la réussite d'un outil.

### Que peut-on réellement tracer ?

Kusto Query Language (KQL) est le langage de requête des journaux. Il lit les traces enregistrées, pas le raisonnement de l'agent.

| Preuve | Présente ici | Limite |
|---|---|---|
| Heure, opération, statut HTTP, durée | Sélectionnés par la requête fournie | Délai d'ingestion, échantillonnage et limite de 200 lignes : ce n'est pas un audit exhaustif |
| Nom de l'outil et type d'erreur | Sélectionnés si les diagnostics MCP les émettent | Un champ vide ne signifie pas qu'aucun outil n'a été exécuté |
| ID d'objet de l'appelant et corrélation | La stratégie du module 04 émet `caller-oid` dans les traces `workshop-mcp-gateway` ; la télémétrie des requêtes porte un ID de corrélation | La requête fournie ne sélectionne pas l'identité de l'appelant et ne joint pas les traces : vérifiez-les séparément |
| Refus du service en aval | Résultat MCP à examiner dans le client | HTTP 200 peut contenir `isError: true` ; un succès HTTP n'est pas un succès de l'outil |
| Confirmation humaine, prompt, arguments, résultat | Non collectés ici | La passerelle ne prouve pas la confirmation et ne conserve pas la conversation |

En accès applicatif, les journaux en aval identifient l'application, pas Alice ou Bob.
OBO peut conserver l'identité utilisateur, mais l'audit en aval exige sa propre configuration et ses propres droits.
Reliez les métadonnées disponibles entre services ; n'ajoutez jamais de jeton ni de corps pour combler un manque.

**Question :** une requête renvoie HTTP 200. Cela prouve-t-il que Bob a lu le rapport ?

<details>
<summary>Afficher la réponse</summary>

Non. Storage peut refuser Bob ; le serveur renvoie alors une erreur d'outil MCP dans une réponse HTTP 200.
Vérifiez le résultat dans le client et les traces disponibles en aval. Une requête de journaux vide ne prouve ni réussite ni absence d'activité.

</details>

### Étape 1 - Exécuter les vérifications hors ligne

Vérifiez les fichiers du module, la requête KQL et les règles de journalisation avant de lancer la moindre requête.

PowerShell :

```powershell
pwsh ./modules/06-observe-inventory/validate.ps1 -Offline
```

> **Résultat réel** — validateur hors ligne, poste de l'auteur, 2026-10-17. Noms et identifiants masqués.
>
> ```text
> PASS file exists: README.md (offline)
> PASS file exists: README.fr.md (offline)
> PASS file exists: validate.ps1 (offline)
> PASS file exists: validate.sh (offline)
> PASS file exists: cleanup.ps1 (offline)
> PASS file exists: cleanup.sh (offline)
> PASS file exists: queries/mcp-traffic.kql (offline)
> PASS README sections present and in order (offline)
> PASS README.fr.md has the same section count (offline)
> PASS Steps give PowerShell before bash (offline)
> PASS Preview label on API Center, BYO and Agent 365 (offline)
> PASS KQL selects no body, argument, result or token fields (offline)
> PASS KQL filters on api.type Mcp (offline)
> PASS README does not instruct enabling payload logging (offline)
> PASS no secrets or tokens in module files (offline)
> PASS only placeholder GUIDs in module files (offline)
> PASS PROGRESS row 06 is not claimed as validated before live run (offline)
> PASS docs/sources.md has module 06 entries with last-verified dates (offline)
> PASS no infra folder (no Azure resources added) (offline)
> PASS README states the log rules (offline)
> RESULT: all offline checks passed
> ```
>
> **Ce que cela signifie pour vous :** les fichiers du module existent et la requête KQL ne lit que des métadonnées. Rien n'a encore été vérifié dans Azure ; le code de sortie 0 signifie que toutes les règles hors ligne sont respectées.

bash :

```bash
./modules/06-observe-inventory/validate.sh --offline
```

> **Résultat attendu** — les mêmes lignes PASS/FAIL que l'exécution PowerShell ci-dessus.

### Étape 2 - Confirmer que la journalisation des charges utiles est désactivée

Dans l'instance APIM, vérifiez que la journalisation des charges utiles pour l'API MCP est désactivée. N'activez pas la capture de `gen_ai.tool.call.arguments` ni de `gen_ai.tool.call.result` pour cet atelier.

### Étape 3 - Interroger le trafic MCP dans Application Insights

Ouvrez `modules/06-observe-inventory/queries/mcp-traffic.kql` et exécutez-le dans le volet **Logs** du composant Application Insights dans lequel API Management écrit.
La requête utilise les noms de tables d'Application Insights (`requests`, `customDimensions`) : exécutez-la dans le
périmètre de ce composant Application Insights, pas sur son espace de travail Log Analytics, où les mêmes données se trouvent dans `AppRequests`.

PowerShell, depuis le dossier du dépôt (extension Azure CLI `application-insights` : `az extension add --name application-insights`) :

```powershell
$ai = '<application-insights-name>'
$group = '<resource-group>'
# '@file' lets the Azure CLI read the query file itself: on Windows a multi-line argument is cut at its first line.
az monitor app-insights query --app $ai --resource-group $group --offset 24h `
  --analytics-query '@modules/06-observe-inventory/queries/mcp-traffic.kql' --query 'tables[0].rows' -o json
```

> **Résultat réel** — abonnement de test de l'auteur, 2026-10-17, sur le composant Application Insights du module 02. Aucune passerelle API Management n'y envoie encore de trafic MCP : aucune ligne ne correspond. Noms masqués.
>
> ```text
> []
> ```
>
> **Résultat attendu** — avec du trafic MCP passant par la passerelle du module 04. Valeurs fictives ; les colonnes suivent la requête : timestamp, operation, toolName, resultCode, success, duration, errorType, clientApp.
>
> ```text
> [
>   [ "<timestamp>", "tools/call", "whoami", "200", true, <ms>, "", "<client-app>" ],
>   [ "<timestamp>", "tools/list", "", "200", true, <ms>, "", "<client-app>" ],
>   [ "<timestamp>", "tools/call", "create_ticket", "403", false, <ms>, "<error-type>", "<client-app>" ]
> ]
> ```
>
> **Ce que cela signifie pour vous :** chaque ligne ne contient que des métadonnées : aucun corps, jeton, prompt, argument ou résultat. Une liste vide est possible s'il n'y a pas eu de trafic MCP dans les dernières 24 heures ou si l'ingestion est encore en retard ; elle ne prouve ni réussite ni absence d'activité.

bash :

```bash
ai='<application-insights-name>'; group='<resource-group>'
az monitor app-insights query --app "$ai" --resource-group "$group" --offset 24h \
  --analytics-query '@modules/06-observe-inventory/queries/mcp-traffic.kql' --query 'tables[0].rows' -o json
```

> **Résultat attendu** — la même liste que l'exécution PowerShell ci-dessus.
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

**Question :** le serveur a maintenant un asset dans API Center. Eve peut-elle l'appeler parce qu'elle le voit dans le catalogue ?

<details>
<summary>Afficher la réponse</summary>

Non. Une entrée d'inventaire n'autorise personne. API Center ne relaie pas les appels. Chaque appel passe toujours par
API Management. La passerelle valide le jeton Microsoft Entra (émetteur, tenant, audience, expiration, scope), puis vérifie le rôle d'application (`Tools.Read` ou `Tools.Write`).
Sans jeton valide ni le bon rôle, Eve est refusée.

</details>

### Étape 5 - Confirmer l'entrée BYO (Préversion)

L'entrée BYO MCP est en **Préversion** et n'est pas destinée à la production. Un administrateur informatique du tenant l'examine et l'approuve dans le centre d'administration Microsoft 365. En tant que participant, vous vérifiez seulement que l'entrée existe et que son statut est celui défini par l'administrateur. Vous ne l'approuvez pas vous-même.

Contrôle : l'entrée affiche le nom du serveur et un état d'approbation. Cet état ne prouve pas que le serveur est sûr : les contrôles restent appliqués par les modules 04 et 05.

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

> **Résultat réel** — validateur hors ligne, poste de l'auteur, 2026-10-17. Noms et identifiants masqués.
>
> ```text
> PASS file exists: README.md (offline)
> PASS file exists: README.fr.md (offline)
> PASS file exists: validate.ps1 (offline)
> PASS file exists: validate.sh (offline)
> PASS file exists: cleanup.ps1 (offline)
> PASS file exists: cleanup.sh (offline)
> PASS file exists: queries/mcp-traffic.kql (offline)
> PASS README sections present and in order (offline)
> PASS README.fr.md has the same section count (offline)
> PASS Steps give PowerShell before bash (offline)
> PASS Preview label on API Center, BYO and Agent 365 (offline)
> PASS KQL selects no body, argument, result or token fields (offline)
> PASS KQL filters on api.type Mcp (offline)
> PASS README does not instruct enabling payload logging (offline)
> PASS no secrets or tokens in module files (offline)
> PASS only placeholder GUIDs in module files (offline)
> PASS PROGRESS row 06 is not claimed as validated before live run (offline)
> PASS docs/sources.md has module 06 entries with last-verified dates (offline)
> PASS no infra folder (no Azure resources added) (offline)
> PASS README states the log rules (offline)
> RESULT: all offline checks passed
> ```
>
> **Ce que cela signifie pour vous :** toutes les règles hors ligne sont respectées. Les résultats KQL, l'asset API Center et l'entrée BYO restent à vérifier à la main.

```bash
./modules/06-observe-inventory/validate.sh --offline
```

> **Résultat attendu** — les mêmes lignes PASS/FAIL que l'exécution PowerShell ci-dessus.

Chaque vérification affiche `PASS` ou `FAIL` sur une ligne. Une ligne `FAIL` indique le fichier ou la règle en cause. Dans cette version, vous faites à la main les vérifications réelles (résultats KQL, asset API Center, entrée BYO) : le script ne les exécute pas.

## Dépannage

| Symptôme | Cause probable | Correction |
|---|---|---|
| La requête KQL ne renvoie aucune ligne | Le trafic est plus ancien que la période interrogée, ou les diagnostics ne sont pas activés sur l'API APIM | Élargissez à la fois `--offset` et le filtre `ago(24h)` de `queries/mcp-traffic.kql`, puis vérifiez le paramètre de diagnostic APIM pour l'API MCP. |
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

> **Résultat réel** — `cleanup.ps1`, puis `cleanup.ps1 -Apply`, poste de l'auteur, 2026-10-17. Noms et identifiants masqués.
>
> ```text
> Module 06 creates no Azure resources. Nothing is deleted by this script.
> Manual cleanup, if you created them:
>   - API Center asset: delete in the Azure portal (API center > Assets).
>   - BYO MCP listing: removed only by a Microsoft 365 administrator.
>   - Agent 365 policy (demo): removed only by a tenant administrator.
> Report only. Re-run with -Apply to confirm the guard passed (no deletions are performed).
> Module 06 creates no Azure resources. Nothing is deleted by this script.
> Manual cleanup, if you created them:
>   - API Center asset: delete in the Azure portal (API center > Assets).
>   - BYO MCP listing: removed only by a Microsoft 365 administrator.
>   - Agent 365 policy (demo): removed only by a tenant administrator.
> Guard passed. No module-owned resources to remove.
> ```
>
> **Ce que cela signifie pour vous :** les deux exécutions ne suppriment rien, car ce module n'a rien créé. Supprimez vous-même l'asset API Center dans le portail. Laissez l'entrée BYO et toute stratégie Agent 365 aux administrateurs.

bash :

```bash
./modules/06-observe-inventory/cleanup.sh
./modules/06-observe-inventory/cleanup.sh --apply
```

> **Résultat attendu** — les mêmes lignes de rapport que l'exécution PowerShell ci-dessus.

Sans `-Apply` (ou `--apply`), le script se contente d'un rapport. Avec l'option, il ne supprime que ce que ce module a créé, c'est-à-dire rien. Pour supprimer l'asset API Center, passez par le portail. Seul un administrateur peut retirer l'entrée BYO, et uniquement via le centre d'administration Microsoft 365.

## Aller plus loin

- **Alertes** : créez une alerte de journal Azure Monitor sur le taux de réponses `403` de l'opération MCP. Gardez-la synthétique et agrégée.
- **Agent 365 (Préversion, démo uniquement)** : Agent 365 peut inventorier les serveurs MCP exposés via API Management et bloquer un serveur que la stratégie n'autorise pas (l'appelant reçoit 403). Le contrôle outil par outil, l'observabilité et l'intégration avec Defender ou Purview nécessitent le niveau AI Gateway, lui aussi en Préversion. Seul un administrateur du tenant peut donner le consentement pour tout le tenant. C'est un argumentaire pour le présentateur, sans étape pour les participants.
- **Rétention** : décidez de la durée de conservation de la télémétrie MCP et alignez-la sur la politique de protection des données.

## Sources

Les pages officielles Microsoft Learn utilisées pour ce module sont consignées avec leurs dates de dernière vérification dans `docs/sources.md`, sous le module 06 :

- [Surveiller le trafic MCP](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers) : dimensions par défaut et journalisation du contenu, maintenue désactivée ici.
- [Intégration Application Insights](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) : échantillonnage et corrélation.
- [Inventaire API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server) (enregistrement en Préversion).
- [Apporter son serveur MCP](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) (Préversion).
- [Agent 365 avec API Management](https://learn.microsoft.com/azure/api-management/agent-365) (Préversion ; argumentaire facultatif, non revérifié ici).

Dernière vérification : 2026-10-16 pour le lecteur et les précisions de traçabilité. Argumentaire Agent 365 : 2026-10-14.

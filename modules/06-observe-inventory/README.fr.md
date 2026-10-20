# 06 - Observer et inventorier (niveau 4)

[English](README.md)

## Objectif

Microsoft Entra ID protège votre serveur MCP (module 03). Le serveur n'est joignable que par
Azure API Management (APIM, module 04) et il accède aux données en aval avec la bonne identité (module 05).
Reste une question : **voyez-vous ce qui se passe, et les autres équipes trouvent-elles ce serveur ?**

Ce module répond en deux temps :

- **Observer :** quel outil, quel appelant, quand, quel statut, quelle durée. Vous lisez ces métadonnées dans
  Application Insights avec une requête KQL (Kusto Query Language).
- **Inventorier :** inscrire le serveur dans un catalogue (existence, responsable, adresse). Vous l'enregistrez dans
  Azure API Center (**Preview**). Un administrateur peut aussi le déclarer dans le centre d'administration
  Microsoft 365 comme serveur MCP « apporté par le client » (BYO, Bring Your Own) (**Preview**).

Vous ne déployez rien de nouveau. Vous apprenez en revanche ce que prouve chaque élément (journal, inventaire,
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
| Spans des appels d'outils et leur requête | OpenTelemetry dans le code du serveur, fichier KQL (`queries/tool-spans.kql`) | Publiés avec le serveur au module 02 ; dossier de ce module | Stable (conventions MCP : Development) |
| Enregistrement du serveur MCP dans API Center | Asset d'un centre API | Portail Azure (étapes manuelles) | **Préversion** |
| Entrée de serveur MCP BYO | Entrée dans le centre d'administration Microsoft 365 | Centre d'administration Microsoft 365 | **Préversion** |
| Agent 365 avec API Management (démo uniquement) | Argumentaire facultatif, voir « Aller plus loin » | Non mis en place par les participants | **Préversion** |

Ce module n'utilise pas Terraform. Il n'a pas de dossier `infra/` car il n'ajoute aucune infrastructure. Deux étapes touchent des paramètres du tenant : l'entrée BYO et, s'il y en a une, la stratégie Agent 365. C'est un administrateur du tenant qui s'en charge, jamais un participant.

## Prérequis et rôles requis

- Modules 00 à 05 terminés ; le point de terminaison MCP d'APIM doit répondre.
- PowerShell 7.4 ou version ultérieure (`pwsh`) et, pour les étapes Linux ou macOS, bash.
- Azure CLI, connecté à un abonnement hors production approuvé que vous possédez. Si vous êtes présentateur, n'exécutez pas ces étapes dans le tenant d'un participant.
- **Lecteur** sur le composant Application Insights, pour exécuter les requêtes KQL.
- Pour API Center : un rôle qui autorise l'enregistrement d'assets dans le centre API. Confirmez le nom exact du rôle intégré dans la page des rôles intégrés Azure RBAC avant de l'attribuer. Ce module ne présuppose aucun rôle précis.
- Pour l'entrée BYO : un administrateur informatique dans le centre d'administration Microsoft 365. Le participant n'a pas besoin de ce rôle et ne doit pas le demander.
- Pour Agent 365 (démo facultative) : un administrateur du tenant qui détient le rôle Agent 365 MCP Gateway Policy Operator. Ce rôle n'est jamais attribué à un participant.

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
| ID d'objet de l'appelant et corrélation | La stratégie du module 04 émet `caller-oid` dans les traces `workshop-mcp-gateway` ; le span de l'outil enregistre `workshop.caller` ; un même ID d'opération relie la passerelle, la Function et les appels en aval (étape 3b) | La requête du trafic ne sélectionne pas l'appelant : utilisez la requête des spans |
| Refus du service en aval | Le span de l'outil (`error.type = tool_error`) et l'appel en aval refusé (étape 3b) | HTTP 200 peut contenir `isError: true` ; un succès HTTP n'est pas un succès de l'outil |
| Confirmation humaine, prompt, arguments, résultat | Non collectés ici | La passerelle ne prouve pas la confirmation et ne conserve pas la conversation |

En accès applicatif (app-only), les journaux en aval identifient l'application, pas Alice ou Bob.
OBO peut conserver l'identité utilisateur, mais l'audit en aval exige sa propre configuration et ses propres droits.
Recoupez les métadonnées disponibles d'un service à l'autre ; n'ajoutez jamais de jeton ni de corps pour combler un manque.

**Question :** l'appel de Bob renvoie HTTP 200. Cela prouve-t-il qu'il a lu le rapport ?

<details>
<summary>Afficher la réponse</summary>

Non. Storage peut refuser Bob ; le serveur renvoie alors une erreur d'outil MCP dans une réponse HTTP 200.
Vérifiez le résultat dans le client et les traces disponibles en aval. Une requête de journaux vide ne prouve ni réussite ni absence d'activité.

</details>

### Parcours low-code (portail et commandes simples)

Les étapes 1, 2 et 5 sont les mêmes dans les deux parcours, et les étapes 3 et 4 donnent déjà le chemin du portail. Seules
leurs lignes de terminal lisent les sorties Terraform : dans le parcours low-code, utilisez plutôt les noms ci-dessous.

```powershell
$p = Get-Content .\.workshop\participant.tfvars.json -Raw | ConvertFrom-Json
$id = "$($p.participant_prefix)lc"; $sfx = $p.resource_suffix.Substring(0, 10)
$group = "rg-mcp-$id-$sfx"; $ai = "appi-mcp-$id-$sfx"; $apim = "apim-mcp-$id-$sfx"; $apic = "apic-mcp-$id-$sfx"
# Étape 3 : le même fichier KQL, sur votre composant Application Insights.
az monitor app-insights query --app $ai --resource-group $group --offset 24h `
  --analytics-query '@modules/06-observe-inventory/queries/mcp-traffic.kql' --query 'tables[0].rows' -o json
# Étape 4 : le centre d'API (plan Free) et son environnement gateway ; l'URL à coller sous Remotes.
az apic create --resource-group $group --name $apic --location (az group show --name $group --query location --output tsv)
az apic environment create --resource-group $group --service-name $apic --environment-id gateway --title "API Management gateway" --type development
"https://$apim.azure-api.net/workshop-mcp/mcp"
```

> **Résultat réel** — parcours low-code, 2026-10-20, tenant de test de l'auteur. 7 des 102 lignes issues des vérifications
> des modules 04 et 05, puis le centre d'API (`"sku": { "name": "Free" }`) et l'environnement `gateway`.
>
> ```text
> [ "2026-10-20T10:27:38.6207559Z", "tools/call", "create_ticket", "200", "True", 442.5, "", "" ]
> [ "2026-10-20T10:27:51.7341172Z", "tools/call", "create_ticket", "403", "False", 3.3805, "", "" ]
> [ "2026-10-20T10:32:02.3050838Z", "tools/call", "list_tickets", "200", "True", 51.4503, "", "" ]
> [ "2026-10-20T10:46:54.2387598Z", "tools/call", "whoami", "200", "True", 1566.4731, "", "" ]
> [ "2026-10-20T10:46:56.2391415Z", "tools/call", "read_report_as_user", "200", "True", 569.971, "", "" ]
> [ "2026-10-20T10:46:57.2408390Z", "tools/call", "read_report_as_app", "200", "True", 258.4664, "", "" ]
> [ "2026-10-20T10:47:08.3307894Z", "tools/call", "read_report_as_user", "200", "True", 292.3766, "", "" ]
> ```
>
> **Ce que cela signifie pour vous :** les mêmes métadonnées que dans le parcours full-code, car les stratégies de la
> passerelle sont les mêmes. Les deux lignes `read_report_as_user` affichent HTTP 200, mais l'une est celle de Bob : Storage
> l'a refusé dans le résultat de l'outil. Un succès HTTP n'est pas un succès de l'outil. Le `create_ticket` de Bob
> (HTTP 403, 3 ms) n'a jamais atteint la Function.

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
> PASS KQL filters on api.type Mcp, pass-through-mcp and mcp-backend (offline)
> PASS README does not instruct enabling payload logging (offline)
> PASS no secrets or tokens in module files (offline)
> PASS only placeholder GUIDs in module files (offline)
> PASS PROGRESS row 06 claims validated only with a date and a live run (offline)
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

Dans l'instance APIM, vérifiez que la journalisation des charges utiles est désactivée pour l'API MCP. N'activez pas la capture de `gen_ai.tool.call.arguments` ni de `gen_ai.tool.call.result` pour cet atelier.

### Étape 3 - Interroger le trafic MCP dans Application Insights

Ouvrez `modules/06-observe-inventory/queries/mcp-traffic.kql` et exécutez son contenu dans le volet **Logs** du composant Application Insights où écrit API Management.

La requête exacte, prête à coller :

```kql
// Module 06 - MCP traffic in Application Insights (synthetic, metadata only).
// Reads only request metadata. Never select request or response bodies,
// tool arguments, tool results, tokens or prompts.
// Single-quoted strings keep the query intact when PowerShell passes it to the Azure CLI on Windows.
requests
| where timestamp > ago(24h)
| extend apiType = tostring(customDimensions['api.type'])
// Microsoft Learn lists 'Mcp'. Verified live 2026-10-20: an existing MCP server behind a backend (part A, passthrough)
// logs 'pass-through-mcp'; a REST API exposed as an MCP server (part B) logs 'mcp-backend'.
| where apiType in ('Mcp', 'pass-through-mcp', 'mcp-backend')
| extend
    operation = tostring(customDimensions['gen_ai.operation.name']),
    toolName  = tostring(customDimensions['gen_ai.tool.name']),
    errorType = tostring(customDimensions['error.type']),
    clientApp = tostring(customDimensions['user_agent.name'])
| project timestamp, operation, toolName, resultCode, success, duration, errorType, clientApp
| order by timestamp desc
| take 200
```

La requête utilise les noms de tables d'Application Insights (`requests`, `customDimensions`) : exécutez-la dans le
périmètre de ce composant Application Insights, pas sur son espace de travail Log Analytics, où les mêmes données se trouvent dans la table `AppRequests`.

**Dans le portail Azure :** cherchez `appi-mcp-<prefix>-<suffix>` (votre ressource Application Insights, affichée par la
première ligne de la commande ci-dessous), ouvrez-la, sélectionnez **Surveillance → Journaux** (**Monitoring → Logs**),
passez l'éditeur en **mode KQL**, collez la requête puis sélectionnez **Exécuter** (**Run**).

**Ou depuis votre terminal.** PowerShell, depuis le dossier du dépôt (extension Azure CLI `application-insights` : `az extension add --name application-insights`) :

```powershell
$ai = (terraform -chdir=infra/workload output -json resource_names | ConvertFrom-Json).application_insights
$group = terraform -chdir=infra/workload output -raw resource_group_name
# '@file' lets the Azure CLI read the query file itself: on Windows a multi-line argument is cut at its first line.
az monitor app-insights query --app $ai --resource-group $group --offset 24h `
  --analytics-query '@modules/06-observe-inventory/queries/mcp-traffic.kql' --query 'tables[0].rows' -o json
```

> **Résultat réel** — trafic de la passerelle issu des vérifications opérateur du module 04, 2026-10-18, tenant de test de l'auteur. Pas encore de trafic des personas. Noms et ID masqués.
>
> ```text
> [
>   [
>     "2026-10-18T14:38:02.4928994Z",
>     "initialize",
>     "",
>     "401",
>     "False",
>     690.08,
>     "",
>     "workshop-validator"
>   ],
>   [
>     "2026-10-18T14:37:54.7916733Z",
>     "initialize",
>     "",
>     "401",
>     "False",
>     1221.7192,
>     "",
>     "workshop-validator"
>   ]
> ]
> ```
>
> **Résultat réel** — trafic des personas des modules 04 et 05 (Alice et Bob), 2026-10-20, tenant de test de l'auteur.
> 6 lignes sur 134 ; les colonnes suivent la requête : timestamp, operation, toolName, resultCode, success, duration (ms), errorType, clientApp.
>
> ```text
> [
>   [ "2026-10-20T05:20:15.1801351Z", "tools/call", "create_ticket", "200", "True", 597.982, "", "" ],
>   [ "2026-10-20T05:31:02.2715503Z", "tools/call", "create_ticket", "403", "False", 3.6035, "", "" ],
>   [ "2026-10-20T06:20:18.3449395Z", "tools/call", "whoami", "200", "True", 1169.1348, "", "" ],
>   [ "2026-10-20T06:20:19.856923Z", "tools/call", "read_report_as_user", "200", "True", 337.9462, "", "" ],
>   [ "2026-10-20T05:31:21.3260289Z", "ping", "", "429", "False", 1.8206, "", "" ],
>   [ "2026-10-20T05:38:27.8248234Z", "tools/call", "list_tickets", "200", "True", 10.8423, "", "" ]
> ]
> ```
>
> **Ce que cela signifie pour vous :** chaque ligne ne contient que des métadonnées : aucun corps, jeton, prompt, argument
> ou résultat. Le `create_ticket` d'Alice a pris environ 600 ms, car la Function l'a exécuté ; celui de Bob 3,6 ms et le
> `ping` limité 1,8 ms : la passerelle les a refusés (HTTP 403 et 429) sans appeler la Function. La requête garde trois
> valeurs d'`api.type` : Microsoft Learn cite `Mcp` ; le serveur existant de l'atelier (partie A) journalise `pass-through-mcp`,
> et l'API REST exposée en MCP (partie B) journalise `mcp-backend`. Une liste vide est possible s'il n'y a pas eu de trafic
> MCP au cours des dernières 24 heures ou si l'ingestion est encore en retard ; elle ne prouve ni réussite ni absence d'activité.

La même requête dans le portail : composant Application Insights → **Logs**, passez en **KQL mode**, collez la requête,
puis **Run** (capture réelle, 2026-10-19, tenant de test de l'auteur ; noms pseudonymisés ; portail en anglais). Le
premier cadre entoure le filtre qui ne garde que le trafic MCP ; le second entoure les lignes : opération, statut, durée et
nom du client, rien d'autre.

![Capture réelle : Logs d'Application Insights en mode KQL, filtre MCP et deux lignes de métadonnées, initialize refusé avec HTTP 401](../../assets/screenshots/azure-06-kql-logs.png)

bash :

```bash
ai=$(terraform -chdir=infra/workload output -json resource_names | jq -r .application_insights); group=$(terraform -chdir=infra/workload output -raw resource_group_name)
az monitor app-insights query --app "$ai" --resource-group "$group" --offset 24h \
  --analytics-query '@modules/06-observe-inventory/queries/mcp-traffic.kql' --query 'tables[0].rows' -o json
```

> **Résultat attendu** — la même liste que l'exécution PowerShell ci-dessus.
La requête ne lit que des métadonnées : nom d'opération, nom d'outil, statut, durée et type d'erreur. Elle ne lit jamais les corps de requête ou de réponse.

### Facultatif - Poser la même question à l'Observability Agent

La page Logs propose un interrupteur **Agent** qui ouvre l'Azure Copilot Observability Agent. Vous posez la question en
langage courant ; l'agent écrit une requête KQL, l'exécute sur ce composant Application Insights et explique le résultat.
Le chat ne nécessite aucune ressource supplémentaire. Si l'interrupteur n'apparaît pas, votre tenant ne propose peut-être pas
Azure Copilot : passez cette étape, le module n'en dépend pas.

1. Dans le même composant Application Insights, ouvrez **Logs**, puis activez **Agent** (en haut à droite).
2. Saisissez cette question (en anglais, comme le portail) :

   ```prompt
   Show MCP requests from the last 7 days where customDimensions api.type is Mcp, pass-through-mcp or mcp-backend: timestamp, operation (gen_ai.operation.name), resultCode, success, duration and client (user_agent.name). Metadata only, no request or response bodies.
   ```

3. Dépliez **Reasoned for ...** pour voir la requête exécutée par l'agent. Comparez-la avec `queries/mcp-traffic.kql`.

> **Résultat réel** — Observability Agent, 2026-10-19, tenant de test de l'auteur. Noms pseudonymisés, ID remplacés.
> Le premier cadre montre la question ; le second, le tableau renvoyé par l'agent : les mêmes deux lignes `initialize`
> refusées avec HTTP 401 qu'avec le fichier KQL.
>
> **Ce que cela signifie pour vous :** l'agent arrive au même résultat parce que les journaux ne contiennent que des
> métadonnées. Il ne trouve que ce qui a été journalisé : ni prompt, ni jeton, ni corps de requête à divulguer. Le chat est
> temporaire et limité à cette seule ressource.

![Capture réelle : chat de l'Observability Agent dans Logs, avec la question et les deux lignes de métadonnées renvoyées](../../assets/screenshots/azure-06-observability-agent-answer.png)

La requête générée par l'agent (encadrée) utilise le filtre `api.type` de la question du 2026-10-19, avant l'ajout de `pass-through-mcp` :

![Capture réelle : requête KQL générée par l'Observability Agent, filtre api.type sur Mcp et mcp-backend](../../assets/screenshots/azure-06-observability-agent-query.png)

**Question :** pourquoi garder `queries/mcp-traffic.kql` si l'agent sait écrire la requête ?

<details>
<summary>Afficher la réponse</summary>

Parce que le fichier est reproductible et relu : il donne toujours le même résultat, il est versionné dans Git et il
s'exécute depuis Azure CLI et le validateur, sans portail ni IA. La requête de l'agent peut changer d'une fois à l'autre,
et un contenu généré par l'IA peut être faux. Servez-vous de l'agent pour explorer et ébaucher ; gardez le fichier relu
comme référence.

</details>

### Étape 3b - Suivre un appel d'outil de bout en bout (OpenTelemetry)

L'étape 3 compte les appels. Ici, vous suivez **un seul** appel, maillon par maillon : la passerelle, la Function,
l'outil, puis les services que l'outil appelle. Rien à déployer : le serveur publié au module 02 envoie déjà à ce
composant Application Insights un span OpenTelemetry par appel d'outil, plus un par étape en aval. Il s'authentifie avec
son identité managée, sans clé.

> [!NOTE]
> Les conventions sémantiques OpenTelemetry pour MCP sont encore au statut **Development** : les noms d'attributs
> peuvent changer.

Bob appelle `read_report_as_user`. Voici ce que montre la trace (durées réelles, 2026-10-20) :

```text
API Management  POST /workshop-mcp/mcp            369 ms  HTTP 200
└ Function      ReadReportAsUser                  358 ms  échec
  └ outil       tools/call read_report_as_user    324 ms  tool_error
    └ étape     Azure Storage read report         323 ms  échec
      ├ étape   Managed identity assertion          0 ms  ok
      ├ HTTP    login.microsoftonline.com (OBO)   306 ms  200
      └ HTTP    Azure blob <compte>/reports         5 ms  403
```

À lire de haut en bas : pour la passerelle, tout va bien (HTTP 200). L'échange OBO avec Entra réussit. C'est Storage
qui refuse Bob (403).

| Ce qu'un span enregistre (métadonnées) | Ce qu'un span n'enregistre jamais |
|---|---|
| L'outil et la méthode : `gen_ai.tool.name`, `mcp.method.name` | Les arguments et les résultats de l'outil : les conventions les classent en **Opt-In**, ce serveur ne les active pas |
| L'ID d'objet de l'appelant (`workshop.caller`), l'issue de l'appel, `error.type = tool_error` | Les jetons, y compris l'assertion On-Behalf-Of |
| La durée et le statut de chaque appel en aval : hôte, chemin, statut HTTP | Les prompts, les corps de requête et de réponse, les paramètres d'URL |

**Dans le portail Azure** (portail en anglais) :

1. Ouvrez votre ressource Application Insights `appi-mcp-<prefix>-<suffix>`, puis **Investigate** → **Search**.
2. Dans la zone de recherche, collez un ID d'opération donné par la requête ci-dessous (ou tapez `read_report_as_user`),
   puis appuyez sur Entrée.
3. Cliquez sur la ligne de la trace : la page **End-to-end transaction details** s'ouvre. Cliquez sur **View timeline**.
4. Cliquez sur la ligne `read_report_as_user` : ses attributs sont sous **Custom Properties**.

**Ou depuis votre terminal.** La requête liste les derniers appels d'outils, avec l'ID d'opération à coller à l'étape 2.

PowerShell :

```powershell
$ai = (terraform -chdir=infra/workload output -json resource_names | ConvertFrom-Json).application_insights
$group = terraform -chdir=infra/workload output -raw resource_group_name
az monitor app-insights query --app $ai --resource-group $group --offset 24h `
  --analytics-query '@modules/06-observe-inventory/queries/tool-spans.kql' --query 'tables[0].rows' -o json
```

> **Résultat réel** — vérifications des personas du module 05, 2026-10-20, tenant de test de l'auteur. Colonnes :
> horodatage, outil, issue, succès, durée (ms), appelant, ID d'opération. ID d'objet remplacés.
>
> ```text
> [ "2026-10-20T12:41:49.8297728Z", "read_report_as_app", "success", "True", 9.2244, "<bob-object-id>", "e87b9b4eb127eb41143869942a1ce275" ]
> [ "2026-10-20T12:41:48.6026728Z", "read_report_as_user", "denied-downstream:403", "False", 323.6665, "<bob-object-id>", "08beb1cec8d288bfb679974b4222bcc1" ]
> [ "2026-10-20T12:41:47.7550955Z", "whoami", "success", "True", 533.3178, "<bob-object-id>", "dc377674e8f2d0ce17bdbdfaed876754" ]
> [ "2026-10-20T12:41:37.1243308Z", "read_report_as_app", "success", "True", 252.9528, "<alice-object-id>", "fac868e66169055f59c7860e473ea7e1" ]
> [ "2026-10-20T12:41:36.4007953Z", "read_report_as_user", "success", "True", 350.2882, "<alice-object-id>", "e4953ce2d99878c9594c99d9d3d548e1" ]
> [ "2026-10-20T12:41:34.3688446Z", "whoami", "success", "True", 1563.1348, "<alice-object-id>", "4227ea095c3caeca474221ab324ec16f" ]
> ```
>
> **Ce que cela signifie pour vous :** même outil, deux issues. Le `read_report_as_user` d'Alice aboutit ; celui de Bob
> se termine par `denied-downstream:403`. Chaque ligne porte son ID d'opération : collez celui de Bob dans le portail
> pour voir où l'appel s'est arrêté.

bash :

```bash
ai=$(terraform -chdir=infra/workload output -json resource_names | jq -r .application_insights); group=$(terraform -chdir=infra/workload output -raw resource_group_name)
az monitor app-insights query --app "$ai" --resource-group "$group" --offset 24h \
  --analytics-query '@modules/06-observe-inventory/queries/tool-spans.kql' --query 'tables[0].rows' -o json
```

> **Résultat attendu** — les mêmes lignes qu'avec PowerShell ci-dessus.

La trace de Bob dans **View timeline** (capture réelle, 2026-10-20 ; noms pseudonymisés). Cadre 1 : la passerelle répond
HTTP 200, en bleu. Cadre 2 : le span de l'outil, en rouge. Cadre 3 : l'appel à Storage qui refuse Bob (HTTP 403).

![Capture réelle : chronologie de la transaction de bout en bout pour l'appel read_report_as_user de Bob ; la ligne de la passerelle est bleue, le span de l'outil et l'appel à Storage sont rouges](../../assets/screenshots/azure-06-trace-waterfall.png)

Les attributs du span de l'outil (cadre 2). Rien d'autre n'est enregistré : ni argument, ni résultat, ni jeton.

![Capture réelle : Custom Properties du span read_report_as_user : mcp.method.name, gen_ai.operation.name, gen_ai.tool.name, workshop.caller, workshop.outcome et error.type](../../assets/screenshots/azure-06-trace-span-attributes.png)

**Question :** la passerelle a journalisé HTTP 200 pour l'appel de Bob. Où la trace montre-t-elle l'échec, et pourquoi ?

<details>
<summary>Afficher la réponse</summary>

Dans les lignes rouges. Le span de l'outil porte `error.type = tool_error`, et la dernière étape est l'appel à Storage,
refusé en HTTP 403. Juste avant, l'échange On-Behalf-Of avec Microsoft Entra a réussi : le jeton de Bob était valide.
Ce qui lui manque, c'est un rôle Storage sur le conteneur du rapport. MCP renvoie les erreurs d'outil dans une réponse
HTTP 200 : seule la trace montre où l'appel s'est arrêté.

</details>

> [!TIP]
> **Vous écrivez votre propre serveur MCP ?** Gardez les mêmes réflexes : un span par appel d'outil, nommé
> `tools/call <outil>` ; le contexte de trace W3C reçu de la passerelle ; des métadonnées seulement (laissez désactivés
> les arguments et résultats, classés Opt-In) ; un export avec une identité managée plutôt qu'une clé.

### Étape 4 - Enregistrer le serveur MCP dans API Center (Préversion)

L'inventaire API Center est en **Préversion**.

**Pas encore de centre API ?** Créez-en un, puis un environnement qui représente la passerelle. Lancez ces commandes
depuis la racine du dépôt, après approbation. Le centre API est créé avec le plan **Free**, dans le groupe de ressources
de l'atelier. Le fournisseur `Microsoft.ApiCenter` doit déjà être enregistré : sinon, demandez-le à votre administrateur.

```powershell
$group = terraform -chdir=infra/workload output -raw resource_group_name
$apic = (terraform -chdir=infra/workload output -raw mcp_function_app_name) -replace '^func-', 'apic-'
az apic create --resource-group $group --name $apic --location (az group show --name $group --query location --output tsv)
az apic environment create --resource-group $group --service-name $apic --environment-id gateway --title "API Management gateway" --type development
terraform -chdir=infra/workload output -raw gateway_mcp_endpoint
```

> **Résultat attendu** — le JSON du nouveau centre API (`"sku": { "name": "Free" }`) et de l'environnement `gateway`, puis
> l'URL de la passerelle à coller sous **Remotes**. La première commande `az apic` propose d'installer l'extension Azure CLI
> `apic-extension` : acceptez. Si la région n'est pas proposée pour API Center, créez-le dans une région prise en charge.

Dans le portail Azure, cherchez **API Center**, ouvrez le centre API que vous avez créé, puis :

1. Ouvrez votre centre API et sélectionnez **Assets**.
2. Choisissez **+ Register an asset**, puis **MCP server**.
3. Saisissez un titre, un résumé et une description. Utilisez un texte fictif, par exemple « Contoso governed MCP demo ».
4. Sous **Remotes**, choisissez **Add remote**. Collez l'URL de la passerelle affichée par la dernière commande ci-dessus,
   choisissez l'environnement **API Management gateway**, puis **Save**.
5. Sous **Version title**, saisissez `v1` et choisissez le cycle de vie **Development**. La licence est facultative.
6. Choisissez **Create**. API Center génère les définitions MCP (SSE, et Streamable d'après la documentation).

Contrôle : l'asset apparaît dans **Assets** avec l'environnement choisi.

![Capture réelle : API Center, Assets, Register an asset, MCP server ; puis le panneau MCP Remote avec l'URL de la passerelle et l'environnement API Management gateway ; puis le nouvel asset MCP dans la liste](../../assets/screenshots/azure-06-apic-register.png)

*Capture réelle, 2026-10-19, tenant de test de l'auteur (noms pseudonymisés). Cadres 1 à 3 : ouvrir le formulaire.
Cadres 4 à 6 : ajouter l'URL d'exécution. Cadre 7 : l'asset apparaît comme **MCP**, cycle de vie **Development**.*

Vérifiez aussi que l'URL d'exécution a bien été enregistrée. Dans le tenant de test de l'auteur, **Create** a créé l'asset
mais a renvoyé une erreur pour l'URL d'exécution (HTTP 400), et seule une définition SSE a été générée. Si l'asset n'a
aucun déploiement, ajoutez-le depuis votre terminal, avec les mêmes noms que ci-dessus :

```powershell
$server = Join-Path $env:TEMP 'apic-server.json'
@{ runtimeUri = @((terraform -chdir=infra/workload output -raw gateway_mcp_endpoint)) } | ConvertTo-Json -Compress | Set-Content $server
az apic api deployment list --resource-group $group --service-name $apic --api-id contoso-governed-mcp-demo --query "[].name" --output tsv
az apic api deployment create --resource-group $group --service-name $apic --api-id contoso-governed-mcp-demo --deployment-id gateway --title "API Management gateway" --environment-id /workspaces/default/environments/gateway --definition-id /workspaces/default/apis/contoso-governed-mcp-demo/versions/v1/definitions/default-sse --server "@$server"
Remove-Item $server
```

> **Résultat attendu** — la première commande n'affiche rien (pas encore de déploiement). La seconde affiche le nouveau
> déploiement `gateway` en JSON. Utilisez l'identifiant (`contoso-governed-mcp-demo`) et la version (`v1`) de votre formulaire.

**Question :** le serveur a maintenant sa fiche (asset) dans API Center. Eve peut-elle l'appeler parce qu'elle le voit dans le catalogue ?

<details>
<summary>Afficher la réponse</summary>

Non. Une entrée d'inventaire n'autorise personne. API Center ne relaie pas les appels. Chaque appel passe toujours par
API Management. La passerelle valide le jeton Microsoft Entra (émetteur, tenant, audience, expiration, scope), puis vérifie le rôle d'application (`Tools.Read` ou `Tools.Write`).
Sans jeton valide ni le bon rôle, la passerelle refuse Eve.

</details>

### Étape 5 - Confirmer l'entrée BYO (Préversion)

L'entrée BYO MCP est en **Préversion** et n'est pas destinée à la production. Un administrateur informatique du tenant l'examine et l'approuve dans le centre d'administration Microsoft 365. En tant que participant, vous vérifiez seulement que l'entrée existe et que son statut est celui défini par l'administrateur. Vous ne l'approuvez pas vous-même.

Où regarder : connectez-vous au [centre d'administration Microsoft 365](https://admin.microsoft.com/), puis sélectionnez
**Agents → Outils** (**Agents → Tools**) et l'onglet **Registre** (**Registry**) ; les demandes en attente sont dans l'onglet
**Demandes** (**Requests**). Il faut un rôle d'administrateur pour le consulter : sinon, demandez à l'administrateur de vous
montrer l'entrée.

Contrôle : l'entrée affiche le nom du serveur et un état d'approbation. Cet état ne prouve pas que le serveur est sûr : ce sont toujours les modules 04 et 05 qui appliquent les contrôles.

## Ce que vous devriez voir

- Si du trafic MCP a été ingéré, la requête KQL renvoie les lignes disponibles avec `api.type` égal à `Mcp`, `pass-through-mcp` ou `mcp-backend`, pour `initialize`, `tools/list` et `tools/call`. Ce n'est pas un audit exhaustif.
- Les colonnes contiennent des noms d'outils et des codes de statut, mais aucun corps de requête, corps de réponse, jeton, prompt ou argument d'outil.
- Un appel d'outil forme une seule trace : la chronologie montre la passerelle, la Function, le span `tools/call` et chaque appel en aval.
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
> PASS KQL filters on api.type Mcp, pass-through-mcp and mcp-backend (offline)
> PASS README does not instruct enabling payload logging (offline)
> PASS no secrets or tokens in module files (offline)
> PASS only placeholder GUIDs in module files (offline)
> PASS PROGRESS row 06 claims validated only with a date and a live run (offline)
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

**Question :** le contrôle `KQL selects no body, argument, result or token fields` passe. Pourquoi tester la requête elle-même, et pas seulement les journaux ?

<details>
<summary>Afficher la réponse</summary>

Parce que la requête est copiée telle quelle. Si elle sélectionnait une colonne de corps ou de jeton, elle exposerait des
données dès que quelqu'un activerait la journalisation du contenu, et elle inciterait à le faire. Tester la requête garde
la règle « métadonnées uniquement » dans le support lui-même.

</details>


## Dépannage

| Symptôme | Cause probable | Correction |
|---|---|---|
| La requête KQL ne renvoie aucune ligne | Le trafic est plus ancien que la période interrogée, ou les diagnostics ne sont pas activés sur l'API APIM | Élargissez à la fois `--offset` et le filtre `ago(24h)` de `queries/mcp-traffic.kql`, puis vérifiez le paramètre de diagnostic APIM pour l'API MCP. |
| Des lignes existent mais `tool.name` est vide | Seul `tools/list` a été appelé, ou l'opération MCP n'a pas été classée | Appelez un outil une fois depuis le client, puis relancez la requête. |
| Des champs de charge utile apparaissent dans les journaux | La journalisation des charges utiles a été activée | Désactivez-la dans APIM, supprimez les lignes concernées selon votre politique de rétention, et consignez-le comme constat. |
| La requête des spans ne renvoie aucune ligne `tools/call` | Aucun outil n'a encore été appelé, ou votre serveur a été publié avant l'ajout des spans | Appelez un outil, attendez 2 à 5 minutes, relancez. Sinon, republiez le serveur ([module 02, étape 5](../02-open-server/README.fr.md#étapes)) ; après l'étape 2 du module 04, publiez avant le verrouillage (voir module 04). |
| L'asset API Center ne peut pas être créé | Le rôle n'est pas attribué, ou l'environnement n'existe pas | Vérifiez le rôle dans RBAC et créez d'abord l'environnement. |
| L'entrée BYO est absente | Fonctionnalité en préversion non activée, ou l'administrateur ne l'a pas approuvée | Adressez-vous à l'administrateur informatique du tenant. Ne demandez pas le rôle vous-même. |

## Nettoyer

Terraform et les scripts de ce module ne créent aucune ressource Azure : le script de nettoyage se limite donc à un rapport,
précédé d'un contrôle de sécurité. La seule ressource que vous pouvez ajouter à la main est le centre API facultatif de
l'étape 4 : supprimez-le avec la commande à la fin de cette section.

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

Si vous avez créé le centre API à l'étape 4, supprimez-le avec les mêmes noms. Cela supprime le centre API, son
environnement et l'asset :

```powershell
$group = terraform -chdir=infra/workload output -raw resource_group_name
$apic = (terraform -chdir=infra/workload output -raw mcp_function_app_name) -replace '^func-', 'apic-'
az apic delete --resource-group $group --name $apic --yes
```

> **Résultat attendu** — aucune sortie et un code de sortie 0. `az apic show --resource-group $group --name $apic` indique
> ensuite que la ressource est introuvable.

## Aller plus loin

- **Alertes** : créez une alerte de journal Azure Monitor sur le taux de réponses `403` de l'opération MCP. Appuyez-la sur des données fictives et agrégées.
- **Agent 365 (Préversion, démo uniquement)** : Agent 365 peut inventorier les serveurs MCP exposés via API Management et bloquer un serveur que la stratégie n'autorise pas (l'appelant reçoit 403). Le contrôle outil par outil, l'observabilité et l'intégration avec Defender ou Purview nécessitent le niveau AI Gateway, lui aussi en Préversion. Seul un administrateur du tenant peut donner le consentement pour tout le tenant. C'est un argumentaire pour le présentateur, sans étape pour les participants.
- **Rétention** : décidez de la durée de conservation de la télémétrie MCP et alignez-la sur votre politique de protection des données.

## Sources

`docs/sources.md` recense, sous le module 06, les pages officielles Microsoft Learn utilisées pour ce module, avec leur date de dernière vérification :

- [Surveiller le trafic MCP](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers) : dimensions par défaut et journalisation du contenu, que l'atelier laisse désactivée.
- [Intégration Application Insights](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) : échantillonnage et corrélation.
- [Inventaire API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server) (enregistrement en Préversion).
- [Apporter son serveur MCP](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) (Préversion).
- [Agent 365 avec API Management](https://learn.microsoft.com/azure/api-management/agent-365) (Préversion ; argumentaire facultatif, non revérifié ici).
- [Azure Copilot Observability Agent](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-overview) et [dialoguer avec vos données d'observabilité](https://learn.microsoft.com/azure/azure-monitor/aiops/observability-agent-chat) : étape facultative. Les opérations autonomes et la ressource de l'agent sont en Préversion et ne sont pas utilisées ici. Dernière vérification : 2026-10-19.
- [Utiliser OpenTelemetry avec Azure Functions](https://learn.microsoft.com/azure/azure-functions/opentelemetry-howto) : paquets du worker et `UseFunctionsWorkerDefaults` ; ce serveur n'exporte que les traces, avec son identité managée. Dernière vérification : 2026-10-20.
- [Conventions sémantiques OpenTelemetry pour MCP](https://github.com/open-telemetry/semantic-conventions-genai/blob/547934afa90a34298441caf80c43b27255c3a292/docs/gen-ai/mcp.md) (statut : Development, commit épinglé) : nom de span `{mcp.method.name} {target}`, `error.type = tool_error` quand `isError` vaut true, arguments et résultats en Opt-In. Dernière vérification : 2026-10-20.
- [Diagnostic des transactions de bout en bout](https://learn.microsoft.com/azure/azure-monitor/app/transaction-search-and-diagnostics) : recherche et chronologie des transactions. Dernière vérification : 2026-10-20.

Dernière vérification : 2026-10-20.

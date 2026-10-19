# Le serveur MCP de l'atelier : ce qui tourne et ce qu'il répond

[English](../MCP-SERVER.md)

Un seul serveur MCP sert pendant tout l'atelier. Chaque module ajoute un contrôle **devant lui**, ou change **qui lit
les données derrière lui**. Cette page montre ce qu'est ce serveur, comment l'atteindre à chaque niveau, et ses
**réponses réelles**, relevées le 2026-10-19 dans le tenant de test de l'auteur. Les noms sont pseudonymisés et les
identifiants remplacés par des zéros.

## Ce qui tourne

| | |
|---|---|
| Code | [src/FunctionsMcpServer](../../src/FunctionsMcpServer) (.NET, extension MCP d'Azure Functions) |
| Nom et version | `workshop-open-mcp` 0.2.0 |
| Point de terminaison | `https://func-mcp-<prefix>-<suffix>.azurewebsites.net/runtime/webhooks/mcp` |
| Transport | Streamable HTTP : un `POST` par message JSON-RPC, la réponse revient en `text/event-stream` |
| Données | Fictives uniquement : deux services (`workshop-api`, `ticket-queue`) et un rapport (`monthly-usage`) |
| Outils | Cinq : quatre en lecture, un en écriture |

Le 2026-10-19, le tenant de test de l'auteur est dans l'état du **module 03** : le serveur du module 02, protégé par
l'authentification intégrée Microsoft Entra. La passerelle du module 04 a été supprimée et le mode du module 05 est désactivé.

## Comment l'atteindre à chaque niveau

![Un serveur MCP, quatre niveaux : ce que vous envoyez à chaque niveau, qui refuse, et quand les réponses changent](../../assets/screenshots/diagram-02-server-levels-fr.png)

| Niveau | Ce que vous envoyez | Sans cela | Ce qui change dans les réponses |
|---|---|---|---|
| 02 Serveur ouvert | En-tête `x-functions-key` | HTTP 401 | Rien : niveau `0-open` |
| 03 Identité Entra | Jeton `Authorization: Bearer` pour l'audience du serveur | HTTP 401 et un défi `WWW-Authenticate` | Rien encore (voir la question plus bas) |
| 04 Passerelle | Le même jeton, envoyé à API Management | HTTP 401 ; HTTP 403 sans le bon rôle | Rien : la passerelle filtre avant le serveur |
| 05 Délégué ou application seule | Le même jeton | Pareil | `whoami` et `read_report_as_*` appellent vraiment Graph et Storage |

## Les cinq outils

| Outil | Type | Entrée | Réponse aux niveaux 0 à 2 | Réponse au niveau 3 (module 05) |
|---|---|---|---|---|
| `get_service_health` | Lecture | `service` : `workshop-api` ou `ticket-queue` | `healthy` ou `degraded`, valeur fixe | Identique |
| `create_ticket` | **Écriture** | `service`, `severity` (`low`, `medium`, `high`), `summary` (10 à 120 caractères simples) | Met un ticket fictif en file, renvoie son identifiant et un **avertissement de risque** | Même outil ; le module 04 exige le rôle `Tools.Write` |
| `whoami` | Lecture | aucune | `caller: unknown`, aucun appel en aval | Libellé de persona venant de Microsoft Graph, via On-Behalf-Of |
| `read_report_as_user` | Lecture | `report` : `monthly-usage` | Démonstration étiquetée, aucun appel en aval | Lit Storage **au nom de l'utilisateur** : c'est son propre rôle qui décide |
| `read_report_as_app` | Lecture | `report` : `monthly-usage` | Démonstration étiquetée, aucun appel en aval | Lit Storage **au nom de l'application** : même résultat pour tout le monde |

## Échange réel, connecté en tant qu'Alice (état du module 03)

**1. Sans jeton.** Le serveur refuse, et indique au client où obtenir un jeton :

```text
HTTP 401
WWW-Authenticate: Bearer ... resource_metadata="https://func-mcp-p01-<suffix>.azurewebsites.net/.well-known/oauth-protected-resource/runtime/webhooks/mcp", scope="api://00000000-0000-0000-0000-000000000000/user_impersonation"
```

Le document de métadonnées (Protected Resource Metadata, en **Preview** dans Functions) indique l'autorité et le scope :

```json
{"resource":"https://func-mcp-p01-<suffix>.azurewebsites.net",
 "authorization_servers":["https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"],
 "scopes_supported":["api://00000000-0000-0000-0000-000000000000/user_impersonation"]}
```

**2. `initialize`** avec le jeton d'Alice : HTTP 200. Le serveur se présente :

```text
event: message
data: {"result":{"protocolVersion":"2025-06-18",
  "capabilities":{"logging":{},"prompts":{},"resources":{},"tools":{}},
  "serverInfo":{"name":"workshop-open-mcp","version":"0.2.0"},
  "instructions":"Workshop level 0. Synthetic data only. Never send real names, tickets, tokens or secrets."},
  "id":1,"jsonrpc":"2.0"}
```

**3. `tools/list`** : HTTP 200, les cinq outils, chacun avec sa description et son schéma d'entrée (extrait) :

```json
{"name":"get_service_health",
 "description":"Read fixed synthetic health data for a workshop service. No real monitoring.",
 "inputSchema":{"type":"object",
   "properties":{"service":{"type":"string","enum":["workshop-api","ticket-queue"]}},
   "required":["service"],"additionalProperties":false}}
```

**4. `tools/call`.** Le résultat est du **texte** placé dans `content`. Ici, ce texte est du JSON :

| Appel | Réponse réelle (le champ `text`, décodé) |
|---|---|
| `get_service_health` `{"service":"workshop-api"}` | `{"service":"workshop-api","status":"healthy","source":"synthetic","level":"0-open"}` |
| `get_service_health` `{"service":"ticket-queue"}` | `{"service":"ticket-queue","status":"degraded","source":"synthetic","level":"0-open"}` |
| `get_service_health` `{"service":"payroll"}` | `An error occurred invoking 'get_service_health'.` avec `"isError": true` |
| `whoami` `{}` | `{"caller":"unknown","source":"synthetic-demonstration","level":"0-open","downstreamCall":"none","explanation":"A function key identifies no user. Module 03 adds Microsoft Entra sign-in; module 05 adds On-Behalf-Of to Microsoft Graph."}` |
| `read_report_as_user` `{"report":"monthly-usage"}` | `{"report":"monthly-usage","mode":"as-user (demonstration)","source":"synthetic-demonstration","level":"0-open","downstreamCall":"none","authorization":"Not evaluated: ...","rows":[{"service":"workshop-api","requests":1200,"errors":3},{"service":"ticket-queue","requests":340,"errors":12}]}` |
| `read_report_as_app` `{"report":"monthly-usage"}` | Mêmes lignes, `"mode":"as-app (demonstration)"` |

L'enveloppe complète d'un appel :

```text
event: message
data: {"result":{"content":[{"type":"text","text":"{\"service\":\"workshop-api\",\"status\":\"healthy\",\"source\":\"synthetic\",\"level\":\"0-open\"}"}]},"id":3,"jsonrpc":"2.0"}
```

Chaque appel a pris environ 1 seconde (Flex Consumption, instance déjà démarrée).

> **Ce que cela signifie pour vous :** un mauvais argument renvoie une erreur courte et générique avec `isError: true`,
> jamais une pile d'appels ni un détail interne. Le statut HTTP reste 200 : en MCP, une erreur d'**outil** fait partie
> de la réponse, ce n'est pas une erreur de transport.

**Question :** Alice est connectée avec Microsoft Entra. Pourquoi `whoami` répond-il encore `caller: unknown` et `level: 0-open` ?

<details>
<summary>Afficher la réponse</summary>

Parce que l'authentification se fait **devant** le code. Au module 03, la plateforme Functions vérifie le jeton avant
que la requête n'atteigne le serveur, et le code du serveur ne change pas. Les outils gardent leurs réponses de niveau 0
jusqu'au module 05, qui active le code qui lit l'appelant et appelle Graph et Storage. L'étiquette décrit le code de
l'outil, pas la porte d'entrée.

</details>

`create_ticket` n'a pas été appelé ici : il écrit. Au module 02, sa réponse ressemble à ceci (l'identifiant change à chaque appel) :

```json
{"ticketId":"TCK-1A2B3C4D","service":"ticket-queue","severity":"low","status":"queued","source":"synthetic","level":"0-open",
 "warning":"Level 0: anyone holding the function key can call this write tool. No user identity or role was checked."}
```

## Au niveau 3 (module 05)

Quand le mode du module 05 est activé, les mêmes appels suivent le vrai chemin d'identité. Le module 05 montre les
résultats complets : [module 05, ce que vous devez voir](../../modules/05-delegated-and-app-only/README.fr.md#ce-que-vous-devez-voir).

| Outil | Forme de la réponse au niveau 3 |
|---|---|
| `whoami` | `persona` (par exemple `alice`), `identity: signed-in user (On-Behalf-Of)`, `graphMatchesCaller: true` ; jamais de nom ni d'adresse e-mail |
| `read_report_as_user` | `mode: as-user`, les lignes **si le rôle Storage de l'utilisateur le permet** ; Bob obtient `isError: true` |
| `read_report_as_app` | `mode: as-app`, les mêmes lignes pour Alice et Bob : c'est le rôle de l'identité managée qui décide |

## L'essayer vous-même

Passez par un client MCP, pas par un navigateur : VS Code ou l'Inspector vous connectent grâce aux métadonnées
ci-dessus. Voir [Tester votre serveur MCP](PRACTICE.md). Le script de validation de chaque module fait aussi ces appels
pour vous et affiche une ligne `PASS` par contrôle.

## Sources

- [Model Context Protocol : transport Streamable HTTP](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports)
- [Model Context Protocol : outils, résultats et `isError`](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)
- [Extension MCP d'Azure Functions](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp)
- [Protected Resource Metadata pour App Service et Functions (Preview)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp)

Dernière vérification : 2026-10-19.

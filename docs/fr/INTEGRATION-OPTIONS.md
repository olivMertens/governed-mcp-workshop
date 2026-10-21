# Séquence 2 - Intégrer et exposer des serveurs MCP dans l'architecture d'entreprise

Page présentateur, environ 35 minutes. Elle suit la matinée sur les bases de MCP et précède la séquence sur la sécurité.
Toutes les démonstrations utilisent des données fictives (Contoso, Alice, Bob, Eve) dans un tenant hors production.

**Le message :** pour chaque serveur MCP, une entreprise prend quatre décisions : **où il tourne**, **comment les
clients l'atteignent**, **comment les équipes le trouvent** et **qui l'utilise**. Azure API Management devient la porte
d'entrée unique, quel que soit le serveur derrière.

## 1. Du serveur local à une architecture sécurisée sur Azure

Suivez le parcours d'un appel d'outil, depuis le serveur exécuté sur votre poste jusqu'à la passerelle Azure API Management.
Faites avancer le schéma pour comprendre le rôle de chaque composant et retrouver les commandes associées.
Utilisez le bouton **Étape suivante** ou les flèches du clavier.

```reveal
{
  "title": "Du serveur local à une architecture sécurisée sur Azure",
  "width": 1100,
  "height": 500,
  "lanes": [
    {"x":10,"width":240,"label":"Consommer · clients"},
    {"x":315,"width":245,"label":"Exposer · porte d'entrée"},
    {"x":615,"width":245,"label":"Héberger · où il tourne"},
    {"x":885,"width":205,"label":"Découvrir · inventaire"}
  ],
  "nodes": [
    {"id":"vscode","step":0,"tone":"morning","x":20,"y":44,"width":210,"title":"VS Code + Copilot","detail":["Alice (Contoso)","mode Agent"]},
    {"id":"local","step":0,"until":1,"tone":"morning","x":630,"y":44,"width":215,"title":"Serveur MCP local","detail":["stdio · Workshop.LocalMcp","get_service_health"]},
    {"id":"func","step":1,"x":630,"y":150,"width":215,"icon":"functions","title":"Azure Functions","detail":["extension MCP","/runtime/webhooks/mcp"]},
    {"id":"entra","step":2,"tone":"governed","x":330,"y":44,"width":215,"icon":"entra","title":"Microsoft Entra ID","detail":["aud: api://<client-id>","roles: Tools.Read"]},
    {"id":"apimA","step":2,"tone":"governed","x":330,"y":150,"width":215,"icon":"apim","title":"workshop-mcp","detail":["API Management · partie A","/workshop-mcp/mcp"]},
    {"id":"apimB","step":3,"tone":"preview","x":330,"y":260,"width":215,"icon":"apim","title":"contoso-tickets-mcp","detail":["partie B · Preview","list_tickets · get_ticket"]},
    {"id":"rest","step":3,"x":630,"y":260,"width":215,"title":"contoso-tickets-api","detail":["GET /tickets/{ticketId}","mock-response, sans backend"]},
    {"id":"anon","step":5,"tone":"risk","x":20,"y":300,"width":210,"title":"Appel sans jeton","detail":["validate-rest-mcp.ps1","HTTP 401 + challenge"]},
    {"id":"clients","step":6,"tone":"governed","x":20,"y":410,"width":210,"icon":"foundry-agent-service","title":"Autres clients","detail":["Foundry Agent Service","Copilot Studio"]},
    {"id":"apic","step":7,"tone":"preview","x":895,"y":300,"width":195,"icon":"api-center","title":"Azure API Center","detail":["Preview","URL passerelle seule"]},
    {"id":"catalog","step":7,"tone":"preview","x":895,"y":410,"width":195,"icon":"foundry-agent-service","title":"Catalogue d'outils","detail":["Foundry · Preview","lit API Center"]}
  ],
  "edges": [
    {"from":"vscode","to":"local","step":0,"until":1,"tone":"morning","label":"stdio"},
    {"from":"vscode","to":"func","step":1,"until":2,"tone":"risk","label":"clé de fonction"},
    {"from":"vscode","to":"apimA","step":2,"tone":"governed","label":"jeton Entra"},
    {"from":"entra","to":"apimA","step":2,"tone":"governed","label":"valider le jeton"},
    {"from":"apimA","to":"func","step":2,"tone":"governed","label":"privé"},
    {"from":"apimB","to":"rest","step":3,"tone":"preview","label":"op = outil"},
    {"from":"vscode","to":"apimB","step":4,"tone":"governed","fromSide":"bottom","toSide":"left","toOffset":-10,"label":"list_tickets"},
    {"from":"anon","to":"apimB","step":5,"tone":"risk","offset":10,"label":"401"},
    {"from":"clients","to":"apimB","step":6,"tone":"governed","toSide":"bottom","toOffset":-50,"label":"même URL"},
    {"from":"apimB","to":"apic","step":7,"tone":"preview","fromSide":"bottom","toSide":"left","fromOffset":50,"bend":70,"label":"inscrire l'URL passerelle","labelDy":26},
    {"from":"apic","to":"catalog","step":7,"tone":"preview","label":"lit"}
  ],
  "steps": [
    {
      "title": "Point de départ : un serveur sur votre poste",
      "simple": "Au départ, l'outil s'exécute sur votre poste. Le client qui lance ce processus peut l'appeler.",
      "say": "Dans le [module 01](../../modules/01-discover-mcp/README.fr.md), le client démarre le serveur comme processus enfant et communique avec lui en **stdio** : les échanges restent sur votre poste. `tools/list` renvoie `get_service_health`.",
      "show": "Listez les outils avec MCP Inspector. Vous devez retrouver `get_service_health`. Ce serveur local n'est pas accessible aux autres participants par le réseau.",
      "blocks": [
        {
          "language": "powershell",
          "code": "$server = (Resolve-Path .\\modules\\01-discover-mcp\\server\\bin\\Release\\net10.0\\Workshop.LocalMcp.dll).Path\nnpx @modelcontextprotocol/inspector@2.9.0 --cli dotnet $server --method tools/list"
        }
      ]
    },
    {
      "title": "Héberger : les mêmes outils sur Azure Functions",
      "simple": "On met le même outil dans le cloud. Il fonctionne, mais quiconque a la clé peut l'appeler.",
      "say": "Décision 1, **où il tourne**. Le [module 02](../../modules/02-open-server/README.fr.md) déploie l'extension MCP sur Azure Functions. Le point de terminaison est public et seule une clé de fonction le protège : le niveau **ouvert**, montré pour rendre le risque visible.",
      "show": "L'URL `https://<function-app-host>/runtime/webhooks/mcp`. La clé va dans le presse-papiers, jamais à l'écran. Faites-la tourner juste après la démo.",
      "blocks": [
        {
          "language": "powershell",
          "code": "terraform '-chdir=infra\\workload' apply '..\\..\\.workshop\\module02.tfplan'\n$group = terraform -chdir=infra/workload output -raw resource_group_name\n$app = terraform -chdir=infra/workload output -raw mcp_function_app_name\naz functionapp deployment source config-zip --resource-group $group --name $app --src .\\.workshop\\module02.zip --output none\naz functionapp keys list --resource-group $group --name $app --query systemKeys.mcp_extension --output tsv | Set-Clipboard"
        }
      ]
    },
    {
      "title": "Exposer : API Management devient la porte d'entrée",
      "simple": "On ajoute une porte d'entrée. Elle vérifie votre badge avant de vous laisser entrer.",
      "say": "Décision 2, **comment les clients l'atteignent**. La partie A du [module 04](../../modules/04-governed-gateway/README.fr.md) place API Management devant la Function. La passerelle valide un jeton Microsoft Entra émis pour l'audience du serveur, vérifie un rôle par outil et limite les appels par appelant. La clé de fonction disparaît et la Function n'est plus publiée.",
      "show": "La configuration du client : une URL de passerelle, sans en-tête, sans clé, sans secret. `$vars` vient de l'étape 3 du module 04.",
      "blocks": [
        {
          "language": "powershell",
          "code": "terraform '-chdir=infra\\workload' plan @vars '-out=..\\..\\.workshop\\module04.tfplan'\nterraform '-chdir=infra\\workload' apply '..\\..\\.workshop\\module04.tfplan'"
        },
        {
          "language": "json",
          "code": "{\n  \"servers\": {\n    \"workshop-governed\": { \"type\": \"http\", \"url\": \"https://apim-mcp-<prefix>-<suffix>.azure-api.net/workshop-mcp/mcp\" }\n  }\n}"
        }
      ]
    },
    {
      "title": "Exposer, partie B : une API REST devient un serveur MCP",
      "simple": "Une API existante peut aussi devenir des outils, sans nouveau code, derrière la même porte.",
      "say": "Personne n'écrit de code MCP. Chaque opération d'API cochée devient un outil sur la même passerelle, avec le même contrôle de jeton. Les serveurs MCP d'API Management sont en **Preview** pour l'infrastructure as code (`2025-09-01-preview`).",
      "show": "Portail Azure, API Management, **MCP Servers** : `contoso-tickets-mcp`, puis **Tools** : `list_tickets` et `get_ticket`.",
      "blocks": [
        {
          "language": "powershell",
          "code": "$varsB = $vars + '-var-file=..\\..\\.workshop\\module04b.tfvars.json'\nterraform '-chdir=infra\\workload' plan @varsB '-out=..\\..\\.workshop\\module04b.tfplan'\nterraform '-chdir=infra\\workload' apply '..\\..\\.workshop\\module04b.tfplan'"
        },
        {
          "language": "text",
          "code": "azapi_resource.rest_mcp_api[0]: Creation complete after 5s [id=.../apis/contoso-tickets-mcp]\nazapi_resource.rest_mcp_tool[\"get_ticket\"]: Creation complete after 2s [id=.../apis/contoso-tickets-mcp/tools/get_ticket]\nazapi_resource.rest_mcp_tool[\"list_tickets\"]: Creation complete after 3s [id=.../apis/contoso-tickets-mcp/tools/list_tickets]",
          "output": true
        }
      ]
    },
    {
      "title": "Consommer : Alice appelle un outil",
      "simple": "Alice montre son badge, demande un ticket et obtient la réponse.",
      "say": "Décision 4, **qui le consomme**. Dans VS Code, le serveur n'est qu'une URL. Alice se connecte, la passerelle vérifie son jeton et son rôle, et l'outil répond avec des tickets synthétiques.",
      "show": "Copilot Chat en mode **Agent**. Approuvez vous-même chaque appel d'outil.",
      "blocks": [
        {
          "language": "prompt",
          "code": "Utilise le serveur MCP contoso-tickets. Appelle list_tickets, puis get_ticket avec ticketId \"CT-1001\" et résume le ticket."
        }
      ]
    },
    {
      "title": "Pas de jeton, pas d'outil",
      "simple": "Pas de badge, pas d'entrée : la porte répond 401 et indique où obtenir un badge.",
      "say": "Le même appel sans jeton reçoit **HTTP 401** avec un challenge qui désigne les métadonnées de la passerelle. Un jeton pour une autre audience (Microsoft Graph) est refusé aussi. C'est le pont vers la séquence sécurité.",
      "show": "Les lignes PASS du validateur : chacune indique le statut HTTP attendu.",
      "blocks": [
        {
          "language": "powershell",
          "code": "& .\\modules\\04-governed-gateway\\validate-rest-mcp.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID"
        },
        {
          "language": "text",
          "code": "PASS part B MCP request without a token is refused with a challenge naming its metadata URL (expected HTTP 401).\nPASS the backing REST API /contoso-tickets/tickets without a token is refused (expected HTTP 401).\nPASS a valid token for another audience (Microsoft Graph) is refused by the part B MCP server and its REST API (expected HTTP 401).",
          "output": true
        }
      ]
    },
    {
      "title": "La même porte d'entrée pour tous les clients",
      "simple": "Tous les clients passent par la même porte. Seul le badge change.",
      "say": "Foundry Agent Service et Copilot Studio utilisent la même URL de passerelle. Seule l'identité change : celle de l'utilisateur (On-Behalf-Of) ou celle de l'agent (app-only). Voir les modules [05](../../modules/05-delegated-and-app-only/README.fr.md) et [07](../../modules/07-clients/README.fr.md).",
      "show": "Une passerelle, plusieurs clients. L'URL du backend n'apparaît dans aucun client."
    },
    {
      "title": "Découvrir : inscrire la passerelle, pas le backend",
      "simple": "On inscrit l'adresse de la porte dans un catalogue : les autres équipes la réutilisent au lieu d'en refaire une.",
      "say": "Décision 3, **comment les équipes le trouvent**. Azure API Center (**Preview** pour MCP) garde une entrée par serveur, avec propriétaire et environnement. Le catalogue d'outils privé de Foundry (**Preview**) lit cet inventaire. Étapes dans le portail au [module 06](../../modules/06-observe-inventory/README.fr.md).",
      "show": "L'entrée API Center : le point de terminaison est l'URL de la passerelle. Transition : « Ensuite : qui porte les droits à chaque appel, un jeton par saut. »"
    }
  ]
}
```

## 2. La vue d'ensemble

**En une phrase :** où qu'un serveur MCP tourne, les personnes et les agents l'atteignent par une seule porte d'entrée
qui vérifie qui ils sont, et les autres équipes le trouvent dans un seul inventaire.

![Architecture de la séquence 2 : à gauche, les clients appellent une seule porte d'entrée API Management avec un jeton Microsoft Entra ; derrière, le serveur MCP Azure Functions (partie A) et une API REST dont les opérations deviennent des outils (partie B, Preview) ; l'URL de la passerelle est inscrite dans Azure API Center, que lit le catalogue d'outils Foundry (Preview)](../../assets/architecture/session2.fr.svg)

#### Lire de gauche à droite

1. **Consommer : qui appelle.** Une personne dans VS Code, un agent Foundry ou un agent Copilot Studio demande un outil.
2. **Exposer : la porte d'entrée.** API Management vérifie le badge (un jeton Microsoft Entra émis pour ce serveur) et
   le rôle, puis laisse passer l'appel. Sans badge : HTTP 401.
3. **Héberger : où il tourne.** Derrière la porte, l'équipe garde son propre serveur (Azure Functions) ou transforme une
   API REST existante en outils. Personne ne les appelle directement.
4. **Découvrir : comment les équipes le trouvent.** L'adresse de la porte est inscrite dans un inventaire : les autres
   équipes la réutilisent au lieu d'en refaire une.

<details>
<summary>Avancé : lire le schéma</summary>

- **Un jeton par saut, une audience par jeton.** Les clients obtiennent un jeton Microsoft Entra pour l'audience du
  serveur MCP (`api://<client-id>`). La passerelle valide émetteur, tenant, audience et expiration avec
  `validate-azure-ad-token`, puis vérifie le rôle d'application par outil (`Tools.Read`, `Tools.Write`) et applique
  une limite par identifiant d'objet de l'appelant ([module 04](../../modules/04-governed-gateway/README.fr.md)).
- **Pas de transmission du jeton aux API en aval.** Les appels de la Function vers d'autres API utilisent On-Behalf-Of
  ou une identité managée, choisi outil par outil ([module 05](../../modules/05-delegated-and-app-only/README.fr.md)).
- **Le backend n'est jamais publié.** La partie A atteint la Function par un point de terminaison privé ; son accès
  réseau public est désactivé. La partie B n'a pas de backend : des stratégies REST (`mock-response`) répondent avec
  des tickets fictifs.
- **Découverte pour les clients.** Un appel sans jeton reçoit HTTP 401 avec un challenge qui désigne les métadonnées de
  ressource protégée de la passerelle (RFC 9728) : les clients comme VS Code savent où se connecter.
- **Pas de clé d'abonnement.** Chaque API définit `subscriptionRequired = false` : l'accès dépend uniquement des jetons
  Microsoft Entra et des rôles d'application.
- **De l'inventaire, pas du trafic.** API Center (**Preview** pour MCP) conserve l'URL de la passerelle, le propriétaire
  et l'environnement ([module 06](../../modules/06-observe-inventory/README.fr.md)) ; le catalogue d'outils privé de
  Foundry (**Preview**) le lit.
- **Infrastructure as code.** Les serveurs MCP d'API Management utilisent la version d'API `2025-09-01-preview`
  (**Preview**) via le fournisseur azapi, dans `infra/workload/gateway.tf` et `infra/workload/rest-mcp.tf`.
- Modifiez le schéma dans [session2.drawio](../../assets/architecture/session2.drawio), puis régénérez le SVG et le PNG
  avec `scripts/render-architecture.py`.

</details>

## 3. Les quatre décisions

| Décision | La question | La réponse Azure | Dans cet atelier |
|---|---|---|---|
| Héberger | Où le serveur tourne-t-il ? | Azure Functions, App Service, Container Apps, AKS | [Module 02](../../modules/02-open-server/README.fr.md) (Functions) |
| Exposer | Comment les clients l'atteignent-ils, et qui les contrôle ? | Azure API Management : un serveur MCP existant, ou une API REST transformée en outils | [Module 04](../../modules/04-governed-gateway/README.fr.md), parties A et B |
| Faire connaître | Comment les autres équipes le trouvent-elles au lieu d'en refaire un ? | Inventaire Azure API Center, catalogue privé d'outils Foundry (**Preview**) | [Module 06](../../modules/06-observe-inventory/README.fr.md) |
| Consommer | Quels clients l'appellent, avec quelle identité ? | GitHub Copilot dans VS Code, Foundry Agent Service, Copilot Studio | Modules [03](../../modules/03-entra-authentication/README.fr.md) à [07](../../modules/07-clients/README.fr.md) |

**À dire en une phrase :** le choix de l'hébergement appartient à l'équipe qui possède le code ; la porte d'entrée,
l'identité et l'inventaire appartiennent à la plateforme.

## 4. Où héberger un serveur MCP

| Option | À choisir quand | Remarques |
|---|---|---|
| Azure Functions (extension MCP) | Outils sans état, facturation à l'appel | Le choix de l'atelier. Clés de fonction ou Microsoft Entra ID |
| App Service, votre propre serveur | Vous ajoutez MCP à une application web existante | Authentification App Service avec Microsoft Entra ID |
| App Service, MCP intégré (**Preview**) | Une API REST décrite en OpenAPI 3.x doit devenir MCP vite, sans code MCP | Chaque opération OpenAPI devient un outil |
| Azure Container Apps | N'importe quel langage en conteneur, mise à l'échelle jusqu'à zéro | Authentification intégrée avec Microsoft Entra ID |
| Sessions dynamiques Container Apps | Exécution de code isolée avec les outils de la plateforme | Pas d'outils personnalisés ; isolation Hyper-V par session |
| Azure Kubernetes Service | L'équipe exploite déjà Kubernetes | Effort d'exploitation le plus élevé |

**Question à poser à la salle :** votre équipe héberge déjà ses API sur App Service. Faut-il les déplacer vers Functions
pour ajouter MCP ?

<details>
<summary>Afficher la réponse</summary>

Non. Gardez la plateforme que l'équipe exploite déjà. Ce qui doit rester identique partout, c'est la gouvernance : un
jeton Microsoft Entra émis pour l'audience du serveur, une passerelle devant, des journaux limités aux métadonnées et
une entrée dans l'inventaire.

</details>

## 5. Exposer : deux modèles avec Azure API Management

| | Partie A : serveur MCP existant derrière la passerelle | Partie B : API REST exposée en serveur MCP |
|---|---|---|
| Qui écrit le code MCP | L'équipe du serveur (ici, Azure Functions) | Personne : les opérations de l'API deviennent des outils |
| Ce que reçoit le client | Des outils et des ressources ; API Management ne prend pas encore en charge les prompts MCP | Des outils seulement (ni ressources ni prompts) |
| Où l'identité est vérifiée | Par la passerelle, puis de nouveau par le serveur | Par la passerelle |
| Logique côté serveur | Libre : plusieurs appels, On-Behalf-Of, identité managée | Une opération par outil |
| À choisir quand | Les outils sont conçus pour des agents ou ont leur propre logique | Une API REST stable existe déjà et des appels simples suffisent |

Dans les deux cas, la passerelle ajoute les mêmes contrôles : un jeton Microsoft Entra pour une seule audience, un rôle
par outil, une limite de débit par appelant, des journaux limités aux métadonnées et une seule URL publique. Le backend
n'est jamais publié.

Bon à savoir :

- Niveaux pris en charge : Developer, Basic, Standard, Premium, Basic v2, Standard v2 et Premium v2. Les serveurs MCP ne
  sont pas pris en charge dans les *workspaces* API Management.
- L'infrastructure en code utilise la version d'API `2025-09-01-preview` d'API Management (**Preview**).
- Ne lisez jamais le corps de la réponse dans une stratégie de serveur MCP : cela casse le streaming.

## 6. Démo 3 : une API REST devient un serveur MCP (8 minutes environ)

Avant la séance : déployez la [partie B du module 04](../../modules/04-governed-gateway/README.fr.md) dans le tenant de
test, lancez son validateur et gardez les captures réelles prêtes en solution de repli. Supprimez API Management le jour
même.

1. Dans le portail Azure, ouvrez API Management, **APIs**, puis l'API REST **Contoso Tickets**. Montrez ses deux
   opérations : elles renvoient des tickets fictifs, sans aucun backend.
2. Ouvrez **MCP Servers** : le serveur MCP **Contoso Tickets** liste deux outils, `list_tickets` et `get_ticket`. Chacun
   pointe vers une opération de l'API.
3. Ouvrez les **Policies** du serveur MCP : le même contrôle de jeton Microsoft Entra que le serveur gouverné, une limite
   de débit par appelant et un contrôle de rôle. Aucune clé d'abonnement.
4. Dans VS Code, le serveur se résume à une URL. Connectez-vous en tant qu'Alice, puis collez ce prompt dans Copilot Chat
   (mode **Agent**) :

   ```prompt
   Utilise le serveur MCP contoso-tickets. Appelle list_tickets, puis get_ticket avec ticketId "CT-1001", et résume le ticket.
   ```

5. Montrez le cas d'échec : l'appel du validateur sans jeton reçoit HTTP 401 avec le lien vers les métadonnées. C'est
   la transition vers la séquence sur la sécurité.

Solution de repli si la démo en direct ne peut pas tourner : ces captures réelles viennent du même déploiement
(2026-10-19, tenant de test de l'auteur ; noms pseudonymisés, ID remplacés par des zéros).

![Capture réelle : liste MCP Servers d'API Management ; le cadre 1 marque workshop-mcp avec la source MCP server (relais vers la Function), le cadre 2 contoso-tickets-mcp avec la source API (construit à partir de l'API REST)](../../assets/screenshots/azure-04-mcp-servers.png)

![Capture réelle : page Tools du serveur MCP, avec les deux opérations REST sélectionnées comme outils](../../assets/screenshots/azure-04b-mcp-tools.png)

![Sortie réelle du terminal : Alice liste les deux outils et les appelle à travers la passerelle](../../assets/screenshots/terminal-04b-alice.png)

## 7. Inventaire et découverte

- **Azure API Center** sert d'inventaire : une entrée par serveur MCP, avec son propriétaire, son environnement et son
  point de terminaison. Enregistrez l'URL de la passerelle, jamais celle du backend
  ([module 06](../../modules/06-observe-inventory/README.fr.md)).
- Le **catalogue privé d'outils Foundry (Preview)** s'appuie sur cet inventaire : les développeurs retrouvent les serveurs
  MCP de l'organisation dans Foundry Tools. Il leur faut au minimum le rôle Azure API Center Data Reader. Une attribution
  de rôle peut mettre jusqu'à 24 heures à s'appliquer.
- La gouvernance à l'échelle du tenant avec Agent 365 et les serveurs MCP « BYO » de Microsoft 365 (**Preview**) relève
  de la séquence Agent 365.

## 8. Ce qu'un administrateur général doit vérifier quand une entité adopte Foundry

1. **Le consentement.** Qui peut donner son consentement aux applications et aux agents, et le circuit de demande de
   consentement administrateur est-il activé ?
2. **Qui peut ajouter des serveurs MCP.** Les rôles du projet Foundry décident qui peut ajouter des outils et des
   connexions. Préférez le catalogue privé aux URL saisies librement.
3. **Les identités.** Les agents ont leurs propres identités (Microsoft Entra Agent ID, **Preview**) : recensez-les comme
   des applications, avec un propriétaire et une date d'expiration.
4. **L'accès conditionnel.** Utilisateurs et agents atteignent les mêmes serveurs MCP : appliquez les mêmes règles de
   connexion.
5. **Les données qui sortent du tenant.** Un serveur MCP tiers reçoit des prompts et des arguments d'outils. Approuvez
   chacun comme une application SaaS.
6. **Journaux et coûts.** Des métadonnées seulement (outil, appelant, statut, latence). API Management v2 et Foundry sont
   facturés tant qu'ils tournent : étiquetez propriétaires et dates d'expiration.

**Transition vers la séquence suivante :** « Nous savons où vivent les serveurs MCP et comment on les expose. Voyons
maintenant qui porte les droits à chaque appel : un jeton par saut. »

## 9. Pour conclure : qu'est-ce que Microsoft Agent 365 ?

**Agent 365 est le plan de contrôle des agents, pas un nouvel outil de création d'agents ni un serveur MCP.**
Il aide les administrateurs à observer, gouverner et sécuriser les agents de l'organisation, même lorsqu'ils
proviennent de plateformes différentes. Son registre central rassemble l'inventaire, les propriétaires et la gestion
du cycle de vie. Il s'appuie sur Microsoft Entra pour les identités et les accès, Microsoft Purview pour la gouvernance
des données et Microsoft Defender pour la protection contre les menaces. Les fonctions disponibles dépendent
des licences et de la configuration.

Retenez trois responsabilités distinctes :

| Composant | Responsabilité |
|---|---|
| Azure API Center | Cataloguer les serveurs MCP pour retrouver les adresses approuvées. Ce n'est pas une étape à l'exécution. |
| Microsoft Agent 365 | Donner aux administrateurs une vue centrale et des décisions de gouvernance sur les agents et leurs outils. |
| Azure API Management | Appliquer les contrôles configurés aux appels qui traversent la passerelle. |

**Disponibilité :** Agent 365 est généralement disponible pour le segment Commercial depuis le 2026-05-01.
Son **intégration avec API Management reste en Preview**. Sur API Management v2, elle permet l'inventaire des serveurs
MCP et le blocage d'un serveur entier (HTTP 403). Le blocage d'un outil par Agent 365 exige le
**niveau AI Gateway (Preview)** ; les stratégies par rôle et par outil de notre passerelle v2 sont un contrôle distinct.

Cette intégration exige le consentement unique d'un administrateur du tenant pour le rôle
**A365 MCP Gateway Policy Operator**. Ce droit permet de lire les ressources de passerelle et de lire ou modifier
les stratégies des API dans les abonnements du tenant. Ce n'est pas un prérequis participant : gardez-le comme
discussion facultative avec l'animateur, avec approbation séparée, licences et tenant de test. Cette page n'active rien.

**Conservez la frontière :** Agent 365 ne redirige pas les clients vers API Management, ne remplace pas les contrôles
d'audience et de rôle de la passerelle, ni l'approbation humaine des outils d'écriture. Les clients doivent toujours
utiliser l'URL de la passerelle et l'accès direct au backend doit rester bloqué. L'atelier ne journalise que des
métadonnées, jamais les prompts, les arguments ou les résultats.

**À retenir :** API Center aide à trouver la porte ; Agent 365 aide les administrateurs à décider ce qui est permis ;
API Management contrôle chaque appel à la porte.

## Sources

- [Serveurs MCP dans Azure API Management](https://learn.microsoft.com/azure/api-management/mcp-server-overview)
- [Exposer une API REST d'API Management en serveur MCP](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server)
- [Exposer et gouverner un serveur MCP existant](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server)
- [Gérer les serveurs MCP par programmation dans API Management](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) (version d'API `2025-09-01-preview`)
- [Choisir un service Azure pour votre serveur MCP](https://learn.microsoft.com/azure/container-apps/mcp-choosing-azure-service)
- [Inscrire et découvrir des serveurs MCP dans Azure API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server)
- [Créer un catalogue privé d'outils dans Foundry (préversion)](https://learn.microsoft.com/azure/foundry/agents/how-to/private-tool-catalog)
- [Vue d'ensemble et disponibilité de Microsoft Agent 365](https://learn.microsoft.com/microsoft-agent-365/overview)
- [Gouverner les outils avec Agent 365 et API Management (Preview)](https://learn.microsoft.com/azure/api-management/agent-365)

Dernière vérification : 2026-10-21.

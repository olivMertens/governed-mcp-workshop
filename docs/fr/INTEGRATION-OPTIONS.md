# Séquence 2 - Intégrer et exposer des serveurs MCP dans l'architecture d'entreprise

Page présentateur, environ 35 minutes. Elle suit la matinée sur les bases de MCP et précède la séquence sur la sécurité.
Toutes les démonstrations utilisent des données fictives (Contoso, Alice, Bob, Eve) dans un tenant hors production.

**Le message :** pour chaque serveur MCP, une entreprise prend quatre décisions : **où il tourne**, **comment les
clients l'atteignent**, **comment les équipes le trouvent** et **qui l'utilise**. Azure API Management devient la porte
d'entrée unique, quel que soit le serveur derrière.

## 1. Les quatre décisions

| Décision | La question | La réponse Azure | Dans cet atelier |
|---|---|---|---|
| Héberger | Où le serveur tourne-t-il ? | Azure Functions, App Service, Container Apps, AKS | [Module 02](../../modules/02-open-server/README.fr.md) (Functions) |
| Exposer | Comment les clients l'atteignent-ils, et qui les contrôle ? | Azure API Management : un serveur MCP existant, ou une API REST transformée en outils | [Module 04](../../modules/04-governed-gateway/README.fr.md), parties A et B |
| Faire connaître | Comment les autres équipes le trouvent-elles au lieu d'en refaire un ? | Inventaire Azure API Center, catalogue privé d'outils Foundry (**Preview**) | [Module 06](../../modules/06-observe-inventory/README.fr.md) |
| Consommer | Quels clients l'appellent, avec quelle identité ? | GitHub Copilot dans VS Code, Foundry Agent Service, Copilot Studio | Modules [03](../../modules/03-entra-authentication/README.fr.md) à [07](../../modules/07-clients/README.fr.md) |

**À dire en une phrase :** le choix de l'hébergement appartient à l'équipe qui possède le code ; la porte d'entrée,
l'identité et l'inventaire appartiennent à la plateforme.

## 2. Où héberger un serveur MCP

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

## 3. Exposer : deux modèles avec Azure API Management

| | Partie A : serveur MCP existant derrière la passerelle | Partie B : API REST exposée en serveur MCP |
|---|---|---|
| Qui écrit le code MCP | L'équipe du serveur (ici, Azure Functions) | Personne : les opérations de l'API deviennent des outils |
| Ce que reçoit le client | Des outils, et des ressources ou des prompts si le serveur en propose | Des outils seulement (ni ressources ni prompts) |
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

## 4. Démo 3 : une API REST devient un serveur MCP (8 minutes environ)

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

![Capture réelle : liste MCP Servers d'API Management avec contoso-tickets-mcp, construit à partir de l'API REST, et le serveur existant workshop-mcp](../../assets/screenshots/azure-04-mcp-servers.png)

![Capture réelle : page Tools du serveur MCP, avec les deux opérations REST sélectionnées comme outils](../../assets/screenshots/azure-04b-mcp-tools.png)

![Sortie réelle du terminal : Alice liste les deux outils et les appelle à travers la passerelle](../../assets/screenshots/terminal-04b-alice.png)

## 5. Inventaire et découverte

- **Azure API Center** sert d'inventaire : une entrée par serveur MCP, avec son propriétaire, son environnement et son
  point de terminaison. Enregistrez l'URL de la passerelle, jamais celle du backend
  ([module 06](../../modules/06-observe-inventory/README.fr.md)).
- Le **catalogue privé d'outils Foundry (Preview)** s'appuie sur cet inventaire : les développeurs retrouvent les serveurs
  MCP de l'organisation dans Foundry Tools. Il leur faut au minimum le rôle Azure API Center Data Reader. Une attribution
  de rôle peut mettre jusqu'à 24 heures à s'appliquer.
- La gouvernance à l'échelle du tenant avec Agent 365 et les serveurs MCP « BYO » de Microsoft 365 (**Preview**) relève
  de la séquence Agent 365.

## 6. Ce qu'un administrateur général doit vérifier quand une entité adopte Foundry

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

## Sources

- [Serveurs MCP dans Azure API Management](https://learn.microsoft.com/azure/api-management/mcp-server-overview)
- [Exposer une API REST d'API Management en serveur MCP](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server)
- [Exposer et gouverner un serveur MCP existant](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server)
- [Gérer les serveurs MCP par programmation dans API Management](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) (version d'API `2025-09-01-preview`)
- [Choisir un service Azure pour votre serveur MCP](https://learn.microsoft.com/azure/container-apps/mcp-choosing-azure-service)
- [Inscrire et découvrir des serveurs MCP dans Azure API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server)
- [Créer un catalogue privé d'outils dans Foundry (préversion)](https://learn.microsoft.com/azure/foundry/agents/how-to/private-tool-catalog)

Dernière vérification : 2026-10-19.

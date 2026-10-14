# Comprendre les frontières de gouvernance

Lisez une étape, prédisez son résultat, puis utilisez son vrai guide et son validateur lorsqu'ils seront publiés.
Ces explications décrivent le workshop **prévu**, pas un service déjà déployé.
Les schémas séparent requêtes, identité et administration ; ils ne lancent aucune opération.

> [!IMPORTANT]
> L'authentification répond à « qui appelle ? ». L'autorisation répond à « que peut faire cette identité ? ».
> L'approbation client répond à « l'humain autorise-t-il cette action précise ? ». Ces trois contrôles se complètent.

## 00 - Prérequis et environnement

**Objectif :** choisir outils, tenant, abonnement, permissions et budget.
L'administrateur d'identité contrôle applications et consentements Entra. L'opérateur Azure gère les ressources.
Le contrôle d'accès fondé sur les rôles (RBAC) nécessite une autorité distincte pour attribuer ces rôles.

**Schéma :** une ligne prépare les identités Entra ; l'autre prépare l'abonnement de test.
Ce ne sont pas des appels MCP. Un codespace est une machine de développement, pas un tenant.

> [!TIP]
> Commencez par le guide de contexte Azure du board. Identifiez le responsable des approbations d'identité.
> Ne demandez pas Owner par défaut.

**Preuve attendue :** le vrai précontrôle et la demande d'identité sont prêts. Choisir l'abonnement ne suffit pas.
**Suite :** module 01 après réussite du validateur publié du module 00. Aucune ressource cloud dans le module 01.

**Approfondir :** [tenant et abonnement](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli),
[attribution des rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).

## 01 - Découvrir MCP sans Azure

**Objectif :** distinguer découverte et exécution. Model Context Protocol (MCP) permet à un client de découvrir
des outils et leurs schémas puis de les appeler. Les entrées/sorties standard (stdio) servent au local ;
Streamable HTTP sert aux étapes distantes. Une ouverture d'URL dans un navigateur ne teste pas la découverte d'outils.

**Schéma :** client local, serveur local, outil synthétique. Ni Entra, ni passerelle, ni ressource cloud payante.
Les annotations d'outil aident le client mais ne font pas respecter les autorisations.

> [!IMPORTANT]
> Conservez l'approbation humaine des écritures. Vérifiez la trace d'appel réelle, pas seulement la réponse de l'assistant.

**Preuve attendue :** vraie liste d'outils, résultat synthétique réel et contrôle d'approbation visible.
**Suite :** module 02 seulement après validation et approbation du déploiement payant de test.

**Approfondir :** [architecture MCP](https://modelcontextprotocol.io/specification/2026-07-28/architecture),
[transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports),
[outils](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[client VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers).

## 02 - Une clé n'est pas une identité utilisateur

**Objectif :** montrer les limites d'un accès partagé. L'extension MCP d'Azure Functions utilise la clé système
`mcp_extension` et l'autorisation de webhook `System`. « Ouvert » signifie sans identité individuelle, pas anonyme.

**Schéma :** le client muni de la clé appelle Functions ; une écriture synthétique atteint une file Azure Storage.
Les outils dépendant d'une identité restent explicitement simulés jusqu'au module 05.

> [!WARNING]
> Gardez cette étape brève. Ne désactivez jamais la protection du webhook. Pas de clé dans une URL ou un en-tête enregistré.
> Toute personne possédant la clé peut appeler les actions exposées : ce n'est pas la cible d'entreprise.

**Preuve attendue :** HTTP 401 sans clé ; HTTP 200 et résultat MCP réussi avec la bonne clé.
**Suite :** module 03 pour remplacer la démonstration de clé partagée par l'authentification des utilisateurs affectés.

**Approfondir :** [exemple Functions épinglé](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9),
[liaisons MCP](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp).

## 03 - Identité, étendue et rôle applicatif

**Objectif :** n'accepter que les jetons destinés à cette ressource MCP.
La plateforme valide émetteur, tenant, audience et expiration, puis les étendues déléguées et rôles applicatifs
sont contrôlés. N'écrivez pas votre propre validateur JSON Web Token (JWT).
Une étendue décrit ce que le client peut faire pour l'utilisateur ; un rôle indique qui peut faire l'opération.

**Schéma :** la connexion remet d'abord un jeton au client. Une ligne séparée montre ensuite le client appeler
la Function avec ce jeton. Entra ne relaie pas les appels d'outils.
Les métadonnées de ressource protégée (PRM) sont en **Preview**.

> [!IMPORTANT]
> Alice et Bob sont affectés ; Eve ne l'est pas. Une connexion réussie ne donne pas tous les outils.
> Utilisez des claims fictifs, jamais un jeton réel dans un site de décodage, un chat ou un fichier.

**Preuve attendue :** HTTP 401 sans jeton ou avec la mauvaise audience ; Alice et Bob se connectent ;
Eve ne peut pas obtenir le jeton nécessitant une affectation. Les contrôles d'outil arrivent au module 04.
**Suite :** module 04 : API Management devient le point d'entrée imposé.

**Approfondir :** [autorisation MCP et PRM](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp),
[rôles applicatifs](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).

## 04 - Une passerelle imposée, pas une URL de confort

**Objectif :** API Management (APIM) contrôle audience MCP exacte, étendue, rôle et débit.
APIM et Functions protègent une seule ressource logique MCP. N'ajoutez pas d'audience acceptée pour faire passer un test.
L'API de gestion MCP `2025-09-01-preview` est en **Preview**. Ce n'est pas l'offre AI Gateway en preview.

**Schéma :** client, APIM Standard v2, Function privée. L'intégration réseau sortante et le DNS privé assurent
la connectivité ; la désactivation de l'accès public empêche le contournement. Le réseau ne remplace pas la validation du jeton.

> [!WARNING]
> Testez aussi le refus d'accès direct à la Function. Une passerelle fonctionnelle ne suffit pas.
> N'attribuez pas Tools.Write à Bob pour rendre la démonstration artificiellement positive.

**Preuve attendue :** écriture synthétique approuvée de Bob : HTTP 403 à la passerelle ; Alice : HTTP 200 et
résultat réussi ; dépassement de débit : 429 ; accès direct refusé ; zéro octet de corps dans les journaux.
**Suite :** module 05 : quels droits atteignent les données ?

**Approfondir :** [exposer un serveur existant](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server),
[validation de jeton](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy),
[réseau sortant](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound),
[gestion programmatique, Preview](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api).

## 05 - Accès délégué ou applicatif

**Objectif :** le flux On-Behalf-Of (OBO) obtient un **autre jeton** pour l'API cible en conservant le contexte utilisateur.
L'identité managée (MI) obtient un jeton applicatif avec ses propres droits limités à la ressource.
Bibliothèques officielles et fédération évitent les secrets clients.

**Schéma :** deux lignes indépendantes conservent APIM. La première utilise un jeton Storage délégué ;
la seconde un jeton Storage d'identité managée. `whoami` obtient séparément un jeton Microsoft Graph pour l'audience
Graph : Graph n'est pas le point de terminaison Storage représenté.

> [!WARNING]
> Ne transmettez jamais le jeton MCP à Graph ou Storage. Une identité applicative n'usurpe pas l'utilisateur.
> Pas de repli sur l'identité du développeur lorsqu'une délégation échoue.

| Outil | Alice | Bob | Droits utilisés |
|---|---|---|---|
| `read_report_as_user` | Autorisé | Refus de la ressource cible | Ceux de l'utilisateur |
| `read_report_as_app` | Même rapport synthétique autorisé | Même rapport synthétique autorisé | Ceux de l'identité managée |

**Preuve attendue :** les quatre cas. Notez le statut de transport et l'erreur MCP :
un refus HTTP 403 de Storage peut se trouver dans une enveloppe HTTP 200.
**Suite :** module 06 pour observer les métadonnées sans capturer le contenu.

**Approfondir :** [frontière des jetons OBO](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow),
[fédération sans secret](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).

## 06 - Observer les métadonnées, inventorier les adresses

**Objectif :** savoir qui a appelé quel outil et avec quel résultat sans enregistrer le corps.
Conservez seulement ID objet de l'appelant authentifié, nom d'outil fixe, statut, latence et ID de corrélation.
Kusto Query Language (KQL) permet de corréler ces champs autorisés.

**Schéma :** chemin des requêtes, télémétrie et enregistrement d'inventaire sont séparés.
Application Insights reçoit des métadonnées, pas le contenu. Azure API Center référence l'URL de la passerelle ;
il ne relaie pas les requêtes, n'authentifie pas les clients et ne donne aucun droit sur les outils.

> [!WARNING]
> Zéro octet de corps aux niveaux de diagnostic hérités, côté client et backend.
> Ni jetons, prompts, arguments, résultats, ni export de transcript Inspector.
> L'inventaire Microsoft 365 optionnel est en **Preview**, réservé au facilitateur.

**Preuve attendue :** trace d'appel limitée aux métadonnées, requêtes de refus utiles et URL gouvernée dans l'inventaire.
**Suite :** module 99 pour arrêter les coûts. Le module 07 est une branche facultative, pas un prérequis.

**Approfondir :** [télémétrie APIM](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights),
[enregistrement API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server),
[inventaire Microsoft 365 BYO, Preview](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server).

## 07 - Clients facultatifs, même frontière

**Objectif :** comparer client délégué et identité applicative sans modifier les protections du serveur.
Le schéma montre une **connexion optionnelle prévue**, pas un agent Foundry créé ni un agent Copilot Studio configuré.

**Schéma :** client optionnel, même passerelle gouvernée, Function privée.
Identifiez qui appelle MCP avant d'interpréter les résultats. Revérifiez Preview, licences, étendues,
adresse de retour et authentification sans secret pour le client retenu.

> [!IMPORTANT]
> Reportez le parcours OAuth manuel documenté de Copilot Studio s'il exige un secret client.
> Une fonction appelée « identity passthrough » n'autorise pas à transmettre le jeton MCP aux API cibles.

**Preuve attendue :** connexion sans secret, explicitement approuvée et officiellement supportée seulement.
Aucun client supplémentaire n'est requis pour finir le parcours principal.
**Suite :** module 99, même si cette démonstration est ignorée.

**Approfondir :** [authentification Foundry, certains flux en Preview](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication),
[MCP dans Copilot Studio](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent).

## 99 - Nettoyer uniquement ce que possède le workshop

**Objectif :** arrêter les coûts et supprimer les affectations créées sans toucher aux ressources partagées.
Les deux lignes du schéma représentent des opérations administratives, pas des appels d'outils.

> [!WARNING]
> Examinez le vrai plan de destruction et obtenez l'approbation explicite.
> Nettoyez d'abord les ressources, puis seulement les objets Entra créés pour le workshop.
> Préservez identifiants fournis, comptes existants et infrastructure partagée.

**Preuve attendue :** aucune ressource taguée appartenant au workshop ; objets d'identité créés et affectations
de rôles comptabilisés ; inventaire, rétention et suppression récupérable vérifiés.
Arrêtez les clients et codespaces inutilisés.
**Suite :** retour à l'accueil, ou nouveau préfixe approuvé après vérification du nettoyage.

**Approfondir :** [sémantique Terraform destroy](https://developer.hashicorp.com/terraform/cli/commands/destroy),
[affectations de rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).

## Sources

Le registre du board contient les liens officiels complets, exemples épinglés, licences et contrôles de compatibilité.
Voir [REFERENCES.md](REFERENCES.md), [DEPLOYMENT.md](DEPLOYMENT.md) et [PRACTICE.md](PRACTICE.md).
Dernière vérification : 2026-10-14. Synthèses pédagogiques originales, pas reproduction des documentations tierces.

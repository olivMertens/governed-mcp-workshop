# Comprendre les protections du serveur

Pour chaque étape, cherchez à comprendre ce qui est autorisé et ce qui doit être refusé.
Utilisez ensuite le guide et le script de vérification du module lorsqu'ils sont publiés.
Les schémas décrivent l'architecture **prévue**, pas un service déjà déployé.

> [!IMPORTANT]
> La connexion établit qui vous êtes. Vos droits déterminent ce que vous pouvez faire.
> La confirmation manuelle accepte ou refuse une action précise. Aucun de ces contrôles ne remplace les autres.

## 00 - Prérequis et environnement

**Objectif :** vérifier les outils, l'environnement Azure et le budget autorisés.
L'administrateur Entra gère les identités ; l'administrateur Azure gère les ressources.
Le droit de déployer des ressources ne donne pas forcément le droit d'attribuer des rôles.

**Schéma :** une ligne prépare les identités Entra ; l'autre prépare l'abonnement de test.
Ce ne sont pas des appels MCP. Un codespace est une machine de développement, pas un tenant.

> [!TIP]
> Commencez par le guide Azure du tableau. Demandez qui approuve les identités.
> Ne demandez pas le rôle Propriétaire (Owner) pour simplifier l'exercice.

**Résultat attendu :** les vérifications du module 00 réussissent et la demande Entra est comprise.
Choisir l'abonnement ne suffit pas.
**Suite :** module 01, une fois que le validateur publié du module 00 réussit. Aucune ressource cloud dans le module 01.

**Approfondir :** [tenant et abonnement](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli),
[attribution des rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).

## 01 - Découvrir MCP sans Azure

**Objectif :** afficher les outils disponibles, puis en exécuter un.
Le Model Context Protocol (MCP) permet au client de découvrir les outils et les informations qu'ils attendent.
Le serveur local communique avec le client par ses entrées et sorties standard (stdio).
Les serveurs distants utilisent le transport Streamable HTTP. Ouvrir une adresse dans le navigateur ne teste pas les outils.

**Schéma :** client local, serveur local, outil synthétique. Ni Entra, ni passerelle, ni ressource cloud payante.
Les annotations d'outil aident le client, mais n'imposent pas les autorisations.

> [!IMPORTANT]
> Gardez l'approbation humaine pour les écritures. Vérifiez la trace d'appel réelle, pas seulement la réponse de l'assistant.

**Résultat attendu :** les outils s'affichent, l'un d'eux s'exécute avec des données fictives et la confirmation manuelle reste disponible.
**Suite :** module 02, uniquement après la validation et l'approbation du déploiement de test payant.

**Approfondir :** [architecture MCP](https://modelcontextprotocol.io/specification/2026-07-28/architecture),
[transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports),
[outils](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[client VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers).

## 02 - Une clé n'est pas une identité utilisateur

**Objectif :** comprendre qu'une clé partagée ne permet pas de savoir qui l'utilise.
L'extension MCP d'Azure Functions utilise la clé système `mcp_extension`.
Le point d'entrée conserve le niveau d'autorisation `System`. « Ouvert » ne signifie pas « sans protection ».

**Schéma :** le client muni de la clé appelle Functions ; une écriture synthétique atteint une file Azure Storage.
Les outils qui dépendent d'une identité restent simulés, et le signalent, jusqu'au module 05.

> [!WARNING]
> Limitez la durée de cette étape. Ne désactivez jamais la protection du webhook. Ne placez pas la clé dans une URL ni dans un en-tête journalisé.
> Toute personne possédant la clé peut utiliser les outils exposés : ce n'est pas une protection suffisante pour l'entreprise.

**Résultat attendu :** HTTP 401 sans clé ; HTTP 200 et réussite de l'outil avec la bonne clé.
**Suite :** module 03 pour remplacer la démonstration de clé partagée par l'authentification des utilisateurs affectés.

**Approfondir :** [exemple Functions épinglé](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9),
[liaisons MCP](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp).

## 03 - Connexion des utilisateurs et rôles applicatifs

**Objectif :** n'accepter que les jetons d'accès destinés au serveur MCP.
La plateforme vérifie l'émetteur du jeton, le tenant, l'audience (le service destinataire) et la date d'expiration.
Les autorisations déléguées (scopes) définissent ce que le client peut demander au nom de l'utilisateur.
Les rôles applicatifs définissent les actions permises à cet utilisateur ou à une application.
Utilisez les contrôles de la plateforme et les bibliothèques officielles, pas un validateur de jetons écrit à la main.

**Schéma :** la connexion remet d'abord un jeton au client. Une ligne distincte montre ensuite le client qui appelle
la Function avec ce jeton. Entra ne relaie pas les appels d'outils.
Les métadonnées de ressource protégée (PRM) sont en **Preview**.

> [!IMPORTANT]
> Alice et Bob sont affectés ; Eve ne l'est pas. Une connexion réussie ne donne pas tous les outils.
> Pour expliquer le contenu d'un jeton, utilisez des exemples fictifs. Ne copiez jamais un jeton réel dans un site de décodage, une conversation ou un fichier.

**Résultat attendu :** HTTP 401 sans jeton ou avec un jeton destiné à un autre service ; Alice et Bob se connectent ;
Eve ne peut pas obtenir ce jeton, qui exige une affectation. Les contrôles par outil sont traités au module 04.
**Suite :** module 04 : API Management devient le point d'entrée imposé.

**Approfondir :** [autorisation MCP et PRM](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp),
[rôles applicatifs](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).

## 04 - Passer obligatoirement par API Management

**Objectif :** tous les appels passent par API Management (APIM), qui vérifie les droits et limite le nombre d'appels.
APIM et Functions protègent le même service MCP. Le jeton doit être destiné à ce service.
N'ajoutez pas d'autre audience acceptée pour faire réussir un test.
L'API de gestion MCP `2025-09-01-preview` est en **Preview**. Ce n'est pas l'offre AI Gateway, elle aussi en Preview.

**Schéma :** client, APIM Standard v2, Function privée. L'intégration réseau sortante et le DNS privé assurent
la connectivité ; l'accès public désactivé empêche tout contournement. Le réseau ne remplace pas la validation du jeton.

> [!WARNING]
> Vérifiez aussi que l'accès direct à la Function est refusé. Une passerelle qui fonctionne ne suffit pas.
> N'attribuez pas Tools.Write à Bob pour faire réussir artificiellement la démonstration.

**Résultat attendu :** création de ticket avec des données fictives, approuvée pour chaque test :
HTTP 403 pour Bob ; HTTP 200 et réussite de l'outil pour Alice.
Un dépassement de la limite de débit renvoie HTTP 429 ; l'accès direct est refusé.
Les journaux ne contiennent aucun corps de requête ou de réponse.
**Suite :** module 05 pour comprendre avec quels droits les données sont lues.

**Approfondir :** [exposer un serveur existant](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server),
[validation de jeton](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy),
[réseau sortant](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound),
[gestion programmatique, Preview](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api).

## 05 - Accès délégué ou applicatif

**Objectif :** comparer deux façons d'accéder aux données.
L'accès délégué On-Behalf-Of (OBO) agit au nom de l'utilisateur, avec ses droits.
L'accès applicatif utilise une identité managée, avec ses propres droits sur la ressource.
Chaque accès obtient son **propre jeton**, destiné à l'API appelée ; le jeton MCP n'est jamais transmis.

**Schéma :** les deux parcours passent par API Management. Le premier utilise un jeton délégué pour Azure Storage ;
le second utilise un jeton de l'identité managée pour le même stockage.
L'outil `whoami` appelle séparément Microsoft Graph avec un jeton destiné à Graph, pas à Storage.

> [!WARNING]
> Ne transmettez jamais le jeton MCP à Graph ou Storage. Une identité applicative ne se fait pas passer pour l'utilisateur.
> Si la délégation échoue, ne vous rabattez pas sur l'identité du développeur.

| Outil | Alice | Bob | Droits utilisés |
|---|---|---|---|
| `read_report_as_user` | Autorisé | Refusé par la ressource cible | Ceux de l'utilisateur |
| `read_report_as_app` | Même rapport synthétique autorisé | Même rapport synthétique autorisé | Ceux de l'identité managée |

**Résultat attendu :** les quatre cas du tableau. Notez le code HTTP et l'éventuelle erreur MCP :
un refus HTTP 403 de Storage peut arriver dans une réponse HTTP 200.
**Suite :** module 06 pour observer les métadonnées sans capturer le contenu.

**Approfondir :** [fonctionnement des jetons OBO](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow),
[fédération sans secret](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).

## 06 - Suivre les appels et répertorier le serveur

**Objectif :** savoir qui a utilisé quel outil et avec quel résultat, sans enregistrer les données échangées.
Conservez uniquement l'identifiant de l'appelant authentifié, le nom de l'outil, le statut, la durée et
l'identifiant de corrélation. Ces informations sont des métadonnées.

**Schéma :** le chemin des requêtes, la télémétrie et l'inscription à l'inventaire sont séparés.
Application Insights reçoit des métadonnées, pas le contenu. Azure API Center référence l'URL de la passerelle ;
il ne relaie pas les requêtes, n'authentifie pas les clients et ne donne aucun droit sur les outils.

> [!WARNING]
> Aucun contenu de requête ou de réponse dans les journaux, y compris dans les configurations héritées.
> Ne conservez ni jetons, ni prompts, ni arguments, ni résultats d'outils et n'exportez pas les traces Inspector.
> L'inventaire Microsoft 365 facultatif est en **Preview**, réservé à l'animateur.

<details>
<summary>Facultatif : Agent 365 et API Management — Preview, démonstration prévue</summary>

Microsoft Agent 365 définit les décisions de gouvernance ; API Management les applique.
Cette intégration est en **Preview**. L'exercice n'est pas encore implémenté.
Avec API Management v2, elle permet l'inventaire et le blocage d'un serveur entier (HTTP 403).
Le blocage par outil, le suivi d'activité par outil et la protection contre les menaces exigent l'offre
**AI Gateway (Preview)**, hors parcours principal. Le contrôle par outil exige une liste statique d'outils autorisés.

Le consentement à l'échelle du tenant attribue à l'identité du service Agent 365 le rôle
**A365 MCP Gateway Policy Operator**, avec lecture et écriture des stratégies d'API dans les abonnements
actuels et futurs du tenant. Aucun script destiné aux participants ne demande cette autorisation.
Une démonstration exige l'accord distinct de l'administrateur.
Agent 365 ne redirige pas automatiquement les clients : l'accès direct au serveur doit rester bloqué.

**Résultat attendu de la démonstration :** le blocage du serveur renvoie HTTP 403.
Avec AI Gateway (Preview), le blocage d'un outil renvoie HTTP 200, mais le résultat MCP contient
`result.isError: true` et le code `ToolNotAvailable`.
Vérifiez le code HTTP et le résultat structuré, pas seulement la réponse de l'agent.
Ce sont les résultats documentés, pas la preuve d'un exercice validé.

[Instructions officielles et limites par offre (Preview)](https://learn.microsoft.com/azure/api-management/agent-365).
Dernière vérification : 2026-10-14.

</details>

**Résultat attendu :** des traces limitées aux métadonnées, des requêtes permettant d'examiner les refus et l'adresse de la passerelle dans l'inventaire.
**Suite :** module 99 pour arrêter les coûts. Le module 07 est un parcours facultatif, pas un prérequis.

**Approfondir :** [télémétrie APIM](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights),
[enregistrement API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server),
[inventaire Microsoft 365 BYO, Preview](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server).

## 07 - D'autres clients, les mêmes protections

**Objectif :** comparer client délégué et identité applicative sans modifier les protections du serveur.
Le schéma montre une **connexion facultative prévue**, pas un agent Foundry créé ni un agent Copilot Studio configuré.

**Schéma :** un client facultatif passe par la même passerelle pour accéder à la Function privée.
Vérifiez l'identité utilisée, les licences et les fonctionnalités en Preview.
La connexion du client choisi doit être prise en charge sans secret.

> [!IMPORTANT]
> Reportez le parcours OAuth manuel documenté de Copilot Studio s'il exige un secret client.
> Une fonctionnalité nommée « identity passthrough » n'autorise pas à transmettre le jeton MCP aux API cibles.

**Résultat attendu :** une connexion sans secret, approuvée et officiellement prise en charge.
Aucun client supplémentaire n'est requis pour terminer le parcours principal.
**Suite :** module 99, même si vous sautez cette démonstration.

**Approfondir :** [authentification Foundry, certains flux en Preview](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication),
[MCP dans Copilot Studio](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent).

## 99 - Supprimer uniquement ce que l'atelier a créé

**Objectif :** arrêter les coûts et supprimer les affectations créées sans toucher aux ressources partagées.
Les deux lignes du schéma représentent des opérations administratives, pas des appels d'outils.

> [!WARNING]
> Examinez le plan de destruction réel et obtenez l'approbation explicite.
> Nettoyez d'abord les ressources, puis seulement les objets Entra créés pour l'atelier.
> Conservez les identifiants fournis, les comptes existants et l'infrastructure partagée.

**Résultat attendu :** aucune ressource portant l'étiquette de l'atelier ne subsiste ; les identités créées et
les rôles attribués sont tous pris en compte. Vérifiez l'inventaire, les durées de conservation et les suppressions récupérables.
Arrêtez les clients et les codespaces inutilisés.
**Suite :** retour à l'accueil, ou nouveau préfixe approuvé après vérification du nettoyage.

**Approfondir :** [fonctionnement de Terraform destroy](https://developer.hashicorp.com/terraform/cli/commands/destroy),
[affectations de rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).

## Sources

La page des références rassemble les liens officiels, les versions retenues, les licences et les limites de compatibilité.
Voir [REFERENCES.md](REFERENCES.md), [DEPLOYMENT.md](DEPLOYMENT.md) et [PRACTICE.md](PRACTICE.md).
Dernière vérification : 2026-10-14. Synthèses pédagogiques originales, et non reproduction des documentations tierces.

# Comprendre les protections du serveur

Pour chaque étape, cherchez à comprendre ce qui est autorisé et ce qui doit être refusé.
Suivez ensuite le guide du module et lancez son script de vérification.
Les schémas décrivent les échanges et les protections ; ils ne prouvent pas que votre environnement est déjà configuré.

> [!IMPORTANT]
> La connexion établit qui vous êtes. Vos droits déterminent ce que vous pouvez faire.
> La confirmation manuelle accepte ou refuse une action précise. Aucun de ces contrôles ne remplace les autres.

## 00 - Prérequis et environnement

**Objectif :** vous allez vérifier vos outils et préparer un environnement Azure dont l'utilisation et le budget sont approuvés.
L'administrateur Entra gère les identités ; l'administrateur Azure gère les ressources.
Le droit de déployer des ressources ne donne pas forcément le droit d'attribuer des rôles.

**Schéma :** une ligne prépare les identités Entra ; l'autre prépare l'abonnement de test.
Ce ne sont pas des appels MCP. Un codespace est une machine de développement, pas un tenant.

> [!TIP]
> Commencez par le guide du module 00. Identifiez la personne qui doit approuver la configuration des identités.
> Ne demandez pas le rôle Propriétaire (Owner) pour simplifier l'exercice.

**Résultat attendu :** les vérifications du module 00 réussissent et la demande Entra est claire.
Choisir l'abonnement ne suffit pas.
**Suite :** module 01, dès que les outils nécessaires fonctionnent.
Vous pouvez le suivre pendant que les vérifications Azure du module 00 sont en attente : il n'utilise aucune ressource cloud.

**Approfondir :** [tenant et abonnement](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli),
[attribution des rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).

## 01 - Découvrir MCP sans Azure

**Objectif :** vous allez découvrir les outils disponibles, puis en appeler un.
Le Model Context Protocol (MCP) permet au client de découvrir les outils et les informations qu'ils attendent.
Le serveur local communique avec le client par ses entrées et sorties standard (stdio).
Les serveurs distants utilisent le transport Streamable HTTP. Ouvrir une adresse dans le navigateur ne teste pas les outils.

**Schéma :** le client et le serveur fonctionnent sur votre poste ; l'outil renvoie des données fictives.
Aucun service Entra, aucune passerelle ni ressource cloud payante n'intervient.
Les annotations d'outil aident le client, mais n'appliquent aucune autorisation.

> [!IMPORTANT]
> Gardez l'approbation humaine pour les écritures. Vérifiez la trace d'appel réelle, pas seulement la réponse de l'assistant.

**Résultat attendu :** les outils s'affichent, l'un d'eux s'exécute avec des données fictives et la confirmation manuelle reste active.
**Suite :** module 02, uniquement après la validation et l'approbation du déploiement de test payant.

**Approfondir :** [architecture MCP](https://modelcontextprotocol.io/specification/2026-07-28/architecture),
[transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports),
[outils](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[client VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers).

## 02 - Une clé n'est pas une identité utilisateur

**Objectif :** vous allez constater qu'une clé partagée ne permet pas de savoir qui l'utilise.
L'extension MCP d'Azure Functions utilise la clé système `mcp_extension`.
Le point d'entrée conserve le niveau d'autorisation `System`. « Ouvert » ne signifie pas « sans protection ».

**Schéma :** le client appelle Functions avec la clé ; l'outil d'écriture ajoute un ticket fictif à une file Azure Storage.
Les outils qui dépendent d'une identité restent simulés jusqu'au module 05, et l'indiquent.

> [!WARNING]
> Ne laissez pas le serveur protégé par une simple clé en service après l'exercice.
> Ne désactivez jamais l'exigence de clé. Ne la placez pas dans une URL ni dans un en-tête journalisé.
> Quiconque possède la clé peut utiliser les outils exposés : en entreprise, cette protection ne suffit pas.

**Résultat attendu :** HTTP 401 sans clé ; HTTP 200 et réussite de l'outil avec la bonne clé.
**Suite :** module 03, qui remplace la clé partagée par l'authentification des utilisateurs autorisés dans l'application.

**Approfondir :** [exemple Functions épinglé](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9),
[liaisons MCP](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp).

## 03 - Connexion des utilisateurs et rôles applicatifs

**Objectif :** vous allez exiger une connexion utilisateur avec un jeton d'accès destiné au serveur MCP.
La plateforme vérifie l'émetteur du jeton, le tenant, l'audience (le service destinataire) et la date d'expiration.
Les autorisations déléguées (scopes) définissent ce que le client peut demander au nom de l'utilisateur.
Les rôles applicatifs définissent les actions permises à cet utilisateur ou à une application.
Utilisez les contrôles de la plateforme et les bibliothèques officielles, pas un validateur de jetons écrit à la main.

**Schéma :** la connexion remet d'abord un jeton au client. Une ligne distincte montre ensuite le client qui appelle
la Function avec ce jeton. Entra ne relaie pas les appels d'outils.
Les métadonnées de ressource protégée (PRM) sont en **Preview**.

> [!IMPORTANT]
> Alice a `Tools.Read` et `Tools.Write`, Bob a seulement `Tools.Read`, Eve n'a aucune attribution.
> Tous trois peuvent se connecter au tenant, mais Eve ne peut pas obtenir de jeton pour l'application MCP.
> Dans ce module, Bob peut encore utiliser tous les outils, y compris `create_ticket` :
> son rôle de lecture n'est pas encore contrôlé par outil. Ce contrôle arrive au module 04.
> Pour expliquer le contenu d'un jeton, utilisez des exemples fictifs. Ne collez jamais un jeton réel dans un site de décodage, une conversation ou un fichier.

**Résultat attendu :** HTTP 401 sans jeton ou avec un jeton destiné à un autre service ; Alice et Bob se connectent ;
Eve ne peut pas obtenir ce jeton (`AADSTS50105`), car l'application exige une attribution.
Activez d'abord Entra en conservant la clé ; vérifiez sa configuration et le refus sans jeton,
puis retirez l'exigence de clé. Le module 04 traite les contrôles par outil.
**Suite :** module 04 : API Management devient le point d'entrée imposé.

**Approfondir :** [autorisation MCP et PRM](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp),
[rôles applicatifs](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).

## 04 - Passer obligatoirement par API Management

**Objectif :** vous allez faire passer tous les appels par API Management (APIM), qui vérifiera les droits et limitera le débit.
APIM et Functions protègent le même service MCP. Le jeton doit être destiné à ce service.
N'ajoutez pas d'autre audience acceptée pour faire réussir un test.
L'API de gestion MCP `2025-09-01-preview` est en **Preview**. Ce n'est pas l'offre AI Gateway, elle aussi en Preview.

**Schéma :** le client appelle APIM Standard v2, qui rejoint la Function par le réseau privé.
L'intégration réseau sortante et le DNS privé permettent cette connexion.
La désactivation de l'accès public empêche d'appeler directement la Function.
Ces protections réseau ne remplacent pas la vérification du jeton.

> [!WARNING]
> Vérifiez aussi que l'accès direct à la Function est refusé. Une passerelle qui fonctionne ne suffit pas.
> N'attribuez pas Tools.Write à Bob pour faire réussir artificiellement la démonstration.

**Résultat attendu :** création de ticket avec des données fictives, approuvée pour chaque test :
HTTP 403 pour Bob ; HTTP 200 et réussite de l'outil pour Alice.
Un dépassement de la limite de débit renvoie HTTP 429 ; l'accès direct est refusé.
Les journaux ne contiennent aucun corps de requête ou de réponse.
**Suite :** module 05, pour savoir avec quels droits le serveur lit les données.

**Approfondir :** [exposer un serveur existant](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server),
[validation de jeton](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy),
[réseau sortant](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound),
[gestion programmatique, Preview](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api).

## 05 - Accès délégué ou applicatif

**Objectif :** vous allez comparer deux façons d'accéder aux mêmes données.
L'accès délégué On-Behalf-Of (OBO) agit au nom de l'utilisateur, avec ses droits.
L'accès applicatif utilise une identité managée, avec ses propres droits sur la ressource.
Chaque accès obtient son **propre jeton**, destiné à l'API appelée ; le serveur ne transmet jamais le jeton MCP.

**Schéma :** les deux parcours passent par API Management. Le premier utilise un jeton délégué pour Azure Storage ;
le second, un jeton de l'identité managée pour le même stockage.
L'outil `whoami` appelle séparément Microsoft Graph avec un jeton destiné à Graph, pas à Storage.

> [!WARNING]
> Ne transmettez jamais le jeton MCP à Graph ou Storage. Une identité applicative ne se fait pas passer pour l'utilisateur.
> Si la délégation échoue, ne vous rabattez pas sur l'identité du développeur.

| Outil | Alice | Bob | Droits utilisés |
|---|---|---|---|
| `read_report_as_user` | Autorisé | Refusé par la ressource cible | Ceux de l'utilisateur |
| `read_report_as_app` | Même rapport fictif accessible | Même rapport fictif accessible | Ceux de l'identité managée |

**Résultat attendu :** les quatre cas du tableau. Notez le code HTTP et l'éventuelle erreur MCP :
un refus HTTP 403 de Storage peut être signalé par une erreur d'outil dans une réponse HTTP 200 du serveur MCP.
**Suite :** module 06 pour observer les métadonnées sans capturer le contenu.

**Approfondir :** [fonctionnement des jetons OBO](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow),
[fédération sans secret](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).

## 06 - Suivre les appels et répertorier le serveur

**Objectif :** vous allez suivre les appels d'outils sans enregistrer les données échangées.
Conservez uniquement l'identifiant de l'appelant authentifié, le nom de l'outil, le statut, la durée et
l'identifiant de corrélation. Ces informations sont des métadonnées.

**Schéma :** le chemin des requêtes, la télémétrie et l'inscription à l'inventaire sont séparés.
Application Insights reçoit des métadonnées, pas le contenu. Azure API Center référence l'URL de la passerelle ;
il ne relaie pas les requêtes, n'authentifie pas les clients et ne donne aucun droit sur les outils.

> [!WARNING]
> Aucun contenu de requête ou de réponse dans les journaux, y compris dans les configurations héritées.
> Ne conservez ni jetons, ni prompts, ni arguments, ni résultats d'outils et n'exportez pas les traces Inspector.
> L'inventaire Microsoft 365, facultatif, est en **Preview**. Sa configuration est réservée à l'administrateur du tenant.

<!-- author-only -->
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
<!-- /author-only -->

**Résultat attendu :** des traces limitées aux métadonnées, des requêtes pour examiner les refus et l'adresse de la passerelle dans l'inventaire.
**Suite :** module 99 pour arrêter les coûts. Le module 07 est un parcours facultatif, pas un prérequis.

**Approfondir :** [télémétrie APIM](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights),
[enregistrement API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server),
[inventaire Microsoft 365 BYO, Preview](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server).

## 07 - D'autres clients, les mêmes protections

**Objectif :** vous allez appeler le serveur depuis un autre client sans modifier ses contrôles d'accès.
Vous pouvez réaliser la partie A avec Microsoft Foundry dans votre propre environnement de test.
La partie B est un aperçu de Copilot Studio, non validé en conditions réelles.

**Schéma :** un client facultatif passe par la même passerelle pour accéder à la Function privée.
Vérifiez l'identité utilisée, les licences et les fonctionnalités en Preview.
Le [guide du module 07](../../modules/07-clients/README.fr.md) décrit les prérequis, les limites de connexion et le nettoyage.

> [!IMPORTANT]
> Chaque utilisateur doit se connecter avec sa propre identité. N'affaiblissez pas les contrôles pour ajouter un client.
> Une fonctionnalité nommée « identity passthrough » n'autorise pas à transmettre le jeton MCP aux API cibles.

**Résultat attendu :** Foundry permet à Alice de lire ; l'écriture approuvée par Bob reste refusée par la passerelle (HTTP 403).
Aucun client supplémentaire n'est requis pour terminer le parcours principal.
**Suite :** module 99, que vous ayez réalisé ou non cet exercice facultatif.

**Approfondir :** [authentification Foundry, certains flux en Preview](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication),
[MCP dans Copilot Studio](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent).

## 99 - Supprimer uniquement ce que l'atelier a créé

**Objectif :** vous allez arrêter les coûts et retirer les attributions de rôle créées pour l'atelier,
sans toucher aux ressources partagées.
Les deux lignes du schéma représentent des opérations administratives, pas des appels d'outils.

> [!WARNING]
> Examinez le plan de destruction réel et obtenez l'approbation explicite.
> Suivez l'ordre indiqué dans le guide de votre parcours. Si vous avez déployé Foundry au module 07,
> commencez par son nettoyage : son groupe de ressources et ses identités sont distincts de ceux du serveur MCP.
> Conservez les identifiants fournis, les comptes existants et l'infrastructure partagée.

**Résultat attendu :** les ressources, identités et attributions de rôles créées pour l'atelier ont été retirées,
sauf les éléments explicitement conservés après accord. Vérifiez aussi les ressources qu'API Management et Foundry
conservent temporairement après suppression : elles doivent être purgées selon le guide.
Arrêtez les clients et les codespaces inutilisés.
**Suite :** retour à l'accueil, ou nouveau préfixe approuvé après vérification du nettoyage.

**Approfondir :** [fonctionnement de Terraform destroy](https://developer.hashicorp.com/terraform/cli/commands/destroy),
[affectations de rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).

## Sources

La page des références rassemble les liens officiels, les versions retenues, les licences et les limites de compatibilité.
Voir [REFERENCES.md](REFERENCES.md), [DEPLOYMENT.md](DEPLOYMENT.md) et [PRACTICE.md](PRACTICE.md).
Dernière vérification : 2026-10-14. Synthèses pédagogiques originales : aucune documentation tierce n'est reproduite.

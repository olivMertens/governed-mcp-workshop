# Le parcours de l'atelier

Ce parcours présente ce que vous apprendrez à chaque étape. Suivez les modules dans l'ordre.

> [!IMPORTANT]
> Les modules s'enchaînent : chacun réutilise les fichiers privés, l'état Terraform et les ressources des précédents.
> Ne passez au module suivant qu'après la réussite du script de validation du module en cours.
> Sauter une étape provoque des erreurs difficiles à diagnostiquer plus loin. La ligne **Dépend de** indique les prérequis de chaque module.

Les modules 00 et 01 ont des guides exécutables ; les contrôles Azure du module 00 sont encore en attente.
Le module 01 est local et indépendant d'Azure. Les modules 02 à 07 et 99 restent prévus.
N'utilisez pas ces résumés comme procédure de déploiement : suivez le guide du module lorsqu'il est publié.
Le [plan technique en anglais](../BUILD-PLAN.md) s'adresse aux personnes qui construisent l'atelier.

## 00 - Prérequis et environnement
**Dépend de :** aucun module. Commencez ici.


**Objectif :** vérifier vos outils et préparer un environnement de test autorisé.
**À vérifier :** les contrôles réussissent et l'administrateur comprend la demande de configuration Entra.

<details>
<summary>Pour aller plus loin : ce qui est disponible et ce qui reste à valider</summary>

Le guide bilingue, les scripts de vérification en lecture seule et la demande Entra sont disponibles.
Les versions des outils sont fixées et chaque participant conserve ses paramètres privés.
Terraform prépare le groupe et un portail App Service B1 facultatif, payant et désactivé par défaut.
Les tests locaux ne remplacent ni un déploiement dans Azure ni un démarrage du conteneur.
Aucun serveur MCP ni code Terraform Entra n'est encore implémenté.

</details>

## 01 - Découvrir MCP sans Azure
**Dépend de :** outils du module 00. Sans Azure : possible même si les vérifications Azure du 00 sont en attente.


**Objectif :** afficher les outils d'un serveur local, puis en exécuter un avec des données fictives.
**À vérifier :** une exécution réelle et une confirmation manuelle disponible dans le client.
Aucun coût Azure ni modèle d'IA n'est nécessaire pour les tests de protocole avec Inspector.
Le serveur C# utilise ses entrées et sorties standard (stdio), pas une adresse HTTPS.
Le [guide exécutable](../../modules/01-discover-mcp/README.fr.md) fournit les commandes PowerShell et les résultats.
Un outil de lecture, `get_service_health`, est disponible. Le script et Inspector 2.9.0 ont réussi en local.
L'observation de l'approbation dans VS Code reste manuelle. Aucun portail présentateur n'est nécessaire.

## 02 - Serveur par clé, niveau 0
**Dépend de :** module 00 validé pour votre abonnement et module 01 terminé.


**Objectif :** comprendre qu'une clé partagée protège l'accès sans identifier chaque utilisateur.
**À vérifier :** HTTP 401 sans clé ; HTTP 200 et réussite de l'outil avec la bonne clé.
Cette étape payante reste courte et ne représente pas la protection finale.
Le [guide du module 02](../../modules/02-open-server/README.fr.md) est rédigé et vérifié hors ligne ; rien n'est encore déployé.

<details>
<summary>Pour aller plus loin : services et protection de la clé</summary>

Terraform préparera Azure Functions Flex Consumption, le stockage, la télémétrie et une identité managée.
Les outils utiliseront des données fictives ; `create_ticket` ajoutera un message à une file de stockage.
Les accès liés à l'identité resteront simulés jusqu'au module 05.
Le point d'entrée gardera le niveau d'autorisation `System`, jamais un accès anonyme.

</details>

## 03 - Identité Microsoft Entra, niveau 1
**Dépend de :** module 02 déployé (mêmes fichiers privés, même état Terraform) et demande Entra approuvée par l'administrateur des identités.


**Objectif :** autoriser les utilisateurs prévus, plutôt que toute personne possédant une clé.
**À vérifier :** Alice et Bob peuvent se connecter, pas Eve. Un jeton absent ou destiné à un autre service est refusé.

<details>
<summary>Pour aller plus loin : application, autorisations et rôles</summary>

L'application MCP aura sa propre audience, l'autorisation déléguée `user_impersonation` et les rôles
Tools.Read, Tools.Write et Tools.Execute.All. Les utilisateurs devront être affectés à l'application.
L'authentification intégrée et les clients préautorisés prépareront la connexion sans secret client.
Les métadonnées de ressource protégée (PRM) sont en **Preview**.
Les tests sans jeton ou avec une mauvaise audience doivent renvoyer HTTP 401.

</details>

Le [guide du module 03](../../modules/03-entra-authentication/README.fr.md) est rédigé et vérifié hors ligne ; rien n'est
encore déployé dans Azure ni créé dans Microsoft Entra.

## 04 - API Management comme entrée unique, niveau 2
**Dépend de :** modules 02 et 03 (les deux étapes) déployés avec les mêmes fichiers privés et le même état Terraform.


**Objectif :** imposer le passage par la passerelle API Management.
**À vérifier :** Bob ne peut pas créer de ticket, Alice le peut après approbation.
Un nombre excessif d'appels est limité et l'accès direct à la Function est refusé.

<details>
<summary>Pour aller plus loin : réseau privé et contrôles de la passerelle</summary>

API Management (APIM) Standard v2 utilisera l'API de gestion MCP `2025-09-01-preview`, en **Preview**.
La passerelle vérifiera les jetons Entra et le rôle requis par outil. Elle limitera le débit et filtrera les adresses IP.
L'intégration au réseau sortant, un point de terminaison privé et la résolution privée des noms (DNS)
permettront de joindre la Function sans accès public.
APIM et Functions protégeront le même service MCP. Les journaux ne contiendront aucun corps de requête ou de réponse.
Les résultats attendus sont HTTP 403 pour Bob, HTTP 200 et réussite pour Alice, HTTP 429 au-delà du débit autorisé.
L'option 04b REST vers MCP ne remplace pas le serveur principal.

</details>

Le [guide du module 04](../../modules/04-governed-gateway/README.fr.md) est rédigé et vérifié hors ligne : passerelle Standard v2,
API de serveur MCP (**Preview**), stratégies, réseau privé et verrouillage de la Function en deuxième étape.
Rien n'est encore déployé dans Azure.

## 05 - On-Behalf-Of et accès applicatif, niveau 3
**Dépend de :** modules 02 et 03 déployés (04 recommandé). Publiez le code serveur **avant** l'étape 2 du module 04.


**Objectif :** comparer les droits de l'utilisateur et ceux de l'application.
**À vérifier :** la lecture au nom de l'utilisateur réussit pour Alice et échoue pour Bob ;
la lecture avec les droits de l'application donne le même résultat aux deux.

<details>
<summary>Pour aller plus loin : délégation et identité managée</summary>

`whoami` appellera Microsoft Graph et `read_report_as_user` appellera Azure Storage avec On-Behalf-Of (OBO).
`read_report_as_app` utilisera une identité managée. Aucun jeton MCP ne sera transmis aux API cibles.
Les identités managées et la fédération remplacent les secrets clients.
Examinez le code HTTP et l'erreur MCP : un refus du stockage peut être contenu dans une réponse HTTP 200.

</details>

Le [guide du module 05](../../modules/05-delegated-and-app-only/README.fr.md) est rédigé et vérifié hors ligne : On-Behalf-Of avec une
assertion d'identité managée (sans secret), deux identités distinctes, rôles limités au conteneur du rapport, Bob reçoit HTTP 200
avec `isError: true`. Rien n'est encore déployé dans Azure ni créé dans Microsoft Entra.

## 06 - Observation et inventaire, niveau 4
**Dépend de :** modules 00 à 05 terminés, avec le point de terminaison MCP d'APIM qui répond.


**Objectif :** savoir qui a utilisé quel outil et avec quel résultat, sans enregistrer les données échangées.
**À vérifier :** les journaux ne contiennent ni jetons, ni consignes, ni paramètres ou résultats d'outils.
Azure API Center répertorie l'adresse de la passerelle ; il ne relaie pas les appels et ne donne aucun droit.

<details>
<summary>Pour aller plus loin : analyser les métadonnées</summary>

Des requêtes Kusto Query Language (KQL) ou un classeur d'analyse montreront le nom de l'outil,
l'identifiant de l'appelant authentifié, le statut, la durée et l'identifiant de corrélation.
L'inventaire Microsoft 365 est facultatif, en **Preview**, et réservé à l'animateur.
L'intégration [Agent 365 et API Management (Preview)](https://learn.microsoft.com/azure/api-management/agent-365)
reste une démonstration prévue, non implémentée. API Management v2 permet l'inventaire et le blocage du serveur ;
le contrôle par outil exige AI Gateway (Preview) et une liste statique d'outils autorisés.
Le consentement administrateur à l'échelle du tenant n'est jamais une étape participant.
Les limites et les résultats attendus figurent dans la [fiche de gouvernance](LEARNING-GUIDE.md).

</details>

## 07 - Clients supplémentaires, facultatif
**Dépend de :** modules 03 à 06 validés (ou leur enregistrement). Facultatif.


**Objectif :** utiliser le même serveur depuis un client Foundry ou Copilot Studio officiellement pris en charge,
sans secret. Vérifiez les licences, l'identité utilisée et les fonctions en **Preview**.
L'authentification OAuth manuelle Copilot Studio exigeant un secret reste reportée.
Cette démonstration de l'animateur ne doit pas retarder le nettoyage.

## 99 - Nettoyage
**Dépend de :** à lancer en dernier, avec les mêmes fichiers privés et le même état Terraform que les modules déployés. Ordre inverse.


**Objectif :** supprimer les ressources créées pour l'atelier, puis les identités et rôles créés pour les tests.
Examinez le plan de suppression et faites-le approuver. Préservez les ressources partagées et les comptes existants.
**À vérifier :** aucune ressource de l'atelier ne reste facturée ; les rôles, identités et durées de conservation sont vérifiés.
Arrêtez aussi Inspector et les codespaces inutilisés.

## Sources

[Plan technique anglais](../BUILD-PLAN.md), [gouvernance](LEARNING-GUIDE.md), [registre](REFERENCES.md).
Dernière vérification : 2026-10-14.

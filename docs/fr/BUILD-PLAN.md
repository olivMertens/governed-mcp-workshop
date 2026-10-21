# Le parcours de l'atelier

Ce parcours présente ce que vous apprendrez à chaque étape. Suivez les modules dans l'ordre.

> [!IMPORTANT]
> Les modules s'enchaînent : restez dans le même parcours et réutilisez vos fichiers privés et les ressources déjà créées.
> Dans le parcours Terraform, conservez aussi le même état Terraform.
> Ne passez au module suivant qu'après la réussite du script de validation du module en cours.
> Sauter une étape provoque des erreurs difficiles à diagnostiquer plus loin. La ligne **Dépend de** indique les prérequis de chaque module.

Les neuf modules ont un guide pas à pas. Le module 01 s'exécute en local, sans Azure.
Les autres exercices utilisent votre propre environnement de test ; les résultats de l'auteur ne valident pas votre déploiement.
N'utilisez pas ces résumés comme procédure de déploiement : suivez le guide de chaque module.
Le [plan technique en anglais](../BUILD-PLAN.md) s'adresse aux personnes qui construisent l'atelier.

## 00 - Prérequis et environnement
**Dépend de :** aucun module. Commencez ici.


**Objectif :** vous allez vérifier vos outils et préparer un environnement de test approuvé.
**À vérifier :** les contrôles réussissent et votre demande de configuration Entra est prête à être transmise à l'administrateur.

<details>
<summary>Pour aller plus loin : ce qui est disponible et ce qui reste à valider</summary>

Le guide bilingue, les scripts de vérification en lecture seule et la demande Entra sont disponibles.
Les versions des outils sont fixées et chaque participant conserve ses paramètres privés.
Dans le parcours Terraform, les scripts préparent le groupe. Les guides sont publiés uniquement sur GitHub Pages ;
l'ancien site documentaire Azure et son plan dédié ont été retirés le 2026-10-21.
Les tests locaux ne remplacent ni un déploiement dans Azure ni un démarrage du conteneur.
Le serveur MCP et la configuration Entra sont introduits dans les modules suivants.

</details>

## 01 - Découvrir MCP sans Azure
**Dépend de :** outils du module 00. Ce module n'utilise pas Azure : vous pouvez le suivre même si les vérifications Azure du module 00 sont en attente.


**Objectif :** vous allez découvrir les outils d'un serveur local, puis en appeler un avec des données fictives.
**À vérifier :** l'outil s'exécute réellement et le client propose une confirmation manuelle.
Les tests de protocole avec Inspector ne coûtent rien sur Azure et ne demandent aucun modèle d'IA.
Le serveur C# communique par ses entrées et sorties standard (stdio), sans adresse HTTPS.
Le [guide pas à pas](../../modules/01-discover-mcp/README.fr.md) fournit les commandes PowerShell et les résultats.
Un outil de lecture, `get_service_health`, est disponible. Le script et Inspector 2.9.0 ont fonctionné en local.
Dans VS Code, vérifiez vous-même l'approbation de chaque appel. Aucun portail de l'atelier n'est nécessaire.

## 02 - Un serveur protégé par une clé, niveau 0
**Dépend de :** module 00 validé pour votre abonnement et module 01 terminé.


**Objectif :** vous allez tester les limites d'une clé partagée : elle protège l'accès, mais n'identifie pas chaque utilisateur.
**À vérifier :** HTTP 401 sans clé ; HTTP 200 et réussite de l'outil avec la bonne clé.
Les ressources de cet exercice sont payantes. Ne les laissez pas en service si vous interrompez l'atelier.
La clé seule ne constitue pas la protection finale.
Suivez le [guide du module 02](../../modules/02-open-server/README.fr.md) pour déployer le serveur et vérifier son comportement.

<details>
<summary>Pour aller plus loin : services et protection de la clé</summary>

Vous déployez Azure Functions Flex Consumption, le stockage, les services de supervision et une identité managée.
Le guide de votre parcours précise comment créer ces ressources.
Les outils utilisent des données fictives ; `create_ticket` ajoute un message à une file de stockage.
Les accès liés à l'identité restent simulés jusqu'au module 05.
Le point d'entrée conserve le niveau d'autorisation `System`, jamais un accès anonyme.

</details>

## 03 - Identité Microsoft Entra, niveau 1
**Dépend de :** module 02 déployé dans le même parcours, avec les mêmes fichiers privés et, si vous utilisez Terraform, le même état.
La demande Entra doit être approuvée par l'administrateur des identités.


**Objectif :** vous allez réserver l'accès aux utilisateurs qui ont une attribution dans l'application,
plutôt qu'à toute personne qui possède une clé.
**À vérifier :** Alice et Bob obtiennent un jeton MCP et voient les cinq outils.
Eve peut se connecter au tenant, mais n'obtient pas de jeton pour cette application (`AADSTS50105`).
Bob peut encore écrire ici : la vérification du rôle requis pour chaque outil arrive au module 04.
Un jeton absent ou destiné à un autre service est refusé.

**Ordre :** préparer l'application Entra avec l'administrateur → activer Entra en gardant la clé →
lire la configuration déployée et vérifier HTTP 401 → retirer l'exigence de clé → tester les trois comptes.
Dans le parcours Terraform, Terraform applique les changements et Azure CLI permet d'en lire les effets.
Dans le parcours portail, suivez les étapes du guide low-code.

<details>
<summary>Pour aller plus loin : application, autorisations et rôles</summary>

L'application MCP a sa propre audience, l'autorisation déléguée `user_impersonation` et les rôles
Tools.Read, Tools.Write et Tools.Execute.All. Un rôle doit être attribué aux utilisateurs dans cette application.
L'authentification intégrée et les clients préautorisés permettent la connexion sans secret client.
Les métadonnées de ressource protégée (PRM) sont en **Preview**.
Les tests sans jeton ou avec une mauvaise audience doivent renvoyer HTTP 401.

</details>

Suivez le [guide du module 03](../../modules/03-entra-authentication/README.fr.md) avec l'administrateur des identités pour configurer Microsoft Entra, puis vérifier les accès.

## 04 - API Management comme entrée unique, niveau 2
**Dépend de :** modules 02 et 03 (les deux étapes) déployés dans le même parcours, avec les mêmes fichiers privés
et, si vous utilisez Terraform, le même état.


**Objectif :** vous allez imposer le passage par API Management pour vérifier les droits à chaque appel d'outil.
**À vérifier :** Bob ne peut pas créer de ticket, Alice le peut après approbation.
Les appels trop nombreux sont limités et l'accès direct à la Function est refusé.

<details>
<summary>Pour aller plus loin : réseau privé et contrôles de la passerelle</summary>

API Management (APIM) Standard v2 utilise l'API de gestion MCP `2025-09-01-preview`, en **Preview**.
La passerelle vérifie les jetons Entra et le rôle requis par outil. Elle limite le débit et peut filtrer les adresses IP.
L'intégration sortante au réseau virtuel, un point de terminaison privé et la résolution privée des noms (DNS)
permettent de joindre la Function sans accès public.
APIM et Functions protègent le même service MCP. Les journaux ne contiennent aucun corps de requête ou de réponse.
Les résultats attendus sont HTTP 403 pour Bob, HTTP 200 et réussite pour Alice, HTTP 429 au-delà du débit autorisé.
L'option 04b REST vers MCP ne remplace pas le serveur principal.

</details>

Le [guide du module 04](../../modules/04-governed-gateway/README.fr.md) explique comment configurer la passerelle Standard v2,
l'API de serveur MCP (**Preview**), les stratégies et le réseau privé, puis désactiver l'accès public à la Function en deuxième étape.
Vérifiez les accès après avoir déployé les deux étapes.

## 05 - On-Behalf-Of et accès applicatif, niveau 3
**Dépend de :** modules 02 et 03 déployés (04 recommandé). Publiez le code serveur **avant** l'étape 2 du module 04.


**Objectif :** vous allez comparer un accès aux données au nom de l'utilisateur et un accès avec les droits de l'application.
**À vérifier :** la lecture au nom de l'utilisateur réussit pour Alice et échoue pour Bob ;
la lecture avec les droits de l'application donne le même résultat pour les deux.

<details>
<summary>Pour aller plus loin : délégation et identité managée</summary>

`whoami` appelle Microsoft Graph et `read_report_as_user` appelle Azure Storage avec On-Behalf-Of (OBO).
`read_report_as_app` utilise une identité managée. Aucun jeton MCP n'est transmis aux API cibles.
Les identités managées et la fédération remplacent les secrets clients.
Examinez le code HTTP et l'erreur MCP : une réponse HTTP 200 peut contenir un refus du stockage.

</details>

Le [guide du module 05](../../modules/05-delegated-and-app-only/README.fr.md) présente On-Behalf-Of avec une
assertion d'identité managée (sans secret), deux identités distinctes et des rôles limités au conteneur du rapport.
Bob reçoit HTTP 200 avec `isError: true`. Répétez les contrôles avec Alice et Bob dans votre environnement.

## 06 - Observation et inventaire, niveau 4
**Dépend de :** modules 00 à 05 terminés, avec le point de terminaison MCP d'APIM qui répond.


**Objectif :** vous allez retrouver qui a utilisé quel outil et avec quel résultat, sans enregistrer les données échangées.
**À vérifier :** les journaux ne contiennent ni jetons, ni prompts, ni paramètres ou résultats d'outils.
Azure API Center répertorie l'adresse de la passerelle ; il ne relaie pas les appels et ne donne aucun droit.

<details>
<summary>Pour aller plus loin : analyser les métadonnées</summary>

Des requêtes Kusto Query Language (KQL) ou un classeur d'analyse montreront le nom de l'outil,
l'identifiant de l'appelant authentifié, le statut, la durée et l'identifiant de corrélation.
L'inventaire Microsoft 365 est facultatif, en **Preview**, et sa configuration est réservée à l'administrateur du tenant.
L'intégration [Agent 365 et API Management (Preview)](https://learn.microsoft.com/azure/api-management/agent-365)
reste une démonstration prévue, non implémentée. API Management v2 permet l'inventaire et le blocage du serveur ;
le contrôle par outil exige AI Gateway (Preview) et une liste statique d'outils autorisés.
Le consentement administrateur pour tout le tenant n'est jamais une étape confiée aux participants.
Les limites et les résultats attendus figurent dans la [fiche de gouvernance](LEARNING-GUIDE.md).

</details>

## 07 - Clients supplémentaires, facultatif
**Dépend de :** modules 03 à 06 déployés et validés dans votre environnement de test approuvé. Facultatif.
Vous pouvez aussi lire les exemples sans déployer, mais un enregistrement vidéo ne remplace pas les ressources nécessaires à l'exercice.


**Objectif :** vous allez appeler le même serveur depuis un agent Microsoft Foundry, dans votre propre environnement.
La partie A est un exercice pratique facultatif avec relais d'identité OAuth (**Preview**).
La partie B présente Copilot Studio à titre indicatif ; elle n'a pas été validée en conditions réelles.
Suivez le [guide du module 07](../../modules/07-clients/README.fr.md) pour les prérequis, les approbations, le coût et le nettoyage.
Ce module n'est pas nécessaire pour terminer le parcours principal. Si vous le sautez, passez directement au module 99.

## 99 - Nettoyage
**Dépend de :** à lancer en dernier, dans le parcours utilisé pour déployer les ressources.
Conservez vos fichiers privés et, si vous utilisez Terraform, le même état. Supprimez dans l'ordre inverse du déploiement.


**Objectif :** vous allez supprimer les ressources créées pour l'atelier, puis les identités et attributions de rôle propres aux tests.
Examinez le plan de suppression et faites-le approuver. Préservez les ressources partagées et les comptes existants.
**À vérifier :** aucune ressource de l'atelier ne reste facturée ; les rôles, identités et durées de conservation sont vérifiés.
Arrêtez aussi Inspector et les codespaces inutilisés.

## Sources

[Plan technique anglais](../BUILD-PLAN.md), [gouvernance](LEARNING-GUIDE.md), [registre](REFERENCES.md).
Dernière vérification : 2026-10-14.

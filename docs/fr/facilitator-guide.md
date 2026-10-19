# Guide de l'animateur

[English](../facilitator-guide.md)

Ce guide vous aide à préparer l'atelier principal, qui dure 4 heures. Les modules 00, 02 et 03 sont validés en conditions réelles.
Les modules 04 à 06 ont réussi leurs vérifications opérateur dans un tenant de test, mais restent au statut « rédigé »
tant que les vérifications d'Alice, Bob et Eve ne sont pas réussies. Les modules 01, 07 et 99 sont rédigés (contrôles hors ligne réussis).
Les horaires décrivent le parcours prévu ; ils ne prouvent pas que les modules sont validés.

## Avant l'arrivée des participants - 30 minutes

- Vérifiez la révision publiée, les statuts et la [provenance des schémas](../../assets/architecture/README.fr.md).
- Utilisez uniquement les personnages fictifs Alice, Bob et Eve. N'affichez aucun jeton réel, aucun tenant ni aucun abonnement.
- Vérifiez que vous disposez d'un abonnement hors production, d'un administrateur des identités, d'un responsable des rôles et d'un budget.
- Si le tenant de test exige la MFA, faites-la enregistrer pour Alice, Bob et Eve avant la session : une première connexion
  par compte suffit. N'affaiblissez jamais l'accès conditionnel pour l'éviter.
- Renouvelez la revue de capacité du portail (moins de 24 heures) avant tout déploiement ou redéploiement.
  Voir [vérifier capacité et coût en privé](HOSTING.md#vérifier-capacité-et-coût-en-privé).
- Prévoyez l'API Management du module 04 sur une seule journée : il est facturé à l'heure tant qu'il existe. Déployez-le et supprimez-le le même jour.
- Ouvrez à l'avance les captures réelles annotées (liste ci-dessous). Une capture ou un enregistrement montre le résultat attendu, mais ne vaut pas validation.
- Réservez Agent 365 et AI Gateway à l'animateur ; les deux sont en **Preview**.

## Captures réelles en solution de repli

Chaque module présente, à l'étape concernée, des captures réelles prises dans le tenant de test de l'auteur.
Les noms sont des pseudonymes, les identifiants sont remplacés par des zéros, et des cadres roses signalent ce qu'il faut vérifier.

| Module | Emplacement dans le guide | Ce que montre la capture |
|---|---|---|
| 02 | [Étapes](../../modules/02-open-server/README.fr.md#étapes) | Réseau du compte de stockage : accès public désactivé, points de terminaison privés approuvés |
| 03 | [Étapes](../../modules/03-entra-authentication/README.fr.md#étapes) | Terminal : sortie du validateur opérateur ; vérifications d'Alice, Bob et Eve |
| 03 | [Retrouver le même résultat dans le portail Azure](../../modules/03-entra-authentication/README.fr.md#retrouver-le-même-résultat-dans-le-portail-azure) | Authentification de la Function, inscription d'application, rôles d'application, affectation obligatoire |
| 05 | [Étape de l'administrateur des identités](../../modules/05-delegated-and-app-only/README.fr.md#administrateur-des-identités--approuver-la-confiance-et-le-consentement) | Autorisations d'API ; information d'identification fédérée, sans secret client |
| 06 | [Étape 3](../../modules/06-observe-inventory/README.fr.md#étape-3---interroger-le-trafic-mcp-dans-application-insights) | Logs d'Application Insights en mode KQL, métadonnées uniquement |
| 06 | [Étape facultative](../../modules/06-observe-inventory/README.fr.md#facultatif---poser-la-même-question-à-lobservability-agent) | Observability Agent : question, KQL générée, mêmes lignes (facultatif) |

Les captures du terminal suivent la structure du validateur : une ligne d'objectif, des en-têtes `== Step N ==` avec une ligne `Why:`,
puis une ligne `PASS`/`FAIL` par contrôle avec le statut HTTP attendu.

## Déroulé

| Horaire | Module | Objectif | Résultat attendu exact | Solution de repli |
|---|---|---|---|---|
| 00:00-00:15 | Accueil | Authentification, autorisation, approbation | Les participants distinguent les trois contrôles | [Guide pédagogique](LEARNING-GUIDE.md) |
| 00:15-00:40 | 00 | Vérifier les outils et les responsabilités | Lignes PASS publiées ; aucun déploiement implicite | Poste préparé ; ne pas ignorer les droits |
| 00:40-01:10 | 01 | Découvrir et appeler l'outil local | `tools/list`, résultat synthétique exact, approbation visible | Sortie Inspector enregistrée |
| 01:10-01:30 | 02 | Limites d'une clé partagée | HTTP 401 sans clé ; HTTP 200 et réussite MCP avec clé | Captures réelles du module 02 ou enregistrement ; ne jamais montrer la clé |
| 01:30-02:00 | 03 | Audience, scope et rôle | Mauvaise audience 401 ; Alice/Bob se connectent ; Eve n'obtient pas le jeton | Captures réelles du module 03 (terminal et portail) ; revendications fictives |
| 02:00-02:10 | Pause | Réinitialiser les clients | Aucun identifiant visible | Fermer les clients et les terminaux |
| 02:10-02:45 | 04 | APIM comme seul point d'entrée | Bob 403 ; Alice 200 ; rafale 429 ; accès direct refusé ; journaux sans corps | Enregistrement approuvé et statuts |
| 02:45-03:15 | 05 | OBO ou identité managée | Utilisateur : Alice oui/Bob non ; application : même résultat | Tableau des quatre résultats et captures réelles du module 05 |
| 03:15-03:40 | 06 | Métadonnées et inventaire | Appelant, outil fixe, statut, durée, corrélation ; aucun contenu | Capture KQL réelle du module 06 ou résultat de requête préparé |
| 03:40-03:50 | 07 facultatif | Même protection avec un autre client | Connexion sans secret prise en charge | Ignorer ; transfert Foundry **Preview** seulement |
| 03:50-04:00 | 99 | Nettoyage et preuves | Ressources de l'atelier recensées ; suppression encore soumise à approbation | Liste des points à vérifier |

## Erreurs fréquentes et réponses sûres

| Symptôme | Explication | Réponse sûre |
|---|---|---|
| HTTP 401 | Échec d'authentification ou de validation | Vérifier émetteur, tenant, audience exacte et expiration |
| HTTP 403 dans APIM | Identité valide, rôle absent ou blocage | Vérifier l'affectation ; ne pas élargir le rôle de Bob |
| HTTP 200 et `isError: true` | Transport MCP réussi, outil ou ressource aval en échec | Lire le résultat structuré et l'ID de corrélation |
| Appel direct Functions réussi | Contournement de la passerelle | Arrêter, puis rétablir l'accès uniquement par le réseau privé et APIM |
| OBO échoue pour Bob | Les droits de l'utilisateur s'appliquent | Conserver le refus ; aucun repli applicatif |
| Le client exige un secret | Parcours incompatible avec l'atelier | Reporter le client facultatif ; ne pas ajouter de secret |
| Les journaux contiennent le corps | Paramétrage non conforme | Arrêter le trafic, supprimer la capture et vérifier l'absence de tout octet de corps |
| Une fonctionnalité en Preview se comporte autrement | Contrat ou disponibilité modifiés | Utiliser l'enregistrement et revérifier Microsoft Learn |

## Démonstrations facultatives réservées à l'animateur

Les métadonnées de ressource protégée et les API de gestion MCP d'API Management sont en **Preview**.
Agent 365 et **AI Gateway (Preview)** exigent une approbation distincte pour le tenant ; aucune étape destinée aux participants ne la
demande. Le transfert d'identité Foundry est en **Preview** lorsqu'il est documenté. Les clients passent toujours
par APIM, et les API aval reçoivent de nouveaux jetons émis pour leur propre audience.

## Clôture

Consignez seulement les lignes PASS non sensibles, les écarts et les dates des sources publiques. Un module ne devient
`validated` qu'après la réussite de son validateur sur un abonnement neuf, juste après le module précédent.

## Sources

- [Sources de l'atelier](../sources.md).
- [Étapes d'architecture générées](../../assets/architecture/STEPS.fr.md).
- [Microsoft Learn : sécuriser MCP](https://learn.microsoft.com/azure/api-management/secure-mcp-servers).

Dernière vérification : 2026-10-14.

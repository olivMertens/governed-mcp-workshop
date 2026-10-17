# Guide de l'animateur

[English](../facilitator-guide.md)

Ce guide vous aide à préparer l'atelier principal, qui dure 4 heures. Les modules 00 et 01 sont implémentés ; les horaires suivants
décrivent le parcours prévu et ne constituent pas une preuve de validation. Le statut figure dans [PROGRESS.md](../PROGRESS.md).

## Avant l'arrivée des participants - 30 minutes

- Vérifiez la révision publiée, les statuts et la [provenance des schémas](../../assets/architecture/README.fr.md).
- Utilisez uniquement les personnages fictifs Alice, Bob et Eve. N'affichez aucun jeton réel, aucun tenant ni aucun abonnement.
- Vérifiez l'abonnement hors production, l'administrateur d'identité, le responsable des rôles et le budget.
- Préparez des captures ou des enregistrements des étapes cloud. Ils montrent le résultat attendu, pas une validation.
- Réservez Agent 365 et AI Gateway à l'animateur ; les deux sont en **Preview**.

## Déroulé

| Horaire | Module | Objectif | Résultat attendu exact | Solution de repli |
|---|---|---|---|---|
| 00:00-00:15 | Accueil | Authentification, autorisation, approbation | Les participants distinguent les trois contrôles | [Guide pédagogique](LEARNING-GUIDE.md) |
| 00:15-00:40 | 00 | Vérifier les outils et les responsabilités | Lignes PASS publiées ; aucun déploiement implicite | Poste préparé ; ne pas ignorer les droits |
| 00:40-01:10 | 01 | Découvrir et appeler l'outil local | `tools/list`, résultat synthétique exact, approbation visible | Sortie Inspector enregistrée |
| 01:10-01:30 | 02 | Limites d'une clé partagée | HTTP 401 sans clé ; HTTP 200 et réussite MCP avec clé | Enregistrement ; ne jamais montrer la clé |
| 01:30-02:00 | 03 | Audience, scope et rôle | Mauvaise audience 401 ; Alice/Bob se connectent ; Eve n'obtient pas le jeton | Revendications fictives |
| 02:00-02:10 | Pause | Réinitialiser les clients | Aucun identifiant visible | Fermer les clients et les terminaux |
| 02:10-02:45 | 04 | APIM comme seul point d'entrée | Bob 403 ; Alice 200 ; rafale 429 ; accès direct refusé ; journaux sans corps | Enregistrement approuvé et statuts |
| 02:45-03:15 | 05 | OBO ou identité managée | Utilisateur : Alice oui/Bob non ; application : même résultat | Tableau des quatre résultats |
| 03:15-03:40 | 06 | Métadonnées et inventaire | Appelant, outil fixe, statut, durée, corrélation ; aucun contenu | Résultat de requête préparé |
| 03:40-03:50 | 07 facultatif | Même protection avec un autre client | Connexion sans secret prise en charge | Ignorer ; transfert Foundry **Preview** seulement |
| 03:50-04:00 | 99 | Nettoyage et preuves | Ressources de l'atelier recensées ; suppression encore soumise à approbation | Liste de contrôle |

## Erreurs fréquentes et réponses sûres

| Symptôme | Explication | Réponse sûre |
|---|---|---|
| HTTP 401 | Échec d'authentification ou de validation | Vérifier émetteur, tenant, audience exacte et expiration |
| HTTP 403 dans APIM | Identité valide, rôle absent ou blocage | Vérifier l'affectation ; ne pas élargir le rôle de Bob |
| HTTP 200 et `isError: true` | Transport MCP réussi, outil ou ressource aval en échec | Lire le résultat structuré et la corrélation |
| Appel direct Functions réussi | Contournement de la passerelle | Arrêter et rétablir l'accès privé/APIM uniquement |
| OBO échoue pour Bob | Les droits utilisateur sont appliqués | Conserver le refus ; aucun repli applicatif |
| Le client exige un secret | Parcours incompatible avec l'atelier | Reporter le client facultatif ; ne pas ajouter de secret |
| Les journaux contiennent le corps | Paramétrage non conforme | Arrêter le trafic, supprimer la capture et vérifier l'absence de tout octet de corps |
| Une fonction en Preview se comporte autrement | Contrat ou disponibilité modifiés | Utiliser l'enregistrement et revérifier Microsoft Learn |

## Démonstrations facultatives réservées à l'animateur

Les métadonnées de ressource protégée et les API de gestion MCP d'API Management sont en **Preview**.
Agent 365 et **AI Gateway (Preview)** exigent une approbation distincte pour le tenant ; aucune étape destinée aux participants ne la
demande. Le transfert d'identité Foundry est en **Preview** lorsqu'il est documenté. Les clients utilisent toujours
APIM et les API aval reçoivent de nouveaux jetons propres à leur audience.

## Clôture

Consignez seulement les lignes PASS non sensibles, les écarts et les dates des sources publiques. Un module devient
`validated` uniquement après réussite de son validateur sur un abonnement neuf, juste après le module précédent.

## Sources

- [Sources de l'atelier](../sources.md).
- [Étapes d'architecture générées](../../assets/architecture/STEPS.fr.md).
- [Microsoft Learn : sécuriser MCP](https://learn.microsoft.com/azure/api-management/secure-mcp-servers).

Dernière vérification : 2026-10-14.

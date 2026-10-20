# Choisir son parcours

[English](../TRACKS.md)

Choisissez **un seul** parcours avant le module 00. Chaque parcours a ses propres guides :
vous n'avez pas à alterner entre deux méthodes au milieu d'un module.
Le module 01, qui s'exécute sur votre poste sans Azure, est commun.

Sur le site de l'atelier, sélectionnez une carte ci-dessus. Votre choix reste dans l'adresse de la page.
Les guides, leur PDF, les commandes de validation et le nettoyage correspondent ensuite à ce parcours.
Sur GitHub, suivez uniquement les liens du tableau de votre parcours ci-dessous.

## Low-code : le portail d'abord

Ce parcours vous apprend où se trouvent les réglages dans Azure et Microsoft Entra.
Chaque guide précise les menus, les valeurs à saisir et ce qu'il faut vérifier avant de continuer.
Les captures réelles servent de repères : elles viennent de l'environnement de l'auteur.
Utilisez **vos propres** noms de ressources.

Low-code ne signifie pas « sans terminal ». PowerShell 7 et Azure CLI servent à publier le serveur fourni,
à appliquer les réglages indisponibles dans le portail et à vérifier les résultats.
Le guide indique quand quitter le portail, où lancer la commande et ce qu'elle doit afficher.
**Terraform n'est pas nécessaire.**

| Ordre | Votre guide | Vérifier avant de poursuivre |
|---|---|---|
| 00 | [Préparer l'environnement low-code](../../modules/00-prerequisites/LOW-CODE.fr.md) | Les contrôles des outils et de l'abonnement réussissent, sans Terraform |
| 01 | [Découvrir MCP sur votre poste](../../modules/01-discover-mcp/README.fr.md) | Inspector liste les outils |
| 02 | [Créer et publier le serveur ouvert](../../modules/02-open-server/LOW-CODE.fr.md) | Sans clé : HTTP 401 ; avec la bonne clé : HTTP 200 |
| 03 | [Ajouter l'authentification Microsoft Entra](../../modules/03-entra-authentication/LOW-CODE.fr.md) | Alice et Bob se connectent ; Eve est refusée |
| 04 | [Faire passer tous les appels par API Management](../../modules/04-governed-gateway/LOW-CODE.fr.md) | Accès direct à la Function : HTTP 403 ; écriture de Bob : HTTP 403 |
| 05 | [Comparer les appels délégués et applicatifs](../../modules/05-delegated-and-app-only/LOW-CODE.fr.md) | Bob ne lit pas le rapport en son nom ; les résultats applicatifs sont identiques |
| 06 | [Consulter les journaux et l'inventaire](../../modules/06-observe-inventory/LOW-CODE.fr.md) | Vos requêtes montrent les métadonnées, pas le contenu des échanges |
| 07, facultatif | [Connecter le client Foundry](../../modules/07-clients/LOW-CODE.fr.md) | Vous approuvez un véritable appel d'outil ; Copilot Studio reste une lecture |
| 99, toujours | [Nettoyer les ressources low-code](../../modules/99-cleanup/LOW-CODE.fr.md) | Vérifiez tous les groupes et objets d'identité de l'atelier, options comprises |

## Terraform + PowerShell

Ce parcours vous apprend à déployer une infrastructure de façon reproductible.
Suivez les commandes PowerShell dans l'ordre, relisez chaque plan, puis lancez le validateur du module.
Les commandes bash sont facultatives et appartiennent au même parcours.
Les captures du portail servent à inspecter le déploiement, pas à le refaire à la main.

| Ordre | Votre guide | Vérifier avant de poursuivre |
|---|---|---|
| 00 | [Préparer l'environnement Terraform](../../modules/00-prerequisites/README.fr.md) | Les outils, les paramètres privés et les contrôles de l'abonnement sont prêts |
| 01 | [Découvrir MCP sur votre poste](../../modules/01-discover-mcp/README.fr.md) | Inspector liste les outils |
| 02 | [Déployer le serveur ouvert](../../modules/02-open-server/README.fr.md) | Sans clé : HTTP 401 ; avec la bonne clé : HTTP 200 |
| 03 | [Déployer l'authentification Microsoft Entra](../../modules/03-entra-authentication/README.fr.md) | Alice et Bob se connectent ; Eve est refusée |
| 04 | [Déployer la passerelle gouvernée](../../modules/04-governed-gateway/README.fr.md) | Accès direct à la Function : HTTP 403 ; écriture de Bob : HTTP 403 |
| 05 | [Déployer les accès délégués et applicatifs](../../modules/05-delegated-and-app-only/README.fr.md) | L'API appelée en aval refuse à Bob la lecture déléguée du rapport |
| 06 | [Consulter les journaux et inscrire le serveur](../../modules/06-observe-inventory/README.fr.md) | Les requêtes montrent les métadonnées ; l'inventaire contient l'adresse de la passerelle |
| 07, facultatif | [Connecter le client Foundry](../../modules/07-clients/README.fr.md) | Vous approuvez un véritable appel d'outil ; Copilot Studio reste une lecture |
| 99, toujours | [Lancer le nettoyage contrôlé](../../modules/99-cleanup/README.fr.md) | Le rapport ne trouve plus de ressource déployée appartenant à l'atelier |

## Avant de commencer

1. Obtenez l'accord pour votre propre abonnement hors production. N'utilisez pas l'environnement d'un autre participant.
2. Envoyez la [demande à l'administrateur des identités](../requests/identity-request.md) avant le module 03.
   Les guides distinguent ses actions des vôtres.
3. Conservez le fichier privé de paramètres. Le low-code ajoute `lc` au préfixe pour les nouvelles ressources ;
   Terraform conserve le préfixe tel quel. Un groupe fourni par l'administrateur garde son nom.
4. Suivez les modules dans l'ordre. Si vous prévoyez le module 05, publiez son code serveur **avant**
   que le module 04 rende privés les points de terminaison de déploiement de la Function.
5. Gardez du temps pour le module 99, même si vous vous arrêtez après le module 02.

> [!IMPORTANT]
> Changer de guide ne convertit pas les ressources d'un parcours vers l'autre.
> Ne lancez pas Terraform sur les ressources créées avec les guides low-code.
> Nettoyez le premier déploiement avant de changer de parcours.

> [!WARNING]
> Functions, Storage, API Management et les ressources Foundry facultatives peuvent être facturés.
> Le déploiement d'API Management peut dépasser la durée d'une courte séance.
> La date d'expiration d'une étiquette ne supprime rien. Suivez le module 99 de votre parcours.

Les deux parcours gardent les mêmes contrôles : une audience de jeton par appel entre services,
aucun transfert du jeton client vers les API en aval, des rôles par utilisateur, une approbation explicite
des écritures et aucun contenu de message dans les journaux.

## Résultats de référence et captures

Les résultats existants ont été obtenus dans l'environnement de test approuvé de l'auteur le 2026-10-20.
Le précédent essai Foundry low-code portait sur les adaptations de préparation, pas sur un nouveau déroulé complet.
Les guides séparés et leur navigation doivent être suivis à nouveau en conditions réelles :
les anciens résultats ne prouvent pas que chaque instruction réorganisée a déjà été exécutée.
Les captures existantes sont réutilisées avec cette limite. Aucune capture manquante n'est inventée.

Dernière mise à jour éditoriale : 2026-10-20.

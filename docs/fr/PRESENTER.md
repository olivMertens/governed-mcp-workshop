# Présentateur : partager le lien GitHub Pages

[English](../PRESENTER.md)

**GitHub Pages héberge les guides. Chaque participant réalise ses propres exercices.**
Ne déployez pas de seconde page d'accueil dans Azure. Ce guide du présentateur reste dans le dépôt
et dans l'interface locale des auteurs ; il est exclu du site participant.

Publier les guides ne déploie ni ne valide un serveur Model Context Protocol (MCP).
Suivez l'ordre et les limites de validation du [README racine](../../README.md).
Le [module 01](../../modules/01-discover-mcp/README.fr.md) fonctionne localement, sans Azure.

## Avant la session

1. Publiez la version relue avec le [workflow GitHub Pages](HOSTING.md#publier-sur-github-pages).
   Attendez la réussite de la construction et du déploiement. Vérifiez les deux langues et les deux parcours.
2. Ouvrez le site participant dans une fenêtre séparée. Ne projetez ni paramètres privés, ni jetons,
   ni état Terraform, ni réponses contenant des identifiants, ni session administrateur.
3. Dans votre tenant de démonstration approuvé, vérifiez l'enregistrement de l'authentification multifacteur (MFA)
   des comptes dédiés Alice, Bob et Eve. N'affaiblissez jamais l'accès conditionnel pour éviter cet enregistrement.
4. Vérifiez la capacité disponible et le coût avant de déployer des ressources MCP de démonstration.
   API Management Standard v2 reste facturé tant qu'il existe ; consultez les tarifs régionaux et prévoyez le nettoyage.
5. Préparez les captures ci-dessous. Une capture illustre un résultat ; elle ne valide pas le déploiement d'une autre personne.

Fil conducteur de la séquence architecture : [Séquence 2 - intégrer et exposer MCP](INTEGRATION-OPTIONS.md).
Le site public utilise une version destinée aux participants et les animations des modules, pas ces notes orales.

## Partager les liens participants

- [Français](https://olivmertens.github.io/governed-mcp-workshop/?lang=fr#/start)
- [English](https://olivmertens.github.io/governed-mcp-workshop/?lang=en#/start)

Message proposé :

> Ouvrez le lien, choisissez votre langue et votre parcours, puis suivez le module 00.
> Utilisez seulement votre tenant et votre abonnement de test approuvés. Vous n'avez aucun site documentaire à déployer.
> Le module 01 fonctionne sans Azure. Suivez les autres modules dans l'ordre et terminez les exercices payants par le module 99.
> Pour tester votre serveur déployé, utilisez VS Code ou MCP Inspector sur votre ordinateur.
> Le site prépare des instructions ; il ne contacte pas votre serveur et ne valide pas le test.
> Gardez vos identifiants et jetons privés. Si la MFA est requise, enregistrez-la sans désactiver de contrôle de connexion.

## Qui déploie quoi

| Élément | Qui | Où |
|---|---|---|
| Guides partagés | Responsable du dépôt | GitHub Pages, depuis `main` après relecture. Aucun compte Azure ni accès au tenant des participants. |
| Notes du présentateur et outils de construction | Auteurs | Dépôt et interface locale uniquement. |
| Ressources MCP, à partir du module 02 | Chaque participant | Son propre abonnement Azure de test et son tenant Microsoft Entra approuvés. |
| Ressources de démonstration | Présentateur, après approbation | Son environnement hors production, jamais le tenant d'un participant. |

Les lignes PASS d'un participant ne valent que pour son déploiement. Ne lui demandez jamais de transmettre
ses identifiants, jetons ou traces contenant des corps de requêtes. Ne partagez ni identifiants de connexion,
ni clés de déploiement, ni sessions administrateur.

## Enseigner une étape à la fois

Avant le module 01, utilisez [Comprendre MCP et les agents](MCP-CONCEPTS.md) pour expliquer les hôtes,
les clients, les serveurs, la boucle de l'agent, les outils, les ressources et les prompts.
Posez les questions de prédiction avant de révéler les réponses. Lire ou cliquer sur **Suivant** n'exécute aucun outil.

Demandez aux participants d'expliquer le but et de prévoir le résultat avant de copier une commande.
Exécutez un bloc court, examinez la sortie réelle, puis poursuivez. Prévoyez des pauses distinctes pour
la relecture du plan, l'approbation humaine, les interventions de l'administrateur des identités et le nettoyage.
Ne regroupez pas planification et application dans un seul bloc à coller.

Le lecteur affiche la position, le contenu, puis les boutons. Le **Sommaire** permet de revenir à une explication.
Les références longues restent repliées tant qu'on ne les ouvre pas. Les pages de continuation préservent
les commandes et les éléments complets ; un élément indivisible peut dépasser la longueur habituelle.

Le bouton d'apparence propose **Template**, **Blanc** et **Sombre**. Ce choix reste local au navigateur :
il ne modifie pas le guide partagé et ne déploie rien.

## Préparer les captures de repli

Les guides présentent des captures avec pseudonymes, identifiants remplacés par des zéros et repères visuels.
Servez-vous-en si le consentement, la MFA, les quotas ou le réseau bloquent une étape en direct.

| Module | Observation |
|---|---|
| [02](../../modules/02-open-server/README.fr.md) | Accès public du stockage désactivé et points de terminaison privés approuvés |
| [03](../../modules/03-entra-authentication/README.fr.md) | Authentification de la Function, rôles, contrôles opérateur et appel d'Alice |
| [05](../../modules/05-delegated-and-app-only/README.fr.md) | Autorisations déléguées et information d'identification fédérée de l'identité managée |
| [06](../../modules/06-observe-inventory/README.fr.md) | Requêtes sur les métadonnées seules et résultats facultatifs d'Observability Agent |

Lisez l'objectif du validateur, les en-têtes `== Step N ==`, les lignes `Why:` et le statut HTTP attendu.
Une commande préparée n'est pas un résultat. Une réponse HTTP 200 peut encore contenir une erreur d'outil MCP.

## Terminer la session en sécurité

Chaque participant supprime uniquement ses ressources avec le [module 99](../../modules/99-cleanup/README.fr.md).
Le présentateur fait de même pour sa démonstration approuvée. Aucun site Azure partagé ne doit rester en service.
Conservez les paramètres privés et l'état jusqu'à la vérification du nettoyage. Ne supprimez pas de groupe
ou d'identité fourni par l'administrateur. Pour une ancienne copie Azure des guides, suivez la
[procédure de retrait](HOSTING.md#supprimer-une-ancienne-copie-azure).

## Sources

- [Publication GitHub Pages](HOSTING.md).
- [Tarifs API Management](https://azure.microsoft.com/pricing/details/api-management/).
- [Guide de test depuis un client](PRACTICE.md).

Dernière vérification : 2026-10-21. Lire ou publier un guide ne valide pas le déploiement d'un participant.

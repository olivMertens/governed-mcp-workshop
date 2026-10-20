# Choisir son parcours : low-code ou full-code

[English](../TRACKS.md)

Chaque module atteint le même résultat de deux façons. Choisissez **un seul** parcours pour tout l'atelier.

| | Parcours low-code | Parcours full-code |
|---|---|---|
| Comment construire | Portail Azure, ou une courte commande `az` par étape | Terraform (`infra/`) et les scripts des modules |
| Pour qui | Les administrateurs qui préfèrent le portail ; pour apprendre où se trouve chaque réglage | Les déploiements reproductibles ; les équipes déjà habituées à l'infrastructure en code |
| Noms | Même fichier de participant, avec `lc` en plus (`rg-mcp-<prefix>lc-...`) | `rg-mcp-<prefix>-<suffix>` |
| Vérifications | Les mêmes validateurs, avec vos noms de ressources en paramètres | Les validateurs lisent les sorties Terraform |
| Nettoyage | Checklist low-code du module 99 : supprimer un groupe de ressources et les objets Entra créés | Script du module 99 : plans Terraform contrôlés, module par module |
| Erreurs | Le portail accepte tout : les validateurs sont votre filet de sécurité | Chaque modification passe par un plan relu |

> [!IMPORTANT]
> **Ne mélangez pas les parcours.** Terraform ne connaît que ce qu'il a créé. Un réglage modifié à la main dans le portail
> est annulé par le plan Terraform suivant, et le script du module 99 refuse les plans qui touchent des objets inconnus.
> Si vous avez commencé un parcours, terminez-le, ou nettoyez et recommencez.

> [!TIP]
> Lors d'une journée d'atelier avec un après-midi de 90 minutes, choisissez votre parcours ici, puis suivez l'étape
> suivante : **Le parcours de l'après-midi en 90 minutes**.

## Le parcours de l'après-midi en 90 minutes

Ce matin, les présentateurs ont montré un serveur MCP en TypeScript, protégé par la permission `Mcp.Read`. Cet
après-midi, vous construisez vous-même les mêmes niveaux dans votre propre abonnement hors production : un serveur .NET
sur Azure Functions, les rôles d'application `Tools.Read` et `Tools.Write`, et les utilisateurs de test Alice, Bob et
Eve. Les mêmes idées, avec votre code.

| Quand | Ce que vous faites | Module | Terminé quand |
|---|---|---|---|
| Avant la journée | Installer les outils, vous connecter, choisir votre abonnement hors production | [00](../../modules/00-prerequisites/README.fr.md) | Le validateur du module 00 réussit |
| Avant la journée | Envoyer la demande à l'administrateur d'identité, pour que les objets du module 03 existent ou soient approuvés | [Demande d'identité](../requests/identity-request.md) | Vous avez l'ID client de l'API et les utilisateurs de test |
| D'abord | Appeler un serveur MCP local, sans Azure | [01](../../modules/01-discover-mcp/README.fr.md) | L'Inspector liste les outils |
| Ensuite | Déployer le serveur ouvert et constater le risque | [02](../../modules/02-open-server/README.fr.md) | Un appel sans la clé est refusé ; un appel avec la clé fonctionne |
| Ensuite | Le protéger avec Microsoft Entra | [03](../../modules/03-entra-authentication/README.fr.md) | Alice et Bob obtiennent HTTP 200 ; un jeton pour une autre audience est refusé |
| En option | Placer API Management devant | [04](../../modules/04-governed-gateway/README.fr.md) | Le `create_ticket` de Bob reçoit HTTP 403 ; celui d'Alice reçoit HTTP 200 |
| Avant de partir | Nettoyer tout ce que vous avez créé | [99](../../modules/99-cleanup/README.fr.md) | Le rapport ne montre plus aucune ressource de l'atelier |
| Après la journée | Module 04 partie B, puis 05, 06 et 07, à votre rythme | [05](../../modules/05-delegated-and-app-only/README.fr.md) | Le validateur de chaque module réussit |

> [!WARNING]
> Les modules 02 et 04 créent des ressources facturées. Lancez le module 99 avant de partir, même si vous vous êtes
> arrêté avant la fin.

Pas d'abonnement, ou pas d'approbation de l'administrateur d'identité ? Rejoignez le plan d'observation sur
l'environnement préparé : vous appelez les mêmes niveaux sans rien déployer.

## Ce qui reste identique

- Les règles de sécurité : une audience par jeton, aucun relais de jeton, des rôles d'application par utilisateur, aucun
  secret de longue durée, zéro octet de corps dans les journaux.
- Les tests : les mêmes résultats HTTP (401, 403, 200, 429) pour Alice, Bob et Eve.
- L'ordre : modules 00 à 07, puis 99.

## Où commence le parcours low-code dans chaque module

Dans le portail, choisissez votre parcours une fois au-dessus de **Suivez le guide** (**Full-code** ou **Low-code**) : le guide n'affiche alors que les étapes de ce parcours, dans tous les modules, et retient ce choix. Sur GitHub, ouvrez la section **Parcours low-code** au début des **Étapes**. Chaque étape montre d'abord le chemin
dans le portail, puis la commande `az` équivalente, puis le résultat réel obtenu par l'auteur. Gardez le même terminal
PowerShell depuis l'étape L1 : les étapes suivantes réutilisent ses variables.

| Module | Section low-code |
|---|---|
| 00, 01 | Inutile : ils ne construisent rien dans Azure, il n'y a donc qu'un chemin |
| 02 à 05 | **Parcours low-code**, étapes L1, L2 et suivantes (L-B pour la partie B du module 04) |
| 06 | **Parcours low-code**, avant l'étape 1 : seules les lignes de terminal changent |
| 07 | **A2 et A3 dans le parcours low-code**, après l'étape A3 : les étapes Foundry sont les mêmes |
| 99 | **Parcours low-code**, au début des Étapes : un groupe de ressources et deux inscriptions d'applications |

L'auteur a suivi le parcours low-code en conditions réelles le 2026-10-20, du module 02 au module 99, avec Alice, Bob et
Eve. Au module 07, seules A2 et A3 diffèrent : seules elles ont été rejouées ; les étapes Foundry ont été exécutées en
conditions réelles dans le parcours full-code le même jour.

Dernière vérification : 2026-10-20.

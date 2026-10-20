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

## Ce qui reste identique

- Les règles de sécurité : une audience par jeton, aucun relais de jeton, des rôles d'application par utilisateur, aucun
  secret de longue durée, zéro octet de corps dans les journaux.
- Les tests : les mêmes résultats HTTP (401, 403, 200, 429) pour Alice, Bob et Eve.
- L'ordre : modules 00 à 07, puis 99.

## Où commence le parcours low-code dans chaque module

Ouvrez le module, puis la section **Parcours low-code** au début des **Étapes**. Chaque étape montre d'abord le chemin
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

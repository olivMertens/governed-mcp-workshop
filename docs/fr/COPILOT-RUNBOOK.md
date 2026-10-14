# Préparer l'atelier avec l'application GitHub Copilot

Ce guide s'adresse aux personnes qui construisent l'atelier, pas aux participants qui suivent les exercices.
**Un module = une session = une branche = une pull request (PR).** Fusionnez avant le module suivant.
La préparation du module 00 et l'exercice MCP local du module 01 sont implémentés.
Aucun de ces modules n'est encore entièrement validé.

Les participants peuvent travailler sans ce processus de construction :
[choisir leur environnement](GETTING-STARTED.md), VS Code avec un conteneur de développement ou un terminal local,
vérifier les outils puis préparer leurs paramètres privés et le groupe Terraform.
Le tableau s'ouvre par défaut sur `#/start`. Choisir un environnement ne valide aucun module.

## Avant de commencer

Installez et connectez GitHub Copilot app selon la politique de votre organisation.
Les versions candidates de Git, GitHub CLI, Azure CLI, Terraform, PowerShell 7, Node.js, .NET et Functions Core Tools
sont décrites dans les [références](REFERENCES.md). Le module 00 fixe leurs versions et prévoit les contrôles.
Choisissez votre [tenant et abonnement de test](DEPLOYMENT.md). L'administrateur d'identité approuve séparément
applications, consentements et comptes de test Alice, Bob et Eve. Aucun identifiant réel dans le dépôt.

Le serveur MCP Microsoft Learn public est configuré dans `.mcp.json` et `.vscode/mcp.json` pour compatibilité :
`https://learn.microsoft.com/api/mcp`, HTTP, sans authentification.
Pour un autre client, ajoutez-le via Customize ou `/mcp add`, nom `microsoft-learn`. Évitez les doublons.

## Démarrer depuis les bons fichiers

Si vous avez déjà le dépôt, ouvrez ce dossier en session **locale**. N'y relancez pas le bootstrap.
Pour une destination neuve et vide seulement :

```powershell
pwsh -ExecutionPolicy Bypass -File .\setup-workshop-mcp.ps1
```

Le script nécessite Git et GitHub CLI sauf `-SkipGitHub`. Si nécessaire, installez ces outils via les commandes
winget indiquées par le script, puis rouvrez le terminal. L'identité Git doit être configurée.
La publication utilise une identité noreply locale au dépôt, sans modifier l'identité Git globale.
Le bootstrap refuse un dossier non vide et un dépôt distant existant : ne videz pas un dossier pour contourner ce contrôle.
Options : `-Visibility private`, `-SkipGitHub`, `-OpenVSCode`, `-Path`, `-RepoName`.
Il ne crée ni ne modifie de ressource Azure ou Entra. Une publication nouvelle nécessite votre approbation.

## Modes et responsabilités

| Mode | Usage |
|---|---|
| Plan | Lire les sources et proposer avant de coder. |
| Interactive, session locale | Tout accès ou changement Azure/Entra, avec votre contexte Azure CLI. |
| Autopilot | Documentation seulement, éventuellement en parallèle. |

`docs/BUILD-PLAN.md` est le plan technique canonique en anglais. `docs/PROGRESS.md` reste la seule source de statut.
L'agent suit `.github/skills/workshop-module-builder/SKILL.md` et `.github/copilot-instructions.md`.
Il doit présenter le plan Terraform, les objets Entra, rôles, coûts, Preview et nettoyage puis attendre votre
approbation explicite avant tout changement cloud.

## Consignes à copier dans Copilot

Les consignes ci-dessous sont à copier dans une session Copilot. Le tableau ne les exécute pas.

<details>
<summary>Pour aller plus loin : consignes de construction P1 à P9 et documentation</summary>

### P1 - Plan global, sans code

```text
Lis .github/copilot-instructions.md, docs/BUILD-PLAN.md, docs/PROGRESS.md puis les sources officielles.
Propose l'arborescence complète, les fichiers par module et les choix réseau, providers Terraform, région,
permissions Entra, Preview et coûts. Ne code pas. Consigne les décisions à résoudre dans docs/PROGRESS.md.
```

### P2 - Modules 00 puis 01, sessions séparées

```text
Utilise workshop-module-builder pour le module 00 : devcontainer, précontrôle et demande d'identité précise.
Arrête après réussite de sa validation. Mets à jour docs/PROGRESS.md et ouvre la PR.
Après fusion, démarre une autre session et branche pour le module 01 ; arrête après réussite du validateur.
```

### P3 - Module 02, serveur par clé

```text
Utilise workshop-module-builder pour le module 02, préfixe participant p00 et contexte de test approuvé.
Montre le plan Terraform et les coûts avant application. Attends mon approbation.
Utilise la clé système MCP et l'autorisation System, jamais un endpoint anonyme. Valide puis ouvre la PR.
```

### P4 - Module 03, Microsoft Entra

```text
Utilise workshop-module-builder pour le module 03. Liste exactement objets Entra, permissions et consentements
de infra/entra ; applique seulement après approbation. Active l'authentification intégrée et les métadonnées PRM
(Preview), sans secret client. Prouve les résultats attendus pour Alice, Bob et Eve.
```

### P5 - Module 04, point d'entrée imposé

```text
Utilise workshop-module-builder pour le module 04. API Management est le seul point d'entrée.
Prouve avec validate.ps1 : écriture de Bob 403, Alice 200 et succès MCP, seuil de débit 429,
Function directe refusée et journaux sans corps. Présente le plan et attends mon accord avant modification.
```

### P6 - Module 05, délégation et app-only

```text
Utilise workshop-module-builder pour le module 05. Compare OBO et identité managée avec Alice et Bob.
Valide les quatre cas, avec statut HTTP et indicateur d'erreur MCP. Aucun secret, transfert de jeton MCP
aux API cibles ni repli sur l'identité développeur.
```

### P7 - Module 06, observation et inventaire

```text
Utilise workshop-module-builder pour le module 06 : KQL ou workbook limité à outil, ID objet de l'appelant
authentifié, statut, latence et corrélation. Inscris l'URL gouvernée dans API Center. Zéro octet de corps.
Toute création ou modification nécessite mon accord préalable.
```

### P8 - Module 99, nettoyage

```text
Utilise workshop-module-builder pour le module 99. Présente le vrai plan de destruction et attends mon accord.
Supprime les ressources Azure avant les seuls objets Entra créés pour l'atelier. Préserve les identités fournies et les ressources
partagées. Vérifie inventaire, rôles, réseau privé, rétention et coûts restants.
```

### PD - Documentation en parallèle

```text
Écris les explications et le guide de l'animateur à partir du plan et des modules réellement validés.
Synchronise les explications françaises et les schémas éditables. Ne modifie ni code de module ni infrastructure.
Mets à jour les sources et ouvre une PR.
```

### P9 - Revue finale

```text
Vérifie les neuf invariants, l'absence de contenu privé, les liens, les mentions Preview et le nettoyage
sur un abonnement neuf. Liste les écarts dans une PR. Ne corrige que ce qui est sûr et approuvé.
```

</details>

Le module 07 est une démonstration facultative de l'animateur ; il ne doit pas retarder le nettoyage.
Avant l'atelier, répétez les modules 00 à 06 puis 99 sur un abonnement de test neuf.
Vérifiez les coûts et préparez des vidéos de secours.

## Utiliser le tableau

Demandez « Affiche le Workshop build board ». Le SDK canvas Copilot est en **Preview**, indépendant d'un agent Foundry.
Choisissez EN ou FR. `?lang=fr#/module/04` ouvre directement le module 04 en français.
L'URL conserve le choix de langue ; aucun compte ni suivi personnel n'est créé.
Les pages incluent schémas, gouvernance, références, contexte Azure et espace de test.

Le tableau ne change aucun statut ni aucune ressource et n'exécute aucune commande. Il affiche le guide publié lorsqu'il existe ;
sinon, une conception explicitement non exécutable. Si un futur README français manque, il le dit et permet de
lire l'original anglais sans prétendre l'avoir traduit.
Les décisions et preuves de construction conservent leur texte original anglais, clairement signalé.

Dans **Tester votre serveur MCP**, seule une adresse HTTPS sans clé ni paramètre reste en mémoire de page.
Les copies de commandes, configurations et prompts ne font aucun appel réseau MCP.
Codespaces ouvre le choix de création de la branche publiée, pas une machine prête ni les modifications non poussées.
Inspector reste privé, authentifié et sans stockage de jetons. Chaque client Entra demande sa propre approbation.

Les actions agent restent `get_progress`, `set_module_status` et `list_open_decisions`.
L'écriture de statut exige la révision courante. `validated` exige date et vraie preuve du validateur.
Le tableau ne certifie pas cette preuve. N'y mettez ni jetons, consignes, paramètres ou résultats d'outils,
ni données réelles de comptes.

## Sources

[Plan technique original](../BUILD-PLAN.md), [registre](REFERENCES.md), [pratique](PRACTICE.md),
[configuration VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers).
Dernière vérification : 2026-10-14.

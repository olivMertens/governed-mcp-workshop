# Construire le workshop avec GitHub Copilot app

Ce runbook construit le workshop, il ne remplace pas les futurs guides participant.
**Un module = une session = une branche = une pull request (PR).** Fusionnez avant le module suivant.
Les modules ne sont pas encore implémentés ni validés.

Les participants peuvent travailler sans ce processus de construction :
[choisir leur environnement](GETTING-STARTED.md), VS Code en dev container ou terminal local,
vérifier les outils puis préparer leurs paramètres privés et le groupe Terraform.
Le board s'ouvre par défaut sur `#/start`. Choisir un environnement ne valide aucun module.

## Avant de commencer

Installez et connectez GitHub Copilot app selon la politique de votre organisation.
Les versions candidates de Git, GitHub CLI, Azure CLI, Terraform, PowerShell 7, Node.js, .NET et Functions Core Tools
sont décrites dans le [registre de sources](REFERENCES.md). Le module 00 doit les épingler et les vérifier.
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

## Séquence et prompts

Les prompts ci-dessous peuvent être copiés dans une session Copilot. Ils ne sont pas exécutés par le board.

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
Retire le workload avant les seuls objets Entra créés par le workshop. Préserve identités fournies et ressources
partagées. Vérifie inventaire, rôles, réseau privé, rétention et coûts restants.
```

### PD - Documentation en parallèle

```text
Écris les concepts et le guide facilitateur à partir du plan et des modules réellement validés.
Synchronise les explications françaises et les schémas éditables. Ne modifie ni code de module ni infrastructure.
Mets à jour les sources et ouvre une PR.
```

### P9 - Revue finale

```text
Vérifie les neuf invariants, l'absence de contenu privé, les liens, les mentions Preview et le nettoyage
sur un abonnement neuf. Liste les écarts dans une PR. Ne corrige que ce qui est sûr et approuvé.
```

Le module 07 est une démonstration facultative du facilitateur ; il ne bloque jamais le nettoyage.
Avant le jour du workshop : répétition 00 à 06 sur un abonnement de test neuf, puis 99 ; coûts vérifiés et vidéos de secours.

## Utiliser le board

Demandez « Affiche le Workshop build board ». Le SDK canvas Copilot est en **Preview**, indépendant d'un agent Foundry.
Choisissez EN ou FR. `?lang=fr#/module/04` ouvre directement le module 04 en français.
L'URL conserve le choix de langue ; aucun compte ni suivi personnel n'est créé.
Les pages incluent schémas, gouvernance, références, contexte Azure et espace de test.

Le board ne change ni statut ni ressource et n'exécute aucune commande. Il affiche le README réel lorsqu'il existe ;
sinon, une conception explicitement non exécutable. Si un futur README français manque, il le dit et permet de
lire l'original anglais sans prétendre l'avoir traduit.
Les décisions et preuves de construction conservent leur texte original anglais, clairement signalé.

Dans **Tester votre MCP**, seule une adresse HTTPS sans clé ni paramètre reste en mémoire de page.
Les copies de commandes, configurations et prompts ne font aucun appel réseau MCP.
Codespaces ouvre le choix de création de la branche publiée, pas une machine prête ni les modifications non poussées.
Inspector reste privé, authentifié et sans stockage de jetons. Chaque client Entra demande sa propre approbation.

Les actions agent restent `get_progress`, `set_module_status` et `list_open_decisions`.
L'écriture de statut exige la révision courante. `validated` exige date et vraie preuve du validateur.
Le board ne certifie pas cette preuve. N'y mettez ni jetons, prompts, arguments, résultats ni données réelles de comptes.

## Sources

[Plan technique original](../BUILD-PLAN.md), [registre](REFERENCES.md), [pratique](PRACTICE.md),
[configuration VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers).
Dernière vérification : 2026-10-14.

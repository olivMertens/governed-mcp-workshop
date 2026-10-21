# Bien démarrer

Ouvrez le site de l'atelier sur GitHub Pages, choisissez EN/FR et votre parcours, puis commencez le module 00.
Le portail ne demande pas de choisir un environnement. Exécutez les commandes dans votre terminal.
Le site utilise PowerShell 7 partout, sous Windows, macOS et Linux. Aucun terminal de commande à choisir.
Les alternatives bash restent dans les guides et scripts du dépôt, pas dans les leçons ni les exports PDF du site.
Les détails facultatifs sur les conteneurs et Codespaces ci-dessous restent une référence, pas un choix obligatoire.
Vous n'avez besoin ni d'un autre App Service ni du compte administrateur d'une autre personne.
Pas de portail ? Suivez directement ces guides Markdown.
<!-- author-only -->
**Présentateur :** utilisez le [guide de publication séparé](PRESENTER.md).
<!-- /author-only -->

**Essayer MCP sans Azure :** après le clonage et l'installation de .NET 10/PowerShell 7,
suivez le [module 01](../../modules/01-discover-mcp/README.fr.md).
Le site ne fait qu'héberger les guides ; il est facultatif.

Choisissez où exécuter les commandes : sur votre poste, dans un conteneur de développement avec
**Visual Studio Code (VS Code)**, ou dans GitHub Codespaces. Les exercices et les scripts sont les mêmes.
Vous pouvez suivre les guides sans Copilot ni le tableau de bord de l'atelier.

**Choisissez aussi votre parcours de déploiement :** après le clonage ci-dessous, suivez le
[module 00 low-code](../../modules/00-prerequisites/LOW-CODE.fr.md), qui contient tous ses prérequis et contrôles,
ou le [module 00 Terraform](../../modules/00-prerequisites/README.fr.md).
En low-code, vous n'avez pas besoin de l'installation ni des commandes Terraform de cette page.

## 0. Récupérer le dépôt sur votre poste

Pour travailler dans le terminal local ou dans un conteneur VS Code, commencez par récupérer une copie du dépôt.
Avec Codespaces, passez directement au choix d'environnement ci-dessous.

**Sous Windows, si Git et PowerShell 7 ne sont pas installés**, exécutez ces commandes une par une
dans votre terminal, avec l'accord de votre organisation :

```powershell
winget install --id Git.Git --exact
winget install --id Microsoft.PowerShell --exact
```

Fermez le terminal, puis ouvrez **PowerShell 7** (`pwsh`), pas Windows PowerShell 5.1.
Si WinGet est indisponible ou bloqué, utilisez les installateurs officiels du tableau plus bas ;
ne contournez pas les règles de votre poste.

**Cloner `main`** dans un dossier de votre profil utilisateur :

```powershell
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path "$HOME\source" -Force | Out-Null
Set-Location "$HOME\source"
git clone --branch main https://github.com/olivMertens/governed-mcp-workshop.git
if ($LASTEXITCODE -ne 0) { throw 'Le clonage a echoue. Ne poursuivez pas dans un autre dossier.' }
Set-Location .\governed-mcp-workshop
```

Ou, avec bash dans un dossier où vous conservez vos projets :

```bash
git clone --branch main https://github.com/olivMertens/governed-mcp-workshop.git && \
  cd governed-mcp-workshop
```

**Résultat attendu :** `README.md`, `scripts` et `infra` sont présents dans le dossier courant.
Toutes les commandes suivantes s'exécutent depuis ce dossier. Si VS Code est installé, ouvrez-le avec `code .`.
Chaque participant utilise sa propre copie. Le dépôt est public : vous pouvez le cloner sans compte GitHub ni GitHub CLI.
Tant qu'il reste privé, le présentateur doit vous donner accès au dépôt ou vous partager le portail des guides.

<details>
<summary>Vous avez déjà une copie ? La retrouver et la mettre à jour</summary>

Revenez dans **votre copie d'origine**, surtout si des ressources ont déjà été déployées.
Vérifiez que vous êtes sur `main` avec `git branch --show-current`.
Si le dossier est bien un dépôt Git, sans modification locale :

```powershell
if (git status --porcelain) { throw 'Conservez vos modifications locales avant la mise a jour.' }
git pull --ff-only
if ($LASTEXITCODE -ne 0) { throw 'Mise a jour refusee. Ne forcez pas la fusion.' }
```

Ne partagez ni `.workshop` ni l'état Terraform. Ne supprimez pas ces fichiers, ne clonez pas de nouveau le dépôt pour
« repartir de zéro » et ne lancez pas `git clean` pour résoudre un problème de mise à jour.

</details>

## 1. Choisir votre environnement de travail

| Environnement | Ce qu'il vous faut | Pour commencer |
|---|---|---|
| VS Code avec un conteneur de développement | VS Code, l'extension Dev Containers et un moteur de conteneurs Linux autorisé par votre organisation | Ouvrir le dépôt avec `code .`, puis choisir **Dev Containers: Reopen in Container** dans la palette de commandes. |
| Terminal local | Git, PowerShell 7.4+, Azure CLI, SDK .NET, Node.js, Functions Core Tools ; Terraform seulement pour son parcours | Garder la copie locale. Installer les outils de votre parcours selon les règles de votre organisation. |
| Codespaces, facultatif | Un compte GitHub avec un quota disponible et l'accord pour d'éventuels frais | [Choisir la branche et la machine](https://codespaces.new/olivMertens/governed-mcp-workshop). Seuls les fichiers publiés sur cette branche seront disponibles. |

Ne rendez pas publics les ports de MCP Inspector. Ne partagez pas votre dossier de connexion Azure avec le conteneur.
La configuration du conteneur a été vérifiée, mais personne n'a encore testé son démarrage ni celui de Codespaces.
Si le conteneur pose problème, passez au terminal local, à condition que votre organisation l'autorise.

<details>
<summary>Pour aller plus loin : fonctionnement du conteneur et compatibilité Docker ou Podman</summary>

Le conteneur accède aux fichiers du dépôt. Il ne partage pas explicitement votre dossier de connexion Azure
ni la connexion de contrôle du moteur de conteneurs, ne vous connecte pas à Azure et ne déploie rien.
Vérifiez les scripts d'installation et le partage Git de VS Code avant d'approuver le dépôt.
Les instructions concernent VS Code, pas l'environnement de développement Visual Studio.

### Dans le dev container

L'image Ubuntu 24.04 et les composants d'installation officiels (Features) sont fixés par empreinte
dans `.devcontainer/devcontainer.json`.
Versions retenues : Azure CLI 2.88.0, Terraform 1.16.6, SDK .NET 10.0.402, PowerShell 7.6.6,
Node.js 22.22.0 et Functions Core Tools 4.14.0. Le script de création installe Core Tools puis lance
le **même** `check-tools.ps1` que sur le poste local. Les dépendances téléchargées et les extensions de l'éditeur
peuvent évoluer : ces empreintes ne figent pas tous les paquets. Examinez chaque mise à jour.

Il ne suffit pas que Docker soit installé : `docker version` et `docker info` doivent répondre.
Pour Podman 5+, suivez [la procédure VS Code](https://code.visualstudio.com/remote/advancedcontainers/docker-options) :
vérifiez `podman version`, `podman info` et, sur Windows/macOS, `podman machine list`, puis définissez
**Dev Containers: Docker Path** sur `podman`. Ne créez pas de nouvelle machine et n'exposez pas de socket TCP
pour contourner un problème. VS Code ne prend pas officiellement en charge tous les clients compatibles Docker.
Cette configuration n'utilise ni Compose ni conteneurs imbriqués.

**Ce qui reste à vérifier :** la configuration et les empreintes publiques ont été contrôlées, mais aucun moteur
de conteneurs n'était disponible sur le poste de l'auteur. La construction, les deux architectures Linux et l'exécution Codespaces restent à vérifier
au jalon du module 00. La présence d'un fichier ne prouve pas que votre moteur ou votre proxy fonctionne.
En cas d'échec, consultez **Dev Containers: Show Container Log**. Corrigez l'erreur réelle de registre, proxy ou plateforme ;
ne désactivez pas la vérification des certificats et ne changez pas de moteur sans examen.

</details>

### Installer les outils pour le terminal local

Le conteneur et Codespaces gèrent leur propre installation ; n'installez pas tout deux fois.
Sous Windows, installez uniquement les outils manquants ou trop anciens. Exécutez les commandes
une par une, vérifiez leur résultat et respectez les demandes d'autorisation de votre organisation.

| Outil | Commande Windows ou installateur |
|---|---|
| Azure CLI, pour se connecter à Azure | `winget install --id Microsoft.AzureCLI --exact` |
| Terraform, seulement pour le parcours Terraform | `winget install --id Hashicorp.Terraform --exact` |
| SDK .NET 10, pour le serveur C# | `winget install --id Microsoft.DotNet.SDK.10 --exact` |
| Node.js, version LTS prise en charge | `winget install --id OpenJS.NodeJS.LTS --exact` |
| Azure Functions Core Tools **v4** | [Installateurs Windows officiels](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools) : choisissez la version compatible avec votre poste. |

Fermez et rouvrez **PowerShell 7** après l'installation, puis revenez dans le dossier du dépôt.
WinGet propose les versions de son catalogue : le contrôle de l'étape 2 vérifie les versions minimales acceptées ci-dessous.
Si une version est trop ancienne, utilisez l'installation officielle ou demandez l'aide de votre administrateur.
Sur macOS/Linux, suivez les liens officiels correspondant à votre système.

Installez les versions compatibles avec votre système depuis les sources officielles :

| Outil | Version vérifiée | Source |
|---|---|---|
| Git | 2+ | [Téléchargements Git](https://git-scm.com/downloads) |
| PowerShell | 7.4+ | [Installation](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Azure CLI | 2.88.0+ | [Installation](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Terraform (parcours Terraform uniquement) | 1.16.6+, inférieur à 2 | [Installation](https://developer.hashicorp.com/terraform/install) |
| SDK .NET | 10 installé | [Téléchargement .NET](https://dotnet.microsoft.com/download/dotnet/10.0) |
| Node.js | 22.19.0+ | [Téléchargement](https://nodejs.org/en/download) |
| Functions Core Tools | 4.5.0+, inférieur à 5 | [Installation officielle](https://learn.microsoft.com/azure/azure-functions/functions-run-local) |

Choisissez Core Tools v4, et non la CLI Functions v5, un outil distinct en **Preview**.
Certains lanceurs npm téléchargent le programme au premier appel. Le contrôle détecte les installations
incomplètes connues et s'arrête au lieu de déclencher ce téléchargement. Terminez l'installation selon la
procédure approuvée. Aucun script ne modifie automatiquement votre poste ou votre moteur de conteneurs.

## 2. Vérifier le terminal que vous allez utiliser

Les commandes ci-dessous contrôlent les outils du parcours Terraform.
En low-code, utilisez le [module 00 dédié](../../modules/00-prerequisites/LOW-CODE.fr.md) :
il passe `-Track low-code` et ne contrôle pas Terraform.

Depuis la racine du dépôt, dans le conteneur si vous l'avez choisi, sinon sur votre poste :

```powershell
& .\scripts\check-tools.ps1
```

```bash
bash ./scripts/check-tools.sh
```

PowerShell est aussi nécessaire sous macOS et Linux. Corrigez chaque `FAIL`.
Ce contrôle se contente d'afficher la version des outils locaux : il ne vérifie ni les permissions Azure ni les quotas, et ne déploie rien.

## 3. Préparer vos paramètres de déploiement

Choisissez votre préfixe de participant, une région approuvée, un libellé de propriétaire sans information
personnelle et une date de nettoyage proche. Adaptez les exemples : `p01`, `alice` et `swedencentral`
ne sont pas des valeurs imposées.

```powershell
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry $expiry
```

```bash
read -r -p 'Date de nettoyage approuvée (yyyy-MM-dd) : ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry "$expiry"
```

Le script crée un fichier privé, `.workshop/participant.tfvars.json`, que Git ne publie pas.
Il y conserve un suffixe aléatoire pour distinguer vos noms de ressources de ceux des autres participants.
Même si tout le monde choisit `p01`, chaque préparation indépendante produit ses propres noms.
Chacun doit utiliser sa propre copie du dépôt, ses paramètres privés et son état Terraform : ne les copiez pas d'un autre participant.
Relancer la même commande réutilise le fichier ; si vous changez les paramètres, le script s'arrête.
Conservez ce fichier et l'état Terraform, qui permet de retrouver les ressources déployées, jusqu'au nettoyage.
Le script ne contacte pas Azure. La date est un rappel, **pas une suppression automatique**.

Si l'administrateur vous fournit un groupe, ajoutez `-ExistingResourceGroupName` avec son nom dès la
première préparation. Terraform ne gérera pas ce groupe existant et ne le supprimera pas.

> [!WARNING]
> Des noms différents ne donnent pas de quota supplémentaire. Vérifiez la capacité et les coûts
> avant tout déploiement. Ne recréez pas vos paramètres pour contourner une erreur.

<details>
<summary>Pour aller plus loin : noms des ressources et groupes existants</summary>

Une nouvelle préparation enregistre un suffixe de 16 caractères hexadécimaux minuscules, soit 64 bits aléatoires.
Les préparations antérieures, avec un suffixe de 10 caractères, conservent tous leurs noms sans modification.
Dans le tableau, `participant` comporte 2 à 8 lettres minuscules ou chiffres et commence par une lettre.
`court` désigne ses six premiers caractères, ou le préfixe entier s'il est plus court.
Le suffixe aléatoire n'est jamais raccourci.

| Ressource | Nom d'une nouvelle préparation | Contrainte Azure |
|---|---|---|
| Nouveau groupe de ressources | `rg-mcp-<participant>-<suffixe>` | 1 à 90 caractères ; unique dans l'abonnement |
| Compte de stockage (prévu) | `st<court><suffixe>` | 3 à 24 lettres minuscules ou chiffres ; unique dans tout Azure |
| Application Functions (prévue) | `func-mcp-<court>-<suffixe>` | Nom d'application unique dans tout Azure ; limité ici à 32 caractères pour préserver l'identifiant de l'hôte |
| API Management (prévu) | `apim-mcp-<participant>-<suffixe>` | 1 à 50 lettres, chiffres ou traits d'union ; unique dans tout Azure |

Les sorties Terraform sont des **noms prévus**, pas des serveurs déployés ni une réservation de noms.
Le caractère aléatoire réduit le risque de collision sans le supprimer : vérifiez la disponibilité avant le déploiement.
Ne régénérez jamais le suffixe pour résoudre un problème de quota ou réparer un déploiement existant.
Si les paramètres ont disparu mais qu'un état local, des métadonnées de stockage de l'état ou un plan enregistré
sont encore présents aux emplacements connus, le script s'arrête. Restaurez le fichier privé d'origine.
Le script ne détecte pas toujours un état distant ou enregistré ailleurs.

Pour un groupe fourni par l'administrateur, ajoutez son nom exact avec `-ExistingResourceGroupName` au **premier**
appel. Terraform lit ce groupe comme une source de données : il ne l'importe pas, ne le renomme pas,
ne modifie pas ses étiquettes et ne le supprime pas. Les ressources créées ensuite dans ce groupe conservent le suffixe du participant.
Créer un groupe exige une autorisation distincte sur l'abonnement ; Contributor sur un groupe existant
ne permet pas de créer un groupe voisin. Mieux vaut utiliser un groupe existant qu'élargir les rôles.

Si un nom est refusé, recherchez-en la cause avant le premier déploiement. Ne renommez pas un groupe déjà
déployé sans examiner les conséquences.

Ne rendez jamais aléatoires les noms d'outils, les valeurs du protocole, les autorisations et rôles applicatifs,
ni les noms de zones privées du système de noms de domaine (DNS) imposés par les services.
Les modules d'identité et de réseau, encore à construire, devront aussi vérifier l'isolation des participants
et l'absence de chevauchement des plages d'adresses.

</details>

## 4. Comprendre le périmètre Terraform

Continuez avec le [module 00](../../modules/00-prerequisites/README.fr.md).
`infra/workload` est la racine Terraform de **vos** ressources : d'abord le groupe de ressources, puis chaque module
active sa partie avec une variable (la Function App au module 02, l'authentification Entra au 03, API Management au 04,
les accès délégué et applicatif au 05). `infra/entra` contient les objets Microsoft Entra ; un administrateur des
identités le lance (ou vous-même, dans un tenant de test où vous avez ce rôle). Rien n'est déployé tant que vous
n'appliquez pas un plan relu. Les instructions sont publiées sur GitHub Pages, sans application Azure supplémentaire ;
voir le [guide d'hébergement](HOSTING.md).
La section 5 ci-dessous (« Carte de déploiement ») liste ce que chaque module ajoute.
Le parcours en terminal local a été validé sur la cible de préparation, sans créer de ressource.
Chaque participant doit refaire ces contrôles pour sa propre cible ; le parcours conteneur/Codespaces n'a pas encore été vérifié.
Vous pouvez déjà exécuter le [module 01 en local](../../modules/01-discover-mcp/README.fr.md) avec .NET 10 et PowerShell 7.
Il ne demande ni connexion Azure, ni Terraform, ni site supplémentaire.
Les contrôles SDK et Inspector réussissent en local ; l'approbation dans le client reste à vérifier à la main.
Terminez le module 00 dans l'environnement réellement choisi avant les exercices cloud.

### Se connecter à son tenant de test

Après la préparation de l'étape 3, lancez dans **le même terminal PowerShell 7** :

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\select-azure-context.ps1 -Language fr
& .\modules\00-prerequisites\validate.ps1 `
    -TenantId $env:ARM_TENANT_ID `
    -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

Le sélecteur demande les identifiants du tenant et de l'abonnement **approuvés**, puis la confirmation `NONPROD`.
Il lance `az login --tenant`, sélectionne l'abonnement avec `az account set` et vérifie le contexte.
Les variables `ARM_TENANT_ID` et `ARM_SUBSCRIPTION_ID` restent dans ce terminal pour Terraform.
L'administrateur vous fournit ces identifiants en privé ; ne les copiez pas dans GitHub ou dans le portail.

**Résultat attendu :** vérification du contexte, puis `PASS module 00 foundation environment checks.`
La connexion ne donne pas de nouveaux droits et les contrôles ne créent aucune ressource.
En cas d'échec, arrêtez-vous et consultez le [guide de contexte Azure](DEPLOYMENT.md).

**Comptes de test et MFA :** votre tenant de test peut exiger l'authentification multifacteur (MFA).
À la première connexion d'Alice, de Bob ou d'Eve, Microsoft Entra demande d'enregistrer une méthode,
par exemple une application d'authentification. Faites-le dans le navigateur qui s'ouvre.
N'affaiblissez jamais l'accès conditionnel pour éviter cette étape.

### Lire la sortie d'un validateur

Chaque module fournit un `validate.ps1` ; `validate.sh` lance le même script et affiche donc la même sortie.

- La première ligne rappelle ce que le module démontre.
- Les en-têtes `== Step N: ... ==` regroupent les contrôles. La ligne `Why:` placée dessous explique ce que l'étape prouve.
- Chaque contrôle tient sur une ligne : `PASS` ou `FAIL`, ce qui est vérifié, puis le statut HTTP attendu,
  par exemple `(expected HTTP 401)`. Une ligne `INFO` signale un contrôle ignoré ou manuel.
- La dernière ligne donne le résultat. Au moindre `FAIL`, arrêtez-vous et lisez la section Dépannage du module.

Le module 03 montre une [capture réelle annotée](../../modules/03-entra-authentication/README.fr.md#étapes) de cette sortie.

<details>
<summary>Pour aller plus loin : examiner un plan Terraform et conserver son état</summary>

Suivez [le guide de contexte Azure](DEPLOYMENT.md) dans **le même terminal** que Terraform.
Ensuite, uniquement dans une session de déploiement approuvée, examinez le plan réel :

```powershell
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\workload.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
```

```bash
terraform -chdir=infra/workload init -lockfile=readonly &&
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/workload.tfplan
```

La commande `plan` peut interroger Azure. Le tableau de bord n'exécute aucune commande. Ne lancez pas `apply` avant l'approbation du plan exact,
des permissions, du quota et des coûts. N'utilisez jamais `-auto-approve`. L'enregistrement automatique des fournisseurs
est désactivé : un administrateur enregistre séparément ceux qui sont requis. Attribuer des rôles Azure et administrer Entra sont deux permissions distinctes.
N'utilisez jamais de rôle Owner global, de secret client ni d'abonnement de production pour contourner un blocage.

Gardez une seule copie et un seul état pour le déploiement. Le conteneur monté et le poste partagent les fichiers ;
un autre clone ou codespace possède son propre état local. N'y redéployez pas : restaurez en privé les paramètres et l'état,
ou configurez d'abord un backend distant approuvé et isolé. Ne publiez ni état, ni plan, ni paramètres, ni identifiants CLI.

Après les étapes payantes, suivez le module 99. Examinez le plan de suppression avec le même état.
Conservez les groupes et identités existants. Ne supprimez pas un groupe entier pour contourner un nettoyage incomplet.

</details>

## 5. Carte de déploiement : ce que vous déployez, module par module

Vous construisez **un seul** environnement, étape par étape. Chaque module ajoute une couche à la précédente.
Trois règles le gardent sûr :

1. **Une seule copie du dépôt, un seul dossier privé, un seul état Terraform** (le dossier `.workshop`), du module 00 au module 99.
   Ne clonez jamais à nouveau pour « repartir de zéro ».
2. **Chaque module ajoute un petit fichier privé** dans `.workshop` (ignoré par Git). Il contient des options et des
   identifiants, jamais de secret.
3. **Chaque plan reçoit tous les fichiers privés qui existent** (pour `infra/workload`), dans l'ordre du tableau.
   Si vous en retirez un, le plan supprime ce que ce fichier avait activé.

| Module | Racine Terraform | Fichier privé à ajouter | Ce qui apparaît dans votre tenant | Ce que vous devez voir |
|---|---|---|---|---|
| 00 | aucune (contrôles en lecture seule) | `participant.tfvars.json` (section 3) | Rien | [validateur, tout en PASS](../../assets/screenshots/terminal-00-validate.png) |
| 01 | aucune (en local) | aucun | Rien : le serveur tourne sur votre poste | [Inspector liste les outils](../../assets/screenshots/client-01-inspector.png) |
| 02 | `infra/workload` | `module02.tfvars.json` (`enable_mcp_server`) | Compte de stockage, Function App (Flex Consumption) avec les outils MCP derrière une clé | [plan Flex et outils MCP](../../assets/screenshots/azure-02-function-overview.png), [la clé système](../../assets/screenshots/azure-02-function-keys.png) |
| 03 | `infra/entra`, puis `infra/workload` (2 étapes) | `entra.tfvars.json`, `module03.tfvars.json` | Inscription d'application avec rôles d'application, authentification intégrée sur la Function App ; l'étape 2 remplace la clé | [rôles d'application](../../assets/screenshots/azure-03-app-roles.png) |
| 04 | `infra/workload` (2 étapes) | `module04.tfvars.json` (`enable_governed_gateway`) | API Management Standard v2, point de terminaison privé ; l'étape 2 ferme la Function App à Internet | [Function privée](../../assets/screenshots/azure-04-function-networking.png), [validateur](../../assets/screenshots/terminal-04-operator.png) |
| 04 partie B (facultatif) | `infra/workload` | `module04b.tfvars.json` (`enable_rest_mcp_demo`) | Une API REST exposée comme second serveur MCP | [outils MCP](../../assets/screenshots/azure-04b-mcp-tools.png) |
| 05 | `infra/workload`, puis `infra/entra` | `module05.tfvars.json`, `entra-module05.tfvars.json` | Identités managées avec identifiants fédérés, stockage des rapports | [autorisations d'API](../../assets/screenshots/azure-05-api-permissions.png) |
| 06 | aucune | aucun | Rien : vous lisez journaux et traces | [KQL dans Logs](../../assets/screenshots/azure-06-kql-logs.png) |
| 07 | `infra/entra`, puis `infra/workload` | `entra-module07.tfvars.json`, `module07.tfvars.json` | Une application cliente autorisée de plus | [approbation dans Foundry](../../assets/screenshots/azure-07-foundry-approve.png) |
| 99 | les mêmes racines, en suppression | aucun | Tout ce qui précède est supprimé | le rapport du module 99 |

Chaque guide de module donne les commandes exactes. Si vous préférez **une commande par module**, créez le fichier
privé comme l'indique le guide, puis lancez :

```powershell
& .\scripts\select-azure-context.ps1 -Language fr   # une fois par terminal : votre tenant et votre abonnement de test
& .\scripts\deploy-module.ps1 -Module 02            # puis 03, 04, 05, 07, dans l'ordre
```

Le script vérifie le contexte connecté, passe dans le bon ordre les fichiers privés qui existent, enregistre un
`terraform plan`, **attend que vous tapiez** `yes`, applique exactement ce plan, puis lance le validateur du module.
`-PlanOnly` s'arrête après le plan. Pour un module qui modifie des objets Entra, lancez-le d'abord avec `-Root entra`.
Il ne crée jamais vos fichiers privés, ne change jamais d'étape à votre place et n'utilise jamais `-auto-approve`.

Les captures de ce tableau viennent du tenant de test de l'auteur. Les noms sont remplacés par `p01-<suffix>`, les
identifiants par des zéros. Elles ont été produites avec [tools/capture](../../tools/capture/README.md), réutilisable
dans votre propre tenant.

## Sources

- [Azure CLI sous Windows](https://learn.microsoft.com/cli/azure/install-azure-cli-windows), [SDK .NET sous Windows](https://learn.microsoft.com/dotnet/core/install/windows).
- [Installation PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell), [Terraform](https://developer.hashicorp.com/terraform/install), [Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local).
- [Dev Containers VS Code](https://code.visualstudio.com/docs/devcontainers/containers), [moteurs alternatifs](https://code.visualstudio.com/remote/advancedcontainers/docker-options).
- [Features officielles](https://github.com/devcontainers/features), [spécification](https://containers.dev/implementors/json_reference/).
- [Nommage Azure](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules), [quotas](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).
- [Groupe géré AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group), [groupe existant](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/data-sources/resource_group).
- [Tests Terraform simulés](https://developer.hashicorp.com/terraform/language/tests/mocking), [état](https://developer.hashicorp.com/terraform/language/state).
- [Pratique MCP](PRACTICE.md), [gouvernance](LEARNING-GUIDE.md), [références](REFERENCES.md).

Dernière vérification : 2026-10-14. Les contrôles locaux et simulés ne valident ni la construction du conteneur ni le déploiement Azure.

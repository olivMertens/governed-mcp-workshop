# Bien démarrer

**Participant :** ouvrez le lien envoyé par le présentateur, choisissez EN/FR, puis commencez le module 00.
Vous n'avez besoin ni d'un autre App Service ni du compte administrateur du présentateur.
Sans portail, suivez directement ces guides Markdown.
**Présentateur :** utilisez le [guide de publication séparé](PRESENTER.md).

**Essayer MCP sans Azure :** après le clonage et l'installation de .NET 10/PowerShell 7,
suivez le [module 01](../../modules/01-discover-mcp/README.fr.md).
Le portail du présentateur ne fait qu'héberger les guides ; il est facultatif.

Choisissez où exécuter les commandes : sur votre poste, dans un conteneur de développement avec
**Visual Studio Code (VS Code)**, ou dans GitHub Codespaces. Les exercices et les scripts sont les mêmes.
Vous pouvez suivre les guides sans Copilot ni ce tableau.

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
git clone --branch main https://github.com/olivMertens/workshop-mcp.git
if ($LASTEXITCODE -ne 0) { throw 'Le clonage a echoue. Ne poursuivez pas dans un autre dossier.' }
Set-Location .\workshop-mcp
```

**Résultat attendu :** `README.md`, `scripts` et `infra` sont présents dans le dossier courant.
Toutes les commandes suivantes s'exécutent depuis ce dossier. Si VS Code est installé, ouvrez-le avec `code .`.
Chaque participant utilise sa propre copie. Une fois le dépôt public, aucun compte GitHub ni GitHub CLI n'est nécessaire pour le cloner.
Tant qu'il est privé, le présentateur doit vous accorder l'accès au dépôt ou partager le portail documentaire.

<details>
<summary>Vous avez déjà une copie ? La retrouver et la mettre à jour</summary>

Revenez dans **votre copie d'origine**, surtout si des ressources ont déjà été déployées.
Vérifiez que vous êtes sur `main` avec `git branch --show-current`.
Si le dossier est suivi par Git et ne contient aucune modification locale :

```powershell
if (git status --porcelain) { throw 'Conservez vos modifications locales avant la mise a jour.' }
git pull --ff-only
if ($LASTEXITCODE -ne 0) { throw 'Mise a jour refusee. Ne forcez pas la fusion.' }
```

Gardez privés `.workshop` et l'état Terraform. Ne supprimez pas ces fichiers, ne clonez pas de nouveau le dépôt pour
« repartir de zéro » et ne lancez pas `git clean` pour résoudre un problème de mise à jour.

</details>

## 1. Choisir votre environnement de travail

| Environnement | Ce qu'il vous faut | Pour commencer |
|---|---|---|
| VS Code avec un conteneur de développement | VS Code, l'extension Dev Containers et un moteur de conteneurs Linux autorisé par votre organisation | Ouvrir le dépôt avec `code .`, puis choisir **Dev Containers: Reopen in Container** dans la palette de commandes. |
| Terminal local | Git, PowerShell 7.4+, Azure CLI, Terraform, SDK .NET, Node.js, Functions Core Tools | Conserver la copie locale. Installer les outils selon les règles de votre organisation. |
| Codespaces, facultatif | Un compte GitHub avec un quota disponible et l'accord pour d'éventuels frais | [Choisir la branche et la machine](https://codespaces.new/olivMertens/workshop-mcp). Seuls les fichiers publiés sur cette branche seront disponibles. |

Gardez les ports de MCP Inspector privés. Ne partagez pas votre dossier de connexion Azure avec le conteneur.
La configuration du conteneur a été vérifiée, mais son démarrage et celui de Codespaces restent à tester.
En cas de problème avec le conteneur, le terminal local reste possible si votre organisation l'autorise.

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
peuvent évoluer : ces empreintes ne figent pas tous les paquets. Toute mise à jour doit être examinée.

Docker doit répondre à `docker version` et `docker info`, pas seulement être installé.
Pour Podman 5+, suivez [la procédure VS Code](https://code.visualstudio.com/remote/advancedcontainers/docker-options) :
vérifiez `podman version`, `podman info` et, sur Windows/macOS, `podman machine list`, puis définissez
**Dev Containers: Docker Path** sur `podman`. Pour contourner un problème, ne créez pas de nouvelle machine
et n'exposez pas de socket TCP. VS Code ne prend pas officiellement en charge tous les clients compatibles Docker.
Cette configuration n'utilise ni Compose ni conteneurs imbriqués.

**Limite de vérification :** configuration et empreintes publiques vérifiées, mais aucun moteur n'était accessible sur le
poste de l'auteur. La construction, les deux architectures Linux et l'exécution Codespaces restent à vérifier
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
| Terraform, pour préparer les déploiements | `winget install --id Hashicorp.Terraform --exact` |
| SDK .NET 10, pour le serveur C# | `winget install --id Microsoft.DotNet.SDK.10 --exact` |
| Node.js, version LTS prise en charge | `winget install --id OpenJS.NodeJS.LTS --exact` |
| Azure Functions Core Tools **v4** | [Installateurs Windows officiels](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools) : choisissez la version compatible avec votre poste. |

Fermez et rouvrez **PowerShell 7** après l'installation, puis revenez dans le dossier du dépôt.
WinGet propose les versions de son catalogue : le contrôle de l'étape 2 vérifie les versions minimales acceptées ci-dessous.
Si une version est trop ancienne, utilisez l'installation officielle ou demandez l'aide de votre administrateur.
Sur macOS/Linux, suivez les liens officiels correspondant à votre système.

Installez les versions compatibles avec votre système depuis les sources officielles :

| Outil | Contrôle commun | Source |
|---|---|---|
| Git | 2+ | [Téléchargements Git](https://git-scm.com/downloads) |
| PowerShell | 7.4+ | [Installation](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Azure CLI | 2.88.0+ | [Installation](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Terraform | 1.16.6+, inférieur à 2 | [Installation](https://developer.hashicorp.com/terraform/install) |
| SDK .NET | 10 installé | [Téléchargement .NET](https://dotnet.microsoft.com/download/dotnet/10.0) |
| Node.js | 22.19.0+ | [Téléchargement](https://nodejs.org/en/download) |
| Functions Core Tools | 4.5.0+, inférieur à 5 | [Installation officielle](https://learn.microsoft.com/azure/azure-functions/functions-run-local) |

Choisissez Core Tools v4, et non la CLI Functions v5, un outil distinct en **Preview**.
Certains lanceurs npm téléchargent le programme au premier appel. Le contrôle détecte les installations
incomplètes connues et s'arrête au lieu de déclencher ce téléchargement. Terminez l'installation selon la
procédure approuvée. Aucun script ne modifie automatiquement votre poste ou votre moteur de conteneurs.

## 2. Vérifier le terminal réellement utilisé

Dans le conteneur si vous l'avez choisi, sinon sur le poste, depuis la racine du dépôt :

```powershell
& .\scripts\check-tools.ps1
```

```bash
bash ./scripts/check-tools.sh
```

PowerShell reste requis sur macOS/Linux. Corrigez chaque `FAIL`.
Ce contrôle se limite à des commandes locales d'affichage de version : il ne vérifie ni les permissions Azure ni les quotas, et ne déploie rien.

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
| Compte Storage, prévu | `st<court><suffixe>` | 3 à 24 lettres minuscules ou chiffres ; unique dans tout Azure |
| Application Functions, prévue | `func-mcp-<court>-<suffixe>` | Nom d'application unique dans tout Azure ; limité ici à 32 caractères pour préserver l'identifiant de l'hôte |
| API Management, prévu | `apim-mcp-<participant>-<suffixe>` | 1 à 50 lettres, chiffres ou traits d'union ; unique dans tout Azure |
| Plan App Service facultatif | `plan-mcp-<participant>-<suffixe>-portal` | 1 à 60 caractères ; unique dans le groupe |
| Application du portail facultatif | `web-mcp-<participant>-<suffixe>-portal` | 2 à 60 lettres, chiffres ou traits d'union ; nom d'application unique dans tout Azure |

Les sorties Terraform sont des **noms prévus**, pas des serveurs déployés ni une réservation de noms.
Le caractère aléatoire réduit le risque de collision sans le supprimer : vérifiez la disponibilité avant le déploiement.
Ne régénérez jamais le suffixe pour résoudre un problème de quota ou réparer un déploiement existant.
Si les paramètres ont disparu mais qu'un état local, des métadonnées de stockage de l'état ou un plan enregistré
sont encore présents aux emplacements connus, le script s'arrête. Restaurez le fichier privé d'origine.
Un état distant ou enregistré ailleurs n'est pas toujours détectable.

Pour un groupe fourni par l'administrateur, ajoutez son nom exact avec `-ExistingResourceGroupName` au **premier**
appel. Terraform lit ce groupe au moyen d'une source de données : aucun import, renommage, changement d'étiquettes
ou suppression. Les ressources créées ensuite dans ce groupe conservent le suffixe du participant.
Créer un groupe exige une autorisation distincte sur l'abonnement ; Contributor sur un groupe existant
ne permet pas de créer un groupe voisin. Préférez utiliser un groupe existant plutôt que d'élargir les rôles.

Si un nom est refusé, recherchez-en la cause avant le premier déploiement. Ne renommez pas un groupe déjà
déployé sans examiner les conséquences.

Les noms d'outils, les valeurs du protocole, les autorisations et rôles applicatifs, ainsi que les noms de zones
privées du système de noms de domaine (DNS) imposés par les services, ne doivent pas être rendus aléatoires.
Les modules d'identité et de réseau, encore à construire, devront aussi vérifier l'isolation des participants
et l'absence de chevauchement des plages d'adresses.

</details>

## 4. Comprendre le périmètre Terraform

Continuez avec le [module 00](../../modules/00-prerequisites/README.fr.md).
Le code Terraform actuel prépare le groupe et, sur demande, un portail App Service public payant.
Il ne déploie pas encore de serveur MCP, de réseau privé ni d'API Management.
Le parcours en terminal local a été validé sur la cible de préparation, sans créer de ressource.
Chaque participant doit refaire ces contrôles pour sa propre cible ; le parcours conteneur/Codespaces n'a pas encore été vérifié.
Le [module 01 local](../../modules/01-discover-mcp/README.fr.md) peut maintenant être exécuté avec .NET 10 et PowerShell 7.
Il ne demande ni connexion Azure, ni Terraform, ni portail du présentateur.
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

La commande `plan` peut interroger Azure. Le tableau n'exécute aucune commande. Pas d'`apply` avant approbation du plan exact,
des permissions, du quota et des coûts. Pas de `-auto-approve`. L'enregistrement automatique des fournisseurs
est désactivé : un administrateur enregistre séparément ceux qui sont requis. Attribuer des rôles Azure et administrer Entra sont deux permissions distinctes.
N'utilisez jamais de rôle Owner global, de secret client ni d'abonnement de production pour contourner un blocage.

Gardez une seule copie et un seul état pour le déploiement. Le conteneur monté et le poste partagent les fichiers ;
un autre clone ou codespace possède son propre état local. N'y redéployez pas : restaurez paramètres et état de façon privée
ou configurez d'abord un backend distant approuvé et isolé. Ne publiez ni état, ni plan, ni paramètres, ni identifiants CLI.

Après les étapes payantes, suivez le module 99. Examinez le plan de suppression avec le même état.
Conservez les groupes et identités existants. Ne supprimez pas un groupe entier pour contourner un nettoyage incomplet.

</details>

## Sources

- [Azure CLI sous Windows](https://learn.microsoft.com/cli/azure/install-azure-cli-windows), [SDK .NET sous Windows](https://learn.microsoft.com/dotnet/core/install/windows).
- [Installation PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell), [Terraform](https://developer.hashicorp.com/terraform/install), [Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local).
- [Dev Containers VS Code](https://code.visualstudio.com/docs/devcontainers/containers), [moteurs alternatifs](https://code.visualstudio.com/remote/advancedcontainers/docker-options).
- [Features officielles](https://github.com/devcontainers/features), [spécification](https://containers.dev/implementors/json_reference/).
- [Nommage Azure](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules), [quotas](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).
- [Groupe géré AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group), [groupe existant](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/data-sources/resource_group).
- [Tests Terraform simulés](https://developer.hashicorp.com/terraform/language/tests/mocking), [état](https://developer.hashicorp.com/terraform/language/state).
- [Pratique MCP](PRACTICE.md), [gouvernance](LEARNING-GUIDE.md), [références](REFERENCES.md).

Dernière vérification : 2026-10-14. Les contrôles locaux/simulés ne valident ni la construction du conteneur ni le déploiement Azure.

# Bien démarrer

Choisissez où exécuter les commandes : sur votre poste, dans un conteneur de développement avec
**Visual Studio Code (VS Code)**, ou dans GitHub Codespaces. Les exercices et les scripts sont les mêmes.
Vous pouvez suivre les guides sans Copilot ni ce tableau.

## 1. Choisir votre environnement de travail

| Environnement | Ce qu'il vous faut | Pour commencer |
|---|---|---|
| VS Code avec un conteneur de développement | VS Code, l'extension Dev Containers et un moteur de conteneurs Linux autorisé par votre organisation | Ouvrir le dépôt avec `code .`, puis choisir **Dev Containers: Reopen in Container** dans la palette de commandes. |
| Terminal local | Git, PowerShell 7.4+, Azure CLI, Terraform, SDK .NET, Node.js, Functions Core Tools | Garder la copie locale. Installer les outils selon les règles de votre organisation. |
| Codespaces, facultatif | Un compte GitHub avec du quota disponible et un accord pour les frais éventuels | [Choisir la branche et la machine](https://codespaces.new/olivMertens/workshop-mcp). Seuls les fichiers publiés sur cette branche seront disponibles. |

Gardez les ports de MCP Inspector privés. Ne partagez pas votre dossier de connexion Azure avec le conteneur.
La configuration du conteneur a été vérifiée, mais son démarrage et celui de Codespaces restent à tester.
En cas de problème avec le conteneur, le terminal local reste une possibilité si votre organisation l'autorise.

<details>
<summary>Pour aller plus loin : fonctionnement du conteneur et compatibilité Docker ou Podman</summary>

Le conteneur accède aux fichiers du dépôt. Il ne partage pas explicitement votre dossier de connexion Azure
ni la connexion de contrôle du moteur de conteneurs, ne vous connecte pas à Azure et ne déploie rien.
Vérifiez les scripts d'installation et le partage Git de VS Code avant d'approuver le dépôt.
Les instructions concernent VS Code, pas l'environnement de développement Visual Studio.

### Dans le dev container

L'image Ubuntu 24.04 et les composants d'installation officiels (Features) sont fixés par empreinte
dans `.devcontainer/devcontainer.json`.
Versions choisies : Azure CLI 2.88.0, Terraform 1.16.6, SDK .NET 10.0.402, PowerShell 7.6.6,
Node.js 22.22.0 et Functions Core Tools 4.14.0. Le script de création installe Core Tools puis lance
le **même** `check-tools.ps1` que sur le poste local. Les dépendances téléchargées et les extensions de l'éditeur
peuvent évoluer : ces empreintes ne figent pas tous les paquets. Toute mise à jour doit être examinée.

Docker doit répondre à `docker version` et `docker info`, pas seulement être installé.
Pour Podman 5+, suivez [la procédure VS Code](https://code.visualstudio.com/remote/advancedcontainers/docker-options) :
vérifiez `podman version`, `podman info` et, sur Windows/macOS, `podman machine list`, puis réglez
**Dev Containers: Docker Path** sur `podman`. Ne créez pas une nouvelle machine et n'exposez pas de socket TCP
comme contournement. VS Code ne prend pas officiellement en charge tous les clients compatibles Docker.
Cette configuration n'utilise ni Compose ni conteneurs imbriqués.

**Limite de vérification :** configuration et empreintes publiques vérifiées, mais aucun moteur accessible sur le
poste de création. La construction, les deux architectures Linux et l'exécution Codespaces restent à vérifier
au jalon du module 00. Un fichier présent ne prouve pas que votre moteur ou votre proxy fonctionne.
En cas d'échec : **Dev Containers: Show Container Log**. Corrigez l'erreur réelle de registre, proxy ou plateforme ;
ne désactivez pas la vérification des certificats et ne changez pas de moteur sans examen.

</details>

<details>
<summary>Installer les outils sur votre poste : versions et liens officiels</summary>

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

Choisissez Core Tools v4, pas la CLI Functions v5 distincte en **Preview**.
Certains lanceurs npm téléchargent le programme au premier appel. Le contrôle détecte les installations
incomplètes connues et s'arrête au lieu de déclencher ce téléchargement. Terminez l'installation selon la
procédure approuvée. Aucun script ne modifie automatiquement votre poste ou votre moteur de conteneurs.

</details>

## 2. Vérifier le terminal réellement utilisé

Dans le conteneur si vous l'avez choisi, sinon sur le poste, depuis la racine du dépôt :

```powershell
& .\scripts\check-tools.ps1
```

```bash
bash ./scripts/check-tools.sh
```

PowerShell reste requis sur macOS/Linux. Corrigez chaque `FAIL`.
Ce contrôle exécute uniquement des commandes de version locales : ni permissions Azure, ni quota, ni déploiement.

## 3. Préparer vos paramètres de déploiement

Choisissez votre préfixe de participant, une région approuvée, un libellé de propriétaire sans information
personnelle et une date de nettoyage proche. Adaptez les exemples : `p01`, `alice` et `westeurope`
ne sont pas des valeurs imposées.

```powershell
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry $expiry
```

```bash
read -r -p 'Date de nettoyage approuvée (yyyy-MM-dd) : ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry "$expiry"
```

Le script crée un fichier privé, `.workshop/participant.tfvars.json`, que Git ne publie pas.
Il y conserve une terminaison aléatoire pour distinguer vos noms de ressources de ceux des autres participants.
Relancer la même commande réutilise le fichier ; changer les paramètres provoque un arrêt.
Conservez ce fichier et l'état Terraform, qui permet de retrouver les ressources déployées, jusqu'au nettoyage.
Le script ne contacte pas Azure. La date est un rappel, **pas une suppression automatique**.

Si l'administrateur vous fournit un groupe, ajoutez `-ExistingResourceGroupName` avec son nom dès la
première préparation. Terraform ne gérera pas ce groupe existant et ne le supprimera pas.

> [!WARNING]
> Des noms différents ne donnent pas de quota supplémentaire. Vérifiez la capacité et les coûts
> avant tout déploiement. Ne recréez pas vos paramètres pour contourner une erreur.

<details>
<summary>Pour aller plus loin : noms des ressources et groupes existants</summary>

Nouveau groupe : `rg-mcp-<participant>-<suffixe>`. Les futurs noms globaux reprennent ce suffixe :
Storage utilise `stmcp<participant><suffixe>`, au plus 23 lettres minuscules/chiffres ;
Functions et API Management ont leur préfixe de service. Les sorties Terraform sont des **noms prévus**,
pas des serveurs déployés. L'aléatoire réduit le risque de collision sans le supprimer : vérifiez la disponibilité.
Ne régénérez jamais le suffixe pour résoudre un problème de quota ou réparer un déploiement existant.

Pour un groupe fourni par l'administrateur, ajoutez son nom exact avec `-ExistingResourceGroupName` au **premier**
appel. Terraform lit ce groupe par une source de données : aucun import, renommage, changement d'étiquettes
ou suppression. Les futures ressources filles gardent le suffixe participant.
Créer un groupe exige une autorisation distincte au niveau abonnement ; Contributor sur un groupe existant
ne permet pas de créer un groupe voisin. Préférez le chemin groupe existant plutôt qu'élargir les rôles.

En cas de nom refusé, recherchez la cause avant le premier déploiement. Ne renommez pas un groupe déjà
déployé sans examiner les conséquences.

</details>

## 4. Comprendre le périmètre Terraform

Continuez avec le [module 00](../../modules/00-prerequisites/README.fr.md).
Le code Terraform actuel prépare le groupe et, sur demande, un portail App Service public payant.
Il ne déploie pas encore de serveur MCP, de réseau privé ni d'API Management.
Les validations dans Azure et dans le conteneur restent à réaliser.

<details>
<summary>Pour aller plus loin : examiner un plan Terraform et conserver son état</summary>

Suivez [le guide de contexte Azure](DEPLOYMENT.md) dans **le même terminal** que Terraform.
Ensuite, uniquement dans une session de déploiement approuvée, examinez le plan réel :

```powershell
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/workload.tfplan
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
```

```bash
terraform -chdir=infra/workload init -lockfile=readonly &&
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/workload.tfplan
```

La commande `plan` peut consulter Azure. Le tableau n'exécute aucune commande. Pas d'`apply` avant approbation du plan exact,
des permissions, du quota et des coûts. Pas de `-auto-approve`. L'enregistrement automatique des fournisseurs
est désactivé : un administrateur enregistre séparément ceux requis. Les attributions de rôles et Entra sont distincts.
Jamais de rôle Owner global, secret client ou abonnement de production comme contournement.

Gardez une seule copie et un seul état pour le déploiement. Le conteneur monté et le poste partagent les fichiers ;
un autre clone ou codespace a un autre état local. N'y redéployez pas : restaurez paramètres et état de façon privée
ou configurez d'abord un backend distant approuvé et isolé. Ne publiez ni état, plan, paramètres ou identifiants CLI.

Après les étapes payantes, suivez le module 99. Examinez le plan de suppression avec le même état.
Préservez les groupes et identités existants. Ne supprimez pas un groupe entier pour contourner un nettoyage incomplet.

</details>

## Sources

- [Dev Containers VS Code](https://code.visualstudio.com/docs/devcontainers/containers), [moteurs alternatifs](https://code.visualstudio.com/remote/advancedcontainers/docker-options).
- [Features officielles](https://github.com/devcontainers/features), [spécification](https://containers.dev/implementors/json_reference/).
- [Nommage Azure](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules), [quotas](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).
- [Groupe géré AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group), [groupe existant](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/data-sources/resource_group).
- [Tests Terraform simulés](https://developer.hashicorp.com/terraform/language/tests/mocking), [état](https://developer.hashicorp.com/terraform/language/state).
- [Pratique MCP](PRACTICE.md), [gouvernance](LEARNING-GUIDE.md), [références](REFERENCES.md).

Dernière vérification : 2026-10-14. Les contrôles locaux/simulés ne valident ni construction de conteneur ni déploiement Azure.

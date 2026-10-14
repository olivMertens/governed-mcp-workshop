# Choisir votre environnement dès le départ

Utilisez **Visual Studio Code (VS Code)** en dev container, ou votre terminal local.
Les deux chemins utilisent les mêmes scripts, paramètres privés et racine Terraform.
Visual Studio IDE est un autre produit : les instructions conteneur concernent l'extension Dev Containers de VS Code.
Ni Copilot ni le canvas ne sont requis pour lire les guides Markdown et exécuter les scripts.

## 1. Choisir un chemin

| Chemin | Prérequis | Démarrage |
|---|---|---|
| VS Code en dev container | VS Code, extension Dev Containers, moteur de conteneurs Linux approuvé et accessible, accès aux paquets publics | Ouvrir la copie locale avec `code .`, puis **Dev Containers: Reopen in Container**. |
| Terminal local | Git, PowerShell 7.4+, Azure CLI, Terraform, SDK .NET, Node.js, Functions Core Tools | Garder la copie locale. Installer les outils selon les règles de votre organisation. |
| Codespaces, facultatif | Accès GitHub, quota et coûts approuvés | [Choisir branche et machine](https://codespaces.new/olivMertens/workshop-mcp). La même `.devcontainer` est utilisée après publication des fichiers. |

Le conteneur monte la copie du dépôt. Il ne monte pas explicitement votre dossier d'identifiants Azure ni le socket
du moteur, ne vous connecte pas à Azure et ne déploie rien. Vérifiez les scripts des Features et le partage Git de
VS Code avant d'approuver le dépôt. Le moteur est lui-même une frontière de confiance privilégiée.
Gardez les ports Inspector privés, via VS Code desktop et un transfert privé, jamais public.

### Dans le dev container

L'image Ubuntu 24.04 et les Features officielles sont fixées par empreinte dans `.devcontainer/devcontainer.json`.
Versions choisies : Azure CLI 2.88.0, Terraform 1.16.5, SDK .NET 10.0.402, PowerShell 7.6.6,
Node.js 22.22.0 et Functions Core Tools 4.14.0. Le script de création installe Core Tools puis lance
le **même** `check-tools.ps1` que le chemin local. Les dépendances téléchargées et extensions éditeur peuvent
évoluer : ces empreintes ne figent pas tous les dépôts de paquets. Révisez les versions délibérément.

Docker doit répondre à `docker version` et `docker info`, pas seulement être installé.
Pour Podman 5+, suivez [la procédure VS Code](https://code.visualstudio.com/remote/advancedcontainers/docker-options) :
vérifiez `podman version`, `podman info` et, sur Windows/macOS, `podman machine list`, puis réglez
**Dev Containers: Docker Path** sur `podman`. Ne créez pas une nouvelle machine et n'exposez pas de socket TCP
comme contournement. VS Code ne supporte pas officiellement tous les clients compatibles Docker.
Cette configuration n'utilise ni Compose ni conteneurs imbriqués.

**Limite de vérification :** configuration et empreintes publiques vérifiées, mais aucun moteur accessible sur le
poste de création. La construction, les deux architectures Linux et l'exécution Codespaces restent à vérifier
au jalon du module 00. Un fichier présent ne prouve pas que votre moteur ou votre proxy fonctionne.
En cas d'échec : **Dev Containers: Show Container Log**. Corrigez l'erreur réelle de registre, proxy ou plateforme ;
ne désactivez pas les certificats et ne changez pas silencieusement de moteur. Le chemin local reste possible si approuvé.

### Dans le terminal local

Installez les versions compatibles avec votre système depuis les sources officielles :

| Outil | Contrôle commun | Source |
|---|---|---|
| Git | 2+ | [Téléchargements Git](https://git-scm.com/downloads) |
| PowerShell | 7.4+ | [Installation](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Azure CLI | 2.88.0+ | [Installation](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Terraform | 1.16.5+, inférieur à 2 | [Installation](https://developer.hashicorp.com/terraform/install) |
| SDK .NET | 10 installé | [Téléchargement .NET](https://dotnet.microsoft.com/download/dotnet/10.0) |
| Node.js | 22.19.0+ | [Téléchargement](https://nodejs.org/en/download) |
| Functions Core Tools | 4.5.0+, inférieur à 5 | [Installation officielle](https://learn.microsoft.com/azure/azure-functions/functions-run-local) |

Choisissez Core Tools v4, pas la CLI Functions v5 distincte en **Preview**.
Certains lanceurs npm téléchargent le binaire au premier appel. Laissez finir ce téléchargement approuvé ;
un paquet listé ne prouve pas que son binaire fonctionne. Aucun script ne modifie automatiquement votre poste ou moteur.

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

## 3. Préparer des noms privés et isolés

Lisez le script. Choisissez préfixe participant, région approuvée, étiquette propriétaire non sensible et date courte
de nettoyage. Les exemples suivants utilisent des étiquettes synthétiques, pas un compte ou une région imposés.

```powershell
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry $expiry
```

```bash
read -r -p 'Date de nettoyage approuvée (yyyy-MM-dd) : ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry "$expiry"
```

Le fichier `.workshop/participant.tfvars.json`, ignoré par Git, conserve un suffixe aléatoire cryptographique
de dix caractères hexadécimaux. Le script ne contacte pas Azure. Le même appel réutilise le fichier sans changement ;
des paramètres différents provoquent un arrêt. Conservez ce fichier et l'état Terraform jusqu'au nettoyage.
La date est une étiquette, **pas une suppression automatique**.

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

> [!WARNING]
> Changer de nom ou de groupe ne remet pas à zéro les quotas d'abonnement, de région ou de service.
> Vérifiez capacité partagée, règles de l'organisation, disponibilité des noms et coûts API Management séparément.
> En cas de nom refusé, enquêtez avant le premier apply. Ne renommez pas à la légère un groupe déjà déployé.

## 4. Comprendre le périmètre Terraform

`infra/workload` contient pour l'instant **seulement le socle groupe de ressources** et les futurs noms.
Il ne déploie ni Functions, réseau, API Management, identité ni serveur MCP.
Les procédures complètes et validations Azure des modules restent à publier.

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

Plan peut lire Azure. Le board n'exécute aucune commande. Pas d'apply avant approbation du plan exact,
des permissions, du quota et des coûts. Pas de `-auto-approve`. L'enregistrement automatique des fournisseurs
est désactivé : un administrateur enregistre séparément ceux requis. Les attributions de rôles et Entra sont distincts.
Jamais de rôle Owner global, secret client ou abonnement de production comme contournement.

Gardez une seule copie et un seul état pour le déploiement. Le conteneur monté et le poste partagent les fichiers ;
un autre clone ou codespace a un autre état local. N'y redéployez pas : restaurez paramètres et état de façon privée
ou configurez d'abord un backend distant approuvé et isolé. Ne publiez ni état, plan, paramètres ou identifiants CLI.

Continuez le module 00 puis l'exercice MCP local du module 01, avec leurs jalons de publication et validation.
Après les étapes payantes, suivez le module 99. Examinez destroy contre le même état ; préservez groupes et identités
existants. Ne supprimez pas un groupe entier pour contourner un nettoyage incomplet.

## Sources

- [Dev Containers VS Code](https://code.visualstudio.com/docs/devcontainers/containers), [moteurs alternatifs](https://code.visualstudio.com/remote/advancedcontainers/docker-options).
- [Features officielles](https://github.com/devcontainers/features), [spécification](https://containers.dev/implementors/json_reference/).
- [Nommage Azure](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules), [quotas](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).
- [Groupe géré AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group), [groupe existant](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/data-sources/resource_group).
- [Tests Terraform simulés](https://developer.hashicorp.com/terraform/language/tests/mocking), [état](https://developer.hashicorp.com/terraform/language/state).
- [Pratique MCP](PRACTICE.md), [gouvernance](LEARNING-GUIDE.md), [références](REFERENCES.md).

Dernière vérification : 2026-10-14. Les contrôles locaux/simulés ne valident ni construction de conteneur ni déploiement Azure.

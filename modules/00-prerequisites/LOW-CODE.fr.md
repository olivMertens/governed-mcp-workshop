# 00 - Préparer l'environnement low-code

[English](LOW-CODE.md)

## Objectif

Vous allez préparer votre terminal, puis vérifier le contexte et les droits de votre abonnement Azure hors production
pour le **parcours low-code, centré sur le portail**. Vous enregistrerez aussi les noms à réutiliser dans la suite de l'atelier.
Vous n'avez pas besoin de Terraform. Le module 01 est commun aux deux parcours ; à partir du module 02, suivez les guides low-code.

## Pourquoi c'est important

Le portail et le terminal doivent utiliser le même annuaire et le même abonnement.
Une connexion réussie ne prouve pas que vous pouvez créer des ressources.
Les contrôles lisent votre environnement ; ils ne donnent aucun droit et ne déploient rien.

> [!IMPORTANT]
> Obtenez l'accord pour votre propre annuaire et abonnement **hors production** avant de continuer.
> N'utilisez pas l'environnement d'un autre participant. Ne mettez aucun jeton, mot de passe ou renseignement sur votre compte dans le dépôt ou la conversation.

## Ce que vous déployez

Rien. Un fichier local, ignoré par Git, conserve les noms et étiquettes des modules suivants.
Il s'appelle `.workshop/participant.tfvars.json` pour rester compatible avec le script de préparation commun.
Les guides low-code lisent directement ce fichier JSON, sans utiliser Terraform.

## Prérequis et droits nécessaires

- Votre propre copie du dépôt. Si nécessaire, commencez par les instructions de clonage du
  [guide de démarrage](../../docs/fr/GETTING-STARTED.md#0-récupérer-le-dépôt-sur-votre-poste).
- Git 2+, PowerShell 7.4+, Azure CLI 2.88.0+, le kit de développement (SDK) .NET 10,
  Node.js 22.19.0+ et Azure Functions Core Tools v4, version 4.5.0 ou ultérieure, inférieure à 5.
  Le nouvel outil de ligne de commande (CLI) Functions v5 est en **Preview** (préversion) ; ne l'utilisez pas ici.
- Un compte et un abonnement autorisés. Créer ou supprimer un nouveau groupe de ressources demande
  les droits correspondants sur l'abonnement. Le rôle Contributeur sur un groupe ne permet pas d'en créer un autre.
  Préférez un groupe fourni par l'administrateur plutôt que des droits plus larges.
- Aucun rôle d'administration Microsoft Entra pour ces contrôles. Le module 03 distingue les actions de l'administrateur.

Sous Windows, installez seulement les outils manquants, selon les règles de votre organisation :

| Outil | Installation |
|---|---|
| Git | `winget install --id Git.Git --exact` |
| PowerShell 7 | `winget install --id Microsoft.PowerShell --exact` |
| Azure CLI | `winget install --id Microsoft.AzureCLI --exact` |
| SDK .NET 10 | `winget install --id Microsoft.DotNet.SDK.10 --exact` |
| Node.js | `winget install --id OpenJS.NodeJS.LTS --exact` |
| Functions Core Tools v4 | L'[installateur officiel](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools) correspondant à votre poste |

Fermez puis rouvrez PowerShell 7 après l'installation. Les versions proposées par WinGet évoluent :
le contrôle suivant vérifie les versions acceptées. Ne contournez pas les restrictions de votre poste.
Le conteneur facultatif contient aussi des outils supplémentaires ; il n'est pas obligatoire pour ce parcours.

## Étapes

### 1. Ouvrir le bon terminal

Dans Visual Studio Code, ouvrez votre copie du dépôt, puis **Terminal > Nouveau terminal**
et choisissez **PowerShell 7**. Placez-vous à la racine du dépôt, où se trouvent `README.md`, `modules` et `scripts`.
N'utilisez pas Azure Cloud Shell pour ces commandes : la publication utilisera ensuite votre copie locale.

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\check-tools.ps1 -Track low-code
```

> **Résultat attendu** — une ligne `PASS` par outil requis, puis
> `PASS local tools only; Azure context, permissions, quota and deployment remain separate checks.`
> Aucun contrôle Terraform n'est lancé. Arrêtez-vous au premier `FAIL` et corrigez l'outil concerné.

### 2. Enregistrer vos noms de participant une seule fois

Choisissez le préfixe attribué, la région approuvée, un libellé de propriétaire sans donnée sensible et la date de nettoyage.
Les valeurs suivantes sont des exemples : remplacez-les par les choix approuvés pour votre atelier.
La date d'expiration est un rappel ; elle ne supprime rien.

```powershell
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry $expiry
```

> **Résultat attendu** — `PASS private participant parameters created with a stable random suffix.`
> Avec les mêmes paramètres, une relance affiche `PASS existing participant parameters reused unchanged.`
> Le script ne crée aucune ressource Azure.

Si l'administrateur fournit un groupe de ressources, ajoutez `-ExistingResourceGroupName` avec son nom exact
au **premier** appel du script. Ne changez plus les noms dans le fichier après un déploiement.

Conservez le dossier `.workshop` uniquement dans votre copie privée du dépôt. Ne reprenez pas le fichier d'un autre participant.
Les nouvelles ressources low-code ajoutent `lc` au préfixe ; un groupe fourni conserve son nom.
Les guides suivants reconstruisent ces noms depuis le fichier, même si vous avez fermé le terminal.

### 3. Se connecter et vérifier l'abonnement

Gardez ce terminal. Préparez les identifiants approuvés de l'annuaire, aussi appelé tenant, et de l'abonnement.
Ils se trouvent dans **Portail Azure > Abonnements > votre abonnement > Vue d'ensemble**.
Saisissez vos propres identifiants localement, jamais ceux d'une capture.

```powershell
& .\scripts\select-azure-context.ps1 -Language fr
& .\modules\00-prerequisites\validate.ps1 -Track low-code `
    -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

> **Résultat attendu** — le sélecteur demande votre cible approuvée et la confirmation `NONPROD`,
> ouvre la connexion interactive, puis affiche `PASS contexte : tenant et abonnement vérifiés. ...`.
> Le validateur affiche `PASS` pour les outils, le contexte, la région, le fournisseur, les droits requis et la capacité,
> puis `PASS module 00 foundation environment checks. ...`. Les lectures attendent HTTP 200 ; les contrôles locaux indiquent `N/A`.

Dans le portail, ouvrez le menu du compte en haut à droite et choisissez **Changer d'annuaire** si nécessaire.
Ouvrez **Abonnements**, sélectionnez le vôtre et comparez son identifiant à la valeur privée approuvée.
Ne poursuivez pas si le portail et le terminal pointent vers des cibles différentes.

> [!WARNING]
> Un `PASS` n'autorise pas un déploiement. Des stratégies, refus explicites ou quotas partagés peuvent encore le bloquer.
> Demandez à l'administrateur d'examiner le refus précis ; ne désactivez pas le contrôle.

### 4. Préparer la demande à l'administrateur des identités

Ouvrez la [demande d'identité](../../docs/requests/identity-request.md), en anglais.
Transmettez-la par le canal privé approuvé avant le module 03.
Faites confirmer l'inscription de l'API, les identités de test Alice/Bob/Eve, leurs rôles et les consentements nécessaires.
N'utilisez pas les données de véritables utilisateurs et ne demandez pas un rôle d'administration de tout l'annuaire.

### Avec bash

PowerShell doit aussi être installé : les scripts bash appellent les mêmes contrôles PowerShell. Depuis la même copie du dépôt :

```bash
bash ./scripts/check-tools.sh -Track low-code
read -r -p 'Date de nettoyage approuvée (yyyy-MM-dd) : ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry "$expiry"
source ./scripts/select-azure-context.sh fr
bash ./modules/00-prerequisites/validate.sh -Track low-code -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
```

> **Résultat attendu** — les mêmes lignes `PASS` pour les outils et l'environnement, sans Terraform.
> `source` conserve les variables du contexte dans ce terminal.

## Résultat attendu

Si la préparation a réussi, tous les contrôles affichent `PASS`. Ce module ne crée aucune nouvelle ressource dans **Groupes de ressources**.
Votre fichier privé existe et le portail comme le terminal pointent vers la cible approuvée.
Une liste de ressources vide ne prouve pas que le nettoyage des modules suivants a réussi.

**Question :** tous les contrôles réussissent. Pouvez-vous déployer sans demander d'accord ?

<details>
<summary>Afficher la réponse</summary>

Non. Les contrôles lisent le contexte et les droits. L'accord, la capacité et les stratégies se vérifient séparément.

</details>

### Vérifier vous-même avec Azure CLI

**Pourquoi :** le portail et le terminal doivent viser le même abonnement de test.
Dans PowerShell 7, copiez cette commande en lecture seule :

```powershell
az account show --query '{name:name,state:state,cloud:environmentName,isDefault:isDefault}' -o json
if ($LASTEXITCODE -ne 0) { throw 'Impossible de lire le contexte Azure. Arrêtez-vous ici.' }
```

> **Résultat attendu** — le nom de votre abonnement approuvé, `state: Enabled` et `isDefault: true`.
> `AzureCloud` désigne le cloud public. Cela confirme le contexte, pas vos droits de création :
> le validateur vérifie ces derniers séparément.

![Résultat réel de la commande de contexte Azure CLI ; le cadre marque le cloud, l'abonnement actif et son état](../../assets/screenshots/terminal-00-az-context.png)

*Capture en lecture seule du 20 octobre 2026 ; le nom est masqué.
Si le portail et le terminal ne visent pas la même cible, reprenez la sélection du contexte.*

## Valider

Utilisez la commande complète de validation du module 00 à l'étape 3.
Gardez `-Track low-code` : le comportement par défaut contrôle les outils du parcours infrastructure en code.
Arrêtez-vous en cas d'échec. Quand tout réussit et que la demande à l'administrateur est prête,
ouvrez le [module 01](../01-discover-mcp/README.fr.md), puis le [module 02 low-code](../02-open-server/LOW-CODE.fr.md).

> **Note de validation :** ce guide low-code n'a pas encore été suivi de bout en bout en conditions réelles.
> Les contrôles exécutés sur le poste de l'auteur ne valident pas le conteneur ni Codespaces.
> Si vous utilisez l'un de ces environnements facultatifs, exécutez les contrôles à l'intérieur.

## Dépannage

- **Mauvais terminal :** ouvrez PowerShell 7, pas Windows PowerShell 5.1, puis revenez à la racine du dépôt.
- **Mauvaise cible ou authentifications mélangées :** utilisez un terminal de connexion utilisateur interactive approuvé.
  Le validateur refuse les paramètres d'authentification contradictoires.
- **Fournisseur absent :** demandez à l'administrateur de vérifier l'enregistrement du fournisseur indiqué dans l'erreur.
  Le contrôle ne l'enregistre pas.
- **Droit refusé :** identifiez l'action et sa portée. Préférez le groupe approuvé à des droits plus larges.
- **Paquet Core Tools sans exécutable :** terminez l'installation approuvée. Le contrôle ne déclenche aucun téléchargement initial.
- **Conteneur/Codespaces :** lancez les contrôles dans cet environnement. Un test sur le poste ne valide pas le conteneur.
  Leur validation en conditions réelles reste à effectuer, comme l'indique la note de validation.

## Nettoyer

Ce module ne crée aucune ressource cloud. Conservez le fichier privé pour les modules suivants et le nettoyage.
Si vous vous arrêtez après un déploiement, même partiel, suivez le [module 99 low-code](../99-cleanup/LOW-CODE.fr.md).
Ne supprimez jamais un groupe partagé.

## Pour aller plus loin

Lisez les [concepts MCP](../../docs/fr/MCP-CONCEPTS.md) avant votre premier appel.
La [page des parcours](../../docs/fr/TRACKS.md) donne les liens des guides low-code dans l'ordre.

## Sources

- [Lire le contexte avec Azure CLI](https://learn.microsoft.com/cli/azure/account#az-account-show), vérifié le 20 octobre 2026.

- [Installer Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
- [Installer PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
- [.NET 10](https://dotnet.microsoft.com/download/dotnet/10.0).
- [Outils locaux Functions](https://learn.microsoft.com/azure/azure-functions/functions-run-local).
- [API des droits sur un groupe](https://learn.microsoft.com/rest/api/authorization/permissions/list-for-resource-group).
- [Limites d'abonnement](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).

Dernière vérification des sources : 2026-10-14 (sources communes au module 00).
La validation de bout en bout de ce guide low-code reste à effectuer.

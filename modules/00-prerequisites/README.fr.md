# 00 - Préparer votre environnement de test

[English](README.md)

## Objectif

Choisir où travailler, vérifier les outils et confirmer que vous pouvez utiliser votre environnement Azure de test.
Vous préparerez aussi les informations à transmettre à l'administrateur Microsoft Entra.

## Pourquoi cette étape est importante

Un outil installé ne garantit pas que vous ayez les droits ou la capacité nécessaires dans Azure.
Les noms propres à chaque participant limitent les conflits, mais n'augmentent pas les quotas disponibles.

Consultez les [schémas étape par étape](../../assets/architecture/STEPS.fr.md) et
[ce qui est réellement disponible](../../docs/fr/IMPLEMENTATION-STATUS.md).
Un schéma explique l'objectif ; il ne prouve pas que des identités ou des ressources ont été déployées.

## Ce que vous déployez

**Les scripts de vérification ne créent aucune ressource.** Ils consultent votre configuration et vos droits.
Terraform permet, séparément et après approbation, de créer un groupe de ressources dédié ou d'utiliser
un groupe fourni par l'administrateur. Le [portail public facultatif](../../docs/fr/HOSTING.md) est payant
et désactivé par défaut. Aucun serveur Model Context Protocol (MCP) n'est encore déployé.

## Prérequis et droits nécessaires

Commencez par [choisir votre environnement de travail](../../docs/fr/GETTING-STARTED.md).

**Raccourci facultatif :** le [Microsoft Foundry Dev Pack](https://devblogs.microsoft.com/foundry/foundry-devpack-announcement/),
en anglais, peut installer en une seule fois Azure CLI, Azure Developer CLI (`azd`) et l'extension Foundry
(Windows : `winget install Microsoft.FoundryDevPack`). Il n'installe **pas** Terraform, le SDK .NET, Node.js,
PowerShell ni Functions Core Tools : gardez donc les outils de la liste de référence. Lancez ensuite `scripts/check-tools.ps1`, qui doit toujours afficher Azure CLI 2.88.0 ou une version plus récente. Sinon, installez Azure CLI de la façon habituelle.
Utilisez uniquement un annuaire Microsoft Entra et un abonnement Azure autorisés pour des tests hors production.
L'annuaire contient les identités ; l'abonnement contient les ressources facturées.

Si votre administrateur vous fournit un groupe de ressources, utilisez-le. Ne demandez pas le rôle
Propriétaire (Owner) sur tout l'abonnement pour simplifier l'exercice.
Aucun droit d'administration Entra n'est nécessaire à cette étape. La
[demande destinée à l'administrateur](../../docs/requests/identity-request.md), en anglais,
prépare les besoins du module 03.

## Étapes

### PowerShell

Depuis le dossier principal du dépôt, dans le terminal que vous utiliserez pour l'atelier :

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\check-tools.ps1
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry $expiry
& .\scripts\select-azure-context.ps1 -Language fr
& .\modules\00-prerequisites\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

Adaptez `p01`, la région, le libellé du propriétaire et la date aux choix approuvés pour votre atelier.
La date sert de rappel : elle ne déclenche pas de suppression automatique.
Pour un groupe existant, ajoutez `-ExistingResourceGroupName` avec son nom dès le premier appel à
`prepare-workshop.ps1`. Conservez le fichier de paramètres privé et l'état Terraform jusqu'au nettoyage.

Le sélecteur vous demande les identifiants de l'annuaire et de l'abonnement, puis la confirmation `NONPROD`.
Il lance la connexion à Azure et sélectionne l'abonnement. **Gardez le même terminal pour la suite.**
Ne copiez aucune clé, aucun jeton ni aucune information de compte dans le tableau, le dépôt ou la conversation.

<details>
<summary>Vous utilisez bash ?</summary>

PowerShell doit aussi être installé : les scripts bash appellent les mêmes contrôles.

```bash
bash ./scripts/check-tools.sh
read -r -p 'Date de nettoyage approuvée (yyyy-MM-dd) : ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location swedencentral -Owner alice -Expiry "$expiry"
source ./scripts/select-azure-context.sh fr
bash ./modules/00-prerequisites/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
```

</details>

## Résultat attendu

Chaque contrôle réussi affiche `PASS`. En cas d'erreur, corrigez le problème avant de poursuivre.
Les lectures Azure doivent renvoyer un code HTTP 200 ; les contrôles locaux indiquent `N/A`, car ils ne font pas
de requête réseau. Le script n'enregistre aucun fournisseur de ressources et n'attribue aucun rôle.

Le conteneur et Codespaces n'ont pas encore été testés en conditions réelles sur le poste de préparation.
Si vous utilisez l'un de ces environnements, les contrôles doivent y réussir : un test sur votre poste ne suffit pas.

## Vérifier avant de poursuivre

Exécutez `validate.ps1` ou `validate.sh` dans l'abonnement de test approuvé.
Notez la date, le type d'environnement et les lignes `PASS` non sensibles dans `docs/PROGRESS.md`.
Vérifiez aussi que la demande Entra est comprise et pourra être transmise en privé à l'administrateur.
Ne commencez le module 01 qu'une fois cette validation réelle réussie.

## En cas de problème

- **Mauvais abonnement :** relancez le sélecteur dans le terminal utilisé pour l'atelier.
- **Droits manquants :** demandez à l'administrateur de vérifier l'action refusée sur le groupe concerné.
- **Fournisseur non enregistré :** faites examiner son enregistrement par l'administrateur ; le script ne le fera pas.
- **Quota insuffisant :** vérifiez la capacité partagée. Changer les noms des ressources ne résout pas le problème.
- **Functions Core Tools ne démarre pas :** terminez son installation selon la procédure approuvée.
- **Blocage par Azure Policy :** examinez la règle avec l'administrateur ; ne la désactivez pas.

## Nettoyer

```powershell
& .\modules\00-prerequisites\cleanup.ps1
```

Avec bash : `bash ./modules/00-prerequisites/cleanup.sh`.
Les vérifications n'ont rien créé. Ce script conserve vos paramètres privés et votre état Terraform.
Si vous avez déployé le groupe ou le portail, suivez la
[procédure de suppression à faire approuver](../../docs/fr/HOSTING.md#nettoyer).
Arrêter le site n'arrête pas la facturation de son plan. Ne supprimez jamais un groupe partagé.

## Pour aller plus loin

<details>
<summary>Versions des outils, droits vérifiés et limites du contrôle</summary>

Versions retenues : Terraform 1.16.6, fournisseur AzureRM 5.9.0, Azure CLI 2.88.0, kit de développement .NET 10,
PowerShell 7.4+, Node.js 22.19+ et Functions Core Tools v4 >= 4.5.0.
La CLI Functions v5, distincte, est en **Preview** (préversion) et n'est pas utilisée.

Créer un groupe demande des droits de lecture, de création et de suppression au niveau de l'abonnement.
Un groupe existant évite de demander ces droits, mais nécessite toujours les autorisations prévues sur ce groupe.
Le script examine les actions autorisées par Azure Resource Manager (ARM), déduit les exclusions de chaque
ensemble de permissions, puis combine les ensembles. Les pages de résultats doivent rester sur le même
serveur HTTPS et dans le même périmètre. Les refus explicites et les règles Azure Policy peuvent encore
empêcher un déploiement, même si ces contrôles réussissent.

Le mode « nouveau groupe » vérifie aussi la limite de 980 groupes par abonnement.
Cette vérification n'est pas nécessaire si vous utilisez un groupe existant.
Le script de vérification ne vous connecte pas et ne change pas l'abonnement sélectionné.

</details>

<details>
<summary>Tester les scripts localement, sans valider un déploiement Azure</summary>

```powershell
terraform -chdir=infra/workload init -backend=false -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Provider initialization failed.' }
& .\modules\00-prerequisites\validate.ps1 -Offline
```

```bash
terraform -chdir=infra/workload init -backend=false -lockfile=readonly &&
bash ./modules/00-prerequisites/validate.sh -Offline
```

Ces tests utilisent des réponses fictives et des fournisseurs Terraform simulés.
Leur réussite ne valide **ni votre abonnement Azure ni le conteneur**.

</details>

<details>
<summary>Préparer une étape payante ultérieure</summary>

Les options `-Stage portal` et `-Stage mcp` demandent une vérification privée de capacité et de coût,
fournie avec `-CapacityReviewPath`. Consultez le [guide d'hébergement](../../docs/fr/HOSTING.md).
Le mode `mcp` prépare les besoins futurs : il ne valide pas les services qui restent à construire.
Il vérifie aussi la possibilité d'attribuer des rôles. Faites réaliser ces attributions séparément par
l'administrateur plutôt que d'élargir les droits de tous les participants.

</details>

Consultez aussi les [explications sur la sécurité](../../docs/fr/LEARNING-GUIDE.md) et le
[schéma de cette étape](../../assets/architecture/00.fr.svg).

## Sources

- [Installation Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
- [Terraform sur Azure](https://learn.microsoft.com/azure/developer/terraform/overview).
- [Installation PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
- [.NET 10](https://dotnet.microsoft.com/download/dotnet/10.0).
- [Outils Functions](https://learn.microsoft.com/azure/azure-functions/functions-run-local).
- [API des autorisations](https://learn.microsoft.com/rest/api/authorization/permissions/list-for-resource-group).
- [Limites Azure](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).
- [Capacité et versions d'exécution Flex](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan).
- [Conteneurs VS Code](https://code.visualstudio.com/docs/devcontainers/containers).
- [Versions et sources retenues](../../docs/sources.md).

Dernière vérification : 2026-10-14. Les tests locaux ne remplacent pas la validation dans Azure et dans le conteneur.

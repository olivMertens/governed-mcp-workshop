# Examiner votre environnement low-code

[English](../LOW-CODE-DEPLOYMENT.md)

## 1. Vérifier le contexte du terminal et du portail

Utilisez PowerShell 7 à la racine de votre copie d'origine du dépôt.
Ces commandes consultent votre environnement et vos ressources ; elles ne déploient rien,
ne changent pas d'abonnement et n'appellent aucun outil MCP.
Si vous avez rouvert le terminal, commencez par le sélecteur :

```powershell
& .\scripts\select-azure-context.ps1 -Language fr
```

> **Résultat attendu** — après la saisie des identifiants approuvés et la confirmation `NONPROD`,
> la connexion interactive aboutit et le sélecteur affiche `PASS contexte : tenant et abonnement vérifiés. ...`.

Dans le [portail Azure](https://portal.azure.com/), choisissez le même annuaire depuis le menu du compte en haut à droite.
Ouvrez **Abonnements > votre abonnement > Vue d'ensemble** et comparez son identifiant à votre valeur privée approuvée.
Ne collez ni les identifiants ni les résultats de compte dans le site ou la conversation.

## 2. Retrouver votre groupe et votre étiquette

Le fichier privé détermine vos noms, même après la fermeture du terminal.
Un groupe fourni par l'administrateur conserve son nom.

```powershell
$ErrorActionPreference = 'Stop'
. .\scripts\context-common.ps1
Assert-WorkshopAzureContext -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
$p = Read-WorkshopParameters -Path .\.workshop\participant.tfvars.json
$prefix = "$($p.participant_prefix)lc"
$workshopTag = "mcp-$prefix-$($p.resource_suffix)"
$resourceGroup = if ($p.existing_resource_group_name) { $p.existing_resource_group_name } else { "rg-$workshopTag" }
$resourceGroup
$workshopTag
```

> **Résultat attendu** — votre nom de groupe et votre étiquette de participant. Rien n'est créé.
> Le script s'arrête si le fichier manque ou si le contexte diffère.
> Ne recréez pas des paramètres pour un déploiement existant.

Dans le portail, ouvrez **Groupes de ressources > le groupe affiché > Vue d'ensemble**.
Vérifiez l'abonnement, les **Étiquettes** et la valeur `workshop`.
Les étiquettes d'un groupe partagé peuvent appartenir à l'administrateur :
vérifiez alors celles de **vos ressources dans le groupe**.

## 3. Lister uniquement vos ressources

Gardez ce terminal : les variables viennent de l'étape 2.

```powershell
Assert-WorkshopAzureContext -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
az resource list --subscription $env:ARM_SUBSCRIPTION_ID --resource-group $resourceGroup `
    --query "[?tags.workshop=='$workshopTag'].{Name:name,Type:type,Location:location}" --output table --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Resource inspection failed. Check the target and scoped read permissions.' }
```

> **Résultat attendu** — un tableau contenant les ressources qui portent votre étiquette dans ce groupe.
> Aucun jeton ni contenu de message n'est lu. Une erreur n'est pas un résultat vide réussi.

Ne retirez ni le groupe ni le filtre d'étiquette pour obtenir davantage de résultats.
Un tableau vide ne prouve **pas** que tout a été nettoyé :
les objets Microsoft Entra, les services supprimés provisoirement et les groupes Foundry facultatifs sont distincts.
Le [module 99 low-code](../../modules/99-cleanup/LOW-CODE.fr.md) permet de les vérifier.

## 4. Vérifier séparément l'identité et les appels

Dans le [centre d'administration Microsoft Entra](https://entra.microsoft.com/), sélectionnez le même annuaire.
Ouvrez **Identité > Applications > Inscriptions d'applications**, puis l'API identifiée dans vos paramètres privés du module 03.
Dans **Rôles d'application**, vérifiez `Tools.Read` et `Tools.Write`.
Dans **Applications d'entreprise**, vérifiez les attributions d'Alice et Bob ; Eve doit rester sans attribution.
L'existence de l'application ne prouve ni l'authentification, ni les autorisations, ni l'approbation du client.
Lancez la commande complète de validation du guide low-code du module que vous venez de déployer.

## Sources

- [Azure CLI resource list](https://learn.microsoft.com/cli/azure/resource#az-resource-list).
- [Annuaire et abonnement dans le portail](https://learn.microsoft.com/azure/azure-portal/set-preferences).
- [Sources du module 00](../../modules/00-prerequisites/LOW-CODE.fr.md#sources).

Dernière vérification : 2026-10-20 pour la commande de liste et les réglages d'annuaire du portail.
Aucun nouveau déploiement en conditions réelles n'est revendiqué.

# Votre environnement Terraform : annuaire et abonnement

Utilisez uniquement un environnement de test **approuvé et hors production**.
Cette page vous aide à le sélectionner ; elle ne déploie rien et ne garantit pas vos droits.
Si ce n'est pas déjà fait, [choisissez votre environnement de travail](GETTING-STARTED.md).
Les commandes d'inspection de cette page lisent les sorties Terraform.
Pour les ressources créées dans le portail, utilisez le [guide d'inspection low-code séparé](LOW-CODE-DEPLOYMENT.md).

Trois notions suffisent pour commencer :

- **L'annuaire Microsoft Entra**, aussi appelé tenant, contient les utilisateurs et les applications.
- **L'abonnement Azure** contient les ressources et porte les frais.
- **Le groupe de ressources** rassemble les ressources de votre déploiement.

Ces trois périmètres n'ont pas forcément le même administrateur. Gardez leurs identifiants dans votre
terminal privé, jamais dans ce tableau ou dans le dépôt.

## 1. Confirmer les choix avec l'administrateur

Vérifiez l'annuaire, l'abonnement, le groupe, la région et le budget autorisés.
Choisissez aussi une date de nettoyage et un libellé de propriétaire sans information personnelle.
N'utilisez pas de données de production ni la session d'une autre personne.

<details>
<summary>Pour aller plus loin : qui approuve quoi ?</summary>

| Besoin | À faire approuver |
|---|---|
| Déployer les ressources | Les opérations nécessaires sur le groupe de l'atelier |
| Configurer les identités | Les applications, rôles applicatifs, comptes de test et consentements Microsoft Entra |
| Attribuer des droits sur les ressources | Les attributions de rôles, limitées au périmètre nécessaire |
| Connecter VS Code ou Inspector | Les paramètres de chaque application cliente ; l'accord pour l'une ne couvre pas l'autre |
| Utiliser des objets existants | Leur périmètre d'utilisation, sans les modifier ni les supprimer |

Le rôle Contributeur (Contributor) ne permet pas d'attribuer des rôles.
Un rôle Azure ne donne pas de droit d'administration Entra.
Ne demandez pas le rôle Propriétaire (Owner) sur l'abonnement pour contourner ces limites.

</details>

## 2. Sélectionner l'environnement dans votre terminal

Lisez le script, puis lancez-le depuis la racine du dépôt :

```powershell
& .\scripts\select-azure-context.ps1 -Language fr
```

Il ouvre la page de connexion Azure dans le navigateur, sélectionne l'abonnement demandé et vérifie le contexte.
Suivez les règles d'authentification multifacteur de votre organisation.
Le script ne crée aucune ressource et n'attribue aucun rôle.

**Gardez ce même terminal pour la suite du parcours Terraform.** Lancez le script avec `&`, pas dans un nouveau processus
`pwsh -File` : les paramètres de contexte doivent rester disponibles pour la suite.
Si le script échoue, arrêtez-vous. Ne poursuivez pas avec l'abonnement sélectionné auparavant.

<details>
<summary>Vous utilisez bash ?</summary>

```bash
source ./scripts/select-azure-context.sh fr
```

Utilisez bien `source`, pas `bash script.sh`, pour conserver les variables dans le terminal courant.
Les contrôles sont les mêmes qu'avec PowerShell.

</details>

<details>
<summary>Pour aller plus loin : fonctionnement du sélecteur de contexte</summary>

Le script utilise `az login --tenant`, `az account set --subscription` et `az account show`.
Il définit `ARM_TENANT_ID` et `ARM_SUBSCRIPTION_ID` dans le processus courant uniquement.
Il refuse les paramètres d'authentification incompatibles au lieu de les ignorer.
La confirmation demandée atteste votre accord ; elle ne détecte pas automatiquement un environnement de production.

Ces scripts ciblent le cloud public Azure. Un cloud souverain nécessite une configuration distincte, à examiner
avant utilisation. Ne collez jamais la sortie de `az account get-access-token` dans cette page.

</details>

## Voir les ressources depuis votre terminal

Chaque bloc de code de l'application propose **Copier le code**. La copie n'exécute rien.
Relisez le bloc, remplacez les valeurs entre chevrons, puis collez-le dans votre terminal PowerShell 7,
à la racine du dépôt. Utilisez le même terminal que pour le sélecteur de contexte ci-dessus.
Les résultats s'affichent dans ce terminal, pas dans l'application partagée.

Après un déploiement approuvé, utilisez ces commandes en **lecture seule**.
Elles vérifient l'annuaire et l'abonnement sélectionnés, lisent uniquement le nom du groupe et les tags
dans votre état Terraform local, puis listent les ressources portant votre tag.
Elles n'ouvrent aucune session, ne changent pas d'abonnement, ne déploient rien et n'appellent aucun outil MCP.

### Observer 1. Vérifier le contexte avant les ressources

**Pourquoi :** le nom d'un groupe ne suffit pas à identifier l'abonnement approuvé.
**Prévoyez :** le contexte Azure actif doit correspondre aux variables du sélecteur.
Exécutez ce bloc dans le même terminal, après un déploiement approuvé :

```powershell
$ErrorActionPreference = 'Stop'
if (-not $env:ARM_TENANT_ID -or -not $env:ARM_SUBSCRIPTION_ID) {
    throw 'Run the workshop context selector in this terminal first.'
}
$inspectionTenant = $env:ARM_TENANT_ID
$inspectionSubscription = $env:ARM_SUBSCRIPTION_ID
. .\scripts\context-common.ps1
Assert-WorkshopAzureContext -TenantId $inspectionTenant -SubscriptionId $inspectionSubscription
```

**Observez :** aucune erreur. Le script a vérifié l'annuaire et l'abonnement, pas le déploiement.
**Avant de continuer :** arrêtez-vous en cas d'écart. Gardez ce terminal ouvert ; la suite réutilise ses variables.

### Observer 2. Retrouver le groupe dans votre état

**Pourquoi :** ne devinez pas le nom et ne cherchez pas dans tout l'abonnement.
**Prévoyez :** Terraform renvoie le groupe enregistré dans l'état d'origine de votre charge de travail.

```powershell
$workloadPath = Join-Path 'infra' 'workload'
$resourceGroup = & terraform "-chdir=$workloadPath" output -raw resource_group_name
if ($LASTEXITCODE -ne 0 -or -not $resourceGroup) {
    throw 'No resource group output. Use the original workload state after an approved deployment.'
}
$resourceGroup
```

**Observez :** un nom de groupe dans votre terminal privé. Aucune ressource n'a été créée.
**Avant de continuer :** comparez-le au groupe approuvé. Si l'état est absent, arrêtez-vous ; n'en recréez pas un.

### Observer 3. Repérer vos ressources de participant

**Pourquoi :** un groupe partagé peut contenir les ressources d'autres participants.
**Prévoyez :** le tag `workshop` contient votre préfixe et votre suffixe stable.

```powershell
$tagJson = & terraform "-chdir=$workloadPath" output -json resource_tags
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the workshop tags from the original workload state.' }
$workshopTag = ($tagJson | ConvertFrom-Json -AsHashtable).workshop
if ($workshopTag -cnotmatch '^mcp-[a-z][a-z0-9]{1,7}-([a-f0-9]{10}|[a-f0-9]{16})$') {
    throw 'Invalid workshop tag. Stop and inspect the original workload state.'
}
$workshopTag
```

**Observez :** un tag comme `mcp-p01-0123456789abcdef`, pas un identifiant de connexion.
**Avant de continuer :** vérifiez votre préfixe. Ne retirez jamais le filtre pour obtenir davantage de résultats.

### Observer 4. Lister et interpréter le résultat

**Pourquoi :** la requête est maintenant limitée à l'abonnement approuvé et à votre tag de participant.
**Prévoyez :** seules les ressources correspondantes de ce groupe apparaissent. Revérifiez le contexte juste avant l'appel Azure.

```powershell
Assert-WorkshopAzureContext -TenantId $inspectionTenant -SubscriptionId $inspectionSubscription
az resource list --subscription $inspectionSubscription `
    --resource-group $resourceGroup `
    --query "[?tags.workshop=='$workshopTag'].{Name:name,Type:type,Location:location}" --output table --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Resource inspection failed. Check the context and scoped read permissions.' }
```

**Observez :** un tableau des noms, types et régions des ressources portant votre tag dans le groupe sélectionné.
Azure CLI n'accepte pas `--tag` avec `--resource-group`. La requête porte donc sur le groupe,
puis son filtre retient le tag validé.
Si l'état local est absent ou l'accès refusé, arrêtez-vous : ce n'est pas un résultat vide valide.
Un tableau vide signifie seulement que cette requête n'a rien trouvé : ce n'est ni une preuve de nettoyage complet
ni un test des autorisations du serveur. Le module 01 ne crée aucune ressource Azure.
Lancez séparément le script de vérification du module pour tester son comportement.
Ne collez pas de sorties privées, d'identifiants ou de jetons dans l'application ou dans le chat.

### Observer 5. Comparer dans les portails

**Pourquoi :** cette liste établit un inventaire ; elle ne prouve ni la connexion ni l'autorisation des outils.
**Action :** comparez le même groupe et le même tag dans Azure ; vérifiez séparément l'identité dans Entra.

Pour vérifier visuellement, ouvrez le [portail Azure](https://portal.azure.com/), sélectionnez le même annuaire
et le même abonnement, puis ouvrez **Groupes de ressources** et le groupe indiqué par la sortie Terraform.
Dans un groupe partagé, filtrez sur le même tag `workshop` ; les ressources des autres ne vous appartiennent pas.
Pour les identités du module 03, ouvrez le [centre d'administration Microsoft Entra](https://entra.microsoft.com/),
sélectionnez l'annuaire approuvé et consultez uniquement les applications de l'atelier dans **Inscriptions d'applications**.
Ces liens ne sélectionnent aucun tenant, n'accordent aucun droit et ne déploient rien.

**Avant de continuer :** expliquez quel portail contient les ressources et lequel contient les identités.
Lancez ensuite la validation du module pour tester les accès.

## 3. Suivre le module avant de déployer

Terminez les vérifications du [module 00](../../modules/00-prerequisites/README.fr.md), puis l'exercice local
du module 01 lorsqu'il sera disponible. Sélectionner un abonnement ne valide pas un module.

Le code Terraform actuel prépare le groupe et un portail public facultatif sur App Service, désactivé par défaut.
Le serveur MCP et les modules suivants ne sont pas encore implémentés. Attendez leurs guides de déploiement,
de vérification et de nettoyage. Ce tableau ne propose aucun bouton pour déployer tout l'atelier.

> [!IMPORTANT]
> Avant de créer une ressource payante, examinez le plan Terraform, les droits, les quotas et les coûts.
> N'appliquez le plan qu'après un accord explicite. Conservez les mêmes paramètres et le même état Terraform.

<details>
<summary>Pour aller plus loin : ce qu'il faut examiner dans un plan Terraform</summary>

Vérifiez les ressources créées et les périmètres des rôles. Les fournisseurs Terraform AzureRM et AzAPI
doivent cibler l'abonnement approuvé ; AzureAD doit cibler l'annuaire approuvé.
Un paramètre explicite ou un alias peut prendre le pas sur une variable d'environnement.
Revérifiez le contexte après tout changement de terminal, d'abonnement, de fournisseur ou de connexion.
Les modules concernés ajouteront ces fournisseurs et l'infrastructure Entra.

L'administrateur d'identité examine séparément `infra/entra` lorsqu'il sera implémenté.
Ne modifiez et ne supprimez jamais les objets fournis par l'organisation.
Utilisez des identités managées et la fédération, jamais de secret client.

Vérifiez aussi les régions disponibles, les quotas partagés, les règles Azure Policy et les tags.
API Management Standard v2 facture une capacité réservée. Réseau privé, stockage, télémétrie,
API Center et clients facultatifs peuvent ajouter des frais.
Des noms aléatoires évitent certains conflits de noms, pas les limites de capacité.

</details>

## 4. Tester votre serveur après son déploiement

Utilisez l'adresse fournie par **votre déploiement** dans [Tester votre serveur MCP](PRACTICE.md).
Le module 01 fonctionne localement. Le module 02 utilise brièvement une clé système.
Le module 03 ajoute la connexion des utilisateurs.
À partir du module 04, utilisez uniquement API Management ; la Function devient privée.

Alice, Bob et Eve sont des personnages fictifs associés à des comptes de test dédiés.
Une action qui modifie des données exige le rôle prévu et une approbation pour cette action précise.
Un refus peut être le résultat attendu : n'accordez pas plus de droits pour obtenir une réponse positive.
Un code HTTP 200 peut contenir une erreur d'outil MCP.

## 5. Nettoyer après les étapes payantes

Suivez le module 99 après avoir examiné et fait approuver les suppressions.
Supprimez uniquement les ressources et les identités créées pour l'atelier.
Ne touchez pas aux groupes et aux comptes existants. Arrêtez Inspector et les codespaces inutilisés.
Le module 07 est facultatif ; il ne doit pas retarder le nettoyage.

<details>
<summary>Pour aller plus loin : vérifier qu'il ne reste rien de facturable</summary>

Nettoyez les ressources avant les identités créées pour l'atelier.
Vérifiez les tags, le réseau privé, les attributions de rôles et l'inventaire.
Examinez aussi les durées de conservation et les suppressions récupérables.
Arrêter un service ne met pas nécessairement fin à tous ses frais.

</details>

## Sources

- [Choix du tenant et de l'abonnement avec Azure CLI](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli).
- [Connexion interactive Azure CLI](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively).
- [Attribution des rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).
- [Lister les ressources avec Azure CLI](https://learn.microsoft.com/cli/azure/resource#az-resource-list).
- [Configuration et authentification AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs).
- [Guide de test](PRACTICE.md).

Dernière vérification : 2026-10-14. Pendant la préparation, nous n'avons consulté aucun abonnement ni déployé aucune ressource.

Commandes de lecture et boutons de copie vérifiés le 2026-10-16 : contrôles hors ligne uniquement, aucun tenant interrogé.

# Préparer votre environnement Azure

Utilisez uniquement un environnement de test **approuvé et hors production**.
Cette page vous aide à le sélectionner ; elle ne déploie rien et ne garantit pas vos droits.
Si ce n'est pas déjà fait, [choisissez votre environnement de travail](GETTING-STARTED.md).

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

Lisez le script, puis lancez-le depuis le dossier principal du dépôt :

```powershell
& .\scripts\select-azure-context.ps1 -Language fr
```

Il ouvre la connexion Azure dans le navigateur, sélectionne l'abonnement demandé et vérifie le contexte.
Respectez l'authentification multifacteur de votre organisation.
Le script ne crée aucune ressource et n'attribue aucun rôle.

**Gardez ce même terminal pour Terraform.** Lancez le script avec `&`, pas dans un nouveau processus
`pwsh -File` : les paramètres de contexte doivent rester disponibles pour la suite.
Si le script échoue, arrêtez-vous. Ne poursuivez pas avec l'ancien abonnement sélectionné.

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
Il refuse les paramètres d'authentification incompatibles plutôt que de les ignorer.
La confirmation demandée atteste votre accord ; elle ne détecte pas automatiquement un environnement de production.

Ces scripts concernent Azure public. Un cloud souverain nécessite une configuration distincte, à examiner
avant utilisation. Ne collez jamais la sortie de `az account get-access-token` dans cette page.

</details>

## 3. Suivre le module avant de déployer

Terminez les vérifications du [module 00](../../modules/00-prerequisites/README.fr.md), puis l'exercice local
du module 01 lorsqu'il sera disponible. Sélectionner un abonnement ne valide pas un module.

Le code Terraform actuel prépare le groupe et un portail App Service public facultatif, désactivé par défaut.
Le serveur MCP et les modules suivants ne sont pas encore implémentés. Attendez leurs guides de déploiement,
de vérification et de nettoyage. Ce tableau n'a pas de bouton qui déploie tout l'atelier.

> [!IMPORTANT]
> Avant toute création payante, examinez le plan Terraform, les droits, les quotas et les coûts.
> L'application du plan exige un accord explicite. Conservez les mêmes paramètres et le même état Terraform.

<details>
<summary>Pour aller plus loin : ce qu'il faut examiner dans un plan Terraform</summary>

Vérifiez les ressources créées et les périmètres des rôles. Les fournisseurs Terraform AzureRM et AzAPI
doivent cibler l'abonnement approuvé ; AzureAD doit cibler l'annuaire approuvé.
Un paramètre explicite ou un alias peut remplacer une variable d'environnement.
Revérifiez le contexte après tout changement de terminal, d'abonnement, de fournisseur ou de connexion.
Ces fournisseurs et l'infrastructure Entra seront ajoutés dans les modules concernés.

L'administrateur d'identité examine séparément `infra/entra` lorsqu'il sera implémenté.
Les objets fournis par l'organisation ne doivent être ni modifiés ni supprimés.
Utilisez des identités managées et la fédération, jamais de secret client.

Vérifiez aussi les régions disponibles, les quotas partagés, les règles Azure Policy et les étiquettes.
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
Préservez les groupes et les comptes existants. Arrêtez Inspector et les codespaces inutilisés.
Le module 07 est facultatif ; il ne doit pas retarder le nettoyage.

<details>
<summary>Pour aller plus loin : vérifier qu'il ne reste rien de facturable</summary>

Nettoyez les ressources avant les identités créées pour l'atelier.
Vérifiez les étiquettes, le réseau privé, les attributions de rôles et l'inventaire.
Examinez aussi les durées de conservation et les suppressions récupérables.
Arrêter un service ne signifie pas nécessairement arrêter tous ses frais.

</details>

## Sources

- [Choix du tenant et de l'abonnement avec Azure CLI](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli).
- [Connexion interactive Azure CLI](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively).
- [Attribution des rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).
- [Configuration et authentification AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs).
- [Plan technique original en anglais](../BUILD-PLAN.md) et [guide de test](PRACTICE.md).

Dernière vérification : 2026-10-14. Aucun abonnement consulté et aucune ressource déployée lors de la préparation.

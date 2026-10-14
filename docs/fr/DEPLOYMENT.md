# Votre tenant. Votre abonnement. Votre décision.

Le serveur Model Context Protocol (MCP) doit être déployé dans **votre environnement de test approuvé**.
Cette page prépare le contexte de déploiement. Elle ne déploie rien et ne certifie pas vos permissions.
Commencez par [choisir dev container ou outils locaux](GETTING-STARTED.md).
Le preflight en lecture seule, le validateur et la demande d'identité du module 00 sont disponibles.
Terraform contient le socle groupe et le portail App Service public facultatif ; aucun runtime MCP n'est implémenté.

> [!IMPORTANT]
> Le tenant Microsoft Entra contient les identités, applications et consentements. L'abonnement Azure porte les
> ressources facturées. Le groupe de ressources délimite les ressources du workshop. Ce sont des périmètres
> différents, avec des responsabilités administratives distinctes.

## 1. Définir le périmètre avant la connexion

Choisissez un tenant de test approuvé et un abonnement Azure rattaché à cet annuaire.
Confirmez le préfixe participant, le groupe de ressources, le propriétaire, l'expiration, la région, le budget et
la fenêtre de nettoyage. N'utilisez ni données de production, ni session empruntée, ni environnement non approuvé.
Les identifiants de tenant et d'abonnement restent dans votre terminal privé, jamais dans le board ou le dépôt.

| Responsabilité | Autorité nécessaire | Ce que cela ne donne pas |
|---|---|---|
| Déployer les ressources | Opérations approuvées sur le groupe de ressources du workshop | Contributor ne permet pas d'attribuer des rôles. |
| Configurer les identités | Un administrateur d'identité approuve applications, rôles applicatifs, utilisateurs de test et consentements | Un rôle Azure ne donne pas l'administration Entra. |
| Attribuer l'accès aux ressources | Autorisation distincte d'attribuer les rôles au périmètre exact | Ne pas demander Owner sur l'abonnement par défaut. |
| Utiliser un client | ID de client public approuvé, adresse de retour exacte et étendues autorisées | La préautorisation de VS Code ne couvre pas Inspector. |
| Réutiliser des identifiants | Le propriétaire fournit les objets existants et leur périmètre | Ne pas modifier ni supprimer ces identités existantes. |

## 2. Choisir et vérifier dans votre terminal

Lisez le sélecteur de contexte avant de l'exécuter. Il lance la connexion interactive Azure CLI, choisit votre
abonnement et vérifie les deux identifiants ainsi que l'état de l'abonnement. Il ne crée aucune ressource et
n'attribue aucun rôle. Les substitutions d'authentification incompatibles provoquent un arrêt explicite.
Votre confirmation atteste l'approbation : elle ne détecte pas automatiquement un environnement de production.

### PowerShell 7

Depuis votre copie locale du dépôt, dans un terminal PowerShell :

```powershell
& .\scripts\select-azure-context.ps1 -Language fr
```

Utilisez `&` dans le processus PowerShell courant, **pas** un nouveau processus `pwsh -File`.
Le script définit `ARM_TENANT_ID` et `ARM_SUBSCRIPTION_ID` uniquement dans ce processus.
Il utilise `az login --tenant`, `az account set --subscription` et `az account show`.
Respectez la connexion navigateur et l'authentification multifacteur de votre organisation. Aucun mot de passe
ni secret client n'est nécessaire.

### bash

```bash
source ./scripts/select-azure-context.sh fr
```

Sourcez le script dans le même terminal bash. L'exécution avec `bash script.sh` est refusée : les variables
disparaîtraient avec le processus enfant. Les contrôles correspondent à ceux de la version PowerShell.

> [!WARNING]
> Un échec impose l'arrêt, pas la poursuite avec l'ancien abonnement par défaut.
> Sélectionnez à nouveau le contexte approuvé avant Terraform. Ne collez jamais de sortie
> `az account get-access-token` ici. Ces sélecteurs ciblent Azure public ; un cloud souverain nécessite une
> configuration distincte et revue.

## 3. Lire le vrai module avant tout déploiement payant

1. Terminez les contrôles publiés du module 00, puis l'exercice MCP local du module 01. Choisir un contexte
   ne valide pas ces modules.
2. Préparez le fichier participant privé avec le guide de démarrage. Conservez suffixe aléatoire et état Terraform.
   `infra/workload` ne gère qu'un groupe dédié ou lit un groupe approuvé, pas un serveur MCP.
   Attendez le vrai guide, la validation et le nettoyage de chaque module runtime. Aucun bouton Deploy dans le board.
3. Dans le même terminal, vérifiez le tenant et l'abonnement des providers réels de `infra/workload`.
   AzureRM et AzAPI doivent cibler votre abonnement, AzureAD le tenant approuvé.
   Un paramètre explicite ou un alias de provider peut remplacer les variables d'environnement. Lisez chaque
   provider et le plan.
4. L'administrateur d'identité examine séparément `infra/entra`. Lorsque la création est ignorée, lisez les
   identifiants fournis sans modifier les objets. Utilisez identités managées et fédération, jamais un secret client.
5. Vérifiez disponibilité régionale, quotas, politiques, tags et estimation. API Management Standard v2 facture
   une capacité provisionnée. Points de terminaison privés, stockage, télémétrie, API Center et agents optionnels
   peuvent également entraîner des coûts.
   Un nom aléatoire limite les collisions mais ne remet pas à zéro les quotas régionaux ou de l'abonnement partagé.
6. Lisez les ressources exactes et les périmètres de rôles du plan Terraform. L'application nécessite une
   approbation explicite dans la session de déploiement. Revérifiez le contexte après un changement de terminal,
   d'abonnement, de provider ou d'authentification.
7. Exécutez le vrai validateur du module. Conservez seulement les métadonnées autorisées et lignes PASS.
   Ne poursuivez pas avant sa réussite.

## 4. Appeler le serveur réellement déployé

Utilisez l'adresse issue des **sorties de votre déploiement**. Le module 01 utilise les entrées/sorties standard
(stdio), pas HTTPS. Le module 02 démontre brièvement une protection par clé système. Le module 03 ajoute
l'identité des utilisateurs affectés. Dès le module 04, seul l'URL API Management est destiné aux clients :
la Function devient privée.

Connectez le client approuvé au bon tenant avec son adresse de retour exacte et ses étendues.
Alice, Bob et Eve désignent des personas fictifs associés à des comptes de test dédiés.
Ne saisissez ni jeton, ni clé, ni identifiants de connexion dans le board.
Préparez les commandes dans **Tester votre MCP**, puis exécutez et inspectez les appels dans le client officiel.
Un HTTP 200 peut contenir une erreur d'outil MCP. Chaque écriture synthétique exige un rôle explicite et une
approbation individuelle.

> [!TIP]
> Prédisez le résultat : pas de jeton donne 401 ; une écriture de Bob à la passerelle donne 403 ; un dépassement
> de débit donne 429. Pour la délégation, lisez aussi le résultat MCP. Un refus peut être le résultat attendu.

## 5. Arrêter les coûts et préserver les objets partagés

Après les étapes payantes, suivez le module 99. Le module 07 est facultatif.
Examinez le nettoyage des ressources avant celui des identités. Supprimez uniquement les ressources,
affectations et comptes créés pour le workshop, après approbation explicite. Préservez les identités fournies et
l'infrastructure partagée. Vérifiez les tags, le réseau privé, l'inventaire, la rétention et la suppression
récupérable. Arrêtez également Inspector et les codespaces inutilisés.

## Sources

- [Choix du tenant et de l'abonnement avec Azure CLI](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli).
- [Connexion interactive Azure CLI](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively).
- [Autorité d'attribution des rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli).
- [Configuration et authentification AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs).
- [Plan technique original en anglais](../BUILD-PLAN.md) et [guide pratique français](PRACTICE.md).

Dernière vérification : 2026-10-14. Aucun abonnement n'a été consulté et aucune ressource n'a été déployée.

# 00 - Preparer l'environnement approuve

[English](README.md)

## Goal

Choisissez un terminal local ou un conteneur de developpement Visual Studio Code.
Verifiez les outils et votre cible Azure hors production. Preparez la demande a l'administrateur Microsoft Entra.

## Why it matters

Un outil installe ne prouve ni les autorisations ni la capacite disponible.
Les noms aleatoires evitent les collisions ; ils ne changent pas les quotas partages.
Votre terminal s'authentifie dans Azure, jamais le portail public.

## What you deploy

Le preflight ne deploie **rien**. Il lit le contexte, les regions, les fournisseurs et les droits accordes.
La racine Terraform partagee peut creer un groupe isole ou lire un groupe existant sans le gerer.
Le [portail public facultatif](../../docs/fr/HOSTING.md) ajoute un plan App Service payant et un site,
uniquement sur activation explicite. Aucun serveur Model Context Protocol (MCP) n'est encore deploye.

## Prerequisites and required roles

Suivez le [choix du poste](../../docs/fr/GETTING-STARTED.md).
Versions retenues : Terraform 1.16.6, AzureRM 5.9.0, Azure CLI 2.88.0, kit de developpement .NET 10,
PowerShell 7.4+, Node.js 22.19+ et Functions Core Tools v4 >= 4.5.0.
L'interface de commande Functions v5 distincte est en **Preview** et n'est pas retenue.

Un nouveau groupe exige les droits de lecture, creation et suppression de groupes au niveau abonnement.
Pour un groupe fourni par l'administrateur, restez dans son perimetre. Ne demandez pas Owner par commodite.
Le script evalue les actions Azure Resource Manager (ARM) autorisees moins les exclusions de chaque enregistrement,
puis combine les autorisations. Une autre attribution peut autoriser une action exclue ailleurs.
La pagination reste sur le meme hote HTTPS et le meme perimetre.
Les refus explicites et Azure Policy restent a examiner : une autorisation accordee ne garantit pas le deploiement.

Aucun droit Entra d'administration n'est necessaire ici. L'administrateur traite separement la
[demande precise](../../docs/requests/identity-request.md) avant le module 03.
Le script n'enregistre aucun fournisseur et n'attribue aucun role.

## Steps

### PowerShell

Depuis la racine, dans le terminal effectivement choisi :

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\check-tools.ps1
$expiry = [datetime]::UtcNow.AddDays(1).ToString('yyyy-MM-dd')
& .\scripts\prepare-workshop.ps1 -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry $expiry
& .\scripts\select-azure-context.ps1 -Language fr
& .\modules\00-prerequisites\validate.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
```

Adaptez la region, les libelles et la date approuves. Si un groupe est fourni, ajoutez
`-ExistingResourceGroupName` des la premiere preparation. Conservez le suffixe et l'etat Terraform.
Lisez le selecteur : il demande les identifiants prives et `NONPROD`, ouvre la connexion et selectionne
l'abonnement. Le preflight ne se connecte pas et ne change pas le contexte.
Ne publiez aucun identifiant de compte, jeton ou reponse de compte dans le tableau, Git ou le chat.

Les tests locaux sont distincts :

```powershell
terraform -chdir=infra/workload init -backend=false -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Provider initialization failed.' }
& .\modules\00-prerequisites\validate.ps1 -Offline
```

### bash

Les wrappers utilisent le meme PowerShell, egalement present dans le conteneur.

```bash
bash ./scripts/check-tools.sh
read -r -p 'Date de nettoyage approuvee (yyyy-MM-dd) : ' expiry
bash ./scripts/prepare-workshop.sh -ParticipantPrefix p01 -Location westeurope -Owner alice -Expiry "$expiry"
source ./scripts/select-azure-context.sh fr
bash ./modules/00-prerequisites/validate.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID"
terraform -chdir=infra/workload init -backend=false -lockfile=readonly &&
bash ./modules/00-prerequisites/validate.sh -Offline
```

Pour une etape payante ulterieure, utilisez `-Stage portal` ou `-Stage mcp`, avec une preuve privee
`-CapacityReviewPath` decrite dans le [guide d'hebergement](../../docs/fr/HOSTING.md).
La base `mcp` anticipe les futurs services ; elle ne valide pas leurs ressources imbriquees ou leur fonctionnement.
Elle verifie aussi les droits d'attribution de roles : prevoyez leur execution separee par l'administrateur,
pas une elevation des droits de tous les participants. Les futurs modules preciseront leurs operations exactes.

## What you should see

Chaque controle affiche `PASS` ou s'arrete sur une erreur. HTTP designe le protocole de transfert hypertexte.
Les lectures Azure attendent HTTP 200 ; les controles locaux affichent `N/A`.
Les erreurs CLI n'affichent pas les reponses de compte. Le mode nouveau groupe verifie la limite documentee
de 980 groupes ; le mode groupe existant n'exige pas de quota pour un groupe supplementaire.

Les tests hors ligne utilisent des reponses synthetiques et des fournisseurs simules.
Leur derniere ligne indique explicitement que le module n'est **pas valide dans Azure**.
Un controle sur l'hote ne valide pas le conteneur. L'execution du conteneur et de Codespaces reste
non verifiee sur le poste de creation, faute de moteur approuve accessible.

## Validate

Executez `validate.ps1` ou `validate.sh` dans l'abonnement de test approuve.
Consignez l'etape, le type de terminal, la date et les lignes PASS non sensibles dans `docs/PROGRESS.md`.
Avant de declarer le module valide, confirmez que la demande d'identite est comprise et peut etre transmise
en prive. N'etendez pas cette validation a une autre route ou aux capacites des services futurs.
Ne commencez le module 01 qu'apres la validation reelle du module 00.

## Troubleshooting

- Mauvais contexte ou surcharge d'authentification : utilisez un terminal interactif approuve et separe.
- Fournisseur absent : faites examiner l'enregistrement du fournisseur nomme par l'administrateur.
- Droit manquant : verifiez l'action et le perimetre. Preferez un groupe existant aux droits d'abonnement elargis.
- Capacite insuffisante : examinez quotas, nombre maximal d'instances et demande totale du groupe de participants.
- Wrapper npm Core Tools sans binaire : terminez l'installation approuvee. Le controle ne lance pas de telechargement.
- Refus Policy lors du plan reel : traitez le refus ; ne desactivez pas le controle.

## Clean up

```powershell
& .\modules\00-prerequisites\cleanup.ps1
```

```bash
bash ./modules/00-prerequisites/cleanup.sh
```

Le preflight n'a rien cree. Le nettoyage conserve les parametres et l'etat prives.
Si vous avez applique le Terraform du groupe ou du portail, suivez son
[plan de destruction a revoir](../../docs/fr/HOSTING.md#clean-up).
Arreter le site ne supprime pas son plan payant. Ne supprimez jamais un groupe partage pour contourner Terraform.

## Go further

Consultez la [gouvernance](../../docs/fr/LEARNING-GUIDE.md), la [demande Entra](../../docs/requests/identity-request.md)
et le [schema prevu](../../assets/architecture/00.fr.svg).
Le portail facultatif contient de la documentation publique ; ce n'est ni un site interne authentifie,
ni une console de deploiement inter-tenants.

## Sources

- [Installation Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
- [Terraform sur Azure](https://learn.microsoft.com/azure/developer/terraform/overview).
- [Installation PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
- [.NET 10](https://dotnet.microsoft.com/download/dotnet/10.0).
- [Outils Functions](https://learn.microsoft.com/azure/azure-functions/functions-run-local).
- [API des autorisations](https://learn.microsoft.com/rest/api/authorization/permissions/list-for-resource-group).
- [Limites Azure](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits).
- [Capacite et runtimes Flex](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan).
- [Conteneurs VS Code](https://code.visualstudio.com/docs/devcontainers/containers).
- [Versions et sources retenues](../../docs/sources.md).

Last verified: 2026-10-14. Tests locaux uniquement ; aucune validation Azure ou du conteneur a ce stade.

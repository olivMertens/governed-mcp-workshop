# Publier les guides et déployer les ressources séparément

Ce guide s'adresse aux personnes qui hébergent l'atelier. Pour simplement le suivre,
commencez par le [guide de démarrage](GETTING-STARTED.md) : vous n'avez pas besoin de publier le portail.

Le portail public et les services Model Context Protocol (MCP) Azure sont deux déploiements distincts.
Le portail aide à préparer l'environnement. Il ne collecte pas les identifiants Azure, n'accepte aucune clé
de déploiement partagée et ne reçoit aucun accès aux tenants participants.

| Élément | Hébergement conseillé | Accès et responsabilités |
|---|---|---|
| Guides EN/FR, schémas et choix d'environnement | GitHub Pages | Contenu statique public, sans connexion Azure ni droit de déploiement. |
| Copie publique Azure facultative | App Service Linux B1 du participant, activé explicitement dans Terraform | Guides publics. Entra autorise le déploiement, pas l'accès visiteur. |
| Copie interne facultative | App Service **ou** Azure Container Apps désigné | Conception distincte ; connexion visiteur sans secret non implémentée ici. |
| Ressources MCP du participant | Abonnement et groupe de test approuvés | Terraform exécuté depuis son terminal connecté à Azure, après examen du plan. |

App Service et Azure Container Apps (ACA) sont des services différents.
Y héberger le portail ne déploie pas les services de l'atelier. L'architecture MCP reste Azure Functions derrière API Management ;
elle ne devient pas automatiquement une application ACA.

## Construire le portail

<details>
<summary>Publier sur GitHub Pages : préparation et étapes détaillées</summary>

Depuis la racine du dépôt, avec Node.js 22.19+ :

```powershell
node --test scripts/site.test.mjs
if ($LASTEXITCODE -ne 0) { throw 'Site checks failed.' }
node scripts/build-site.mjs
if ($LASTEXITCODE -ne 0) { throw 'Site build failed.' }
```

```bash
node --test scripts/site.test.mjs && node scripts/build-site.mjs
```

La sortie `site-dist` est ignorée par Git. Un dossier existant n'est pas écrasé.
Pour reconstruire, choisissez un nouveau dossier avec `--output` ; ne supprimez qu'une ancienne sortie inspectée.
Servez le dossier avec un serveur HTTP, pas via `file://`.
La sortie portable contient HTML, traduction JavaScript, parcours JSON public et uniquement les icônes/schémas autorisés.
Ni dépôt complet, `.git`, `.workshop`, identifiants, état Terraform, serveur canvas ou capacité d'accès locale.
Les chemins relatifs fonctionnent aussi sous `/workshop-mcp/`.

Accueil : `#/start`. Français : `?lang=fr#/start`. Anglais : `?lang=en#/start`.
Les routes utilisent le fragment, sans serveur applicatif ou réécriture GitHub Pages.
Le site lit ses fichiers statiques. L'adresse saisie reste en mémoire de page ; seuls vos outils de test appellent le serveur MCP.

## Publier sur GitHub Pages

Le workflow `.github/workflows/workshop-pages.yml` suit la procédure GitHub officielle, fixe les actions par commit
et publie **uniquement `site-dist`**, jamais la racine du dépôt.
Aucun identifiant Azure ni secret client. Son identité GitHub temporaire autorise Pages, pas votre tenant Azure.

1. Examinez contenu public, règles d'utilisation des images et sources. Publiez d'abord les sources et tous les
   scripts/configurations nécessaires sur la branche par défaut. Sinon, clone et Codespaces renvoient vers des
   fichiers indisponibles : ne promettez pas de prérequis non publiés.
2. Dans **Settings > Pages**, choisissez **GitHub Actions** comme source.
   Le workflow ne modifie pas silencieusement ce réglage.
3. Définissez les branches autorisées et l'éventuel approbateur de l'environnement `github-pages`.
4. Dans **Actions > Publish workshop guides > Run workflow**, choisissez la branche par défaut.
   Déclenchement manuel uniquement : aucune publication automatique sur push ou pull request.
5. Vérifiez le résultat et l'adresse remontée. Contrôlez accueil, EN/FR, schémas et préparation du client sur le
   vrai site avant de partager son adresse.

Adresse attendue après publication réussie pour ce dépôt : `https://olivmertens.github.io/workshop-mcp/`.
**Cela ne signifie pas que le site est en ligne.** Pages était désactivé lors de la préparation ;
aucun workflow lancé ni réglage distant modifié. Vérifiez droits, visibilité et limites Pages/Actions de votre offre.

</details>

## Héberger les guides dans un tenant

<details>
<summary>Pour aller plus loin : hébergement interne et accès des visiteurs</summary>

La même sortie statique peut être servie par une application App Service ou ACA existante et approuvée.
Avant le déploiement, précisez la ressource, l'abonnement, le groupe, l'environnement d'exécution ou l'image,
les règles réseau, l'authentification, le propriétaire du contenu, les coûts et la procédure de retour arrière.
Ne remplacez pas une application et ne créez ni accès,
permission ou configuration Entra sans approbation explicite. Pas d'application de production comme raccourci.

Pour un portail privé, examinez l'authentification Entra intégrée prise en charge par le service choisi,
les règles d'accès et les paramètres mono-tenant d'émetteur/audience. Un écran de connexion ne suffit pas.
Identité managée pour l'accès applicatif autorisé ; fédération OpenID Connect (OIDC) pour un pipeline approuvé.
Pas de profil de publication copié, de clé permanente ou de secret client.
La référence ACA montre aussi une configuration avec secret client : ne l'exécutez pas.
Un parcours de connexion au portail privé sans secret n'est pas encore établi et reste un prérequis bloquant.
Les identifiants réels et la résolution de cible restent dans la session privée de déploiement, pas ce dépôt public.
Aucune connexion Azure de l'auteur ni découverte/modification d'applications pendant cette préparation.

</details>

## Portail public facultatif sur App Service

Ce chemin implémenté héberge la **même application monopage (SPA) publique**, pas un site interne authentifié.
Il utilise App Service Linux Basic B1 et Node.js 22 LTS (version maintenue à long terme).
Ni registre de conteneurs, construction d'image, secret client, profil de publication ou clé de déploiement.
ACA n'est pas implémenté dans cette itération. Suivez d'abord le
[module 00](../../modules/00-prerequisites/README.fr.md).
Une seule racine `infra/workload` et un seul état. L'activation reste dans les paramètres privés ;
un prochain plan ordinaire ne désactive pas implicitement le portail.

**Coût :** l'instance B1 dédiée est facturée en continu. Vérifiez les prix de la région et les règles de l'abonnement.
Arrêter le site ne supprime pas la facturation du plan. HTTPS et Transport Layer Security (TLS) 1.2+ sont imposés ;
File Transfer Protocol (FTP) et publication par authentification de base sont désactivés.
Le serveur en lecture seule n'enregistre ni corps, paramètres de requête, identifiants ou résultats.
Il expose seulement 50 fichiers publics et `/health`, jamais l'API du canvas.
GitHub Pages reste le choix le plus simple pour un atelier public.

<details>
<summary>Déployer le portail sur App Service : préparation, contrôles et approbations</summary>

### Préparer et examiner localement

Terminez d'abord le déploiement du **socle seul** du [guide de démarrage](GETTING-STARTED.md),
portail encore désactivé, ou utilisez le groupe fourni par l'administrateur.
Examinez et approuvez séparément le plan sauvegardé avant de l'appliquer.
Le script de vérification du portail exige que ce groupe existe.

Répétez votre commande initiale `prepare-workshop.ps1`, avec **les mêmes** préfixe, région, propriétaire,
date et éventuel groupe existant, en ajoutant `-EnablePublicPortal`.
Cette activation explicite peut enrichir un fichier de paramètres du socle existant : suffixe et état sont conservés.
Ne régénérez pas les noms et ne changez pas de copie ou d'état.

```powershell
node scripts/build-portal.mjs
if ($LASTEXITCODE -ne 0) { throw 'Public bundle build failed.' }
node scripts/portal-server.mjs --verify portal-dist
if ($LASTEXITCODE -ne 0) { throw 'Public bundle verification failed.' }
node portal-dist/server.mjs
```

```bash
node scripts/build-portal.mjs &&
node scripts/portal-server.mjs --verify portal-dist &&
node portal-dist/server.mjs
```

Le serveur local écoute sur la boucle locale, port 8080. Examinez les deux langues et les schémas ;
arrêtez-le avec Ctrl+C. `portal-dist`, ignoré par Git, contient exactement 52 fichiers :
les 50 éléments publics, le manifeste d'empreintes et le serveur sans dépendance externe.
Le script de construction refuse un dossier existant ; choisissez un nouveau `--output` pour reconstruire.
En App Service, le serveur respecte `PORT` et n'écoute extérieurement que lorsque cette variable est définie.

### Vérifier capacité et coût en privé

Le groupe doit déjà exister pour les contrôles du portail : examinez et faites approuver le plan du
[socle seul](GETTING-STARTED.md), **avant** d'activer le portail, avec son approbation distincte.
Un groupe fourni par l'administrateur n'est ni créé ni importé.

L'administrateur examine séparément l'enregistrement de `Microsoft.Web` si nécessaire.
Vérifiez la disponibilité de B1 Linux, le quota régional d'instances, les règles et le coût d'une instance.
Pour le futur `-Stage mcp`, consultez **Diagnose and solve problems > Flex Consumption Quota** :
la demande maximale en mémoire est partagée entre participants. Les noms aléatoires ne changent pas les quotas.
Le contrôle `mcp` vérifie les régions Flex et la prise en charge de .NET 10 en processus isolé.
Il ne construit pas les modules suivants.

Conservez la preuve dans `.workshop/capacity-review.json`, ignoré par Git, jamais dans le tableau.
Cet exemple **échoue volontairement** tant que l'abonnement, la capacité, l'heure UTC et le coût n'ont pas été vérifiés :

```json
{
  "subscriptionId": "<abonnement prive approuve>",
  "location": "<code de region approuve>",
  "stage": "portal",
  "unit": "workers",
  "availableUnits": 0,
  "checkedAtUtc": "<yyyy-MM-ddTHH:mm:ssZ>",
  "costApproved": false
}
```

Pour Flex, utilisez `stage: "mcp"` et `unit: "MB"`. Plafond par défaut : 2048 Mo fois 10 instances.
Adaptez `-FlexMemoryMB` et `-FlexMaximumInstances` dans l'appel à `scripts/preflight.ps1` si le plan diffère.
La preuve doit correspondre à abonnement, région et étape, dater de moins de 24 heures et jamais du futur.
C'est une **revue humaine de quota/coût**, pas une lecture automatique du quota ni une réservation.
Les capacités API Management/réseau/télémétrie et les règles attendent le vrai plan du module concerné.

### Planifier, approuver, déployer

Ces commandes lisent la cible approuvée sans connexion, changement d'abonnement, enregistrement ou attribution.
Conservez le contexte sélectionné en privé dans le même terminal.

```powershell
$ErrorActionPreference = 'Stop'
& .\scripts\preflight.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID `
    -Stage portal -CapacityReviewPath .\.workshop\capacity-review.json
terraform -chdir=infra/workload init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\portal.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan failed.' }
terraform '-chdir=infra\workload' show '..\..\.workshop\portal.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform plan review failed.' }
# STOP : obtenir l'approbation du plan exact, de la cible et du cout B1.
# Seulement apres approbation :
terraform '-chdir=infra\workload' apply '..\..\.workshop\portal.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Terraform apply failed.' }
& .\scripts\deploy-portal.ps1 -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID `
    -CapacityReviewPath .\.workshop\capacity-review.json
```

```bash
bash ./scripts/preflight.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" \
  -Stage portal -CapacityReviewPath ./.workshop/capacity-review.json &&
terraform -chdir=infra/workload init -lockfile=readonly &&
terraform -chdir=infra/workload plan -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/portal.tfplan &&
terraform -chdir=infra/workload show ../../.workshop/portal.tfplan
# STOP : obtenir l'approbation distincte du plan exact, de la cible et du cout B1.
# Seulement apres approbation :
terraform -chdir=infra/workload apply ../../.workshop/portal.tfplan &&
bash ./scripts/deploy-portal.sh -TenantId "$ARM_TENANT_ID" -SubscriptionId "$ARM_SUBSCRIPTION_ID" \
  -CapacityReviewPath ./.workshop/capacity-review.json
```

Un plan sauvegardé s'applique sans nouvelle question Terraform : **ne collez pas le bloc entier avant approbation**.
L'envoi du code demande une confirmation distincte pour l'application participant nommée.
`-WhatIf` réalise les lectures, mais ne crée pas de ZIP et ne transfère rien.
Le script vérifie la cible, les étiquettes, le plan, l'environnement d'exécution, TLS
et la désactivation de la publication par authentification de base.
Il crée ensuite un ZIP privé et utilise `az webapp deploy` avec Entra, sans récupérer d'identifiants de publication.
Il refuse un ZIP existant : choisissez un nouveau `-PackagePath` privé lors d'une nouvelle publication.
Pour revenir en arrière, utilisez les fichiers de la précédente version approuvée,
avec un nouveau chemin ZIP et les mêmes contrôles.

Vérifiez `terraform output public_portal_url`, `/health` HTTPS (200 et `{"status":"ok"}`),
accueil, deux langues, schémas et préparation du client sur le vrai site avant de partager l'adresse.
Aucun plan Azure réel, apply, transfert ou contrôle de site déployé n'a été exécuté pendant la création.
Les preuves actuelles sont locales : schéma Terraform, plans simulés, serveur et déploiement synthétique.

</details>

## Nettoyer

Les contrôles préalables ne créent rien. Si vous avez appliqué le code Terraform,
examinez le plan de suppression avec les **mêmes paramètres et le même état**.
Il retire toutes les ressources de l'atelier suivies dans cet état, pas seulement le portail.
Après ajout de modules ultérieurs dans le même état, ne l'utilisez que pour une suppression complète voulue.

<details>
<summary>Préparer un plan de suppression et le faire approuver</summary>

```powershell
terraform '-chdir=infra\workload' plan -destroy '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\destroy.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Destroy plan failed.' }
terraform '-chdir=infra\workload' show '..\..\.workshop\destroy.tfplan'
# STOP : examiner les suppressions et obtenir une approbation distincte.
# Seulement apres approbation :
terraform '-chdir=infra\workload' apply '..\..\.workshop\destroy.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Destroy failed.' }
```

```bash
terraform -chdir=infra/workload plan -destroy -var-file=../../.workshop/participant.tfvars.json -out=../../.workshop/destroy.tfplan &&
terraform -chdir=infra/workload show ../../.workshop/destroy.tfplan
# STOP : obtenir une approbation de suppression distincte avant d'appliquer ce plan.
```

Le groupe existant administrateur reste une source de données, jamais une cible destroy.
Le groupe dédié non vide reste protégé. Conservez paramètres et état privés jusqu'à vérification de la suppression.
Ne supprimez pas un groupe entier pour masquer des ressources non suivies.

</details>

## Portail participant facultatif lié à votre déploiement

Le présentateur ne peut pas déployer dans le tenant des participants. Un participant qui veut un portail connaissant
déjà **son** point de terminaison déploie le même portail App Service dans **son** abonnement, avec le même état
et les mêmes paramètres que son workload MCP, en suivant la procédure ci-dessus.

Quand le portail et le serveur MCP partagent cet état Terraform, le plan ajoute au portail des paramètres non secrets :

| Paramètre d'application | Origine | Quand |
|---|---|---|
| `WORKSHOP_MCP_ENDPOINT` | `mcp_endpoint` (URL HTTPS de la Function App) | `enable_mcp_server = true` (module 02) |
| `WORKSHOP_MCP_SCOPE` | `mcp_auth_scope` (`api://…/user_impersonation`) | `enable_entra_auth = true` (module 03) |

Le serveur du portail revérifie ces deux valeurs et ne sert qu'elles, sur `/participant.json`.
La page **Essayer votre MCP** préremplit le point de terminaison et affiche l'étendue déléguée. Rien n'est prérempli
sur GitHub Pages : le participant saisit son adresse, qui reste dans la mémoire du navigateur.

- Jamais ajoutés : la clé système du module 02, les jetons, les ID de tenant ou d'abonnement, les chaînes de connexion, les secrets client.
- Le portail est public : il révèle le nom d'hôte et l'étendue, qui ne sont pas des secrets. Le point de terminaison reste
  protégé par la clé système (niveau 0) ou Microsoft Entra (niveau 1). Ne diffusez pas le lien hors de votre groupe de test,
  et supprimez le portail avec le workload.
- Relancez le plan et le déploiement du portail après chaque nouveau module pour mettre à jour les valeurs préremplies.
- Coût : un plan B1 par participant qui l'active. C'est facultatif ; les guides partagés sur GitHub Pages suffisent.

## Ressources du participant

Suivez [le choix d'environnement](GETTING-STARTED.md) puis [le contexte Azure](DEPLOYMENT.md).
Le participant se connecte à son tenant dans son terminal ou dev container, garde suffixe aléatoire et état privé,
puis examine le plan destiné à son groupe. Les rôles Azure et le consentement Entra sont deux autorisations distinctes.
Une automatisation propre au participant nécessite sa fédération limitée et ses approbations ;
le portail public ne devient pas une console de déploiement multi-tenant.

Le socle Terraform groupe et l'App Service public facultatif existent maintenant. Functions, identité, passerelle et observabilité
ne sont pas encore implémentés ni validés. Aucun bouton « tout déployer » ni fausse sortie de clé/adresse.
La clé système temporaire du module 02 est saisie uniquement dans le client, à l'exécution :
jamais dans le portail, URL, chat, sortie publique ou configuration sauvegardée.

## Sources

- [Workflows Pages officiels](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
- [Source de publication Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
- [OIDC GitHub vers Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure).
- [Authentification App Service](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization), [authentification ACA](https://learn.microsoft.com/azure/container-apps/authentication).
- [Node.js App Service](https://learn.microsoft.com/azure/app-service/configure-language-nodejs).
- [Déploiement ZIP avec Entra](https://learn.microsoft.com/azure/app-service/deploy-authentication-types).
- [Exécution du package](https://learn.microsoft.com/azure/app-service/deploy-run-package).
- [Prix App Service Linux](https://azure.microsoft.com/pricing/details/app-service/linux/).
- [Capacité Flex](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan).
- [Références](REFERENCES.md), [droits sur les images](../../assets/architecture/README.fr.md).

Dernière vérification : 2026-10-14. Préparation locale uniquement, sans publication ni déploiement Azure.

# Présentateur : publier le portail et partager le lien

[English](../PRESENTER.md)

**Vous hébergez les guides. Les participants réalisent leurs propres exercices.**
Publier le portail ne déploie pas le serveur Model Context Protocol (MCP).
Les modules 00 et 02 à 07 (partie Foundry, préversion) et le nettoyage du module 99 sont validés en conditions réelles
dans un tenant de test, avec les vérifications d'Alice, Bob et Eve. Le module 01 est rédigé (contrôles hors ligne réussis).
Suivez l'ordre d'exécution du [README racine](../../README.md).
Les participants peuvent faire le [module 01](../../modules/01-discover-mcp/README.fr.md) sans attendre votre portail ni un déploiement Azure.

## Avant la session

1. **Faites enregistrer la MFA d'Alice, Bob et Eve.** Un tenant de test peut exiger l'authentification multifacteur (MFA).
   Connectez-vous une fois avec chaque compte de test et enregistrez une méthode (par exemple une application d'authentification).
   N'affaiblissez jamais l'accès conditionnel pour l'éviter. Sinon, les vérifications d'Alice, Bob et Eve restent bloquées à la connexion.
2. **Renouvelez la revue de capacité avant de déployer le portail.** Les contrôles préalables du portail n'acceptent
   qu'une revue de moins de 24 heures ([vérifier capacité et coût en privé](HOSTING.md#vérifier-capacité-et-coût-en-privé)).
   Faites-la le jour même du déploiement.
3. **Prévoyez API Management (module 04) sur une seule journée.** Le niveau Standard v2 est facturé à l'heure tant qu'il existe
   (environ 1 USD de l'heure au moment de la rédaction ; consultez la calculatrice de prix pour votre région).
   Déployez-le le jour où vous présentez le module 04 et supprimez-le le soir même.
4. Ouvrez à l'avance les captures réelles listées ci-dessous : elles servent de solution de repli si une étape en direct échoue.

Fil conducteur de la séquence architecture : [Séquence 2 - intégrer et exposer MCP](INTEGRATION-OPTIONS.md) (options d'hébergement, les deux modèles API Management, démo 3, inventaire, points de vigilance pour l'administrateur général).

## Captures réelles en solution de repli

Chaque module présente, à l'étape concernée, des captures réelles prises dans le tenant de test de l'auteur.
Les noms sont remplacés par des pseudonymes, les identifiants par des zéros, et des cadres roses signalent ce qu'il faut vérifier.
Servez-vous-en quand une étape ne peut pas se faire en direct (consentement absent, MFA non enregistrée, quota, réseau).
Une capture montre le résultat attendu ; elle ne valide pas le déploiement du participant.

| Module | Étape | Captures |
|---|---|---|
| 02 | [Étapes](../../modules/02-open-server/README.fr.md#étapes), contrôle du stockage privé | Réseau du compte de stockage : accès public désactivé, points de terminaison privés approuvés |
| 03 | [Étapes](../../modules/03-entra-authentication/README.fr.md#étapes), vérifications opérateur et persona | Terminal : sortie du validateur opérateur, vérification d'Alice |
| 03 | [Retrouver le même résultat dans le portail Azure](../../modules/03-entra-authentication/README.fr.md#retrouver-le-même-résultat-dans-le-portail-azure) | Authentification de la Function, vue d'ensemble de l'inscription, rôles d'application, propriétés de l'application d'entreprise |
| 05 | [Administrateur des identités : approuver la confiance et le consentement](../../modules/05-delegated-and-app-only/README.fr.md#administrateur-des-identités--approuver-la-confiance-et-le-consentement) | Autorisations d'API, information d'identification fédérée sans secret client |
| 06 | [Étape 3 - Interroger le trafic MCP](../../modules/06-observe-inventory/README.fr.md#étape-3---interroger-le-trafic-mcp-dans-application-insights) | Logs d'Application Insights en mode KQL, métadonnées uniquement |
| 06 | [Facultatif - Observability Agent](../../modules/06-observe-inventory/README.fr.md#facultatif---poser-la-même-question-à-lobservability-agent) | Interrupteur **Agent** de Logs : question, KQL générée, mêmes lignes. Facultatif ; à passer si le tenant ne propose pas Azure Copilot |

Chaque validateur affiche une ligne d'objectif, des en-têtes numérotés `== Step N ==` suivis d'une ligne `Why:`,
puis une ligne `PASS`/`FAIL` par contrôle avec le statut HTTP attendu. Lisez les captures du terminal dans cet ordre avec la salle.

## Enseigner une étape à la fois

Avant le module 01, ouvrez **Comprendre MCP et les agents** dans le menu Commencer
([version du dépôt](MCP-CONCEPTS.md)). Expliquez les rôles d'hôte, de client et de serveur, la boucle de l'agent,
puis les outils, les ressources et les prompts.
Posez les questions de prédiction avant de lire la réponse. Cette séquence de concepts n'exécute aucun outil.

Les pages des modules, du contexte Azure et du présentateur affichent une seule étape à la fois.
Demandez aux participants d'expliquer l'objectif et de prévoir le résultat **avant** de copier une commande.
Exécutez un bloc court dans le même terminal, examinez la sortie réelle, puis cliquez sur **Suivant**, en bas de la page.
Ce bouton change seulement de page : il n'exécute rien et ne valide pas l'exercice.

Chaque page se lit de haut en bas : position, contenu, puis les boutons. Pour revenir à une explication, ouvrez le
**Sommaire** sous les boutons. Les blocs longs restent fermés tant qu'on ne les ouvre pas ;
leurs contrôles ne sont jamais découpés automatiquement. Le guide complet et l'architecture restent accessibles dans des sections repliées.
Les longues sections se poursuivent en parties numérotées. Chaque page compte environ 180 mots visibles et s'arrête toujours à la fin d'un élément complet.
Paragraphes, lignes de tableau, éléments de liste imbriqués, blocs exécutables et sections repliables restent intacts.
Les en-têtes des tableaux sont répétés sur les pages suivantes ;
un élément indivisible peut dépasser la cible. Changer de page ne valide pas la précédente.
Ne projetez pas les sorties privées. Faites une pause explicite pour les approbations, l'intervention de l'administrateur des identités et le nettoyage.

Le bouton d'apparence de la barre supérieure ouvre la boîte de dialogue avec les icônes Microsoft et Azure.
Choisissez **Template** (style d'origine, suit les couleurs du système), **Blanc** ou **Sombre**.
Blanc et Sombre utilisent des surfaces neutres avec de petites touches de bleu Azure. Le choix est enregistré dans le navigateur ;
il ne modifie pas le guide partagé et ne déploie rien. Appuyez sur Échap ou sur le bouton de fermeture pour revenir à la leçon.

## Qui déploie quoi

Vous ne pouvez pas déployer dans le tenant des participants, et vous ne devez pas essayer : pas d'identifiant partagé,
pas de clé de déploiement, pas de compte invité dans leur tenant. Chaque participant déploie dans son propre
abonnement de test approuvé.

| Élément | Qui | Où |
|---|---|---|
| Guides partagés sur App Service (actuel) | Présentateur | Uniquement dans un abonnement qui appartient au présentateur (sections 1 à 4). Jamais dans le tenant d'un participant. C'est le cas du portail publié ; la langue se choisit avec `?lang=fr` ou `?lang=en`. |
| Guides partagés sur GitHub Pages (autre option, désactivée aujourd'hui) | Présentateur | Depuis ce dépôt, une fois public. Sans Azure ni accès à un tenant. Voir [HOSTING.md](HOSTING.md). |
| Charge de travail MCP, modules 02 et suivants | Chaque participant | Son propre abonnement et son tenant Microsoft Entra, depuis son propre terminal. |
| Portail personnel prérempli avec son point de terminaison (facultatif) | Chaque participant | Son propre abonnement. Voir [portail participant](HOSTING.md#portail-participant-facultatif-lié-à-votre-déploiement). |

La validation en conditions réelles des modules 02 et suivants se fait dans l'abonnement de chaque participant.
Ses lignes PASS ne valent que pour lui ; ne lui demandez pas d'envoyer des sorties contenant des identifiants de tenant ou d'abonnement.

Si vous partagez le lien GitHub Pages, passez directement au message de la section 4 et à la section 5.
Les sections 1 à 4 ne concernent que l'hébergement de la copie partagée dans votre propre abonnement.

## 1. Préparer votre espace présentateur

Utilisez une copie du dépôt et un état Terraform distincts de ceux des participants.
Utilisez la branche par défaut, `main`, pour votre copie et pour Codespaces.
Avant la session, vérifiez que tout le groupe utilise la même version publiée.
Ne publiez jamais votre compte administrateur, votre tenant, votre abonnement, vos paramètres, votre état ni vos plans sauvegardés.

Suivez les [commandes PowerShell du module 00](../../modules/00-prerequisites/README.fr.md) :
vérifier les outils, préparer les paramètres privés avec un libellé présentateur, sélectionner le contexte de test
approuvé, puis lancer les contrôles du socle. La date d'expiration est une étiquette, pas une suppression automatique.

## 2. Créer seulement le groupe du portail partagé

Depuis la racine du dépôt, dans le même terminal PowerShell connecté :

### 2.1 Initialiser sans déployer

**Pourquoi :** Terraform doit charger les fournisseurs verrouillés avant de calculer un plan.
**Prévoyez :** l'initialisation réussit sans créer de ressource Azure.

```powershell
terraform '-chdir=infra\workload' init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
```

**Observez :** l'initialisation réussit. En cas d'erreur, arrêtez-vous ; ne modifiez pas le fichier de verrouillage pour contourner l'erreur.

### 2.2 Prévoir les modifications

**Pourquoi :** un plan est une proposition, pas un déploiement.
**Prévoyez :** Terraform ajoute un groupe, ou lit un groupe existant approuvé. Aucun service ne doit être créé.

```powershell
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Foundation plan failed.' }
```

**Observez :** le résumé du plan. Commentez les changements proposés avant de continuer.

### 2.3 Examiner le plan sauvegardé

**Pourquoi :** l'accord porte sur ce plan exact, pas sur un nouveau calcul.
**Action :** lisez le groupe cible, les étiquettes et les changements. Gardez ces sorties dans votre terminal privé.

```powershell
terraform '-chdir=infra\workload' show '..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Plan review failed.' }
```

**Observez :** uniquement le socle approuvé. Si un service payant ou une suppression imprévue apparaît, arrêtez-vous.

### 2.4 Appliquer seulement après accord

**STOP : faites approuver cette cible et ce plan exact.** Résultat prévu : un groupe, aucun service.
Terraform ne crée ni ne gère un groupe existant fourni par l'administrateur.
Exécutez cette commande séparée uniquement après approbation :

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Foundation apply failed.' }
```

**Observez :** le groupe approuvé existe, ou le groupe fourni par l'administrateur est réutilisé. Aucun portail n'est encore publié.

## 3. Planifier et publier le portail

Suivez la [procédure App Service](HOSTING.md#portail-public-facultatif-sur-app-service) :
ajoutez `-EnablePublicPortal` aux paramètres d'origine, construisez le contenu public, conservez en privé la preuve
de quota et de coût, lancez les contrôles préalables, examinez le plan, puis publiez le ZIP avec une authentification Entra.

Résultat prévu : **un plan Linux B1 et une application web** dans ce groupe.
Les adresses réelles ont la forme `https://<nom-de-l'application>.azurewebsites.net/?lang=fr#/start` (ou `?lang=en#/start`).
Les chemins `/fr/` et `/en/` renvoient une erreur 404 : la langue se choisit dans la chaîne de requête, pas dans le chemin.
Ce déploiement ne crée ni identité managée, ni application Entra, ni serveur Functions, ni API Management.
La lecture du portail est publique ; le déploiement utilise Microsoft Entra, sans clé de publication.
Le plan B1 reste facturé tant qu'il existe, même si le site est arrêté.
Le plan du portail et son coût demandent une approbation distincte. Conservez la confirmation d'envoi du ZIP.

## 4. Vérifier, puis partager

Après le déploiement, récupérez l'adresse HTTPS réellement créée :

### 4.1 Identifier le site déployé

**Pourquoi :** un nom calculé ne prouve pas qu'un site existe.
**Prévoyez :** l'état Terraform du déploiement renvoie une adresse HTTPS App Service.

```powershell
$portal = terraform '-chdir=infra\workload' output -raw public_portal_url
if ($LASTEXITCODE -ne 0 -or $portal -notmatch '^https://[a-z0-9.-]+\.azurewebsites\.net$') {
    throw 'No valid deployed portal URL.'
}
```

**Observez :** `$portal` contient l'adresse vérifiée dans ce terminal. Ne la partagez pas encore.

### 4.2 Tester le site, pas seulement son adresse

**Pourquoi :** le site peut exister sans servir le contenu attendu.
**Prévoyez :** le contrôle de santé renvoie HTTP 200 et exactement `{"status":"ok"}`.

```powershell
$health = Invoke-WebRequest -Uri "$portal/health" -TimeoutSec 30
if ($health.StatusCode -ne 200 -or $health.Content -cne '{"status":"ok"}') {
    throw 'Portal health check failed.'
}
$health.StatusCode
```

**Observez :** 200, sans erreur. Si le contrôle échoue, cherchez la cause avant tout partage.

### 4.3 Ouvrir les deux langues avant de partager

**Action :** une fois le contrôle de santé réussi, et seulement alors, affichez les deux liens.

```powershell
if (-not $health -or $health.StatusCode -ne 200 -or $health.Content -cne '{"status":"ok"}') { throw 'Check portal health first.' }
"Lien participant (francais) : $portal/?lang=fr#/start"
"Student link (English): $portal/?lang=en#/start"
```

Ouvrez les deux liens. Vérifiez le changement de langue, les modules 00/01 et les schémas avant de les envoyer.
Ne partagez pas une adresse calculée à l'avance ni un site non vérifié.

**Avant de continuer :** demandez à un participant d'expliquer la première action. Si elle n'est pas claire, ne lui envoyez pas un script plus long.

Message prêt à transmettre :

> Ouvrez le lien de l'atelier, choisissez votre langue et votre environnement, puis suivez le module 00.
> Utilisez uniquement votre tenant et votre abonnement de test approuvés. Vous n'avez pas à héberger les guides partagés.
> Vous déployez vous-même le serveur MCP ; si vous le souhaitez, vous pouvez déployer votre propre portail prérempli avec votre point de terminaison.
> Le module 01 fonctionne en local sans Azure. Les modules 02 à 07 se déroulent dans votre abonnement, dans l'ordre du README racine ; le module 99 sert au nettoyage après chaque étape payante.
> Si votre tenant de test vous demande d'enregistrer la MFA à la première connexion, faites-le ; ne désactivez jamais un contrôle de connexion.
> Ne transmettez aucun identifiant de connexion ni jeton.

## 5. Terminer sans laisser de frais inutiles

Chaque participant nettoie ses propres ressources. Le présentateur reste responsable du portail partagé.
Avant la fin de la session, rappelez aux participants de supprimer l'API Management du module 04 le jour même (nettoyage du module 99), car il est facturé à l'heure.
Gardez le portail jusqu'à la fin de la session, puis examinez et faites approuver le
[plan de suppression Terraform](HOSTING.md#nettoyer).
Arrêter le site ne suffit pas à arrêter la facturation du plan.
Conservez les paramètres privés et l'état jusqu'à la confirmation du nettoyage.

## Sources

- [Authentification du déploiement App Service](https://learn.microsoft.com/azure/app-service/deploy-authentication-types).
- [Tarifs App Service Linux](https://azure.microsoft.com/pricing/details/app-service/linux/).
- [Procédure d'hébergement](HOSTING.md).

Dernière vérification : 2026-10-14. Un plan préparé ne prouve pas un déploiement réussi.

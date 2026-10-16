# Présentateur : publier le portail et partager le lien

[English](../PRESENTER.md)

**Vous hébergez les guides. Les participants réalisent leurs propres exercices.**
Publier le portail ne déploie pas le serveur Model Context Protocol (MCP).
Le module 00 est validé ; les modules 01 à 07 et 99 sont rédigés (contrôles hors ligne réussis). Suivez l'ordre d'exécution du [README racine](../../README.md).
Les participants peuvent faire le [module 01](../../modules/01-discover-mcp/README.fr.md) sans attendre votre portail ou un déploiement Azure.

## Qui déploie quoi

Vous ne pouvez pas déployer dans le tenant des participants, et vous ne devez pas essayer : pas d'identifiant partagé,
pas de clé de déploiement, pas de compte invité dans leur tenant. Chaque participant déploie dans son propre
abonnement de test approuvé.

| Élément | Qui | Où |
|---|---|---|
| Guides partagés (par défaut) | Présentateur | GitHub Pages, depuis ce dépôt. Pas d'Azure, aucun accès à un tenant. Voir [HOSTING.md](HOSTING.md). |
| Guides partagés sur App Service (facultatif) | Présentateur | Uniquement dans un abonnement qui appartient au présentateur (sections 1 à 4). Jamais dans le tenant d'un participant. |
| Workload MCP, modules 02 et suivants | Chaque participant | Son propre abonnement et son tenant Microsoft Entra, depuis son propre terminal. |
| Portail personnel prérempli avec son point de terminaison (facultatif) | Chaque participant | Son propre abonnement. Voir [portail participant](HOSTING.md#portail-participant-facultatif-lié-à-votre-déploiement). |

La validation en conditions réelles des modules 02 et suivants se fait dans l'abonnement de chaque participant.
Ses lignes PASS ne valent que pour lui ; ne lui demandez pas d'envoyer des sorties contenant des ID de tenant ou d'abonnement.

Si vous partagez le lien GitHub Pages, passez directement au message de la section 4 et à la section 5.
Les sections 1 à 4 ne concernent que l'hébergement de la copie partagée dans votre propre abonnement.

## 1. Préparer votre espace présentateur

Utilisez une copie du dépôt et un état Terraform distincts de ceux des participants.
Utilisez la branche par défaut, `main`, pour votre copie et pour Codespaces.
Vérifiez que tout le groupe utilise la même version publiée avant la session.
Ne publiez jamais votre compte administrateur, tenant, abonnement, paramètres, état ou plans sauvegardés.

Suivez les [commandes PowerShell du module 00](../../modules/00-prerequisites/README.fr.md) :
vérifier les outils, préparer les paramètres privés avec un libellé présentateur, sélectionner le contexte de test
approuvé, puis lancer les contrôles du socle. La date d'expiration est une étiquette, pas une suppression automatique.

## 2. Créer seulement le groupe du portail partagé

Depuis la racine du dépôt, dans le même terminal PowerShell connecté :

```powershell
terraform '-chdir=infra\workload' init -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Terraform init failed.' }
terraform '-chdir=infra\workload' plan '-var-file=..\..\.workshop\participant.tfvars.json' '-out=..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Foundation plan failed.' }
terraform '-chdir=infra\workload' show '..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Plan review failed.' }
```

**STOP : faites approuver cette cible et ce plan exact.** Résultat prévu : un groupe, aucun service.
Un groupe existant fourni par l'administrateur n'est ni créé ni géré par Terraform.
Seulement après approbation, exécutez cette commande séparée :

```powershell
terraform '-chdir=infra\workload' apply '..\..\.workshop\presenter-foundation.tfplan'
if ($LASTEXITCODE -ne 0) { throw 'Foundation apply failed.' }
```

## 3. Planifier et publier le portail

Suivez la [procédure App Service](HOSTING.md#portail-public-facultatif-sur-app-service) :
ajout de `-EnablePublicPortal` avec les paramètres d'origine, construction du contenu public,
preuve privée de quota et de coût, préflight, examen du plan et publication ZIP authentifiée par Entra.

Résultat prévu : **un plan Linux B1 et une application web** dans ce groupe.
Les adresses réelles suivent la forme `https://<nom-de-l'application>.azurewebsites.net/?lang=fr#/start` (ou `?lang=en#/start`).
Les chemins `/fr/` et `/en/` renvoient 404 : la langue passe par la requête, pas par le chemin.
Ce déploiement ne crée ni identité managée, ni application Entra, ni serveur Functions, ni API Management.
La lecture du portail est publique ; le déploiement utilise Microsoft Entra, sans clé de publication.
Le plan B1 reste facturé tant qu'il existe, même si le site est arrêté.
Le plan du portail et son coût demandent une approbation distincte. Conservez la confirmation d'envoi du ZIP.

## 4. Vérifier, puis partager

Après le déploiement, récupérez l'adresse HTTPS réellement créée :

```powershell
$portal = terraform '-chdir=infra\workload' output -raw public_portal_url
if ($LASTEXITCODE -ne 0 -or $portal -notmatch '^https://[a-z0-9.-]+\.azurewebsites\.net$') {
    throw 'No valid deployed portal URL.'
}
$health = Invoke-WebRequest -Uri "$portal/health" -TimeoutSec 30
if ($health.StatusCode -ne 200 -or $health.Content -cne '{"status":"ok"}') {
    throw 'Portal health check failed.'
}
"Lien participant (francais) : $portal/?lang=fr#/start"
"Student link (English): $portal/?lang=en#/start"
```

Ouvrez les deux liens. Vérifiez le changement de langue, les modules 00/01 et les schémas avant de les envoyer.
Ne partagez pas une adresse calculée à l'avance ou un site non vérifié.

Message prêt à transmettre :

> Ouvrez le lien de l'atelier, choisissez votre langue et votre environnement, puis suivez le module 00.
> Utilisez uniquement votre tenant et votre abonnement de test approuvés. Vous n'avez pas à héberger les guides partagés.
> Vous déployez vous-même le serveur MCP ; si vous le souhaitez, vous pouvez déployer votre propre portail prérempli avec votre point de terminaison.
> Le module 01 fonctionne en local sans Azure. Les modules 02 à 07 se déroulent dans votre abonnement, dans l'ordre du README racine ; le module 99 nettoie après chaque étape payante.
> Ne transmettez aucun identifiant de connexion ni jeton.

## 5. Terminer sans laisser de frais inutiles

Chaque participant nettoie ses propres ressources. Le présentateur reste responsable du portail partagé.
Conservez-le jusqu'à la fin de la session, puis examinez et faites approuver le
[plan de suppression Terraform](HOSTING.md#nettoyer).
Arrêter le site ne suffit pas à arrêter la facturation du plan.
Conservez les paramètres privés et l'état jusqu'à la confirmation du nettoyage.

## Sources

- [Authentification du déploiement App Service](https://learn.microsoft.com/azure/app-service/deploy-authentication-types).
- [Tarifs App Service Linux](https://azure.microsoft.com/pricing/details/app-service/linux/).
- [Procédure d'hébergement](HOSTING.md).

Dernière vérification : 2026-10-14. Un plan préparé ne prouve pas un déploiement réussi.

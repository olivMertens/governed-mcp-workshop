# Publier les guides et déployer les ressources séparément

Le portail public et les services Model Context Protocol (MCP) Azure sont deux déploiements distincts.
Le portail aide à préparer l'environnement. Il ne collecte pas les identifiants Azure, n'accepte aucune clé
de déploiement partagée et ne reçoit aucun accès aux tenants participants.

| Élément | Hébergement conseillé | Frontière d'identité |
|---|---|---|
| Guides EN/FR, schémas et choix d'environnement | GitHub Pages | Contenu statique public, sans connexion Azure ni droit de déploiement. |
| Copie interne facultative des guides | Une application App Service **ou** Azure Container Apps désignée | Hébergement, accès mono-tenant et coûts à examiner séparément. |
| Ressources MCP participant | Abonnement et groupe non-production approuvés du participant | Terraform exécuté depuis son terminal authentifié, après revue du plan. |

App Service et Azure Container Apps (ACA) sont des services différents.
Y héberger le portail ne déploie pas le workshop. L'architecture MCP reste Azure Functions derrière API Management ;
elle ne devient pas automatiquement une application ACA.

## Construire le portail

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
Le site lit son JSON statique. La préparation de connexion reste en mémoire ; les vrais appels restent dans le client.

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

## Héberger les guides dans un tenant

La même sortie statique peut être servie par une application App Service ou ACA existante et approuvée.
Avant le déploiement, désignez ressource exacte, abonnement, groupe, runtime/image, règles réseau et authentification,
propriété du contenu existant, coûts et retour arrière. Ne remplacez pas une application et ne créez ni accès,
permission ou configuration Entra sans approbation explicite. Pas d'application de production comme raccourci.

Pour un portail privé, examinez l'authentification Entra intégrée supportée par le service choisi,
les règles d'accès et les paramètres mono-tenant d'émetteur/audience. Un écran de connexion ne suffit pas.
Identité managée pour l'accès applicatif autorisé ; fédération OpenID Connect (OIDC) pour un pipeline approuvé.
Pas de profil de publication copié, de clé permanente ou de secret client.
La référence ACA montre aussi une configuration avec secret client : ne l'exécutez pas.
Un parcours de connexion au portail privé sans secret n'est pas encore établi et reste un prérequis bloquant.
Les identifiants réels et la résolution de cible restent dans la session privée de déploiement, pas ce dépôt public.
Aucune connexion Azure de l'auteur ni découverte/modification d'applications pendant cette préparation.

## Ressources du participant

Suivez [le choix d'environnement](GETTING-STARTED.md) puis [le contexte Azure](DEPLOYMENT.md).
Le participant se connecte à son tenant dans son terminal ou dev container, garde suffixe aléatoire et état privé,
puis examine le plan destiné à son groupe. Rôles Azure et consentement Entra sont distincts.
Une automatisation propre au participant nécessite sa fédération limitée et ses approbations ;
le portail public ne devient pas une console de déploiement multi-tenant.

Seul le socle Terraform groupe de ressources existe actuellement. Functions, identité, passerelle et observabilité
ne sont pas encore implémentés ni validés. Aucun bouton « tout déployer » ni fausse sortie de clé/adresse.
La clé système temporaire du module 02 est saisie uniquement dans le client, à l'exécution :
jamais dans le portail, URL, chat, sortie publique ou configuration sauvegardée.

## Sources

- [Workflows Pages officiels](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
- [Source de publication Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
- [OIDC GitHub vers Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure).
- [Authentification App Service](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization), [authentification ACA](https://learn.microsoft.com/azure/container-apps/authentication).
- [Références](REFERENCES.md), [droits sur les images](../../assets/architecture/README.fr.md).

Dernière vérification : 2026-10-14. Préparation statique uniquement, sans publication ni déploiement Azure.

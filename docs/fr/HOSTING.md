# Publier les guides sur GitHub Pages

[English](../HOSTING.md)

**GitHub Pages est le seul site publié pour cet atelier.** Ne déployez pas de copie des guides sur
Azure App Service ou Azure Container Apps. Les notes du présentateur et les outils de construction restent
dans le dépôt et dans l'interface locale des auteurs.

Le site web et les ressources Model Context Protocol (MCP) ont des rôles différents :

| Élément | Emplacement | Responsabilité |
|---|---|---|
| Guides participants français et anglais, animations et instructions de test | GitHub Pages | Le responsable publie le contenu relu. Le site n'a aucun identifiant Azure ni droit de déploiement. |
| Notes du présentateur et outils de construction | Dépôt et interface locale | Réservés aux auteurs ; exclus des données publiques du parcours. |
| Serveur MCP, passerelle et services en aval | Abonnement Azure de test approuvé du participant | Chaque participant déploie, vérifie et supprime ses propres ressources. |

Le site n'exécute aucun test MCP. Les participants utilisent Visual Studio Code ou MCP Inspector sur leur
ordinateur. Le champ d'adresse prépare seulement des commandes dans la mémoire du navigateur.
Il n'est pas prérempli depuis Azure ; l'adresse n'est ni enregistrée ni envoyée au serveur.
Consultez le [guide de test](PRACTICE.md).

## Construire le site localement

Depuis la racine du dépôt, avec Node.js 22.19.0 ou plus récent :

```powershell
node --test scripts/site.test.mjs
if ($LASTEXITCODE -ne 0) { throw 'Site checks failed.' }
node scripts/build-site.mjs
if ($LASTEXITCODE -ne 0) { throw 'Site build failed.' }
```

```bash
node --test scripts/site.test.mjs && node scripts/build-site.mjs
```

Git ignore le dossier `site-dist`. Le script refuse d'écraser un dossier existant.
Pour reconstruire, utilisez `--output` avec un nouveau dossier. Examinez une ancienne sortie avant de supprimer
ce dossier précis. Prévisualisez le résultat avec un serveur HTTP local, pas avec une URL `file://`.

L'export ne contient que les fichiers statiques autorisés : HTML, libellés français, parcours public, schémas
et captures. Il exclut les identifiants, les paramètres privés, l'état Terraform, l'API locale des auteurs
et les documents de construction. Le registre technique des sources (`#/sources`) reste réservé aux auteurs :
son URL publique affiche une page introuvable. Les liens vers les sources des modules, les consignes de sécurité,
les commandes et les résultats attendus restent disponibles.

Les deux langues et les deux parcours utilisent le même lecteur. Les modules 01 à 07 donnent un accès direct
à leur schéma animé. Le marqueur `<!-- module-animations -->` est remplacé par ces animations.
Les blocs `<!-- author-only -->` sont exclus du texte public ; le code reste intact.

## Publier sur GitHub Pages

1. Ajoutez les modifications à l'index Git, puis régénérez `setup-workshop-mcp.ps1` avec `node scripts/sync-scaffold.mjs`.
   Incluez ce fichier dans le commit relu. Le workflow vérifie qu'il correspond aux fichiers suivis par Git.
2. Fusionnez les changements relus dans `main`. Vérifiez que le dépôt est public et ne contient rien de privé.
3. Ouvrez **Actions → Publish workshop guides → Run workflow**, sur `main`.
4. Attendez la réussite des tâches **build** et **deploy**. La publication est manuelle, pas automatique après fusion.
5. Vérifiez les pages françaises et anglaises, les deux parcours, les commandes copiées et les animations.

- [Lien participant en français](https://olivmertens.github.io/governed-mcp-workshop/?lang=fr#/start)
- [Lien participant en anglais](https://olivmertens.github.io/governed-mcp-workshop/?lang=en#/start)

Le workflow utilise une identité GitHub Pages de courte durée, sans compte Azure ni secret client.
Dans **Settings → Pages → Source**, choisissez **GitHub Actions**. Vérifiez la visibilité autorisée,
l'offre GitHub de votre organisation et ses limites d'utilisation ; toutes les offres ne sont pas gratuites.

## Supprimer une ancienne copie Azure

L'hébergement Azure des guides a été retiré le 2026-10-21. Cette procédure de migration ne fait pas partie
des exercices participants. Ne lancez pas une application Terraform ordinaire pour retirer un ancien portail :
le même état peut contenir les ressources MCP.

1. Conservez les paramètres privés, le suffixe et l'état d'origine. Sauvegardez l'état en privé.
2. Retrouvez l'application web du portail et son plan App Service exacts dans cet état.
   Vérifiez le propriétaire, l'abonnement, le groupe et l'absence d'autre application sur ce plan.
3. Après approbation explicite de la suppression, préparez un plan de destruction ciblé et enregistré pour
   `azurerm_linux_web_app.portal[0]` et `azurerm_service_plan.portal[0]` uniquement.
   Le ciblage sert ici à une migration exceptionnelle, pas au déploiement habituel de l'atelier.
4. Examinez ce plan en privé. Il doit supprimer uniquement les ressources approuvées du portail, sans ajout,
   mise à jour, suppression de groupe ni changement MCP ou d'identité. Arrêtez-vous si le plan diffère.
5. Faites approuver ce plan précis, appliquez le plan enregistré, puis vérifiez l'absence des deux ressources
   dans Azure et des deux adresses dans l'état. Arrêter ou supprimer seulement le site ne retire pas un plan payant.
6. Après vérification, retirez la clé obsolète `public_portal_enabled` des fichiers privés de paramètres.
   Ne changez aucune autre valeur et ne régénérez pas les noms. Examinez les chemins exacts avant de supprimer
   les anciens paquets et plans de déploiement. N'appliquez jamais un ancien plan du portail.

Si la copie a été créée hors de cet état, demandez à son propriétaire de supprimer ces ressources précises.
N'importez pas de plan partagé, ne supprimez pas de groupe, n'élargissez pas les droits et ne jetez pas l'état
pour contourner un contrôle en échec.

## Nettoyer

GitHub Pages ne nécessite aucune ressource Azure de l'atelier. Pour retirer le site, utilisez les paramètres Pages du dépôt.
Pour les ressources MCP, suivez le [module 99](../../modules/99-cleanup/README.fr.md) avec les mêmes paramètres privés
et le même état. Préservez les groupes et les identités fournis par l'administrateur.

## Sources

- [Workflows GitHub Pages](https://docs.github.com/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
- [Plans App Service et facturation](https://learn.microsoft.com/azure/app-service/overview-hosting-plans).
- [Destruction Terraform et ciblage exceptionnel](https://developer.hashicorp.com/terraform/cli/commands/destroy).

Dernière vérification : 2026-10-21. Publier les guides ne valide pas le déploiement d'un participant.

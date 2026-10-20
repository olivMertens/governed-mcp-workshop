# Schémas modifiables de l'atelier

Pour comprendre une étape, consultez d'abord le schéma de son module.
Cette page s'adresse aux personnes qui modifient ou republient les schémas.

`workshop.drawio` est le fichier source commun des modules : neuf modules, chacun avec une page anglaise et une page française.
Les fichiers `NN.en.svg` / `NN.fr.svg` et PNG correspondants sont générés et ne sont jamais retouchés séparément.
`session2.drawio` est la source distincte de la vue d'ensemble de la séquence 2 (pages `session2.en` et `session2.fr`).
Le même script et les mêmes contrôles produisent `session2.en.svg` / `session2.fr.svg` et leurs PNG ; il n'a pas de guide Mermaid.
Les guides `STEPS.md` et `STEPS.fr.md` reprennent les mêmes composants, liens et périmètres en Mermaid.
Pour suivre l'atelier, ouvrez les [schémas étape par étape](STEPS.fr.md).
Tous montrent une **cible prévue**, pas une infrastructure déjà déployée.
Chaque cadre en pointillés délimite un périmètre nommé : poste local, identité ou ressources Azure.
Les lignes numérotées sont des vues liées de la même étape, pas des ressources déployées en double.
Les flux de requêtes, d'identité, d'observation et d'administration sont représentés séparément. Le module 05 représente Storage ;
Graph exige un autre jeton, émis pour sa propre audience.

Pour les modifier, les mainteneurs suivent [la compétence de schémas d'architecture](../../.github/skills/architecture-diagram-author/SKILL.md)
(en anglais), que l'agent de construction des modules charge lorsqu'un module modifie une architecture représentée.

## Reproduire les exports

<details>
<summary>Pour aller plus loin : outils et commandes de génération</summary>

Pour générer les PNG, il faut Python 3, le paquet Python `playwright` et une installation existante de Chromium ou Edge.
Installez le paquet avec `python -m pip install playwright==1.62.0`. Aucun paquet ni navigateur n'est installé automatiquement.
La génération SVG seule et `--check` utilisent uniquement la bibliothèque standard de Python.
Le générateur local gère le sous-ensemble mxGraph utilisé : texte simple, rectangles à angles droits, périmètres en pointillés,
SVG incorporés, coordonnées des parents et routage orthogonal ancré. Un style non pris en charge provoque une erreur.
Ce n'est pas un remplaçant de l'exporteur draw.io. Draw.io Desktop n'était pas disponible ; Edge convertit le SVG local en PNG, hors ligne.

```powershell
python .\scripts\render-architecture.py --browser 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
```

```bash
python3 ./scripts/render-architecture.py --browser "$(command -v chromium)"
```

Indiquez le chemin réel de votre navigateur. `--svg-only` régénère les SVG sans navigateur mais **pas les PNG**.
Régénérez les deux avant publication. Examinez les PNG et le tableau après toute modification de la disposition.
`python .\scripts\render-architecture.py --check` vérifie la cohérence sans navigateur ni modification des exports.
Chaque PNG contient l'empreinte SHA-256 de son SVG source ; une paire désynchronisée fait échouer le contrôle au lieu de passer inaperçue.
Contrôles effectués : segments orthogonaux complets, traversée de composants sans rapport, croisements et chevauchements d'arêtes, écart de 16 pixels
entre arêtes parallèles, arrivée perpendiculaire des flèches, place suffisante pour le texte et icônes intégrées au SVG.

La même commande régénère les deux guides Mermaid. `--check` refuse aussi un texte Mermaid qui n'est plus à jour.
Mermaid conserve les liens et les périmètres, pas la position exacte des éléments ni les icônes Microsoft.
GitHub affiche directement ses blocs Mermaid. Dans l'application et le portail, chaque bloc publié s'affiche
sous la forme du SVG correspondant, avec ses icônes et son tracé vérifiés, sans bibliothèque Mermaid ni service externe.
Un bloc inconnu provoque une erreur explicite : ce n'est pas un éditeur de schémas généraliste.
Le code Mermaid de chaque module reste dans une section repliée par défaut, avec un bouton de copie.
Les README du module 99 reprennent aussi le bloc généré dans une section repliable pour GitHub.
Après toute modification de l'architecture du module 99, recopiez le bloc 99 de chaque guide `STEPS` dans le README correspondant ;
`node --test scripts/site.test.mjs` échoue à la moindre divergence, dans les deux langues.
Après chaque modification, régénérez les exports, examinez les PNG et vérifiez les deux langues avant publication.

</details>

## Encadrés dans les README

Utilisez les alertes GitHub : `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`.
Séparez les paragraphes, listes et blocs de code par une ligne citée vide (`>`).
GitHub conserve ces blocs, tout comme le moteur d'affichage commun au tableau de bord et au portail.
L'application ajoute une icône décorative, un libellé traduit et une couleur distincte par type.
Les citations restent des citations ; le HTML arbitraire s'affiche comme du texte, sans être interprété.
Le [guide de nettoyage](../../modules/99-cleanup/README.fr.md) sert d'exemple bilingue.
La mise en forme ne prouve ni un déploiement ni la réussite du nettoyage.

Tous les blocs de code hors Mermaid proposent un bouton de copie commun, y compris JSON et texte simple.
Le code est copié à l'identique, sans traduction ni exécution.
Les blocs de commandes rappellent qu'il faut relire les commandes et remplacer les valeurs d'exemple dans votre propre terminal.
Si l'accès au presse-papiers est refusé, une consigne de copie manuelle s'affiche.
Le [guide du contexte Azure](../../docs/fr/DEPLOYMENT.md) fournit les commandes de lecture et les liens vers les portails ;
les résultats et les identifiants restent dans le terminal du participant, jamais dans l'interface partagée.

## Provenance et droits

L'[inventaire détaillé](README.md) fournit chaque adresse de téléchargement et chaque chemin officiel.
Consulté le 2026-10-14 : [az-icons.com](https://az-icons.com/) est le premier catalogue utilisé, miroir communautaire
du pack Azure de juillet 2026, **non publié par Microsoft**. Les six icônes de services ont été rapprochées des noms
du pack officiel V24. Pour Entra ID et les logos exacts manquants, la source de repli
[MsiconsCollections](https://aka.ms/MsiconsCollections) renvoie vers [Microsoft Icon Collections](https://tomkiljo.github.io/ms-icons/).
Les chemins ont été vérifiés dans son index. Entra ID utilise le pack couleur d'octobre 2023.
Les logos Azure et Microsoft proviennent de la collection UX ; ce ne sont pas des icônes de service V24.

Consulté le 2026-10-16, pour la liste des services du module 07 dans le tableau de bord (pas dans les schémas) :
l'icône Foundry Agent Service a été repérée sur az-icons.com, mais le fichier conservé est extrait tel quel de
l'archive officielle V24. Copilot Studio n'est pas un service Azure : az-icons.com ne le propose pas et
MsiconsCollections n'offre qu'un logo Copilot générique, qu'il ne faut pas renommer. Son icône vient du
[pack officiel Power Platform](https://learn.microsoft.com/power-platform/guidance/icons) (mise à jour de décembre 2025).

Microsoft conserve les droits. Les icônes d'architecture Azure, Entra et Power Platform sont autorisées dans les schémas, la formation
et la documentation selon leurs conditions, **pas sous la licence MIT du dépôt**.
Les logos d'entreprise restent soumis aux règles de marques Microsoft ; ce dépôt n'accorde aucune autorisation générale.
Avant toute publication ou action marketing, vérifiez l'autorisation applicable à votre diffusion.
Conservez les couleurs, les proportions et les noms. Les marques désignent les technologies utilisées, pas l'atelier.
Cet atelier indépendant n'est ni approuvé ni sponsorisé par Microsoft.

## Sources

- [Conditions des icônes Azure](https://learn.microsoft.com/azure/architecture/icons/).
- [Archive officielle V24](https://arch-center.azureedge.net/icons/Azure_Public_Service_Icons_V24.zip).
- [Conditions et pack Entra](https://learn.microsoft.com/entra/architecture/architecture-icons).
- [Conditions et pack Power Platform](https://learn.microsoft.com/power-platform/guidance/icons).
- [Règles de marques Microsoft](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks).
- [Source et inventaire exacts](README.md), [plan technique](../../docs/BUILD-PLAN.md).
- [Affichage des schémas sur GitHub](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams).

Dernière vérification : 2026-10-14.

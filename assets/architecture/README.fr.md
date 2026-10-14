# Schémas modifiables de l'atelier

Pour comprendre une étape, consultez d'abord le schéma dans son module.
Cette page s'adresse aux personnes qui modifient ou republient les schémas.

`workshop.drawio` est le fichier source commun : neuf modules, chacun avec une page anglaise et une page française.
Les fichiers `NN.en.svg` / `NN.fr.svg` et PNG correspondants sont générés, jamais retouchés séparément.
Les guides `STEPS.md` et `STEPS.fr.md` reprennent les mêmes composants, liens et périmètres en Mermaid.
Pour suivre l'atelier, ouvrez les [schémas étape par étape](STEPS.fr.md).
Tous montrent une **cible prévue**, pas une infrastructure déjà déployée.
Les cadres en pointillés désignent le périmètre nommé : poste local, identité ou ressources Azure.
Les lignes numérotées sont des vues liées de la même étape, pas des ressources déployées en double.
Requêtes, identité, observation et administration sont séparées. Le module 05 représente Storage ;
Graph exige un autre jeton pour sa propre audience.

## Reproduire les exports

<details>
<summary>Pour aller plus loin : outils et commandes de génération</summary>

Pour les PNG : Python 3, le paquet Python `playwright` et une installation existante de Chromium ou Edge.
Installez le paquet avec `python -m pip install playwright==1.62.0`. Aucun paquet ni navigateur n'est installé automatiquement.
La génération SVG seule et `--check` utilisent uniquement la bibliothèque standard de Python.
Le générateur local gère le sous-ensemble mxGraph utilisé : texte simple, rectangles carrés, périmètres pointillés,
SVG incorporés, coordonnées des parents et routage orthogonal ancré. Un style non pris en charge provoque une erreur.
Ce n'est pas un exporteur draw.io général. Draw.io Desktop était absent ; Edge rasterise le SVG local hors ligne.

```powershell
python .\scripts\render-architecture.py --browser 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
```

```bash
python3 ./scripts/render-architecture.py --browser "$(command -v chromium)"
```

Indiquez le chemin réel de votre navigateur. `--svg-only` régénère les SVG sans navigateur mais **pas les PNG**.
Régénérez les deux avant publication. Examinez les PNG et le tableau après un changement de disposition.
`python .\scripts\render-architecture.py --check` vérifie la cohérence sans navigateur ni modification des exports.
Chaque PNG contient l'empreinte SHA-256 de son SVG source ; une paire périmée provoque un échec.
Contrôles : segments complets, traversée de composants, intersections et recouvrement d'arêtes, écart parallèle
de 16 pixels, approche perpendiculaire des flèches, capacité du texte et icônes autonomes.

La même commande régénère les deux guides Mermaid. `--check` refuse aussi un guide devenu incohérent.
Mermaid conserve les liens et les périmètres, pas la position exacte des éléments ni les icônes Microsoft.
GitHub affiche directement ses blocs Mermaid. Dans l'application et le portail, chaque bloc publié affiche
le SVG correspondant, avec ses icônes et son tracé vérifiés, sans bibliothèque Mermaid ni service externe.
Un bloc inconnu provoque une erreur explicite : ce n'est pas un éditeur de schémas généraliste.
Le code Mermaid de chaque module reste dans une section fermée au départ, avec un bouton de copie.
Après une modification, régénérez, examinez les PNG et vérifiez les deux langues avant publication.

</details>

## Provenance et droits

L'[inventaire détaillé](README.md) fournit chaque adresse de téléchargement et chemin officiel.
Consulté le 2026-10-14 : [az-icons.com](https://az-icons.com/) est le premier catalogue utilisé, miroir communautaire
du pack Azure de juillet 2026, **pas un éditeur Microsoft**. Les six icônes de services ont été rapprochées des noms
du pack officiel V24. Pour Entra ID et les logos exacts manquants, le repli
[MsiconsCollections](https://aka.ms/MsiconsCollections) renvoie vers [Microsoft Icon Collections](https://tomkiljo.github.io/ms-icons/).
Les chemins ont été vérifiés dans son index. Entra ID utilise le pack couleur d'octobre 2023.
Les logos Azure et Microsoft viennent de la collection UX, sans prétendre être des icônes de service V24.

Microsoft conserve les droits. Les icônes d'architecture Azure et Entra sont permises dans les schémas, la formation
et la documentation selon leurs conditions, **pas sous la licence MIT du dépôt**.
Les logos d'entreprise restent soumis aux règles de marques Microsoft ; ce dépôt n'accorde pas de permission générale.
Vérifiez la permission applicable à votre diffusion avant publication ou marketing.
Conservez les couleurs, les proportions et les noms. Les marques identifient les technologies, pas l'atelier.
Cet atelier indépendant n'est ni approuvé ni sponsorisé par Microsoft.

## Sources

- [Conditions des icônes Azure](https://learn.microsoft.com/azure/architecture/icons/).
- [Archive officielle V24](https://arch-center.azureedge.net/icons/Azure_Public_Service_Icons_V24.zip).
- [Conditions et pack Entra](https://learn.microsoft.com/entra/architecture/architecture-icons).
- [Règles de marques Microsoft](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks).
- [Source et inventaire exacts](README.md), [plan technique](../../docs/BUILD-PLAN.md).
- [Affichage des schémas sur GitHub](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams).

Dernière vérification : 2026-10-14.

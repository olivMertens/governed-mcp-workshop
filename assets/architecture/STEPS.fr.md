# L'architecture, étape par étape

Ces schémas montrent les objectifs du parcours, pas des déploiements réalisés. Consultez le suivi de construction pour les preuves de validation.

Le protocole de contexte de modèle (MCP) relie un client à des outils. Chaque étape ajoute un contrôle ou explique une responsabilité.

[Ce qui est réellement disponible](../../docs/fr/IMPLEMENTATION-STATUS.md). [Modifier les schémas et vérifier les icônes](README.fr.md).

Fichier généré depuis `workshop.drawio` : ne le modifiez pas séparément. Les cadres représentent des périmètres ; les vues répétées désignent le même environnement. GitHub affiche Mermaid ; l'application affiche le SVG équivalent avec ses icônes et son routage vérifiés.

## 00 - Préparer les identités et les ressources

L'autorité Entra et les droits Azure sont distincts. Ni appel MCP ni création de ressources ici.

[SVG](00.fr.svg) · [PNG](00.fr.png)

```mermaid
flowchart LR
  %% Préparation des identités - administration
  %% Préparation des ressources - aucun déploiement
  n_node_0_0["Admin identité / Périmètre approuvé"]
  n_node_0_2["Clients publics / Retours exacts"]
  n_node_1_0["Opérateur Azure / Budget de test"]
  n_node_1_2["Précontrôle / Droits et coût"]
  subgraph boundary_0["Tenant Microsoft Entra"]
    n_node_0_1["Microsoft Entra ID / Apps et consentement"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Azure : ressources de test"]
    n_node_1_1["Abonnement Azure / Groupe de ressources"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Revue"| n_node_0_1
  n_node_0_1 -->|"Approuver"| n_node_0_2
  n_node_1_0 -->|"Choisir / vérifier"| n_node_1_1
  n_node_1_1 -->|"Contrôler"| n_node_1_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_2 fill:#ffffff,stroke:#1659dc,color:#172c48
```

## 01 - Découvrir et appeler en local

Découverte et exécution diffèrent. Accord humain pour chaque écriture. Négocier le protocole supporté.

[SVG](01.fr.svg) · [PNG](01.fr.png)

```mermaid
flowchart LR
  %% Processus locaux - aucun déploiement Azure
  subgraph boundary_0["Poste de travail local"]
    n_node_0_0["Client MCP / VS Code / Inspector"]
    n_node_0_1["Serveur MCP local / Transport stdio"]
    n_node_0_2["Outil synthétique / Accord explicite"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Lister / appeler"| n_node_0_1
  n_node_0_1 -->|"Exécuter"| n_node_0_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#ffffff,stroke:#1659dc,color:#172c48
```

## 02 - Une clé partagée n'est pas une identité

Aucun accès anonyme. Outils d'identité simulés jusqu'à 05. Garder cette étape par clé très brève.

[SVG](02.fr.svg) · [PNG](02.fr.png)

```mermaid
flowchart LR
  %% Démonstration brève par clé - votre abonnement de test
  n_node_0_0["Client MCP / Clé système"]
  subgraph boundary_0["Azure : ressources de test"]
    n_node_0_1["Azure Functions / Protection System"]
    n_node_0_2["Azure Storage / File synthétique"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"MCP + clé"| n_node_0_1
  n_node_0_1 -->|"Écriture approuvée"| n_node_0_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 03 - Se connecter, puis appeler la ressource protégée

401 sans jeton MCP valide. Eve non affectée. Aucun jeton réel dans journaux, chat, fichiers ou sites.

[SVG](03.fr.svg) · [PNG](03.fr.png)

```mermaid
flowchart LR
  %% 1. Identité - Entra remet le jeton au client
  %% 2. Requête - découverte PRM en Preview
  n_node_0_0["Client MCP / App publique validée"]
  n_node_0_2["Même client MCP / Jeton destiné à MCP"]
  n_node_1_0["Client MCP / Audience MCP"]
  subgraph boundary_0["Tenant Microsoft Entra"]
    n_node_0_1["Microsoft Entra ID / Utilisateurs affectés"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Azure : ressources de test"]
    n_node_1_1["Azure Functions / Validation plateforme"]
    n_node_1_2["Lecture synthétique / Étendue et rôle"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Connexion"| n_node_0_1
  n_node_0_1 -->|"Émettre le jeton"| n_node_0_2
  n_node_1_0 -->|"Jeton MCP"| n_node_1_1
  n_node_1_1 -->|"Autoriser"| n_node_1_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_2 fill:#ffffff,stroke:#1659dc,color:#172c48
```

## 04 - Seule la passerelle gouvernée accepte les clients

Accès public Function désactivé. DNS privé et intégration sortante. 403 Bob / 429 débit. API de gestion MCP : Preview.

[SVG](04.fr.svg) · [PNG](04.fr.png)

```mermaid
flowchart LR
  %% Requête - APIM et Functions protègent une seule ressource MCP
  n_node_0_0["Client MCP / Jeton destiné à MCP"]
  subgraph boundary_0["Azure : ressources de test"]
    n_node_0_1["API Management / Standard v2"]
    n_node_0_2["Azure Functions / Accès privé"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Jeton MCP"| n_node_0_1
  n_node_0_1 -->|"Réseau privé"| n_node_0_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 05 - Deux identités cibles, deux contrôles de droits

Ne jamais transmettre le jeton MCP à Storage ou Graph. Jeton Graph distinct. Un 403 cible peut être dans HTTP 200.

[SVG](05.fr.svg) · [PNG](05.fr.png)

```mermaid
flowchart LR
  %% Contexte utilisateur - On-Behalf-Of (OBO)
  %% Contexte applicatif - identité managée (MI)
  n_node_0_0["Client MCP / Alice / Bob"]
  n_node_1_0["Client MCP / Alice / Bob"]
  subgraph boundary_0["Azure : ressources de test"]
    n_node_0_1["API Management / Contrôle du rôle MCP"]
    n_node_0_2["Azure Functions / Échange OBO"]
    n_node_0_3["Azure Storage / RBAC utilisateur"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Azure : ressources de test"]
    n_node_1_1["API Management / Contrôle du rôle MCP"]
    n_node_1_2["Azure Functions / MI explicite"]
    n_node_1_3["Azure Storage / Rôle MI du conteneur"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Jeton MCP"| n_node_0_1
  n_node_0_1 -->|"Jeton MCP"| n_node_0_2
  n_node_0_2 -->|"Jeton Storage / Utilisateur"| n_node_0_3
  n_node_1_0 -->|"Jeton MCP"| n_node_1_1
  n_node_1_1 -->|"Jeton MCP"| n_node_1_2
  n_node_1_2 -->|"Jeton Storage / Application"| n_node_1_3
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_3 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_3 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 06 - Requêtes, observation et inventaire sont séparés

Seulement outil, ID objet appelant, statut, latence et corrélation. API Center n'autorise ni ne relaie les appels.

[SVG](06.fr.svg) · [PNG](06.fr.png)

```mermaid
flowchart LR
  %% 1. Requête à l'exécution - URL gouvernée uniquement
  %% 2. Observation - aucune copie du corps
  %% 3. Inventaire - enregistrement administratif, pas de routage
  n_node_0_0["Client MCP / Appel approuvé"]
  n_node_2_0["Inscrire la passerelle / URL approuvée"]
  subgraph boundary_0["Azure : ressources de test"]
    n_node_0_1["API Management / Valider / autoriser"]
    n_node_0_2["Azure Functions / Accès privé"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Azure : ressources de test"]
    n_node_1_0["Même passerelle / Appelant authentifié"]
    n_node_1_1["Application Insights / Zéro octet de corps"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_2["Azure : ressources de test"]
    n_node_2_1["Azure API Center / Aucun droit accordé"]
  end
  style boundary_2 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"MCP"| n_node_0_1
  n_node_0_1 -->|"Réseau privé"| n_node_0_2
  n_node_1_0 -->|"Métadonnées seules"| n_node_1_1
  n_node_2_0 -->|"Inventaire"| n_node_2_1
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_2_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_2_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 07 - Les clients facultatifs utilisent la même frontière

Aucun agent déployé ici. Vérifier licences, Preview et accès sans secret. Reporter tout flux exigeant un secret.

[SVG](07.fr.svg) · [PNG](07.fr.png)

```mermaid
flowchart LR
  %% Démonstration prévue - certains flux Foundry en Preview
  n_node_0_0["Client MCP facultatif / Utilisateur ou app"]
  subgraph boundary_0["Azure : ressources de test"]
    n_node_0_1["API Management / Mêmes contrôles"]
    n_node_0_2["Azure Functions / Accès privé"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Identité approuvée"| n_node_0_1
  n_node_0_1 -->|"Réseau privé"| n_node_0_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#eaf0ff,stroke:#1659dc,color:#172c48
```

## 99 - Retirer les ressources du workshop, préserver le reste

Ressources d'abord, puis objets Entra créés. Vérifier rôles, DNS privé, inventaire, rétention et codespaces.

[SVG](99.fr.svg) · [PNG](99.fr.png)

```mermaid
flowchart LR
  %% 1. Nettoyage des ressources - après accord explicite
  %% 2. Nettoyage des identités - préserver les objets fournis
  n_node_0_0["Vérifier la propriété / Vrai plan destroy"]
  n_node_0_2["Vérifier l'inventaire / Coûts et rétention"]
  n_node_1_0["Admin identité / Revoir les créations"]
  n_node_1_2["Préserver l'existant / Comptes / apps"]
  subgraph boundary_0["Azure : ressources de test"]
    n_node_0_1["Abonnement Azure / Retrait des ressources"]
  end
  style boundary_0 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  subgraph boundary_1["Tenant Microsoft Entra"]
    n_node_1_1["Microsoft Entra ID / Objets du workshop"]
  end
  style boundary_1 fill:#ffffff,stroke:#526783,stroke-dasharray:8 6
  n_node_0_0 -->|"Approuver"| n_node_0_1
  n_node_0_1 -->|"Vérifier"| n_node_0_2
  n_node_1_0 -->|"Approuver le périmètre"| n_node_1_1
  n_node_1_1 -->|"Vérifier"| n_node_1_2
  style n_node_0_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_0_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_0_2 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_0 fill:#ffffff,stroke:#1659dc,color:#172c48
  style n_node_1_1 fill:#eaf0ff,stroke:#1659dc,color:#172c48
  style n_node_1_2 fill:#ffffff,stroke:#1659dc,color:#172c48
```

## Sources

- [Draw.io](workshop.drawio).
- [GitHub Mermaid](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams).
- [Mermaid flowcharts](https://mermaid.js.org/syntax/flowchart.html).

Dernière vérification : 2026-10-14.

# Ce qui est réellement disponible

Le dépôt contient l'atelier complet : code de préparation, exercice MCP local, modules 02 à 07 et module 99.
Le [suivi de construction](../PROGRESS.md) indique les contrôles réalisés. **Les modules 00 et 02 sont validés en conditions réelles.**
Les modules 03 à 06 ont réussi leurs vérifications opérateur dans le tenant de test de l'auteur (2026-10-17 et 2026-10-18),
mais restent au statut `authored` tant que les vérifications d'Alice, Bob et Eve ne sont pas réussies.
Les comptes de test doivent parfois d'abord enregistrer l'authentification multifacteur (MFA).

| Élément | Disponible dans cette branche | Reste à faire |
|---|---|---|
| Environnement participant | Vérification des outils, choix explicite du tenant et de l'abonnement, noms stables et état individuel | Exécuter le conteneur et valider une cible Azure approuvée |
| Portail documentaire public | Application bilingue, Terraform App Service et script de déploiement avec contrôles ; publié sur App Service dans l'abonnement du présentateur (contrôle de santé et liens `?lang=fr` / `?lang=en` réussis) | Renouveler la revue de capacité (moins de 24 heures) avant chaque redéploiement |
| Découverte MCP locale, module 01 | Serveur stdio .NET 10, contrôles SDK et Inspector, guide EN/FR et configuration VS Code | Observer l'approbation par appel ; le jalon d'environnement précédent reste ouvert |
| Serveur MCP ouvert, module 02 | **Validé en conditions réelles (2026-10-16).** Serveur MCP Functions .NET 10 avec cinq outils synthétiques, tests unitaires, Terraform Flex/Storage/télémétrie/identité désactivé par défaut avec tests simulés, stockage privé en option (`mcp_private_storage`), guide EN/FR, validateur et nettoyage ciblé | Chaque participant refait la validation dans son propre abonnement |
| Identité Entra, module 03 | Racine `infra/entra` (inscription, scope, trois rôles d'application, attribution obligatoire, VS Code et Azure CLI préautorisés, attributions pour des comptes existants) et option d'authentification intégrée désactivée par défaut, avec métadonnées de ressource protégée (**Preview**), tests simulés, guide EN/FR, validateur et nettoyage ciblé. Vérifications opérateur réussies en conditions réelles ; vérification d'Alice réussie (2026-10-19) | Vérifications de Bob (HTTP 200) et d'Eve (refus), après leur enregistrement MFA |
| Passerelle gouvernée, module 04 | Option API Management Standard v2 désactivée par défaut : API de serveur MCP (**Preview**), stratégie de jeton Entra et rôle par outil, limite de débit par `oid`, filtre IP facultatif, métadonnées de ressource protégée sur la passerelle, intégration sortante au réseau virtuel, point de terminaison privé et DNS privé de la Function, verrouillage de l'accès public en deuxième étape, diagnostics à 0 octet de corps ; tests simulés, guide EN/FR, validateur et nettoyage ciblé. Vérifications opérateur réussies en conditions réelles (2026-10-18) : 401 sur la passerelle, 403 en accès direct à la Function, 0 octet de corps | Vérifications par persona 403/200, rafale 429 et télémétrie. Standard v2 est facturé à l'heure : déployez et nettoyez le même jour |
| Accès délégué et applicatif (05) | Option à activer explicitement, désactivée par défaut : `whoami` (On-Behalf-Of vers Graph, étiquette de persona seulement), `read_report_as_user` (On-Behalf-Of vers Storage, RBAC de l'appelant) et `read_report_as_app` (identité managée réservée à l'application) ; deux identités distinctes, rôles limités au conteneur, informations d'identification fédérées Entra, consentement à activer explicitement, sans secret ; tests unitaires et simulés, guide EN/FR, validateur, étape de publication et nettoyage ciblé. Vérifications opérateur réussies en conditions réelles (2026-10-18) | Vérifications par persona : Alice HTTP 200, Bob HTTP 200 avec `isError`, résultat applicatif identique |
| Observer et inventorier (06) | Rédigé : requêtes de télémétrie, inventaire API Center, guide EN/FR, validateur hors ligne et nettoyage ciblé. La requête KQL a tourné en conditions réelles sur le trafic de la passerelle (2026-10-18), métadonnées uniquement | Trafic des personas (`tools/call`), inscription et listage dans API Center (manuels, **Preview**) |
| Clients (07) et nettoyage (99) | Rédigés : configuration facultative des clients (guide EN/FR, validateur hors ligne, scripts de nettoyage) ; nettoyage orchestré en ordre inverse, en mode rapport par défaut | Vérifications réelles des clients ; nettoyage en mode rapport sur un vrai poste de participant |
| Identités managées | Identité d'hébergement du module 02 et identités OBO et applicative du module 05, avec des rôles limités au conteneur ; vérifications opérateur réussies dans le tenant de test de l'auteur | Vérifications par persona |
| Microsoft Entra | Racine d'identité rédigée au module 03 (sans utilisateurs ni secrets) et activation de délégation du module 05 (Graph `User.Read` et Storage `user_impersonation` délégués, informations d'identification fédérées d'identité managée, consentement administrateur à activer explicitement) ; appliquée dans le tenant de test de l'auteur | Vérifier l'autorisation par utilisateur avec Alice, Bob et Eve |
| Passerelle API Management | Passerelle Standard v2, réseau privé et règles d'autorisation du module 04 ; vérifications opérateur réussies en conditions réelles | Vérifications par persona, limite de débit et télémétrie ; le module 06 ajoute requêtes et inventaire |
| Microsoft Foundry | Scénario de client facultatif uniquement | Examiner séparément le projet, le modèle, l'agent et la connexion sans secret si cette option est retenue |
| Observabilité et inventaire | Journalisation sans contenu des échanges (0 octet de corps vérifié en conditions réelles au module 04) et requête KQL limitée aux métadonnées | Valider avec le trafic des personas et l'inscription dans API Center |

## Comprendre chaque étape

Consultez les [schémas étape par étape](../../assets/architecture/STEPS.fr.md).
Chaque module affiche aussi son schéma dans l'application. Le code Mermaid se trouve dans une section
« Pour aller plus loin », repliée par défaut.
Ces schémas montrent une **cible prévue** : ils ne prouvent pas que les ressources existent.

Commencez par le [guide du module 00](../../modules/00-prerequisites/README.fr.md).
Le [module 01](../../modules/01-discover-mcp/README.fr.md) fonctionne sans Azure ni portail présentateur.
Le module 00 est validé sur le parcours en terminal local ; le parcours conteneur/Codespaces reste à vérifier.
Le [guide du module 02](../../modules/02-open-server/README.fr.md) est validé en conditions réelles (2026-10-16).
Les guides des modules [03](../../modules/03-entra-authentication/README.fr.md), [04](../../modules/04-governed-gateway/README.fr.md),
[05](../../modules/05-delegated-and-app-only/README.fr.md) et [06](../../modules/06-observe-inventory/README.fr.md)
ont réussi leurs vérifications opérateur en conditions réelles ; les vérifications par persona restent à faire.
Le [guide du module 07](../../modules/07-clients/README.fr.md) n'a passé que les vérifications hors ligne.
Le [guide de nettoyage du module 99](../../modules/99-cleanup/README.fr.md) est rédigé ; son mode rapport n'a pas encore tourné sur un état réel.
Chaque validateur affiche une ligne d'objectif, des en-têtes numérotés `== Step N ==` suivis d'une ligne `Why:`,
puis une ligne `PASS`/`FAIL` par contrôle avec le statut HTTP attendu. Les modules 02, 03, 05 et 06 montrent des captures
réelles annotées (noms remplacés par des pseudonymes, identifiants remplacés par des zéros).
Les approbations de déploiement restent exigées.

<details>
<summary>Pour aller plus loin : identités, Foundry et passerelle IA</summary>

Le portail ne sert que des fichiers publics. Il ne contacte aucune ressource Azure et n'a donc pas besoin
d'identité managée à ce stade. Il ne doit jamais recueillir les identifiants des participants.
Le déploiement utilise la connexion interactive de l'opérateur autorisé, pas une clé de publication.

Le serveur Model Context Protocol (MCP) a ses propres identités et droits ciblés.
Un appel effectué pour un utilisateur utilise la délégation On-Behalf-Of.
Un appel au nom de l'application utilise une identité managée.
Le jeton reçu du client MCP n'est jamais transmis à Storage ou Microsoft Graph.

La passerelle du parcours principal est **API Management Standard v2**, pas le niveau AI Gateway en préversion.
L'API de gestion MCP utilisée au module 04 est en **Preview**.
Acheminer les requêtes vers un modèle d'intelligence artificielle (IA) est un besoin distinct des appels aux outils MCP.
Aucun projet Foundry, modèle, agent ni règle de routage vers un modèle n'a été construit ou déployé ici.
Cette option demandera sa propre revue des sources, des quotas, des coûts et des accès, puis une approbation
et une validation.

</details>

<details>
<summary>Pour aller plus loin : mettre à jour les schémas</summary>

Modifiez `assets/architecture/workshop.drawio`, puis régénérez les SVG, PNG et documents Mermaid.
Le [guide de modification](../../assets/architecture/README.fr.md) donne les commandes et la provenance des icônes.
Ne maintenez pas une seconde copie dessinée à la main.
Mettez à jour cette page et `PROGRESS.md` quand le code ou la validation réelle change, pas seulement après une modification du dessin.

</details>

Ces documents n'autorisent aucune création, modification de droits ou suppression dans Azure ou Microsoft Entra.

## Sources

- [Plan de construction](BUILD-PLAN.md), [suivi](../PROGRESS.md) et [références](REFERENCES.md).
- [Demande à l'administrateur, en anglais](../requests/identity-request.md).
- [Hébergement du portail et approbation](HOSTING.md).

Dernière vérification : 2026-10-19. État du code du dépôt, pas un inventaire en direct d'Azure.

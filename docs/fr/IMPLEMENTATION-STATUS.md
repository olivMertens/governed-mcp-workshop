# Ce qui est réellement disponible

Le dépôt public contient du code de préparation et un exercice MCP local utilisables, pas un atelier déjà déployé dans Azure.
Le [suivi de construction](../PROGRESS.md) indique les contrôles réalisés. **Aucun module n'est encore validé dans Azure.**

| Élément | Disponible dans cette branche | Reste à faire |
|---|---|---|
| Environnement participant | Vérification des outils, choix explicite du tenant et de l'abonnement, noms stables et état individuel | Exécuter le conteneur et valider une cible Azure approuvée |
| Portail documentaire public | Application bilingue, Terraform App Service et script de déploiement avec contrôles | Examiner un plan réel, approuver les frais, déployer et vérifier le site |
| Découverte MCP locale, module 01 | Serveur stdio .NET 10, contrôles SDK et Inspector, guide EN/FR et configuration VS Code | Observer l'approbation par appel ; le jalon d'environnement précédent reste ouvert |
| Serveur MCP ouvert, module 02 | Serveur MCP Functions .NET 10 avec cinq outils synthétiques, tests unitaires, Terraform Flex/Storage/télémétrie/identité désactivé par défaut avec tests simulés, guide EN/FR, validateur et nettoyage ciblé | Approbation du plan, déploiement et validation HTTP 401/200 en ligne ; rien n'est déployé |
| Identité Entra, module 03 | Racine `infra/entra` (inscription, étendue, trois rôles d'application, attribution obligatoire, VS Code et Azure CLI préautorisés, attributions pour des comptes existants) et option d'authentification intégrée désactivée par défaut, avec métadonnées de ressource protégée (**Preview**), tests simulés, guide EN/FR, validateur et nettoyage ciblé | Approbation et application par un administrateur des identités, application en deux étapes côté charge de travail, contrôles 401/200 et Eve en ligne ; rien n'est déployé ni créé |
| Passerelle gouvernée, module 04 | Option API Management Standard v2 désactivée par défaut : API de serveur MCP (**Preview**), stratégie de jeton Entra et rôle par outil, limite de débit par `oid`, filtre IP facultatif, métadonnées de ressource protégée sur la passerelle, intégration sortante au réseau virtuel, point de terminaison privé et DNS privé de la Function, verrouillage de l'accès public en deuxième étape, diagnostics à 0 octet de corps ; tests simulés, guide EN/FR, validateur et nettoyage ciblé | Approbation du coût, application en deux étapes, contrôles 401/403/200/429/403 direct/télémétrie en ligne ; rien n'est déployé |
| Accès délégué et applicatif (05) | Option à activer explicitement, désactivée par défaut : `whoami` (On-Behalf-Of vers Graph, étiquette de persona seulement), `read_report_as_user` (On-Behalf-Of vers Storage, RBAC de l'appelant) et `read_report_as_app` (identité managée réservée à l'application) ; deux identités distinctes, rôles limités au conteneur, identifiant fédéré Entra avec consentement à activer explicitement, sans secret ; tests unitaires et simulés, guide EN/FR, validateur, étape de publication et nettoyage ciblé | Consentement et fédération par l'administrateur des identités, application sur la charge de travail, publication du rapport, vérifications réelles Alice/Bob ; rien n'est déployé |
| Observer et inventorier (06 et suivants) | Objectifs et schémas du parcours | Requêtes de télémétrie et inscription dans API Center à partir du module 06 |
| Identités managées | Identité d'hébergement du module 02 et identités OBO et applicative du module 05 rédigées (non déployées) | Les créer avec des attributions ciblées et la fédération approuvée |
| Microsoft Entra | Racine d'identité rédigée au module 03 (sans utilisateurs ni secrets) et activation de délégation du module 05 (Graph `User.Read` et Storage `user_impersonation` délégués, identifiant fédéré d'identité managée, consentement administrateur à activer explicitement) | La faire appliquer par un administrateur des identités, puis vérifier les accès |
| Passerelle API Management | Passerelle Standard v2, réseau privé et règles d'autorisation rédigés au module 04 (non déployés) | Déployer après approbation du coût et valider en ligne ; le module 06 ajoute requêtes et inventaire |
| Microsoft Foundry | Scénario de client facultatif uniquement | Examiner séparément le projet, le modèle, l'agent et la connexion sans secret si cette option est retenue |
| Observabilité et inventaire | Règles de journalisation sans contenu des échanges | Construire et vérifier la télémétrie et l'inscription dans API Center |

## Comprendre chaque étape

Consultez les [schémas étape par étape](../../assets/architecture/STEPS.fr.md).
Chaque module affiche aussi son schéma dans l'application. Le code Mermaid se trouve dans une section
« Pour aller plus loin », repliée par défaut.
Ces schémas montrent une **cible prévue** : ils ne prouvent pas que les ressources existent.

Commencez par le [guide du module 00](../../modules/00-prerequisites/README.fr.md).
Le [module 01](../../modules/01-discover-mcp/README.fr.md) fonctionne sans Azure ni portail présentateur.
Sa construction locale a été explicitement approuvée en attendant les contrôles Azure et conteneur du module 00.
Le [guide du module 02](../../modules/02-open-server/README.fr.md) est rédigé et ne passe que les vérifications hors ligne ; il n'est pas déployé.
Le [guide du module 03](../../modules/03-entra-authentication/README.fr.md) est rédigé et ne passe que les vérifications hors ligne ; aucun objet Entra n'est créé.
Le [guide du module 04](../../modules/04-governed-gateway/README.fr.md) est rédigé et ne passe que les vérifications hors ligne ; aucune passerelle n'est déployée.
Le [guide du module 05](../../modules/05-delegated-and-app-only/README.fr.md) est rédigé et ne passe que les vérifications hors ligne ; aucune identité, aucun consentement ni aucun conteneur n'existe.
Les modules 06 et suivants restent des plans. Les validations dans le cloud et les approbations de déploiement restent en attente.

<details>
<summary>Pour aller plus loin : identités, Foundry et passerelle IA</summary>

Le portail ne sert que des fichiers publics. Il ne contacte aucune ressource Azure et n'a donc pas besoin
d'identité managée à ce stade. Il ne doit jamais recueillir les identifiants des participants.
Le déploiement utilise la connexion interactive de l'opérateur autorisé, pas une clé de publication.

Le futur serveur Model Context Protocol (MCP) aura ses propres identités et droits ciblés.
Un appel effectué pour un utilisateur utilisera la délégation On-Behalf-Of.
Un appel au nom de l'application utilisera une identité managée.
Le jeton reçu du client MCP ne sera jamais transmis à Storage ou Microsoft Graph.

La passerelle du parcours principal est **API Management Standard v2**, pas le niveau AI Gateway en préversion.
L'API de gestion MCP prévue est **Preview**.
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

Dernière vérification : 2026-10-15. État du code du dépôt, pas un inventaire en direct d'Azure.

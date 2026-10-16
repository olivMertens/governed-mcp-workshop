# Comprendre MCP et les agents

[English](../MCP-CONCEPTS.md)

## 1. Quel problème MCP résout-il ?

Model Context Protocol (MCP) donne à une application d'intelligence artificielle (IA) une manière commune
de découvrir des capacités et de demander leur exécution. Il la relie à des outils et à des données de contexte.

Il ne remplace pas les interfaces de programmation d'application (API). Un serveur peut appeler une API existante,
interroger une base ou effectuer un calcul. MCP standardise la découverte et l'appel par un client compatible.

**Question :** si un serveur annonce un outil de création de tickets, tout utilisateur peut-il créer un ticket ?

<details>
<summary>Afficher la réponse</summary>

Non. La découverte décrit une capacité. L'autorisation du serveur décide qui peut l'utiliser.

</details>

**Lire :** [architecture officielle](https://modelcontextprotocol.io/specification/2026-07-28/architecture).

## 2. Hôte, client et serveur sont différents

| Élément | Responsabilité | Exemple de l'atelier |
|---|---|---|
| Hôte | Fournir l'expérience IA, contrôler le contexte et les confirmations | VS Code avec GitHub Copilot |
| Client | Échanger les messages MCP avec un serveur | La connexion MCP de l'hôte |
| Serveur | Annoncer les capacités et vérifier les requêtes | Serveur .NET local, puis Azure Functions |
| Service en aval | Réaliser l'opération sous-jacente | File Storage ou Microsoft Graph |

Un hôte peut gérer plusieurs clients et serveurs. Un serveur MCP ne contient pas forcément de modèle de langage.
N'envoyez pas toute la conversation lorsqu'une requête d'outil ciblée suffit.

**Question :** qui affiche la confirmation humaine, et qui doit faire respecter les droits ?

<details>
<summary>Afficher la réponse</summary>

L'hôte affiche la confirmation ; le serveur et le service en aval appliquent toujours leurs propres autorisations.

</details>

## 3. De quoi un agent est-il composé ?

Un agent associe un modèle à une boucle applicative. Le modèle propose une action ;
le code de l'application décide ce qui peut réellement s'exécuter. MCP est un mécanisme d'intégration, pas l'agent lui-même.

| Composant | Décision à prendre |
|---|---|
| Objectif et instructions | Quelle tâche est permise ? Quand faut-il s'arrêter ? |
| Modèle | Sait-il sélectionner un outil adapté et construire des arguments valides ? |
| Contexte et état | Quelles informations sont utiles ? Combien de temps sont-elles conservées ? |
| Outils | Quelles opérations sont exposées, avec quelles entrées et sorties ? |
| Identité et règles | Quels droits s'appliquent ? Quelles actions demandent une confirmation ? |
| Évaluation et observation | L'exécution réelle a-t-elle produit le résultat attendu ? |

**Question :** un meilleur modèle peut-il compenser l'absence de contrôle des droits sur le serveur ?

<details>
<summary>Afficher la réponse</summary>

Non. Les instructions et le comportement du modèle ne sont pas des contrôles d'accès.

</details>

## 4. Outils, ressources et prompts

| Capacité MCP | Usage | Contrôle habituel |
|---|---|---|
| Outil, ou tool | Exécuter une opération, en lecture ou en écriture | Sélection du modèle, sous contrôle de l'application |
| Ressource | Exposer des données de contexte identifiées par un identifiant uniforme de ressource (URI) | Contexte géré par l'application |
| Prompt | Proposer un modèle de messages réutilisable | Parcours choisi par l'utilisateur |

Ces modes d'interaction n'imposent pas une interface particulière. Les clients ne prennent pas tous en charge les mêmes capacités.
Une ressource MCP n'est pas une ressource Azure. Un prompt MCP n'est pas une instruction système secrète.

**Classez :** consulter la santé d'un service est un outil ; fournir un manuel peut être une ressource ;
proposer un modèle de synthèse d'incident peut être un prompt.

L'atelier implémente des **outils**. Les ressources et prompts sont expliqués ici, mais ne sont pas déployés.

**Lire :** [outils](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
[ressources](https://modelcontextprotocol.io/specification/2026-07-28/server/resources),
[prompts](https://modelcontextprotocol.io/specification/2026-07-28/server/prompts).

## 5. Lire le contrat d'un outil

Un outil utile possède un nom précis, une description, un schéma d'entrée et un résultat prévisible.
La description aide à choisir ; le schéma décrit les entrées ; le serveur doit les vérifier.

Pour `get_service_health` dans cet atelier :

- **Intention :** consulter une santé synthétique sans modifier de données.
- **Entrée :** `service` vaut `workshop-api` ou `ticket-queue`.
- **Sortie :** un résultat synthétique, ou une erreur explicite si l'entrée est invalide.
- **Limite :** aucun ticket créé, aucune consultation de production.

`create_ticket` est différent : il produit une écriture synthétique. Sa description doit le dire.
Les annotations de lecture seule sont des indications, pas une preuve ni un contrôle d'autorisation.

**Question :** que faire d'un argument inattendu ?

<details>
<summary>Afficher la réponse</summary>

Le serveur le refuse. Il ne doit pas élargir silencieusement l'opération.

</details>

## 6. Suivre une itération de l'agent

Séquence illustrative, pas une exécution réelle :

1. **Intention :** Alice demande la santé synthétique d'un service.
2. **Découverte :** le client demande `tools/list`.
3. **Sélection :** le modèle propose `get_service_health` avec un service autorisé.
4. **Contrôle :** l'hôte applique ses règles et confirmations.
5. **Exécution :** le client envoie `tools/call` ; le serveur vérifie identité, droits et arguments.
6. **Observation :** l'hôte reçoit le résultat et recherche les erreurs.
7. **Décision suivante :** répondre, justifier un nouvel appel ou s'arrêter.

Écrire le nom d'un outil dans une réponse ne l'exécute pas. Une phrase de l'assistant annonçant un succès
n'est pas une preuve. Examinez l'appel et son résultat réels.

**À observer :** retrouvez l'intention, l'outil choisi, les arguments, le contrôle et le résultat dans le module 01.

## 7. Messages locaux et distants

MCP utilise des messages JavaScript Object Notation Remote Procedure Call (JSON-RPC).
L'entrée/sortie standard (stdio) relie un client à un processus local.
Streamable Hypertext Transfer Protocol (HTTP) transporte les requêtes distantes.
Un GET de navigateur ne teste ni `tools/list` ni `tools/call`.

La version compte. La spécification 2026-07-28 transmet les métadonnées de version et de capacités dans chaque requête.
Des implémentations antérieures utilisent un échange `initialize`. Suivez la version réellement prise en charge
par le client et le serveur ; ne mélangez pas leurs formats.

Les validateurs de l'atelier construisent les messages pour la combinaison testée.
Cette page ne propose volontairement aucun JSON incomplet à copier comme requête exécutable.

**Lire :** [transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports).

## 8. MCP, API, connecteurs et recherche

| Mécanisme | Question principale |
|---|---|
| API | Quelles opérations et données un service expose-t-il ? |
| Connecteur | Comment un produit prépare-t-il une intégration et ses paramètres de connexion ? |
| Génération augmentée par récupération (RAG) | Quelles connaissances pertinentes récupérer pour étayer une réponse ? |
| MCP | Comment un hôte compatible découvre-t-il et utilise-t-il les capacités d'un serveur ? |

Ces mécanismes se complètent. Un outil MCP peut appeler une API ou rechercher des documents.
MCP n'ajoute pas automatiquement d'index, de mémoire, d'identité ou de confirmation humaine.

**Question :** ajouter un serveur rend-il son utilisation sûre par tous les agents compatibles ?

<details>
<summary>Afficher la réponse</summary>

Non. Vérifiez séparément le client, l'identité, les droits, les confirmations et les journaux.

</details>

## 9. Trois contrôles indépendants

| Contrôle | Question | Exemple |
|---|---|---|
| Authentification | Qui appelle ? | Jeton Microsoft Entra accepté pour l'audience MCP |
| Autorisation | Que peut faire cette identité ? | Rôle `Tools.Write` pour une écriture |
| Confirmation humaine | Cette action précise peut-elle s'exécuter maintenant ? | Confirmation du client avant `create_ticket` |

Une clé partagée n'identifie pas une personne. Se connecter ne donne pas accès à tous les outils.
Une confirmation humaine ne remplace pas un contrôle de rôle manquant.

Pour une API en aval, obtenez un jeton distinct pour son audience.
L'accès délégué On-Behalf-Of (OBO) utilise le contexte utilisateur ; l'accès applicatif par identité managée
utilise les droits de l'application. Ne transmettez jamais le jeton client tel quel.

**Question :** Bob confirme, mais n'a pas `Tools.Write`. L'écriture doit-elle réussir ?

<details>
<summary>Afficher la réponse</summary>

Non. Le contrôle d'autorisation doit toujours la refuser.

</details>

## 10. On-Behalf-Of expliqué simplement

**La question :** quand le serveur MCP appelle une autre API (Microsoft Graph, Storage…), **avec les droits de qui ?**

**Analogie.** Un collègue fait une course pour vous à la banque.

- **On-Behalf-Of (OBO) :** il apporte une procuration signée par vous. La banque vérifie vos droits.
  Il ne peut jamais faire plus que vous.
- **Accès applicatif (identité managée) :** il utilise la carte de l'entreprise. La banque vérifie les droits
  de l'entreprise, quel que soit le demandeur.

**Comment fonctionne OBO, en trois sauts :**

1. Le client envoie au serveur MCP un jeton émis **pour le serveur MCP** (audience = API MCP).
2. Le serveur transmet ce jeton **uniquement à Microsoft Entra ID** et demande : « le même utilisateur, mais pour Storage ».
3. Entra renvoie un **nouveau** jeton pour Storage, qui représente toujours l'utilisateur. Le serveur appelle Storage avec.

Le jeton du client n'est jamais transmis à Storage. Un jeton par saut, une audience par jeton.

![OBO et accès applicatif obtiennent des jetons Storage distincts après le contrôle d'accès MCP.](../../assets/architecture/05.fr.svg)

## 11. OBO ou accès applicatif : que choisir ?

| Question | On-Behalf-Of (droits de l'utilisateur) | Accès applicatif (identité managée) |
|---|---|---|
| Qui décide de l'accès aux données ? | Les droits **de l'utilisateur** | Les droits **de l'application** |
| Deux utilisateurs, même question | Résultats différents possibles (Alice oui, Bob non) | Toujours le même résultat |
| Principal risque évité | Le serveur ne peut pas dépasser les droits de l'utilisateur | Pas de dépendance aux droits de chaque utilisateur |
| Principal risque ajouté | Plus de pièces : consentement, rôles utilisateurs, erreurs d'échange de jeton | « Mandataire abusé » : quiconque peut appeler l'outil lit ce que l'application peut lire |
| Audit en aval | Montre le véritable utilisateur | Montre l'application |
| Fonctionne sans utilisateur connecté ? | **Non** (ni tâche planifiée, ni appelant applicatif) | **Oui** |
| Usage typique | Données personnelles ou sensibles, droits par utilisateur déjà en place | Données de référence partagées, automatisations, même réponse pour tous |

**Choisissez OBO quand** le système en aval porte déjà des droits par utilisateur à respecter,
ou quand l'audit doit montrer le véritable utilisateur sur les données.

**Choisissez l'accès applicatif quand** tous les appelants autorisés doivent voir les mêmes données,
qu'il n'y a pas d'utilisateur (automatisation), ou que l'API en aval n'offre aucune permission déléguée.
Compensez alors par une autorisation stricte des outils (rôles applicatifs) et un rôle étroit pour l'identité.

**Hors choix pour MCP :** transmettre le jeton du client à l'API en aval (« token passthrough »). C'est interdit.

## 12. Ce qu'OBO implique pour l'implémentation

| Domaine | À prévoir |
|---|---|
| Administrateur des identités | Permissions déléguées sur l'inscription de l'API MCP, et **consentement administrateur** |
| Identifiant du serveur | OBO exige que le serveur prouve sa propre identité. Utilisez un **identifiant fédéré avec une identité managée**, pas un secret client |
| Données en aval | Chaque utilisateur a besoin d'un rôle sur les données (ici : Storage Blob Data Reader pour Alice seulement) |
| Appelants | Refusez les jetons applicatifs sur les outils OBO : il n'y a pas d'utilisateur à représenter |
| Erreurs | Un HTTP 403 en aval revient comme une **erreur d'outil MCP dans une réponse HTTP 200**. Affichez-la, ne la masquez pas |
| Performances | Un appel Entra supplémentaire par audience en aval. Mettez en cache par utilisateur et audience, jamais entre utilisateurs |
| Stratégies | L'accès conditionnel et le risque de connexion s'appliquent aussi à l'échange ; il peut échouer comme une connexion |

**Exemple de l'atelier (module 05) :** `whoami` et `read_report_as_user` utilisent OBO ; `read_report_as_app` utilise une identité managée.
Alice et Bob posent la même question : seul OBO donne une réponse différente.

**Question :** Bob n'a aucun rôle sur Storage. Que renvoie `read_report_as_user` ? Et `read_report_as_app` ?

<details>
<summary>Afficher la réponse</summary>

OBO renvoie une erreur d'outil pour Bob (Storage le refuse). L'accès applicatif renvoie le rapport,
car l'application a le droit de le lire.

</details>
**Lire :** [flux On-Behalf-Of](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow),
[identité managée comme identifiant fédéré](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity),
[module 05](../../modules/05-delegated-and-app-only/README.fr.md).

## 13. Descriptions et résultats sont une limite de confiance

Traitez les descriptions d'outils, documents et résultats comme des entrées externes.
Ils peuvent contenir des instructions trompeuses. Un texte retourné ne peut pas s'attribuer un rôle,
contourner une confirmation ou demander des identifiants.

Exposez des outils ciblés, des entrées bornées et des effets explicites.
Demandez une confirmation avant les écritures. Rendez les erreurs visibles et limitez les nouvelles tentatives.

Dans l'atelier, les journaux contiennent seulement des métadonnées : outil, identifiant autorisé de l'appelant,
résultat de contrôle, latence et corrélation. Jamais de jeton, prompt, arguments ni résultat d'outil.
N'utilisez pas de données de production pour illustrer une leçon.

**Ce qu'une trace ne prouve pas :** un HTTP 200 peut contenir une erreur d'outil MCP. Les journaux de passerelle
ne prouvent pas la confirmation humaine et ne montrent pas le raisonnement du modèle.
Un journal en aval applicatif identifie l'application, pas la personne.
L'absence de trace ne prouve pas l'absence d'appel. Le [module 06](../../modules/06-observe-inventory/README.fr.md)
détaille les champs disponibles et les manques.

**Lire :** [conseils sur les outils](https://learn.microsoft.com/azure/foundry/agents/concepts/tool-best-practice).
Leurs recommandations générales de traçage ne remplacent pas la règle de journalisation sans corps de l'atelier.

## 14. Placer les composants de l'atelier

| Composant | Rôle dans le parcours |
|---|---|
| VS Code et MCP Inspector | Découvrir les outils et examiner les appels réels |
| Azure Functions | Héberger le serveur MCP distant de l'atelier |
| Microsoft Entra ID | Authentifier l'appelant |
| Azure API Management | Appliquer les contrôles de passerelle au module 04 |
| Storage et Microsoft Graph | Opérations en aval avec leurs propres droits |
| Application Insights | Preuves sans contenu dans les modules suivants |

Le produit distinct [Azure MCP Server](https://learn.microsoft.com/azure/developer/azure-mcp-server/overview)
propose des outils de gestion Azure. Ce n'est pas le serveur à cinq outils de cet atelier.
N'utilisez pas un outil d'administration large pour contourner les commandes ciblées.

**Suite :** le [module 01](../../modules/01-discover-mcp/README.fr.md) montre une vraie découverte locale et une lecture synthétique.
Cette démonstration ne demande aucun déploiement Azure.

## Sources

Dernière vérification : 2026-10-16. Explications originales et génériques fondées sur des références publiques uniquement.
Aucun contenu privé d'événement n'est repris.

- [Architecture MCP](https://modelcontextprotocol.io/specification/2026-07-28/architecture).
- [Outils](https://modelcontextprotocol.io/specification/2026-07-28/server/tools),
  [ressources](https://modelcontextprotocol.io/specification/2026-07-28/server/resources) et
  [prompts](https://modelcontextprotocol.io/specification/2026-07-28/server/prompts).
- [Transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports).
- [Microsoft MCP for Beginners](https://github.com/microsoft/mcp-for-beginners) : pour poursuivre ; aucun code copié.
- [Conseils Foundry sur les outils](https://learn.microsoft.com/azure/foundry/agents/concepts/tool-best-practice).
- [Vue d'ensemble Azure MCP Server](https://learn.microsoft.com/azure/developer/azure-mcp-server/overview).
- [Limites de gouvernance de l'atelier](LEARNING-GUIDE.md) et leurs sources sur l'identité.

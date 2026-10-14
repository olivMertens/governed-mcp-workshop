# Tester votre serveur MCP

Ce guide sert à tester **votre serveur déjà déployé**, pas à le déployer.
**Sans Azure :** commencez par le [module 01 local](../../modules/01-discover-mcp/README.fr.md),
avec ses commandes réelles et sans champ d'adresse distante.
Le tableau prépare les commandes. VS Code ou MCP Inspector les exécute.
Un résultat attendu dans le guide n'est pas un test déjà réussi.

## Commencer par un test simple

1. Ouvrez l'environnement choisi au module 00 et sélectionnez uniquement le serveur de l'atelier.
2. Affichez les outils disponibles : **Tools / List Tools** dans Inspector, ou **MCP: List Servers**
   et le sélecteur d'outils dans VS Code.
3. Commencez par `get_service_health` s'il est disponible. Lisez les informations demandées par l'outil
   et utilisez seulement des données fictives. S'il n'est pas disponible, arrêtez-vous.
4. Lancez **Call Tool** dans Inspector, ou utilisez la consigne proposée dans le tableau avec VS Code.
   Vérifiez la trace de l'exécution, pas seulement la réponse de l'assistant.
5. Comparez le résultat avec celui du module. Un code HTTP 200 peut contenir une erreur MCP.
   Lancez ensuite le script de vérification du module, s'il est publié.

> [!IMPORTANT]
> Ne collez jamais de clé ou de jeton dans ce tableau. Ne désactivez pas la confirmation manuelle.
> `create_ticket` modifie les données de test et peut entraîner des coûts : chaque exécution
> nécessite le rôle prévu et votre accord explicite pour cette action précise.

## Se connecter au bon serveur

Récupérez l'adresse dans les sorties de **votre déploiement approuvé**.
À partir du module 04, utilisez uniquement l'adresse d'API Management, jamais celle de la Function privée.
Au module 01, le serveur fonctionne localement : suivez son guide, sans saisir d'adresse HTTPS.

Dans VS Code, lancez **MCP: Add Server**, choisissez HTTP et saisissez l'adresse.
Utilisez une configuration utilisateur privée sans remplacer les autres serveurs déjà configurés.
Pour Inspector, lisez les précisions ci-dessous avant de lancer la commande.

<details>
<summary>Pour aller plus loin : installer Inspector et se connecter en toute sécurité</summary>

Les commandes utilisent Inspector **2.9.0** et demandent Node.js 22.19.0 minimum.
Vérifiez la demande d'installation de `npx`, puis ouvrez l'adresse locale affichée.
Elle contient un accès privé à votre session : ne la partagez pas.
La version 2.11.0 publiée sur GitHub n'était pas disponible dans le registre de paquets configuré lors du
contrôle du 2026-10-14. Si la version prévue manque, la commande s'arrête sans changer de registre ni de version.

Utilisez une connexion ponctuelle, pas un catalogue enregistré. Les identifiants restent en mémoire ;
les jetons OAuth ne sont pas enregistrés de façon persistante. N'enregistrez et n'exportez aucun en-tête
d'authentification : les en-têtes d'un catalogue peuvent rester lisibles même si les secrets sont protégés.
Le client négocie la version du protocole ; n'inventez pas de messages de connexion pour contourner une erreur.

Pour Microsoft Entra, demandez à l'administrateur les paramètres approuvés pour **ce client** :
identifiant d'application cliente publique, adresse de retour et autorisations déléguées (scopes).
L'accord donné à VS Code ne vaut pas pour Inspector. Entra ne crée pas automatiquement un enregistrement
pour un nouveau client. Laissez le secret client vide ; arrêtez-vous si le parcours exige un secret ou
des droits supplémentaires.

Au module 02, utilisez uniquement la saisie protégée de la clé système `mcp_extension` prévue par le guide.
L'adresse seule ne permet pas de se connecter. Aucune clé dans l'URL, les arguments de commande,
un en-tête enregistré, la conversation, les journaux ou le dépôt.
Les métadonnées de ressource protégée (PRM) d'App Service sont en **Preview** (préversion).

</details>

<details>
<summary>Pour aller plus loin : utiliser Codespaces ou vérifier le contexte Azure</summary>

[Choisissez votre environnement](GETTING-STARTED.md), puis suivez le [guide Azure](DEPLOYMENT.md).
L'annuaire Microsoft Entra contient les identités ; l'abonnement Azure contient les ressources et les coûts.
Gardez leurs identifiants dans votre terminal privé.

Codespaces n'inclut que les fichiers publiés sur la branche choisie. Vérifiez cette branche, la taille de la
machine, les quotas et la prise en charge des frais. La configuration du conteneur est disponible,
mais son exécution et celle de Codespaces restent à vérifier.

Pour Inspector avec connexion utilisateur, privilégiez VS Code installé sur votre poste, éventuellement
connecté au codespace avec une redirection privée des ports. La connexion depuis le seul navigateur
peut utiliser une autre adresse de retour OAuth. Ne rendez jamais Inspector public et ne désactivez pas
son authentification. Arrêtez-le avec Ctrl+C. Arrêtez les codespaces inutilisés ; leur stockage peut rester facturé.

</details>

## Résultats attendus

Ces résultats décrivent les exercices prévus. Ils ne prouvent pas que votre déploiement a été testé.

| Module | Test | Résultat attendu |
|---|---|---|
| 01 | Afficher puis exécuter un outil local | Une liste d'outils et un résultat réel |
| 02 | Essayer sans clé, puis avec la clé système | HTTP 401, puis HTTP 200 et réussite de l'outil |
| 03 | Essayer sans jeton, puis avec un jeton destiné à un autre service | HTTP 401 ; Eve ne peut pas obtenir le jeton requis |
| 04 | Préparer une création de ticket avec Bob, puis Alice, avec approbation | HTTP 403 pour Bob ; HTTP 200 et réussite pour Alice |
| 04 | Dépasser la limite de débit ; essayer l'accès direct à la Function | HTTP 429 ; accès direct refusé |
| 05 | Lire avec `read_report_as_user`, en tant qu'Alice puis Bob | Alice réussit ; Bob est refusé par le stockage, parfois dans une réponse HTTP 200 |
| 05 | Lire avec `read_report_as_app`, en tant qu'Alice puis Bob | Le même rapport fictif est accessible aux deux |
| 06 | Examiner une trace et l'inventaire | Métadonnées autorisées uniquement ; adresse de la passerelle dans API Center |

Utilisez seulement les comptes de test dédiés. Ne reprenez pas la session d'une autre personne.
Un refus prévu est une réussite du contrôle : ne donnez pas plus de droits à Bob pour obtenir une réponse positive.
Les outils qui dépendent de l'identité restent simulés avant le module 05.

Ne conservez comme preuves que les métadonnées autorisées et les lignes `PASS` ou `FAIL`.
N'exportez pas les traces Network/Protocol d'Inspector : elles peuvent contenir des jetons,
des consignes, les paramètres des outils ou leurs résultats.

## En cas de problème

- **Aucun outil affiché :** vérifiez le serveur sélectionné, l'adresse et le mode de connexion, puis reconnectez-vous.
  Ouvrir l'adresse dans un navigateur ne remplace pas la découverte des outils.
- **HTTP 401 :** vérifiez le compte connecté et les paramètres de connexion avec le guide.
  N'utilisez pas de site de décodage pour examiner un jeton réel.
- **HTTP 403 :** comparez avec le résultat attendu. Si l'accès devrait être autorisé, faites vérifier le rôle requis.
- **HTTP 200 avec une erreur MCP :** l'outil n'a pas réussi ; lisez le détail dans le client.
- **HTTP 429 :** attendez le délai prévu. Ne désactivez pas la limite et ne relancez pas en boucle.
- **Connexion qui n'aboutit pas :** vérifiez le réseau, l'adresse de retour et les ports privés avec le guide.
  Ne rendez pas publics Inspector ou la Function pour contourner le problème.

## 00 - Préparer votre environnement

**À vérifier :** les outils fonctionnent et votre environnement de test est approuvé.
**Conseil :** un droit Azure ne donne pas de droit d'administration dans Microsoft Entra.
**En cas de problème :** utilisez le guide du module 00 et faites préciser les droits nécessaires par l'administrateur.

## 01 - Afficher les outils avant de les utiliser

**À vérifier :** le client affiche les outils du serveur local et peut en exécuter un.
**Conseil :** reprenez la commande de démarrage du guide ; cette étape n'utilise pas d'adresse HTTPS.
Lancez `pwsh -File .\modules\01-discover-mcp\validate.ps1` à la racine, puis démarrez `workshop-local`
dans VS Code ou utilisez Inspector avec le [guide exécutable](../../modules/01-discover-mcp/README.fr.md).
`get_service_health` avec `service=workshop-api` renvoie `healthy` fictif, pas un contrôle Azure.
**En cas de problème :** vérifiez la trace et la version du protocole, sans fabriquer de messages de connexion.

## 02 - Comprendre les limites d'une clé partagée

**À vérifier :** la clé protège l'accès, mais ne distingue pas Alice de Bob.
**Conseil :** utilisez la clé système MCP prévue, pas une autre clé de la Function. Un refus HTTP 401 sans clé est normal.
**En cas de problème :** gardez la protection du point d'entrée activée. Les accès liés à l'identité sont encore simulés.

## 03 - Vérifier qui se connecte et avec quels droits

**À vérifier :** le jeton est destiné au serveur MCP ; Alice et Bob sont autorisés à se connecter, pas Eve.
**Conseil :** vérifiez le compte réellement connecté et l'application cliente utilisée.
**En cas de problème :** faites vérifier le consentement et les affectations. N'acceptez pas un jeton destiné à Graph.

## 04 - Imposer le passage par API Management

**À vérifier :** les droits, la limite de débit et l'interdiction d'accès direct sont respectés.
**Conseil :** testez Bob puis Alice séparément, en approuvant chaque action qui modifie des données.
**En cas de problème :** ne réactivez pas l'accès public à la Function. L'API de gestion MCP est en **Preview**.

## 05 - Comprendre quels droits servent à lire les données

**À vérifier :** l'accès délégué utilise les droits de l'utilisateur ; l'accès applicatif utilise ceux de l'application.
**Conseil :** prévoyez les résultats pour Alice et Bob avec chacun des deux outils, puis comparez-les.
**En cas de problème :** vérifiez les droits sur le conteneur de stockage. Ne remplacez pas l'utilisateur par le développeur.

## 06 - Suivre les appels sans enregistrer leur contenu

**À vérifier :** vous savez qui a utilisé quel outil et avec quel résultat, sans conserver les données échangées.
**Conseil :** reliez les événements grâce à l'identifiant de corrélation, pas au contenu des requêtes.
**En cas de problème :** vérifiez les paramètres des journaux. API Center répertorie les serveurs, sans donner de droits d'accès.

## 07 - Utiliser un autre client sans changer les protections

**À vérifier :** le client facultatif utilise la même passerelle et une connexion officiellement prise en charge.
**Conseil :** cette démonstration est réservée à l'animateur ; vérifiez licences, identité et fonctions en **Preview**.
**En cas de problème :** reportez tout parcours qui exige un secret client. Ne transmettez pas le jeton MCP aux API cibles.

## 99 - Supprimer les ressources de l'atelier

**À vérifier :** les ressources et affectations créées pour l'atelier sont supprimées ; les ressources partagées sont préservées.
**Conseil :** nettoyez séparément les ressources Azure et les identités. Arrêtez Inspector et les codespaces inutilisés.
**En cas de problème :** examinez l'inventaire, les durées de conservation et les suppressions récupérables.
Ne lancez pas de suppression globale sans examen et approbation.

## Sources

- [Configuration MCP dans VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers).
- [Client web Inspector](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/web).
- [Stockage des identifiants Inspector](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/configuration).
- [Autorisation et retours Inspector](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/authorization).
- [Source Inspector 2.9.0](https://github.com/modelcontextprotocol/inspector/tree/ae865a19178ddf6f375780a02e9c77c4cf4da184).
- [Création d'un codespace](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository).
- [Redirection privée des ports](https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace).
- [Autorisation App Service et PRM, Preview](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).
- [Contexte Azure](DEPLOYMENT.md) et [références complètes](REFERENCES.md).

Dernière vérification : 2026-10-14. Préparer une commande ne valide ni la connexion au serveur ni un module.

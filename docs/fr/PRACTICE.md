# Tester votre serveur MCP

Ce guide accompagne **votre serveur déjà déployé**. Il ne déploie pas le workshop.
Le board prépare les commandes ; votre client Model Context Protocol (MCP) effectue les appels.
Un exemple ou un résultat attendu n'est pas une preuve de test.

## Choisir votre poste de travail

- **Local :** ouvrez le dépôt dans Visual Studio Code (VS Code), avec les prérequis du module 00.
  La commande locale ouvre le dossier courant : exécutez-la depuis votre copie existante.
- **Codespaces :** le lien ouvre l'écran de création GitHub. Vérifiez branche, taille, payeur et quota.
  Les changements locaux non poussés ne sont pas inclus. Le dev container du workshop n'est pas encore publié.
- **Inspector avec authentification :** préférez le poste local, ou VS Code desktop connecté au codespace
  avec redirection privée des ports. Dans un codespace ouvert seulement dans le navigateur, l'origine du retour
  OAuth peut changer. N'exposez jamais Inspector publiquement et ne désactivez pas son authentification.
  Arrêtez Inspector avec Ctrl+C ; arrêtez les codespaces inutilisés. Leur stockage peut rester facturé.

## Choisir votre environnement Azure

Lisez d'abord **Votre contexte Azure**. Le tenant porte les identités ; l'abonnement porte les ressources et les coûts.
Sélectionnez et vérifiez les deux dans votre terminal avec les sélecteurs fournis. Les identifiants ne vont pas
dans le board. Le serveur appelé doit être celui de votre déploiement approuvé, pas un exemple partagé.
Les guides et validateurs des modules ne sont pas encore publiés.

## Connecter sans déplacer les identifiants

1. Récupérez l'adresse exacte dans les sorties de votre déploiement. Utilisez Streamable HTTP pour le distant.
   Dès le module 04, utilisez uniquement la passerelle API Management, jamais l'adresse privée de la Function.
2. Saisissez seulement cet URL HTTPS dans le board. Ni clé, ni jeton, ni paramètres d'URL.
   La valeur reste en mémoire de page : ni envoi au serveur du board, ni stockage, ni ajout au suivi.
3. Dans VS Code : **MCP: Add Server**, type HTTP, puis adresse du serveur. Préférez la configuration utilisateur
   privée. Fusionnez l'entrée avec les serveurs existants ; ne remplacez pas le fichier complet.
4. Pour Inspector, copiez la commande PowerShell ou bash dans votre terminal. Version épinglée : **2.9.0** ;
   Node.js 22.19.0 minimum. Examinez la demande d'installation `npx`. Ouvrez l'URL locale affichée par le lanceur :
   elle contient une capacité privée de session, à ne pas partager.
5. La version GitHub 2.11.0 retenue comme candidate source n'était pas disponible dans le registre npm configuré
   le 2026-10-14. Les commandes s'arrêtent si 2.9.0 n'est pas disponible. Elles ne changent pas de registre et
   ne contournent aucune alerte de sécurité. Le client négocie explicitement la génération de protocole.
6. Les identifiants Inspector restent en mémoire ; les jetons OAuth ne sont pas persistés. Utilisez une connexion
   ponctuelle, pas un catalogue enregistré. N'enregistrez ni n'exportez les en-têtes d'authentification :
   les valeurs d'en-tête de catalogue peuvent rester en clair malgré le stockage protégé des secrets.
7. Pour Entra, demandez l'ID de client **public** approuvé, l'adresse de retour exacte et les étendues de ce client.
   Entra ne propose pas d'enregistrement dynamique de clients. Laissez le secret client vide.
   L'approbation de VS Code n'approuve pas Inspector. Arrêtez si le flux exige un secret ou des droits supplémentaires.
8. Au module 02, utilisez la saisie sécurisée prévue par le guide pour la clé système `mcp_extension`.
   Une configuration avec URL seule ne suffit volontairement pas. Pas de clé dans URL, argument de commande,
   en-tête enregistré, chat, journal ou dépôt. Ce n'est pas l'exercice OAuth.

> [!IMPORTANT]
> Les métadonnées de ressource protégée (PRM) App Service sont en Preview.
> Connexion réussie, confiance dans le client et approbation d'outil ne remplacent pas les contrôles serveur.

## Effectuer un vrai appel

1. Sélectionnez uniquement le serveur du workshop dans le client. Dans Inspector, utilisez **Tools / List Tools**.
   Dans VS Code, utilisez **MCP: List Servers** et le sélecteur d'outils. Un badge connecté ne prouve pas qu'un outil fonctionne.
2. Lisez les noms et schémas annoncés. Commencez par `get_service_health` s'il existe. Respectez son vrai schéma ;
   n'inventez ni champs ni résultats. Utilisez exclusivement des données synthétiques.
3. Dans Inspector, sélectionnez l'outil et cliquez explicitement **Call Tool**. Dans VS Code, utilisez les prompts
   proposés puis inspectez la trace d'appel, pas seulement le texte de l'assistant.
4. Comparez statut de transport et résultat MCP. Un HTTP 200 peut transporter une erreur d'outil.
   Un outil absent n'est pas une réussite de contrôle d'accès. Reconnectez après un changement de module.
5. Réalisez les cas négatifs avec les seuls comptes de test dédiés. N'empruntez pas la session d'une autre personne.
   Un refus peut être correct ; n'accordez pas davantage de droits pour obtenir du vert.
6. `create_ticket` crée un message de file et peut entraîner des coûts. Chaque appel exige un rôle explicite et
   une approbation humaine individuelle. N'activez pas l'approbation automatique. **Call Tool** n'approuve qu'un seul appel.
7. Lisez puis lancez le validateur publié du module. Le board n'affiche la commande que si le README et le script
   existent. Le script peut effectuer de vrais appels, écrire des données synthétiques et nécessiter une approbation.

## Comparer le résultat

Ces observations sont des objectifs, pas des tests déjà réussis.

| Étape | Exercice | Observation attendue | Ce que cela prouve |
|---|---|---|---|
| 01 | Lister et appeler l'outil local | Vraie liste et vrai résultat MCP | Découvrir n'est pas exécuter. |
| 02 | Sans clé puis avec la clé système | HTTP 401, puis HTTP 200 et résultat réussi | Posséder une clé n'identifie pas l'utilisateur. |
| 03 | Sans jeton ou mauvaise audience | HTTP 401 ; Eve ne peut pas obtenir le jeton requis | Le jeton est destiné à cette ressource. |
| 04 | Écriture approuvée, Bob puis Alice | HTTP 403 pour Bob ; HTTP 200 et succès pour Alice | Tools.Read n'accorde pas Tools.Write. |
| 04 | Débit et accès direct au backend | HTTP 429 au seuil ; Function directe refusée | La passerelle est imposée. |
| 05 | `read_report_as_user`, Alice et Bob | Alice réussit ; Bob est refusé en aval, parfois dans HTTP 200 | OBO conserve les droits utilisateur. |
| 05 | `read_report_as_app`, Alice et Bob | Même rapport synthétique autorisé | Droits de l'identité managée. |
| 06 | Trace et inventaire | Outil, ID objet, statut, latence, corrélation ; passerelle dans API Center | Observer ne signifie pas capturer le contenu ; inventorier n'autorise pas. |

Ne conservez ni jetons, prompts, arguments, ni résultats comme preuves. Seulement les métadonnées approuvées et
lignes PASS/FAIL du validateur. N'exportez pas les transcripts Network/Protocol d'Inspector : ils peuvent contenir
corps et identifiants. Les outils d'identité restent simulés avant le module 05.

## En cas de blocage

- **Pas d'outils :** vérifiez serveur sélectionné, transport, adresse et implémentation réelle ; reconnectez.
  Ouvrir l'adresse dans un navigateur ne teste pas `tools/list`.
- **HTTP 401 :** vérifiez identité du client, tenant, audience, expiration et étendues approuvées.
  Utilisez la connexion du client, pas un site de décodage de jeton.
- **HTTP 403 :** vérifiez le rôle applicatif ou la permission de ressource attendue.
  Un refus prévu pour Bob n'est pas une raison de lui donner Tools.Write ou des droits sur l'abonnement.
- **HTTP 200 avec erreur :** lisez l'indicateur d'erreur MCP ; le statut externe ne suffit pas.
- **HTTP 429 :** attendez la fenêtre prévue. Ne désactivez pas la limite et ne bouclez pas sans borne.
- **Délai ou retour OAuth :** vérifiez réseau, adresse de retour et redirection privée des ports.
  N'exposez ni Function privée ni Inspector pour contourner le problème.

## 00 - Comprendre votre environnement

**À prouver :** outils, identités, région et budget sont prêts.
**Indice :** une permission Azure ne donne pas l'administration Entra. Un codespace n'est pas un tenant.
**Si cela bloque :** demande d'identité précise, pas Owner ni secret client. Le vrai précontrôle reste à publier.

## 01 - Découvrir avant d'appeler

**À prouver :** découverte et appel réels sur stdio.
**Indice :** utilisez la commande de démarrage du README ; aucun endpoint HTTP ici.
**Si cela bloque :** vérifiez la trace réelle et le protocole négocié, sans fabriquer de messages d'initialisation.

## 02 - Voir les limites d'une clé

**À prouver :** la clé protège l'entrée, mais ne distingue pas Alice et Bob.
**Indice :** clé système MCP, pas une clé Function choisie au hasard. Gardez l'autorisation du webhook.
**Si cela bloque :** 401 sans clé est correct. Les outils OBO et app-only sont encore des simulations.

## 03 - Séparer identité, étendue et rôle

**À prouver :** jeton destiné au serveur, étendue du client et rôles utilisateur corrects ; Eve reste non affectée.
**Indice :** identifiez le compte réellement connecté et le client préautorisé.
**Si cela bloque :** revoyez consentement et affectation avec l'administrateur. Pas de jeton Graph pour MCP ni d'audience élargie.

## 04 - Prouver l'absence de contournement

**À prouver :** identité, rôle par outil, débit et réseau sont imposés. API de gestion MCP en Preview.
**Indice :** l'écriture synthétique approuvée de Bob doit donner un 403. Testez Alice séparément avec son approbation.
**Si cela bloque :** vérifiez le refus de la Function privée et les métadonnées. Ne réactivez pas son accès public.

## 05 - Identifier les droits qui atteignent la donnée

**À prouver :** OBO obtient un autre jeton avec contexte utilisateur ; app-only utilise une identité managée.
**Indice :** prédisez les quatre cas Alice/Bob et as_user/as_app. Lisez HTTP et l'erreur MCP.
**Si cela bloque :** vérifiez les droits exacts du conteneur. Pas de repli développeur ni de rôle élargi.

## 06 - Observer sans collecter le contenu

**À prouver :** savoir qui appelle quoi sans enregistrer le corps. API Center inventorie, sans autoriser.
**Indice :** corrélation à partir des métadonnées approuvées ; pas de requête ou réponse sérialisée.
**Si cela bloque :** contrôlez les diagnostics. N'activez pas les journaux de corps et n'exportez pas de transcript Inspector.

## 07 - Réutiliser la frontière, pas le jeton

**À prouver :** un client optionnel utilise la même entrée gouvernée.
**Indice :** utilisateur ou application ? Vérifiez licences, Preview et retour OAuth. Démonstration du facilitateur seulement.
**Si cela bloque :** reportez tout flux exigeant un secret client. Aucun transfert du jeton MCP aux API cibles.

## 99 - Arrêter la facture, préserver le partagé

**À prouver :** supprimer créations et affectations du workshop, préserver identités et infrastructure existantes.
**Indice :** nettoyage ressources et identités sont séparés. Arrêtez Inspector et les codespaces inutilisés.
**Si cela bloque :** examinez inventaire tagué, rétention et suppression récupérable. Pas de suppression large non revue.

## Sources

- [Configuration MCP dans VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers).
- [Client web Inspector](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/web).
- [Stockage des identifiants Inspector](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/configuration).
- [Autorisation et retours Inspector](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/authorization).
- [Source Inspector 2.9.0](https://github.com/modelcontextprotocol/inspector/tree/ae865a19178ddf6f375780a02e9c77c4cf4da184).
- [Création d'un codespace](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository).
- [Redirection privée des ports](https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace).
- [Autorisation App Service et PRM, Preview](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).
- [Contexte Azure](DEPLOYMENT.md) et [registre complet](REFERENCES.md).

Dernière vérification : 2026-10-14. Les recettes de lancement ne prouvent ni compatibilité déployée ni validation d'un module.

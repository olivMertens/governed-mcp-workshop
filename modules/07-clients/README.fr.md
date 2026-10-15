# Module 07 — Optionnel : autres clients (démo du formateur)

> English: [README.md](README.md)

## Objectif

Montrer que le même serveur MCP gouverné peut être appelé depuis d'autres clients : un agent Microsoft Foundry et Microsoft Copilot Studio. Ce module est une **démo du formateur**. Les participants regardent et lisent la checklist. Ils n'ont pas besoin de le construire.

## Pourquoi c'est important

La gouvernance doit tenir quel que soit le client qui appelle le serveur. Chaque client a sa propre manière de se connecter et d'envoyer le jeton. Les questions à poser sont toujours les mêmes :

- Quelle identité appelle le serveur MCP (l'utilisateur, une identité managée ou une identité d'agent) ?
- Quelle audience a le jeton, et est-ce bien l'audience propre au serveur MCP ?
- Y a-t-il un passage de jeton (token passthrough) vers un service aval ?

## Ce que vous déployez

Rien. Ce module ne crée aucune ressource Azure, Microsoft Entra ou Copilot Studio. Il décrit seulement les étapes et fournit une vérification hors ligne de ce dossier.

Fonctionnalités en préversion utilisées dans cette démo (indiquez « Preview » quand vous les montrez) :

- **Préversion :** passage d'identité OAuth pour les outils MCP dans Microsoft Foundry.
- **Préversion :** configuration des outils MCP de Microsoft Foundry dans le constructeur d'agents.

## Prérequis et rôles nécessaires

- Modules 03 à 06 terminés et validés (ou un enregistrement de ceux-ci).
- L'URL du serveur MCP du module 04 (via la passerelle, jamais l'URL de la Function).
- Pour une démo en direct seulement : un projet Microsoft Foundry et un environnement Copilot Studio que votre tenant autorise. Votre administrateur les approuve. Rien dans ce module ne modifie leurs rôles.

## Étapes

C'est une démo. Le formateur l'exécute. Les participants suivent.

### Partie A — Agent Microsoft Foundry (préversion)

1. Dans le projet Foundry, ouvrez l'agent et ajoutez un **outil MCP**.
2. Indiquez l'URL de la passerelle du module 04. Utilisez le transport **Streamable HTTP**.
3. Choisissez l'authentification :
   - **Identité managée du projet :** le projet appelle le serveur avec sa propre identité. Le serveur doit alors accorder un rôle d'application à cette identité (modèle du module 03).
   - **Passage d'identité OAuth (préversion) :** l'identité de chaque utilisateur connecté est utilisée. Le serveur doit accepter un jeton dont l'audience est sa propre audience. Les jetons Microsoft ne sont pas transmis à des points de terminaison MCP non approuvés.
4. Posez une question en lecture seule qui appelle un outil de lecture. Montrez le résultat.
5. Demandez à l'agent d'appeler un outil d'écriture. Montrez que l'écriture exige le rôle correspondant et une approbation humaine.

### Partie B — Microsoft Copilot Studio (plan)

1. Dans l'agent, ouvrez **Outils**, puis **Ajouter un outil**, puis **Nouvel outil**, puis **Model Context Protocol**.
2. Saisissez un **Nom du serveur**, une **Description du serveur** et l'**URL du serveur** (URL de la passerelle).
3. Choisissez l'authentification : **Aucune**, **Clé API** ou **OAuth 2.0**. Pour cet atelier, utilisez **OAuth 2.0** et jamais **Aucune** (voir les invariants de sécurité de `copilot-instructions.md`).
4. Seul le transport **Streamable** est pris en charge. SSE n'est plus pris en charge.
5. Testez l'outil dans le volet de test de l'agent.

> Les libellés exacts des écrans peuvent changer. Vérifiez la page source ci-dessous avant la session.

### Partie C — Checklist pour chaque client

- [ ] L'audience du jeton est l'audience propre au serveur MCP (ni Microsoft Graph, ni une API aval).
- [ ] Aucun secret client ni clé API n'est stocké dans la configuration du client.
- [ ] Les outils d'écriture exigent un rôle explicite et une approbation humaine.
- [ ] Les journaux de la passerelle montrent l'appel avec un ID de corrélation et sans corps de requête (module 06).

## Résultat attendu

- L'agent Foundry renvoie un résultat de l'outil de lecture.
- La tentative d'écriture est refusée, ou demande une approbation, quand l'appelant n'a pas le rôle.
- Le journal de la passerelle du module 06 montre les appels de chaque client, sans corps.

## Valider

Vérifications hors ligne uniquement. Elles confirment que ce dossier est complet et que les règles ci-dessus sont présentes :

```powershell
pwsh ./modules/07-clients/validate.ps1 -Offline
```

```bash
bash ./modules/07-clients/validate.sh --offline
```

Chaque vérification affiche une ligne `PASS` ou `FAIL`. Aucune vérification en direct n'est scriptée, car cette démo dépend des paramètres du tenant.

## Dépannage

- **Le client reçoit 401 :** l'audience du jeton ne correspond pas au serveur. Vérifiez le module 03.
- **Le client reçoit 403 :** l'appelant n'a pas le rôle d'application. Vérifiez les modules 03 et 05.
- **Le client n'atteint pas le serveur :** l'URL doit être celle de la passerelle (module 04). L'URL de la Function est verrouillée par conception.
- **Le transport SSE échoue :** utilisez Streamable. SSE n'est plus pris en charge.

## Nettoyage

Rien n'a été créé, donc rien à supprimer. Retirez tout agent ou outil de test ajouté au projet Foundry ou à Copilot Studio après la démo :

```powershell
pwsh ./modules/07-clients/cleanup.ps1
```

```bash
bash ./modules/07-clients/cleanup.sh
```

## Aller plus loin

- Ajoutez un deuxième client et comparez les choix d'authentification.
- Lisez les notes de préversion de la documentation Foundry et suivez quand le passage OAuth devient généralement disponible.

## Sources

- Microsoft Foundry — Authentification MCP : https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication
- Microsoft Copilot Studio — Ajouter un serveur MCP existant à un agent : https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent

Dernière vérification : 2026-10-15. La page Copilot Studio n'a été relue que partiellement. Confirmez les étapes restantes avant une session en direct.

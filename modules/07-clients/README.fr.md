# 07 - Optionnel : autres clients (démo du formateur)

[English](README.md)

## Objectif

Montrer que le même serveur MCP gouverné peut être appelé depuis d'autres clients : un agent Microsoft Foundry et Microsoft Copilot Studio. Ce module est une **démo du formateur**. Les participants regardent et lisent la checklist. Ils n'ont pas besoin de le construire.

## Pourquoi c'est important

La gouvernance doit s'appliquer quel que soit le client qui appelle le serveur. Chaque client a sa propre manière de se connecter et d'envoyer le jeton. Les questions à poser sont toujours les mêmes :

- Quelle identité appelle le serveur MCP (l'utilisateur, une identité managée ou une identité d'agent) ?
- Quelle est l'audience du jeton, et s'agit-il bien de l'audience propre au serveur MCP ?
- Y a-t-il un passage de jeton (token passthrough) vers un service en aval ?

## Ce que vous déployez

Rien. Ce module ne crée aucune ressource Azure, Microsoft Entra ou Copilot Studio. Il décrit seulement les étapes et fournit une vérification hors ligne de ce dossier.

> [!NOTE]
> Fonctionnalités en préversion utilisées dans cette démo (indiquez « Preview » quand vous les montrez) :
>
> - **Préversion :** passage d'identité OAuth pour les outils MCP dans Microsoft Foundry.
> - **Préversion :** configuration des outils MCP de Microsoft Foundry dans le constructeur d'agents.

## Prérequis et rôles nécessaires

- Modules 03 à 06 terminés et validés (ou leur enregistrement).
- L'URL du serveur MCP du module 04 (via la passerelle, jamais l'URL de la Function).
- Pour une démo en direct seulement : un projet Microsoft Foundry et un environnement Copilot Studio autorisés par votre tenant. Votre administrateur les approuve. Rien dans ce module ne modifie leurs rôles.

## Étapes

### Garder la même frontière d'autorisation

![Les clients facultatifs utilisent les mêmes contrôles API Management et la même Function privée.](../../assets/architecture/07.fr.svg)

Le produit change ; les droits exigés par le serveur ne changent pas.

| Appel | Jeton et contrôle à prévoir |
|---|---|
| Client vers passerelle MCP | Jeton destiné à l'audience MCP. Validation de l'émetteur, du tenant, de l'audience, de l'expiration, du scope et du rôle par les contrôles de plateforme |
| Passerelle vers Function | Même ressource logique MCP dans l'atelier ; pas d'échange vers une audience en aval. Authentification et accès privé de la Function conservés |
| Serveur MCP vers Graph ou Storage comme utilisateur | Nouveau jeton pour cette API par On-Behalf-Of (OBO) ; droits utilisateur et consentement délégué |
| Serveur MCP vers Storage comme application | Nouveau jeton Storage par identité managée ; droits applicatifs limités au conteneur |
| Serveur local en stdio | Pas de jeton OAuth HTTP sur ce transport ; accès au processus et droits du système d'exploitation restent nécessaires |
| Calcul synthétique dans un outil | Aucun jeton en aval s'il n'y a aucun appel en aval ; l'accès MCP distant reste authentifié |

![Les outils utilisateur et applicatifs emploient des jetons en aval distincts, jamais le jeton MCP.](../../assets/architecture/05.fr.svg)

> [!IMPORTANT]
> **Point de compatibilité :** la passerelle actuelle exige un scope délégué et les outils OBO exigent un utilisateur.
> Une identité managée Foundry est applicative : lui attribuer un rôle ne suffit **pas**.
> Ne présentez pas ce chemin comme fonctionnel et ne retirez pas le contrôle de scope. Utilisez un flux utilisateur approuvé ou un enregistrement.

**Question :** Foundry appelle avec son identité managée. `whoami` peut-il agir pour Alice ?

<details>
<summary>Afficher la réponse</summary>

Non. Un jeton applicatif ne contient pas de contexte délégué d'Alice. La passerelle actuelle refuse ce flux ;
les outils OBO doivent aussi refuser les appelants applicatifs. L'identité du client et l'identité managée utilisée par un outil en aval sont deux choix distincts.

</details>

### Partie A — Agent Microsoft Foundry (préversion)

1. Dans le projet Foundry, ouvrez l'agent et ajoutez un **outil MCP**.
2. Indiquez l'URL de la passerelle du module 04. Utilisez le transport **Streamable HTTP**.
3. Choisissez l'authentification :
   - **Identité managée du projet :** option documentée de Foundry, mais incompatible avec le contrôle de scope délégué actuel de l'atelier. Expliquez la différence ; ne la présentez pas comme une démonstration réussie.
   - **Passage d'identité OAuth (préversion) :** l'identité de chaque utilisateur connecté est utilisée. Le serveur doit accepter un jeton dont l'audience est sa propre audience. Les jetons Microsoft ne sont pas transmis à des points de terminaison MCP non approuvés.
4. Posez une question en lecture seule qui appelle un outil de lecture. Montrez le résultat.
5. Avant toute écriture, vérifiez que ce client peut exiger une confirmation humaine pour cet appel précis. Sinon, omettez l'écriture. La confirmation ne donne jamais le rôle manquant : Bob doit toujours être refusé.

### Partie B — Microsoft Copilot Studio (plan)

1. Dans l'agent, ouvrez **Outils**, puis **Ajouter un outil**, puis **Nouvel outil**, puis **Model Context Protocol**.
2. Saisissez un **Nom du serveur**, une **Description du serveur** et l'**URL du serveur** (URL de la passerelle).
3. Examinez **OAuth 2.0**, jamais **Aucune**. Le parcours **Manual** documenté demande un **Client secret**, interdit dans cet atelier. Arrêtez-vous avant de créer cette connexion ; utilisez le plan ou un enregistrement. La découverte ne prouve pas une compatibilité sans secret et l'atelier n'implémente pas l'inscription dynamique de clients. Ne passez pas à **Clé API** pour contourner ce blocage.
4. Seul le transport **Streamable** est pris en charge. SSE n'est plus pris en charge.
5. Ne testez un outil de lecture que si un administrateur a vérifié séparément un flux sans secret pris en charge, avec la bonne audience MCP, le scope délégué et les rôles. Ce guide ne prétend pas avoir configuré ou validé une telle connexion.

> [!CAUTION]
> Arrêtez-vous avant de créer une connexion Copilot Studio qui demande un **Client secret**. Ne passez jamais
> à **Aucune** ni à **Clé API** pour la faire fonctionner : cela supprime le contrôle d'identité construit dans l'atelier.

> Les libellés exacts des écrans peuvent changer. Vérifiez la page source ci-dessous avant la session.

### Partie C — Checklist pour chaque client

- [ ] L'audience du jeton est l'audience propre au serveur MCP (ni Microsoft Graph, ni une API en aval).
- [ ] Aucun secret client ni clé API n'est stocké dans la configuration du client.
- [ ] Les outils d'écriture exigent un rôle explicite et une approbation humaine.
- [ ] Les journaux de la passerelle montrent l'appel avec un ID de corrélation et sans corps de requête (module 06).

## Résultat attendu

- Avec un flux utilisateur compatible et approuvé, Foundry peut renvoyer un résultat de lecture ; sinon, montrez l'enregistrement et la limite de compatibilité.
- L'écriture de Bob est refusée même s'il confirme. Alice a besoin du rôle et d'une confirmation pour l'appel précis.
- Les métadonnées disponibles de la passerelle montrent les requêtes sans corps. Elles ne prouvent pas l'affichage d'une confirmation dans le client ; vérifiez-le séparément.

## Valider

Vérifications hors ligne uniquement. Elles confirment que ce dossier est complet et que les règles ci-dessus sont présentes :

```powershell
pwsh ./modules/07-clients/validate.ps1 -Offline
```

```bash
bash ./modules/07-clients/validate.sh --offline
```

Chaque vérification affiche une ligne `PASS` ou `FAIL`. Aucune vérification en direct n'est automatisée, car cette démo dépend des paramètres du tenant.

## Dépannage

- **Le client reçoit 401 :** l'audience du jeton ne correspond pas au serveur. Vérifiez le module 03.
- **Le client reçoit 403 :** l'appelant n'a pas le rôle d'application. Vérifiez les modules 03 et 05.
- **Le client n'atteint pas le serveur :** l'URL doit être celle de la passerelle (module 04). L'URL de la Function est volontairement verrouillée.
- **Le transport SSE échoue :** utilisez Streamable. SSE n'est plus pris en charge.

## Nettoyage

Rien n'a été créé : il n'y a donc rien à supprimer. Retirez tout agent ou outil de test ajouté au projet Foundry ou à Copilot Studio après la démo :

```powershell
pwsh ./modules/07-clients/cleanup.ps1
```

```bash
bash ./modules/07-clients/cleanup.sh
```

## Aller plus loin

- Ajoutez un deuxième client et comparez les choix d'authentification.
- Lisez les notes de préversion de la documentation Foundry et surveillez le moment où le passage d'identité OAuth sera en disponibilité générale.

## Sources

- Microsoft Foundry — Authentification MCP : https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication
- Microsoft Copilot Studio — Ajouter un serveur MCP existant à un agent : https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent

Dernière vérification : 2026-10-16. Le parcours Copilot Studio Manual documenté exige un secret client et n'est pas exécuté ici.

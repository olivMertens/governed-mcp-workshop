# Scopes et rôles applicatifs

[English](../../concepts/scopes-and-app-roles.md)

L'authentification identifie l'appelant. Un scope délégué indique ce qu'un client peut demander pour un utilisateur
connecté. Un rôle applicatif, affecté à un utilisateur ou à une application, indique quelle opération celui-ci peut exécuter.
L'approbation humaine autorise un appel précis. Ces contrôles sont complémentaires.

| Contrôle | Revendication | Exemple | Question |
|---|---|---|---|
| Scope délégué | `scp` | `user_impersonation` | Ce client peut-il appeler MCP pour Alice ? |
| Rôle applicatif | `roles` | `Tools.Read`, `Tools.Write` | Alice peut-elle exécuter cette opération ? |
| Approbation client | Trace du client | Approuver `create_ticket` | La personne approuve-t-elle cette écriture, ici et maintenant ? |

## Alice, Bob et Eve

- **Alice** reçoit `Tools.Read` et `Tools.Write`. Après son approbation, `create_ticket` peut s'exécuter.
- **Bob** reçoit `Tools.Read`. Son scope, pourtant valide, ne lui accorde pas `Tools.Write` ; APIM renvoie HTTP 403.
- **Eve** n'est pas affectée. Si l'affectation est obligatoire, elle ne peut pas obtenir le jeton de l'atelier.

L'API définit des rôles stables. Les administrateurs les affectent. La ressource vérifie les valeurs exactes.
Le consentement à un scope n'est pas une affectation de rôle ; la préautorisation n'accorde aucun rôle d'outil.
Utilisez la validation intégrée à la plateforme et les stratégies ou frameworks officiels, jamais un validateur JWT fait maison.

## Résultat attendu

À partir de revendications fictives, vous savez expliquer pourquoi Alice réussit, pourquoi l'écriture de Bob est refusée
et pourquoi Eve n'obtient aucun accès. Toute écriture exige un rôle explicite et l'approbation humaine. Les journaux conservent
seulement l'identifiant d'objet, le nom fixe de l'outil, le statut, la durée et l'identifiant de corrélation.

## Sources

- [Scopes et autorisations](https://learn.microsoft.com/entra/identity-platform/scopes-oidc).
- [Ajouter des rôles applicatifs](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps).
- [Vérifier les scopes et les rôles](https://learn.microsoft.com/entra/identity-platform/scenario-protected-web-api-verification-scope-app-roles).

Dernière vérification : 2026-10-14.

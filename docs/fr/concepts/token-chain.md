# Chaîne de jetons : un jeton par étape

[English](../../concepts/token-chain.md)

Utilisez le [schéma du module 05](../../../assets/architecture/05.fr.svg) et la
[vue Mermaid générée](../../../assets/architecture/STEPS.fr.md#05--qui-porte-les-droits).
`assets/architecture/workshop.drawio` reste l'unique source d'architecture.

## La règle

Un jeton d'accès vise une seule ressource. Sa revendication `aud` (audience) désigne cette ressource.
Chaque ressource vérifie l'émetteur, le tenant, l'audience et l'expiration, puis les scopes ou les rôles.

```text
Alice -> client MCP : connexion
Client MCP -> APIM/Functions : jeton A, audience = serveur MCP gouverné
Functions -> Microsoft Graph : jeton B, audience = Microsoft Graph
Functions -> Azure Storage : jeton C, audience = Azure Storage
```

Le jeton A peut traverser API Management (APIM) vers la Function privée, car ils protègent une même ressource
MCP logique. Il n'est jamais envoyé à Graph ou Storage. La Function obtient un nouveau jeton par On-Behalf-Of
(OBO) pour un outil au nom de l'utilisateur, ou par identité managée pour un outil applicatif.

## Parcours synthétique

1. Alice se connecte. Le client demande le scope délégué du serveur MCP.
2. APIM valide le jeton A, le nom fixe de l'outil et le rôle applicatif d'Alice.
3. `whoami` échange l'assertion d'Alice contre le jeton B.
4. `read_report_as_user` obtient un jeton Storage distinct avec le contexte d'Alice.
5. `read_report_as_app` obtient un jeton Storage de l'identité managée, sans contexte Alice.

Le jeton MCP de Bob peut être valide alors que Storage refuse `read_report_as_user`. Eve ne peut pas obtenir
le jeton réservé aux utilisateurs affectés. Un refus HTTP 403 en aval peut apparaître dans une erreur MCP sous HTTP 200.

## Résultat attendu

Vous identifiez l'émetteur, l'audience et le propriétaire des droits à chaque étape sans examiner de jeton réel.
Aucun jeton, prompt, argument ou résultat n'est journalisé. APIM reste le seul point d'entrée public.

> [!WARNING]
> Transmettre un jeton n'est pas déléguer. N'envoyez jamais le jeton MCP à une API aval, n'élargissez pas les
> audiences acceptées et ne revenez pas à l'identité du développeur après un échec OBO.

## Sources

- [Jetons d'accès](https://learn.microsoft.com/entra/identity-platform/access-tokens).
- [Validation des revendications](https://learn.microsoft.com/entra/identity-platform/claims-validation).
- [Flux On-Behalf-Of](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow).
- [Autorisation MCP intégrée et métadonnées de ressource protégée (Preview)](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp).

Dernière vérification : 2026-10-14.

# On-Behalf-Of ou identité managée

[English](../../concepts/obo-and-managed-identity.md)

Utilisez le [schéma du module 05](../../../assets/architecture/05.fr.svg). Les deux parcours passent par API
Management (APIM). Seule change l'identité utilisée pour l'appel en aval.

| Propriété | On-Behalf-Of (OBO) | Identité managée |
|---|---|---|
| Détenteur des droits | Utilisateur connecté | Charge de travail |
| Type de jeton | Jeton délégué pour l'API en aval | Jeton applicatif pour l'API en aval |
| Outil | `read_report_as_user`, `whoami` | `read_report_as_app` |
| Alice et Bob | Résultats différents selon leurs droits | Même résultat si l'application est autorisée |
| Secret | Aucun ; fédération prise en charge | Aucun ; Azure gère l'identité |
| Échec | Renvoyer le refus, sans identité de repli | Conserver le rôle limité à la ressource exacte |

## Décision

Choisissez OBO si le service en aval doit appliquer les droits de l'utilisateur ou conserver son contexte d'audit.
Choisissez l'identité managée si tous les appelants autorisés doivent recevoir le même résultat applicatif.
Documentez ce choix pour chaque outil. L'accès applicatif ne doit jamais servir à compenser un droit que l'utilisateur n'a pas.

Alice a le rôle Storage Blob Data Reader, pas Bob. `read_report_as_user` réussit donc pour Alice et échoue pour Bob.
L'identité managée dispose de ce rôle sur un seul conteneur, qui contient le rapport synthétique ; `read_report_as_app` renvoie le
même rapport aux deux utilisateurs.

## Résultat attendu

Vous savez prédire les quatre résultats pour Alice et Bob et dire quels droits Storage applique. Chaque appel en
aval utilise un nouveau jeton pour sa propre audience. Aucun secret client, aucun rôle attribué sur tout l'abonnement, aucun
repli sur l'identité du développeur.

## Sources

- [Flux On-Behalf-Of](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow).
- [Authentification sans secret avec les identités managées](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/secretless-authentication).
- [Fédération avec une identité managée affectée par l'utilisateur](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).

Dernière vérification : 2026-10-14.

# On-Behalf-Of or managed identity

[Français](../fr/concepts/obo-and-managed-identity.md)

Use the [module 05 architecture](../../assets/architecture/05.en.svg). Both paths enter through API Management
(APIM). They differ only in the identity used for the downstream call.

| Property | On-Behalf-Of (OBO) | Managed identity |
|---|---|---|
| Rights owner | Signed-in user | Application workload |
| Token type | Delegated downstream token | App-only downstream token |
| Workshop tool | `read_report_as_user`, `whoami` | `read_report_as_app` |
| Alice versus Bob | May differ because user rights apply | Same result when the app has access |
| Secret | None; use supported federation | None; Azure manages the credential |
| Failure rule | Return the denial; no fallback identity | Keep exact resource-scoped role |

## Decision

Choose OBO when the downstream service must enforce the user's rights or audit the user context. Choose managed
identity when every authorized caller should receive the same application-owned result. Document the choice per
tool. Do not use app-only access to imitate a user or to bypass a user's missing permission.

For the workshop, Alice has Storage Blob Data Reader and Bob does not. `read_report_as_user` therefore succeeds
for Alice and returns a downstream denial for Bob. The managed identity has Storage Blob Data Reader on one
synthetic report container, so `read_report_as_app` returns the same synthetic report for both users.

## Expected outcome

You can predict all four Alice/Bob results and identify whose rights Storage enforces. Every downstream call uses
a new token for the downstream audience. No client secret, broad subscription role or developer-identity fallback
is present.

## Sources

- [On-Behalf-Of flow](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow).
- [Secretless authentication with managed identities](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/secretless-authentication).
- [Federated identity credential with a user-assigned managed identity](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity).

Last verified: 2026-10-14.

# Références de l'atelier

Ces liens officiels permettent d'approfondir les sujets abordés. Vous n'avez pas besoin de tout lire pour commencer :
suivez d'abord le guide du module. Les synthèses françaises sont originales ;
les pages externes peuvent rester en anglais. La vérification des sources ne prouve pas qu'un déploiement fonctionne.
Le [registre technique](../sources.md), en anglais, détaille aussi chaque fichier inspecté et les limites de réutilisation.

## Choisir son poste et isoler ses ressources

Commencez par [le guide de démarrage](GETTING-STARTED.md), dans un dev container VS Code ou un terminal local.
Les deux utilisent les mêmes contrôles, les mêmes paramètres privés et la même racine Terraform.
Chaque participant garde son suffixe aléatoire : il réduit les conflits de noms, mais ne change jamais les quotas.

- [Dev Containers VS Code](https://code.visualstudio.com/docs/devcontainers/containers) : ouvrir la copie du dépôt, consulter le journal et vérifier le terminal réellement utilisé.
- [Moteurs alternatifs](https://code.visualstudio.com/remote/advancedcontainers/docker-options) : sélection explicite de Podman 5+, pas de bascule automatique.
- [Features officielles](https://github.com/devcontainers/features) : empreintes figées dans la configuration, versions d'outils choisies ; construction toujours à valider.
- [Nommage Azure](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules), [quotas](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits) : distinguer l'unicité des noms de la capacité partagée.
- [Groupe AzureRM](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/resources/resource_group), [lecture d'un groupe existant](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs/data-sources/resource_group) : ne gérer que les objets créés pour l'atelier.
- [Tests simulés Terraform](https://developer.hashicorp.com/terraform/language/tests/mocking) : vérifier les plans sans appel Azure, sans prétendre valider un déploiement.

Dernière vérification : 2026-10-14. Aucun moteur de conteneurs n'était disponible sur le poste de l'auteur pour tester l'exécution du conteneur.

## Pour aller plus loin : exemples et versions retenues

<details>
<summary>Consulter les versions exactes, les licences et les limites connues</summary>

| Source | Version / instantané | Usage et limite |
|---|---|---|
| [Functions .NET](https://github.com/Azure-Samples/remote-mcp-functions-dotnet/tree/468c518c884ec318e3001b9573254c9e775409c9) | `468c518c884ec318e3001b9573254c9e775409c9` | Base du serveur, MIT ; conserver les notices en cas d'adaptation. Le host.json amont, en mode Anonymous, ne convient pas au module 02. |
| [SDK C#](https://github.com/modelcontextprotocol/csharp-sdk/tree/6fa3825973949a9c4f0cd8af344e15a8db09dc35) | 2.2.0, `6fa3825973949a9c4f0cd8af344e15a8db09dc35` | Initiation à stdio ; transition de licences Apache-2.0/MIT à vérifier fichier par fichier. Documentation CC-BY-4.0. |
| [AI Gateway labs](https://github.com/Azure-Samples/AI-Gateway/tree/1679e3137d2fe7592d2a668d77ff71550d35b69e) | `1679e3137d2fe7592d2a668d77ff71550d35b69e` | Modèles PRM, stratégies et inventaire, MIT. Pas d'import de catalogues ni de notebooks complets. |
| [Inspector 2.9.0](https://github.com/modelcontextprotocol/inspector/tree/ae865a19178ddf6f375780a02e9c77c4cf4da184) | Installation vérifiée | Commandes du tableau, identifiants en mémoire uniquement et négociation du protocole. |
| [Release Inspector 2.11.0](https://github.com/modelcontextprotocol/inspector/releases/tag/2.11.0) | Version candidate pour comparaison | Release GitHub disponible, mais paquet absent du registre configuré lors du test. Aucun changement silencieux de version ou de registre. |
| [Spécification MCP](https://modelcontextprotocol.io/specification/2026-07-28) | 2026-07-28 | Référence de l'atelier ; vérifier la version du protocole que chaque client prend réellement en charge. |

</details>

## 00 - Environnement, tenant et abonnement

- [Module 00 publié](../../modules/00-prerequisites/README.fr.md), [publication sur GitHub Pages](HOSTING.md) et [demande administrateur](../requests/identity-request.md).
- [Terraform 1.16.6](https://releases.hashicorp.com/terraform/1.16.6/) : binaire de test vérifié avec l'empreinte officielle ; conteneur toujours à construire.
- [Autorisations effectives ARM](https://learn.microsoft.com/rest/api/authorization/permissions/list-for-resource-group) : actions moins exclusions, entrée par entrée ; pagination limitée au même périmètre.
- [Workflows GitHub Pages](https://docs.github.com/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages) : publication statique des guides, sans site documentaire Azure. Vérifié le 2026-10-21.
- [Choisir tenant et abonnement](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli) : contexte Azure CLI.
- [Connexion interactive](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively) : navigateur et authentification multifacteur, jamais de mot de passe dans une commande.
- [Attribution de rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli) : autorisation distincte et périmètre minimal.
- [AzureRM 5.9.0](https://registry.terraform.io/providers/hashicorp/azurerm/5.9.0/docs), [AzureAD 3.10.0](https://registry.terraform.io/providers/hashicorp/azuread/3.10.0), [AzAPI 2.13.0](https://registry.terraform.io/providers/Azure/azapi/2.13.0) : versions candidates, combinaison non validée.
- [Création Codespaces](https://docs.github.com/en/codespaces/developing-in-a-codespace/creating-a-codespace-for-a-repository) et [ports privés](https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace) : budget et origine de la redirection OAuth.

## 01 - Protocole et clients

- [Module 01 exécutable](../../modules/01-discover-mcp/README.fr.md) : serveur local .NET 10, SDK 2.2.0
  et Hosting 10.0.13 verrouillés ; découverte et appel réels vérifiés avec le SDK et Inspector 2.9.0.
  L'approbation VS Code reste manuelle. Aucun déploiement Azure ni fonctionnalité Preview ici.
- [Approbations VS Code](https://code.visualstudio.com/docs/agents/run/approvals) : permissions manuelles
  et choix par outil ; ne pas activer l'approbation globale.
- [Architecture](https://modelcontextprotocol.io/specification/2026-07-28/architecture), [transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports), [outils](https://modelcontextprotocol.io/specification/2026-07-28/server/tools), [autorisation](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization).
- [VS Code MCP](https://code.visualstudio.com/docs/agent-customization/mcp-servers) : configuration, confiance et approbations.
- [Documentation Inspector](https://modelcontextprotocol.io/docs/tools/inspector), [client web](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/web), [configuration](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/configuration), [autorisation](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/authorization).
- [Stockage des secrets 2.9.0](https://github.com/modelcontextprotocol/inspector/blob/2.9.0/docs/secret-storage.md), [sélection du stockage](https://github.com/modelcontextprotocol/inspector/blob/2.9.0/core/auth/node/secret-store-selection.ts) : ne pas enregistrer les en-têtes d'authentification.

## 02 - Functions et clé système

- [Serveur MCP distant](https://learn.microsoft.com/azure/azure-functions/scenario-custom-remote-mcp-server), [liaisons MCP](https://learn.microsoft.com/azure/azure-functions/functions-bindings-mcp), [Flex Consumption](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan).
- [Ressource Flex AzureRM 5.9.0](https://github.com/hashicorp/terraform-provider-azurerm/blob/v5.9.0/website/docs/r/function_app_flex_consumption.html.markdown) : identité managée et restrictions réseau ; ne pas reprendre l'exemple de clé tel quel.

## 03 - Authentification et rôles

- [Autorisation MCP App Service](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp) : PRM en **Preview**.
- [Parcours VS Code](https://learn.microsoft.com/azure/app-service/configure-authentication-mcp-server-vscode) : reprendre la préautorisation, pas la création de secret.
- [Tutoriel Functions MCP](https://learn.microsoft.com/azure/azure-functions/functions-mcp-tutorial) : extension MCP retenue ; variante auto-hébergée (**Preview**) non retenue.
- [Rôles applicatifs](https://learn.microsoft.com/entra/identity-platform/howto-add-app-roles-in-apps) : l'affectation d'un utilisateur est distincte du consentement délégué.

## 04 - Passerelle et réseau privé

- [Exposer un serveur existant](https://learn.microsoft.com/azure/api-management/expose-existing-mcp-server), [sécuriser MCP](https://learn.microsoft.com/azure/api-management/secure-mcp-servers), [vue d'ensemble](https://learn.microsoft.com/azure/api-management/mcp-server-overview).
- [Gestion programmatique](https://learn.microsoft.com/azure/api-management/manage-mcp-servers-rest-api) : API `2025-09-01-preview`, **Preview**.
- [Stratégie de validation Entra](https://learn.microsoft.com/azure/api-management/validate-azure-ad-token-policy) : audience et tenant exacts.
- [Intégration réseau sortante](https://learn.microsoft.com/azure/api-management/integrate-vnet-outbound), [réseau Functions](https://learn.microsoft.com/azure/azure-functions/functions-networking-options) : rendre le backend privé ; l'intégration sortante seule ne bloque pas son accès public.
- [Limite par clé](https://learn.microsoft.com/azure/api-management/rate-limit-by-key-policy), [filtre IP](https://learn.microsoft.com/azure/api-management/ip-filter-policy), [Application Insights](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights), [points de terminaison privés App Service](https://learn.microsoft.com/azure/app-service/overview-private-endpoint) : utilisés par le [guide du module 04](../../modules/04-governed-gateway/README.fr.md), vérifiés le 2026-10-15.
- [REST vers MCP, option 04b](https://learn.microsoft.com/azure/api-management/export-rest-mcp-server).

## 05 - Délégation et identité managée

- [On-Behalf-Of](https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow) : deux jetons, deux audiences ; ne pas reprendre l'exemple de secret client.
- [Fédération avec une identité managée](https://learn.microsoft.com/entra/workload-id/workload-identity-federation-config-app-trust-managed-identity) : assertion sans secret et permissions exactes.

## 06 - Télémétrie et inventaire

- [APIM et Application Insights](https://learn.microsoft.com/azure/api-management/api-management-howto-app-insights) : diagnostics sans corps de message.
- [Enregistrement API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server) : uniquement l'URL de la passerelle.
- [BYO MCP Microsoft 365, option 06b](https://learn.microsoft.com/microsoft-365/admin/manage/manage-byo-mcp-server) : **Preview**, licences et éligibilité à revérifier, démonstration seulement.

## 07 - Clients facultatifs

- [Authentification Foundry](https://learn.microsoft.com/azure/foundry/agents/how-to/mcp-authentication) : contexte utilisateur ou application ; certains flux en **Preview**.
- [Copilot Studio MCP](https://learn.microsoft.com/microsoft-copilot-studio/mcp-add-existing-server-to-agent) : reporter le flux manuel s'il exige un secret client.

## 99 - Nettoyage

- [Terraform destroy](https://developer.hashicorp.com/terraform/cli/commands/destroy) : vérifier le périmètre et le plan avant approbation.
- [Rôles Azure](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-cli) : distinguer les affectations créées des objets fournis.

## Publier le portail sans accès aux tenants

[Guide de publication et d'hébergement](HOSTING.md) : GitHub Pages pour les guides, Terraform privé pour les ressources.
Le portail ne collecte pas les clés Azure et n'exécute aucun déploiement pour le visiteur.

- [Workflow Pages officiel](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [source de publication](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) : workflow lancé manuellement, qui publie uniquement un artefact statique autorisé.
- [OIDC GitHub vers Azure](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure) : fédération facultative dans le pipeline d'un participant, sans secret partagé.
- [Authentification App Service](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization), [authentification ACA](https://learn.microsoft.com/azure/container-apps/authentication) : services et cibles distincts, à faire approuver au préalable.

Dernière vérification : 2026-10-14. Aucune publication ni modification Azure/Entra effectuée.

## Schémas et droits des icônes

[Provenance des icônes et reproduction des schémas](../../assets/architecture/README.md).
Les marques restent la propriété de leurs titulaires et ne servent pas de logo à l'atelier.
Le SDK canvas Copilot est en **Preview**.

Dernière vérification : 2026-10-14.

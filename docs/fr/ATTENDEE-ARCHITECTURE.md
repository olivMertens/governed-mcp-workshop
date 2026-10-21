# Comprendre l'architecture en images

Suivez le chemin d'un appel d'outil, puis ajoutez les contrôles un par un.
Choisissez un module ci-dessous ou utilisez Suivant et Précédent dans son schéma.
Chaque animation fait partie du module correspondant, dans les deux parcours : commencez par comprendre le schéma,
puis utilisez le lien sous l'animation pour passer aux exercices.
Ces schémas expliquent l'architecture. Ils n'exécutent aucune commande et ne valident pas votre environnement.

<!-- module-animations -->

## 9. Qu'est-ce que Microsoft Agent 365 ?

**Agent 365 est un plan de contrôle des agents, pas un outil de création d'agents ni un serveur MCP.**
Il vous aide à observer, gouverner et sécuriser les agents de votre organisation, même lorsqu'ils proviennent
de plateformes différentes. Son registre central rassemble l'inventaire, les propriétaires et le cycle de vie.
Microsoft Entra gère les identités et les accès, Microsoft Purview contribue à la gouvernance des données
et Microsoft Defender protège contre les menaces. Les fonctions disponibles dépendent des licences et de la configuration.

| Composant | Son rôle |
|---|---|
| Azure API Center | Vous aide à retrouver les adresses MCP approuvées. Ce n'est pas une étape à l'exécution. |
| Microsoft Agent 365 | Fournit une vue centrale et des décisions de gouvernance sur les agents et les outils. |
| Azure API Management | Applique les contrôles configurés aux appels qui traversent la passerelle. |

Agent 365 est généralement disponible pour le segment Commercial depuis le 2026-05-01.
Son **intégration avec API Management reste en Preview**. Sur API Management v2, elle permet l'inventaire des serveurs
et le blocage d'un serveur entier (HTTP 403). Le blocage d'un outil par Agent 365 exige le
**niveau AI Gateway (Preview)**. Les stratégies par rôle et par outil de notre passerelle v2 sont un contrôle distinct.

L'intégration exige le consentement de l'administrateur du tenant pour le rôle **A365 MCP Gateway Policy Operator**.
Ce rôle permet de lire les ressources de passerelle et de lire ou modifier les stratégies d'API des abonnements du tenant.
Il s'agit d'une lecture facultative, pas d'une étape de configuration de l'atelier.
Aucune commande participant ne demande cette autorisation.

Agent 365 ne redirige pas les clients vers la passerelle et ne remplace ni les contrôles d'audience, ni les rôles,
ni l'approbation humaine des outils d'écriture. Utilisez toujours l'URL de la passerelle et bloquez l'accès direct au backend.
Limitez les journaux de l'atelier aux métadonnées : jamais de jetons, prompts, arguments ou résultats.

**À retenir :** API Center vous aide à trouver la porte ; Agent 365 aide les administrateurs à décider ce qui est permis ;
API Management contrôle les appels à la porte.

## Sources

- [Vue d'ensemble et disponibilité de Microsoft Agent 365](https://learn.microsoft.com/microsoft-agent-365/overview)
- [Intégration Agent 365 et API Management (Preview)](https://learn.microsoft.com/azure/api-management/agent-365)
- [Découvrir les serveurs MCP avec API Center](https://learn.microsoft.com/azure/api-center/register-discover-mcp-server)

Dernière vérification : 2026-10-21.

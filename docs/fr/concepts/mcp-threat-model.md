# Modèle de menaces MCP

[English](../../concepts/mcp-threat-model.md)

Ce modèle couvre le point d'entrée gouverné prévu. Utilisez les schémas des
[modules 04](../../../assets/architecture/04.fr.svg) et [06](../../../assets/architecture/06.fr.svg).
La Function privée n'est pas un second point d'entrée public.

| Menace | Exemple | Contrôle obligatoire | Preuve |
|---|---|---|---|
| Empoisonnement d'outil | Description ou comportement modifié après revue | Sources épinglées, liste statique, revue, approbation des écritures | Liste et révision conformes |
| Injection de prompt | Un contenu demande une action dangereuse | Contenu traité comme des données, outils minimaux, rôles, approbation, validation | Écriture interdite refusée |
| Transmission de jeton | Jeton MCP envoyé à Graph ou Storage | Un jeton et une audience par étape ; OBO ou identité managée | Mauvaise audience : HTTP 401 |
| Adjoint confus | Bob fait agir l'identité applicative à sa place | Outils utilisateur/app séparés, rôles, droits restreints | Écriture de Bob : HTTP 403 |
| Outil trop large | Commande générique ou écriture illimitée | Schémas fixes, données synthétiques, moindre privilège | Seule l'opération prévue existe |
| Contournement APIM | Appel direct à Functions | APIM seul point public, point de terminaison privé | Accès direct refusé |
| Télémétrie sensible | Jetons, prompts ou résultats dans les journaux | Zéro octet de corps ; métadonnées approuvées | Aucun champ de contenu |
| Secret réutilisé | Clé ou jeton volé | Durée de vie courte, aucun secret dans les fichiers | Aucun identifiant dans un commit |

Les métadonnées de ressource protégée (PRM) sont en **Preview**. Les API de gestion MCP d'API Management avec
`2025-09-01-preview` sont en **Preview**. Elles ne remplacent pas l'autorisation appliquée par la passerelle et par la ressource.

## Contexte facultatif réservé à l'animateur

L'intégration Microsoft Agent 365 est en **Preview**. Avec API Management v2, elle permet d'inventorier et de bloquer un serveur.
Le blocage par outil, l'observabilité par outil et la protection contre les menaces exigent
**AI Gateway (Preview)**, hors parcours principal. Le consentement au niveau du tenant et la rédaction de
stratégies ne sont jamais confiés aux participants.

Le transfert d'identité Foundry est en **Preview** lorsqu'il est documenté. Il n'autorise pas la transmission du
jeton MCP à Graph ou Storage. Les clients facultatifs utilisent toujours APIM et un parcours sans secret pris en charge.

## Résultat attendu

Pour chaque menace, vous savez nommer un contrôle préventif et une preuve mesurable : un refus ou une vérification
dans les journaux. Aucune mesure n'affaiblit l'audience unique, l'approbation des écritures, le moindre privilège, les
journaux sans contenu ou le point d'entrée APIM unique.

## Sources

- [Attaque MCP par changement malveillant](https://learn.microsoft.com/security/zero-trust/catalog-ai-attack-techniques/rug-pull-attack).
- [Injection de prompt](https://learn.microsoft.com/security/zero-trust/catalog-ai-attack-techniques/prompt-injection).
- [Sécuriser MCP dans API Management](https://learn.microsoft.com/azure/api-management/secure-mcp-servers).
- [Surveiller le trafic MCP](https://learn.microsoft.com/azure/api-management/monitor-mcp-servers).
- [Agent 365 et API Management (Preview)](https://learn.microsoft.com/azure/api-management/agent-365).

Dernière vérification : 2026-10-14.

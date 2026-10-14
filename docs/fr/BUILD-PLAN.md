# Parcours prévu - Governed MCP on Azure

Version pédagogique française. Le [plan technique original](../BUILD-PLAN.md) reste la référence de construction.
Un module par session, branche et PR. Aucun module n'est encore implémenté ou validé.
Une conception n'est pas une commande de déploiement. Lire le guide publié et valider avant de poursuivre.

## 00 - Prérequis et environnement

**Préparer :** outils épinglés, dev container, précontrôle, région, quotas, budget et demande d'identité.
Choisir tenant et abonnement de test ; distinguer administration Entra, création de ressources et attribution de rôles.
**À démontrer :** vrai précontrôle réussi et demande exploitable par l'administrateur d'identité.
**Préparation partielle disponible :** choix du poste, configuration dev container épinglée, contrôles d'outils communs,
suffixe aléatoire privé conservé et socle Terraform du groupe testé avec un provider simulé.
Construction du conteneur, précontrôle complet et validation Azure restent à effectuer.

## 01 - Découvrir MCP sans Azure

**Construire :** serveur C# local minimal sur entrées/sorties standard (stdio), outils et données synthétiques.
Connecter VS Code puis Inspector ; négocier la version du protocole.
**À démontrer :** découverte réelle, appel réussi, approbation client visible. Aucun coût Azure ni modèle requis.

## 02 - Serveur par clé, niveau 0

**Construire :** Functions Flex Consumption, Storage, télémétrie et identité managée avec Terraform.
Les cinq outils restent synthétiques ; l'écriture crée un message de file. Outils d'identité simulés jusqu'à 05.
**À démontrer :** 401 sans clé système MCP, 200 et résultat MCP réussi avec la clé.
Autorisation webhook `System`, jamais accès anonyme. Cette étape est brève et ne représente pas la cible d'entreprise.

## 03 - Identité Microsoft Entra, niveau 1

**Construire :** application MCP, audience propre, étendue `user_impersonation`, rôles Tools.Read, Tools.Write,
Tools.Execute.All, affectation requise, clients préautorisés et authentification intégrée.
Métadonnées de ressource protégée (PRM) en **Preview**. Pas de secret client.
**À démontrer :** 401 sans jeton ou avec mauvaise audience ; Alice et Bob affectés ; Eve exclue.

## 04 - API Management comme entrée unique, niveau 2

**Construire :** APIM Standard v2, API de gestion MCP `2025-09-01-preview` en **Preview**,
validation Entra, contrôle de rôle par outil, limite de débit et filtre IP.
Intégration réseau sortante, point de terminaison privé, DNS privé, accès public Function désactivé.
APIM et Functions protègent une seule ressource logique MCP. Zéro octet de corps dans les diagnostics.
**À démontrer :** écriture Bob 403 ; Alice 200 et succès MCP ; débit 429 ; Function directe refusée.
L'option 04b REST vers MCP ne remplace pas le serveur principal.

## 05 - On-Behalf-Of et accès applicatif, niveau 3

**Construire :** `whoami` vers Graph et `read_report_as_user` vers Storage avec On-Behalf-Of (OBO).
`read_report_as_app` utilise explicitement une identité managée. Aucun jeton MCP transmis aux API cibles.
Les identités managées et la fédération remplacent les secrets clients.
**À démontrer :** lecture déléguée autorisée pour Alice, refusée pour Bob ; même résultat applicatif pour les deux.
Noter HTTP et erreur MCP : un 403 cible peut être contenu dans HTTP 200.

## 06 - Observation et inventaire, niveau 4

**Construire :** requêtes Kusto Query Language (KQL) ou workbook avec outil, appelant authentifié, statut, latence
et corrélation. Inscrire uniquement l'adresse gouvernée dans Azure API Center.
**À démontrer :** qui appelle quoi et avec quel résultat, sans stocker jetons, prompts, arguments ou résultats.
API Center n'est ni une étape de routage ni une autorisation. Option Microsoft 365 BYO : **Preview**, facilitateur seulement.

## 07 - Clients supplémentaires, facultatif

**Démontrer :** le même serveur gouverné depuis un client Foundry ou Copilot Studio officiellement supporté
et sans secret. Revérifier licences, identité et statut **Preview** des fonctions choisies.
L'authentification OAuth manuelle Copilot Studio exigeant un secret reste reportée.
Cette démonstration du facilitateur ne bloque pas le nettoyage.

## 99 - Nettoyage

**Retirer :** ressources du workload d'abord, puis uniquement objets Entra, utilisateurs de test et affectations créés.
Lire le plan de destruction et obtenir l'approbation ; préserver identités fournies et infrastructure partagée.
**À démontrer :** inventaire des ressources du workshop vide, rôles et objets créés comptabilisés, rétention vérifiée.
Arrêter aussi Inspector et les codespaces inutilisés.

## Sources

[Plan technique anglais](../BUILD-PLAN.md), [gouvernance](LEARNING-GUIDE.md), [registre](REFERENCES.md).
Dernière vérification : 2026-10-14.

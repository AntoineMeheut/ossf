# Validation : portée et limites

[Accueil](../README.md) · [Développement](DEVELOPMENT.md) · [Tests Docker](../tests/docker/README.md)

Ce document distingue les vérifications du dépôt de la qualification d’une
application consommatrice. Un résultat de test est lié à une version et à un
environnement ; il ne garantit pas tous les usages du modèle.

## Installateurs — référence historique

Le [compte rendu du 27 septembre 2026](../tests/docker/RESULTS.md) documente les
installateurs Ubuntu 26.04.1 **ARM64**, leur configuration partagée, les
authentifications, réexécutions et tests d’erreur exécutés.

Ce compte rendu conserve les références CI de l’époque : ses anciens modèles
ont été remplacés. Ses résultats d’installation ne certifient pas les pipelines
actuels ni les deux architectures à la fois.

## Modèles CI — vérifications du 1er novembre 2026

| Périmètre | Vérifications réalisées |
| --- | --- |
| Helper partagé, six profils | 39 tests unitaires de rapports, politique, cohérence et publication simulée |
| Profils Python, Java et C | Compilation YAML par GitLab 19.4.1 et préparation d’overlays |
| Python | Fixture PEP 517 : wheel, pytest, couverture, packaging, pip-audit réel et CycloneDX sur poste ARM macOS/Python 3.14 |
| Java | Fixture Maven/JUnit sur Linux ARM64 : build propre, tests obligatoires, JaCoCo, SBOM et JAR exécutable |
| C | Fixture Linux ARM64 : Conan, builds couverture/Release, CTest, gcovr, Cppcheck et installation empaquetée |
| Dépendances C | Rapports Grype réels et comparaison au graphe Conan ; cas vide et bibliothèque ancienne avec détection effective d’alertes |
| Images Python, Java et C | Construction depuis les artefacts de fixtures et hooks runtime réussis sur Linux ARM64 ; UID 10001 vérifié |
| SonarScanner du profil C | Téléchargement avec SHA-256 fixé et lancement de la CLI indépendante de la plateforme |

Les fixtures et leurs journaux ont été gardés hors du dépôt public. Aucun code,
identifiant ou rapport d’une application utilisateur n’est nécessaire aux
exemples génériques. Les mises à jour de commentaires/docstrings sont vérifiées
avec les tests partagés et les contrôles de syntaxe pertinents.

## Ce que ces vérifications ne démontrent pas

- Une compilation YAML ne lance pas les jobs, n’enregistre pas de Runner et ne
  valide pas les autorisations des comptes applicatifs.
- Un test du publisher avec API simulée ne remplace pas l’écriture/relecture de
  la livraison réelle dans le Nexus cible.
- La réussite d’une fixture ne garantit pas les tests, services temporaires,
  dépendances natives ou contrats de démarrage d’une autre application.
- L’analyse **CFamily du profil C n’a pas été exécutée** sur l’instance Community
  Build du laboratoire. Ce profil nécessite son prérequis d’édition/analyseur.
- Les tests Linux ARM64 et l’émulation d’analyseurs AMD64 ne constituent pas une
  campagne native AMD64 équivalente.
- Les tests Docker partagent le noyau de l’hôte. Ils ne valident pas le reboot
  d’une VM, les sauvegardes/restaurations, TLS, les migrations ou la charge de production.
- Une absence d’alerte reste liée aux données et capacités des scanners. Elle
  ne prouve pas l’absence de vulnérabilité, notamment pour le matching CPE.

## Qualifier votre intégration

Avant d’autoriser les livraisons, vérifiez avec votre code :

1. le Runner, l’architecture et les références protégées ;
2. la résolution des dépendances, les vrais tests et les rapports de couverture ;
3. le comportement des images et la présence des fichiers runtime ;
4. la complétude des scans/SBOM et la cohérence de l’analyse Sonar avec le commit ;
5. les imports Dojo et une décision de refus effectivement bloquante ;
6. une publication approuvée, la relecture Nexus et les contrôles d’empreintes ;
7. les droits de consultation des personnes qui examinent les résultats.

Les [instructions CI](CI.md) décrivent les paramètres et diagnostics associés.

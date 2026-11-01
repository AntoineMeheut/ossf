# Helpers partagés des pipelines CI

[Catalogue](../README.md) · [Guide d’intégration](../../docs/CI.md) ·
[Documentation du code](../../docs/DEVELOPMENT.md)

Ce dossier assemble les overlays et implémente les intégrations SonarQube,
DefectDojo et Nexus. Les profils restent génériques : aucune application ou
configuration privée n’est nécessaire à leur distribution.

## Fichiers et responsabilités

| Fichier | Responsabilité |
| --- | --- |
| [prepare-example.py](prepare-example.py) | Copier un profil dans un nouveau dossier et ajouter le helper commun |
| [pipeline.py](pipeline.py) | Valider les rapports, exporter Sonar, décider dans Dojo et publier dans Nexus |
| [test_pipeline.py](test_pipeline.py) | Vérifier politique et publisher sans appeler les services externes |

L’assemblage est nécessaire : copier le dossier de profil seul ne fournit pas
`ci/pipeline.py`.

```sh
# Depuis la racine d’OSSF ; la destination doit être nouvelle.
python3 samples-gitlab-ci/security/prepare-example.py python /tmp/python-ci-overlay
```

Les choix sont `python`, `django`, `java`, `angular`, `angular-java` et `c`.
L’outil ne reçoit pas de source applicative et n’écrase pas un dossier existant.

## Interface du helper

Exécuter `python ci/pipeline.py <commande>` à la racine de l’application, dans
le job dont les variables et artefacts sont préparés :

| Commande | Résultat |
| --- | --- |
| `audit` | Exécution pip-audit de l’environnement résolu |
| `sonar-export` | Export d’une analyse Sonar liée au commit et de son statut qualité |
| `require-c-analyzer` | Refus si le serveur ne propose pas l’analyse C |
| `validate-dependency-check` | Validation du JSON OWASP standard |
| `gate` | Validation, imports synchrones Dojo et décision de publication |
| `publish` | Vérification des fichiers approuvés, écriture puis relecture Nexus |

`gate` et `publish` ont des effets sur les services. Une importation Python du
module ne lance aucune de ces opérations. Les accès et variables sont décrits
dans le [guide CI](../../docs/CI.md#variables-ci).

## Contrats de preuve

| Profil | Rapports Dojo requis | Fichiers approuvés avant `approval.json` |
| --- | --- | --- |
| Django / Angular | 8 | 3 |
| Python | 8 | 4 |
| Java / C | 7 | 4 |
| Angular + Java | 12 | 7 |

Les nombres ne comptent pas tous les fichiers de preuve : les JSON compagnons
OWASP, le graphe Conan et l’inventaire CycloneDX Grype sont également contrôlés
et hashés selon le profil.

Une donnée manquante, un scan invalide, un import incomplet ou une erreur API ne
produit pas d’approbation. La politique prend en compte les résultats actifs au
seuil, toutes les alertes pip/npm, les sévérités inconnues contrôlées, les erreurs
Cppcheck et une Quality Gate Sonar autre que `OK`. Consultez la
[politique complète](../../docs/CI.md#rapports-et-décision-de-publication).

En cas d’accord, les fichiers sont liés au commit et au pipeline par SHA-256.
Le publisher exige exactement le jeu prévu, vérifie chaque relecture et envoie
l’approbation en dernier. Un consommateur doit vérifier cette approbation et les
empreintes ; il ne s’agit pas d’une signature indépendante.

## Tests

```sh
python3 -m venv /tmp/ossf-policy-tests
/tmp/ossf-policy-tests/bin/pip install requests==2.34.2
/tmp/ossf-policy-tests/bin/python -m unittest discover \
  -s samples-gitlab-ci/security -p 'test_*.py'
```

Les 39 tests couvrent les six profils et leurs chemins de refus. Ils simulent
les clients des services et ne remplacent pas une exécution complète de votre
application. La [portée de validation](../../docs/VALIDATION.md) distingue tests
unitaires, compilation YAML, fixtures runtime et limites d’intégration.

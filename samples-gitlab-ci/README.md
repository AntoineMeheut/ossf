# Catalogue des modèles GitLab CI

[Accueil du projet](../README.md) · [Guide d’intégration](../docs/CI.md) ·
[Documentation du code](../docs/DEVELOPMENT.md)

Ces dossiers contiennent des configurations réutilisables et leurs helpers,
sans application de démonstration ni résultat applicatif privé.

| Dossier | Contrat du projet |
| --- | --- |
| [python](python/.gitlab-ci.yml) | Paquet PEP 517, pytest et wheel |
| [django](django/.gitlab-ci.yml) | Application Django et Gunicorn |
| [java](java/.gitlab-ci.yml) | Application Maven et JAR exécutable |
| [angular](angular/.gitlab-ci.yml) | Workspace npm et bundle SPA |
| [angular-java](angular-java/.gitlab-ci.yml) | Monorepo Angular/Maven, deux images |
| [c](c/.gitlab-ci.yml) | CMake/CTest, Conan 2, Cppcheck et Sonar CFamily |

## Préparer un overlay complet

Depuis la racine du dépôt :

```sh
python3 samples-gitlab-ci/security/prepare-example.py java /tmp/java-ci-overlay
```

La préparation ajoute `ci/pipeline.py` depuis le dossier partagé
[security](security/README.md). Copier uniquement le YAML ou le dossier de profil
ne fournit pas ce helper. La destination doit être nouvelle, puis les fichiers
doivent être examinés et fusionnés dans le dépôt de l’application.

Les différences de dépendances, de build, de licence et d’environnement sont
décrites dans le [guide CI](../docs/CI.md). Pour C, l’analyse Sonar exige CFamily ;
Community Build ne satisfait pas ce prérequis. Les identifiants d’administration
du laboratoire ne doivent pas être utilisés comme accès des jobs.

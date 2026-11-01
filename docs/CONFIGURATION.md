# Référence de configuration

[Accueil](../README.md) · [Installation](INSTALLATION.md) · [Variables CI](CI.md#variables-ci)

## Deux usages distincts

| Usage | Emplacement | Contenu |
| --- | --- | --- |
| Administration des services | `config/ossf.env` | Versions, comptes administrateurs, bases et clés de la plateforme |
| Exécution des pipelines | Variables protégées du projet GitLab | Accès CI dédiés à un projet SonarQube, un produit Dojo et un dépôt Nexus |

Le fichier d’administration n’est pas un fichier de variables à injecter dans
les jobs. Les éventuels `config/ci-*.env` locaux sont également exclus de Git ;
ils ne sont pas chargés par les installateurs.

## Créer et conserver le fichier privé

```sh
bash scripts/init-config.sh
chmod 600 config/ossf.env
```

L’initialiseur utilise OpenSSL pour produire des valeurs indépendantes et un
fichier privé. Il ne remplace pas une destination existante, y compris un lien
symbolique. Les commentaires du [modèle public](../config/ossf.env.example)
sont conservés. Protégez une sauvegarde et copiez le même fichier sur les VM.

Les scripts acceptent `OSSF_CONFIG=/chemin/vers/ossf.env`. Les options GitLab
`-d` et SonarQube `--archive` sont les seules substitutions de paramètres de
service par ligne de commande prévues ici.

## Format et règles de lecture

```text
# Exemple public sans secret réel
GITLAB_DOMAIN=gitlab.example.com
WAIT_TIMEOUT=900
```

- Une ligne contient `CLE=valeur` ; une ligne de commentaire commence par `#`.
- Ne pas ajouter `export`, de guillemets d’encadrement ni de commentaire en fin
  de valeur. Le fichier n’est pas un script shell.
- Les espaces, `$`, `#`, guillemets et antislashs présents **dans** une valeur
  sont littéraux. N’utilisez pas `source` ou `eval` pour lire le fichier.
- Les clés inconnues, doublons et lignes invalides sont rejetés. Les valeurs de
  l’environnement ne remplacent pas les paramètres lus dans le fichier.
- Les permissions de groupe/autres doivent être absentes. Le mode prévu est `600`.
- Les mots de passe doivent contenir au moins 16 caractères ASCII imprimables.
  Les applications peuvent imposer des contraintes supplémentaires.
- La clé AES DefectDojo contient exactement 32 caractères hexadécimaux.

## Paramètres communs et machine 1

| Clé | Défaut public | Usage |
| --- | --- | --- |
| `WAIT_TIMEOUT` | `900` | Attente de disponibilité, en secondes, pour tous les services |
| `GITLAB_DOMAIN` | `gitlab.example.com` | Nom DNS sans protocole, chemin ni port |
| `GITLAB_VERSION` | `19.4.1-ce.0` | Version APT exacte de GitLab CE |
| `RUNNER_VERSION` | `19.4.1-1` | Version APT exacte de Runner, sans enregistrement automatique |
| `GITLAB_ADMIN_USER` | `root` | Compte web imposé par l’installateur |
| `GITLAB_ROOT_EMAIL` | `admin@example.com` | Adresse de l’administrateur à personnaliser |
| `GITLAB_ROOT_PASSWORD` | Généré | Mot de passe web initial, vérifié aux réexécutions |
| `DOCKER_VERSION` | `29.8.1` | Version Engine/CLI résolue vers les paquets exacts |
| `COMPOSE_VERSION` | `5.5.1` | Version du plugin Compose |

## Machine 1 — DefectDojo

| Clé | Défaut public | Usage |
| --- | --- | --- |
| `DEFECTDOJO_VERSION` | `3.3.200` | Tag amont et version des images applicatives |
| `INSTALL_DIR` | `/opt/defectdojo` | Chemin absolu d’installation, sans espaces |
| `DD_PORT` | `8088` | Port HTTP publié, distinct du port interne 8080 de GitLab |
| `DD_TLS_PORT` | `8443` | Port TLS publié ; les certificats restent à configurer |
| `DD_ADMIN_USER` | `admin` | Nom du compte web, personnalisable |
| `DD_ADMIN_MAIL` | `admin@example.com` | Adresse du compte web à personnaliser |
| `DD_ADMIN_PASSWORD` | Généré | Mot de passe transmis à l’initialisation |
| `DD_DATABASE_USER` | `defectdojo` | Rôle PostgreSQL imposé par Compose amont |
| `DD_DATABASE_NAME` | `defectdojo` | Base interne imposée par Compose amont |
| `DD_DATABASE_PASSWORD` | Généré | Secret de la base interne |
| `DD_SECRET_KEY` | Généré | Clé de signature de l’application |
| `DD_CREDENTIAL_AES_256_KEY` | Généré | Clé de chiffrement des identifiants enregistrés |

PostgreSQL est joint sous le nom de service Compose `postgres:5432`. Il ne s’agit
pas du PostgreSQL de SonarQube. Si DefectDojo est installé sur une VM dédiée, les
paramètres Docker et DefectDojo s’appliquent à cette VM.

## Machine 2 — SonarQube

| Clé | Défaut public | Usage |
| --- | --- | --- |
| `SONARQUBE_ARCHIVE` | Vide | ZIP local ; vide signifie téléchargement officiel |
| `SONARQUBE_SHA256` | Empreinte dans le modèle | SHA-256 attendu du ZIP, non secret |
| `SONARQUBE_ADMIN_USER` | `admin` | Compte web imposé par l’installateur |
| `SONARQUBE_ADMIN_PASSWORD` | Généré | Remplace le mot de passe initial du compte web |
| `SONARQUBE_DB_USER` | `sonar` | Rôle PostgreSQL local, indépendant du compte Unix `sonar` |
| `SONARQUBE_DB_NAME` | `sonarqube` | Base PostgreSQL locale |
| `SONARQUBE_DB_PASSWORD` | Généré | Mot de passe du rôle PostgreSQL |

Le rôle et la base utilisent des lettres minuscules, chiffres et `_`, commencent
par une lettre ou `_`, et ne dépassent pas 63 caractères. Le ZIP doit correspondre
à la version fixée dans l’installateur, même si son chemin est personnalisé.

## Machine 3 — Nexus

| Clé | Défaut public | Usage |
| --- | --- | --- |
| `NEXUS_VERSION` | `3.96.3-01` | Version de l’archive Sonatype |
| `NEXUS_ADMIN_USER` | `admin` | Compte web imposé par l’installateur |
| `NEXUS_ADMIN_PASSWORD` | Généré | Remplace le secret initial généré par Nexus |

Nexus utilise le Java livré dans son archive, indépendamment du JDK installé
sur la machine SonarQube.

## État généré et changement de secrets

Les copies nécessaires aux applications sont de l’état d’exploitation :
propriétés JDBC, fichier privé Compose, secrets GitLab et empreintes sous
`/etc/ossf`. Elles ne deviennent pas des sources de configuration concurrentes.

Les empreintes enregistrées détectent les changements de paramètres protégés.
Elles ne permettent ni de retrouver un secret ni de le faire tourner.
Modifier le fichier puis relancer un installateur n’est pas une procédure de
rotation. Consultez les [règles de réexécution et de sauvegarde](OPERATIONS.md).

Pour ajouter une clé, mettez à jour le modèle, le lecteur/consommateur concerné,
la génération si nécessaire, les tests et cette référence. Les commentaires de
maintenance du code restent en anglais ; les guides d’utilisation sont en français.

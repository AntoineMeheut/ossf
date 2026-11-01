# Installer la plateforme

[Accueil](../README.md) · [Configuration](CONFIGURATION.md) · [Exploitation](OPERATIONS.md)

## Prérequis

Les installateurs ciblent Ubuntu Server **26.04**, sur `amd64` ou `arm64`, avec
systemd actif. La version Ubuntu 26.04.1 ARM64 a été utilisée pour la validation
documentée. Exécutez les commandes d’installation sur les machines Ubuntu cibles.

Prévoir un accès administrateur, un accès Internet aux dépôts APT et aux archives
des éditeurs, ainsi qu’une résolution DNS cohérente pour GitLab. Dimensionnez la
mémoire, le disque et les sauvegardes selon les services et les builds prévus.
La machine GitLab partage ses ressources avec DefectDojo et les jobs du Runner.

Docker est nécessaire pour DefectDojo et l’exécuteur Docker du Runner.
SonarQube et Nexus sont installés comme services natifs et ne nécessitent pas
Docker sur leurs machines respectives.

## Versions et dépendances

| Composant | Valeur du dépôt | Méthode |
| --- | --- | --- |
| GitLab CE | `19.4.1-ce.0` | Paquet Linux officiel |
| GitLab Runner | `19.4.1-1` | Paquet Linux officiel |
| SonarQube Community Build | `26.9.0.129388` | ZIP officiel et service `sonar` |
| Java / base SonarQube | OpenJDK 25 / PostgreSQL 18 | Paquets Ubuntu |
| Nexus Repository | `3.96.3-01` | Archive par architecture, Java embarqué |
| DefectDojo | `3.3.200` | Compose et images de la version amont |
| Base / cache DefectDojo | PostgreSQL `18.6` / Valkey `9.1.2` | Images définies par Compose amont |
| Docker Engine / Compose | `29.8.1` / `5.5.1` | Dépôt APT officiel Docker |

Les paramètres modifiables sont référencés dans
[ossf.env.example](../config/ossf.env.example). La version SonarQube est fixée
dans son installateur ; sa modification exige de vérifier ensemble le ZIP,
l’empreinte, le JDK et les tests. Les autres paquets Ubuntu suivent les dépôts
configurés sur les machines. Modifier une version ne lance pas une migration.

## Préparer la configuration

Sur le poste d’administration, avec Bash et OpenSSL :

```sh
git clone https://github.com/AntoineMeheut/ossf.git
cd ossf
bash scripts/init-config.sh
${EDITOR:-vi} config/ossf.env
```

L’initialiseur génère les secrets, conserve les commentaires de référence et
crée un fichier privé sans remplacer un fichier existant. Renseignez au minimum
le domaine GitLab et les adresses électroniques.

Copiez ensuite le dépôt complet et **le même** `config/ossf.env` sur chaque VM :

```sh
chmod 600 config/ossf.env
```

Les installateurs utilisent aussi `scripts/config.sh` et le modèle public :
copier un installateur seul ne suffit pas. Ne chargez pas le fichier privé avec
`source` ; son format est expliqué dans le [guide de configuration](CONFIGURATION.md).

## Machine 1 — Docker, GitLab et DefectDojo

Exécutez dans cet ordre, depuis la racine du dépôt :

```sh
sudo bash install-docker/docker-ubuntu-server.sh
sudo bash install-gitlab-ce/gitlab-ubuntu-server.sh
sudo bash install-defectdojo/defectdojo-ubuntu-server.sh
```

### Docker

L’installateur configure le dépôt signé de Docker, puis installe Engine, CLI,
Compose, Buildx et containerd. Il signale les paquets de distribution en conflit
sans les supprimer automatiquement. Le choix d’un pilote de stockage particulier
dans les tests imbriqués ne modifie pas cette installation native.

### GitLab CE et Runner

`GITLAB_DOMAIN` doit contenir un nom d’hôte, sans protocole, chemin ni port.
Le script configure `external_url` en HTTP avant l’installation du paquet.
L’option `-d` peut remplacer ce nom pour une invocation :

```sh
sudo bash install-gitlab-ce/gitlab-ubuntu-server.sh -d gitlab.example.com
```

Le compte web initial est `root`, avec le mot de passe du fichier privé.
L’installation du paquet Runner ne l’enregistre pas dans GitLab. Créez et
enregistrez ensuite un Runner de projet selon le [guide CI](CI.md#runner).

### DefectDojo

Le déploiement utilise les fichiers Compose amont dans `/opt/defectdojo`, le nom
de projet Compose `ossf-defectdojo`, PostgreSQL et Valkey internes à la pile.
L’installateur attend la fin de l’initialisation puis vérifie la page de connexion.

Le port HTTP par défaut est **8088** pour éviter le port interne 8080 de GitLab.
Sur une machine dédiée à DefectDojo, ce port peut être adapté avant installation.
Le port `DD_TLS_PORT=8443` ne dispense pas de configurer les certificats TLS.

Une copie privée d’état est écrite dans `/opt/defectdojo/.ossf.env`.
Utilisez le wrapper du dépôt pour conserver le traitement littéral des valeurs :

```sh
sudo bash scripts/defectdojo-compose.sh ps
sudo bash scripts/defectdojo-compose.sh logs --tail 50 uwsgi
```

## Machine 2 — SonarQube et PostgreSQL

```sh
sudo bash install-sonarqube/sonarqube-ubuntu-server.sh
```

Le script télécharge le ZIP officiel, vérifie son SHA-256, installe le JDK et
PostgreSQL, crée le compte de service `sonar`, prépare les limites système
d’Elasticsearch et attend le statut `UP`.

Le compte web est `admin`. L’installateur remplace son mot de passe initial par
`SONARQUBE_ADMIN_PASSWORD` et vérifie l’authentification. Le rôle PostgreSQL et
son mot de passe sont distincts de ce compte web.

Pour utiliser un ZIP officiel local :

```sh
sudo bash install-sonarqube/sonarqube-ubuntu-server.sh \
  --archive /path/to/sonarqube-26.9.0.129388.zip
```

`SONARQUBE_ARCHIVE` permet la même sélection dans le fichier de configuration.
`--archive` est prioritaire. Le contrôle d’empreinte reste obligatoire ; un ZIP
local ne supprime pas l’accès nécessaire aux paquets Ubuntu. Une réexécution
normale de la version déjà installée ne nécessite pas de télécharger le ZIP.

**Profil CI C :** l’édition Community Build installée ne contient pas CFamily.
Le [profil C](CI.md#profil-c) nécessite un serveur permettant l’analyse C et une
licence correspondante ; les installateurs ne réalisent pas ce changement.

## Machine 3 — Nexus

```sh
sudo bash install-nexus/nexus-ubuntu-server.sh
```

Le script choisit l’archive adaptée à l’architecture, vérifie le SHA-256 amont
et conserve le Java embarqué par Sonatype. Le service utilise le compte Unix
`nexus`, des binaires versionnés sous `/opt/nexus-*` et les données sous
`/opt/sonatype-work`.

Après disponibilité, le mot de passe initial généré par Nexus est remplacé par
`NEXUS_ADMIN_PASSWORD`, puis l’authentification est vérifiée. Terminez le parcours
de premier démarrage et l’examen/acceptation de la licence avant d’utiliser les
écritures d’artefacts. Les contrôles d’installation n’acceptent pas cette licence.

## Accéder aux interfaces

| Service | URL de laboratoire | Compte web initial |
| --- | --- | --- |
| GitLab | `http://gitlab.example.com` | `root` |
| DefectDojo | `http://<machine-1>:8088` | `DD_ADMIN_USER` |
| SonarQube | `http://<machine-2>:9000` | `admin` |
| Nexus | `http://<machine-3>:8081` | `admin` |

Remplacez les noms des machines par vos adresses résolues depuis le poste client.
Les mots de passe proviennent de votre fichier privé ; les comptes web ne sont
pas les comptes Unix des VM.

## Configuration externe et réexécution

Tous les installateurs et le wrapper acceptent un autre emplacement :

```sh
sudo env OSSF_CONFIG=/etc/ossf/ossf.env \
  bash install-gitlab-ce/gitlab-ubuntu-server.sh
```

Les scripts exigent root et systemd, s’arrêtent sur erreur et contrôlent la
disponibilité. `WAIT_TIMEOUT` borne cette attente, pas la durée totale d’APT.
`--help` reste accessible avant la création de la configuration.

Une réexécution de la même version gérée préserve les données et les secrets.
Les empreintes d’état détectent une configuration incompatible. Pour reprendre
une installation existante, changer un mot de passe ou monter de version, suivez
les procédures du [guide d’exploitation](OPERATIONS.md).

## Références éditeurs

- [Ubuntu 26.04](https://documentation.ubuntu.com/release-notes/26.04/).
- [Installation du paquet GitLab](https://docs.gitlab.com/install/package/).
- [Prérequis SonarQube](https://docs.sonarsource.com/sonarqube-community-build/server-installation/server-host-requirements).
- [Distribution Nexus](https://help.sonatype.com/en/download.html).
- [Version DefectDojo 3.3.200](https://github.com/DefectDojo/django-DefectDojo/releases/tag/3.3.200).
- [Docker sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

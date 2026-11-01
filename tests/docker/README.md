# Tests des installateurs dans Docker

[Accueil](../../README.md) · [Développement](../../docs/DEVELOPMENT.md) ·
[Portée de validation](../../docs/VALIDATION.md) · [Résultats historiques](RESULTS.md)

Ce harness exécute les **vrais installateurs**, gestionnaires de paquets, bases
et applications dans Ubuntu 26.04 avec systemd. Il s’utilise depuis la racine du
dépôt, avec Bash et un Docker Engine opérationnel.

## Lancer les vérifications

```sh
bash tests/docker/run.sh lint
bash tests/docker/run.sh failures
bash tests/docker/run.sh nexus
bash tests/docker/run.sh gitlab
bash tests/docker/run.sh defectdojo
bash tests/docker/run.sh sonarqube
# Tous les targets, séquentiellement :
bash tests/docker/run.sh all
```

| Target | Vérifications |
| --- | --- |
| `lint` | ShellCheck, syntaxe Bash, CLI, configuration et parsing YAML |
| `failures` | Entrées invalides, archive absente, checksum erroné, Docker absent et propagation d’erreur APT |
| `nexus`, `gitlab`, `defectdojo`, `sonarqube` | Installation réelle, disponibilité, configuration, authentification et réexécution |

Prévoir plusieurs Go de téléchargements, des dizaines de Go libres et la mémoire
nécessaire au service le plus lourd, particulièrement GitLab. SonarQube télécharge
son ZIP officiel par défaut. Pour réutiliser un ZIP officiel local :

```sh
SONARQUBE_ARCHIVE=/absolute/path/sonarqube-26.9.0.129388.zip \
  bash tests/docker/run.sh sonarqube
```

## Isolation et noyau partagé

Les conteneurs ne publient aucun port hôte et ne montent jamais son socket Docker.
Les intégrations systemd utilisent toutefois `--privileged --cgroupns private` et
partagent le noyau de Docker. Les scripts de paquets et Sonar peuvent changer
`vm.max_map_count` : le runner capture sa valeur et la restaure après suppression
du conteneur.

Utilisez un environnement Docker dédié et exécutez ces intégrations en série,
sans autre charge modifiant ce paramètre. Les services nécessitant la console
ou le contrôle du noyau sont masqués dans l’image de test, notamment les sysctls
automatiques de systemd.

Le test DefectDojo installe Docker/Compose avec l’installateur de production,
le réexécute et lance `hello-world` dans un daemon interne isolé. Seul ce daemon
**de test** utilise VFS et désactive le stockage d’images containerd : cela évite
le problème d’OverlayFS imbriqué avec Docker 29. L’installateur de production ne
change pas le pilote de stockage de l’hôte.

## Configuration et assertions

Les tests génèrent leur propre fichier privé dans le conteneur et ne copient
jamais `config/ossf.env` du poste. Les secrets de test exercent espaces,
guillemets, `$`, antislashs et ponctuation d’URL. Sonar utilise aussi un nom de
base/rôle personnalisé et Dojo un nom d’administrateur personnalisé.

Les tests runtime :

1. copient un snapshot des installateurs et du modèle public ;
2. vérifient disponibilité et configuration ;
3. réexécutent la même installation ;
4. contrôlent les empreintes de la configuration et des fichiers de secrets ;
5. vérifient l’authentification des quatre applications.

La réexécution Sonar omet l’archive. Dojo vérifie l’initialisation et ses six
services persistants. Seul le test d’échec APT remplace le gestionnaire de paquets
pour contrôler la propagation d’une erreur.

Le target GitLab compile les modèles via son processeur YAML installé. Il
n’enregistre pas de Runner et ne lance pas les pipelines applicatifs. Pour la
politique et le publisher CI, utilisez aussi les
[tests Python partagés](../../docs/DEVELOPMENT.md#vérifications-locales).

## Journaux et options

Les conteneurs sont supprimés après succès ou échec. Les journaux sont copiés
dans le dossier temporaire affiché.

| Variable | Usage |
| --- | --- |
| `TEST_LOG_DIR` | Répertoire parent des journaux |
| `TEST_KEEP_CONTAINER=1` | Conserver le conteneur pour diagnostic ; le nettoyage et la restauration du noyau restent alors à faire |
| `TEST_PLATFORM=linux/amd64` | Choisir la plateforme AMD64 |
| `TEST_PLATFORM=linux/arm64` | Choisir la plateforme ARM64 |

Préférez le matériel natif. L’émulation peut échouer sur les contrôles seccomp
d’Elasticsearch ; ne les désactivez pas pour obtenir artificiellement un succès.
Un test d’architecture ne qualifie pas l’autre. Ces tests ne remplacent pas les
vérifications de reboot VM, réseau, TLS, sauvegarde/restauration, migration et
charge de production.

Le [compte rendu historique](RESULTS.md) décrit les versions et contrôles exécutés
à sa date. Le [guide de validation actuel](../../docs/VALIDATION.md) explique leur
portée par rapport aux modèles CI actuels.

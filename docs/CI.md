# Intégrer un pipeline GitLab CI

[Accueil](../README.md) · [Architecture](ARCHITECTURE.md) · [Helpers CI](../samples-gitlab-ci/security/README.md)

## Choisir le profil

| Profil | Structure attendue | Dépendances et SAST | Rapports importés dans Dojo |
| --- | --- | --- | --- |
| [python](../samples-gitlab-ci/python/.gitlab-ci.yml) | `pyproject.toml`, `requirements.txt`, `src/`, `tests/` | pip-audit, OWASP, GitLab Semgrep | 8 |
| [django](../samples-gitlab-ci/django/.gitlab-ci.yml) | `manage.py`, `requirements.txt`, application Django | pip-audit, OWASP, GitLab Semgrep | 8 |
| [java](../samples-gitlab-ci/java/.gitlab-ci.yml) | `pom.xml`, `src/main/`, `src/test/` | OWASP Maven, GitLab Semgrep | 7 |
| [angular](../samples-gitlab-ci/angular/.gitlab-ci.yml) | Workspace npm à la racine | npm audit, OWASP, GitLab Semgrep | 8 |
| [angular-java](../samples-gitlab-ci/angular-java/.gitlab-ci.yml) | `frontend/` npm et `backend/` Maven | npm audit, OWASP npm/Maven, GitLab Semgrep | 12 |
| [c](../samples-gitlab-ci/c/.gitlab-ci.yml) | `CMakeLists.txt`, recette et verrou Conan, sources et tests C | Grype et Cppcheck | 7 |

Chaque profil ajoute GitLab Secret Detection, l’analyse SonarQube, la construction
et le contrôle de l’image, GitLab Container Scanning, les SBOM CycloneDX, la
barrière DefectDojo et la publication conditionnelle dans Nexus.

GitLab CE ne fournit pas Dependency Scanning Ultimate. Les outils de dépendances
ci-dessus sont les alternatives explicites de ces exemples. Leurs rapports sont
des artefacts CI ; les tableaux de bord de vulnérabilités Ultimate ne sont pas
supposés disponibles. Le profil C utilise Cppcheck à la place de C/C++ Advanced
SAST et nécessite CFamily pour SonarQube.

## Préparer et fusionner les fichiers

Depuis votre copie d’OSSF, choisissez **un** profil :

```sh
python3 samples-gitlab-ci/security/prepare-example.py python /tmp/python-ci-overlay
# Autres choix : django, java, angular, angular-java, c
```

La destination doit être nouvelle. Le script copie le profil et installe le
helper partagé sous `ci/pipeline.py`. Il ne reçoit pas de chemin d’application
et ne copie pas vos sources.

Examinez l’overlay, puis fusionnez son contenu à la racine du dépôt de votre
application. Conservez vos manifestes, verrous, sources et tests. Fusionnez les
fichiers CI, Docker, Sonar et ignore existants ; ne les écrasez pas sans examen.
Le fichier Django `requirements.txt.example` est un point de départ facultatif
et ne remplace pas les dépendances d’une application existante.

Le profil Angular + Java utilise deux Dockerfiles sous `ci/`. Les autres profils
ont un Dockerfile à la racine. Préservez tous les helpers livrés avec le profil.

Une fois les adaptations effectuées, validez le YAML dans l’éditeur de pipeline
GitLab, configurez les accès décrits plus bas, puis commitez les fichiers dans le
**dépôt applicatif**. Le workflow ne s’exécute que sur la branche par défaut protégée.

## Profil Python

1. Fournissez un paquet PEP 517 et un `requirements.txt` contenant les dépendances
   runtime complètes et figées, y compris les transitives. Le fichier peut être
   vide pour un paquet utilisant seulement la bibliothèque standard.
2. Fusionnez `ci/requirements.txt` avec vos dépendances de test et de build.
   Les outils fournis comprennent pytest, coverage.py, build, setuptools, wheel,
   CycloneDX et pip-audit. Ajoutez le backend figé correspondant à votre projet
   s’il utilise Hatch, Poetry ou un autre backend.
3. Le job construit un wheel avec `--no-isolation`, installe le projet en mode
   éditable pour pytest et produit couverture et JUnit. L’absence de tests ou un
   test en échec arrête le job. Un script isolé doit être empaqueté ou disposer
   de jobs de construction adaptés.
4. L’image installe le wheel testé et les dépendances runtime depuis wheelhouse.
   Son entrée est `python -m "$PYTHON_MODULE"` : un programme exécutable a besoin
   d’un `__main__.py`. Le contrôle par défaut vérifie l’import, ce qui convient
   aussi à une bibliothèque. Remplacez le hook par un contrôle de démarrage/HTTP
   pour un service.

| Paramètre | Défaut | Adaptation |
| --- | --- | --- |
| `PYTHON_MODULE` | `app` | Module/paquet importable à exécuter |
| `PYTHON_SOURCE_DIR` | `src` | Sources couvertes et analysées par Sonar |
| `SMOKE_SCRIPT` | `ci/smoke-image.sh` | Script de vérification de l’image |

Le wheel garde son nom valide dans `python-package.tar.gz`. Il n’est pas
reconstruit après approbation. Le SBOM applicatif et les audits couvrent
l’environnement **runtime et outils CI** ; le SBOM de conteneur décrit l’image
runtime. L’audit ne cherche pas le paquet local lui-même sur PyPI.

Le profil utilise Python 3.14.7. Pour changer de version, adaptez les images CI,
les deux étapes du Dockerfile et la propriété Sonar ensemble. La résolution
exige des wheels binaires : les extensions natives et bibliothèques système
nécessitent des jobs et un runtime compatibles.

## Profil Django

1. Placez `manage.py` et les dépendances complètes/figées dans `requirements.txt`
   à la racine. Incluez Gunicorn. Les dépendances des outils restent dans
   `ci/requirements.txt`.
2. Définissez `DJANGO_WSGI_MODULE`, par exemple `myproject.wsgi:application`.
   Il s’agit d’un nom de module non secret enregistré dans l’image.
3. Conservez `python manage.py test` ou adaptez le job à votre runner de tests.
   Préparez les services et paramètres de test : `DJANGO_SETTINGS_MODULE` peut
   sélectionner une configuration CI. Le job génère `DJANGO_SECRET_KEY` ; les
   settings de l’application doivent lire cette variable si elle est utilisée.
4. Fournissez un endpoint léger renvoyant HTTP 200 et configurez
   `DJANGO_SMOKE_PATH`, par défaut `/health/`. Autorisez le contrôle local sur
   `127.0.0.1:8000` et fournissez la configuration requise au démarrage.

Exemple à adapter dans la configuration d’URL Django :

```python
from django.http import JsonResponse
from django.urls import path

urlpatterns = [path("health/", lambda request: JsonResponse({"status": "ok"}))]
```

Vérifiez les chemins sources/tests et `coverage.xml` dans les propriétés Sonar.
Le Dockerfile copie les paquets, templates et fichiers statiques : relisez
`.dockerignore`. Le runtime Gunicorn utilise l’UID 10001 et le port 8000.
Migrations, `collectstatic`, secrets de production et déploiement sont à intégrer
dans vos propres procédures. Python 3.14.7 et la résolution par wheels binaires
doivent correspondre aux dépendances de votre application.

## Profil Java

Le profil cible une application **Java/Maven exécutable**, sans frontend.

1. Conservez `pom.xml`, `src/main/` et `src/test/`. Configurez Surefire/JUnit et
   JaCoCo dans le POM. Le job exécute `mvn -DfailIfNoTests=true verify`, copie
   aussi les dépendances de test et exige `target/site/jacoco/jacoco.xml`.
2. Configurez la génération d’un JAR avec `Main-Class`. Les dépendances runtime
   doivent être embarquées ou prises en charge par votre packaging exécutable.
   Un JAR de bibliothèque exige une autre stratégie d’image/runtime.
3. Ajustez `JAVA_JAR_GLOB` : il doit sélectionner un seul JAR exécutable.
   Les JAR sources, Javadoc et tests sont exclus ; une sélection ambiguë échoue.
4. Le hook par défaut exécute le conteneur avec `--help` et exige un code 0.
   Pour un serveur, écrivez un hook de démarrage/HTTP et fournissez les paramètres
   temporaires dont il a besoin.

| Paramètre | Défaut | Adaptation |
| --- | --- | --- |
| `JAVA_SOURCE` | `17` | Version de langage transmise à Sonar |
| `JAVA_JAR_GLOB` | `target/*.jar` | JAR publiable unique |
| `SMOKE_SCRIPT` | `ci/smoke-image.sh` | Contrat de démarrage du projet |

Maven utilise un JDK 17 et le runtime un JRE 17. Modifiez les deux images et
`JAVA_SOURCE` ensemble. Sonar reçoit classes, tests, bibliothèques et couverture.
Les globs de bibliothèques sont omis quand aucune dépendance externe n’existe.

OWASP Maven utilise les identités du graphe résolu et le SBOM inclut les
dépendances de test. Le contrôle d’inventaire exige toutes les identités Maven
du SBOM. Un inventaire applicatif vide, mais identifié et cohérent, est permis
pour une application sans dépendance externe.

Pour un reactor Maven, adaptez l’agrégation des rapports, les chemins de classes
et couverture et le JAR du module déployable. Gradle, WAR et serveurs
d’applications demandent des jobs de build/SBOM et un runtime correspondants.

## Profil Angular

1. Le workspace npm est à la racine, avec ses `package.json`, `package-lock.json`,
   `angular.json`, sources et tests. Les dépendances applicatives ne sont pas
   mises à jour par le pipeline.
2. Définissez `test:ci` et `build:ci` dans votre `package.json`, selon le builder
   et la version Angular du projet. L’absence d’un script ou un test en échec
   fait échouer le pipeline.

Exemple pour un builder Vitest compatible avec ces options :

```json
{
  "scripts": {
    "test:ci": "ng test my-app --watch=false --coverage --coverage-reporters=lcov",
    "build:ci": "ng build my-app --configuration production"
  }
}
```

Les builders Karma peuvent utiliser `--code-coverage`. Le job installe Chromium
et définit `CHROME_BIN=/usr/bin/chromium`. Si Karma tourne comme root dans le
conteneur CI, configurez un launcher `ChromeHeadlessCI`, basé sur
`ChromeHeadless`, avec les flags `["--no-sandbox"]`.

| Paramètre | Défaut | Adaptation |
| --- | --- | --- |
| `ANGULAR_DIST_DIR` | `dist/app/browser` | Dossier du bundle contenant `index.html` |
| `ANGULAR_SMOKE_PATH` | `/` | Route publique renvoyant l’index SPA |

Le job copie le bundle testé dans `.ci-dist/`. L’image Nginx utilise ce bundle,
l’UID Nginx et le port 8080, avec fallback SPA. Le contrôle HTTP compare la
réponse avec l’index testé. Le build n’est pas répété dans le Dockerfile.

Configurez LCOV à son emplacement réel, par défaut `coverage/lcov.info`, puis
ajustez les propriétés Sonar. Le profil utilise Node 22.23.2 : vérifiez sa
compatibilité avec votre version Angular avant modification. Les applications
SSR ont besoin d’un runtime Node et d’un hook adaptés.

Références : [commande de test Angular](https://angular.dev/cli/test) et
[compatibilité des versions](https://angular.dev/reference/versions).

## Profil Angular + Java

Le modèle est prévu pour un monorepo contenant un workspace Angular sous
`frontend/` et une application Java/Maven sous `backend/`. Il teste les deux
composants, réalise une analyse Sonar commune et construit deux images.

```text
.gitlab-ci.yml
sonar-project.properties
ci/                 Helpers et Dockerfiles frontend/backend
frontend/           package.json, verrou npm, sources et tests
backend/            pom.xml, src/main/, src/test/
```

| Paramètre | Défaut | Usage |
| --- | --- | --- |
| `FRONTEND_DIR` | `frontend` | Workspace npm relatif à la racine |
| `BACKEND_DIR` | `backend` | Dossier du POM |
| `ANGULAR_DIST_DIR` | `frontend/dist/app/browser` | Bundle, relatif à la racine |
| `FRONTEND_LCOV` | `frontend/coverage/lcov.info` | Rapport LCOV |
| `BACKEND_JAR_GLOB` | `backend/target/*.jar` | JAR exécutable unique |
| `JAVA_SOURCE` | `17` | Langage Java transmis à Sonar |
| `ANGULAR_SMOKE_PATH` | `/` | Route de vérification SPA |
| `BACKEND_PORT` | `8080` | Port HTTP réel dans le conteneur backend |
| `BACKEND_SMOKE_PATH` | `/actuator/health` | Endpoint existant renvoyant 200 |

Appliquez les contrats npm, Maven/JAR et couverture décrits plus haut. Le helper
Karma facultatif `ci/karma.conf.cjs` vise `@angular/build:karma` et résout les
plugins dans les dépendances du frontend. Un script compatible est :

```text
ng test --watch=false --code-coverage --browsers=ChromeHeadlessCI --karma-config=../ci/karma.conf.cjs
```

Le profil n’ajoute pas Actuator : choisissez un endpoint existant. Les hooks
vérifient chaque image ; les tests de navigateur de bout en bout restent propres
au projet. Nginx fournit le fallback SPA, pas un proxy API : configurez l’URL
backend selon votre application. Gardez le JDK/JRE et `JAVA_SOURCE` compatibles.

### Dépendances temporaires du contrôle d’image

Pour un backend ayant besoin d’une base ou d’un autre service :

- `BACKEND_SMOKE_ENV_FILE` peut être une variable GitLab de type **File**, au
  format Docker env-file.
- `SMOKE_SETUP_SCRIPT` et `SMOKE_CLEANUP_SCRIPT` désignent des scripts de projet
  facultatifs, par exemple `./ci/smoke-setup.sh` et `./ci/smoke-cleanup.sh`.
- Le setup peut créer un réseau/service, définir `SMOKE_NETWORK` et produire le
  fichier d’environnement. Les hooks sont chargés avec `.` : ce sont des scripts
  de confiance exécutés dans le job Docker.
- Le cleanup doit accepter une initialisation partielle, retirer seulement les
  ressources qu’il a créées et supprimer les secrets temporaires. Utilisez des
  données synthétiques et ne journalisez pas les secrets.

Les services nécessaires aux tests Maven doivent être configurés dans leur job
de test ; les hooks d’image sont exécutés plus tard dans `build_container`.

## Profil C

**Prérequis SonarQube :** CFamily et une licence permettant l’analyse C.
Community Build n’inclut pas C dans ses
[langages pris en charge](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/languages/overview).
Le helper vérifie `/api/languages/list` et échoue si C est absent. Le modèle ne
modifie pas le serveur existant et ne remplace pas l’analyse C par celle d’autres fichiers.

1. Fournissez CMake, les sources, les tests CTest et les règles d’installation
   du programme et de ses fichiers runtime. `ctest --no-tests=error` interdit une
   exécution réussie sans tests.
2. Déclarez toutes les dépendances tierces runtime/build/test dans une recette
   Conan 2 ou un `conanfile.txt`, puis générez et commitez `conan.lock`.
3. Le job compile une version instrumentée, exécute CTest et génère la couverture
   gcovr. Il construit ensuite une version Release sans instrumentation et
   exécute à nouveau CTest avant de préparer le paquet.
4. Cppcheck et Sonar exploitent la base de compilation Release. Sonar s’exécute
   dans **le même job** pour retrouver compilateur, en-têtes, cache Conan et
   chemins absolus. Le SonarScanner indépendant de la plateforme est téléchargé
   avec un SHA-256 fixé et utilise le JRE du job.

Exemple de manifeste sans layout personnalisé :

```ini
[requires]
# Vos références package/version figées
[generators]
CMakeDeps
CMakeToolchain
```

```sh
conan lock create . -s build_type=Release --lockfile-out=conan.lock
```

Un projet sans dépendance externe peut conserver un verrou vide généré par Conan.
Pour stabiliser le compilateur et les options, remplacez la détection de profil
par un profil Conan versionné dans votre application.

| Paramètre | Défaut | Usage |
| --- | --- | --- |
| `C_SOURCE_DIR` | `src` | Sources Sonar et filtre de couverture |
| `C_TEST_DIR` | `tests` | Sources des tests Sonar |
| `C_EXECUTABLE` | `/usr/local/bin/app` | Programme installé à empaqueter |
| `CONAN_TOOLCHAIN_FILE` | `build/conan/conan_toolchain.cmake` | Toolchain générée, relative à la racine |
| `SMOKE_SCRIPT` | `ci/smoke-image.sh` | Contrôle `--help` par défaut |

L’installation CMake est préparée sous `.ci-dist/usr/local`. Le paquet et l’image
reprennent cette arborescence ; le runtime Debian utilise l’UID 10001. Installez
aussi les bibliothèques partagées nécessaires, ou liez-les statiquement. Le cache
Conan n’est pas copié dans l’image. Adaptez le hook pour un autre contrat CLI ou
pour un serveur.

Le deployer Conan produit CycloneDX 1.6 depuis le graphe résolu, y compris les
outils et tests. Grype exporte les alertes JSON et l’inventaire CycloneDX complet
scanné. La barrière vérifie la source du scan, la validité de la base et la
couverture des identités Conan nom/version. Un inventaire vide n’est accepté
que pour un graphe vide cohérent avec une application identifiée.

Le matching C utilise NVD/CPE ; les CPE manquants sont générés heuristiquement.
Relisez la [couverture C/C++ de Grype](https://oss.anchore.com/docs/capabilities/cpp/)
et les identités de vos bibliothèques. Une absence d’alerte ne prouve pas
l’absence de vulnérabilité. Les bibliothèques vendues avec le code ou installées
hors Conan doivent être inventoriées explicitement.

Le rapport XML Cppcheck utilise le parseur dédié de Dojo. Les erreurs d’analyse
bloquent le pipeline ; les alertes de sévérité `error` interdisent la publication,
même si l’importeur les classe plus bas. Makefile, Meson, compilation croisée,
cibles embarquées et autres ABI runtime nécessitent des adaptations.

## Runner

Utilisez un Runner Docker de **projet**, verrouillé sur ce projet, avec le tag
`ossf-security`, les jobs sans tag désactivés et l’accès limité aux références
protégées. Le workflow fourni accepte seulement la branche par défaut protégée.

Les analyseurs officiels GitLab utilisent Linux AMD64. Préférez un Runner natif.
Sur ARM, binfmt/QEMU doit être configuré et qualifié séparément ; cela ne constitue
pas une prise en charge native par ces analyseurs.

Extrait de configuration à adapter après l’enregistrement du Runner avec son
jeton d’authentification GitLab :

```toml
concurrent = 1
[[runners]]
  executor = "docker"
  limit = 1
  [runners.docker]
    privileged = true
    volumes = ["/certs/client", "/cache"]
```

Docker-in-Docker utilise TLS sur `2376`. Réservez ce Runner au code de confiance.
Ne montez pas le socket Docker de l’hôte. Prévoyez le disque et la mémoire des
archives, caches et scanners, en plus des services de la plateforme.

Dans **Settings > CI/CD > General pipelines**, ajustez la taille maximale
d’artefacts au **ZIP combiné du job**, et non à chaque fichier isolé. La limite
GitLab par défaut de 100 Mo peut produire HTTP 413, notamment avec deux images
et un JAR dans le même job. Voir les
[réglages GitLab](https://docs.gitlab.com/ci/jobs/job_artifacts/#set-the-maximum-artifacts-size).

## Comptes et services CI

Créez un projet SonarQube privé, un produit DefectDojo et un dépôt Nexus **raw
hosted** dédiés à l’application. Utilisez des identités CI séparées des
administrateurs d’installation.

| Service | Droits attendus |
| --- | --- |
| SonarQube | Lecture/Browse et Execute Analysis du projet ; jeton utilisateur capable d’exporter les résultats |
| DefectDojo | Compte non administrateur autorisé sur le produit et aux imports d’analyse |
| Nexus | `browse`, `read`, `add`, `edit` limités au dépôt raw de l’application |

Donnez aussi Browse au lecteur humain Sonar. Examinez les droits hérités des
groupes globaux et du projet. Un jeton d’analyse Sonar limité à l’envoi peut être
insuffisant pour l’export API des résultats. Utilisez une clé Sonar distincte
par application/branche ; Community Build ne fournit pas une analyse multibranche
équivalente aux éditions qui la prennent en charge.

Configurez Nexus avec `ALLOW_ONCE`, terminez son onboarding et l’acceptation de
licence avant les écritures. Le mécanisme CI publie des archives dans raw, pas
dans un registre Docker.

## Variables CI

Dans **Settings > CI/CD > Variables**, créez les variables suivantes comme
**protégées**. Masquez les secrets et choisissez des valeurs répondant aux
contraintes de masquage GitLab.

| Variable | Valeur ou rôle | Masquer |
| --- | --- | --- |
| `SONAR_HOST_URL` | Origine, par exemple `https://sonar.example.com` | Non |
| `SONAR_PROJECT_KEY` | Projet Sonar de l’application | Non |
| `SONAR_TOKEN` | Jeton de l’identité CI d’analyse et de lecture | Oui |
| `DEFECTDOJO_URL` | Origine `https://dojo.example.com` | Non |
| `DEFECTDOJO_PRODUCT_ID` | Identifiant numérique du produit | Non |
| `DEFECTDOJO_TOKEN` | Jeton de l’identité produit | Oui |
| `NEXUS_URL` | Origine `https://nexus.example.com` | Non |
| `NEXUS_REPOSITORY` | Dépôt raw, par exemple `application-releases` | Non |
| `NEXUS_USER` | Compte de publication dédié | Non |
| `NEXUS_PASSWORD` | Secret de publication | Oui |
| `DD_MIN_SEVERITY` | Seuil Dojo, `High` par défaut | Non |

Les URL des helpers doivent être des origines HTTP(S), sans chemin API,
identifiants, query string ni fragment. Utilisez HTTPS pour un environnement
partagé. Les variables natives `CI_*` identifient le commit, le projet, le
pipeline et le job ; ne les remplacez pas par des paramètres applicatifs.

`OSSF_PROFILE`, les chemins, versions d’outils et commandes de tests sont définis
dans le YAML du profil. Les variables optionnelles spécifiques sont décrites
dans les sections correspondantes. `SONAR_TIMEOUT` borne l’attente de la tâche
Sonar exportée à 900 secondes par défaut.

## Rapports et décision de publication

Les stages déclarés sont `prepare`, `test`, `build`, `scan`, `quality`, `publish`.
Les dépendances `needs` déterminent les artefacts et l’ordre réel ; des contrôles
indépendants peuvent démarrer avant la fin de tout un stage.

La barrière exige 7, 8 ou 12 rapports selon le profil, plus leurs preuves de
cohérence. Les JSON/XML OWASP doivent porter le même inventaire. Pour npm et
Maven, les identités doivent couvrir le SBOM correspondant. Grype/Conan disposent
de contrôles de source, de base et d’inventaire dédiés. OWASP utilise un cache
NVD ; l’enrichissement OSS Index est désactivé faute d’identifiants dédiés.
Le Node Audit Analyzer du contrôle npm reste actif.

Après validation des fichiers, le helper crée un engagement Dojo par exécution
de job et exige un import synchrone terminé pour chaque rapport. Il relit toutes
les pages de résultats et refuse une pagination instable ou incomplète.

La publication est bloquée dans les cas suivants :

- résultat Dojo actif au seuil `DD_MIN_SEVERITY` ou au-dessus ;
- au moins une alerte pip-audit ou npm audit, quelle que soit sa sévérité ;
- sévérité inconnue dans les rapports GitLab, Grype ou la réponse Dojo contrôlée ;
- erreur Cppcheck de niveau `error`, échec de scanner, données manquantes ou
  inventaire incomplet ;
- erreur API, import Dojo incomplet, analyse Sonar d’un autre commit ou Quality
  Gate différente de `OK`.

Les résultats non vérifiés et les doublons actifs comptent par précaution.
Les résultats marqués mitigés, faux positifs ou hors périmètre sont traités selon
leurs indicateurs Dojo. Modifier le seuil n’annule pas les autres règles.

Après les imports, une décision de refus conserve `reports/gate-summary.json`
dans le job de barrière et ignore `publish_nexus`. En cas d’échec technique en
amont, consultez le journal du job fautif : un engagement ou une synthèse peut
ne pas avoir été créé. Un scan exécuté sans erreur peut contenir des alertes.

En cas d’accord, `reports/approval.json` lie commit, pipeline, rapports et SHA-256
des artefacts. Le publisher vérifie le jeu de fichiers et leurs empreintes avant
le premier envoi. Il relit ensuite chaque fichier Nexus pour contrôler ses octets.

## Artefacts Nexus et consommation

La destination est :

```text
/repository/<depot>/<project-id>/<commit>/<pipeline-id>/<nom-du-fichier>
```

| Profils | Fichiers publiés avant `approval.json` |
| --- | --- |
| Django, Angular | `image.tar`, `application-sbom.cdx.json`, `gl-sbom-report.cdx.json` |
| Python | Les trois fichiers précédents et `python-package.tar.gz` |
| Java | Les trois fichiers précédents et `application.jar` |
| C | Les trois fichiers précédents et `c-package.tar.gz` |
| Angular + Java | `frontend-image.tar`, `backend-image.tar`, `application.jar`, `frontend-sbom.cdx.json`, `backend-sbom.cdx.json`, `frontend-container-sbom.cdx.json`, `backend-container-sbom.cdx.json` |

`approval.json` est envoyé **en dernier**. Vérifiez sa présence et les empreintes
avant consommation. Ce fichier est un enregistrement de décision avec empreintes,
pas une signature cryptographique indépendante. `ALLOW_ONCE` interdit l’écrasement :
reprenez une publication partielle avec un nouveau pipeline et un nouveau chemin.

```sh
docker load -i image.tar
# Angular + Java : charger chaque archive d’image séparément.
```

Décompressez les paquets Python/C pour récupérer le wheel ou l’installation,
ou utilisez le JAR avec un runtime compatible. Fournissez séparément les secrets,
services et paramètres de déploiement. Les images sont scannées puis publiées
sans reconstruction après approbation. L’archive Docker externe reste un tar
brut : la compresser en gzip peut ralentir fortement les lectures répétées du
manifest par l’analyseur GitLab.

Une vérification d’écriture/relecture Nexus seule ne prouve pas une publication
applicative approuvée. Validez le pipeline complet avec votre code, vos services
et vos droits avant d’autoriser les livraisons ; voir [la portée des tests](VALIDATION.md).

# Documentation du code et développement

[Accueil](../README.md) · [Contribution](../CONTRIBUTING.md) · [Validation](VALIDATION.md)

## Organisation et conventions

Les installateurs sont des scripts Bash autonomes s’appuyant sur une bibliothèque
commune. Les modèles CI sont des overlays de fichiers ; le helper d’intégration
est un script Python partagé, copié dans le dépôt consommateur à la préparation.

Les guides sont rédigés en français. Les identifiants, commentaires de maintenance
et docstrings suivent l’anglais du code. Les secrets et configurations locales
ne sont pas des exemples de données à ajouter au dépôt.

| Emplacement | Rôle |
| --- | --- |
| `config/ossf.env.example` | Schéma public, valeurs par défaut et commentaires de chaque clé |
| `scripts/init-config.sh` | Génération atomique du fichier privé, sans remplacement |
| `scripts/config.sh` | Lecture littérale, validation, empreintes et helpers d’authentification |
| `scripts/defectdojo-compose.sh` | Wrapper Compose avec le même environnement que l’installation |
| `install-*/` | Préconditions, installation, état géré et contrôles des services |
| `samples-gitlab-ci/<profil>/` | YAML, Dockerfile, propriétés Sonar et helpers du profil |
| `samples-gitlab-ci/security/` | Assemblage d’overlay, intégrations, politique et tests |
| `tests/docker/` | Vérification des installateurs avec les paquets et services réels |

## Contrats des scripts Bash

Les cinq installateurs utilisent Bash en mode strict et une gestion d’erreur qui
conserve le code de sortie sans afficher la commande sensible. Leurs préconditions
exigent Ubuntu 26.04, root et systemd. `--help` est traité avant ces vérifications
pour rester utilisable sans configuration ou service actif.

Le chemin du dépôt est calculé depuis le script. Les installateurs ont besoin
du modèle public et de `scripts/config.sh`, même si le fichier privé est placé
ailleurs avec `OSSF_CONFIG`.

### Bibliothèque de configuration

| Fonction | Contrat |
| --- | --- |
| `ossf_load_config(root)` | Charge les valeurs par défaut, puis les valeurs privées autorisées ; rejette permissions, clés et syntaxe invalides |
| `ossf_require_secret(name)` | Valide la variable par son nom, sans journaliser sa valeur |
| `ossf_check_state(service, keys…)` | Calcule une empreinte d’un jeu ordonné de paramètres et compare l’état existant |
| `ossf_save_state()` | Écrit l’empreinte préparée ; à appeler après succès uniquement |
| `ossf_curl(user, password, options…)` | Transmet l’en-tête Basic par stdin à curl, hors de ses arguments |
| `ossf_urlencode(value)` | Encode un composant d’URL octet par octet, notamment un mot de passe PostgreSQL |
| `ossf_java_property(value)` | Échappe espaces et antislashs pour les propriétés JDBC |
| `ossf_defectdojo_environment()` | Exporte les seuls paramètres de la pile et construit son URL de base interne |

Les valeurs ne sont jamais exécutées par `source` ou `eval`. Le fichier privé est
un format de données ; seule la bibliothèque Bash est sourcée. Ne remplacez pas
ce lecteur par un chargement shell ou par le parsing dotenv de Compose.

### État d’installation

Les empreintes `/etc/ossf/*-config.sha256` détectent des changements de paramètres ;
elles ne sont ni des sauvegardes ni un mécanisme de rotation. Les marqueurs des
répertoires installés limitent les réexécutions à une version gérée. Le wrapper
Dojo désactive le chargement dotenv avec `--env-file /dev/null`, puis transmet les
valeurs littérales exportées et conserve les signaux via `exec`.

## Assemblage d’un profil CI

```sh
python3 samples-gitlab-ci/security/prepare-example.py --help
python3 samples-gitlab-ci/security/prepare-example.py java /tmp/java-ci-overlay
```

`prepare-example.py` accepte un profil parmi les six valeurs connues et une
destination inexistante. Il copie le dossier de profil, ignore les caches Python
et ajoute `ci/pipeline.py`. Il ne recherche pas d’application, n’appelle aucune
API et ne remplace pas un dossier existant. L’overlay obtenu doit être fusionné
dans le dépôt applicatif avant usage.

## Helper d’intégration Python

Le module [pipeline.py](../samples-gitlab-ci/security/pipeline.py) s’importe sans
appeler les services. Son point d’entrée CLI doit s’exécuter à la racine du dépôt
applicatif, où les jobs ont restauré leurs artefacts.

| Commande | Entrées principales | Sorties / effets |
| --- | --- | --- |
| `audit` | Environnements `.venv` et `.tools` | Exécute pip-audit, écrit `reports/pip-audit.json` ; les alertes sont évaluées plus tard |
| `sonar-export` | Métadonnées `reports/sonar-task.txt`, accès Sonar, révision CI | Attend la tâche et exporte résultats/Quality Gate liés à l’analyse |
| `require-c-analyzer` | Accès Sonar | Vérifie la présence du langage `c` avant le job C |
| `validate-dependency-check` | JSON OWASP standard | Contrôle son inventaire et ses erreurs d’analyse |
| `gate` | Tous les rapports du profil, variables CI et accès Dojo | Valide, importe, décide et produit synthèse/approbation selon résultat |
| `publish` | Approbation, fichiers correspondants et accès Nexus | Envoie puis relit les fichiers approuvés ; approbation en dernier |

Exemples d’invocation **dans un job correctement configuré** :

```sh
python ci/pipeline.py sonar-export
python ci/pipeline.py gate
python ci/pipeline.py publish
```

Les variables de service sont détaillées dans le [guide CI](CI.md#variables-ci).
Le module retourne 0 après succès et un statut non nul lors des erreurs traitées.
Les erreurs HTTP ne journalisent pas les réponses susceptibles de contenir des
secrets. Les commandes `gate` et `publish` ont des effets externes : les tests
unitaires les exécutent avec des clients simulés.

### Manifeste de rapports et d’artefacts

- `reports()` retourne les tuples `(fichier, parseur Dojo, clé de données)` du
  profil `OSSF_PROFILE` : 7, 8 ou 12 rapports. Les XML sont traités séparément.
- `assets()` définit le jeu complet de fichiers à approuver : 3 pour
  Django/Angular, 4 pour Python/Java/C et 7 pour Angular + Java.
- `validate_reports()` contrôle les fichiers, schémas utiles, états de scanners
  et inventaires. Il calcule les SHA-256 des rapports et preuves associées avant
  tout import Dojo.

Les JSON compagnons OWASP et, pour C, le graphe Conan et l’inventaire CycloneDX
Grype font partie des preuves hashées. Leur nombre est distinct de celui des
rapports importés dans Dojo.

`validate_dependency_inventory()` compare les PURL npm/Maven après décodage et
retrait des qualifiers/fragments. `c_dependencies()` extrait les identités
nom/version des références Conan et vérifie leur présence dans le SBOM.
`validate_grype()` vérifie base valide, source SBOM attendue, inventaire scanné
et sévérités reconnues. Les inventaires applicatifs vides ne sont admis que
dans les cas Java/C explicitement contrôlés ; cette exception ne s’applique pas
aux SBOM d’images.

### Client HTTP

`API` accepte une origine HTTP(S) sans chemin ni identifiants. Les méthodes
`request()` et `json()` limitent les appels à cette origine, refusent les
redirections et exigent un statut 2xx. Les timeouts connexion/lecture sont
respectivement de 10/180 secondes par requête. L’environnement des proxies
n’est pas repris automatiquement (`trust_env=False`).

Les schémas d’authentification sont Bearer pour Sonar, Token pour Dojo et Basic
pour Nexus. Les modifications de transport doivent préserver la restriction
d’origine et la confidentialité des jetons dans les journaux.

### Cohérence et politique

`sonar_export()` contrôle projet, tâche, analyse et révision avant/après export
paginé. Il exporte les issues non résolues et hotspots ; l’interprétation du
rapport importé dépend ensuite du parseur Dojo. `findings()` refuse boucles,
comptages instables, pages manquantes et identifiants dupliqués.

`gate()` retire une ancienne approbation au démarrage, exige tous les imports
synchrones puis applique la [politique de livraison](CI.md#rapports-et-décision-de-publication).
Un refus de politique conserve la synthèse ; une erreur technique peut arrêter
le traitement avant sa création. `publish()` exige un jeu de fichiers exactement
conforme au profil et les empreintes attendues avant le premier PUT.

## Helpers spécifiques aux profils

| Helper | Contrat utile |
| --- | --- |
| `ci/package.py` — Python/Java/C | Normalise le wheel, le JAR ou l’installation C ; refuse les sélections ambiguës et conserve les artefacts testés |
| `angular-java/ci/normalize-jar.py` | Sélectionne un JAR backend unique avec `Main-Class` |
| `ci/check-npm-audit.cjs` | Vérifie structure, comptage, sévérités et code de sortie npm sans transformer une erreur réseau en rapport vide |
| `angular-java/ci/karma.conf.cjs` | Adaptateur facultatif pour les plugins Karma du frontend consommateur |
| `java/ci/sonar-scan.sh` | Construit les arguments Sonar et évite les globs JAR vides |
| `c/ci/sbom_deployer.py` | Génère CycloneDX depuis le graphe Conan avec dépendances build et tests |
| `c/ci/install-scanner.py` | Vérifie l’empreinte du ZIP SonarScanner et son extraction avant installation locale |
| `ci/smoke-image.sh` / `ci/smoke-images.sh` | Vérifie le contrat runtime et nettoie les conteneurs temporaires selon le profil |

Les scripts de packaging et d’installation du scanner sont des entrées CLI,
pas des bibliothèques à importer. Les fichiers répliqués dans plusieurs overlays
doivent rester cohérents quand leur comportement commun change.

## Vérifications locales

Tests de politique et publisher, sans services externes :

```sh
python3 -m venv /tmp/ossf-policy-tests
/tmp/ossf-policy-tests/bin/pip install requests==2.34.2
/tmp/ossf-policy-tests/bin/python -m unittest discover \
  -s samples-gitlab-ci/security -p 'test_*.py'
```

Syntaxe Bash des scripts d’administration :

```sh
for script in install-*/*.sh scripts/*.sh tests/docker/*.sh; do
  bash -n "$script"
done
```

Le [harness Docker](../tests/docker/README.md) ajoute ShellCheck, tests de
configuration, erreurs injectées et intégrations des installateurs. Le test
GitLab utilise le compilateur YAML de la version réellement installée. Le parseur
YAML local ne vérifie pas à lui seul les templates GitLab, `needs` ou les règles.

Les changements de documentation et de commentaires demandent une vérification
des liens, de la syntaxe et de la concordance avec le code. Ne relancez les
installations complètes que si le changement ou une incertitude technique le justifie.

## Ajouter un profil ou changer une version

1. Définir le contrat de sources, dépendances, tests, couverture et runtime.
2. Ajouter l’overlay et le choix dans `prepare-example.py`.
3. Définir les rapports/parseurs, preuves d’inventaire et artefacts approuvés.
4. Tester les chemins de refus autant que l’accord ; aucun scanner absent ou
   échec d’API ne doit devenir une autorisation.
5. Compiler le YAML avec GitLab et vérifier les commandes/images sur une fixture.
6. Mettre à jour le catalogue, les variables, la compatibilité des éditions et
   la portée de validation documentée.

Une version d’installateur doit être revue avec son archive/empreinte, les paquets,
le JDK, la base, les marqueurs d’état et les procédures de migration associés.

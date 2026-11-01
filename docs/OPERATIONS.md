# Exploitation et diagnostic

[Accueil](../README.md) · [Installation](INSTALLATION.md) · [Configuration](CONFIGURATION.md)

## Contrôler les services

Sur les VM concernées :

```sh
# Machine 1
sudo gitlab-ctl status
sudo systemctl status gitlab-runner
sudo systemctl status docker
sudo bash scripts/defectdojo-compose.sh ps

# Machine 2
sudo systemctl status sonar
sudo systemctl status postgresql

# Machine 3
sudo systemctl status nexus
```

Pour les journaux :

```sh
sudo gitlab-ctl tail
sudo journalctl -u gitlab-runner -n 100 --no-pager
sudo bash scripts/defectdojo-compose.sh logs --tail 100 uwsgi
sudo journalctl -u sonar -n 100 --no-pager
sudo journalctl -u nexus -n 100 --no-pager
```

Exécutez chaque commande sur la machine qui héberge le service et le wrapper
depuis le dépôt complet. SonarQube écrit aussi ses journaux sous
`/opt/sonarqube/logs`. Vérifiez les journaux avant de les partager : les journaux
d’application et les sorties de diagnostic ne sont pas tous produits par OSSF.

## Réexécuter un installateur

Une réexécution supportée utilise **la même version gérée et les mêmes paramètres**.
Les scripts vérifient les marqueurs et les empreintes de configuration avant
les étapes sensibles, puis contrôlent disponibilité et authentification.

- Conservez `config/ossf.env` et les marqueurs sous `/etc/ossf`.
- Ne régénérez pas les clés Dojo pour une base existante.
- Une installation étrangère ou une version différente peut être refusée.
- `WAIT_TIMEOUT` ajuste l’attente de disponibilité ; il ne corrige ni un manque
  de mémoire ni une erreur de base de données.

Pour reprendre une installation antérieure au fichier partagé, renseignez les
**vrais paramètres existants** : mots de passe, clés, noms, chemins et ports.
Un fichier nouvellement généré ne récupère pas les secrets d’une installation.

## Modifier un secret ou une version

Le fichier privé est la référence d’administration. Les copies runtime servent
aux applications ; ne les faites pas évoluer indépendamment.

Un changement de mot de passe suit la procédure de l’application, puis une mise
en cohérence de la configuration et de l’état géré. Modifier simplement la
valeur dans le fichier et relancer le script n’est pas une rotation.

Les clés de version servent au choix d’une installation. Une montée de version
demande la procédure éditeur, l’examen des compatibilités JDK/base, une sauvegarde
restaurable et une validation adaptée. Les scripts ne migrent pas arbitrairement
des bases ou des installations d’une autre version.

### Mot de passe GitLab existant différent

Si l’installateur affiche `Configured GitLab password does not match the installed account`,
son contrôle final a échoué. Vérifiez d’abord le chemin de configuration utilisé.
Le paramètre de création initiale ne réinitialise pas un compte existant.

Pour décider explicitement de mettre le compte `root` en cohérence avec la
configuration, la [tâche GitLab de réinitialisation](https://docs.gitlab.com/security/reset_user_password/#use-a-rake-task)
est disponible sur la VM GitLab :

```sh
sudo gitlab-rake "gitlab:password:reset[root]"
```

Cette commande **change le mot de passe du compte existant**. Saisissez la valeur
prévue dans la configuration aux invites, puis relancez l’installateur avec le
même fichier et domaine. Ne passez pas le mot de passe en argument de commande.
L’empreinte gérée n’est enregistrée qu’après le contrôle réussi.

## Points à sauvegarder

| Service | Données et état à prendre en compte |
| --- | --- |
| Configuration OSSF | Fichier privé, configuration des VM et état sous `/etc/ossf` |
| GitLab | Dépôts, base, secrets et configuration GitLab selon sa procédure officielle |
| Runner | Configuration, rattachement au projet et gestion de ses identifiants |
| SonarQube | Base PostgreSQL, configuration et extensions installées |
| Nexus | Données sous `/opt/sonatype-work`, blob stores et configuration |
| DefectDojo | Base, volumes, fichier privé central et clés de signature/chiffrement |

Coordonnez les sauvegardes de données et de secrets selon les procédures des
produits. Une copie des scripts ou un simple export de rapports ne remplace pas
une sauvegarde des services. Testez la restauration dans un environnement séparé ;
la validation du dépôt ne certifie pas votre procédure de reprise.

## Diagnostic rapide

| Symptôme | Vérification utile |
| --- | --- |
| Configuration absente ou illisible | Chemin `OSSF_CONFIG`, dépôt complet et permissions `600` |
| Clé inconnue, doublon ou valeur mal interprétée | Format littéral et modèle `ossf.env.example` ; ne pas utiliser `source` |
| Empreinte de configuration différente | Restaurer les paramètres d’origine ou préparer une rotation cohérente |
| GitLab et Dojo en conflit réseau | Port Dojo `8088` sur la machine partagée, résolution DNS et écoute des services |
| Sonar ne devient pas `UP` | Journaux Sonar, PostgreSQL, mémoire et limites Elasticsearch |
| Scan C ignoré ou prérequis C absent | Analyseur CFamily et licence ; Community Build n’analyse pas C |
| Nexus répond mais refuse les écritures | Onboarding/licence, droits sur le dépôt et politique `ALLOW_ONCE` |
| Sonar renvoie 403 au compte de lecture | Droit Browse du projet, droits hérités et type du jeton |
| Job CI en attente | Runner en ligne, tag `ossf-security`, branche protégée et rattachement au projet |
| Upload d’artefacts HTTP 413 | Taille maximale du ZIP combiné du job et limites du proxy |
| Image non lisible par l’analyseur | Archive tar brute présente, permissions et `needs`/`dependencies` |
| Inventaire npm OWASP incomplet | Modules installés à côté du verrou copié et Node Audit actif |
| Inventaire Maven incomplet | Plugin OWASP Maven, dépendances de test et SBOM cohérent |
| Barrière Dojo en échec | Synthèse du job, imports, seuil, révision Sonar et résultats actifs |

## Rapports CI et livraisons partielles

Commencez par le premier job en échec dans GitLab. Une erreur de prérequis ou de
scanner peut empêcher la création de la synthèse et de l’engagement Dojo.
Après les imports, la décision de politique se lit dans `reports/gate-summary.json`.

Un scanner réussi signifie qu’il s’est exécuté, pas que son rapport est vide.
Un refus de la barrière doit ignorer le publisher. Examinez les résultats et
leur triage selon votre politique ; un rapport absent n’est pas une absence d’alerte.

Si une écriture Nexus échoue après certains fichiers, le chemin reste partiel.
Le consommateur doit exiger `approval.json`, envoyé en dernier, puis vérifier
les SHA-256. Avec `ALLOW_ONCE`, relancez une publication approuvée sous un nouveau
pipeline plutôt que d’écraser le même chemin.

Les durées de rétention dépendent des `expire_in` des jobs et des paramètres
GitLab. Plusieurs artefacts volumineux des exemples expirent après un jour.
Définissez une politique de conservation adaptée pour GitLab, Dojo et Nexus.

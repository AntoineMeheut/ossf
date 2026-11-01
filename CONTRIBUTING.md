# Contribuer à OSSF

[Accueil](README.md) · [Documentation du code](docs/DEVELOPMENT.md) · [Validation](docs/VALIDATION.md)

## Préparer une modification

Décrivez le problème, le comportement obtenu et les composants concernés.
Conservez les exemples CI génériques : chemins paramétrables, aucun code
applicatif privé, aucun nom ou rapport d’exécution propre à un projet utilisateur.
Les fixtures de validation peuvent être créées dans un dossier temporaire séparé.

Les guides sont en français ; commentaires de maintenance, docstrings et noms
techniques restent en anglais pour suivre le code existant. Préférez expliquer
un contrat, une contrainte ou une décision plutôt que paraphraser une instruction.

## Vérifier le changement

- Documentation : contrôler les liens relatifs, les commandes et leur concordance
  avec le code ; conserver une portée de validation explicite.
- Helpers CI : exécuter les tests partagés et ajouter des cas pertinents pour
  toute évolution de politique, de format ou de publication.
- YAML ou image : vérifier structure et compilation GitLab, puis tester le
  comportement modifié sur une fixture adaptée.
- Installateur/configuration : syntaxe Bash, ShellCheck et tests d’erreur ; les
  changements de runtime ou de version demandent les intégrations concernées.

Les commandes et l’organisation des tests sont dans le
[guide de développement](docs/DEVELOPMENT.md). Les tests d’installation utilisent
des conteneurs privilégiés et le noyau de l’hôte : lisez leurs prérequis avant
de les lancer.

## Présenter une contribution

La description d’une pull request doit préciser :

1. le problème et le comportement après modification ;
2. les choix ou limites utiles à la revue ;
3. les vérifications effectivement exécutées et les vérifications restantes ;
4. les changements de documentation et de compatibilité éventuels.

Ne présentez pas un lint YAML comme une preuve de pipeline complet, ni un test
ARM comme une validation AMD64. Une évolution d’édition, de licence ou de
dépendance doit apparaître dans la documentation et les prérequis.

## Signaler un problème

Utilisez les [issues du dépôt](https://github.com/AntoineMeheut/ossf/issues) avec
les versions, l’architecture, la commande concernée et des journaux expurgés.
N’ajoutez pas de fichier privé, jeton, mot de passe ou contenu applicatif
confidentiel à une issue ou une pull request.

Les contributions au code du dépôt sont distribuées sous [licence MIT](LICENSE).
Les licences des produits et outils intégrés restent applicables séparément.

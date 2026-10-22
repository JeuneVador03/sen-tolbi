# Sen Tolbi

Code du site **sen-tolbi.com**, marketplace agricole de Dakar.
Ce dépôt est publié automatiquement sur Netlify : ce qui est sur la branche `main` est en ligne.

## Comment on travaille

1. On ne modifie jamais `main` directement.
2. Chaque modification se fait sur une **branche** à son nom (ex. `coumba-page-contact`).
3. On ouvre une **pull request** (proposition de modification) vers `main`.
4. Netlify crée un **aperçu** du site : on le teste sur téléphone avant de valider.
5. ELO relit, puis fusionne : le site en ligne est mis à jour tout seul.

## Règles

- Pas de mot de passe, ni de clé `service_role` dans les fichiers. Seule la clé publique Supabase (`sb_publishable_…`) est autorisée.
- Une modification = un sujet.
- Les grosses fonctionnalités passent d'abord par l'accord des associés et le Trello.

Premier enregistrement : copie fidèle du site en ligne du 14/07/2026, pour pouvoir revenir en arrière.

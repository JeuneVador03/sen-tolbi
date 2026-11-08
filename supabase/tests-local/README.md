# Tests locaux T17 (statut et annulation des commandes)

Postgres local uniquement, jamais la base réelle. La base jetable `sentolbi_t17` reproduit la base réelle
du 8/11/2026 (tables lues en lecture seule, puis les SQL T6, T11 et option advisors du dossier `supabase/`).

```bash
./run.sh a          # mécanisme + variante A « le vendeur confirme » + retour en arrière
./run.sh b          # mécanisme + variante B « l'équipe confirme » + retour en arrière
./40-concurrence.sh # deux annulations à la même seconde : stock remis une seule fois
```

Résultat du 8/11/2026 : 17 tests communs, 22 tests variante A, 17 tests variante B, retour en arrière
et concurrence : tout passe.

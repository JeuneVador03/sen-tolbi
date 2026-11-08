# Tests locaux T19 (heures avec fuseau)

Postgres local uniquement, jamais la base réelle. Base jetable `sentolbi_t19` qui reproduit la base réelle
(tables lues en lecture seule le 8/11/2026, puis les SQL T6, T11 et option advisors), avec les heures
réelles d'un profil, d'un produit et d'une commande. Le SQL T19 et le retour en arrière sont lancés
exprès avec une session en heure de Paris : le résultat ne doit pas en dépendre.

```bash
PGPASSWORD=... ./run.sh
```

Résultat du 8/11/2026 : T1 à T7 et R1-R2 passent (colonnes converties, anciennes heures lues comme UTC,
commande du 21/10 21:49 UTC affichée 21:49 à Dakar, nouvelle commande via preparer_commande à l'heure
exacte et stock baissé, format JSON « +00:00 », vendeurs_publics OK, restauration T14 OK, retour en
arrière identique à l'avant).

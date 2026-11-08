-- Retour en arrière des zones harmonisées (à n'utiliser qu'en cas de besoin).
-- Avant la PR #21, seule la liste VENDEUR utilisait les anciens noms (la liste
-- acheteur avait déjà « Plateau / Centre-ville » et « Almadies / Ngor ») : le retour
-- en arrière ne touche donc que les vendeurs. Le 08/11/2026, le seul profil en
-- « Plateau / Centre-ville » est un acheteur : il n'est pas touché.
-- Limite : un vendeur inscrit après la PR #21 avec ces noms serait aussi renommé.
-- Ne lancer ce fichier que si on revient aussi sur la PR #21.

begin;
update public.utilisateurs set zone = 'Plateau'         where zone = 'Plateau / Centre-ville' and type = 'vendeur';
update public.utilisateurs set zone = 'Ngor / Almadies' where zone = 'Almadies / Ngor'        and type = 'vendeur';
select zone, type, count(*) from public.utilisateurs group by zone, type order by zone;
commit;
